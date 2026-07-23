// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Relay } from "../../../../contracts/protocol/implementation/Relay.sol";
import { RelayMainDeployed } from "../../../../contracts/mock/RelayMainDeployed.sol";
import { IRelay } from "../../../../contracts/userInterfaces/IRelay.sol";
import { IIRelay } from "../../../../contracts/protocol/interface/IIRelay.sol";
import { RelayTestBase } from "./Relay.t.sol";

// RLY-23: chain-domain binding. The signing-policy hash the contract stores/verifies and the
// digest voters sign both commit to the chain id (keccak256(chainid ‖ hash)), read at runtime
// via the CHAINID opcode. These tests pin the security property that motivated the change —
// a quorum's signatures minted for one network are inert on another network's Relay even under
// a fully overlapping voter set — plus the two deliberate design commitments:
//   - same-chain redeployments still accept the same consensus messages (old→new Relay migration),
//   - a chain-id-changing fork fails closed ("Signing policy hash mismatch") until redeployment.
contract RelayChainDomainTest is RelayTestBase {
    uint256 internal constant FLARE_CHAIN_ID = 14;
    uint256 internal constant SONGBIRD_CHAIN_ID = 19;

    bytes internal policy;

    function setUp() public override {
        super.setUp();
        policy = _buildSigningPolicy(REWARD_EPOCH_ID, START_VOTING_ROUND_ID, THRESHOLD, SEED);
    }

    // Deploys a pure-relay Relay whose initial policy hash is bound to the CURRENT block.chainid
    // (the helper reads it at call time), with the shared voter set.
    function _deployRelay() internal returns (Relay) {
        return new Relay(_initialConfig(_signingPolicyHash(policy)), address(0), IRelay(address(0)));
    }

    // relay() calldata for a Mode-2 non-random message; digest bound to the CURRENT block.chainid.
    function _msgRelay(uint8 pid, uint32 vrid, bytes32 root, uint256 numSigners)
        internal view returns (bytes memory)
    {
        bytes memory message = _protocolMessage(pid, vrid, false, root);
        return abi.encodePacked(
            Relay.relay.selector, policy, message, _signatures(_ethSignedHash(message), _firstK(numSigners))
        );
    }

    // bubbles the inner relay() revert data so vm.expectRevert can match the exact reason
    function relayTo(Relay r, bytes calldata rm) external {
        (bool ok, bytes memory ret) = address(r).call(rm);
        if (!ok) {
            assembly { revert(add(ret, 0x20), mload(ret)) }
        }
    }

    function relayToLegacy(RelayMainDeployed r, bytes calldata rm) external {
        (bool ok, bytes memory ret) = address(r).call(rm);
        if (!ok) {
            assembly { revert(add(ret, 0x20), mload(ret)) }
        }
    }

    function _legacySignedHash(bytes memory content) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(content)));
    }

    function _legacyPolicyRelay(bytes memory oldPolicy, bytes memory newPolicy)
        internal view returns (bytes memory)
    {
        return abi.encodePacked(
            RelayMainDeployed.relay.selector,
            oldPolicy,
            uint8(0),
            newPolicy,
            _signatures(_legacySignedHash(newPolicy), _firstK(3))
        );
    }

    function _policyStruct(uint24 epoch, uint32 startVotingRoundId)
        internal view returns (IIRelay.SigningPolicy memory sp)
    {
        sp.rewardEpochId = epoch;
        sp.startVotingRoundId = startVotingRoundId;
        sp.threshold = THRESHOLD;
        sp.seed = SEED;
        sp.voters = voters;
        sp.weights = weights;
    }

    function _legacyMessageRelay(bytes memory signerPolicy, uint32 votingRoundId, bytes32 root)
        internal view returns (bytes memory)
    {
        bytes memory message = _protocolMessage(3, votingRoundId, false, root);
        return abi.encodePacked(
            RelayMainDeployed.relay.selector,
            signerPolicy,
            message,
            _signatures(_legacySignedHash(message), _firstK(3))
        );
    }

    function _chainBoundMessageRelay(bytes memory signerPolicy, uint32 votingRoundId, bytes32 root)
        internal view returns (bytes memory)
    {
        bytes memory message = _protocolMessage(3, votingRoundId, false, root);
        return abi.encodePacked(
            Relay.relay.selector,
            signerPolicy,
            message,
            _signatures(_ethSignedHash(message), _firstK(3))
        );
    }

    function _chainBoundPolicyRelay(bytes memory currentPolicy, bytes memory newPolicy)
        internal view returns (bytes memory)
    {
        bytes32 signedHash = _chainBound(_signingPolicyContentHash(newPolicy));
        signedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", signedHash));
        return abi.encodePacked(
            Relay.relay.selector,
            currentPolicy,
            uint8(0),
            newPolicy,
            _signatures(signedHash, _firstK(3))
        );
    }

    // The stored hash is exactly keccak256(chainid ‖ contentHash): checked via a setter-mode
    // relay (so both the setSigningPolicy return value and the getter are observable).
    function test_storedPolicyHash_isChainBound() public {
        IRelay.RelayInitialConfig memory cfg = _initialConfig(bytes32(uint256(1)));
        cfg.initialRewardEpochId = 0; // setSigningPolicy requires lastInitialized + 1 == rewardEpochId
        Relay setterRelay = new Relay(cfg, address(this), IRelay(address(0)));

        IIRelay.SigningPolicy memory sp;
        sp.rewardEpochId = REWARD_EPOCH_ID;
        sp.startVotingRoundId = START_VOTING_ROUND_ID;
        sp.threshold = THRESHOLD;
        sp.seed = SEED;
        sp.voters = voters;
        sp.weights = weights;

        bytes32 contentHash = _signingPolicyContentHash(policy);
        bytes32 stored = setterRelay.setSigningPolicy(sp);
        assertEq(stored, keccak256(abi.encodePacked(block.chainid, contentHash)), "not keccak(chainid || content)");
        assertTrue(stored != contentHash, "stored hash must not be the bare content hash");
        assertEq(setterRelay.toSigningPolicyHash(REWARD_EPOCH_ID), stored, "getter disagrees with stored hash");
    }

    // The core RLY-23 property: a message finalized on Flare is rejected by a Songbird Relay
    // carrying the SAME voter set — the signatures recover to non-voters under the other domain.
    function test_crossChain_message_rejected() public {
        vm.chainId(FLARE_CHAIN_ID);
        Relay flareRelay = _deployRelay();
        bytes memory rm = _msgRelay(3, START_VOTING_ROUND_ID, keccak256("root"), 3); // 300 > 260
        (bool ok,) = address(flareRelay).call(rm);
        assertTrue(ok, "flare relay should accept");
        assertTrue(flareRelay.isFinalized(3, START_VOTING_ROUND_ID), "flare not finalized");

        vm.chainId(SONGBIRD_CHAIN_ID);
        Relay songbirdRelay = _deployRelay(); // identical (fully overlapping) voter set
        vm.expectRevert("Wrong signature");
        this.relayTo(songbirdRelay, rm);
        assertFalse(songbirdRelay.isFinalized(3, START_VOTING_ROUND_ID), "songbird must not finalize");
    }

    // Same property for Mode-1: a signing-policy rotation quorum for Flare cannot rotate the
    // policy on a Songbird Relay with the same voters.
    function test_crossChain_policyRotation_rejected() public {
        vm.chainId(FLARE_CHAIN_ID);
        Relay flareRelay = _deployRelay();
        bytes memory policy2 = _buildSigningPolicy(
            uint24(REWARD_EPOCH_ID + 1), START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION, THRESHOLD, SEED
        );
        bytes32 signedHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _signingPolicyHash(policy2)));
        bytes memory rm =
            abi.encodePacked(Relay.relay.selector, policy, uint8(0), policy2, _signatures(signedHash, _firstK(3)));
        (bool ok,) = address(flareRelay).call(rm);
        assertTrue(ok, "flare rotation should succeed");
        (uint32 lastEpoch,) = flareRelay.lastInitializedRewardEpochData();
        assertEq(lastEpoch, REWARD_EPOCH_ID + 1, "flare epoch not advanced");

        vm.chainId(SONGBIRD_CHAIN_ID);
        Relay songbirdRelay = _deployRelay();
        // The submitted current policy re-hashes consistently under Songbird's domain (content is
        // identical), so the gate reached is the signature check — which fails under the new domain.
        vm.expectRevert("Wrong signature");
        this.relayTo(songbirdRelay, rm);
        (uint32 sbEpoch,) = songbirdRelay.lastInitializedRewardEpochData();
        assertEq(sbEpoch, REWARD_EPOCH_ID, "songbird epoch must not advance");
    }

    // verifyCustomSignature (T1-b): the cross-CHAIN half of the third-party replay residual is
    // closed — the same relay message is rejected by an identical-policy Relay on another chain.
    function test_crossChain_customSignature_rejected() public {
        vm.chainId(FLARE_CHAIN_ID);
        Relay flareRelay = _deployRelay();
        bytes32 mh = keccak256("app-action");
        bytes memory rm = _customSigRelayMessage(policy, mh, 3);
        assertEq(flareRelay.verifyCustomSignature(rm, mh), REWARD_EPOCH_ID, "flare custom-sig should verify");

        vm.chainId(SONGBIRD_CHAIN_ID);
        Relay songbirdRelay = _deployRelay();
        vm.expectRevert("Verification failed");
        songbirdRelay.verifyCustomSignature(rm, mh);
    }

    // Old-format (unbound) signatures — prefixed(keccak(message)) without the chain wrap — are
    // dead on the new contract: the format break is total, in both directions.
    function test_unboundSignatures_rejected() public {
        bytes memory message = _protocolMessage(3, START_VOTING_ROUND_ID, false, keccak256("root"));
        bytes32 oldFormatDigest =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(message)));
        bytes memory rm = abi.encodePacked(
            Relay.relay.selector, policy, message, _signatures(oldFormatDigest, _firstK(3))
        );
        vm.expectRevert("Wrong signature");
        this.relayTo(relay, rm);
    }

    // Deliberate non-goal: two Relays on the SAME chain accept the same consensus message — this
    // preserves the old→new Relay migration flow (finalizers submit identical calldata to both).
    function test_sameChain_secondDeployment_accepts() public {
        Relay second = _deployRelay(); // same chain id as the setUp relay
        bytes memory rm = _msgRelay(3, START_VOTING_ROUND_ID, keccak256("root"), 3);
        (bool ok1,) = address(relay).call(rm);
        (bool ok2,) = address(second).call(rm);
        assertTrue(ok1, "first deployment should accept");
        assertTrue(ok2, "second deployment should accept the same message");
        assertTrue(relay.isFinalized(3, START_VOTING_ROUND_ID) && second.isFinalized(3, START_VOTING_ROUND_ID));
    }

    // Full legacy-to-RLY-23 migration using the exact Relay implementation deployed on main.
    // The legacy Relay stores bare policy hashes and verifies bare message hashes. The new Relay
    // must wrap the legacy hash exactly once when it is seeded at the cutover boundary.
    function test_migration_fromMainRelay_wrapsLegacyHashAndPreservesLiveRelay() public {
        vm.chainId(FLARE_CHAIN_ID);

        bytes memory policy2 = _buildSigningPolicy(
            uint24(REWARD_EPOCH_ID + 1), START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION, THRESHOLD, SEED
        );
        bytes memory policy3 = _buildSigningPolicy(
            uint24(REWARD_EPOCH_ID + 2), START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION, THRESHOLD, SEED
        );

        // This is the deployed/main contract, not a reduced compatibility stub. Flare uses the
        // trusted signing-policy setter mode; relay-mode migration and fee-message migration are
        // deliberately out of scope here.
        RelayMainDeployed oldRelay = new RelayMainDeployed(
            _initialConfig(_signingPolicyContentHash(policy)), address(this), IRelay(address(0))
        );

        // Populate realistic pre-cutover history: two policies installed by the trusted setter
        // and one legacy-format message finalized under each active policy.
        (bool ok,) = address(oldRelay).call(_legacyMessageRelay(policy, START_VOTING_ROUND_ID, keccak256("old-1")));
        assertTrue(ok, "legacy message under policy 1 failed");
        oldRelay.setSigningPolicy(_policyStruct(REWARD_EPOCH_ID + 1, START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION));
        (ok,) = address(oldRelay).call(_legacyMessageRelay(policy2, START_VOTING_ROUND_ID + REWARD_EPOCH_DURATION, keccak256("old-2")));
        assertTrue(ok, "legacy message under policy 2 failed");
        oldRelay.setSigningPolicy(_policyStruct(REWARD_EPOCH_ID + 2, START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION));

        bytes32 legacyHash = oldRelay.toSigningPolicyHash(REWARD_EPOCH_ID + 2);
        assertEq(legacyHash, _signingPolicyContentHash(policy3), "main Relay must expose the bare legacy hash");

        // This is the migration operation: the new Relay is seeded with the legacy hash wrapped
        // once for the live chain. Its compatibility checks also consume the exact old Relay.
        IRelay.RelayInitialConfig memory migratedConfig = _initialConfig(_chainBound(legacyHash));
        migratedConfig.initialRewardEpochId = REWARD_EPOCH_ID + 2;
        migratedConfig.startingVotingRoundIdForInitialRewardEpochId =
            START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION;
        Relay migrated = new Relay(migratedConfig, address(this), IRelay(address(oldRelay)));

        bytes memory postCutover = _chainBoundMessageRelay(
            policy3,
            START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION,
            keccak256("new-1")
        );
        (ok,) = address(migrated).call(postCutover);
        assertTrue(ok, "migrated Relay rejected the first chain-bound message");
        assertTrue(
            migrated.isFinalized(3, START_VOTING_ROUND_ID + 2 * REWARD_EPOCH_DURATION),
            "migrated Relay did not finalize the post-cutover message"
        );

        // The format transition is intentional: the pre-RLY-23 deployment cannot consume the
        // chain-bound digest, even though it has the same voters and policy content.
        vm.expectRevert("Wrong signature");
        this.relayToLegacy(oldRelay, postCutover);

        // Data providers signing a policy for the RLY-23 contract cannot use that policy-relay
        // message on the deployed/main contract. Flare runs both contracts in trusted-setter
        // mode, so the old contract rejects the mode before it can process the chain-bound
        // signatures; policy changes must go through the setter instead.
        bytes memory policy4 = _buildSigningPolicy(
            uint24(REWARD_EPOCH_ID + 3), START_VOTING_ROUND_ID + 3 * REWARD_EPOCH_DURATION, THRESHOLD, SEED
        );
        vm.expectRevert("Sign policy relay disabled");
        this.relayToLegacy(oldRelay, _chainBoundPolicyRelay(policy3, policy4));
    }

    // Fork behavior (runtime chainid, EIP-1344): if the chain id changes under an existing
    // deployment, the stored policy hash no longer matches under the new domain — the Relay fails
    // closed for ALL new finalizations (even freshly signed ones) until redeployed. Already-stored
    // roots remain verifiable (verify() is content-pure).
    function test_fork_failsClosed() public {
        bytes memory rm = _msgRelay(3, START_VOTING_ROUND_ID, keccak256("root"), 3);
        (bool ok,) = address(relay).call(rm);
        assertTrue(ok, "pre-fork accept failed");

        vm.chainId(SONGBIRD_CHAIN_ID); // the fork renames the chain
        // pre-fork calldata: rejected before the signature loop
        vm.expectRevert("Signing policy hash mismatch");
        this.relayTo(relay, rm);
        // even fresh signatures under the NEW domain cannot finalize — the stored policy hash
        // still carries the old domain
        bytes memory rmNew = _msgRelay(3, START_VOTING_ROUND_ID + 1, keccak256("root2"), 3);
        vm.expectRevert("Signing policy hash mismatch");
        this.relayTo(relay, rmNew);
        // content-pure reads survive the fork
        assertTrue(relay.isFinalized(3, START_VOTING_ROUND_ID), "stored root must remain readable");
    }
}
