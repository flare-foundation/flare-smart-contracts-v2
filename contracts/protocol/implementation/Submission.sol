// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./FlareSystemManager.sol";
import "./Relay.sol";
import "../../governance/implementation/Governed.sol";
import "../../governance/implementation/AddressUpdatable.sol";

contract Submission is Governed, AddressUpdatable {

    FlareSystemManager public flareSystemManager;
    Relay public relay;
    bool public submitMethodEnabled;

    mapping(address => bool) private commitAddresses;
    mapping(address => bool) private submitAddresses;
    mapping(address => bool) private revealAddresses;
    mapping(address => bool) private depositSignaturesAddresses;

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
        bool _submitMethodEnabled
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        submitMethodEnabled = _submitMethodEnabled;
    }

    function initNewVotingRound(
        address[] calldata _commitSubmitAddresses,
        address[] calldata _revealAddresses,
        address[] calldata _depositSignaturesAddresses
    )
        external
        onlyFlareSystemManager
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

        for (uint256 i = 0; i < _depositSignaturesAddresses.length; i++) {
            depositSignaturesAddresses[_depositSignaturesAddresses[i]] = true;
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

    function depositSignatures() external returns (bool) {
        if(depositSignaturesAddresses[msg.sender]) {
            delete depositSignaturesAddresses[msg.sender];
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
        flareSystemManager = FlareSystemManager(_getContractAddress(
            _contractNameHashes, _contractAddresses, "FlareSystemManager"));
        relay = Relay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}
