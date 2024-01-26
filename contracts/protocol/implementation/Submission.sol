// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../interface/IISubmission.sol";

/**
 * Submission contract.
 *
 * This contract is used to manage the submissions - prioritized transactions.
 */
contract Submission is Governed, AddressUpdatable, IISubmission {

    /// The FlareSystemManager contract.
    address public flareSystemManager;
    /// Indicates if the submit3 method is enabled.
    bool public submit3MethodEnabled;
    /// The contract address to call when submitAndPass is called.
    address public submitAndPassContract;
    /// The selector to call when submitAndPass is called.
    bytes4 public submitAndPassSelector;

    mapping(address => bool) private submit1Addresses;
    mapping(address => bool) private submit2Addresses;
    mapping(address => bool) private submit3Addresses;
    mapping(address => bool) private submitSignaturesAddresses;

    /// Only FlareSystemManager contract can call this method.
    modifier onlyFlareSystemManager {
        require(msg.sender == flareSystemManager, "only flare system manager");
        _;
    }

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _submit3MethodEnabled Indicates if the submit3 method is enabled.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        bool _submit3MethodEnabled
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        submit3MethodEnabled = _submit3MethodEnabled;
    }

    /**
     * @inheritdoc IISubmission
     */
    function initNewVotingRound(
        address[] memory _submit1Addresses,
        address[] memory _submit2Addresses,
        address[] memory _submit3Addresses,
        address[] memory _submitSignaturesAddresses
    )
        external
        onlyFlareSystemManager
    {
        for (uint256 i = 0; i < _submit1Addresses.length; i++) {
            submit1Addresses[_submit1Addresses[i]] = true;
        }

        for (uint256 i = 0; i < _submit2Addresses.length; i++) {
            submit2Addresses[_submit2Addresses[i]] = true;
        }

        if (submit3MethodEnabled) {
            for (uint256 i = 0; i < _submit3Addresses.length; i++) {
                submit3Addresses[_submit3Addresses[i]] = true;
            }
        }

        for (uint256 i = 0; i < _submitSignaturesAddresses.length; i++) {
            submitSignaturesAddresses[_submitSignaturesAddresses[i]] = true;
        }

        emit NewVotingRoundInitiated();
    }

    /**
     * @inheritdoc ISubmission
     */
    function submit1() external returns (bool) {
        if (submit1Addresses[msg.sender]) {
            delete submit1Addresses[msg.sender];
            return true;
        }
        return false;
    }

    /**
     * @inheritdoc ISubmission
     */
    function submit2() external returns (bool) {
        if (submit2Addresses[msg.sender]) {
            delete submit2Addresses[msg.sender];
            return true;
        }
        return false;
    }

    /**
     * @inheritdoc ISubmission
     */
    function submit3() external returns (bool) {
        if (submit3Addresses[msg.sender]) {
            delete submit3Addresses[msg.sender];
            return true;
        }
        return false;
    }

    /**
     * @inheritdoc ISubmission
     */
    function submitSignatures() external returns (bool) {
        if (submitSignaturesAddresses[msg.sender]) {
            delete submitSignaturesAddresses[msg.sender];
            return true;
        }
        return false;
    }

    /**
     * @inheritdoc ISubmission
     */
    function submitAndPass(bytes calldata _data) external returns (bool) {
        require(submitAndPassContract != address(0) && submitAndPassSelector != bytes4(0), "submitAndPass disabled");
        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, bytes memory e) = submitAndPassContract.call(bytes.concat(submitAndPassSelector, _data));
        /* solhint-enable avoid-low-level-calls */
        require(success, _getRevertMsg(e));

        return true;
    }

    /**
     * Sets the submit3 method enabled flag.
     * @param _enabled Indicates if the submit3 method is enabled.
     * @dev Only governance can call this method.
     */
    function setSubmit3MethodEnabled(bool _enabled) external onlyGovernance {
        submit3MethodEnabled = _enabled;
    }

    /**
     * Sets the submitAndPass contract and selector.
     * @param _submitAndPassContract The contract address to call when submitAndPass is called.
     * @param _submitAndPassSelector The selector to call when submitAndPass is called.
     * @dev Only governance can call this method.
     */
    function setSubmitAndPassData(
        address _submitAndPassContract,
        bytes4 _submitAndPassSelector
    )
        external onlyGovernance
    {
        submitAndPassContract = _submitAndPassContract;
        submitAndPassSelector = _submitAndPassSelector;
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
        flareSystemManager = _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager");
    }

    /**
     * @dev Returns the revert message from the returned bytes.
     * @param _returnData The returned bytes.
     * @return The revert message.
     */
    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        uint256 length = _returnData.length;
        if (length < 68) return "Transaction reverted silently";

        // solhint-disable-next-line no-inline-assembly
        assembly {
            _returnData := add(_returnData, 0x04) // Slice the signature hash
            mstore(_returnData, sub(length, 0x04)) // Set proper length
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
