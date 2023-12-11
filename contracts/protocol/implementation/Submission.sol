// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Finalisation.sol";
import "../../governance/implementation/Governed.sol";
import "../../governance/implementation/AddressUpdatable.sol";

contract Submission is Governed, AddressUpdatable {

    Finalisation public finalisation;
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

    function initVotingRound(
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

    function finalise(
        Finalisation.SigningPolicy calldata _signingPolicy,
        uint64 _pId,
        uint64 _votingRoundId,
        bool _quality,
        bytes32 _root,
        Finalisation.SignatureWithIndex[] calldata _signatures
    )
        external
        returns (bool)
    {
        finalisation.finalise(
            _signingPolicy,
            _pId,
            _votingRoundId,
            _quality,
            _root,
            _signatures
        );

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
    }
}
