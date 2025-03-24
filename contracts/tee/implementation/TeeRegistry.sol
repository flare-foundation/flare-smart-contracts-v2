// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/tee/ITeeDataConnector.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/IRelay.sol";
import "../../utils/lib/AddressSet.sol";

/**
 * TeeRegistry is used for registration of TEE machines.
 */
contract TeeRegistry is ITeeRegistry, Governed, AddressUpdatable {
    using AddressSet for AddressSet.State;

    struct TeeState {
        address owner;
        TeeStatus status; // 0: initialized, 1: production, 2: paused, 3: paused_for_upgrade, 4: replicating
        uint64 availabilityCheckValidityEndTs;
        uint64 lastStatusChangeTs;
        bytes32 codeHash;
        bytes32 platform; // utf8 encoded
        string url;
    }

    struct TeeVersion {
        uint256 version;
        bytes32[] platforms; // utf8 encoded platform
    }

    bytes32 public constant TEE_SOURCE_ID = bytes32("TEE");
    bytes32 public constant REG_OP_TYPE = bytes32("REG");
    bytes32 public constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 public constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// TEE data connector contract.
    ITeeDataConnector public teeDataConnector;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Relay contract.
    IRelay public relay;

    /// The minimum supported version.
    uint256 public minSupportedVersion;
    /// The latest version.
    uint256 public latestVersion;
    /// The minimum duration (in paused status) before a TEE machine can be upgraded.
    uint256 public pauseBeforeUpgradeMinDurationSeconds;
    /// The duration for which an availability check proof is valid.
    uint256 public availabilityCheckProofValiditySeconds;
    /// The TEE availability check validity duration, in seconds.
    /// In order to receive rewards, TEE must be checked for availability at least once in this period.
    uint256 public availabilityCheckValidityDurationSeconds;

    AddressSet.State private activeTeeIds;
    mapping(address teeId => TeeState) private teeStates;
    mapping(bytes32 codeHash => TeeVersion) private codeHashToVersion;
    mapping(uint256 version => bytes32[]) private versionOpTypes; // utf8 encoded operation types (XRP, BTC, etc.)
    mapping(uint256 version => bytes32) private versionToCodeHash;
    mapping(address oldTeeId => address newTeeId) public replications;
    /// Proposed new TEE owner.
    mapping(address teeId => address) public proposedTeeOwner;

    modifier onlyOwner(address _teeId) {
        require(teeStates[_teeId].owner == msg.sender, "only owner");
        _;
    }

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _pauseBeforeUpgradeMinDurationSeconds The minimum duration (paused status) before a tee can be upgraded.
     * @param _availabilityCheckProofValiditySeconds The duration for which an availability check proof is valid.
     * @param _availabilityCheckValidityDurationSeconds The duration for which the availability of a tee is valid.
     * @param _minSupportedVersion The minimum supported version.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _pauseBeforeUpgradeMinDurationSeconds,
        uint256 _availabilityCheckProofValiditySeconds,
        uint256 _availabilityCheckValidityDurationSeconds,
        uint256 _minSupportedVersion
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        _setPauseBeforeUpgradeMinDuration(_pauseBeforeUpgradeMinDurationSeconds);
        _setAvailabilityCheckProofValidity(_availabilityCheckProofValiditySeconds);
        _setAvailabilityCheckValidityDuration(_availabilityCheckValidityDurationSeconds);
        require(_minSupportedVersion > 0, "invalid version");
        minSupportedVersion = _minSupportedVersion;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function register(
        address _teeId,
        string calldata _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external payable
    {
        require(teeStates[_teeId].owner == address(0), "tee already registered");
        _checkVersionSupported(_codeHash);
        require(_isSupportedPlatform(_platform, codeHashToVersion[_codeHash].platforms), "platform not supported");

        teeStates[_teeId] = TeeState({
            owner: msg.sender,
            status: TeeStatus.INITIALIZED,
            availabilityCheckValidityEndTs: 0,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: _codeHash,
            platform: _platform,
            url: _url
        });

        _requestAvailabilityCheckAttestation(_teeId, _teeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function requestAvailabilityCheckAttestation(
        address _teeId,
        address _testOnTeeId
    )
        external payable
    {
        _requestAvailabilityCheckAttestation(_teeId, _testOnTeeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external onlyOwner(_proof.data.requestBody.teeMachine.teeId)
    {
        address teeId = _proof.data.requestBody.teeMachine.teeId;
        TeeState storage teeState = teeStates[teeId];
        TeeStatus status = teeState.status;
        require(status == TeeStatus.INITIALIZED || status == TeeStatus.PAUSED, "invalid tee status");
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        _checkVersionSupported(teeState.codeHash);
        _validateAvailabilityCheckTs(teeId, _proof.data.timestamp);
        _validateAvailabilityCheckResponse(teeState, _proof);

        teeState.status = TeeStatus.PRODUCTION;
        uint64 endTs = uint64(_proof.data.timestamp + availabilityCheckValidityDurationSeconds);
        if (endTs > teeState.availabilityCheckValidityEndTs) {
            teeState.availabilityCheckValidityEndTs = endTs;
            emit AvailabilityCheckValidityExtended(teeId, endTs);
        }
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.add(teeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function confirmAvailability(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
         external
    {
        address teeId = _proof.data.requestBody.teeMachine.teeId;
        TeeState storage teeState = teeStates[teeId];
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        _checkVersionSupported(teeState.codeHash);
        _validateAvailabilityCheckTs(teeId, _proof.data.timestamp);
        _validateAvailabilityCheckResponse(teeState, _proof);

        uint64 endTs = uint64(_proof.data.timestamp + availabilityCheckValidityDurationSeconds);
        if (endTs > teeState.availabilityCheckValidityEndTs) {
            teeState.availabilityCheckValidityEndTs = endTs;
            emit AvailabilityCheckValidityExtended(teeId, endTs);
        }
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function pause(address _teeId)
        external
    {
        TeeState storage teeState = teeStates[_teeId];
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
        require(msg.sender == teeState.owner || codeHashToVersion[teeState.codeHash].version < minSupportedVersion,
            "only owner or obsolete version");

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.remove(_teeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function pauseWithProof(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.data.requestBody.teeMachine.teeId;
        TeeState storage teeState = teeStates[teeId];
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
        require(_proof.data.responseBody.status != ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        _validateAvailabilityCheckTs(teeId, _proof.data.timestamp);
        _validateAvailabilityCheckResponse(teeState, _proof);

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.remove(teeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function toPauseForUpgrade(address _teeId)
        external payable
        onlyOwner(_teeId)
    {
        TeeState storage teeState = teeStates[_teeId];
        TeeStatus status = teeState.status;
        require(status == TeeStatus.PAUSED || status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid tee status");
        if (status == TeeStatus.PAUSED) {
            require(teeState.lastStatusChangeTs + pauseBeforeUpgradeMinDurationSeconds < block.timestamp,
                "pause for upgrade too soon");
            teeState.status = TeeStatus.PAUSED_FOR_UPGRADE;
            teeState.lastStatusChangeTs = uint64(block.timestamp);
        }
        _checkFee(TO_PAUSE_FOR_UPGRADE, _teeId);
        PauseForUpgrade memory message = PauseForUpgrade({ teeId: _teeId });
        bytes32 instructionId = keccak256(abi.encode(REG_OP_TYPE, TO_PAUSE_FOR_UPGRADE, _teeId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(TeeMachine({ teeId: _teeId, owner: msg.sender, url: teeState.url })),
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            TO_PAUSE_FOR_UPGRADE,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external payable
        onlyOwner(_oldTeeId)
        onlyOwner(_proof.data.requestBody.teeMachine.teeId)
    {
        address newTeeId = _proof.data.requestBody.teeMachine.teeId;
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        TeeState storage oldTeeState = teeStates[_oldTeeId];
        require(oldTeeState.status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid old tee status");
        TeeState storage newTeeState = teeStates[newTeeId];
        require(newTeeState.status == TeeStatus.INITIALIZED ||
            (replications[_oldTeeId] == newTeeId && newTeeState.status == TeeStatus.REPLICATING), // retry
            "invalid new tee status");
        _checkVersionSupported(newTeeState.codeHash);
        require(_getTeeVersion(newTeeId) >= _getTeeVersion(_oldTeeId), "new tee version too old");
        _validateAvailabilityCheckTs(newTeeId, _proof.data.timestamp);
        _validateAvailabilityCheckResponse(newTeeState, _proof);
        _checkFee(REPLICATE_FROM, newTeeId);

        replications[_oldTeeId] = newTeeId;
        newTeeState.status = TeeStatus.REPLICATING;
        newTeeState.lastStatusChangeTs = uint64(block.timestamp);
        ReplicateTeeMachine memory message = ReplicateTeeMachine({
            oldTeeMachine: _getTeeMachineWithAttestationData(_oldTeeId, oldTeeState),
            newTeeMachine: _getTeeMachineWithAttestationData(newTeeId, newTeeState)
        });
        require(
            _isSupportedPlatform(
                message.newTeeMachine.platform,
                codeHashToVersion[message.oldTeeMachine.codeHash].platforms
            ) &&
            _isSupportedPlatform(
                message.oldTeeMachine.platform,
                codeHashToVersion[message.newTeeMachine.codeHash].platforms
            ),
            "platforms not supported");

        bytes32 instructionId = keccak256(abi.encode(REG_OP_TYPE, REPLICATE_FROM, _oldTeeId, newTeeId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(ITeeRegistry.TeeMachine({ teeId: newTeeId, owner: msg.sender, url: newTeeState.url })),
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            REPLICATE_FROM,
            abi.encode(message)
        );
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        onlyOwner(_proof.data.requestBody.teeMachine.teeId)
        onlyOwner(_newTeeId)
    {
        address oldTeeId = _proof.data.requestBody.teeMachine.teeId;
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        TeeState storage oldTeeState = teeStates[oldTeeId];
        require(oldTeeState.status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid old tee status");
        TeeState storage newTeeState = teeStates[_newTeeId];
        require(newTeeState.status == TeeStatus.REPLICATING, "invalid new tee status");
        // in case multiple replications are triggered only the last one can be confirmed
        require(replications[oldTeeId] == _newTeeId, "replication not valid");
        _checkVersionSupported(newTeeState.codeHash);

        _validateAvailabilityCheckTs(_newTeeId, _proof.data.timestamp);
        _validateAvailabilityCheckResponse(newTeeState, _proof);

        oldTeeState.status = TeeStatus.PRODUCTION;
        uint64 endTs = uint64(_proof.data.timestamp + availabilityCheckValidityDurationSeconds);
        oldTeeState.availabilityCheckValidityEndTs = endTs;
        emit AvailabilityCheckValidityExtended(oldTeeId, endTs);
        oldTeeState.lastStatusChangeTs = uint64(block.timestamp);
        oldTeeState.codeHash = newTeeState.codeHash;
        oldTeeState.platform = newTeeState.platform;
        oldTeeState.url = newTeeState.url;
        delete replications[oldTeeId];
        delete teeStates[_newTeeId];
        activeTeeIds.add(oldTeeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function proposeNewOwner(address _teeId, address _newOwner)
        external onlyOwner(_teeId)
    {
        proposedTeeOwner[_teeId] = _newOwner;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function confirmOwnership(address _teeId)
        external
    {
        require(proposedTeeOwner[_teeId] == msg.sender, "only proposed owner");
        teeStates[_teeId].owner = msg.sender;
        delete proposedTeeOwner[_teeId];
    }

    /**
     * Set the minimum supported version.
     * @param _minSupportedVersion The minimum supported version.
     * Can only be called by the governance.
     */
    function setMinSupportedVersion(uint256 _minSupportedVersion)
        external onlyGovernance
    {
        require(_minSupportedVersion > minSupportedVersion && _minSupportedVersion <= latestVersion,
            "invalid version");
        minSupportedVersion = _minSupportedVersion;
    }

    /**
     * Add a new TEE version.
     * @param _version The version number.
     * @param _codeHash The code hash.
     * @param _platforms The supported platforms.
     * @param _opTypes The supported operation types.
     * Can only be called by the governance.
     */
    function addNewTeeVersion(
        uint256 _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms, // utf8 encoded platforms
        bytes32[] calldata _opTypes // utf8 encoded operation types (XRP, BTC, FDC, etc.)
    )
        external onlyGovernance
    {
        require(_version > latestVersion, "invalid version");
        require(_codeHash != bytes32(0), "invalid code hash");
        require(codeHashToVersion[_codeHash].version == 0, "code hash already registered");
        latestVersion = _version;
        codeHashToVersion[_codeHash] = TeeVersion({
            version: _version,
            platforms: _platforms
        });
        versionToCodeHash[_version] = _codeHash;
        versionOpTypes[_version] = _opTypes;
    }

    /**
     * Set the minimum duration before a TEE can be paused for upgrade.
     * @param _pauseBeforeUpgradeMinDurationSeconds The minimum duration in seconds.
     * Can only be called by the governance.
     */
    function setPauseBeforeUpgradeMinDurationSeconds(uint256 _pauseBeforeUpgradeMinDurationSeconds)
        external onlyGovernance
    {
        _setPauseBeforeUpgradeMinDuration(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /**
     * Set the duration for which an availability check proof is valid.
     * @param _availabilityCheckProofValiditySeconds The duration in seconds.
     * Can only be called by the governance.
     */
    function setAvailabilityCheckProofValiditySeconds(uint256 _availabilityCheckProofValiditySeconds)
        external onlyGovernance
    {
        _setAvailabilityCheckProofValidity(_availabilityCheckProofValiditySeconds);
    }

    /**
     * Set the duration for which the availability check validity is extended.
     * @param _availabilityCheckValidityDurationSeconds The duration in seconds.
     * Can only be called by the governance.
     */
    function setAvailabilityCheckValidityDurationSeconds(uint256 _availabilityCheckValidityDurationSeconds)
        external onlyGovernance
    {
        _setAvailabilityCheckValidityDuration(_availabilityCheckValidityDurationSeconds);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachineStatus(address _teeId)
        external view
        returns(TeeStatus)
    {
        TeeState storage teeState = _getTeeState(_teeId);
        return teeState.status;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachine(address _teeId)
        external view
        returns(TeeMachine memory _teeMachine)
    {
        TeeState storage teeState = _getTeeState(_teeId);
        _teeMachine = TeeMachine({
            teeId: _teeId,
            owner: teeState.owner,
            url: teeState.url
        });
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachineWithAttestationData(address _teeId)
        external view
        returns(TeeMachineWithAttestationData memory _teeMachine)
    {
        TeeState storage teeState = _getTeeState(_teeId);
        _teeMachine = _getTeeMachineWithAttestationData(_teeId, teeState);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getRandomTeeIds(uint256 _count)
        external view
        returns(address[] memory _teeIds)
    {
        uint256 length = activeTeeIds.list.length;
        require (_count <= length, "too many tee ids requested");
        (uint256 randomNumber,,) = relay.getRandomNumber();

        // Reservoir sampling
        uint256[] memory indices = new uint256[](_count);
        for (uint256 i = 0; i < _count; i++) {
            indices[i] = i;
        }
        for (uint256 i = _count; i < length; i++) {
            randomNumber = uint256(keccak256(abi.encode(randomNumber, i)));
            uint256 j = randomNumber % (i + 1);
            if (j < _count) {
                indices[j] = i;
            }
        }

        // Copy tee ids for random indices
        _teeIds = new address[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _teeIds[i] = activeTeeIds.list[indices[i]];
        }
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function arePlatformsCompatible(address _teeId, address[] calldata _backupTeeIds)
        external view
        returns(bool)
    {
        TeeState storage teeState = teeStates[_teeId];
        bytes32 platform = teeState.platform;
        bytes32[] storage platforms = codeHashToVersion[teeState.codeHash].platforms;
        for (uint256 i = 0; i < _backupTeeIds.length; i++) {
            TeeState storage backupTeeState = teeStates[_backupTeeIds[i]];
            // check if backup tee platform is compatible with main tee
            if (!_isSupportedPlatform(backupTeeState.platform, platforms)) {
                return false;
            }
            // check if main tee platform is compatible with backup tee
            if (!_isSupportedPlatform(platform, codeHashToVersion[backupTeeState.codeHash].platforms)) {
                return false;
            }
        }
        return true;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachineVersion(address _teeId)
        external view
        returns(uint256 _version)
    {
        _version = _getTeeVersion(_teeId);
        require(_version != 0, "tee not found");
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getActiveTeeIds()
        external view
        returns(address[] memory)
    {
        return activeTeeIds.list;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getVersionInfo(uint256 _version)
        external view
        returns(bytes32 _codeHash, bytes32[] memory _platforms, bytes32[] memory _opTypes)
    {
        _codeHash = versionToCodeHash[_version];
        require(_codeHash != bytes32(0), "invalid version");
        TeeVersion storage teeVersion = codeHashToVersion[_codeHash];
        _platforms = teeVersion.platforms;
        _opTypes = versionOpTypes[_version];
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getCodeHashVersion(bytes32 _codeHash)
        external view
        returns(uint256 _version)
    {
        _version = codeHashToVersion[_codeHash].version;
        require(_version != 0, "invalid code hash");
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function isOpTypeSupported(address _teeId, bytes32 _opType)
        external view
        returns(bool)
    {
        bytes32[] storage opTypes = versionOpTypes[_getTeeVersion(_teeId)];
        for (uint256 i = 0; i < opTypes.length; i++) {
            if (opTypes[i] == _opType) {
                return true;
            }
        }
        return false;
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        teeDataConnector = ITeeDataConnector(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeDataConnector"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _requestAvailabilityCheckAttestation(
        address _teeId,
        address _testOnTeeId
    )
        internal
    {
        TeeState storage teeState = _getTeeState(_teeId);
        TeeMachineWithAttestationData memory teeMachine = _getTeeMachineWithAttestationData(_teeId, teeState);
        ITeeAvailabilityCheck.RequestBody memory requestBody = ITeeAvailabilityCheck.RequestBody({
            teeMachine: teeMachine,
            rewardEpochId: flareSystemsManager.getCurrentRewardEpochId()
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _testOnTeeId;

        teeDataConnector.requestAttestation{value: msg.value}(
            0,
            0,
            teeIds,
            bytes.concat(TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE, TEE_SOURCE_ID, abi.encode(requestBody))
        );
    }

    function _setPauseBeforeUpgradeMinDuration(uint256 _pauseBeforeUpgradeMinDurationSeconds) internal {
        require(_pauseBeforeUpgradeMinDurationSeconds >= 1 minutes &&
            _pauseBeforeUpgradeMinDurationSeconds <= 1 days, "invalid duration");
        pauseBeforeUpgradeMinDurationSeconds = _pauseBeforeUpgradeMinDurationSeconds;
    }

    function _setAvailabilityCheckProofValidity(uint256 _availabilityCheckProofValiditySeconds) internal {
        require(_availabilityCheckProofValiditySeconds >= 1 minutes &&
            _availabilityCheckProofValiditySeconds <= 1 days, "invalid duration");
        availabilityCheckProofValiditySeconds = _availabilityCheckProofValiditySeconds;
    }

    function _setAvailabilityCheckValidityDuration(uint256 _availabilityCheckValidityDurationSeconds) internal {
        require(_availabilityCheckValidityDurationSeconds >= 1 hours &&
            _availabilityCheckValidityDurationSeconds <= 365 days, "invalid duration");
        availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
    }

    function _validateAvailabilityCheckResponse(
        TeeState storage teeState,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        internal
    {
        require(_proof.data.thresholdBIPS == 0, "random threshold not supported");
        require(keccak256(bytes(_proof.data.requestBody.teeMachine.url)) == keccak256(bytes(teeState.url)),
            "url mismatch");
        require(_proof.data.requestBody.teeMachine.codeHash == teeState.codeHash, "code hash mismatch");
        require(_proof.data.requestBody.teeMachine.platform == teeState.platform, "platform mismatch");
        require(_proof.data.attestationType == TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE, "invalid attestation type");
        require(_proof.data.sourceId == TEE_SOURCE_ID, "invalid source id");
        // TODO validate proof
        // bytes32 dataHash = keccak256(abi.encode(_proof.data));
        // // 1 byte (protocolId=1), 4 bytes (votingRoundId=0), 1 byte (isSecureRandom=false), 32 bytes (dataHash)
        // bytes memory relayMessage = bytes.concat(bytes1(uint8(1)), bytes5(0), dataHash);
        // bytes32 messageHash = keccak256(relayMessage);
        // uint256 rewardEpochId = relay.verifyCustomSignature(_proof.relayMessage, messageHash);
        // uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // require(_proof.data.requestBody.rewardEpochId == rewardEpochId &&
        //     (rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId),
        //     "too old signing policy");
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs < block.timestamp, "availability check timestamp in the future");
        require(_availabilityCheckTs >= teeStates[_teeId].lastStatusChangeTs,
            "availability check timestamp too old");
        require(_availabilityCheckTs + availabilityCheckProofValiditySeconds > block.timestamp,
            "availability check validity expired");
    }

    function _checkVersionSupported(bytes32 _codeHash) internal view {
        require(codeHashToVersion[_codeHash].version >= minSupportedVersion, "version not supported");
    }

    function _isSupportedPlatform(bytes32 _platform, bytes32[] storage _platforms) internal view returns(bool) {
        for (uint256 i = 0; i < _platforms.length; i++) {
            if (_platforms[i] == _platform) {
                return true;
            }
        }
        return false;
    }

    function _getTeeVersion(address _teeId) internal view returns(uint256) {
        return codeHashToVersion[teeStates[_teeId].codeHash].version;
    }

    function _getTeeState(address _teeId) internal view returns(TeeState storage _teeState) {
        address teeId = replications[_teeId];
        _teeState = teeId != address(0) ? teeStates[teeId] : teeStates[_teeId];
        require(_teeState.owner != address(0), "tee not found");
    }

    function _getTeeMachineWithAttestationData(address _teeId, TeeState storage teeState)
        internal view
        returns(TeeMachineWithAttestationData memory)
    {
        return TeeMachineWithAttestationData({
            teeId: _teeId,
            owner: teeState.owner,
            url: teeState.url,
            codeHash: teeState.codeHash,
            platform: teeState.platform
        });
    }

    function _checkFee(
        bytes32 _opCommand,
        address _teeId
    )
        internal view
    {
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        require(msg.value >= teeFeeCalculator.calculateFeeByTeeIds(REG_OP_TYPE, _opCommand, teeIds, new address[](0)),
            "fee too low");
    }

    function _getTeeMachines(TeeMachine memory _teeMachine)
        internal pure
        returns(ITeeRegistry.TeeMachine[] memory)
    {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = _teeMachine;
        return teeMachines;
    }
}
