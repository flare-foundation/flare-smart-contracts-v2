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
    constructor() TeePayments() {}

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
     * @inheritdoc ITeePayments
     */
    function getOpType() external view virtual override(ITeePayments, TeePayments) returns(bytes32) {
        return opType;
    }

    /**
     * @inheritdoc ITeeWalletProjectOpTypeConstants
     */
    function getOpTypeConstants(bytes32 _projectId) external view virtual override returns(bytes memory) {
        uint256 chainId = projectChainId[_projectId];
        require(chainId > 0, "chainId not set");
        return abi.encode(ITeePaymentsEVM.OpTypeConstantsEVM(chainId));
    }
}
