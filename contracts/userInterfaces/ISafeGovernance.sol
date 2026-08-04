// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * Generic interface of contracts governed by the Safe.
 *
 * Safe = the Safe (formerly Gnosis Safe) v1.3.0 (`GnosisSafeL2`) multisig on Flare acting
 * as the governance authority. Owners sign ONE Safe transaction on the source chain; relayers
 * carry the transaction data and its owner signatures to every `SafeGoverned` contract
 * (including the one on the source chain), each of which independently verifies the threshold
 * signatures against its own admitted owner mirror and applies the action locally.
 *
 * Governance action grammar: every action is calldata of the form
 * `selector ‖ abi.encode(safeNonce, ownerConfigHash, …payload)` — the first two words after
 * the selector are ALWAYS the SIGNED Safe nonce (equal to the transaction envelope nonce,
 * i.e. what owners see when signing) and the admitted owner-configuration hash the signers
 * approved under. `changeOwners` is the one generic action handled by the
 * `SafeGoverned` base itself; all other selectors are dispatched to the inheriting contract.
 */
interface ISafeGovernance {

    /// Mirror of the Safe v1.3.0 transaction struct (field order = SafeTx typehash order).
    struct SafeTx {
        address to;
        uint256 value;
        bytes data;
        uint8 operation;      // 0 = CALL, 1 = DELEGATECALL
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
    }

    /// Safe governance deployment configuration. Governance is mandatory: every field is
    /// validated at initialization (a consumer that must ship without governance simply
    /// never runs the initializer). The source network id doubles as the consumer's
    /// signing-domain source and must be explicit and nonzero — no own-chain defaulting.
    struct GovernanceConfig {
        uint256 sourceChainId;          // Network id the Safe lives on (must be explicit, nonzero)
        address safe;                   // The Safe proxy address on the source chain
        uint256 threshold;              // Admitted signature threshold
        address[] owners;               // Admitted owners, strictly ascending
        uint256 ownerConfigSafeNonce;   // Safe nonce of the admitted owner generation
        uint256 safeNonce;              // Safe.nonce() at deployment: first accepted signed nonce
    }

    event GovernanceInitialized(
        bytes32 indexed ownerConfigHash,
        uint256 ownerConfigSafeNonce,
        uint256 replayFloor,
        uint256 threshold,
        address[] owners
    );

    event GovernanceOwnerConfigUpdated(
        bytes32 indexed previousOwnerConfigHash,
        bytes32 indexed ownerConfigHash,
        uint256 safeNonce,
        uint256 threshold,
        address[] owners
    );

    // Signature verification errors.
    error InvalidSignaturesLength();          // not a non-zero multiple of 65 bytes
    error UnsupportedSignatureType(uint8 v);  // v == 0 (EIP-1271) or v == 1 (pre-approved hash)
    error SignersNotSorted();                 // recovered signers not strictly ascending (also duplicates)
    error UnknownSigner(address signer);      // a recovered signer is not an admitted owner
    error ThresholdNotReached(uint256 validSigners, uint256 threshold);

    // Governance state-machine errors.
    error InvalidGovernanceSource();
    error InvalidGovernanceOwnerConfiguration();
    error InvalidGovernanceTransaction();
    error UnknownGovernanceAction(bytes4 selector);
    error GovernanceOwnerHashMismatch(bytes32 supplied, bytes32 active);
    error GovernanceNonceNotMonotonic(uint256 supplied, uint256 lastAccepted);
    error GovernanceNonceBeforeReplayFloor(uint256 supplied, uint256 replayFloor);
    error GovernanceNonceAlreadyConsumed(uint256 supplied);
    error GovernanceOwnerConfigNonceNotIncreasing(uint256 supplied, uint256 active);

    /**
     * Verifies a Safe transaction signed for the source chain and applies its local action.
     * @param txData The complete Safe transaction as signed by the owners.
     * @param signatures Concatenated 65-byte `{r}{s}{v}` owner signatures, strictly ascending
     * by recovered signer address. Supported types: direct EIP-712 ECDSA (v = 27/28) and
     * eth_sign-flavoured ECDSA (v = 31/32). EIP-1271 (v = 0) and pre-approved hashes (v = 1)
     * are not verifiable cross-chain; relayers must strip such chunks (and any non-owner
     * signatures) and canonicalize high-`s` values before submitting.
     */
    function processSafeMessage(
        SafeTx calldata txData,
        bytes calldata signatures
    ) external;

    /// Returns the Safe source network id.
    function governanceSourceChainId() external view returns (uint256);

    /// Returns the admitted signer set: the Safe address, threshold and owner mirror.
    function governanceSigners()
        external view
        returns (address safe, uint256 threshold, address[] memory owners);

    /// Returns the identity of the admitted owner generation: its canonical hash and the
    /// Safe nonce it was installed at.
    function governanceOwnerConfig()
        external view
        returns (bytes32 activeOwnerConfigHash, uint256 activeOwnerConfigSafeNonce);

    /// Returns the replay bookkeeping: the first accepted signed nonce (the deployment-time
    /// floor) and the high-water mark of locally applied app actions.
    function governanceNonces()
        external view
        returns (uint256 replayFloor, uint256 lastGovernanceSafeNonce);

    /// Returns whether a Safe nonce has already applied an action on this contract.
    function governanceSafeNonceConsumed(uint256 nonce) external view returns (bool);
}
