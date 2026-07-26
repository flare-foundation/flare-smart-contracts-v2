// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// solhint-disable func-name-mixedcase

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {GSSGovernance} from "../../../contracts/governance/GSSGovernance.sol";
import {GnosisSafeTx} from "../../../contracts/governance/GnosisSafeTx.sol";
import {GSSOwnerConfigurationChecker} from "../../../contracts/governance/GSSOwnerConfigurationChecker.sol";
import {GnosisSafeL2} from "@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

interface IInvariantSafe {
    function setup(
        address[] calldata owners,
        uint256 threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 nonce
    ) external view returns (bytes32);

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

contract GSSGovernanceInvariantHandler is Test {
    struct PendingMessage {
        bytes data;
        bytes signatures;
        uint256 safeTxNonce;
        uint256 actionNonce;
        bytes32 sourceHash;
        bytes32 nextHash;
        uint8 kind;
        uint8 feeMask;
        uint256 feeA;
        uint256 feeB;
    }

    struct TargetModel {
        bytes32 ownerHash;
        uint256 ownerGeneration;
        uint256 lastNonce;
        uint256 fee3;
        uint256 fee4;
    }

    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant CHAIN_A = 100;
    uint256 internal constant CHAIN_B = 200;
    uint256 internal constant OTHER_CHAIN = 300;
    uint256 internal constant THRESHOLD = 3;
    uint256 internal constant MAX_PENDING = 32;
    address internal constant HELPER = address(0xCAFE);
    uint8 internal constant KIND_FEE = 1;
    uint8 internal constant KIND_OWNERS = 2;
    bytes4 internal constant CHANGE_OWNERS = bytes4(keccak256("changeOwners(uint256,bytes32,uint256,address[])"));
    bytes4 internal constant CHANGE_FEES =
        bytes4(keccak256("changeProtocolFees(uint256,bytes32,(uint256,uint256,uint256)[])"));

    Relay public immutable relayA;
    Relay public immutable relayB;
    address public immutable safe;
    uint256 public immutable replayFloor;

    uint256[] internal keysA;
    uint256[] internal keysB;
    uint256[] internal sourceKeys;
    address[] internal sourceOwners;
    bytes32 internal sourceHash;
    uint256 internal sourceGeneration;
    uint256 internal nextActionNonce;
    bool internal sourceUsesB;

    PendingMessage[] internal pending;
    uint256[] internal trackedNonces;
    mapping(uint256 nonce => bool) internal tracked;
    mapping(uint256 nonce => bool) internal consumedA;
    mapping(uint256 nonce => bool) internal consumedB;
    TargetModel internal modelA;
    TargetModel internal modelB;

    uint256 public acceptedCalls;
    uint256 public rejectedCalls;
    uint256 public irrelevantCalls;
    uint256 public mutationRejections;

    constructor(
        Relay relayA_,
        Relay relayB_,
        address safe_,
        uint256 replayFloor_,
        bytes32 initialHash,
        uint256[] memory keysA_,
        uint256[] memory keysB_
    ) {
        relayA = relayA_;
        relayB = relayB_;
        safe = safe_;
        replayFloor = replayFloor_;
        keysA = keysA_;
        keysB = keysB_;
        _setSourceKeys(keysA_);
        sourceHash = initialHash;
        sourceGeneration = replayFloor_;
        nextActionNonce = replayFloor_;
        modelA = TargetModel(initialHash, replayFloor_, replayFloor_, 0, 0);
        modelB = TargetModel(initialHash, replayFloor_, replayFloor_, 0, 0);
    }

    function createFee(uint8 gapSeed, uint256 feeA, uint256 feeB, uint8 maskSeed) external {
        if (pending.length >= MAX_PENDING) return;
        uint256 actionNonce = nextActionNonce + uint256(gapSeed % 4) + 1;
        nextActionNonce = actionNonce;
        uint8 feeMask = maskSeed % 4;
        _appendFeeMessage(actionNonce, feeA, feeB, feeMask);
    }

    function createConflict(
        uint8 gapSeed,
        uint256 firstFeeA,
        uint256 firstFeeB,
        uint256 secondFeeA,
        uint256 secondFeeB
    ) external {
        if (pending.length + 2 > MAX_PENDING) return;
        uint256 actionNonce = nextActionNonce + uint256(gapSeed % 4) + 1;
        nextActionNonce = actionNonce;
        _appendFeeMessage(actionNonce, firstFeeA, firstFeeB, 3);
        _appendFeeMessage(actionNonce, secondFeeA, secondFeeB, 3);
    }

    function createRotation(uint8 gapSeed) external {
        if (pending.length >= MAX_PENDING) return;
        uint256 actionNonce = nextActionNonce + uint256(gapSeed % 4) + 1;
        nextActionNonce = actionNonce;

        uint256[] memory nextKeys = sourceUsesB ? _copy(keysA) : _copy(keysB);
        address[] memory nextOwners = _ownersForKeys(nextKeys);
        bytes32 nextHash = GSSGovernance.ownerConfigHash(SOURCE_CHAIN, safe, actionNonce, THRESHOLD, nextOwners);
        bytes memory data = abi.encodeWithSelector(CHANGE_OWNERS, actionNonce, sourceHash, THRESHOLD, nextOwners);
        pending.push(
            PendingMessage({
                data: data,
                signatures: _sign(data, actionNonce - 1, sourceKeys),
                safeTxNonce: actionNonce - 1,
                actionNonce: actionNonce,
                sourceHash: sourceHash,
                nextHash: nextHash,
                kind: KIND_OWNERS,
                feeMask: 0,
                feeA: 0,
                feeB: 0
            })
        );
        _track(actionNonce);
        sourceUsesB = !sourceUsesB;
        _setSourceKeys(nextKeys);
        sourceHash = nextHash;
        sourceGeneration = actionNonce;
    }

    function deliver(uint8 messageSeed, uint8 targetSeed) external {
        if (pending.length == 0) return;
        uint256 index = uint256(messageSeed) % pending.length;
        bool toA = targetSeed % 2 == 0;
        _deliver(index, toA);
    }

    function mutateAndDeliver(uint8 messageSeed, uint8 targetSeed, uint8 fieldSeed) external {
        if (pending.length == 0) return;
        PendingMessage storage message = pending[uint256(messageSeed) % pending.length];
        bool toA = targetSeed % 2 == 0;
        Relay target = toA ? relayA : relayB;
        GnosisSafeTx.Transaction memory txData = _transaction(message);
        uint8 field = fieldSeed % 7;
        if (field == 0) {
            txData.to = address(uint160(txData.to) ^ 1);
        } else if (field == 1) {
            txData.data = bytes.concat(txData.data, hex"00");
        } else if (field == 2) {
            txData.nonce ^= 1;
        } else if (field == 3) {
            txData.safeTxGas = 1;
        } else if (field == 4) {
            txData.gasToken = address(1);
        } else if (field == 5) {
            txData.value = 1;
        } else {
            txData.operation = 1;
        }

        vm.chainId(toA ? CHAIN_A : CHAIN_B);
        (bool ok,) = address(target).call(abi.encodeCall(Relay.processGSSMessage, (txData, message.signatures)));
        assertFalse(ok, "mutated signed transaction accepted");
        ++mutationRejections;
        _assertTarget(target, toA ? modelA : modelB, toA);
    }

    function pendingLength() external view returns (uint256) {
        return pending.length;
    }

    function sourceState() external view returns (bytes32 hash, uint256 generation, uint256 actionNonce) {
        return (sourceHash, sourceGeneration, nextActionNonce);
    }

    function assertAll() external view {
        _assertTarget(relayA, modelA, true);
        _assertTarget(relayB, modelB, false);
    }

    function _appendFeeMessage(uint256 actionNonce, uint256 feeA, uint256 feeB, uint8 feeMask) internal {
        uint256 count = feeMask == 0 ? 1 : ((feeMask & 1 == 0 ? 0 : 1) + (feeMask & 2 == 0 ? 0 : 1));
        Relay.GovernanceFeeUpdate[] memory updates = new Relay.GovernanceFeeUpdate[](count);
        uint256 position;
        if (feeMask & 1 != 0) {
            updates[position++] = Relay.GovernanceFeeUpdate(CHAIN_A, 3, feeA);
        }
        if (feeMask & 2 != 0) {
            updates[position++] = Relay.GovernanceFeeUpdate(CHAIN_B, 4, feeB);
        }
        if (feeMask == 0) {
            updates[0] = Relay.GovernanceFeeUpdate(OTHER_CHAIN, 5, feeA ^ feeB);
        }
        bytes memory data = abi.encodeWithSelector(CHANGE_FEES, actionNonce, sourceHash, updates);
        pending.push(
            PendingMessage({
                data: data,
                signatures: _sign(data, actionNonce - 1, sourceKeys),
                safeTxNonce: actionNonce - 1,
                actionNonce: actionNonce,
                sourceHash: sourceHash,
                nextHash: bytes32(0),
                kind: KIND_FEE,
                feeMask: feeMask,
                feeA: feeA,
                feeB: feeB
            })
        );
        _track(actionNonce);
    }

    function _deliver(uint256 index, bool toA) internal {
        PendingMessage storage message = pending[index];
        Relay target = toA ? relayA : relayB;
        TargetModel storage model = toA ? modelA : modelB;
        mapping(uint256 => bool) storage consumed = toA ? consumedA : consumedB;
        uint256 targetChain = toA ? CHAIN_A : CHAIN_B;

        bool hashMatches = message.sourceHash == model.ownerHash;
        bool nonceAvailable = message.actionNonce > replayFloor && !consumed[message.actionNonce];
        bool expectedSuccess;
        bool relevant;
        if (message.kind == KIND_OWNERS) {
            expectedSuccess = hashMatches && nonceAvailable && message.actionNonce > model.ownerGeneration;
            relevant = expectedSuccess;
        } else {
            expectedSuccess = hashMatches && nonceAvailable && message.actionNonce > model.lastNonce;
            relevant = expectedSuccess && _isRelevant(message.feeMask, toA);
        }

        GnosisSafeTx.Transaction memory txData = _transaction(message);
        vm.chainId(targetChain);
        (bool ok,) = address(target).call(abi.encodeCall(Relay.processGSSMessage, (txData, message.signatures)));
        assertEq(ok, expectedSuccess, "Relay/reference-model result mismatch");

        if (!ok) {
            ++rejectedCalls;
        } else if (!relevant) {
            ++irrelevantCalls;
        } else {
            ++acceptedCalls;
            consumed[message.actionNonce] = true;
            if (message.kind == KIND_OWNERS) {
                model.ownerHash = message.nextHash;
                model.ownerGeneration = message.actionNonce;
                if (message.actionNonce > model.lastNonce) {
                    model.lastNonce = message.actionNonce;
                }
            } else {
                model.lastNonce = message.actionNonce;
                if (toA) model.fee3 = message.feeA;
                else model.fee4 = message.feeB;
            }
        }
        _assertTarget(target, model, toA);
    }

    function _transaction(PendingMessage storage message)
        internal
        view
        returns (GnosisSafeTx.Transaction memory txData)
    {
        txData.to = HELPER;
        txData.data = message.data;
        txData.nonce = message.safeTxNonce;
    }

    function _sign(bytes memory data, uint256 safeTxNonce, uint256[] storage signingKeys)
        internal
        returns (bytes memory signatures)
    {
        GnosisSafeTx.Transaction memory txData;
        txData.to = HELPER;
        txData.data = data;
        txData.nonce = safeTxNonce;
        bytes32 digest = GnosisSafeTx.digest(txData, SOURCE_CHAIN, safe);
        for (uint256 i; i < THRESHOLD; ++i) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKeys[i], digest);
            signatures = bytes.concat(signatures, abi.encodePacked(r, s, v));
        }
    }

    function _setSourceKeys(uint256[] memory values) internal {
        delete sourceKeys;
        delete sourceOwners;
        for (uint256 i; i < values.length; ++i) {
            sourceKeys.push(values[i]);
            sourceOwners.push(vm.addr(values[i]));
        }
    }

    function _ownersForKeys(uint256[] memory values) internal returns (address[] memory owners) {
        owners = new address[](values.length);
        for (uint256 i; i < values.length; ++i) {
            owners[i] = vm.addr(values[i]);
        }
    }

    function _copy(uint256[] storage values) internal view returns (uint256[] memory copy) {
        copy = new uint256[](values.length);
        for (uint256 i; i < values.length; ++i) {
            copy[i] = values[i];
        }
    }

    function _isRelevant(uint8 feeMask, bool toA) internal pure returns (bool) {
        return toA ? feeMask & 1 != 0 : feeMask & 2 != 0;
    }

    function _track(uint256 nonce) internal {
        if (tracked[nonce]) return;
        tracked[nonce] = true;
        trackedNonces.push(nonce);
    }

    function _assertTarget(Relay target, TargetModel storage model, bool isA) internal view {
        assertEq(target.activeOwnerConfigHash(), model.ownerHash, "owner hash");
        assertEq(target.activeOwnerConfigSafeNonce(), model.ownerGeneration, "owner generation");
        assertEq(target.lastGovernanceSafeNonce(), model.lastNonce, "last nonce");
        assertEq(target.protocolFeeInWei(3), model.fee3, "protocol 3 fee");
        assertEq(target.protocolFeeInWei(4), model.fee4, "protocol 4 fee");
        assertGe(model.ownerGeneration, replayFloor, "owner generation regressed");
        assertGe(model.lastNonce, replayFloor, "last nonce regressed");

        address[] memory owners = new address[](target.governanceOwnersLength());
        for (uint256 i; i < owners.length; ++i) {
            owners[i] = target.governanceOwner(i);
            if (i > 0) {
                assertLt(uint256(uint160(owners[i - 1])), uint256(uint160(owners[i])), "owners not canonical");
            }
        }
        assertEq(
            GSSGovernance.ownerConfigHash(SOURCE_CHAIN, safe, model.ownerGeneration, THRESHOLD, owners),
            model.ownerHash,
            "owner hash is not derived from stored generation/config"
        );

        for (uint256 i; i < trackedNonces.length; ++i) {
            uint256 nonce = trackedNonces[i];
            bool expected = isA ? consumedA[nonce] : consumedB[nonce];
            assertEq(target.governanceSafeNonceConsumed(nonce), expected, "consumed nonce");
        }
    }
}

