// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../contracts/protocol/implementation/Relay.sol";
import { RelayProxy } from "../../contracts/protocol/implementation/RelayProxy.sol";
// solhint-disable-next-line no-unused-import
import { deployRelay, RELAY_TEST_GOVERNANCE } from "../utils/RelayDeploy.sol";
import {IRelay} from "../../contracts/userInterfaces/IRelay.sol";
import {SafeGovernance} from "../../contracts/governance/lib/SafeGovernance.sol";
import {RelayProxy} from "../../contracts/protocol/implementation/RelayProxy.sol";

/// @dev Verification-only child exposing the two internal boundaries used by processSafeMessage.
/// Production callers can reach neither function on Relay itself.
contract RelaySafeGovernanceFormalHarness is Relay {
    function processVerifiedGovernanceAction(bytes calldata action, uint256 safeTxNonce) external {
        _processVerifiedGovernanceAction(action, safeTxNonce);
    }

    function validateGovernanceSigners(address[] calldata signers) external view {
        _validateGovernanceSigners(signers);
    }
}

/// @notice Bounded symbolic proofs for the Safe authorization/state-transition boundary.
/// @dev ECDSA recovery is deliberately outside this harness. These checks prove that recovered
/// signers must form a sorted, distinct threshold subset of the active owners and that an action
/// admitted after signature verification preserves the target-side nonce, generation, locality,
/// and atomicity rules. Safe digest equivalence is checked differentially against Safe v1.3.0.
contract SafeGovernanceFV is Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant TARGET_CHAIN = 100;
    uint256 internal constant OTHER_CHAIN = 200;
    uint256 internal constant REPLAY_FLOOR = 1;
    uint256 internal constant THRESHOLD = 2;
    address internal constant SAFE = address(0xCAFE);
    address internal constant OWNER_1 = address(0x1000);
    address internal constant OWNER_2 = address(0x2000);
    address internal constant OWNER_3 = address(0x3000);
    address internal constant NEW_OWNER = address(0x2800);

    bytes4 internal constant CHANGE_OWNERS = bytes4(keccak256("changeOwners(uint256,bytes32,uint256,address[])"));
    bytes4 internal constant CHANGE_FEES =
        bytes4(keccak256("changeProtocolFees(uint256,bytes32,(uint256,address,uint256,uint256)[])"));

    function setUp() public {}

    function _owners() internal pure returns (address[] memory values) {
        values = new address[](3);
        values[0] = OWNER_1;
        values[1] = OWNER_2;
        values[2] = OWNER_3;
    }

    function _newOwners() internal pure returns (address[] memory values) {
        values = new address[](3);
        values[0] = OWNER_1;
        values[1] = NEW_OWNER;
        values[2] = OWNER_3;
    }

    function _config() internal pure returns (IRelay.RelayInitialConfig memory config) {
        config.initialRewardEpochId = 1;
        config.startingVotingRoundIdForInitialRewardEpochId = 1;
        config.initialSigningPolicyHash = bytes32(uint256(1));
        config.randomNumberProtocolId = 2;
        config.firstVotingRoundStartTs = 1;
        config.votingEpochDurationSeconds = 1;
        config.firstRewardEpochStartVotingRoundId = 0;
        config.rewardEpochDurationInVotingEpochs = 1;
        config.thresholdIncreaseBIPS = 10_000;
        config.messageFinalizationWindowInRewardEpochs = 1;
        config.feeCollectionAddress = payable(address(0xFEE));
        config.governance.sourceChainId = SOURCE_CHAIN;
        config.governance.safe = SAFE;
        config.governance.threshold = THRESHOLD;
        config.governance.owners = _owners();
        config.governance.ownerConfigSafeNonce = REPLAY_FLOOR;
        config.governance.safeNonce = REPLAY_FLOOR;
    }

    function _deploy() internal returns (RelaySafeGovernanceFormalHarness target) {
        vm.chainId(TARGET_CHAIN);
        RelaySafeGovernanceFormalHarness harnessImplementation = new RelaySafeGovernanceFormalHarness();
        target = RelaySafeGovernanceFormalHarness(
            address(
                new RelayProxy(
                    address(harnessImplementation), _config(), address(0), IRelay(address(0)), address(0x600D)
                )
            )
        );
    }

    function _ownerHash(uint256 generation, address[] memory owners) internal pure returns (bytes32) {
        return SafeGovernance.ownerConfigHash(SOURCE_CHAIN, SAFE, generation, THRESHOLD, owners);
    }

    function _feeAction(uint256 nonce, bytes32 configHash, uint256 targetChain, address targetAddress, uint256 fee)
        internal
        pure
        returns (bytes memory action)
    {
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](1);
        updates[0] = SafeGovernance.GovernanceFeeUpdate(targetChain, targetAddress, 3, fee);
        return abi.encodeWithSelector(CHANGE_FEES, nonce, configHash, updates);
    }

    function _callAction(RelaySafeGovernanceFormalHarness target, bytes memory action, uint256 safeTxNonce)
        internal
        returns (bool ok)
    {
        (ok,) = address(target)
            .call(
                abi.encodeWithSelector(
                    RelaySafeGovernanceFormalHarness.processVerifiedGovernanceAction.selector, action, safeTxNonce
                )
            );
    }

    function _callSigners(RelaySafeGovernanceFormalHarness target, address[] memory signers) internal view returns (bool ok) {
        (ok,) = address(target)
            .staticcall(abi.encodeWithSelector(RelaySafeGovernanceFormalHarness.validateGovernanceSigners.selector, signers));
    }

    // Any recovered signer list shorter than the active threshold is rejected.
    // EXPECT: PASS.
    function check_gss_signers_belowThreshold_rejected() external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        address[] memory signers = new address[](1);
        signers[0] = OWNER_1;
        assert(!_callSigners(target, signers));
    }

    // Duplicate recovered owners cannot satisfy the threshold.
    // EXPECT: PASS.
    function check_gss_duplicateSigner_rejected() external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        address[] memory signers = new address[](2);
        signers[0] = OWNER_1;
        signers[1] = OWNER_1;
        assert(!_callSigners(target, signers));
    }

    // A sorted non-owner cannot be substituted for an active owner.
    // EXPECT: PASS.
    function check_gss_nonOwnerSigner_rejected(address outsider) external {
        vm.assume(outsider > OWNER_1 && outsider < OWNER_2);
        RelaySafeGovernanceFormalHarness target = _deploy();
        address[] memory signers = new address[](2);
        signers[0] = OWNER_1;
        signers[1] = outsider;
        assert(!_callSigners(target, signers));
    }

    // Owner signatures must be in the same strict order required by Safe v1.3.0.
    // EXPECT: PASS.
    function check_gss_unorderedSigners_rejected() external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        address[] memory signers = new address[](2);
        signers[0] = OWNER_2;
        signers[1] = OWNER_1;
        assert(!_callSigners(target, signers));
    }

    // A relevant canonical fee action updates only the local protocol and consumes its nonce.
    // EXPECT: PASS.
    function check_gss_relevantFee_atomicAndConsumed(uint128 fee) external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes memory action = _feeAction(2, _ownerHash(REPLAY_FLOOR, _owners()), TARGET_CHAIN, address(target), fee);
        bool ok = _callAction(target, action, 2);
        assert(ok);
        assert(target.protocolFeeInWei(3) == fee);
        (, uint256 lastNonce) = target.governanceNonces();
        assert(lastNonce == 2);
        assert(target.governanceSafeNonceConsumed(2));
    }

    // A valid action with no local target entry is a complete target-side no-op.
    // EXPECT: PASS.
    function check_gss_irrelevantFee_doesNotConsume(uint128 fee) external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes memory action = _feeAction(2, _ownerHash(REPLAY_FLOOR, _owners()), OTHER_CHAIN, address(target), fee);
        bool ok = _callAction(target, action, 2);
        assert(ok);
        assert(target.protocolFeeInWei(3) == 0);
        (, uint256 lastNonce) = target.governanceNonces();
        assert(lastNonce == REPLAY_FLOOR);
        assert(!target.governanceSafeNonceConsumed(2));
    }

    // A duplicate fee key is rejected before any local write occurs.
    // EXPECT: PASS.
    function check_gss_nonCanonicalFee_isAtomic(uint128 firstFee, uint128 secondFee) external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](2);
        updates[0] = SafeGovernance.GovernanceFeeUpdate(TARGET_CHAIN, address(target), 3, firstFee);
        updates[1] = SafeGovernance.GovernanceFeeUpdate(TARGET_CHAIN, address(target), 3, secondFee);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, uint256(2), _ownerHash(REPLAY_FLOOR, _owners()), updates);
        assert(!_callAction(target, action, 2));
        assert(target.protocolFeeInWei(3) == 0);
        (, uint256 lastNonce) = target.governanceNonces();
        assert(lastNonce == REPLAY_FLOOR);
        assert(!target.governanceSafeNonceConsumed(2));
    }

    // Owner changes are authorized against the old hash and create a generation-bound new hash.
    // EXPECT: PASS.
    function check_gss_ownerRotation_advancesGeneration(uint32 nonceSeed) external {
        uint256 nonce = uint256(nonceSeed) + 2;
        RelaySafeGovernanceFormalHarness target = _deploy();
        address[] memory nextOwners = _newOwners();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_OWNERS, nonce, _ownerHash(REPLAY_FLOOR, _owners()), THRESHOLD, nextOwners);
        assert(_callAction(target, action, nonce));
        (bytes32 activeHash, uint256 activeNonce) = target.governanceOwnerConfig();
        (, uint256 lastNonce) = target.governanceNonces();
        assert(activeNonce == nonce);
        assert(activeHash == _ownerHash(nonce, nextOwners));
        assert(target.governanceSafeNonceConsumed(nonce));
        assert(lastNonce == nonce);
    }

    // A proposed configuration cannot install itself by supplying any hash other than the active one.
    // EXPECT: PASS.
    function check_gss_wrongCurrentHash_cannotRotate(bytes32 wrongHash) external {
        bytes32 currentHash = _ownerHash(REPLAY_FLOOR, _owners());
        vm.assume(wrongHash != currentHash);
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes memory action = abi.encodeWithSelector(CHANGE_OWNERS, uint256(2), wrongHash, THRESHOLD, _newOwners());
        assert(!_callAction(target, action, 2));
        (bytes32 activeHash, uint256 activeNonce) = target.governanceOwnerConfig();
        assert(activeNonce == REPLAY_FLOOR);
        assert(activeHash == currentHash);
        assert(!target.governanceSafeNonceConsumed(2));
    }

    // A relevant action consumes its nonce globally, so a conflicting action cannot execute later.
    // EXPECT: PASS.
    function check_gss_consumedNonce_excludesConflict(uint128 fee) external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes32 currentHash = _ownerHash(REPLAY_FLOOR, _owners());
        assert(_callAction(target, _feeAction(2, currentHash, TARGET_CHAIN, address(target), fee), 2));
        bytes memory ownerAction =
            abi.encodeWithSelector(CHANGE_OWNERS, uint256(2), currentHash, THRESHOLD, _newOwners());
        assert(!_callAction(target, ownerAction, 2));
        assert(target.protocolFeeInWei(3) == fee);
        (bytes32 activeHash,) = target.governanceOwnerConfig();
        assert(activeHash == currentHash);
        assert(target.governanceSafeNonceConsumed(2));
    }

    // A delayed lower-nonce rotation may progress but cannot regress the global fee high-water mark.
    // EXPECT: PASS.
    function check_gss_delayedRotation_preservesFeeHighWater(uint128 fee) external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes32 currentHash = _ownerHash(REPLAY_FLOOR, _owners());
        assert(_callAction(target, _feeAction(5, currentHash, TARGET_CHAIN, address(target), fee), 5));
        address[] memory nextOwners = _newOwners();
        bytes memory ownerAction =
            abi.encodeWithSelector(CHANGE_OWNERS, uint256(3), currentHash, THRESHOLD, nextOwners);
        assert(_callAction(target, ownerAction, 3));
        (bytes32 activeHash, uint256 activeNonce) = target.governanceOwnerConfig();
        (, uint256 lastNonce) = target.governanceNonces();
        assert(lastNonce == 5);
        assert(activeNonce == 3);
        assert(activeHash == _ownerHash(3, nextOwners));
        assert(target.governanceSafeNonceConsumed(3));
        assert(target.governanceSafeNonceConsumed(5));
    }

    // Once a higher relevant fee action lands, a lower fee nonce cannot overwrite it.
    // EXPECT: PASS.
    function check_gss_lowerFeeNonce_cannotRegress(uint128 highFee, uint128 lowFee) external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes32 currentHash = _ownerHash(REPLAY_FLOOR, _owners());
        assert(_callAction(target, _feeAction(5, currentHash, TARGET_CHAIN, address(target), highFee), 5));
        assert(!_callAction(target, _feeAction(3, currentHash, TARGET_CHAIN, address(target), lowFee), 3));
        assert(target.protocolFeeInWei(3) == highFee);
        (, uint256 lastNonce) = target.governanceNonces();
        assert(lastNonce == 5);
        assert(!target.governanceSafeNonceConsumed(3));
    }

    // The action nonce is exactly Safe.nonce + 1; no other outer nonce can authorize it.
    // EXPECT: PASS.
    function check_gss_actionNonce_boundToSafeNonce(uint64 wrongSafeTxNonce) external {
        vm.assume(wrongSafeTxNonce != 2);
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes memory action = _feeAction(2, _ownerHash(REPLAY_FLOOR, _owners()), TARGET_CHAIN, address(target), 7);
        assert(!_callAction(target, action, wrongSafeTxNonce));
        (, uint256 lastNonce) = target.governanceNonces();
        assert(lastNonce == REPLAY_FLOOR);
        assert(!target.governanceSafeNonceConsumed(2));
    }

    // Anti-vacuity: a sorted threshold subset of active owners is accepted by the signer validator.
    // EXPECT: COUNTEREXAMPLE.
    function check_reach_gss_validSignerSet() external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        address[] memory signers = new address[](2);
        signers[0] = OWNER_1;
        signers[1] = OWNER_2;
        assert(!_callSigners(target, signers));
    }

    // Anti-vacuity: a valid local fee action reaches the successful state transition.
    // EXPECT: COUNTEREXAMPLE.
    function check_reach_gss_validFeeAction() external {
        RelaySafeGovernanceFormalHarness target = _deploy();
        bytes memory action = _feeAction(2, _ownerHash(REPLAY_FLOOR, _owners()), TARGET_CHAIN, address(target), 7);
        assert(!_callAction(target, action, 1));
    }
}
