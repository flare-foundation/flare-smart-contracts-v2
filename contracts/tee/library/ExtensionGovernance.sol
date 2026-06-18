// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title ExtensionGovernance
 * @notice Library for managing TEE extension governance: per-extension signer sets and thresholds
 *         identified by a content-derived `governanceHash`.
 * @dev Uses ERC-7201 namespaced storage.
 */
library ExtensionGovernance {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct TeeGovernanceData {
        EnumerableSet.AddressSet signers;
        uint64 signersThreshold;
    }

    struct TeeExtensionGovernanceState {
        /// The latest TEE governance hash.
        bytes32 latestTeeGovernanceHash;
        mapping(bytes32 governanceHash => TeeGovernanceData) governanceHashToTeeGovernance;
    }

    /// @custom:storage-location erc7201:tee.ExtensionGovernance.State
    struct State {
        mapping(uint256 extensionId => TeeExtensionGovernanceState) extensionStates;
    }

    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 internal constant STATE_POSITION = bytes32(erc7201("tee.ExtensionGovernance.State"));

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
        returns (uint64 _threshold)
    {
        _threshold = getState().extensionStates[_extensionId]
            .governanceHashToTeeGovernance[_governanceHash].signersThreshold;
        require(_threshold > 0, ITeeCommonErrors.InvalidGovernanceHash());
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
