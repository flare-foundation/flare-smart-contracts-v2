// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITeePayments.sol";

/**
 * TeePaymentsEVM interface.
 */
interface ITeePaymentsEVM is ITeePayments {

    struct OpTypeConstantsEVM{
        uint256 chainId;
    }

    event ChainIdSet(
        bytes32 indexed projectId,
        uint256 chainId
    );

    error OnlyProjectOwner();
    error ChainIdZero();
    error ChainIdAlreadySet();
    error ChainIdNotSet();

    /**
     * Sets the chain id for the project.
     * @param _projectId The project id.
     * @param _chainId The chain id.
     */
    function setChainId(bytes32 _projectId, uint256 _chainId)
        external;

    /**
     * Returns the chain id for the project.
     * @param _projectId The project id.
     * @return The chain id.
     */
    function getChainId(bytes32 _projectId)
        external view returns(uint256);
}