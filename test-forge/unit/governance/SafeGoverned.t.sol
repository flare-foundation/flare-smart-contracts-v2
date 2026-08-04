// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {SafeGoverned} from "../../../contracts/governance/implementation/SafeGoverned.sol";
import {ISafeGovernance} from "../../../contracts/userInterfaces/ISafeGovernance.sol";
import {SafeGovernance} from "../../../contracts/governance/lib/SafeGovernance.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {GnosisSafeL2} from "@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

interface IDigestSafe {
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
        uint256 nonce_
    ) external view returns (bytes32);
}

/// Minimal concrete child: one mock app action, internals exposed for direct testing.
contract MockSafeGoverned is SafeGoverned {
    bytes4 public constant MOCK_ACTION_SELECTOR =
        bytes4(keccak256("mockAction(uint256,bytes32,uint256)"));

    uint256 public lastPayload;
    uint256 public hookCalls;
    bool public relevant = true;

    function initialize(GovernanceConfig memory _config) external initializer {
        initializeSafeGoverned(_config);
    }

    function setRelevant(bool _relevant) external {
        relevant = _relevant;
    }

    function safeTxDigest(SafeTx calldata txData, uint256 chainId, address safe) external pure returns (bytes32) {
        return _safeTxDigest(txData, chainId, safe);
    }

    function recoverSigner(bytes32 digest, bytes calldata signature) external pure returns (address) {
        return _recoverSigner(digest, signature);
    }

    function validateSigners(address[] calldata signers) external view {
        _validateGovernanceSigners(signers);
    }

    function _processGovernanceAction(bytes4 _selector, bytes calldata _action)
        internal override
        returns (bool)
    {
        if (_selector != MOCK_ACTION_SELECTOR) {
            revert UnknownGovernanceAction(_selector);
        }
        (,, uint256 payload) = abi.decode(_action[4:], (uint256, bytes32, uint256));
        ++hookCalls;
        lastPayload = payload;
        return relevant;
    }
}

