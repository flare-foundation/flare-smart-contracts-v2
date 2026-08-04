// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "./FlareUpgradeableBase.sol";
import { SafeGovernance } from "../lib/SafeGovernance.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { ISafeMinimal } from "../../utils/interface/ISafeMinimal.sol";

/**
 * @title SafeInstructions
 * @notice The source-chain (Flare) contract Safe instructions are created against: the Safe's
 *         `execTransaction` targets this contract, which validates the instruction's nonce,
 *         owner configuration and structure against LIVE Safe state at creation time and
 *         emits the issuance record. Target-chain consumers (`SafeGoverned` contracts) never
 *         call it — the signed message itself is the cross-chain authorization (DR-01) —
 *         so this contract is an operational quality gate, not a trust anchor.
 * @dev Upgradeable via the Flare governed-UUPS house pattern (`FlareUpgradeableBase`):
 *      supporting a NEW instruction type for a future `SafeGoverned` consumer means
 *      upgrading this contract with the matching validation method. Shares the action
 *      grammar with all consumers through the `SafeGovernance` library. Initialization
 *      admits the Safe's live owner configuration as generation 0, so instructions can be
 *      issued immediately and no bootstrap ceremony exists; owner rotations are attested
 *      AFTER the native Safe change (see `changeOwners`), so the admitted generation is
 *      always a configuration the Safe actually had.
 */
