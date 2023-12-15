// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Finalisation.sol";
import "./Relay.sol";
import "../../governance/implementation/Governed.sol";
import "../../governance/implementation/AddressUpdatable.sol";

contract Submission is Governed, AddressUpdatable {

    Finalisation public finalisation;
    Relay public relay;
    bool public submitMethodEnabled;

    mapping(address => bool) private commitAddresses;
    mapping(address => bool) private submitAddresses;
    mapping(address => bool) private revealAddresses;
    mapping(address => bool) private signingAddresses;

    event NewVotingRoundInitiated();

    /// Only Finalisation contract can call this method.
    modifier onlyFinalisation {
        require (msg.sender == address(finalisation), "only finalisation");
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        bool _submitMethodEnabled
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        submitMethodEnabled = _submitMethodEnabled;
    }

    function initNewVotingRound(
        address[] calldata _commitSubmitAddresses,
        address[] calldata _revealAddresses,
        address[] calldata _signingAddresses
    )
        external
        onlyFinalisation
    {
        for (uint256 i = 0; i < _commitSubmitAddresses.length; i++) {
            commitAddresses[_commitSubmitAddresses[i]] = true;
        }
        if (submitMethodEnabled) {
            for (uint256 i = 0; i < _commitSubmitAddresses.length; i++) {
                submitAddresses[_commitSubmitAddresses[i]] = true;
            }
        }
        for (uint256 i = 0; i < _revealAddresses.length; i++) {
            revealAddresses[_revealAddresses[i]] = true;
        }
        for (uint256 i = 0; i < _signingAddresses.length; i++) {
            signingAddresses[_signingAddresses[i]] = true;
        }

        emit NewVotingRoundInitiated();
    }

    function commit() external returns (bool) {
        if(commitAddresses[msg.sender]) {
            delete commitAddresses[msg.sender];
            return true;
        }
        return false;
    }

    function reveal() external returns (bool) {
        if(revealAddresses[msg.sender]) {
            delete revealAddresses[msg.sender];
            return true;
        }
        return false;
    }

    function sign() external returns (bool) {
        if(signingAddresses[msg.sender]) {
            delete signingAddresses[msg.sender];
            return true;
        }
        return false;
    }

    function submit() external returns (bool) {
        if(submitAddresses[msg.sender]) {
            delete submitAddresses[msg.sender];
            return true;
        }
        return false;
    }

    function finalise(bytes calldata _data) external returns (bool) {
        /* solhint-disable avoid-low-level-calls */
        //slither-disable-next-line arbitrary-send-eth
        (bool success, bytes memory e) = address(relay).call(bytes.concat(abi.encodeWithSignature("relay()"), _data));
        /* solhint-enable avoid-low-level-calls */
        require(success, _getRevertMsg(e));

        return true;
    }

    function setSubmitMethodEnabled(bool _enabled) external onlyGovernance {
        submitMethodEnabled = _enabled;
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
        finalisation = Finalisation(_getContractAddress(_contractNameHashes, _contractAddresses, "Finalisation"));
        relay = Relay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
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
