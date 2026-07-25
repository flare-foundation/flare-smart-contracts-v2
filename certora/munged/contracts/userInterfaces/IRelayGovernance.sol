// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GnosisSafeTx } from "../governance/GnosisSafeTx.sol";

interface IRelayGovernance {
    event GovernanceFeeUpdated(
        uint256 indexed targetChainId,
        uint256 indexed protocolId,
        uint256 feeInWei,
        uint256 safeNonce,
        bytes32 indexed ownerConfigHash
    );

    event GovernanceOwnerConfigUpdated(
        bytes32 indexed previousOwnerConfigHash,
        bytes32 indexed ownerConfigHash,
        uint256 safeNonce,
        uint256 threshold,
        address[] owners
    );

    error InvalidGovernanceSource();
    error InvalidGovernanceDeployment();
    error InvalidGovernanceOwnerConfiguration();
    error InvalidGovernanceTransaction();
    error InvalidGovernanceSignatures();
    error UnknownGovernanceAction(bytes4 selector);
    error GovernanceOwnerHashMismatch(bytes32 supplied, bytes32 active);
    error GovernanceNonceNotMonotonic(uint256 supplied, uint256 lastAccepted);

    function processGSSMessage(
        GnosisSafeTx.Transaction calldata txData,
        bytes calldata signatures
    ) external;

    function governanceSourceChainId() external view returns (uint256);

    function governanceSafe() external view returns (address);

    function activeOwnerConfigHash() external view returns (bytes32);

    function lastGovernanceSafeNonce() external view returns (uint256);

    function governanceThreshold() external view returns (uint256);

    function governanceOwnersLength() external view returns (uint256);

    function governanceOwner(uint256 index) external view returns (address);
}
