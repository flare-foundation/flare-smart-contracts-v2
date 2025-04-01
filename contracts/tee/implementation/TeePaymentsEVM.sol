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
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _maxBatchSize,
        uint64 _maxBatchDurationSeconds,
        bytes32 _opType
    )
        TeePayments(
            _governanceSettings,
            _initialGovernance,
            _addressUpdater,
            _maxBatchSize,
            _maxBatchDurationSeconds,
            _opType
        )
    { }

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
    function getChainId(bytes32 _walletId)
        external view returns(uint256)
    {
        return projectChainId[_walletId];
    }

    /**
     * @inheritdoc IITeeWalletBaseSettings
     */
    function getBaseSettings(bytes32 _walletId) external view override returns(bytes memory) {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        uint256 chainId = projectChainId[projectId];
        require(chainId > 0, "chainId not set");
        return abi.encode(ITeePaymentsEVM.BaseSettingsEVM(chainId));
    }
}