contract SafeInstructions is FlareUpgradeableBase {

    /// The chain id instructions are validated for (the Safe source chain), sampled from
    /// the deployment chain at initialization; hash-grammar input shared with all targets.
    uint256 public sourceChainId;
    /// The governance Safe proxy address.
    address public safe;
    /// The lowest signed Safe nonce the next instruction may carry (last accepted + 1);
    /// starts at 0 so a fresh Safe's first transaction can be accepted.
    uint256 public nextSafeNonce;
    /// Hash of the currently admitted owner configuration generation.
    bytes32 public activeOwnerConfigHash;
    /// Generation ordinal of the admitted owner configuration: 0 for the configuration
    /// admitted from the live Safe at initialization, otherwise the signed Safe nonce of
    /// the rotation that installed it.
    uint256 public activeOwnerConfigSafeNonce;

    event OwnerConfigurationChanged(
        uint256 indexed safeNonce, bytes32 indexed ownerConfigHash, uint256 threshold, address[] owners
    );

    event ProtocolFeesChecked(uint256 indexed safeNonce, bytes32 indexed ownerConfigHash, uint256 updateCount);

    event FeeExemptionsChecked(uint256 indexed safeNonce, bytes32 indexed ownerConfigHash, uint256 updateCount);

    event FeeCollectionsChecked(uint256 indexed safeNonce, bytes32 indexed ownerConfigHash, uint256 updateCount);

    error OnlySafe();
    error WrongSafeNonce(uint256 supplied, uint256 actual);
    error NonMonotonicNonce();
    error OwnerConfigNonceNotIncreasing(uint256 supplied, uint256 active);
    error InvalidGovernanceSource();
    error OwnerConfigurationMismatch(bytes32 supplied, bytes32 actual);

    constructor() FlareUpgradeableBase() {}

    /**
     * Admits the Safe's LIVE owner configuration as generation 0 (the deployment
     * generation; every rotation must strictly succeed it), so instructions are issuable
     * immediately. The live read also makes a wrong-network deployment fail loudly here:
     * the Safe only has code on the source chain. The source chain id baked into the hash
     * grammar is therefore simply the deployment chain.
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _safe
    )
        external
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        require(_safe != address(0), InvalidGovernanceSource());
        sourceChainId = block.chainid;
        safe = _safe;
        address[] memory owners = ISafeMinimal(_safe).getOwners();
        uint256 threshold = ISafeMinimal(_safe).getThreshold();
        _sort(owners);
        SafeGovernance.validateOwners(owners, threshold);
        activeOwnerConfigSafeNonce = 0;
        activeOwnerConfigHash = SafeGovernance.ownerConfigHash(block.chainid, _safe, 0, threshold, owners);
        emit OwnerConfigurationChanged(0, activeOwnerConfigHash, threshold, owners);
    }

    /**
     * Attests an executed owner rotation against live Safe state. The Safe performs its
     * native owner/threshold changes FIRST; this attestation then admits EXACTLY the live
     * configuration, so the cross-chain layer can never carry a configuration the Safe
     * never had. A mistaken native change is fixed natively before attesting — nothing
     * crosses chains until the attestation.
     * @dev The attestation must be signed only by owners present in BOTH the previous and
     * the new configuration, at least max(previous threshold, new threshold) of them: the
     * Safe verifies the signatures against the new owners, while target consumers verify
     * the same bytes against their admitted previous mirror. That composition rule is
     * enforced by the targets (and preflighted by ceremony tooling) — it is not checkable
     * here, since the signatures are consumed by the Safe before this call.
     */
    function changeOwners(
        uint256 _safeNonce,
        bytes32 _currentOwnerConfigHash,
        uint256 _threshold,
        address[] calldata _owners
    )
        external
        returns (bytes32 _newHash)
    {
        require(msg.sender == safe, OnlySafe());
        // The Safe increments its nonce before the inner call, so the signed nonce of the
        // executing transaction is the live value minus one.
        uint256 actualNonce = ISafeMinimal(safe).nonce() - 1;
        require(_safeNonce == actualNonce, WrongSafeNonce(_safeNonce, actualNonce));
        require(_safeNonce >= nextSafeNonce, NonMonotonicNonce());
        // Rotations strictly succeed the generation they replace (mirrors the target rule;
        // only reachable when a fresh Safe's first transaction collides with generation 0).
        require(
            _safeNonce > activeOwnerConfigSafeNonce,
            OwnerConfigNonceNotIncreasing(_safeNonce, activeOwnerConfigSafeNonce)
        );
        // Lineage: every attestation chains off the previously admitted generation, keeping
        // the issuance record a single linear generation history.
        require(
            _currentOwnerConfigHash == activeOwnerConfigHash,
            OwnerConfigurationMismatch(_currentOwnerConfigHash, activeOwnerConfigHash)
        );
        SafeGovernance.validateOwners(_owners, _threshold);
        // Attest-after: the proposed configuration must BE the Safe's live configuration.
        _newHash = SafeGovernance.ownerConfigHash(sourceChainId, safe, _safeNonce, _threshold, _owners);
        bytes32 liveHash = _liveOwnerConfigHash(_safeNonce);
        require(_newHash == liveHash, OwnerConfigurationMismatch(_newHash, liveHash));
        nextSafeNonce = _safeNonce + 1;
        activeOwnerConfigSafeNonce = _safeNonce;
        activeOwnerConfigHash = _newHash;
        emit OwnerConfigurationChanged(_safeNonce, _newHash, _threshold, _owners);
    }

    /**
     * Source-chain check of the same fee-action calldata relayed to target chains.
     * @dev Deliberately stores no target-chain fees; target Relays extract their own updates.
     */
    function changeProtocolFees(
        uint256 _safeNonce,
        bytes32 _ownerConfigHash,
        SafeGovernance.GovernanceFeeUpdate[] calldata _updates
    )
        external
    {
        require(msg.sender == safe, OnlySafe());
        // The Safe increments its nonce before the inner call, so the signed nonce of the
        // executing transaction is the live value minus one.
        uint256 actualNonce = ISafeMinimal(safe).nonce() - 1;
        require(_safeNonce == actualNonce, WrongSafeNonce(_safeNonce, actualNonce));
        require(_safeNonce >= nextSafeNonce, NonMonotonicNonce());
        require(
            _ownerConfigHash == activeOwnerConfigHash,
            OwnerConfigurationMismatch(_ownerConfigHash, activeOwnerConfigHash)
        );
        bytes32 liveHash = _liveOwnerConfigHash(activeOwnerConfigSafeNonce);
        require(
            liveHash == activeOwnerConfigHash,
            OwnerConfigurationMismatch(liveHash, activeOwnerConfigHash)
        );
        SafeGovernance.validateFeeUpdates(_updates);
        nextSafeNonce = _safeNonce + 1;
        emit ProtocolFeesChecked(_safeNonce, _ownerConfigHash, _updates.length);
    }

    /**
     * Source-chain check of the same fee-exemption calldata relayed to target chains.
     * @dev Stores no exemptions; every target (including the source-chain Relay) extracts
     * its own updates from the relayed action.
     */
    function changeFeeExemptions(
        uint256 _safeNonce,
        bytes32 _ownerConfigHash,
        SafeGovernance.GovernanceFeeExemption[] calldata _updates
    )
        external
    {
        require(msg.sender == safe, OnlySafe());
        // The Safe increments its nonce before the inner call, so the signed nonce of the
        // executing transaction is the live value minus one.
        uint256 actualNonce = ISafeMinimal(safe).nonce() - 1;
        require(_safeNonce == actualNonce, WrongSafeNonce(_safeNonce, actualNonce));
        require(_safeNonce >= nextSafeNonce, NonMonotonicNonce());
        require(
            _ownerConfigHash == activeOwnerConfigHash,
            OwnerConfigurationMismatch(_ownerConfigHash, activeOwnerConfigHash)
        );
        bytes32 liveHash = _liveOwnerConfigHash(activeOwnerConfigSafeNonce);
        require(
            liveHash == activeOwnerConfigHash,
            OwnerConfigurationMismatch(liveHash, activeOwnerConfigHash)
        );
        SafeGovernance.validateFeeExemptions(_updates);
        nextSafeNonce = _safeNonce + 1;
        emit FeeExemptionsChecked(_safeNonce, _ownerConfigHash, _updates.length);
    }

    /**
     * Source-chain check of the same fee-collection calldata relayed to target chains.
     * @dev Stores no recipients; every addressed target extracts its own update from the
     * relayed action.
     */
    function changeFeeCollectionAddresses(
        uint256 _safeNonce,
        bytes32 _ownerConfigHash,
        SafeGovernance.GovernanceFeeCollection[] calldata _updates
    )
        external
    {
        require(msg.sender == safe, OnlySafe());
        // The Safe increments its nonce before the inner call, so the signed nonce of the
        // executing transaction is the live value minus one.
        uint256 actualNonce = ISafeMinimal(safe).nonce() - 1;
        require(_safeNonce == actualNonce, WrongSafeNonce(_safeNonce, actualNonce));
        require(_safeNonce >= nextSafeNonce, NonMonotonicNonce());
        require(
            _ownerConfigHash == activeOwnerConfigHash,
            OwnerConfigurationMismatch(_ownerConfigHash, activeOwnerConfigHash)
        );
        bytes32 liveHash = _liveOwnerConfigHash(activeOwnerConfigSafeNonce);
        require(
            liveHash == activeOwnerConfigHash,
            OwnerConfigurationMismatch(liveHash, activeOwnerConfigHash)
        );
        SafeGovernance.validateFeeCollections(_updates);
        nextSafeNonce = _safeNonce + 1;
        emit FeeCollectionsChecked(_safeNonce, _ownerConfigHash, _updates.length);
    }

    /**
     * Returns whether the admitted owner generation exactly matches the live Safe.
     * @dev Deployment tooling must require true; false identifies a rotation whose
     * attestation is still pending (the Safe changed natively, `changeOwners` not yet
     * issued).
     */
    function activeOwnerConfigurationIsLive() external view returns (bool) {
        return _liveOwnerConfigHash(activeOwnerConfigSafeNonce) == activeOwnerConfigHash;
    }

    function _liveOwnerConfigHash(uint256 _ownerConfigSafeNonce) internal view returns (bytes32) {
        address[] memory owners = ISafeMinimal(safe).getOwners();
        uint256 threshold = ISafeMinimal(safe).getThreshold();
        _sort(owners);
        SafeGovernance.validateOwners(owners, threshold);
        return SafeGovernance.ownerConfigHash(sourceChainId, safe, _ownerConfigSafeNonce, threshold, owners);
    }

    function _sort(address[] memory _values) internal pure {
        for (uint256 i = 1; i < _values.length; ++i) {
            address value = _values[i];
            uint256 j = i;
            while (j > 0 && _values[j - 1] > value) {
                _values[j] = _values[j - 1];
                --j;
            }
            _values[j] = value;
        }
    }

    /**
     * No contract-address dependencies; present to satisfy AddressUpdatable.
     */
    // solhint-disable-next-line no-empty-blocks
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {}
}
