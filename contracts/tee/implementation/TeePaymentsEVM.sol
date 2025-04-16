// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./TeePayments.sol";
import "../../userInterfaces/tee/ITeePaymentsEVM.sol";

/**
 * TeePaymentsEVM is a contract used for instructing TEE based wallets payments for EVM based chains.
 */
contract TeePaymentsEVM is ITeePaymentsEVM, TeePayments {

    mapping(bytes32 projectId => uint256) private projectChainId;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        TeePayments()
    { }

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _maxBatchSize,
        uint64 _maxBatchDurationSeconds,
        bytes32 _opType
    )
        external override
    {
        _initialize(
            _governanceSettings,
            _initialGovernance,
            _addressUpdater,
            _maxBatchSize,
            _maxBatchDurationSeconds,
            _opType
        );
    }

    /**
     * @inheritdoc ITeePaymentsEVM
     */
    function setChainId(bytes32 _projectId, uint256 _chainId)
        external
    {
        require(teeWalletProjectManager.getOwner(_projectId) == msg.sender, "only project owner");
        require(_chainId > 0, "chainId zero");
        require(projectChainId[_projectId] == 0, "chainId already set");
        projectChainId[_projectId] = _chainId;
        emit ChainIdSet(_projectId, _chainId);
    }

    /**
     * @inheritdoc ITeePaymentsEVM
     */
    function getChainId(bytes32 _projectId)
        external view returns(uint256)
    {
        return projectChainId[_projectId];
    }

    /**
     * @inheritdoc IITeeWalletOpTypeConstants
     */
    function getOpTypeConstants(bytes32 _walletId) external view override returns(bytes memory) {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        uint256 chainId = projectChainId[projectId];
        require(chainId > 0, "chainId not set");
        return abi.encode(ITeePaymentsEVM.OpTypeConstantsEVM(chainId));
    }
}
