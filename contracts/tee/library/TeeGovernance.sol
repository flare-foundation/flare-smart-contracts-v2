// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";

/**
 * @title TeeGovernance
 * @notice Library for managing TEE extension governance.
 * @dev Uses ERC-7201 namespaced storage.
 */
library TeeGovernance {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TeeGovernanceData {
        EnumerableSet.AddressSet signers;
        uint64 signersThreshold;
    }

    struct TeePausingAddressesState {
        EnumerableSet.AddressSet pausingAddresses;
        bytes32 pausingAddressesHash;
        mapping(address => bool) signers;
        Signature[] signatures;
    }

    struct TeeExtensionState {
        /// Next nonce for pausing addresses.
        uint256 nextPausingAddressesNonce;
        mapping(uint256 nonce => TeePausingAddressesState) nonceToTeePausingAddresses;
        mapping(address signer => bool) teePausingAddressesSigner;
        /// The latest TEE governance hash.
        bytes32 latestTeeGovernanceHash;
        mapping(bytes32 governanceHash => TeeGovernanceData) governanceHashToTeeGovernance;
    }

    /// @custom:storage-location erc7201:tee.TeeGovernance.State
    struct State {
        mapping(uint256 extensionId => TeeExtensionState) extensionStates;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.TeeGovernance.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function getLatestTeeGovernanceHash(
        uint256 _extensionId
    )
        internal view
        returns (bytes32)
    {
        return getState().extensionStates[_extensionId].latestTeeGovernanceHash;
    }

    function isGovernanceHashValid(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        internal view
        returns (bool)
    {
        return getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].signersThreshold > 0;
    }

    function isTeeGovernanceSigner(
        uint256 _extensionId,
        bytes32 _governanceHash,
        address _signer
    )
        internal view
        returns (bool)
    {
        return getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].signers.contains(_signer);
    }

    function getTeeGovernanceThreshold(
        uint256 _extensionId,
        bytes32 _governanceHash
    )
        internal view
        returns (uint64)
    {
        return getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].signersThreshold;
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
