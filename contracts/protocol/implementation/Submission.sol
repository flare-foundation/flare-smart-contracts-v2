// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./FlareSystemManager.sol";
import "./Relay.sol";
import "../../governance/implementation/Governed.sol";
import "../../utils/implementation/AddressUpdatable.sol";

contract Submission is Governed, AddressUpdatable {

    FlareSystemManager public flareSystemManager;
    bool public submit3MethodEnabled;
    address public submitAndPassContract;
    bytes4 public submitAndPassSelector;

    mapping(address => bool) private submit1Addresses;
    mapping(address => bool) private submit2Addresses;
    mapping(address => bool) private submit3Addresses;
    mapping(address => bool) private submitSignaturesAddresses;

    event NewVotingRoundInitiated();

    /// Only FlareSystemManager contract can call this method.
    modifier onlyFlareSystemManager {
        require(msg.sender == address(flareSystemManager), "only flare system manager");
        _;
    }

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

    function submit1() external returns (bool) {
        if (submit1Addresses[msg.sender]) {
            delete submit1Addresses[msg.sender];
            return true;
        }
        return false;
    }

    function submit2() external returns (bool) {
        if (submit2Addresses[msg.sender]) {
            delete submit2Addresses[msg.sender];
            return true;
        }
        return false;
    }

    function submit3() external returns (bool) {
        if (submit3Addresses[msg.sender]) {
            delete submit3Addresses[msg.sender];
            return true;
        }
        return false;
    }

    function submitSignatures() external returns (bool) {
        if (submitSignaturesAddresses[msg.sender]) {
            delete submitSignaturesAddresses[msg.sender];
            return true;
        }
        return false;
    }

    function submitAndPass(bytes calldata _data) external returns (bool) {
        require(submitAndPassContract != address(0) && submitAndPassSelector != bytes4(0), "submitAndPass disabled");
        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, bytes memory e) = submitAndPassContract.call(bytes.concat(submitAndPassSelector, _data));
        /* solhint-enable avoid-low-level-calls */
        require(success, _getRevertMsg(e));

        return true;
    }

    function setSubmit3MethodEnabled(bool _enabled) external onlyGovernance {
        submit3MethodEnabled = _enabled;
    }

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
        flareSystemManager = FlareSystemManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemManager"));
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
