// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ISafeGovernance } from "../../userInterfaces/ISafeGovernance.sol";
import { SafeGovernance } from "../lib/SafeGovernance.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title SafeGoverned
 * @notice Abstract base for contracts governed cross-chain by the Safe (the multisig
 *         formerly known as Gnosis Safe, on Flare). Inheriting exposes `processSafeMessage` and the full
 *         governance getter set; the child contributes exactly one hook,
 *         `_processGovernanceAction`, mapping app-specific action selectors to its methods.
 * @dev Holds ALL generic state in ERC-7201 namespaced storage (admitted owner mirror +
 *      threshold, owner-generation tracking, replay floor, consumed nonces) and implements:
 *      - Safe v1.3.0 EIP-712 digest reconstruction (version-pinned typehashes);
 *      - owner-signature verification: direct EIP-712 ECDSA (v = 27/28) and
 *        eth_sign-flavoured ECDSA (v = 31/32, recovered over the prefixed digest with v-4);
 *        v = 0 (EIP-1271) and v = 1 (pre-approved hash) are unverifiable cross-chain and
 *        revert; every recovered signer must be an admitted owner (strictly ascending order);
 *      - the generic `changeOwners` rotation action;
 *      - the action grammar rules: `actionNonce == SafeTx.nonce` (the SIGNED Safe nonce),
 *        replay floor,
 *        consumed-nonce set, active owner-configuration binding, monotonic high-water mark.
 *      Initializer-based (proxy-compatible); the inheriting contract calls
 *      `initializeSafeGoverned` from its own `initializer`-guarded entry point.
 */