contract GSSGovernanceInvariantTest is StdInvariant, Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant CHAIN_A = 100;
    uint256 internal constant CHAIN_B = 200;
    uint256 internal constant THRESHOLD = 3;

    IInvariantSafe internal safe;
    GSSOwnerConfigurationChecker internal checker;
    Relay internal relayA;
    Relay internal relayB;
    GSSGovernanceInvariantHandler internal handler;
    uint256[] internal keysA;
    uint256[] internal keysB;
    address[] internal ownersA;

    function setUp() public {
        vm.chainId(SOURCE_CHAIN);
        keysA = _sortedKeys(_keys(11, 12, 13, 14, 15));
        keysB = _sortedKeys(_keys(12, 13, 14, 15, 16));
        ownersA = _owners(keysA);

        GnosisSafeL2 singleton = new GnosisSafeL2();
        GnosisSafeProxy proxy = new GnosisSafeProxy(address(singleton));
        safe = IInvariantSafe(address(proxy));
        safe.setup(ownersA, THRESHOLD, address(0), bytes(""), address(0), address(0), 0, payable(address(0)));
        checker = new GSSOwnerConfigurationChecker(SOURCE_CHAIN, address(safe));
        bytes memory bootstrap =
            abi.encodeWithSelector(checker.changeOwners.selector, uint256(1), bytes32(0), THRESHOLD, ownersA);
        _executeSafe(address(checker), bootstrap, 0, keysA);

        bytes32 initialHash = checker.activeOwnerConfigHash();
        vm.chainId(CHAIN_A);
        relayA = new Relay(_config(initialHash), address(0), IRelay(address(0)));
        vm.chainId(CHAIN_B);
        relayB = new Relay(_config(initialHash), address(0), IRelay(address(0)));

        handler = new GSSGovernanceInvariantHandler(relayA, relayB, address(safe), 1, initialHash, keysA, keysB);
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = handler.createFee.selector;
        selectors[1] = handler.createConflict.selector;
        selectors[2] = handler.createRotation.selector;
        selectors[3] = handler.deliver.selector;
        selectors[4] = handler.mutateAndDeliver.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_modelMatchesBothRelayTargets() public view {
        handler.assertAll();
    }

    function test_stateMachineHandlesDelayedRotationAndTargetDivergence() public {
        handler.createFee(0, 10, 20, 3); // pending[0], old generation
        handler.createRotation(0); // pending[1]
        handler.createFee(0, 30, 40, 3); // pending[2], new generation

        handler.deliver(2, 0); // A rejects new generation before rotation
        handler.deliver(1, 0); // A installs rotation
        handler.deliver(2, 0); // A accepts new fee
        handler.deliver(0, 0); // A rejects stale lower nonce

        handler.deliver(0, 1); // B accepts old-generation fee
        handler.deliver(1, 1); // B installs delayed rotation
        handler.deliver(2, 1); // B accepts new-generation fee
        handler.assertAll();
    }

    function test_stateMachineMakesSameNonceConflictsFirstDeliveryWinsPerTarget() public {
        handler.createConflict(0, 10, 20, 30, 40);
        handler.deliver(0, 0);
        handler.deliver(1, 0);
        handler.deliver(1, 1);
        handler.deliver(0, 1);
        handler.assertAll();
    }

    function _config(bytes32 initialHash) internal view returns (IRelay.RelayInitialConfig memory config) {
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
        config.governanceSourceChainId = SOURCE_CHAIN;
        config.governanceSafe = address(safe);
        config.governanceThreshold = THRESHOLD;
        config.governanceOwners = ownersA;
        config.governanceOwnerConfigSafeNonce = 1;
        config.governanceSafeNonce = 1;
        assertEq(GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(safe), 1, THRESHOLD, ownersA), initialHash);
    }

    function _executeSafe(address to, bytes memory data, uint256 nonce, uint256[] memory signingKeys) internal {
        bytes32 digest = safe.getTransactionHash(to, 0, data, 0, 0, 0, 0, address(0), address(0), nonce);
        bytes memory signatures;
        for (uint256 i; i < THRESHOLD; ++i) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKeys[i], digest);
            signatures = bytes.concat(signatures, abi.encodePacked(r, s, v));
        }
        assertTrue(safe.execTransaction(to, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures));
    }

    function _keys(uint256 a, uint256 b, uint256 c, uint256 d, uint256 e)
        internal
        pure
        returns (uint256[] memory values)
    {
        values = new uint256[](5);
        values[0] = a;
        values[1] = b;
        values[2] = c;
        values[3] = d;
        values[4] = e;
    }

    function _sortedKeys(uint256[] memory values) internal returns (uint256[] memory) {
        for (uint256 i = 1; i < values.length; ++i) {
            uint256 value = values[i];
            address owner = vm.addr(value);
            uint256 j = i;
            while (j > 0 && vm.addr(values[j - 1]) > owner) {
                values[j] = values[j - 1];
                --j;
            }
            values[j] = value;
        }
        return values;
    }

    function _owners(uint256[] memory values) internal returns (address[] memory owners) {
        owners = new address[](values.length);
        for (uint256 i; i < values.length; ++i) {
            owners[i] = vm.addr(values[i]);
        }
    }
}