contract SafeGovernedTest is Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant THRESHOLD = 2;
    uint256 internal constant REPLAY_FLOOR = 5;
    address internal constant SAFE = address(0xCAFE);
    bytes32 internal constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
    bytes32 internal constant SAFE_TX_TYPEHASH =
        0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    uint256[3] internal keys = [uint256(21), 22, 23];
    address[] internal owners;
    MockSafeGoverned internal governed;
    bytes32 internal ownerHash;

    function setUp() public {
        for (uint256 i; i < keys.length; ++i) {
            owners.push(vm.addr(keys[i]));
        }
        _sortAddresses(owners);
        governed = new MockSafeGoverned();
        governed.initialize(_config());
        (ownerHash,) = governed.governanceOwnerConfig();
    }

    //// Digest: typehash pinning + differential parity against the real Safe v1.3.0 ////

    function test_digestPinsDeployedSafeTypehashes() public view {
        ISafeGovernance.SafeTx memory txData = _mockTx(bytes("payload"), 7);
        bytes32 domain = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, SOURCE_CHAIN, SAFE));
        bytes32 structHash = keccak256(abi.encode(
            SAFE_TX_TYPEHASH,
            txData.to,
            txData.value,
            keccak256(txData.data),
            txData.operation,
            txData.safeTxGas,
            txData.baseGas,
            txData.gasPrice,
            txData.gasToken,
            txData.refundReceiver,
            txData.nonce
        ));
        bytes32 expected = keccak256(abi.encodePacked("\x19\x01", domain, structHash));
        assertEq(governed.safeTxDigest(txData, SOURCE_CHAIN, SAFE), expected);
    }

    function testFuzz_digestMatchesRealSafeV130(
        address to,
        uint128 value,
        bytes memory data,
        uint8 operation,
        uint64 safeTxGas,
        uint64 baseGas,
        uint64 gasPrice,
        address gasToken,
        address refundReceiver,
        uint64 nonce
    ) public {
        vm.assume(data.length <= 512);
        operation %= 2;
        vm.chainId(SOURCE_CHAIN);
        GnosisSafeL2 singleton = new GnosisSafeL2();
        GnosisSafeProxy proxy = new GnosisSafeProxy(address(singleton));
        IDigestSafe realSafe = IDigestSafe(address(proxy));
        realSafe.setup(owners, THRESHOLD, address(0), bytes(""), address(0), address(0), 0, payable(address(0)));

        ISafeGovernance.SafeTx memory txData = ISafeGovernance.SafeTx(
            to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce
        );
        bytes32 expected = realSafe.getTransactionHash(
            to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce
        );
        assertEq(governed.safeTxDigest(txData, SOURCE_CHAIN, address(realSafe)), expected);
    }

    //// Signature recovery: v flavours ////

    function test_recoverDirectAndEthSignFlavours() public view {
        bytes32 digest = keccak256("some digest");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(keys[0], digest);
        assertEq(governed.recoverSigner(digest, abi.encodePacked(r, s, v)), vm.addr(keys[0]));

        bytes32 prefixed = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(keys[1], prefixed);
        assertEq(governed.recoverSigner(digest, abi.encodePacked(r2, s2, v2 + 4)), vm.addr(keys[1]));
    }

    function test_recoverRejectsUnsupportedAndMalformedTypes() public {
        bytes32 digest = keccak256("some digest");
        (, bytes32 r, bytes32 s) = vm.sign(keys[0], digest);

        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.UnsupportedSignatureType.selector, 0));
        governed.recoverSigner(digest, abi.encodePacked(r, s, uint8(0)));

        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.UnsupportedSignatureType.selector, 1));
        governed.recoverSigner(digest, abi.encodePacked(r, s, uint8(1)));

        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
        governed.recoverSigner(digest, abi.encodePacked(r, s, uint8(29)));

        vm.expectRevert(
            abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureS.selector, bytes32(type(uint256).max))
        );
        governed.recoverSigner(digest, abi.encodePacked(r, bytes32(type(uint256).max), uint8(27)));
    }

    //// Signer-set validation ////

    function test_validateSignersMatrix() public {
        address[] memory two = new address[](2);
        two[0] = owners[0];
        two[1] = owners[1];
        governed.validateSigners(two);

        address[] memory unsorted = new address[](2);
        unsorted[0] = owners[1];
        unsorted[1] = owners[0];
        vm.expectRevert(ISafeGovernance.SignersNotSorted.selector);
        governed.validateSigners(unsorted);

        address[] memory duplicated = new address[](2);
        duplicated[0] = owners[0];
        duplicated[1] = owners[0];
        vm.expectRevert(ISafeGovernance.SignersNotSorted.selector);
        governed.validateSigners(duplicated);

        address stranger = vm.addr(99);
        address[] memory withStranger = new address[](3);
        withStranger[0] = owners[0];
        withStranger[1] = owners[1];
        withStranger[2] = stranger;
        _sortAddresses3(withStranger);
        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.UnknownSigner.selector, stranger));
        governed.validateSigners(withStranger);

        address[] memory one = new address[](1);
        one[0] = owners[0];
        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.ThresholdNotReached.selector, 1, THRESHOLD));
        governed.validateSigners(one);
    }

    //// Initialization matrix ////

    function test_initEmptyConfigReverts() public {
        // Governance is mandatory: an all-zero configuration cannot initialize.
        MockSafeGoverned fresh = new MockSafeGoverned();
        ISafeGovernance.GovernanceConfig memory empty;
        vm.expectRevert(ISafeGovernance.InvalidGovernanceSource.selector);
        fresh.initialize(empty);
    }

    function test_uninitializedProcessSafeMessageReverts() public {
        // A consumer that never runs the initializer has the governance path disabled.
        MockSafeGoverned fresh = new MockSafeGoverned();
        (ISafeGovernance.SafeTx memory txData, bytes memory sigs) = _signedMockAction(REPLAY_FLOOR + 1, 1);
        vm.expectRevert(ISafeGovernance.InvalidGovernanceTransaction.selector);
        fresh.processSafeMessage(txData, sigs);
    }

    function test_initValidationMatrix() public {
        MockSafeGoverned fresh = new MockSafeGoverned();

        ISafeGovernance.GovernanceConfig memory noSafe = _config();
        noSafe.safe = address(0);
        vm.expectRevert(ISafeGovernance.InvalidGovernanceSource.selector);
        fresh.initialize(noSafe);

        ISafeGovernance.GovernanceConfig memory noSource = _config();
        noSource.sourceChainId = 0;
        vm.expectRevert(ISafeGovernance.InvalidGovernanceSource.selector);
        fresh.initialize(noSource);

        ISafeGovernance.GovernanceConfig memory badNonce = _config();
        badNonce.ownerConfigSafeNonce = badNonce.safeNonce + 1;
        vm.expectRevert(ISafeGovernance.InvalidGovernanceOwnerConfiguration.selector);
        fresh.initialize(badNonce);

        ISafeGovernance.GovernanceConfig memory badThreshold = _config();
        badThreshold.threshold = owners.length + 1;
        vm.expectRevert(ISafeGovernance.InvalidGovernanceOwnerConfiguration.selector);
        fresh.initialize(badThreshold);

        fresh.initialize(_config());
        vm.expectRevert();
        fresh.initialize(_config()); // initializer: exactly once
    }

    //// Action state machine via the hook ////

    function test_hookDispatchAndNonceConsumption() public {
        // the floor itself is the FIRST accepted signed nonce
        uint256 actionNonce = REPLAY_FLOOR;
        (ISafeGovernance.SafeTx memory txData, bytes memory sigs) = _signedMockAction(actionNonce, 42);
        governed.processSafeMessage(txData, sigs);
        assertEq(governed.hookCalls(), 1);
        assertEq(governed.lastPayload(), 42);
        assertTrue(governed.governanceSafeNonceConsumed(actionNonce));
        (, uint256 lastNonce) = governed.governanceNonces();
        assertEq(lastNonce, actionNonce);
    }

    function test_irrelevantHookResultDoesNotConsume() public {
        governed.setRelevant(false);
        uint256 actionNonce = REPLAY_FLOOR + 1;
        (ISafeGovernance.SafeTx memory txData, bytes memory sigs) = _signedMockAction(actionNonce, 42);
        governed.processSafeMessage(txData, sigs);
        assertEq(governed.hookCalls(), 1);
        assertFalse(governed.governanceSafeNonceConsumed(actionNonce));
        (, uint256 lastNonce) = governed.governanceNonces();
        assertEq(lastNonce, REPLAY_FLOOR);
    }

    function test_unknownSelectorReverts() public {
        uint256 actionNonce = REPLAY_FLOOR + 1;
        bytes memory action = abi.encodeWithSelector(bytes4(0xDEADBEEF), actionNonce, ownerHash, uint256(1));
        (ISafeGovernance.SafeTx memory txData, bytes memory sigs) = _signedAction(action, actionNonce);
        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.UnknownGovernanceAction.selector, bytes4(0xDEADBEEF))
        );
        governed.processSafeMessage(txData, sigs);
    }

    function test_actionMustBindActiveOwnerConfig() public {
        uint256 actionNonce = REPLAY_FLOOR + 1;
        bytes32 wrongHash = keccak256("wrong");
        bytes memory action =
            abi.encodeWithSelector(governed.MOCK_ACTION_SELECTOR(), actionNonce, wrongHash, uint256(1));
        (ISafeGovernance.SafeTx memory txData, bytes memory sigs) = _signedAction(action, actionNonce);
        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.GovernanceOwnerHashMismatch.selector, wrongHash, ownerHash)
        );
        governed.processSafeMessage(txData, sigs);
    }

    function test_changeOwnersRotationInBase() public {
        uint256 rotationNonce = REPLAY_FLOOR + 1;
        address[] memory newOwners = new address[](3);
        newOwners[0] = owners[0];
        newOwners[1] = owners[1];
        newOwners[2] = vm.addr(31);
        _sortAddresses3(newOwners);
        bytes memory action = abi.encodeWithSelector(
            SafeGovernance.CHANGE_OWNERS_SELECTOR, rotationNonce, ownerHash, THRESHOLD, newOwners
        );
        (ISafeGovernance.SafeTx memory txData, bytes memory sigs) = _signedAction(action, rotationNonce);
        governed.processSafeMessage(txData, sigs);

        bytes32 expected =
            SafeGovernance.ownerConfigHash(SOURCE_CHAIN, SAFE, rotationNonce, THRESHOLD, newOwners);
        (bytes32 activeHash, uint256 activeNonce) = governed.governanceOwnerConfig();
        assertEq(activeHash, expected);
        assertEq(activeNonce, rotationNonce);
        (,, address[] memory storedOwners) = governed.governanceSigners();
        assertEq(storedOwners.length, newOwners.length);
        for (uint256 i; i < newOwners.length; ++i) {
            assertEq(storedOwners[i], newOwners[i]);
        }
        assertEq(governed.hookCalls(), 0); // rotation handled entirely in the base
    }

    function test_replayRules() public {
        // below the replay floor (the floor itself is the first ACCEPTED signed nonce)
        (ISafeGovernance.SafeTx memory floorTx, bytes memory floorSigs) = _signedMockAction(REPLAY_FLOOR - 1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeGovernance.GovernanceNonceBeforeReplayFloor.selector, REPLAY_FLOOR - 1, REPLAY_FLOOR
            )
        );
        governed.processSafeMessage(floorTx, floorSigs);

        // nonce binding to the Safe transaction nonce — an envelope one below the action
        // nonce is EXACTLY the retired post-execution (+1) convention and must be rejected
        bytes memory action =
            abi.encodeWithSelector(governed.MOCK_ACTION_SELECTOR(), REPLAY_FLOOR + 2, ownerHash, uint256(1));
        (ISafeGovernance.SafeTx memory mismatched, bytes memory mSigs) = _signedAction(action, REPLAY_FLOOR + 1);
        vm.expectRevert(ISafeGovernance.InvalidGovernanceTransaction.selector);
        governed.processSafeMessage(mismatched, mSigs);

        // consumed nonce cannot be reused
        uint256 actionNonce = REPLAY_FLOOR + 3;
        (ISafeGovernance.SafeTx memory okTx, bytes memory okSigs) = _signedMockAction(actionNonce, 7);
        governed.processSafeMessage(okTx, okSigs);
        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.GovernanceNonceAlreadyConsumed.selector, actionNonce)
        );
        governed.processSafeMessage(okTx, okSigs);

        // app actions must advance the high-water mark
        (ISafeGovernance.SafeTx memory oldTx, bytes memory oldSigs) = _signedMockAction(REPLAY_FLOOR + 1, 9);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeGovernance.GovernanceNonceNotMonotonic.selector, REPLAY_FLOOR + 1, actionNonce
            )
        );
        governed.processSafeMessage(oldTx, oldSigs);
    }

    function test_envelopeRules() public {
        uint256 actionNonce = REPLAY_FLOOR + 1;
        (ISafeGovernance.SafeTx memory txData, bytes memory sigs) = _signedMockAction(actionNonce, 1);

        // NOTE: memory-struct assignment aliases, so mutate + restore between cases.
        txData.operation = 1;
        vm.expectRevert(ISafeGovernance.InvalidGovernanceTransaction.selector);
        governed.processSafeMessage(txData, sigs);
        txData.operation = 0;

        txData.value = 1;
        vm.expectRevert(ISafeGovernance.InvalidGovernanceTransaction.selector);
        governed.processSafeMessage(txData, sigs);
        txData.value = 0;

        vm.expectRevert(ISafeGovernance.InvalidSignaturesLength.selector);
        governed.processSafeMessage(txData, bytes(""));

        vm.expectRevert(ISafeGovernance.InvalidSignaturesLength.selector);
        governed.processSafeMessage(txData, bytes.concat(sigs, hex"00"));
    }

    //// helpers ////

    function _config() internal view returns (ISafeGovernance.GovernanceConfig memory c) {
        c.sourceChainId = SOURCE_CHAIN;
        c.safe = SAFE;
        c.threshold = THRESHOLD;
        c.owners = owners;
        c.ownerConfigSafeNonce = REPLAY_FLOOR;
        c.safeNonce = REPLAY_FLOOR;
    }

    function _mockTx(bytes memory data, uint256 nonce) internal pure returns (ISafeGovernance.SafeTx memory t) {
        t.to = address(0x1234);
        t.data = data;
        t.nonce = nonce;
    }

    function _signedMockAction(uint256 actionNonce, uint256 payload)
        internal
        view
        returns (ISafeGovernance.SafeTx memory txData, bytes memory signatures)
    {
        bytes memory action =
            abi.encodeWithSelector(governed.MOCK_ACTION_SELECTOR(), actionNonce, ownerHash, payload);
        return _signedAction(action, actionNonce);
    }

    function _signedAction(bytes memory action, uint256 safeTxNonce)
        internal
        view
        returns (ISafeGovernance.SafeTx memory txData, bytes memory signatures)
    {
        txData = _mockTx(action, safeTxNonce);
        bytes32 digest = governed.safeTxDigest(txData, SOURCE_CHAIN, SAFE);
        uint256[] memory sortedKeys = new uint256[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            sortedKeys[i] = keys[i];
        }
        for (uint256 i; i < sortedKeys.length; ++i) {
            for (uint256 j = i + 1; j < sortedKeys.length; ++j) {
                if (vm.addr(sortedKeys[j]) < vm.addr(sortedKeys[i])) {
                    (sortedKeys[i], sortedKeys[j]) = (sortedKeys[j], sortedKeys[i]);
                }
            }
        }
        for (uint256 i; i < THRESHOLD; ++i) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(sortedKeys[i], digest);
            signatures = bytes.concat(signatures, abi.encodePacked(r, s, v));
        }
    }

    function _sortAddresses(address[] storage values) internal {
        for (uint256 i = 1; i < values.length; ++i) {
            address value = values[i];
            uint256 j = i;
            while (j > 0 && values[j - 1] > value) {
                values[j] = values[j - 1];
                --j;
            }
            values[j] = value;
        }
    }

    function _sortAddresses3(address[] memory values) internal pure {
        for (uint256 i = 1; i < values.length; ++i) {
            address value = values[i];
            uint256 j = i;
            while (j > 0 && values[j - 1] > value) {
                values[j] = values[j - 1];
                --j;
            }
            values[j] = value;
        }
    }
}