abstract contract SafeGoverned is ISafeGovernance, Initializable {

    /// @custom:storage-location erc7201:flare.SafeGoverned.State
    struct SafeGovernedState {
        // Deployment-fixed configuration (set once in initializeSafeGoverned).
        uint256 sourceChainId;
        address safe;
        uint256 replayFloor;
        // Admitted owner mirror.
        uint256 threshold;
        address[] owners;
        bytes32 activeOwnerConfigHash;
        uint256 activeOwnerConfigSafeNonce;
        // Replay protection.
        uint256 lastSafeNonce;
        mapping(uint256 safeNonce => bool) consumedNonces;
    }

    bytes32 private constant STATE_POSITION = bytes32(erc7201("flare.SafeGoverned.State"));

    // Safe v1.3.0 EIP-712 constants. The deployed governance Safe's version must match.
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = keccak256(
        "EIP712Domain(uint256 chainId,address verifyingContract)"
    );
    bytes32 private constant SAFE_TX_TYPEHASH = keccak256(
        // solhint-disable-next-line max-line-length
        "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    );

    /**
     * @inheritdoc ISafeGovernance
     * @dev The source-chain target (`txData.to`) is covered by the Safe digest but is not part
     * of the authorization: any calldata matching a known action selector is treated as
     * governance. Acceptance proves threshold authorization, not source-chain execution.
     */
    function processSafeMessage(
        SafeTx calldata txData,
        bytes calldata signatures
    )
        external
    {
        SafeGovernedState storage state = _safeGovernedState();
        require(
            state.safe != address(0) && txData.operation == 0 && txData.value == 0,
            InvalidGovernanceTransaction()
        );
        _verifyGovernanceSignatures(state, txData, signatures);
        _processVerifiedGovernanceAction(txData.data, txData.nonce);
    }

    /**
     * @inheritdoc ISafeGovernance
     */
    function governanceSourceChainId() external view returns (uint256) {
        return _safeSourceChainId();
    }

    /**
     * @inheritdoc ISafeGovernance
     */
    function governanceSigners()
        external view
        returns (address safe, uint256 threshold, address[] memory owners)
    {
        SafeGovernedState storage state = _safeGovernedState();
        return (state.safe, state.threshold, state.owners);
    }

    /**
     * @inheritdoc ISafeGovernance
     */
    function governanceOwnerConfig()
        external view
        returns (bytes32 activeOwnerConfigHash, uint256 activeOwnerConfigSafeNonce)
    {
        SafeGovernedState storage state = _safeGovernedState();
        return (state.activeOwnerConfigHash, state.activeOwnerConfigSafeNonce);
    }

    /**
     * @inheritdoc ISafeGovernance
     */
    function governanceNonces()
        external view
        returns (uint256 replayFloor, uint256 lastGovernanceSafeNonce)
    {
        SafeGovernedState storage state = _safeGovernedState();
        return (state.replayFloor, state.lastSafeNonce);
    }

    /**
     * @inheritdoc ISafeGovernance
     */
    function governanceSafeNonceConsumed(uint256 nonce) external view returns (bool) {
        return _safeGovernedState().consumedNonces[nonce];
    }

    /**
     * Initializes the Safe governance configuration. Governance is mandatory: the full
     * configuration is validated (nonzero source network id and Safe, canonical owners,
     * threshold and nonce rules). A consumer that must ship without Safe governance simply
     * never calls this initializer — `processSafeMessage` then always reverts.
     * @param _config The governance configuration.
     */
    function initializeSafeGoverned(
        GovernanceConfig memory _config
    )
        internal virtual
        onlyInitializing
    {
        SafeGovernedState storage state = _safeGovernedState();
        state.sourceChainId = _config.sourceChainId;
        state.safe = _config.safe;
        state.threshold = _config.threshold;
        state.activeOwnerConfigSafeNonce = _config.ownerConfigSafeNonce;
        state.lastSafeNonce = _config.safeNonce;
        state.replayFloor = _config.safeNonce;
        // The Safe exists on the source chain, so target-chain deployment cannot inspect its code.
        require(_config.sourceChainId != 0 && _config.safe != address(0), InvalidGovernanceSource());
        require(_config.ownerConfigSafeNonce <= _config.safeNonce, InvalidGovernanceOwnerConfiguration());
        SafeGovernance.validateOwners(_config.owners, _config.threshold);
        for (uint256 i; i < _config.owners.length; ++i) {
            state.owners.push(_config.owners[i]);
        }
        state.activeOwnerConfigHash = SafeGovernance.ownerConfigHash(
            _config.sourceChainId,
            _config.safe,
            _config.ownerConfigSafeNonce,
            _config.threshold,
            _config.owners
        );
        emit GovernanceInitialized(
            state.activeOwnerConfigHash,
            _config.ownerConfigSafeNonce,
            _config.safeNonce,
            _config.threshold,
            _config.owners
        );
    }

    /**
     * The single app-action hook: called for every verified governance action whose selector
     * is not the generic `changeOwners`. The implementation must revert
     * `UnknownGovernanceAction(selector)` for selectors it does not support.
     * @return _relevant True if the action applied anything on this chain — only then is the
     * action nonce consumed and the high-water mark advanced, so an all-foreign action can
     * later be superseded without burning the nonce here.
     */
    function _processGovernanceAction(
        bytes4 _selector,
        bytes calldata _action
    )
        internal virtual
        returns (bool _relevant);

    /**
     * @dev Applies an action after the enclosing Safe transaction and signer set have been
     * verified. Kept separate so the state machine can be reasoned about independently of
     * the ECDSA precompile model.
     */
    function _processVerifiedGovernanceAction(
        bytes calldata _action,
        uint256 _safeTxNonce
    )
        internal
    {
        SafeGovernedState storage _state = _safeGovernedState();
        bytes4 selector = _governanceSelector(_action);
        uint256 actionNonce = _governanceActionNonce(_action);
        // The action carries the SIGNED Safe nonce (what owners see when signing) and must
        // match the transaction envelope exactly.
        require(actionNonce == _safeTxNonce, InvalidGovernanceTransaction());
        // replayFloor is the FIRST signed nonce this deployment accepts (Safe.nonce() sampled
        // at deployment == the next nonce to be signed).
        require(
            actionNonce >= _state.replayFloor,
            GovernanceNonceBeforeReplayFloor(actionNonce, _state.replayFloor)
        );
        require(!_state.consumedNonces[actionNonce], GovernanceNonceAlreadyConsumed(actionNonce));
        // Grammar rule: EVERY action binds the admitted owner configuration in its second
        // word, so signers always approve against a specific owner generation.
        bytes32 configHash = _governanceActionConfigHash(_action);
        require(
            configHash == _state.activeOwnerConfigHash,
            GovernanceOwnerHashMismatch(configHash, _state.activeOwnerConfigHash)
        );
        if (selector == SafeGovernance.CHANGE_OWNERS_SELECTOR) {
            require(
                actionNonce > _state.activeOwnerConfigSafeNonce,
                GovernanceOwnerConfigNonceNotIncreasing(actionNonce, _state.activeOwnerConfigSafeNonce)
            );
            _applyGovernanceOwners(_state, _action);
            _state.consumedNonces[actionNonce] = true;
            if (actionNonce > _state.lastSafeNonce) {
                _state.lastSafeNonce = actionNonce;
            }
        } else {
            // lastSafeNonce starts at the floor (first accepted, not yet consumed) and then
            // tracks consumed app nonces; the equal case is either the floor bootstrap
            // (allowed) or an already-consumed nonce (caught by the consumed check above).
            require(
                actionNonce >= _state.lastSafeNonce,
                GovernanceNonceNotMonotonic(actionNonce, _state.lastSafeNonce)
            );
            if (_processGovernanceAction(selector, _action)) {
                _state.consumedNonces[actionNonce] = true;
                _state.lastSafeNonce = actionNonce;
            }
        }
    }

    function _applyGovernanceOwners(
        SafeGovernedState storage _state,
        bytes calldata _action
    )
        private
    {
        (uint256 nonce, bytes32 currentHash, uint256 threshold, address[] memory owners) =
            abi.decode(_action[4:], (uint256, bytes32, uint256, address[]));
        // Exact re-encoding pins the action to the canonical ABI encoding of its fields.
        require(
            keccak256(_action) ==
            keccak256(
                abi.encodeWithSelector(SafeGovernance.CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners)
            ),
            InvalidGovernanceTransaction()
        );
        SafeGovernance.validateOwners(owners, threshold);
        bytes32 previous = _state.activeOwnerConfigHash;
        bytes32 next = SafeGovernance.ownerConfigHash(_state.sourceChainId, _state.safe, nonce, threshold, owners);
        delete _state.owners;
        for (uint256 i; i < owners.length; ++i) {
            _state.owners.push(owners[i]);
        }
        _state.threshold = threshold;
        _state.activeOwnerConfigSafeNonce = nonce;
        _state.activeOwnerConfigHash = next;
        emit GovernanceOwnerConfigUpdated(previous, next, nonce, threshold, owners);
    }

    function _verifyGovernanceSignatures(
        SafeGovernedState storage _state,
        SafeTx calldata _txData,
        bytes calldata _signatures
    )
        private view
    {
        require(_signatures.length != 0 && _signatures.length % 65 == 0, InvalidSignaturesLength());
        bytes32 digest = _safeTxDigest(_txData, _state.sourceChainId, _state.safe);
        uint256 count = _signatures.length / 65;
        address[] memory signers = new address[](count);
        for (uint256 i; i < count; ++i) {
            signers[i] = _recoverSigner(digest, _signatures[i * 65:(i + 1) * 65]);
        }
        _validateGovernanceSigners(signers);
    }

    /**
     * @dev Validates a recovered signer set against the admitted owner mirror: strictly
     * ascending order (which also rejects duplicates), every signer an admitted owner, and
     * at least threshold-many signatures. Owners and signers are both strictly ascending, so
     * a single merge scan proves membership (and bounds count <= owners.length for free).
     * Kept as a separable boundary so it can be proved independently of ECDSA recovery.
     */
    /**
     * The Safe source network id, for consumers that bind their own signing domain to it
     * (Relay's RLY-23 origin binding).
     */
    function _safeSourceChainId() internal view returns (uint256) {
        return _safeGovernedState().sourceChainId;
    }

    function _validateGovernanceSigners(address[] memory _signers) internal view {
        SafeGovernedState storage state = _safeGovernedState();
        address[] storage owners = state.owners;
        uint256 ownersLength = owners.length;
        address previous;
        uint256 ownerIndex;
        for (uint256 i; i < _signers.length; ++i) {
            address signer = _signers[i];
            require(i == 0 || signer > previous, SignersNotSorted());
            while (ownerIndex < ownersLength && owners[ownerIndex] < signer) {
                ++ownerIndex;
            }
            require(ownerIndex < ownersLength && owners[ownerIndex] == signer, UnknownSigner(signer));
            ++ownerIndex;
            previous = signer;
        }
        require(_signers.length >= state.threshold, ThresholdNotReached(_signers.length, state.threshold));
    }

    /**
     * @dev Recovers one 65-byte `{r}{s}{v}` chunk. v = 27/28: direct ECDSA over the Safe
     * digest; v = 31/32: eth_sign flavour — Safe's `checkNSignatures` semantics, recovered
     * over the EIP-191-prefixed digest with v - 4; v = 0/1: unsupported cross-chain. Any
     * other v (and high-`s`) reverts inside OpenZeppelin `ECDSA.recover`.
     */
    function _recoverSigner(
        bytes32 _digest,
        bytes calldata _signature
    )
        internal pure
        returns (address)
    {
        bytes32 r = bytes32(_signature[0:32]);
        bytes32 s = bytes32(_signature[32:64]);
        uint8 v = uint8(_signature[64]);
        require(v > 1, UnsupportedSignatureType(v));
        if (v > 30) {
            return ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(_digest), v - 4, r, s);
        }
        return ECDSA.recover(_digest, v, r, s);
    }

    /// @dev Rebuilds the exact Safe v1.3.0 EIP-712 digest the owners signed on the source chain.
    function _safeTxDigest(
        SafeTx calldata _txData,
        uint256 _chainId,
        address _safe
    )
        internal pure
        returns (bytes32)
    {
        bytes32 domain = keccak256(abi.encode(
            DOMAIN_SEPARATOR_TYPEHASH,
            _chainId,
            _safe
        ));
        bytes32 structHash = keccak256(abi.encode(
            SAFE_TX_TYPEHASH,
            _txData.to,
            _txData.value,
            keccak256(_txData.data),
            _txData.operation,
            _txData.safeTxGas,
            _txData.baseGas,
            _txData.gasPrice,
            _txData.gasToken,
            _txData.refundReceiver,
            _txData.nonce
        ));
        return keccak256(abi.encodePacked("\x19\x01", domain, structHash));
    }

    function _governanceSelector(bytes calldata _data) private pure returns (bytes4 _selector) {
        require(_data.length >= 4, InvalidGovernanceTransaction());
        _selector = bytes4(_data[:4]);
    }

    function _governanceActionNonce(bytes calldata _data) private pure returns (uint256 _actionNonce) {
        require(_data.length >= 36, InvalidGovernanceTransaction());
        _actionNonce = abi.decode(_data[4:36], (uint256));
    }

    function _governanceActionConfigHash(bytes calldata _data) private pure returns (bytes32 _configHash) {
        require(_data.length >= 68, InvalidGovernanceTransaction());
        _configHash = abi.decode(_data[36:68], (bytes32));
    }

    function _safeGovernedState() private pure returns (SafeGovernedState storage _state) {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
