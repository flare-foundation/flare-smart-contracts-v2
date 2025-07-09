// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeOwnerAllowlist.sol";
import "../../userInterfaces/tee/ITeeVersionManager.sol";
import "../../userInterfaces/tee/ITeeVerification.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
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
        address initialTeeId;
        address owner;
        address teeProxyId; // address of the TEE proxy
        TeeStatus status; // 0: initialized, 1: production, 2: paused, 3: paused_for_upgrade, 4: replicating
        uint256 lastStatusChangeTs;
        bytes32 codeHash;
        bytes32 platform; // utf8 encoded
        string url;
    }

    bytes32 public constant REG_OP_TYPE = bytes32("REG");
    bytes32 public constant TO_PAUSE_FOR_UPGRADE = bytes32("TO_PAUSE_FOR_UPGRADE");
    bytes32 public constant REPLICATE_FROM = bytes32("REPLICATE_FROM");

    /// TEE owner allowlist contract.
    ITeeOwnerAllowlist public teeOwnerAllowlist;
    /// TEE version manager contract.
    ITeeVersionManager public teeVersionManager;
    /// TEE verification contract.
    ITeeVerification public teeVerification;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Relay contract.
    IRelay public relay;

    /// The minimum duration (in paused status) before a TEE machine can be upgraded.
    uint256 public pauseBeforeUpgradeMinDurationSeconds;

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
        uint256 _pauseBeforeUpgradeMinDurationSeconds
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
        _setPauseBeforeUpgradeMinDurationSeconds(_pauseBeforeUpgradeMinDurationSeconds);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function register(
        address _teeId,
        address _teeProxyId,
        string calldata _url,
        bytes32 _codeHash,
        bytes32 _platform
    )
        external payable
    {
        require(teeOwnerAllowlist.isAllowedTeeMachineOwner(msg.sender), "owner not allowed");
        require(_teeId != address(0), "invalid tee id");
        require(_teeProxyId != address(0), "invalid tee proxy id");
        require(bytes(_url).length > 0, "invalid url");
        require(teeStates[_teeId].owner == address(0), "already registered");
        _checkCodeHashPlatformSupported(_codeHash, _platform);

        teeStates[_teeId] = TeeState({
            initialTeeId: _teeId,
            owner: msg.sender,
            teeProxyId: _teeProxyId,
            status: TeeStatus.INITIALIZED,
            lastStatusChangeTs: block.timestamp,
            codeHash: _codeHash,
            platform: _platform,
            url: _url
        });

        teeVerification.requestTeeAttestation{value: msg.value}(_teeId);
        emit TeeMachineRegistered(_teeId, _teeProxyId, msg.sender, _url, _codeHash, _platform);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function toProduction(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
    {
        address teeId = _proof.requestBody.teeId;
        TeeState storage teeState = teeStates[teeId];
        TeeStatus status = teeState.status;
        require(
            status == TeeStatus.PAUSED_WITH_PROOF ||
            (status == TeeStatus.INITIALIZED || status == TeeStatus.PAUSED) && msg.sender == teeState.owner,
            "invalid tee status"
        );
        _checkCodeHashPlatformSupported(teeState.codeHash, teeState.platform);
        _validateAvailabilityCheckStatuses(_proof.responseBody.status, _proof.responseBody.machineStatus);
        _validateAvailabilityCheckTs(teeId, _proof.header.timestamp);
        require(teeVerification.verifyAvailabilityCheckProof(_proof), "invalid response data");

        teeState.status = TeeStatus.PRODUCTION;
        teeState.lastStatusChangeTs = block.timestamp;
        activeTeeIds.add(teeId);
        teeVerification.confirmAvailability(_proof);
        emit TeeMachinePutIntoProduction(teeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function pause(address _teeId)
        external
    {
        TeeState storage teeState = teeStates[_teeId];
        _checkTeeStatus(teeState.status, TeeStatus.PRODUCTION, TeeStatus.PAUSED_WITH_PROOF);
        require(
            msg.sender == teeState.owner ||
            teeVersionManager.codeHashPlatformDisabled(teeState.codeHash, teeState.platform),
            "only owner or disabled version"
        );

        teeState.status = TeeStatus.PAUSED;
        teeState.lastStatusChangeTs = block.timestamp;
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
        address teeId = _proof.requestBody.teeId;
        TeeState storage teeState = teeStates[teeId];
        _checkTeeStatus(teeState.status, TeeStatus.PRODUCTION);
        bool responseDataValid = teeVerification.verifyAvailabilityCheckProof(_proof);
        require(
            !responseDataValid ||
            _proof.responseBody.status != ITeeAvailabilityCheck.AvailabilityCheckStatus.OK ||
            _proof.responseBody.machineStatus != ITeeAvailabilityCheck.TeeMachineStatus.ACTIVE,
            "invalid response data or AC status"
        );
        _validateAvailabilityCheckTs(teeId, _proof.header.timestamp);

        teeState.status = TeeStatus.PAUSED_WITH_PROOF;
        teeState.lastStatusChangeTs = block.timestamp;
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
        _checkTeeStatus(teeState.status, TeeStatus.PAUSED, TeeStatus.PAUSED_FOR_UPGRADE);
        if (status == TeeStatus.PAUSED) {
            require(teeState.lastStatusChangeTs + pauseBeforeUpgradeMinDurationSeconds < block.timestamp, "too soon");
            teeState.status = TeeStatus.PAUSED_FOR_UPGRADE;
            teeState.lastStatusChangeTs = block.timestamp;
        }
        address[] memory teeIds = new address[](1);
        teeIds[0] = _teeId;
        _checkFee(TO_PAUSE_FOR_UPGRADE, teeIds);

        PauseForUpgrade memory message = PauseForUpgrade({
            teeId: _teeId,
            initialTeeId: teeState.initialTeeId
        });
        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, TO_PAUSE_FOR_UPGRADE, _teeId, pauseForUpgradeCounter[_teeId]++
        ));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = TeeMachine({ teeId: _teeId, teeProxyId: teeState.teeProxyId, url: teeState.url });
        _sendInstructions(
            instructionId,
            teeMachines,
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
        onlyOwner(_proof.requestBody.teeId)
    {
        address newTeeId = _proof.requestBody.teeId;
        TeeState storage oldTeeState = teeStates[_oldTeeId];
        _checkTeeStatus(oldTeeState.status, TeeStatus.PAUSED_FOR_UPGRADE);
        TeeState storage newTeeState = teeStates[newTeeId];
        require(
            newTeeState.status == TeeStatus.INITIALIZED ||
            (replications[_oldTeeId] == newTeeId && newTeeState.status == TeeStatus.REPLICATING), // retry
            "invalid tee status"
        );
        _checkCodeHashPlatformSupported(newTeeState.codeHash, newTeeState.platform);
        require(_areTeeMachinesCompatible(oldTeeState, newTeeState), "tees not compatible");
        _validateAvailabilityCheckStatuses(_proof.responseBody.status, _proof.responseBody.machineStatus);
        _validateAvailabilityCheckTs(newTeeId, _proof.header.timestamp);
        require(teeVerification.verifyAvailabilityCheckProof(_proof), "invalid response data");
        address[] memory teeIds = new address[](2);
        teeIds[0] = _oldTeeId;
        teeIds[1] = newTeeId;
        _checkFee(REPLICATE_FROM, teeIds);
        require(
            teeVersionManager.isTeeUpgradePathValid(
                _teeUpgradeId,
                oldTeeState.codeHash,
                oldTeeState.platform,
                newTeeState.codeHash,
                newTeeState.platform
            ),
            "invalid upgrade path"
        );
        require(teeVersionManager.isTeeUpgradeSigned(_teeUpgradeId), "tee upgrade not signed");

        replications[_oldTeeId] = newTeeId;
        newTeeState.status = TeeStatus.REPLICATING;
        newTeeState.lastStatusChangeTs = block.timestamp;

        ReplicateTeeMachine memory message = ReplicateTeeMachine({
            oldTeeMachine: _getTeeMachineWithAttestationData(_oldTeeId, oldTeeState),
            newTeeMachine: _getTeeMachineWithAttestationData(newTeeId, newTeeState)
        });
        uint256 counter = replicateCounter[_oldTeeId]++;
        bytes32 instructionId = keccak256(abi.encode(
            REG_OP_TYPE, REPLICATE_FROM, _oldTeeId, newTeeId, counter
        ));
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](2);
        teeMachines[0] = TeeMachine({ teeId: _oldTeeId, teeProxyId: oldTeeState.teeProxyId, url: oldTeeState.url });
        teeMachines[1] = TeeMachine({ teeId: newTeeId, teeProxyId: newTeeState.teeProxyId, url: newTeeState.url });
        _sendInstructions(
            instructionId,
            teeMachines,
            REPLICATE_FROM,
            abi.encode(message)
        );
        emit TeeMachineReplicationTriggered(_oldTeeId, newTeeId, _teeUpgradeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function confirmReplicate(
        ITeeAvailabilityCheck.Proof calldata _proof
    )
        external
        onlyOwner(_proof.requestBody.teeId)
        onlyOwner(_proof.responseBody.initialTeeId)
    {
        address oldTeeId = _proof.requestBody.teeId;
        address newTeeId = _proof.responseBody.initialTeeId;
        TeeState storage oldTeeState = teeStates[oldTeeId];
        _checkTeeStatus(oldTeeState.status, TeeStatus.PAUSED_FOR_UPGRADE);
        TeeState storage newTeeState = teeStates[newTeeId];
        _checkTeeStatus(newTeeState.status, TeeStatus.REPLICATING);
        // in case multiple replications are triggered only the last one can be confirmed
        require(replications[oldTeeId] == newTeeId, "replication not valid");
        _checkCodeHashPlatformSupported(newTeeState.codeHash, newTeeState.platform);

        _validateAvailabilityCheckStatuses(_proof.responseBody.status, _proof.responseBody.machineStatus);
        _validateAvailabilityCheckTs(newTeeId, _proof.header.timestamp);
        require(teeVerification.verifyAvailabilityCheckProof(_proof), "invalid response data");
        oldTeeState.initialTeeId = newTeeId; // same as newTeeState.initialTeeId
        oldTeeState.status = TeeStatus.PRODUCTION;
        oldTeeState.lastStatusChangeTs = block.timestamp;
        oldTeeState.teeProxyId = newTeeState.teeProxyId;
        oldTeeState.codeHash = newTeeState.codeHash;
        oldTeeState.platform = newTeeState.platform;
        oldTeeState.url = newTeeState.url;
        delete replications[oldTeeId];
        delete teeStates[newTeeId];
        activeTeeIds.add(oldTeeId);
        teeVerification.confirmAvailability(_proof);
        emit TeeMachineReplicationConfirmed(oldTeeId, newTeeId);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function proposeNewOwner(address _teeId, address _newOwner)
        external onlyOwner(_teeId)
    {
        require(
            _newOwner == address(0) || teeOwnerAllowlist.isAllowedTeeMachineOwner(_newOwner),
            "owner not allowed"
        );
        proposedTeeOwner[_teeId] = _newOwner;
        emit NewOwnerProposed(_teeId, msg.sender, _newOwner);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function confirmOwnership(address _teeId)
        external
    {
        require(teeOwnerAllowlist.isAllowedTeeMachineOwner(msg.sender), "owner not allowed");
        require(proposedTeeOwner[_teeId] == msg.sender, "only proposed owner");
        teeStates[_teeId].owner = msg.sender;
        delete proposedTeeOwner[_teeId];
        emit NewOwnerConfirmed(_teeId, msg.sender);
    }

    /**
     * @inheritdoc ITeeRegistry
     */
    function setTeeProxyId(address _teeId, address _teeProxyId)
        external onlyOwner(_teeId)
    {
        require(_teeProxyId != address(0), "invalid tee proxy id");
        TeeState storage teeState = teeStates[_teeId];
        teeState.teeProxyId = _teeProxyId;
        emit TeeProxyIdSet(_teeId, _teeProxyId);
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
    function getTeeMachineOwner(address _teeId)
        external view
        returns(address)
    {
        TeeState storage teeState = _getTeeState(_teeId);
        return teeState.owner;
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
            teeProxyId: teeState.teeProxyId,
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
    function getActiveTees()
        external view
        returns(address[] memory _teeIds, string[] memory _urls)
    {
        _teeIds = activeTeeIds.list;
        uint256 length = _teeIds.length;
        _urls = new string[](length);
        for (uint256 i = 0; i < length; i++) {
            _urls[i] = teeStates[_teeIds[i]].url;
        }
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
        teeOwnerAllowlist = ITeeOwnerAllowlist(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeOwnerAllowlist"));
        teeVersionManager = ITeeVersionManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVersionManager"));
        teeVerification = ITeeVerification(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeVerification"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
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
        ITeeRegistry.TeeMachine[] memory _teeMachines,
        bytes32 _opCommand,
        bytes memory _message
    )
        internal
    {
        teeInstructions.sendInstructions{value: msg.value}(
            _instructionId,
            _teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
            _opCommand,
            _message
        );
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs >= teeStates[_teeId].lastStatusChangeTs, "AC timestamp invalid");
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
            initialTeeId: _teeState.initialTeeId,
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
        require(teeVersionManager.isCodeHashPlatformSupported(_codeHash, _platform), "version not supported");
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
        address[] memory _teeIds
    )
        internal view
    {
        require(msg.value >= teeFeeCalculator.calculateFeeByTeeIds(REG_OP_TYPE, _opCommand, _teeIds), "fee too low");
    }

    function _checkOnlyOwner(address _teeId) internal view {
        require(msg.sender == teeStates[_teeId].owner, "only owner");
    }

    function _checkTeeStatus(TeeStatus _actualStatus, TeeStatus _expectedStatus)
        internal pure
    {
        require(_actualStatus == _expectedStatus, "invalid tee status");
    }

    function _checkTeeStatus(TeeStatus _actualStatus, TeeStatus _expectedStatus1, TeeStatus _expectedStatus2)
        internal pure
    {
        require(_actualStatus == _expectedStatus1 || _actualStatus == _expectedStatus2, "invalid tee status");
    }

    function _validateAvailabilityCheckStatuses(
        ITeeAvailabilityCheck.AvailabilityCheckStatus _status,
        ITeeAvailabilityCheck.TeeMachineStatus _machineStatus
    )
        internal pure
    {
        require(
            _status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK &&
            _machineStatus == ITeeAvailabilityCheck.TeeMachineStatus.ACTIVE,
            "invalid AC status"
        );
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
