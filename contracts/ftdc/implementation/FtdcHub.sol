// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/ftdc/IFtdcHub.sol";
import "../../userInterfaces/tee/ITeeFeeCalculator.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/tee/ITeeInstructions.sol";
import "../../userInterfaces/IFlareSystemsManager.sol";
import "../../userInterfaces/ftdc/IFtdcRequestFeeConfigurations.sol";

/**
 * FtdcHub is used for requesting FTDC attestations.
 */
contract FtdcHub is IFtdcHub, Governed, AddressUpdatable {

    uint256 internal constant MAX_BIPS = 1e4;
    bytes32 public constant FTDC_OP_TYPE = bytes32("FTDC");
    bytes32 public constant PROVE = bytes32("PROVE");

    /// TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// TEE fee calculator contract.
    ITeeFeeCalculator public teeFeeCalculator;
    /// TEE instructions contract.
    ITeeInstructions public teeInstructions;
    /// Flare systems manager contract.
    IFlareSystemsManager public flareSystemsManager;
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
        bytes calldata _attestationRequest
    )
        external payable
    {
        require(_thresholdBIPS == 0 || (minThresholdBIPS <= _thresholdBIPS && _thresholdBIPS <= MAX_BIPS),
            "threshold invalid");
        require(_numberOfTees == 0 || _teeIds.length == 0 || _numberOfTees == _teeIds.length,
            "numberOfTees and teeIds invalid");
        require(_cosigners.length >= _cosignersThreshold, "cosigners threshold invalid");
        if (_teeIds.length == 0) {
            if (_numberOfTees == 0) {
                _numberOfTees = defaultNumberOfTees;
            }
            _teeIds = teeRegistry.getRandomTeeIds(_numberOfTees);
        } else {
            // check tee status
            for (uint256 i = 0; i < _teeIds.length; i++) {
                require(teeRegistry.getTeeMachineStatus(_teeIds[i]) != ITeeRegistry.TeeStatus.PAUSED_FOR_UPGRADE,
                    "tee machine not available");
            }
        }
        uint256 fee = teeFeeCalculator.calculateFeeByTeeIds(FTDC_OP_TYPE, PROVE, _teeIds, new address[](0)) +
            ftdcRequestFeeConfigurations.getRequestFee(_attestationRequest);
        require(msg.value >= fee, "fee to low");
        FtdcProve memory message = FtdcProve({
            teeMachines: new ITeeRegistry.TeeMachineWithAttestationData[](_teeIds.length),
            thresholdBIPS: _thresholdBIPS,
            cosigners: _cosigners,
            cosignersThreshold: _cosignersThreshold,
            attestationRequest: _attestationRequest
        });
        ITeeRegistry.TeeMachine[] memory teeMachines = new ITeeRegistry.TeeMachine[](_teeIds.length);
        for (uint256 i = 0; i < _teeIds.length; i++) {
            message.teeMachines[i] = teeRegistry.getTeeMachineWithAttestationData(_teeIds[i]);
            teeMachines[i] = ITeeRegistry.TeeMachine({
                teeId: _teeIds[i],
                owner: message.teeMachines[i].owner,
                url: message.teeMachines[i].url
            });
        }
        bytes32 instructionId = keccak256(abi.encode(
            FTDC_OP_TYPE, PROVE, _attestationRequest, attestationRequestCounter++ // TODO
        ));
        teeInstructions.sendInstructions{value: msg.value}(
            instructionId,
            teeMachines,
            flareSystemsManager.getCurrentRewardEpochId(),
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
        teeRegistry = ITeeRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
        teeFeeCalculator = ITeeFeeCalculator(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeFeeCalculator"));
        teeInstructions = ITeeInstructions(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeeInstructions"));
        flareSystemsManager = IFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
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
