// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
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
        TeeStatus status; // 0: initialized, 1: production, 2: paused, 3: paused_for_upgrade
        uint64 lastStatusChangeTs;
        bytes32 codeHash;
        bytes32 platform; // utf8 encoded
        string url;
    }

    struct TeeVersion {
        uint256 version;
        bytes32[] platforms; // utf8 encoded platform
    }

    bytes32 public constant REG_OP_TYPE = bytes32("REG");
    bytes32 public constant AVAILABILITY_CHECK = bytes32("AVAILABILITY_CHECK");
    bytes32 public constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 public constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    ITeeInstructions public teeInstructions;
    ITeeFeeCalculator public teeFeeCalculator;
    IFlareSystemsManager public flareSystemsManager;
    IRelay public relay;

    uint256 public minSupportedVersion;
    uint256 public latestVersion;
    uint256 public pauseBeforeUpgradeMinDurationSeconds;
    uint256 public availabilityCheckValidityDurationSeconds;

    AddressSet.State private activeTeeIds;
    mapping(address teeId => TeeState) private teeStates;
    mapping(bytes32 codeHash => TeeVersion) private codeHashToVersion;
    mapping(uint256 version => bytes32[]) private versionOpTypes; // utf8 encoded operation types (XRP, BTC, FDC, etc.)
    mapping(uint256 version => bytes32) private versionToCodeHash;
    mapping(address oldTeeId => address newTeeId) public replications;
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
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _pauseBeforeUpgradeMinDurationSeconds,
        uint256 _availabilityCheckValidityDurationSeconds,
        uint256 _minSupportedVersion
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_availabilityCheckValidityDurationSeconds >= 1 minutes, "invalid duration");
        require(_minSupportedVersion > 0, "invalid version");
        pauseBeforeUpgradeMinDurationSeconds = _pauseBeforeUpgradeMinDurationSeconds;
        availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
        minSupportedVersion = _minSupportedVersion;
    }

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
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: _codeHash,
            platform: _platform,
            url: _url
        });

        _triggerAvailabilityCheck(
            TeeMachine({ teeId: _teeId, owner: msg.sender, url: _url }),
            _teeId,
            _url,
            _codeHash,
            _platform
        );
    }

    function triggerAvailabilityCheck(
        address _teeId,
        address _testOnTeeId
    )
        external payable
    {
        TeeState storage teeState;
        address newTeeId = replications[_teeId];
        if (newTeeId != address(0)) {
            // use data from new tee in case of replication
            // old tee in status PAUSED_FOR_UPGRADE, new tee in status REPLICATING
            teeState = teeStates[newTeeId];
        } else {
            teeState = teeStates[_teeId];
            // there is no need to check availability for _teeId:
            // if status is PAUSED_FOR_UPGRADE and replication is not in progress, tee status cannot change
            // if status is REPLICATING => availability check should be triggered for old tee id
            TeeStatus status = teeState.status;
            require(status != TeeStatus.PAUSED_FOR_UPGRADE && status != TeeStatus.REPLICATING, "invalid tee status");
        }
        require(teeState.owner != address(0), "tee not found");
        TeeMachine memory teeMachine;
        if (_teeId == _testOnTeeId || (newTeeId != address(0) && newTeeId == _testOnTeeId)) {
            // if newTeeId != address(0) we allow testing on new tee url using old tee id to confirm replication
            // else teeState.status is not PAUSED_FOR_UPGRADE nor REPLICATING (checked above)
            teeMachine = TeeMachine({ teeId: _teeId, owner: teeState.owner, url: teeState.url });
        } else {
            TeeState storage testTeeState = teeStates[_testOnTeeId];
            require(testTeeState.owner != address(0), "test tee not found");
            // cannot test on tee in status PAUSED_FOR_UPGRADE as machine does not process requests
            // cannot test on tee in status REPLICATING as machine tee id might be changed already
            TeeStatus status = testTeeState.status;
            require(status != TeeStatus.PAUSED_FOR_UPGRADE && status != TeeStatus.REPLICATING, "invalid tee status");
            teeMachine = TeeMachine({ teeId: _testOnTeeId, owner: testTeeState.owner, url: testTeeState.url });
        }

        _triggerAvailabilityCheck(
            teeMachine,
            _teeId,
            teeState.url,
            teeState.codeHash,
            teeState.platform
        );
    }

    function toProduction(
        address _teeId,
        uint256 _availabilityCheckTs,
        bytes calldata _relayMessage
    )
        external onlyOwner(_teeId)
    {
        TeeState storage teeState = teeStates[_teeId];
        TeeStatus status = teeState.status;
        require(status == TeeStatus.INITIALIZED || status == TeeStatus.PAUSED, "invalid tee status");
        _checkVersionSupported(teeState.codeHash);
        _validateAvailabilityCheckTs(_teeId, _availabilityCheckTs);
        _validateAvailabilityCheckResponse(_teeId, teeState.url, teeState.codeHash, teeState.platform,
            _availabilityCheckTs, AvailabilityStatus.OK, _relayMessage);

        teeState.status = TeeStatus.PRODUCTION;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.add(_teeId);
    }

    function pause(address _teeId) external {
        TeeState storage teeState = teeStates[_teeId];
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
        require(msg.sender == teeState.owner || codeHashToVersion[teeState.codeHash].version < minSupportedVersion,
            "only owner or too old version");

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.remove(_teeId);
    }

    function pauseWithProof(
        address _teeId,
        AvailabilityStatus _status,
        uint256 _availabilityCheckTs,
        bytes calldata _relayMessage
    )
        external
    {
        TeeState storage teeState = teeStates[_teeId];
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
        require(_status != AvailabilityStatus.OK, "invalid availability status");
        _validateAvailabilityCheckTs(_teeId, _availabilityCheckTs);
        _validateAvailabilityCheckResponse(_teeId, teeState.url, teeState.codeHash, teeState.platform,
            _availabilityCheckTs, _status, _relayMessage);

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.remove(_teeId);
    }

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

        bytes32 instructionId = keccak256(abi.encode(TO_PAUSE_FOR_UPGRADE, _teeId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(TeeMachine({ teeId: _teeId, owner: msg.sender, url: teeState.url })),
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            TO_PAUSE_FOR_UPGRADE,
            abi.encode(PauseForUpgrade({ teeId: _teeId }))
        );
    }

    function replicateFrom(
        address _oldTeeId,
        address _newTeeId,
        uint256 _availabilityCheckTs,
        bytes calldata _relayMessage
    )
        external payable
        onlyOwner(_oldTeeId)
        onlyOwner(_newTeeId)
    {
        require(teeStates[_oldTeeId].status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid old tee status");
        TeeState storage newTeeState = teeStates[_newTeeId];
        require(newTeeState.status == TeeStatus.INITIALIZED ||
            (replications[_oldTeeId] == _newTeeId && newTeeState.status == TeeStatus.REPLICATING), // retry
            "invalid new tee status");
        _checkVersionSupported(newTeeState.codeHash);
        require(_getTeeVersion(_newTeeId) >= _getTeeVersion(_oldTeeId), "new tee version too old");
        _validateAvailabilityCheckTs(_newTeeId, _availabilityCheckTs);
        _validateAvailabilityCheckResponse(_newTeeId, newTeeState.url, newTeeState.codeHash, newTeeState.platform,
            _availabilityCheckTs, AvailabilityStatus.OK, _relayMessage);
        _checkFee(REPLICATE_FROM, _newTeeId);

        replications[_oldTeeId] = _newTeeId;
        newTeeState.status = TeeStatus.REPLICATING;
        newTeeState.lastStatusChangeTs = uint64(block.timestamp);
        ReplicateTeeMachine memory replicateTeeMachine = ReplicateTeeMachine({
            oldTeeMachine: _getTeeMachineWithAttestationData(_oldTeeId),
            newTeeMachine: _getTeeMachineWithAttestationData(_newTeeId)
        });
        require(
            _isSupportedPlatform(
                replicateTeeMachine.newTeeMachine.platform,
                codeHashToVersion[replicateTeeMachine.oldTeeMachine.codeHash].platforms
            ) &&
            _isSupportedPlatform(
                replicateTeeMachine.oldTeeMachine.platform,
                codeHashToVersion[replicateTeeMachine.newTeeMachine.codeHash].platforms
            ),
            "platforms not supported");

        bytes32 instructionId = keccak256(abi.encode(REPLICATE_FROM, _oldTeeId, _newTeeId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(ITeeRegistry.TeeMachine({ teeId: _newTeeId, owner: msg.sender, url: newTeeState.url })),
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            REPLICATE_FROM,
            abi.encode(replicateTeeMachine)
        );
    }

    function confirmReplicate(
        address _oldTeeId,
        address _newTeeId,
        uint256 _availabilityCheckTs,
        bytes calldata _relayMessage
    )
        external payable
        onlyOwner(_oldTeeId)
        onlyOwner(_newTeeId)
    {
        TeeState storage oldTeeState = teeStates[_oldTeeId];
        require(oldTeeState.status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid old tee status");
        TeeState storage newTeeState = teeStates[_newTeeId];
        require(newTeeState.status == TeeStatus.REPLICATING, "invalid new tee status");
        // in case multiple replications are triggered only the last one can be confirmed
        require(replications[_oldTeeId] == _newTeeId, "replication not valid");
        _checkVersionSupported(newTeeState.codeHash);
        _validateAvailabilityCheckTs(_newTeeId, _availabilityCheckTs);
        _validateAvailabilityCheckResponse(_oldTeeId, newTeeState.url, newTeeState.codeHash, newTeeState.platform,
            _availabilityCheckTs, AvailabilityStatus.OK, _relayMessage);

        oldTeeState.status = TeeStatus.PRODUCTION;
        oldTeeState.lastStatusChangeTs = uint64(block.timestamp);
        oldTeeState.codeHash = newTeeState.codeHash;
        oldTeeState.platform = newTeeState.platform;
        oldTeeState.url = newTeeState.url;
        delete replications[_oldTeeId];
        delete teeStates[_newTeeId];
        activeTeeIds.add(_oldTeeId);
    }

    function proposeNewOwner(address _teeId, address _newOwner)
        external onlyOwner(_teeId)
    {
        proposedTeeOwner[_teeId] = _newOwner;
    }

    function confirmOwnership(address _teeId)
        external
    {
        require(proposedTeeOwner[_teeId] == msg.sender, "only proposed owner");
        teeStates[_teeId].owner = msg.sender;
        delete proposedTeeOwner[_teeId];
    }

    function setMinSupportedVersion(uint256 _minSupportedVersion) external onlyGovernance {
        require(_minSupportedVersion > minSupportedVersion && _minSupportedVersion <= latestVersion,
            "invalid version");
        minSupportedVersion = _minSupportedVersion;
    }

    function addNewTeeVersion(
        uint256 _version,
        bytes32 _codeHash,
        bytes32[] calldata _platforms, // utf8 encoded platforms
        bytes32[] calldata _opTypes // utf8 encoded operation types (XRP, BTC, FDC, etc.)
    )
        external onlyGovernance
    {
        require(_version > latestVersion, "version too old");
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

    function setPauseBeforeUpgradeMinDurationSeconds(uint256 _pauseBeforeUpgradeMinDurationSeconds)
        external
        onlyGovernance
    {
        pauseBeforeUpgradeMinDurationSeconds = _pauseBeforeUpgradeMinDurationSeconds;
    }

    function setAvailabilityCheckValidityDurationSeconds(uint256 _availabilityCheckValidityDurationSeconds)
        external
        onlyGovernance
    {
        require(_availabilityCheckValidityDurationSeconds >= 1 minutes, "invalid duration");
        availabilityCheckValidityDurationSeconds = _availabilityCheckValidityDurationSeconds;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachineStatus(address _teeId) external view returns(TeeStatus) {
        return teeStates[_teeId].status;
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachine(address _teeId) external view returns(TeeMachine memory _teeMachine) {
        TeeState storage teeState = teeStates[_teeId];
        _teeMachine = TeeMachine({
            teeId: _teeId,
            owner: teeState.owner,
            url: teeState.url
        });
        require(bytes(_teeMachine.url).length > 0, "tee not found");
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function getTeeMachineWithAttestationData(address _teeId)
        external view returns(TeeMachineWithAttestationData memory _teeMachine)
    {
        _teeMachine = _getTeeMachineWithAttestationData(_teeId);
        require(bytes(_teeMachine.url).length > 0, "tee not found");
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function arePlatformsCompatible(address _teeId, address[] calldata _backupTeeIds)
        external view returns(bool)
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

    function getTeeMachineVersion(address _teeId) external view returns(uint256 _version) {
        _version = _getTeeVersion(_teeId);
        require(_version != 0, "tee not found");
    }

    function getActiveTeeIds() external view returns(address[] memory) {
        return activeTeeIds.list;
    }

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

    function getCodeHashVersion(bytes32 _codeHash) external view returns(uint256 _version) {
        _version = codeHashToVersion[_codeHash].version;
        require(_version != 0, "invalid code hash");
    }
    /**
     * @inheritdoc ITeeRegistry
     */
    function isOpTypeSupported(address _teeId, bytes32 _opType) external view returns(bool) {
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
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _triggerAvailabilityCheck(
        ITeeRegistry.TeeMachine memory _teeMachine,
        address _teeId,
        string memory _teeUrl,
        bytes32 _codeHash,
        bytes32 _platform
    )
        internal
    {
        _checkFee(AVAILABILITY_CHECK, _teeMachine.teeId);
        AvailabilityCheckRequest memory availabilityCheckRequest = AvailabilityCheckRequest({
            teeId: _teeId,
            url: _teeUrl,
            codeHash: _codeHash,
            platform: _platform,
            timestamp: block.timestamp
        });
        bytes32 instructionId = keccak256(abi.encode(AVAILABILITY_CHECK, _teeId));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(_teeMachine),
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            AVAILABILITY_CHECK,
            abi.encode(availabilityCheckRequest)
        );
    }

    function _validateAvailabilityCheckResponse(
        address _teeId,
        string memory _teeUrl,
        bytes32 _codeHash,
        bytes32 _platform,
        uint256 _availabilityCheckTs,
        AvailabilityStatus _status,
        bytes memory _relayMessage
    )
        internal
    {
        AvailabilityCheckResponse memory availabilityCheckResponse = AvailabilityCheckResponse({
            teeId: _teeId,
            url: _teeUrl,
            codeHash: _codeHash,
            platform: _platform,
            timestamp: _availabilityCheckTs,
            status: _status
        });
        bytes32 messageHash = keccak256(abi.encode(availabilityCheckResponse));
        uint256 rewardEpochId = relay.verifyCustomSignature(_relayMessage, messageHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId,
            "too old signing policy");
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs < block.timestamp, "availability check timestamp in the future");
        require(_availabilityCheckTs >= teeStates[_teeId].lastStatusChangeTs, "availability check timestamp too old");
        require(_availabilityCheckTs + availabilityCheckValidityDurationSeconds > block.timestamp,
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

    function _getTeeMachineWithAttestationData(address _teeId)
        internal view
        returns(TeeMachineWithAttestationData memory)
    {
        TeeState storage teeState = teeStates[_teeId];
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
