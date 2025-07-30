// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/tee/ITeeMachineRegistry.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../protocol/interface/IIRewardManager.sol";
import "../../userInterfaces/ftdc/IFtdcRequestFeeConfigurations.sol";

/**
 * FtdcHub is used for requesting FTDC attestations.
 */
contract FtdcHub is IFtdcHub, Governed, AddressUpdatable {

    uint256 internal constant MAX_BIPS = 1e4;
    bytes32 public constant FTDC_OP_TYPE = bytes32("F_FTDC");
    bytes32 public constant PROVE = bytes32("PROVE");

    /// TEE machine registry contract.
    ITeeMachineRegistry public teeMachineRegistry;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
    /// Reward manager contract.
    IIRewardManager public rewardManager;
    /// FTDC request fee configurations contract.
    IFtdcRequestFeeConfigurations public ftdcRequestFeeConfigurations;

    /// The minimum threshold in BIPS.
    uint16 public minThresholdBIPS;
    /// The default number of TEEs used for attestation.
    uint8 public defaultNumberOfTees;

    uint256 private attestationRequestCounter;

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
        uint16 _minThresholdBIPS,
        uint8 _defaultNumberOfTees
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        _setMinThresholdBIPS(_minThresholdBIPS);
        _setDefaultNumberOfTees(_defaultNumberOfTees);
    }

    /**
     * @inheritdoc IFtdcHub
     */
    function requestAttestation(
        uint16 _thresholdBIPS,
        uint256 _numberOfTees,
        address[] memory _teeIds,
        address[] memory _cosigners,
        uint64 _cosignersThreshold,
        bytes32 _attestationType,
        bytes32 _sourceId,
        bytes calldata _requestBody
    )
        external payable
    {
        require(
            _thresholdBIPS == 0 || (minThresholdBIPS <= _thresholdBIPS && _thresholdBIPS <= MAX_BIPS),
            "threshold invalid"
        );
        require(
            _numberOfTees == 0 || _teeIds.length == 0 || _numberOfTees == _teeIds.length,
            "numberOfTees and teeIds invalid"
        );
        require(_cosigners.length >= _cosignersThreshold, "cosigners threshold invalid");
        require(_thresholdBIPS == 0 || _thresholdBIPS >= MAX_BIPS / 2 ||
            _cosignersThreshold > _cosigners.length / 2, "multiple responses possible");
        if (_teeIds.length == 0) {
            if (_numberOfTees == 0) {
                _numberOfTees = defaultNumberOfTees;
            }
            _teeIds = teeMachineRegistry.getRandomTeeIds(0, _numberOfTees);
            // all random tee machines are in PRODUCTION status, so we don't need to check their status
        } else {
            // Check that the TEE machines are not paused for upgrade.
            for (uint256 i = 0; i < _teeIds.length; i++) {
                require(
                    teeMachineRegistry.getTeeMachineStatus(_teeIds[i]) !=
                        ITeeMachineRegistry.TeeStatus.PAUSED_FOR_UPGRADE,
                    "tee machine not available"
                );
            }
        }
        // Send the fee to the reward manager.
        uint256 fee = ftdcRequestFeeConfigurations.getTypeAndSourceFee(_attestationType, _sourceId);
        require(msg.value >= fee, "fee to low");
        //slither-disable-next-line arbitrary-send-eth
        rewardManager.receiveRewards{value: fee}(flareSystemsManager.getCurrentRewardEpochId(), false);
        // Create the attestation request message.
        FtdcAttestationRequest memory message = FtdcAttestationRequest({
            header: FtdcRequestHeader({
                attestationType: _attestationType,
                sourceId: _sourceId,
                thresholdBIPS: _thresholdBIPS,
                cosigners: _cosigners,
                cosignersThreshold: _cosignersThreshold
            }),
            requestBody: _requestBody
        });
        bytes32 instructionId = keccak256(abi.encode(
            FTDC_OP_TYPE, PROVE, attestationRequestCounter++ // TODO
        ));
        teeInstructions.sendInstructions{value: msg.value - fee}(
            instructionId,
            _teeIds,
            FTDC_OP_TYPE,
            PROVE,
            abi.encode(message)
        );
    }

    /**
     * Sets the minimum threshold in BIPS.
     * @param _minThresholdBIPS The minimum threshold in BIPS.
     * Can only be called by the governance.
     */
    function setMinThresholdBIPS(uint16 _minThresholdBIPS) external onlyGovernance {
        _setMinThresholdBIPS(_minThresholdBIPS);
    }

    /**
     * Sets the default number of TEEs used for attestation.
     * @param _defaultNumberOfTees The default number of TEEs.
     * Can only be called by the governance.
     */
    function setDefaultNumberOfTees(uint8 _defaultNumberOfTees) external onlyGovernance {
        _setDefaultNumberOfTees(_defaultNumberOfTees);
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
        teeMachineRegistry = ITeeMachineRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeMachineRegistry"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        rewardManager = IIRewardManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "RewardManager"));
        ftdcRequestFeeConfigurations = IFtdcRequestFeeConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtdcRequestFeeConfigurations"));
    }

    function _setMinThresholdBIPS(uint16 _minThresholdBIPS) internal {
        require(0 < _minThresholdBIPS && _minThresholdBIPS <= MAX_BIPS, "min threshold invalid");
        minThresholdBIPS = _minThresholdBIPS;
        emit MinThresholdBIPSSet(_minThresholdBIPS);
    }

    function _setDefaultNumberOfTees(uint8 _defaultNumberOfTees) internal {
        require(_defaultNumberOfTees > 0, "default number of tees zero");
        defaultNumberOfTees = _defaultNumberOfTees;
        emit DefaultNumberOfTeesSet(_defaultNumberOfTees);
    }
}
