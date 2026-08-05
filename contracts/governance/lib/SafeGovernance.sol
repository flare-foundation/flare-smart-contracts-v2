// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ISafeGovernance } from "../../userInterfaces/ISafeGovernance.sol";

/**
 * @title SafeGovernance
 * @notice The shared Safe governance action grammar: canonical hashing, action selectors,
 *         size limits and structural validators.
 * @dev Single source of truth used by BOTH sides of the pipeline — the source-chain
 *      instruction contract (`SafeInstructions`) and the target-chain consumers
 *      (`SafeGoverned` / `Relay`) — so the two can never drift apart.
 */
library SafeGovernance {

    /// A single protocol-fee update inside a `changeProtocolFees` action. `targetAddress`
    /// is the addressed consumer deployment (`address(this)` on the applying target), so
    /// several deployments on one chain are individually addressable.
    struct GovernanceFeeUpdate {
        uint256 targetChainId;
        address targetAddress;
        uint8 protocolId;       // Protocol id is a single byte in relay messages, so a fee for a
                                // protocolId > 255 is unmatchable dead state; keep it uint8.
        uint256 feeInWei;
    }

    /// A single fee-exemption update inside a `changeFeeExemptions` action: grants (or
    /// revokes) free `verify()` access for `account` on the addressed deployment of
    /// `targetChainId` (e.g. a DVN adapter).
    struct GovernanceFeeExemption {
        uint256 targetChainId;
        address targetAddress;
        address account;
        bool exempt;
    }

    /// A single fee-collection update inside a `changeFeeCollectionAddresses` action:
    /// points the addressed deployment's collected `verify()` fees at a new recipient.
    struct GovernanceFeeCollection {
        uint256 targetChainId;
        address targetAddress;
        address feeCollectionAddress;
    }

    uint256 internal constant MAX_GOVERNANCE_OWNERS = 256;
    uint256 internal constant MAX_GOVERNANCE_FEE_UPDATES = 256;
    uint256 internal constant MAX_GOVERNANCE_FEE_EXEMPTIONS = 256;
    uint256 internal constant MAX_GOVERNANCE_FEE_COLLECTIONS = 256;

    bytes32 internal constant OWNER_CONFIG_TYPEHASH = keccak256(
        "FlareRelayOwnerConfiguration(uint256 sourceChainId,address safe,"
        "uint256 safeNonce,uint256 threshold,address[] owners)"
    );

    /// The generic owner-rotation action, handled by the `SafeGoverned` base on every consumer.
    bytes4 internal constant CHANGE_OWNERS_SELECTOR =
        bytes4(keccak256("changeOwners(uint256,bytes32,uint256,address[])"));
    /// The Relay-specific protocol-fee action.
    bytes4 internal constant CHANGE_PROTOCOL_FEES_SELECTOR =
        bytes4(keccak256("changeProtocolFees(uint256,bytes32,(uint256,address,uint8,uint256)[])"));
    /// The Relay-specific verify-fee-exemption action.
    bytes4 internal constant CHANGE_FEE_EXEMPTIONS_SELECTOR =
        bytes4(keccak256("changeFeeExemptions(uint256,bytes32,(uint256,address,address,bool)[])"));
    /// The Relay-specific fee-collection-address action.
    bytes4 internal constant CHANGE_FEE_COLLECTION_SELECTOR =
        bytes4(keccak256("changeFeeCollectionAddresses(uint256,bytes32,(uint256,address,address)[])"));

    /**
     * Canonical hash of an admitted owner configuration generation.
     */
    function ownerConfigHash(
        uint256 _sourceChainId,
        address _safe,
        uint256 _safeNonce,
        uint256 _threshold,
        address[] memory _owners
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, _sourceChainId, _safe, _safeNonce, _threshold, _owners));
    }

    /**
     * Structural validation of an owner configuration: nonempty, at most
     * `MAX_GOVERNANCE_OWNERS`, nonzero addresses in strictly ascending order, and a
     * threshold in `[1, owners.length]`. Reverts `InvalidGovernanceOwnerConfiguration`.
     */
    function validateOwners(
        address[] memory _owners,
        uint256 _threshold
    )
        internal pure
    {
        require(
            _owners.length != 0 &&
            _owners.length <= MAX_GOVERNANCE_OWNERS &&
            _threshold != 0 &&
            _threshold <= _owners.length,
            ISafeGovernance.InvalidGovernanceOwnerConfiguration()
        );
        for (uint256 i; i < _owners.length; ++i) {
            require(
                _owners[i] != address(0) && (i == 0 || _owners[i - 1] < _owners[i]),
                ISafeGovernance.InvalidGovernanceOwnerConfiguration()
            );
        }
    }

    /**
     * Structural validation of a fee-update list: nonempty, at most
     * `MAX_GOVERNANCE_FEE_UPDATES`, nonzero target chain ids and addresses,
     * `protocolId > 1`, and canonical strictly-increasing
     * (targetChainId, targetAddress, protocolId) ordering (which also rules out
     * duplicates). Reverts `InvalidGovernanceTransaction`.
     */
    function validateFeeUpdates(
        GovernanceFeeUpdate[] memory _updates
    )
        internal pure
    {
        require(
            _updates.length != 0 && _updates.length <= MAX_GOVERNANCE_FEE_UPDATES,
            ISafeGovernance.InvalidGovernanceTransaction()
        );
        for (uint256 i; i < _updates.length; ++i) {
            GovernanceFeeUpdate memory update = _updates[i];
            require(
                update.targetChainId != 0 && update.targetAddress != address(0) && update.protocolId > 1,
                ISafeGovernance.InvalidGovernanceTransaction()
            );
            if (i > 0) {
                GovernanceFeeUpdate memory previous = _updates[i - 1];
                require(
                    _increases(
                        previous.targetChainId, previous.targetAddress,
                        update.targetChainId, update.targetAddress
                    ) ||
                    (
                        update.targetChainId == previous.targetChainId &&
                        update.targetAddress == previous.targetAddress &&
                        update.protocolId > previous.protocolId
                    ),
                    ISafeGovernance.InvalidGovernanceTransaction()
                );
            }
        }
    }

    /**
     * Structural validation of a fee-exemption list: nonempty, at most
     * `MAX_GOVERNANCE_FEE_EXEMPTIONS`, nonzero target chain ids, addresses and accounts,
     * and canonical strictly-increasing (targetChainId, targetAddress, account) ordering
     * (which also rules out duplicates). Reverts `InvalidGovernanceTransaction`.
     */
    function validateFeeExemptions(
        GovernanceFeeExemption[] memory _updates
    )
        internal pure
    {
        require(
            _updates.length != 0 && _updates.length <= MAX_GOVERNANCE_FEE_EXEMPTIONS,
            ISafeGovernance.InvalidGovernanceTransaction()
        );
        for (uint256 i; i < _updates.length; ++i) {
            GovernanceFeeExemption memory update = _updates[i];
            require(
                update.targetChainId != 0 && update.targetAddress != address(0) && update.account != address(0),
                ISafeGovernance.InvalidGovernanceTransaction()
            );
            if (i > 0) {
                GovernanceFeeExemption memory previous = _updates[i - 1];
                require(
                    _increases(
                        previous.targetChainId, previous.targetAddress,
                        update.targetChainId, update.targetAddress
                    ) ||
                    (
                        update.targetChainId == previous.targetChainId &&
                        update.targetAddress == previous.targetAddress &&
                        uint160(update.account) > uint160(previous.account)
                    ),
                    ISafeGovernance.InvalidGovernanceTransaction()
                );
            }
        }
    }

    /**
     * Structural validation of a fee-collection list: nonempty, at most
     * `MAX_GOVERNANCE_FEE_COLLECTIONS`, nonzero target chain ids, addresses and
     * collection addresses (a zero recipient would burn collected fees), and canonical
     * strictly-increasing (targetChainId, targetAddress) ordering (which also rules out
     * duplicates — one recipient per addressed deployment).
     * Reverts `InvalidGovernanceTransaction`.
     */
    function validateFeeCollections(
        GovernanceFeeCollection[] memory _updates
    )
        internal pure
    {
        require(
            _updates.length != 0 && _updates.length <= MAX_GOVERNANCE_FEE_COLLECTIONS,
            ISafeGovernance.InvalidGovernanceTransaction()
        );
        for (uint256 i; i < _updates.length; ++i) {
            GovernanceFeeCollection memory update = _updates[i];
            require(
                update.targetChainId != 0 &&
                update.targetAddress != address(0) &&
                update.feeCollectionAddress != address(0),
                ISafeGovernance.InvalidGovernanceTransaction()
            );
            if (i > 0) {
                GovernanceFeeCollection memory previous = _updates[i - 1];
                require(
                    _increases(
                        previous.targetChainId, previous.targetAddress,
                        update.targetChainId, update.targetAddress
                    ),
                    ISafeGovernance.InvalidGovernanceTransaction()
                );
            }
        }
    }

    /// Strict lexicographic increase on the (targetChainId, targetAddress) pair.
    function _increases(
        uint256 _previousChainId,
        address _previousAddress,
        uint256 _nextChainId,
        address _nextAddress
    )
        private pure
        returns (bool)
    {
        return _nextChainId > _previousChainId ||
            (_nextChainId == _previousChainId && uint160(_nextAddress) > uint160(_previousAddress));
    }
}
