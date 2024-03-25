// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./Governor.sol";
import "./Governed.sol";
import "./GovernorProposer.sol";
import "../interface/IIPollingFoundation.sol";


/**
 * Polling Foundation contract used for proposing and voting about governance proposals.
 */
contract PollingFoundation is IIPollingFoundation, Governor, Governed, GovernorProposer {

    /**
     * Initializes the contract with default parameters.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     * @param _proposers Array of addresses allowed to submit a proposal.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address[] memory _proposers
    )
        Governed(_governanceSettings, _initialGovernance)
        Governor(_addressUpdater)
        GovernorProposer(_proposers)
    {}

    /**
     * @inheritdoc IIPollingFoundation
     */
    function propose(
        string memory _description,
        GovernorSettingsWithoutExecParams memory _settings
    ) external returns (uint256) {
        GovernorSettings memory settings = GovernorSettings({
            accept: _settings.accept,
            votingStartTs: _settings.votingStartTs,
            votingPeriodSeconds: _settings.votingPeriodSeconds,
            vpBlockPeriodSeconds:_settings.vpBlockPeriodSeconds,
            thresholdConditionBIPS:_settings.thresholdConditionBIPS,
            majorityConditionBIPS:_settings.majorityConditionBIPS,
            executionDelaySeconds: 0,
            executionPeriodSeconds: 1 // should be > 0
        });
        return _propose(new address[](0), new uint256[](0), new bytes[](0), _description, settings);
    }

    /**
     * @inheritdoc IIPollingFoundation
     */
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description,
        GovernorSettings memory _settings
    ) external returns (uint256) {
        return _propose(_targets, _values, _calldatas, _description, _settings);
    }

    /**
     * @inheritdoc Governor
     */
    function name() public pure override returns (string memory) {
        return "PollingFoundation";
    }

    /**
     * @inheritdoc Governor
     */
    function version() public pure override returns (string memory) {
        return "2";
    }

    /**
     * @inheritdoc Governor
     */
    function _isValidProposer(address _proposer, uint256 /*_votePowerBlock*/) internal view override returns (bool) {
        return isProposer(_proposer);
    }
}
