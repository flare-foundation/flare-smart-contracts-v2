// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
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
    bytes32 public constant PAUSE_FOR_UPGRADE = bytes32("PAUSE_FOR_UPGRADE");
    bytes32 public constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    ITeeInstructions public teeInstructions;
    IFlareSystemsManager public flareSystemsManager;
    IRelay public relay;

    uint256 public minSupportedVersion;
    uint256 public latestVersion;
    uint256 public pauseBeforeUpgradeMinDurationSeconds;
    uint256 public availabilityCheckValidityDurationSeconds;

    AddressSet.State private activeTeeIds;
    mapping(address teeId => TeeState) private teeStates;
    mapping(bytes32 codeHash => TeeVersion) private codeHashPlatforms;
    mapping(uint256 version => bytes32[]) private versionOpTypes; // utf8 encoded operation types (XRP, BTC, FDC, etc.)
    mapping(address oldTeeId => address newTeeId) private replications;

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
        require(codeHashPlatforms[_codeHash].version >= minSupportedVersion, "version not supported");
        require(_isSupportedPlatform(_codeHash, _platform), "platform not supported");

        teeStates[_teeId] = TeeState({
            owner: msg.sender,
            status: TeeStatus.INITIALIZED,
            lastStatusChangeTs: uint64(block.timestamp),
            codeHash: _codeHash,
            platform: _platform,
            url: _url
        });

        _triggerAvailabilityCheck(
            TeeMachine({ teeId: _teeId, url: _url }),
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
            // use data from new tee in case of replication - old tee in status paused for upgrade
            teeState = teeStates[newTeeId];
        } else {
            teeState = teeStates[_teeId];
        }
        require(teeState.owner != address(0), "tee not found");
        TeeMachine memory teeMachine;
        if (_teeId == _testOnTeeId || (newTeeId != address(0) && newTeeId == _testOnTeeId)) {
            // testing on upgraded tee should use old tee id and new url
            teeMachine = TeeMachine({ teeId: _teeId, url: teeState.url });
        } else {
            require(teeStates[_testOnTeeId].status == TeeStatus.PRODUCTION, "invalid test tee");
            teeMachine = TeeMachine({ teeId: _testOnTeeId, url: teeStates[_testOnTeeId].url });
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
        _validateAvailabilityCheckTs(_teeId, _availabilityCheckTs);
        TeeStatus status = teeStates[_teeId].status;
        require(status == TeeStatus.INITIALIZED || status == TeeStatus.PAUSED, "invalid tee status");
        TeeState storage teeState = teeStates[_teeId];
        AvailabilityCheckResponse memory availabilityCheck = AvailabilityCheckResponse({
            teeId: _teeId,
            url: teeState.url,
            codeHash: teeState.codeHash,
            platform: teeState.platform,
            timestamp: _availabilityCheckTs,
            status: AvailabilityStatus.OK
        });
        bytes32 messageHash = keccak256(abi.encode(availabilityCheck));
        uint256 rewardEpochId = relay.verifyCustomSignature(_relayMessage, messageHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId,
            "too old signing policy");

        teeState.status = TeeStatus.PRODUCTION;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.add(_teeId);
    }

    function pause(address _teeId) external onlyOwner(_teeId) {
        require(teeStates[_teeId].status == TeeStatus.PRODUCTION, "invalid tee status");
        teeStates[_teeId].status = TeeStatus.PAUSED;
        teeStates[_teeId].lastStatusChangeTs = uint64(block.timestamp);
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
        AvailabilityCheckResponse memory availabilityCheck = AvailabilityCheckResponse({
            teeId: _teeId,
            url: teeState.url,
            codeHash: teeState.codeHash,
            platform: teeState.platform,
            timestamp: _availabilityCheckTs,
            status: _status
        });
        bytes32 messageHash = keccak256(abi.encode(availabilityCheck));
        uint256 rewardEpochId = relay.verifyCustomSignature(_relayMessage, messageHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId,
            "too old signing policy");

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = uint64(block.timestamp);
        activeTeeIds.remove(_teeId);
    }

    function toPauseForUpgrade(address _teeId)
        external payable
        onlyOwner(_teeId)
    {
        require(teeStates[_teeId].status == TeeStatus.PAUSED ||
            teeStates[_teeId].status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid tee status");
        if (teeStates[_teeId].status == TeeStatus.PAUSED) {
            require(teeStates[_teeId].lastStatusChangeTs + pauseBeforeUpgradeMinDurationSeconds < block.timestamp,
                "pause for upgrade too soon");
            teeStates[_teeId].status = TeeStatus.PAUSED_FOR_UPGRADE;
            teeStates[_teeId].lastStatusChangeTs = uint64(block.timestamp);
        }

        bytes32 instructionId = keccak256(abi.encode(PAUSE_FOR_UPGRADE, _teeId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = ITeeRegistry.TeeMachine({
            teeId: _teeId,
            url: teeStates[_teeId].url
        });
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            PAUSE_FOR_UPGRADE,
            abi.encode(_teeId)
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
        require(_getTeeVersion(_newTeeId) >= _getTeeVersion(_oldTeeId), "new tee version too old");
        _validateAvailabilityCheckTs(_newTeeId, _availabilityCheckTs);
        AvailabilityCheckResponse memory availabilityCheck = AvailabilityCheckResponse({
            teeId: _newTeeId,
            url: newTeeState.url,
            codeHash: newTeeState.codeHash,
            platform: newTeeState.platform,
            timestamp: _availabilityCheckTs,
            status: AvailabilityStatus.OK
        });
        bytes32 messageHash = keccak256(abi.encode(availabilityCheck));
        uint256 rewardEpochId = relay.verifyCustomSignature(_relayMessage, messageHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId,
            "too old signing policy");

        replications[_oldTeeId] = _newTeeId;
        newTeeState.status = TeeStatus.REPLICATING;
        newTeeState.lastStatusChangeTs = uint64(block.timestamp);
        ReplicateTeeMachine memory replicateTeeMachine = ReplicateTeeMachine({
            oldTeeMachine: _getTeeMachineWithAttestationData(_oldTeeId),
            newTeeMachine: _getTeeMachineWithAttestationData(_newTeeId)
        });
        require(_isSupportedPlatform(
            replicateTeeMachine.oldTeeMachine.codeHash, replicateTeeMachine.newTeeMachine.platform) &&
            _isSupportedPlatform(
                replicateTeeMachine.newTeeMachine.codeHash, replicateTeeMachine.oldTeeMachine.platform),
            "platforms not supported");

        bytes32 instructionId = keccak256(abi.encode(REPLICATE_FROM, _oldTeeId, _newTeeId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = ITeeRegistry.TeeMachine({
            teeId: _newTeeId,
            url: newTeeState.url
        });
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
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
        // in case multiple replications are triggered only the last one can be confirmed
        require(teeStates[_oldTeeId].status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid old tee status");
        require(teeStates[_newTeeId].status == TeeStatus.REPLICATING, "invalid new tee status");
        require(replications[_oldTeeId] == _newTeeId, "replication not valid");
        _validateAvailabilityCheckTs(_newTeeId, _availabilityCheckTs);
        AvailabilityCheckResponse memory availabilityCheck = AvailabilityCheckResponse({
            teeId: _oldTeeId,
            url: teeStates[_newTeeId].url,
            codeHash: teeStates[_newTeeId].codeHash,
            platform: teeStates[_newTeeId].platform,
            timestamp: _availabilityCheckTs,
            status: AvailabilityStatus.OK
        });

        bytes32 messageHash = keccak256(abi.encode(availabilityCheck));
        uint256 rewardEpochId = relay.verifyCustomSignature(_relayMessage, messageHash);
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId,
            "too old signing policy");

        teeStates[_oldTeeId].status = TeeStatus.PRODUCTION;
        teeStates[_oldTeeId].lastStatusChangeTs = uint64(block.timestamp);
        teeStates[_oldTeeId].codeHash = teeStates[_newTeeId].codeHash;
        teeStates[_oldTeeId].platform = teeStates[_newTeeId].platform;
        teeStates[_oldTeeId].url = teeStates[_newTeeId].url;
        delete replications[_oldTeeId];
        delete teeStates[_newTeeId];
        activeTeeIds.add(_oldTeeId);
    }

    function setPauseBeforeUpgradeMinDurationSeconds(uint256 _pauseBeforeUpgradeMinDurationSeconds)
        external
        onlyGovernance
    {
        pauseBeforeUpgradeMinDurationSeconds = _pauseBeforeUpgradeMinDurationSeconds;
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
    function isOpTypeSupported(address _teeId, bytes32 _opType) external view returns(bool) {
        bytes32[] storage opTypes = versionOpTypes[codeHashPlatforms[teeStates[_teeId].codeHash].version];
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
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
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
        AvailabilityCheckRequest memory availabilityCheckRequest = AvailabilityCheckRequest({
            teeId: _teeId,
            url: _teeUrl,
            codeHash: _codeHash,
            platform: _platform,
            timestamp: block.timestamp
        });
        bytes32 instructionId = keccak256(abi.encode(AVAILABILITY_CHECK, _teeId));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = _teeMachine;
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            AVAILABILITY_CHECK,
            abi.encode(availabilityCheckRequest)
        );
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs < block.timestamp, "availability check timestamp in the future");
        require(_availabilityCheckTs >= teeStates[_teeId].lastStatusChangeTs, "availability check timestamp too old");
        require(_availabilityCheckTs + availabilityCheckValidityDurationSeconds > block.timestamp,
            "availability check validity expired");
    }

    function _isSupportedPlatform(bytes32 _codeHash, bytes32 _platform) internal view returns(bool) {
        bytes32[] storage platforms = codeHashPlatforms[_codeHash].platforms;
        for (uint256 i = 0; i < platforms.length; i++) {
            if (platforms[i] == _platform) {
                return true;
            }
        }
        return false;
    }

    function _getTeeVersion(address _teeId) internal view returns(uint256) {
        return codeHashPlatforms[teeStates[_teeId].codeHash].version;
    }

    function _getTeeMachineWithAttestationData(address _teeId)
        internal view
        returns(TeeMachineWithAttestationData memory)
    {
        TeeState storage teeState = teeStates[_teeId];
        return TeeMachineWithAttestationData({
            teeId: _teeId,
            url: teeState.url,
            codeHash: teeState.codeHash,
            platform: teeState.platform
        });
    }
}
