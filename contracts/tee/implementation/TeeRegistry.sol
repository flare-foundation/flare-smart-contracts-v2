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

    AddressSet.State private activeTeeIds;
    mapping(address teeId => TeeState) private teeStates;
    mapping(address oldTeeId => address newTeeId) public replications;
    /// Proposed new TEE owner.
    mapping(address teeId => address) public proposedTeeOwner;
    mapping(address teeId => uint256) private pauseForUpgradeCounter;
    mapping(address oldTeeId => uint256) private replicateCounter;

    modifier onlyOwner(address _teeId) {
        require(teeStates[_teeId].owner == msg.sender, "only owner");
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
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        _checkCodeHashPlatformSupported(teeState.codeHash, teeState.platform);
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
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        _checkCodeHashPlatformSupported(teeState.codeHash, teeState.platform);
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
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
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
        require(teeState.status == TeeStatus.PRODUCTION, "invalid tee status");
        require(_proof.data.responseBody.status != ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
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
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(TeeMachine({ teeId: _teeId, owner: msg.sender, url: teeState.url })),
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
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
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        TeeState storage oldTeeState = teeStates[_oldTeeId];
        require(oldTeeState.status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid old tee status");
        TeeState storage newTeeState = teeStates[newTeeId];
        require(newTeeState.status == TeeStatus.INITIALIZED ||
            (replications[_oldTeeId] == newTeeId && newTeeState.status == TeeStatus.REPLICATING), // retry
            "invalid new tee status");
        _checkCodeHashPlatformSupported(newTeeState.codeHash, newTeeState.platform);
        require(_areTeeMachinesCompatible(oldTeeState, newTeeState), "tee machines not compatible");
        _validateAvailabilityCheckTs(newTeeId, _proof.data.timestamp);
        _validateAvailabilityCheckProof(newTeeState, _proof);
        _checkFee(REPLICATE_FROM, newTeeId);
        require(teeVersionManager.isTeeUpgradePathValid(
            _teeUpgradeId, oldTeeState.codeHash, oldTeeState.platform, newTeeState.codeHash, newTeeState.platform),
            "invalid tee upgrade path");
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
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            _getTeeMachines(ITeeRegistry.TeeMachine({ teeId: newTeeId, owner: msg.sender, url: newTeeState.url })),
            flareSystemsManager.getCurrentRewardEpochId(),
            REG_OP_TYPE,
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
        require(_proof.data.responseBody.status == ITeeAvailabilityCheck.AvailabilityCheckStatus.OK,
            "invalid availability status");
        TeeState storage oldTeeState = teeStates[oldTeeId];
        require(oldTeeState.status == TeeStatus.PAUSED_FOR_UPGRADE, "invalid old tee status");
        TeeState storage newTeeState = teeStates[_newTeeId];
        require(newTeeState.status == TeeStatus.REPLICATING, "invalid new tee status");
        // in case multiple replications are triggered only the last one can be confirmed
        require(replications[oldTeeId] == _newTeeId, "replication not valid");
        _checkCodeHashPlatformSupported(newTeeState.codeHash, newTeeState.platform);

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
    function areTeeMachinesCompatible(address _teeId, address[] calldata _backupTeeIds)
        external view
        returns(bool)
    {
        TeeState storage teeState = teeStates[_teeId];
        for (uint256 i = 0; i < _backupTeeIds.length; i++) {
            if (!_areTeeMachinesCompatible(teeState, teeStates[_backupTeeIds[i]])) {
                return false;
            }
        }
        return true;
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

        ftdcHub.requestAttestation{value: msg.value}(
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

    function _validateAvailabilityCheckProof(
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
        require(_proof.data.requestBody.teeGovernanceHash == teeVersionManager.getTeeGovernanceHash(teeState.codeHash),
            "tee governance hash mismatch");
        require(_proof.data.attestationType == TEE_AVAILABILITY_CHECK_ATTESTATION_TYPE, "invalid attestation type");
        require(_proof.data.sourceId == TEE_SOURCE_ID, "invalid source id");
        uint256 rewardEpochId = ftdcVerification.verifySigningPolicySignatures(
            _proof.relayMessage,
            keccak256(abi.encode(_proof.data))
        );
        uint256 currentRewardEpochId = flareSystemsManager.getCurrentRewardEpochId();
        require(_proof.data.requestBody.rewardEpochId == rewardEpochId &&
            (rewardEpochId == currentRewardEpochId || rewardEpochId + 1 == currentRewardEpochId),
            "too old signing policy");
    }

    function _validateAvailabilityCheckTs(address _teeId, uint256 _availabilityCheckTs) internal view {
        require(_availabilityCheckTs < block.timestamp, "availability check timestamp in the future");
        require(_availabilityCheckTs >= teeStates[_teeId].lastStatusChangeTs,
            "availability check timestamp too old");
        require(_availabilityCheckTs + availabilityCheckProofValiditySeconds > block.timestamp,
            "availability check validity expired");
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

    function _checkCodeHashPlatformSupported(
        bytes32 _codeHash,
        bytes32 _platform
    )
        internal view
    {
        require(teeVersionManager.isCodeHashPlatformSupported(_codeHash, _platform),
            "code hash or platform not supported");
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

    function _getTeeMachines(TeeMachine memory _teeMachine)
        internal pure
        returns(ITeeRegistry.TeeMachine[] memory)
    {
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](1);
        teeMachines[0] = _teeMachine;
        return teeMachines;
    }
}
