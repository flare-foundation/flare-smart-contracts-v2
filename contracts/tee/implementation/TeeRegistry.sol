// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeVersionManager.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/ftdc/IFtdcVerification.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/IRelay.sol";
import "../../utils/lib/AddressSet.sol";
import "../../governance/implementation/GovernedProxyImplementation.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * TeeRegistry is used for registration of TEE machines.
 */
contract TeeRegistry is ITeeRegistry, GovernedProxyImplementation, AddressUpdatable, UUPSUpgradeable {
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

    bytes32 public constant TEE_SOURCE_ID = bytes32("TEE");
    bytes32 public constant REG_OP_TYPE = bytes32("REG");
    bytes32 public constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 public constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    /// TEE version manager contract.
    ITeeVersionManager public teeVersionManager;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare TEE data connector contract.
    IFtdcHub public ftdcHub;
    /// FTDC verification contract.
    IFtdcVerification public ftdcVerification;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Relay contract.
    IRelay public relay;

    /// The minimum duration (in paused status) before a TEE machine can be upgraded.
    uint256 public pauseBeforeUpgradeMinDurationSeconds;
    /// The duration for which an availability check proof is valid.
    uint256 public availabilityCheckProofValiditySeconds;
    /// The TEE availability check validity duration, in seconds.
    /// In order to receive rewards, TEE must be checked for availability at least once in this period.
    uint256 public availabilityCheckValidityDurationSeconds;

    /// registration availability check cosigners and their threshold
    AddressSet.State private cosigners;
    uint256 private cosignersThreshold;

    AddressSet.State private activeTeeIds;
    mapping(address teeId => TeeState) private teeStates;
    mapping(address oldTeeId => address newTeeId) public replications;
    /// Proposed new TEE owner.
    mapping(address teeId => address) public proposedTeeOwner;
    mapping(address teeId => uint256) private pauseForUpgradeCounter;
    mapping(address oldTeeId => uint256) private replicateCounter;

    modifier onlyOwner(address _teeId) {
        _checkOnlyOwner(_teeId);
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _pauseBeforeUpgradeMinDurationSeconds,
        uint256 _availabilityCheckProofValiditySeconds,
        uint256 _availabilityCheckValidityDurationSeconds
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);

        _setPauseBeforeUpgradeMinDuration(_pauseBeforeUpgradeMinDurationSeconds);
        _setAvailabilityCheckProofValidity(_availabilityCheckProofValiditySeconds);
        _setAvailabilityCheckValidityDuration(_availabilityCheckValidityDurationSeconds);
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
        _checkCodeHashPlatformSupported(_codeHash, _platform);

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
        emit TeeMachineRegistered(_teeId, msg.sender, _url, _codeHash, _platform);
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
        _checkCodeHashPlatformSupported(teeState.codeHash, teeState.platform);
        _validateAvailabilityCheckStatus(_proof.data.responseBody.status);
        _validateAvailabilityCheckTs(teeId, _proof.data.timestamp);
        _validateAvailabilityCheckProof(teeState, _proof);

        teeState.status = TeeStatus.PRODUCTION;
        uint64 endTs = uint64(_proof.data.timestamp + availabilityCheckValidityDurationSeconds);
        if (endTs > teeState.availabilityCheckValidityEndTs) {
            teeState.availabilityCheckValidityEndTs = endTs;
            emit AvailabilityCheckValidityExtended(teeId, endTs);
        }
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.add(teeId);
        emit TeeMachinePutIntoProduction(teeId);
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
        _checkTeeStatus(teeState.status, TeeStatus.PRODUCTION);
        _checkCodeHashPlatformSupported(teeState.codeHash, teeState.platform);
        _validateAvailabilityCheckStatus(_proof.data.responseBody.status);
        _validateAvailabilityCheckTs(teeId, _proof.data.timestamp);
        _validateAvailabilityCheckProof(teeState, _proof);

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
        _checkTeeStatus(teeState.status, TeeStatus.PRODUCTION);
        require(msg.sender == teeState.owner ||
            teeVersionManager.codeHashPlatformDisabled(teeState.codeHash, teeState.platform),
            "only owner or disabled version");

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.remove(_teeId);
        emit TeeMachinePaused(_teeId);
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
        _checkTeeStatus(teeState.status, TeeStatus.PRODUCTION);
        require(_proof.data.responseBody.status != ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "AC status invalid");
        _validateAvailabilityCheckTs(teeId, _proof.data.timestamp);
        _validateAvailabilityCheckProof(teeState, _proof);

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.remove(teeId);
        emit TeeMachinePaused(teeId);
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
        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, TO_PAUSE_FOR_UPGRADE, _teeId, pauseForUpgradeCounter[_teeId]++
        ));
        _sendInstructions(
            instructionId,
            _teeId,
            msg.sender,
            teeState.url,
            TO_PAUSE_FOR_UPGRADE,
            abi.encode(message)
        );
        emit TeeMachinePausedForUpgrade(_teeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof,
        uint256 _teeUpgradeId
    )
        external payable
        onlyOwner(_oldTeeId)
        onlyOwner(_proof.data.requestBody.teeMachine.teeId)
    {
        address newTeeId = _proof.data.requestBody.teeMachine.teeId;
        TeeState storage oldTeeState = teeStates[_oldTeeId];
        _checkTeeStatus(oldTeeState.status, TeeStatus.PAUSED_FOR_UPGRADE);
        TeeState storage newTeeState = teeStates[newTeeId];
        require(newTeeState.status == TeeStatus.INITIALIZED ||
            (replications[_oldTeeId] == newTeeId && newTeeState.status == TeeStatus.REPLICATING), // retry
            "invalid tee status");
        _checkCodeHashPlatformSupported(newTeeState.codeHash, newTeeState.platform);
        require(_areTeeMachinesCompatible(oldTeeState, newTeeState), "tee machines not compatible");
        _validateAvailabilityCheckStatus(_proof.data.responseBody.status);
        _validateAvailabilityCheckTs(newTeeId, _proof.data.timestamp);
        _validateAvailabilityCheckProof(newTeeState, _proof);
        _checkFee(REPLICATE_FROM, newTeeId);
        require(teeVersionManager.isTeeUpgradePathValid(
            _teeUpgradeId, oldTeeState.codeHash, oldTeeState.platform, newTeeState.codeHash, newTeeState.platform),
            "invalid upgrade path");
        require(teeVersionManager.isTeeUpgradeSigned(_teeUpgradeId), "tee upgrade not signed");

        replications[_oldTeeId] = newTeeId;
        newTeeState.status = TeeStatus.REPLICATING;
        newTeeState.lastStatusChangeTs = uint64(block.timestamp);
        ReplicateTeeMachine memory message = ReplicateTeeMachine({
            oldTeeMachine: _getTeeMachineWithAttestationData(_oldTeeId, oldTeeState),
            newTeeMachine: _getTeeMachineWithAttestationData(newTeeId, newTeeState)
        });

        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, REPLICATE_FROM, _oldTeeId, newTeeId, replicateCounter[_oldTeeId]++
        ));
        _sendInstructions(
            instructionId,
            newTeeId,
            msg.sender,
            newTeeState.url,
            REPLICATE_FROM,
            abi.encode(message)
        );
        emit TeeMachineReplicationTriggered(_oldTeeId, newTeeId, _teeUpgradeId);
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
        TeeState storage oldTeeState = teeStates[oldTeeId];
        _checkTeeStatus(oldTeeState.status, TeeStatus.PAUSED_FOR_UPGRADE);
        TeeState storage newTeeState = teeStates[_newTeeId];
        _checkTeeStatus(newTeeState.status, TeeStatus.REPLICATING);
        // in case multiple replications are triggered only the last one can be confirmed
        require(replications[oldTeeId] == _newTeeId, "replication not valid");
        _checkCodeHashPlatformSupported(newTeeState.codeHash, newTeeState.platform);

        _validateAvailabilityCheckStatus(_proof.data.responseBody.status);
        _validateAvailabilityCheckTs(_newTeeId, _proof.data.timestamp);
        _validateAvailabilityCheckProof(newTeeState, _proof);

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
        emit TeeMachineReplicationConfirmed(oldTeeId, _newTeeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function proposeNewOwner(address _teeId, address _newOwner)
        external onlyOwner(_teeId)
    {
        proposedTeeOwner[_teeId] = _newOwner;
        emit NewOwnerProposed(_teeId, msg.sender, _newOwner);
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
        emit NewOwnerConfirmed(_teeId, msg.sender);
    }

    /**
     * Sets the FTDC cosigners and their threshold used for the TEE machine registration.
     * @param _cosigners The cosigners.
     * @param _cosignersThreshold The cosigners threshold.
     */
    function setCosigners(
        address[] calldata _cosigners,
        uint256 _cosignersThreshold
    )
        external onlyGovernance
    {
        require(
            _cosigners.length >= _cosignersThreshold &&
            (_cosigners.length == 0 || _cosignersThreshold > 0),
            "invalid threshold"
        );
        for (uint256 i = 0; i < _cosigners.length; i++) {
            require(_cosigners[i] != address(0), "invalid cosigner");
            // check for duplicates
            for (uint256 j = 0; j < i; j++) {
                require(_cosigners[j] != _cosigners[i], "duplicated cosigner");
            }
        }
        cosigners.replaceAll(_cosigners);
        cosignersThreshold = _cosignersThreshold;
        emit CosignersSet(_cosigners, _cosignersThreshold);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getCosigners()
        external view
        returns(address[] memory _cosigners, uint256 _cosignersThreshold)
    {
        _cosigners = cosigners.list;
        _cosignersThreshold = cosignersThreshold;
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
        require (_count <= length, "too many");
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
    function areTeeMachinesCompatible(address _teeId1, address _teeId2)
        external view
        returns(bool)
    {
        return _areTeeMachinesCompatible(teeStates[_teeId1], teeStates[_teeId2]);
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

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. Present just to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        teeVersionManager = ITeeVersionManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVersionManager"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        ftdcHub = IFtdcHub(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcHub"));
        ftdcVerification = IFtdcVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcVerification"));
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
            teeGovernanceHash: teeVersionManager.getTeeGovernanceHash(teeState.codeHash),
            rewardEpochId: flareSystemsManager.getCurrentRewardEpochId()
        });
        address[] memory teeIds = new address[](1);
        teeIds[0] = _testOnTeeId;

        address[] memory registrationCosigners = new address[](0);
        uint256 registrationCosignersThreshold = 0;
        if (teeState.status == TeeStatus.INITIALIZED) {
            registrationCosigners = cosigners.list;
            registrationCosignersThreshold = cosignersThreshold;
        }

        ftdcHub.requestAttestation{value: msg.value}(
            0,
            0,
            teeIds,
            registrationCosigners,
            registrationCosignersThreshold,
            bytes.concat(TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE, TEE_SOURCE_ID, abi.encode(requestBody))
        );
    }

    function _setPauseBeforeUpgradeMinDuration(uint256 _pauseBeforeUpgradeMinDurationSeconds) internal {
        _validateDuration(_pauseBeforeUpgradeMinDurationSeconds, 1 minutes, 1 days);
        pauseBeforeUpgradeMinDurationSeconds = _pauseBeforeUpgradeMinDurationSeconds;
    }

    function _setAvailabilityCheckProofValidity(uint256 _availabilityCheckProofValiditySeconds) internal {
        _validateDuration(_availabilityCheckProofValiditySeconds, 1 minutes, 1 days);
        availabilityCheckProofValiditySeconds = _availabilityCheckProofValiditySeconds;
    }

    function _setAvailabilityCheckValidityDuration(uint256 _availabilityCheckValidityDurationSeconds) internal {
        _validateDuration(_availabilityCheckValidityDurationSeconds, 1 hours, 365 days);
        availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
    }

    function _validateAvailabilityCheckProof(
        TeeState storage _teeState,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        internal
    {
        require(
            _proof.data.thresholdBIPS == 0 &&
            _proof.data.attestationType == TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE &&
            _proof.data.sourceId == TEE_SOURCE_ID,
            "invalid attestation"
        );
        require(
            keccak256(bytes(_proof.data.requestBody.teeMachine.url)) == keccak256(bytes(_teeState.url)) &&
            _proof.data.requestBody.teeMachine.codeHash == _teeState.codeHash &&
            _proof.data.requestBody.teeMachine.platform == _teeState.platform &&
            _proof.data.requestBody.teeGovernanceHash == teeVersionManager.getTeeGovernanceHash(_teeState.codeHash),
            "invalid request body"
        );
        bytes32 messageHash = keccak256(abi.encode(_proof.data));
        uint256 rewardEpochId = ftdcVerification.verifySigningPolicySignatures(_proof.relayMessage, messageHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(_proof.data.requestBody.rewardEpochId == rewardEpochId &&
            (rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId),
            "too old signing policy");
        // additionally check cosigners in case of initial availability check
        if (_teeState.status == TeeStatus.INITIALIZED && cosignersThreshold > 0) {
            address[] memory registrationCosigners =
                ftdcVerification.verifyCosignerSignatures(_proof.cosignerSignatures, messageHash);
            require(registrationCosigners.length >= cosignersThreshold, "cosigners threshold not met");
            for (uint256 i = 0; i < registrationCosigners.length; i++) {
                require(cosigners.index[registrationCosigners[i]] != 0, "invalid cosigner");
            }
        }
    }

    function _sendInstructions(
        bytes32 _instructionId,
        address _teeId,
        address _owner,
        string memory _url,
        bytes32 _opCommand,
        bytes memory _message
    )
        internal
    {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = TeeMachine({ teeId: _teeId, owner: _owner, url: _url });
        teeInstructions.sendInstructions{value: msg.value}(
            _instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            _opCommand,
            _message
        );
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(
            _availabilityCheckTs < block.timestamp &&
            _availabilityCheckTs + availabilityCheckProofValiditySeconds > block.timestamp &&
            _availabilityCheckTs >= teeStates[_teeId].lastStatusChangeTs,
            "AC timestamp invalid"
        );
    }

    function _getTeeState(address _teeId) internal view returns(TeeState storage _teeState) {
        address teeId = replications[_teeId];
        _teeState = teeId != address(0) ? teeStates[teeId] : teeStates[_teeId];
        require(_teeState.owner != address(0), "tee not found");
    }

    function _getTeeMachineWithAttestationData(address _teeId, TeeState storage _teeState)
        internal view
        returns(TeeMachineWithAttestationData memory)
    {
        return TeeMachineWithAttestationData({
            teeId: _teeId,
            owner: _teeState.owner,
            url: _teeState.url,
            codeHash: _teeState.codeHash,
            platform: _teeState.platform
        });
    }

    function _checkCodeHashPlatformSupported(
        bytes32 _codeHash,
        bytes32 _platform
    )
        internal view
    {
        require(teeVersionManager.isCodeHashPlatformSupported(_codeHash, _platform),
            "version not supported");
    }

    function _areTeeMachinesCompatible(
        TeeState storage _teeState1,
        TeeState storage _teeState2
    )
        internal view
        returns(bool)
    {
        return teeVersionManager.isCodeHashPlatformSupported(_teeState1.codeHash, _teeState2.platform) &&
            teeVersionManager.isCodeHashPlatformSupported(_teeState2.codeHash, _teeState1.platform);
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

    function _checkOnlyOwner(address _teeId) internal view {
        require(msg.sender == teeStates[_teeId].owner, "only owner");
    }

    function _checkTeeStatus(TeeStatus _actualStatus, TeeStatus _expectedStatus)
        internal pure
    {
        require(_actualStatus == _expectedStatus, "invalid tee status");
    }

    function _validateAvailabilityCheckStatus(
        ITeeAvailabilityCheck.AvailabilityCheckStatus _status
    )
        internal pure
    {
        require(_status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK, "AC status invalid");
    }

    function _validateDuration(
        uint256 _duration,
        uint256 _minDuration,
        uint256 _maxDuration
    )
        internal pure
    {
        require(_minDuration <= _duration && _duration <= _maxDuration, "invalid duration");
    }
}
