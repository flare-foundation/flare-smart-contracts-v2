// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./TeeBase.sol";
import "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import "../../userInterfaces/tee/ITeeVersionManager.sol";
import "../../userInterfaces/tee/ITeeVerification.sol";
import "../interface/IITeeMachineRegistry.sol";
import "../../userInterfaces/tee/ITeeReplication.sol";
import "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
import "../../userInterfaces/IRelay.sol";
import "../../utils/lib/AddressSet.sol";

/**
 * TeeReplication is used for replication of TEE machines.
 */
contract TeeReplication is ITeeReplication, TeeBase {
    using AddressSet for AddressSet.State;


    bytes32 public constant REG_OP_TYPE = bytes32("F_REG");
    bytes32 public constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 public constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    /// TEE extension registry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TEE owner allowlist contract.
    ITeeOwnerAllowlist public teeOwnerAllowlist;
    /// TEE version manager contract.
    ITeeVersionManager public teeVersionManager;
    /// TEE machine registry contract.
    IITeeMachineRegistry public teeMachineRegistry;
    /// TEE verification contract.
    ITeeVerification public teeVerification;
    /// Relay contract.
    IRelay public relay;

    /// The minimum duration (in paused status) before a TEE machine can be upgraded.
    uint256 public pauseBeforeUpgradeMinDurationSeconds;

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
    constructor() TeeBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
    {
        TeeBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        _setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function toPauseForUpgrade(address _teeId)
        external payable
        onlyOwner(_teeId)
    {
        ITeeMachineRegistry.TeeStatus status = teeMachineRegistry.getTeeMachineStatus(_teeId);
        _checkTeeStatus(
            status,
            ITeeMachineRegistry.TeeStatus.PAUSED,
            ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE
        );
        if (status == ITeeMachineRegistry.TeeStatus.PAUSED) {
            require(
                teeMachineRegistry.getLastStatusChangeTs(_teeId) + pauseBeforeUpgradeMinDurationSeconds <
                block.timestamp,
                "too soon"
            );
            teeMachineRegistry.changeStatus(_teeId, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        }

        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
            _getTeeMachineWithAttestationData(_teeId);
        PauseForUpgrade memory message = PauseForUpgrade({
            teeId: _teeId,
            initialTeeId: teeMachine.initialTeeId
        });
        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, TO_PAUSE_FOR_UPGRADE, _teeId, pauseForUpgradeCounter[_teeId]++
        ));
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        _sendInstructions(
            instructionId,
            teeIds,
            TO_PAUSE_FOR_UPGRADE,
            abi.encode(message)
        );
        emit TeeMachinePausedForUpgrade(_teeId);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function replicateFrom(
        address _oldTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof,
        uint256 _teeUpgradeId
    )
        external payable
        onlyOwner(_oldTeeId)
        onlyOwner(_proof.requestBody.teeId)
    {
        address newTeeId = _proof.requestBody.teeId;
        ITeeMachineRegistry.TeeStatus oldStatus = teeMachineRegistry.getTeeMachineStatus(_oldTeeId);
        _checkTeeStatus(oldStatus, ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE);
        ITeeMachineRegistry.TeeStatus newStatus = teeMachineRegistry.getTeeMachineStatus(newTeeId);
        require(
            newStatus == ITeeMachineRegistry.TeeStatus.INITIALIZED ||
            (replications[_oldTeeId] == newTeeId && newStatus == ITeeMachineRegistry.TeeStatus.REPLICATING), // retry
            "invalid tee status"
        );
        uint256 extensionId = teeMachineRegistry.getExtensionId(_oldTeeId);
        require(extensionId == teeMachineRegistry.getExtensionId(newTeeId), "extension mismatch");
        _checkCodeHashPlatformSupported(extensionId, newTeeId);
        _checkTeeMachinesCompatible(_teeUpgradeId, extensionId, _oldTeeId, newTeeId);
        _validateAvailabilityCheckStatus(_proof.responseBody.status);
        _validateAvailabilityCheckTs(newTeeId, _proof.header.timestamp);
        require(teeVerification.verifyAvailabilityCheckProof(_proof), "invalid response data");

        replications[_oldTeeId] = newTeeId;
        teeMachineRegistry.changeStatus(newTeeId, ITeeMachineRegistry.TeeStatus.REPLICATING);

        ReplicateTeeMachine memory message = ReplicateTeeMachine({
            oldTeeMachine: _getTeeMachineWithAttestationData(_oldTeeId),
            newTeeMachine: _getTeeMachineWithAttestationData(newTeeId)
        });
        uint256 counter = replicateCounter[_oldTeeId]++;
        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, REPLICATE_FROM, _oldTeeId, newTeeId, counter
        ));
        address[] memory teeIds = new address[](2);
        teeIds[0] = _oldTeeId;
        teeIds[1] = newTeeId;
        _sendInstructions(
            instructionId,
            teeIds,
            REPLICATE_FROM,
            abi.encode(message)
        );
        emit TeeMachineReplicationTriggered(_oldTeeId, newTeeId, _teeUpgradeId);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function confirmReplicate(
        address _newTeeId,
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        onlyOwner(_proof.requestBody.teeId)
        onlyOwner(_newTeeId)
    {
        address oldTeeId = _proof.requestBody.teeId;
        // in case multiple replications are triggered only the last one can be confirmed
        require(replications[oldTeeId] == _newTeeId, "replication not valid");
        delete replications[oldTeeId];
        teeMachineRegistry.replicate(_newTeeId, _proof);
        emit TeeMachineReplicationConfirmed(oldTeeId, _newTeeId);
    }

    /**
     * Sets the minimum duration (in paused status) before a TEE machine can be upgraded.
     * @param _pauseBeforeUpgradeMinDurationSeconds The minimum duration in seconds.
     */
    function setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external onlyGovernance
    {
        _setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /**
     * @inheritdoc ITeeReplication
     */
    function getReplicatingTeeId(address _oldTeeId) external view returns(address) {
        return replications[_oldTeeId];
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
        teeExtensionRegistry = ITeeExtensionRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeExtensionRegistry"));
        teeOwnerAllowlist = ITeeOwnerAllowlist(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeOwnerAllowlist"));
        teeVersionManager = ITeeVersionManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVersionManager"));
        teeMachineRegistry = IITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeVerification = ITeeVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVerification"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }

    function _setPauseBeforeUpgradeMinDurationSeconds(
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        internal
    {
        _validateDuration(_pauseBeforeUpgradeMinDurationSeconds, 1 minutes, 1 days);
        pauseBeforeUpgradeMinDurationSeconds = _pauseBeforeUpgradeMinDurationSeconds;
        emit PauseBeforeUpgradeMinDurationSecondsSet(_pauseBeforeUpgradeMinDurationSeconds);
    }

    function _sendInstructions(
        bytes32 _instructionId,
        address[] memory _teeIds,
        bytes32 _opCommand,
        bytes memory _message
    )
        internal
    {
        uint256 extensionId = teeMachineRegistry.getExtensionId(_teeIds[0]);
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            _instructionId,
            extensionId,
            _teeIds,
            REG_OP_TYPE,
            _opCommand,
            _message
        );
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs >= teeMachineRegistry.getLastStatusChangeTs(_teeId), "AC timestamp invalid");
    }

    function _getTeeMachineWithAttestationData(address _teeId)
        internal view
        returns(ITeeMachineRegistry.TeeMachineWithAttestationData memory)
    {
        return teeMachineRegistry.getTeeMachineWithAttestationData(_teeId);
    }

    function _checkCodeHashPlatformSupported(
        uint256 _extensionId,
        address _teeId
    )
        internal view
    {
        ITeeMachineRegistry.TeeMachineWithAttestationData memory teeMachine =
            _getTeeMachineWithAttestationData(_teeId);
        require(
            teeExtensionRegistry.isCodeHashPlatformSupported(_extensionId, teeMachine.codeHash, teeMachine.platform),
            "version not supported"
        );
    }

    function _checkTeeMachinesCompatible(
        uint256 _teeUpgradeId,
        uint256 _extensionId,
        address _oldTeeId,
        address _newTeeId
    )
        internal view
    {
        ITeeMachineRegistry.TeeMachineWithAttestationData memory oldTeeMachine =
            _getTeeMachineWithAttestationData(_oldTeeId);
        ITeeMachineRegistry.TeeMachineWithAttestationData memory newTeeMachine =
            _getTeeMachineWithAttestationData(_newTeeId);
        require(
            teeVersionManager.isTeeUpgradePathValid(
                _teeUpgradeId,
                _extensionId,
                oldTeeMachine.codeHash,
                oldTeeMachine.platform,
                newTeeMachine.codeHash,
                newTeeMachine.platform
            ),
            "invalid upgrade path"
        );
        require(teeVersionManager.isTeeUpgradeSigned(_teeUpgradeId), "tee upgrade not signed");
    }

    function _checkOnlyOwner(address _teeId) internal view {
        require(msg.sender == teeMachineRegistry.getTeeMachineOwner(_teeId), "only owner");
    }

    function _checkTeeStatus(
        ITeeMachineRegistry.TeeStatus _actualStatus,
        ITeeMachineRegistry.TeeStatus _expectedStatus
    )
        internal pure
    {
        require(_actualStatus == _expectedStatus, "invalid tee status");
    }

    function _checkTeeStatus(
        ITeeMachineRegistry.TeeStatus _actualStatus,
        ITeeMachineRegistry.TeeStatus _expectedStatus1,
        ITeeMachineRegistry.TeeStatus _expectedStatus2
    )
        internal pure
    {
        require(_actualStatus == _expectedStatus1 || _actualStatus == _expectedStatus2, "invalid tee status");
    }

    function _validateAvailabilityCheckStatus(
        ITeeAvailabilityCheck.AvailabilityCheckStatus _status
    )
        internal pure
    {
        require(_status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK, "invalid AC status");
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
