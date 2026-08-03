// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IRelayGovernance} from "../../../contracts/userInterfaces/IRelayGovernance.sol";
import {GSSGovernance} from "../../../contracts/governance/GSSGovernance.sol";
import {GnosisSafeTx} from "../../../contracts/governance/GnosisSafeTx.sol";
import {GSSOwnerConfigurationChecker} from "../../../contracts/governance/GSSOwnerConfigurationChecker.sol";
import {GnosisSafeL2} from "@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

interface IRealGSS {
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
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
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

contract GSSGovernanceTest is Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant CHAIN_A = 100;
    uint256 internal constant CHAIN_B = 200;
    uint256 internal constant THRESHOLD = 3;
    uint256 internal constant NEW_OWNER_KEY = 16;
    address internal constant SENTINEL_OWNERS = address(0x1);
    bytes4 internal constant CHANGE_FEES =
        bytes4(keccak256("changeProtocolFees(uint256,bytes32,(uint256,uint256,uint256)[])"));

    uint256[5] internal keys = [uint256(11), 12, 13, 14, 15];
    address[] internal owners;
    IRealGSS internal gss;
    GSSOwnerConfigurationChecker internal checker;
    Relay internal relayA;
    Relay internal relayB;
    bytes32 internal ownerHash;
    uint256 internal ownerConfigSafeNonce;

    function setUp() public {
        for (uint256 i; i < keys.length; ++i) {
            owners.push(vm.addr(keys[i]));
        }
        address[] memory sortedOwners = owners;
        _sort(sortedOwners);
        owners = sortedOwners;
        vm.chainId(SOURCE_CHAIN);
        GnosisSafeL2 singleton = new GnosisSafeL2();
        GnosisSafeProxy proxy = new GnosisSafeProxy(address(singleton));
        gss = IRealGSS(address(proxy));
        gss.setup(owners, THRESHOLD, address(0), bytes(""), address(0), address(0), 0, payable(address(0)));
        checker = new GSSOwnerConfigurationChecker(SOURCE_CHAIN, address(gss));
        bytes memory bootstrapAction =
            abi.encodeWithSelector(checker.changeOwners.selector, gss.nonce() + 1, bytes32(0), THRESHOLD, owners);
        _executeThroughGSS(address(checker), bootstrapAction);
        ownerConfigSafeNonce = checker.activeOwnerConfigSafeNonce();
        ownerHash = checker.activeOwnerConfigHash();

        vm.chainId(CHAIN_A);
        relayA = new Relay(_relayConfig(address(gss)), address(0), IRelay(address(0)));
        vm.chainId(CHAIN_B);
        relayB = new Relay(_relayConfig(address(gss)), address(0), IRelay(address(0)));
    }

    function test_setupIsThreeOfFiveAndCheckerMatchesGSS() public {
        assertEq(IRelayGovernance.InvalidGovernanceSource.selector, bytes4(keccak256("InvalidGovernanceSource()")));
        assertEq(
            IRelayGovernance.InvalidGovernanceDeployment.selector, bytes4(keccak256("InvalidGovernanceDeployment()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceOwnerConfiguration.selector,
            bytes4(keccak256("InvalidGovernanceOwnerConfiguration()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceTransaction.selector, bytes4(keccak256("InvalidGovernanceTransaction()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceSignatures.selector, bytes4(keccak256("InvalidGovernanceSignatures()"))
        );
        assertEq(
            IRelayGovernance.UnknownGovernanceAction.selector, bytes4(keccak256("UnknownGovernanceAction(bytes4)"))
        );
        assertEq(
            IRelayGovernance.GovernanceOwnerHashMismatch.selector,
            bytes4(keccak256("GovernanceOwnerHashMismatch(bytes32,bytes32)"))
        );
        assertEq(
            IRelayGovernance.GovernanceNonceNotMonotonic.selector,
            bytes4(keccak256("GovernanceNonceNotMonotonic(uint256,uint256)"))
        );
        assertEq(
            IRelayGovernance.GovernanceNonceBeforeReplayFloor.selector,
            bytes4(keccak256("GovernanceNonceBeforeReplayFloor(uint256,uint256)"))
        );
        assertEq(
            IRelayGovernance.GovernanceNonceAlreadyConsumed.selector,
            bytes4(keccak256("GovernanceNonceAlreadyConsumed(uint256)"))
        );
        assertEq(
            IRelayGovernance.GovernanceOwnerConfigNonceNotIncreasing.selector,
            bytes4(keccak256("GovernanceOwnerConfigNonceNotIncreasing(uint256,uint256)"))
        );

        assertEq(checker.activeOwnerConfigHash(), ownerHash);
        assertEq(checker.activeOwnerConfigSafeNonce(), ownerConfigSafeNonce);
        assertEq(checker.latestSafeNonce(), ownerConfigSafeNonce);
        assertTrue(checker.activeOwnerConfigurationIsLive());
        assertEq(relayA.activeOwnerConfigSafeNonce(), ownerConfigSafeNonce);
        assertEq(relayA.governanceReplayFloor(), ownerConfigSafeNonce);
    }

    function test_safeDigestMatchesRealSafeForCompleteTransaction() public {
        vm.chainId(SOURCE_CHAIN);
        GnosisSafeTx.Transaction memory txData;
        txData.to = address(0x1234);
        txData.value = 17;
        txData.data = hex"1234567890";
        txData.operation = 1;
        txData.safeTxGas = 100_000;
        txData.baseGas = 21_000;
        txData.gasPrice = 7;
        txData.gasToken = address(0x5678);
        txData.refundReceiver = address(0x9ABC);
        txData.nonce = gss.nonce();

        bytes32 expected = gss.getTransactionHash(
            txData.to,
            txData.value,
            txData.data,
            txData.operation,
            txData.safeTxGas,
            txData.baseGas,
            txData.gasPrice,
            txData.gasToken,
            txData.refundReceiver,
            txData.nonce
        );
        assertEq(GnosisSafeTx.digest(txData, SOURCE_CHAIN, address(gss)), expected);
    }

    function testFuzz_safeDigestMatchesRealSafeForArbitraryTransaction(
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
        GnosisSafeTx.Transaction memory txData = GnosisSafeTx.Transaction(
            to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce
        );
        bytes32 expected = gss.getTransactionHash(
            txData.to,
            txData.value,
            txData.data,
            txData.operation,
            txData.safeTxGas,
            txData.baseGas,
            txData.gasPrice,
            txData.gasToken,
            txData.refundReceiver,
            txData.nonce
        );
        assertEq(GnosisSafeTx.digest(txData, SOURCE_CHAIN, address(gss)), expected);
    }

    function testFuzz_everySafeTransactionFieldIsBound(uint8 fieldSeed, uint64 mutationSeed) public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = gss.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safeNonce + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory original = _txTo(address(checker), action, safeNonce);
        original.safeTxGas = 100_000;
        original.baseGas = 21_000;
        original.gasPrice = 7;
        original.gasToken = address(0x1234);
        original.refundReceiver = address(0x5678);
        bytes memory signatures = _signWith(original, _ownerKeys(), THRESHOLD);

        GnosisSafeTx.Transaction memory mutated = _copyTransaction(original);
        uint256 mutation = uint256(mutationSeed) + 1;
        uint8 field = fieldSeed % 10;
        if (field == 0) {
            mutated.to = address(uint160(original.to) ^ uint160(mutation));
            if (mutated.to == original.to) mutated.to = address(uint160(original.to) ^ 1);
        } else if (field == 1) {
            mutated.value = mutation;
        } else if (field == 2) {
            mutated.data = bytes.concat(original.data, abi.encodePacked(bytes1(uint8(mutation))));
        } else if (field == 3) {
            mutated.operation = 1;
        } else if (field == 4) {
            mutated.safeTxGas = original.safeTxGas + mutation;
        } else if (field == 5) {
            mutated.baseGas = original.baseGas + mutation;
        } else if (field == 6) {
            mutated.gasPrice = original.gasPrice + mutation;
        } else if (field == 7) {
            mutated.gasToken = address(uint160(original.gasToken) ^ uint160(mutation));
            if (mutated.gasToken == original.gasToken) {
                mutated.gasToken = address(uint160(original.gasToken) ^ 1);
            }
        } else if (field == 8) {
            mutated.refundReceiver = address(uint160(original.refundReceiver) ^ uint160(mutation));
            if (mutated.refundReceiver == original.refundReceiver) {
                mutated.refundReceiver = address(uint160(original.refundReceiver) ^ 1);
            }
        } else {
            mutated.nonce = original.nonce + mutation;
        }

        vm.chainId(CHAIN_A);
        vm.expectRevert();
        relayA.processGSSMessage(mutated, signatures);
        assertEq(relayA.protocolFeeInWei(3), 0);
        assertEq(relayA.lastGovernanceSafeNonce(), ownerConfigSafeNonce);
        assertFalse(relayA.governanceSafeNonceConsumed(safeNonce + 1));
    }

    function test_feeMessageWorksOnTwoIndependentTargetChains() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = gss.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safeNonce + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        assertEq(relayA.protocolFeeInWei(4), 0);

        vm.chainId(CHAIN_B);
        relayB.processGSSMessage(txData, signatures);
        assertEq(relayB.protocolFeeInWei(4), 222);
        assertEq(relayB.protocolFeeInWei(3), 0);
    }

    function test_rejectsReplayAndModifiedAction() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = gss.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safeNonce + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);
        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        vm.expectRevert();
        relayA.processGSSMessage(txData, signatures);

        bytes memory modified =
            abi.encodeWithSelector(CHANGE_FEES, uint256(2), ownerHash, _feeUpdates(CHAIN_A, CHAIN_A));
        vm.expectRevert();
        relayA.processGSSMessage(_tx(modified, 2), signatures);

        GnosisSafeTx.Transaction memory modifiedTarget = txData;
        modifiedTarget.to = address(0xBEEF);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(modifiedTarget, signatures);
    }

    function test_acceptsMessageExecutedThroughAnyCompatibleHelper() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory feeAction =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(0xCAFE), feeAction);
        assertEq(txData.to, address(0xCAFE));

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_targetDeploymentDoesNotRequireSourceSafeCode() public {
        vm.chainId(CHAIN_A);
        address sourceOnlySafe = address(0x123456789);
        assertEq(sourceOnlySafe.code.length, 0);
        Relay targetRelay = new Relay(_relayConfig(sourceOnlySafe), address(0), IRelay(address(0)));
        assertEq(targetRelay.governanceSafe(), sourceOnlySafe);
    }

    function test_rejectsActionNonceThatDoesNotMatchSafeTransactionNonce() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 2, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceTransaction.selector);
        relayA.processGSSMessage(txData, signatures);
    }

    function test_irrelevantFeeMessageDoesNotConsumeLocalNonce() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_B, CHAIN_B));
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.lastGovernanceSafeNonce(), ownerConfigSafeNonce);
        assertEq(relayA.protocolFeeInWei(3), 0);
        assertEq(relayA.protocolFeeInWei(4), 0);
    }

    function test_acceptsMoreValidSignaturesThanThreshold() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSSWithKeys(address(checker), action, _ownerKeys(), owners.length);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_rejectsInvalidSignatureSetsAndNormalizesRecoveryErrors() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory insufficient = _signWith(txData, _ownerKeys(), THRESHOLD - 1);

        uint256[] memory duplicateKeys = new uint256[](3);
        duplicateKeys[0] = keys[0];
        duplicateKeys[1] = keys[0];
        duplicateKeys[2] = keys[1];
        bytes memory duplicate = _signWith(txData, duplicateKeys, duplicateKeys.length);
        bytes memory malformed = bytes.concat(_signWith(txData, _ownerKeys(), THRESHOLD), hex"00");
        bytes memory oversized = bytes.concat(_signWith(txData, _ownerKeys(), owners.length), new bytes(65));
        bytes memory invalidV = bytes.concat(_signWith(txData, _ownerKeys(), THRESHOLD));
        invalidV[64] = bytes1(uint8(29));
        bytes memory highS = bytes.concat(_signWith(txData, _ownerKeys(), THRESHOLD));
        for (uint256 i = 32; i < 64; ++i) {
            highS[i] = 0xff;
        }

        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(txData, insufficient);

        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(txData, duplicate);

        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(txData, malformed);

        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(txData, oversized);

        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(txData, invalidV);

        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(txData, highS);
    }

    function test_rejectsDuplicateLocalFeeWithoutPartialUpdate() public {
        vm.chainId(SOURCE_CHAIN);
        Relay.GovernanceFeeUpdate[] memory updates = new Relay.GovernanceFeeUpdate[](2);
        updates[0] = Relay.GovernanceFeeUpdate(CHAIN_A, 3, 111);
        updates[1] = Relay.GovernanceFeeUpdate(CHAIN_A, 3, 222);
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, updates);
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceTransaction.selector);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 0);
        assertEq(relayA.lastGovernanceSafeNonce(), ownerConfigSafeNonce);
    }

    function test_checkerAndRelayRejectNonCanonicalFeeList() public {
        vm.chainId(SOURCE_CHAIN);
        Relay.GovernanceFeeUpdate[] memory updates = new Relay.GovernanceFeeUpdate[](2);
        updates[0] = Relay.GovernanceFeeUpdate(CHAIN_B, 4, 222);
        updates[1] = Relay.GovernanceFeeUpdate(CHAIN_A, 3, 111);
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, updates);
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.expectRevert();
        gss.execTransaction(
            txData.to,
            txData.value,
            txData.data,
            txData.operation,
            txData.safeTxGas,
            txData.baseGas,
            txData.gasPrice,
            txData.gasToken,
            payable(txData.refundReceiver),
            signatures
        );

        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceTransaction.selector);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 0);
        assertEq(relayA.lastGovernanceSafeNonce(), ownerConfigSafeNonce);
    }

    function test_rejectsEmptyFeeList() public {
        vm.chainId(SOURCE_CHAIN);
        Relay.GovernanceFeeUpdate[] memory updates = new Relay.GovernanceFeeUpdate[](0);
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, updates);
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceTransaction.selector);
        relayA.processGSSMessage(txData, signatures);
    }

    function test_maximumCanonicalFeeBatchIsExecutable() public {
        vm.chainId(SOURCE_CHAIN);
        Relay.GovernanceFeeUpdate[] memory updates = new Relay.GovernanceFeeUpdate[](256);
        for (uint256 i; i < updates.length; ++i) {
            updates[i] = Relay.GovernanceFeeUpdate(CHAIN_A, i + 2, i + 1);
        }
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, updates);
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(2), 1);
        assertEq(relayA.protocolFeeInWei(257), 256);
    }

    function test_rejectsFeeBatchAboveLimit() public {
        vm.chainId(SOURCE_CHAIN);
        Relay.GovernanceFeeUpdate[] memory updates = new Relay.GovernanceFeeUpdate[](257);
        for (uint256 i; i < updates.length; ++i) {
            updates[i] = Relay.GovernanceFeeUpdate(CHAIN_A, i + 2, i + 1);
        }
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, updates);
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceTransaction.selector);
        relayA.processGSSMessage(txData, signatures);
    }

    function test_gappedSafeNonceIsAccepted() public {
        vm.chainId(SOURCE_CHAIN);
        _executeThroughGSS(address(0xCAFE), bytes(""));
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.lastGovernanceSafeNonce(), 3);
    }

    function test_extremeFutureNonceCanExhaustFeeSequenceWithoutSourceExecution() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 terminalNonce = type(uint256).max;
        bytes memory terminalAction =
            abi.encodeWithSelector(CHANGE_FEES, terminalNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory terminalTx = _txTo(address(checker), terminalAction, terminalNonce - 1);
        bytes memory terminalSignatures = _signWith(terminalTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(terminalTx, terminalSignatures);
        assertEq(relayA.lastGovernanceSafeNonce(), terminalNonce);
        assertEq(relayA.protocolFeeInWei(3), 111);

        vm.chainId(SOURCE_CHAIN);
        uint256 lowerNonce = terminalNonce - 1;
        bytes memory lowerAction =
            abi.encodeWithSelector(CHANGE_FEES, lowerNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory lowerTx = _txTo(address(checker), lowerAction, lowerNonce - 1);
        bytes memory lowerSignatures = _signWith(lowerTx, _ownerKeys(), THRESHOLD);
        vm.chainId(CHAIN_A);
        vm.expectRevert(
            abi.encodeWithSelector(IRelayGovernance.GovernanceNonceNotMonotonic.selector, lowerNonce, terminalNonce)
        );
        relayA.processGSSMessage(lowerTx, lowerSignatures);
    }

    function test_higherNonceFeeDeliveredFirstSuppressesLowerNonceFee() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 lowerNonce = gss.nonce() + 2;
        uint256 higherNonce = lowerNonce + 2;
        Relay.GovernanceFeeUpdate[] memory lowerUpdates = _feeUpdates(CHAIN_A, CHAIN_B);
        lowerUpdates[0].feeInWei = 333;

        GnosisSafeTx.Transaction memory lowerTx = _txTo(
            address(checker), abi.encodeWithSelector(CHANGE_FEES, lowerNonce, ownerHash, lowerUpdates), lowerNonce - 1
        );
        bytes memory lowerSignatures = _signWith(lowerTx, _ownerKeys(), THRESHOLD);
        GnosisSafeTx.Transaction memory higherTx = _txTo(
            address(checker),
            abi.encodeWithSelector(CHANGE_FEES, higherNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)),
            higherNonce - 1
        );
        bytes memory higherSignatures = _signWith(higherTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(higherTx, higherSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        assertEq(relayA.lastGovernanceSafeNonce(), higherNonce);

        vm.expectRevert(
            abi.encodeWithSelector(IRelayGovernance.GovernanceNonceNotMonotonic.selector, lowerNonce, higherNonce)
        );
        relayA.processGSSMessage(lowerTx, lowerSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_sameSignedMessageAuthorizesTwoRelayDeploymentsOnSameChain() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);

        vm.chainId(CHAIN_A);
        Relay replacementWithoutFreshCutover = new Relay(_relayConfig(address(gss)), address(0), IRelay(address(0)));
        relayA.processGSSMessage(txData, signatures);
        replacementWithoutFreshCutover.processGSSMessage(txData, signatures);

        assertEq(relayA.protocolFeeInWei(3), 111);
        assertEq(replacementWithoutFreshCutover.protocolFeeInWei(3), 111);
    }

    function test_deploymentReplayFloorRejectsPredatingMessage() public {
        uint256 replayFloor = gss.nonce() + 5;
        IRelay.RelayInitialConfig memory config = _relayConfig(address(gss));
        config.governanceSafeNonce = replayFloor;

        vm.chainId(CHAIN_A);
        Relay laterRelay = new Relay(config, address(0), IRelay(address(0)));

        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, replayFloor, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, replayFloor - 1);
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRelayGovernance.GovernanceNonceBeforeReplayFloor.selector, replayFloor, replayFloor
            )
        );
        laterRelay.processGSSMessage(txData, signatures);
        assertEq(laterRelay.protocolFeeInWei(3), 0);
        assertFalse(laterRelay.governanceSafeNonceConsumed(replayFloor));
    }

    function test_conflictingTransactionsAtSameSafeNonceAreFirstDeliveryWins() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 actionNonce = gss.nonce() + 1;
        Relay.GovernanceFeeUpdate[] memory firstUpdates = _feeUpdates(CHAIN_A, CHAIN_B);
        Relay.GovernanceFeeUpdate[] memory secondUpdates = _feeUpdates(CHAIN_A, CHAIN_B);
        secondUpdates[0].feeInWei = 333;
        secondUpdates[1].feeInWei = 444;

        GnosisSafeTx.Transaction memory firstTx = _txTo(
            address(checker),
            abi.encodeWithSelector(CHANGE_FEES, actionNonce, ownerHash, firstUpdates),
            actionNonce - 1
        );
        GnosisSafeTx.Transaction memory secondTx = _txTo(
            address(checker),
            abi.encodeWithSelector(CHANGE_FEES, actionNonce, ownerHash, secondUpdates),
            actionNonce - 1
        );
        bytes memory firstSignatures = _signWith(firstTx, _ownerKeys(), THRESHOLD);
        bytes memory secondSignatures = _signWith(secondTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(firstTx, firstSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        assertTrue(relayA.governanceSafeNonceConsumed(actionNonce));
        vm.expectRevert(abi.encodeWithSelector(IRelayGovernance.GovernanceNonceAlreadyConsumed.selector, actionNonce));
        relayA.processGSSMessage(secondTx, secondSignatures);

        // Without source execution evidence, another target can see the other valid
        // transaction first. Each target remains internally one-action-per-nonce.
        vm.chainId(CHAIN_B);
        relayB.processGSSMessage(secondTx, secondSignatures);
        assertEq(relayB.protocolFeeInWei(4), 444);
        assertTrue(relayB.governanceSafeNonceConsumed(actionNonce));
        vm.expectRevert(abi.encodeWithSelector(IRelayGovernance.GovernanceNonceAlreadyConsumed.selector, actionNonce));
        relayB.processGSSMessage(firstTx, firstSignatures);
    }

    function test_delayedOwnerRotationCannotBeStrandedByHigherOldConfigFee() public {
        vm.chainId(SOURCE_CHAIN);
        address oldOwner = owners[0];
        address[] memory newOwners = _replaceOwner(owners, oldOwner, vm.addr(NEW_OWNER_KEY));
        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);

        uint256 rotationNonce = gss.nonce() + 1;
        (GnosisSafeTx.Transaction memory ownerTx, bytes memory ownerSignatures, bytes32 newOwnerHash) =
            _signedOwnerChange(rotationNonce, ownerHash, newOwners, _ownerKeys());

        uint256 oldConfigFeeNonce = rotationNonce + 5;
        bytes memory oldConfigFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, oldConfigFeeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory oldConfigFeeTx =
            _txTo(address(checker), oldConfigFeeAction, oldConfigFeeNonce - 1);
        bytes memory oldConfigFeeSignatures = _signWith(oldConfigFeeTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(oldConfigFeeTx, oldConfigFeeSignatures);
        assertEq(relayA.lastGovernanceSafeNonce(), oldConfigFeeNonce);

        relayA.processGSSMessage(ownerTx, ownerSignatures);
        assertEq(relayA.activeOwnerConfigHash(), newOwnerHash);
        assertEq(relayA.activeOwnerConfigSafeNonce(), rotationNonce);
        assertEq(relayA.lastGovernanceSafeNonce(), oldConfigFeeNonce);

        {
            vm.chainId(SOURCE_CHAIN);
            uint256 staleNewConfigFeeNonce = rotationNonce + 1;
            bytes memory staleNewConfigFeeAction = abi.encodeWithSelector(
                CHANGE_FEES, staleNewConfigFeeNonce, newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B)
            );
            GnosisSafeTx.Transaction memory staleNewConfigFeeTx =
                _txTo(address(checker), staleNewConfigFeeAction, staleNewConfigFeeNonce - 1);
            bytes memory staleNewConfigFeeSignatures = _signWith(staleNewConfigFeeTx, newKeys, THRESHOLD);
            vm.chainId(CHAIN_A);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IRelayGovernance.GovernanceNonceNotMonotonic.selector, staleNewConfigFeeNonce, oldConfigFeeNonce
                )
            );
            relayA.processGSSMessage(staleNewConfigFeeTx, staleNewConfigFeeSignatures);
        }

        vm.chainId(SOURCE_CHAIN);
        uint256 newConfigFeeNonce = oldConfigFeeNonce + 1;
        bytes memory newConfigFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, newConfigFeeNonce, newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory newConfigFeeTx =
            _txTo(address(checker), newConfigFeeAction, newConfigFeeNonce - 1);
        bytes memory newConfigFeeSignatures = _signWith(newConfigFeeTx, newKeys, THRESHOLD);
        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(newConfigFeeTx, newConfigFeeSignatures);
        assertEq(relayA.lastGovernanceSafeNonce(), newConfigFeeNonce);
    }

    function test_returningToSameOwnersDoesNotReviveOldFutureNonceMessage() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 staleFeeNonce = 10;
        bytes memory staleFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, staleFeeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory staleFeeTx = _txTo(address(checker), staleFeeAction, staleFeeNonce - 1);
        bytes memory staleFeeSignatures = _signWith(staleFeeTx, _ownerKeys(), THRESHOLD);

        address oldOwner = owners[0];
        address[] memory newOwners = _replaceOwner(owners, oldOwner, vm.addr(NEW_OWNER_KEY));
        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);
        uint256 firstRotationNonce = gss.nonce() + 1;
        bytes32 intermediateHash = _applyOwnerChange(relayA, firstRotationNonce, ownerHash, newOwners, _ownerKeys());

        vm.chainId(SOURCE_CHAIN);
        uint256 secondRotationNonce = firstRotationNonce + 1;
        bytes32 returnedOwnerHash = _applyOwnerChange(relayA, secondRotationNonce, intermediateHash, owners, newKeys);
        assertEq(relayA.activeOwnerConfigHash(), returnedOwnerHash);
        assertNotEq(returnedOwnerHash, ownerHash);

        vm.expectRevert(
            abi.encodeWithSelector(IRelayGovernance.GovernanceOwnerHashMismatch.selector, ownerHash, returnedOwnerHash)
        );
        relayA.processGSSMessage(staleFeeTx, staleFeeSignatures);
    }

    function test_safeCancellationDoesNotRevokeRemoteAuthorization() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeTxNonce = gss.nonce();
        bytes memory feeAction =
            abi.encodeWithSelector(CHANGE_FEES, safeTxNonce + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory canceledTx = _txTo(address(checker), feeAction, safeTxNonce);
        bytes memory canceledSignatures = _signWith(canceledTx, _ownerKeys(), THRESHOLD);

        _executeThroughGSS(address(gss), bytes(""));
        assertEq(gss.nonce(), safeTxNonce + 1);
        vm.expectRevert();
        gss.execTransaction(
            canceledTx.to,
            canceledTx.value,
            canceledTx.data,
            canceledTx.operation,
            canceledTx.safeTxGas,
            canceledTx.baseGas,
            canceledTx.gasPrice,
            canceledTx.gasToken,
            payable(canceledTx.refundReceiver),
            canceledSignatures
        );

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(canceledTx, canceledSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_removedOwnerRemainsAuthorizedUntilTargetInstallsRotation() public {
        vm.chainId(SOURCE_CHAIN);
        address oldOwner = gss.getOwners()[0];
        address newOwner = vm.addr(NEW_OWNER_KEY);
        address[] memory newOwners = _replaceOwner(owners, oldOwner, newOwner);
        uint256 rotationNonce = gss.nonce() + 1;
        bytes32 newOwnerHash =
            GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(gss), rotationNonce, THRESHOLD, newOwners);
        bytes memory ownerAction =
            abi.encodeWithSelector(checker.changeOwners.selector, rotationNonce, ownerHash, THRESHOLD, newOwners);
        (GnosisSafeTx.Transaction memory ownerTx, bytes memory ownerSignatures) =
            _executeThroughGSS(address(checker), ownerAction);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(ownerTx, ownerSignatures);

        vm.chainId(SOURCE_CHAIN);
        bytes memory swapData =
            abi.encodeWithSignature("swapOwner(address,address,address)", SENTINEL_OWNERS, oldOwner, newOwner);
        _executeThroughGSS(address(gss), swapData);

        uint256 staleActionNonce = gss.nonce() + 1;
        bytes memory staleFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, staleActionNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        GnosisSafeTx.Transaction memory staleFeeTx = _txTo(address(checker), staleFeeAction, staleActionNonce - 1);
        bytes memory staleFeeSignatures = _signWith(staleFeeTx, _keysIncludingOwner(oldOwner, THRESHOLD), THRESHOLD);

        // Relay A has the rotation and rejects the removed owner's old generation.
        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(staleFeeTx, staleFeeSignatures);

        // Relay B has not received the rotation, so its locally admitted old
        // generation still authorizes the message despite the live Safe change.
        vm.chainId(CHAIN_B);
        relayB.processGSSMessage(staleFeeTx, staleFeeSignatures);
        assertEq(relayB.protocolFeeInWei(4), 222);
        relayB.processGSSMessage(ownerTx, ownerSignatures);
        assertEq(relayB.activeOwnerConfigHash(), newOwnerHash);
    }

    function test_ownerRotationRequiresLocalInstallationBeforeNewOwnersCanGovern() public {
        vm.chainId(SOURCE_CHAIN);

        address[] memory safeOwners = gss.getOwners();
        address oldOwner = safeOwners[0];
        address newOwner = vm.addr(NEW_OWNER_KEY);
        address[] memory newOwners = _replaceOwner(owners, oldOwner, newOwner);
        uint256 rotationNonce = gss.nonce() + 1;
        bytes32 newOwnerHash =
            GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(gss), rotationNonce, THRESHOLD, newOwners);
        bytes memory ownerAction =
            abi.encodeWithSelector(checker.changeOwners.selector, rotationNonce, ownerHash, THRESHOLD, newOwners);
        (GnosisSafeTx.Transaction memory ownerTx, bytes memory ownerSignatures) =
            _executeThroughGSS(address(checker), ownerAction);
        assertEq(checker.activeOwnerConfigHash(), newOwnerHash);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(ownerTx, ownerSignatures);
        assertEq(relayA.activeOwnerConfigHash(), newOwnerHash);

        vm.chainId(SOURCE_CHAIN);
        bytes memory swapData =
            abi.encodeWithSignature("swapOwner(address,address,address)", SENTINEL_OWNERS, oldOwner, newOwner);
        _executeThroughGSS(address(gss), swapData);
        address[] memory actualOwners = gss.getOwners();
        _sort(actualOwners);
        assertEq(keccak256(abi.encode(actualOwners)), keccak256(abi.encode(newOwners)));
        assertTrue(checker.activeOwnerConfigurationIsLive());

        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);
        bytes memory feeAction =
            abi.encodeWithSelector(CHANGE_FEES, gss.nonce() + 1, newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (GnosisSafeTx.Transaction memory feeTx, bytes memory feeSignatures) =
            _executeThroughGSSWithKeys(address(checker), feeAction, newKeys, THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(feeTx, feeSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);

        vm.chainId(CHAIN_B);
        vm.expectRevert();
        relayB.processGSSMessage(feeTx, feeSignatures);
        relayB.processGSSMessage(ownerTx, ownerSignatures);
        relayB.processGSSMessage(feeTx, feeSignatures);
        assertEq(relayB.protocolFeeInWei(4), 222);
    }

    function test_checkerRejectsFeesWhileOwnerRotationIsStaged() public {
        vm.chainId(SOURCE_CHAIN);

        address oldOwner = gss.getOwners()[0];
        address[] memory newOwners = _replaceOwner(owners, oldOwner, vm.addr(NEW_OWNER_KEY));
        uint256 rotationNonce = gss.nonce() + 1;
        bytes32 newOwnerHash =
            GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(gss), rotationNonce, THRESHOLD, newOwners);
        bytes memory ownerAction =
            abi.encodeWithSelector(checker.changeOwners.selector, rotationNonce, ownerHash, THRESHOLD, newOwners);
        _executeThroughGSS(address(checker), ownerAction);
        assertFalse(checker.activeOwnerConfigurationIsLive());

        uint256 nonceBeforeRejectedFee = gss.nonce();
        bytes memory feeAction = abi.encodeWithSelector(
            CHANGE_FEES, nonceBeforeRejectedFee + 1, newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        GnosisSafeTx.Transaction memory feeTx = _txTo(address(checker), feeAction, nonceBeforeRejectedFee);
        bytes memory signatures = _signWith(feeTx, _ownerKeys(), THRESHOLD);

        vm.expectRevert();
        gss.execTransaction(address(checker), 0, feeAction, 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertEq(gss.nonce(), nonceBeforeRejectedFee);
        assertEq(checker.latestSafeNonce(), nonceBeforeRejectedFee);

        bytes memory restageAction =
            abi.encodeWithSelector(checker.changeOwners.selector, gss.nonce() + 1, newOwnerHash, THRESHOLD, owners);
        GnosisSafeTx.Transaction memory restageTx = _txTo(address(checker), restageAction, gss.nonce());
        bytes memory restageSignatures = _signWith(restageTx, _ownerKeys(), THRESHOLD);
        vm.expectRevert();
        gss.execTransaction(
            address(checker), 0, restageAction, 0, 0, 0, 0, address(0), payable(address(0)), restageSignatures
        );
        assertEq(gss.nonce(), nonceBeforeRejectedFee);
        assertEq(checker.activeOwnerConfigHash(), newOwnerHash);
        assertFalse(checker.activeOwnerConfigurationIsLive());
    }

    function test_governanceConfigurationRequiresRelayModeAndNoOldRelay() public {
        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceDeployment.selector);
        new Relay(_relayConfig(address(gss)), address(this), IRelay(address(0)));

        vm.expectRevert(IRelayGovernance.InvalidGovernanceDeployment.selector);
        new Relay(_relayConfig(address(gss)), address(0), IRelay(address(relayA)));

        IRelay.RelayInitialConfig memory invalidConfig = _relayConfig(address(gss));
        invalidConfig.governanceOwnerConfigSafeNonce = invalidConfig.governanceSafeNonce + 1;
        vm.expectRevert(IRelayGovernance.InvalidGovernanceOwnerConfiguration.selector);
        new Relay(invalidConfig, address(0), IRelay(address(0)));
    }

    function _relayConfig(address safe) internal view returns (IRelay.RelayInitialConfig memory c) {
        c.initialRewardEpochId = 1;
        c.startingVotingRoundIdForInitialRewardEpochId = 1;
        c.initialSigningPolicyHash = bytes32(uint256(1));
        c.randomNumberProtocolId = 2;
        c.firstVotingRoundStartTs = 1;
        c.votingEpochDurationSeconds = 1;
        c.firstRewardEpochStartVotingRoundId = 0;
        c.rewardEpochDurationInVotingEpochs = 1;
        c.thresholdIncreaseBIPS = 10000;
        c.messageFinalizationWindowInRewardEpochs = 1;
        c.feeCollectionAddress = payable(address(0xfee));
        c.sourceChainId = SOURCE_CHAIN;
        c.governanceSafe = safe;
        c.governanceThreshold = THRESHOLD;
        c.governanceOwners = owners;
        c.governanceOwnerConfigSafeNonce = ownerConfigSafeNonce;
        c.governanceSafeNonce = ownerConfigSafeNonce;
    }

    function _feeUpdates(uint256 a, uint256 b) internal pure returns (Relay.GovernanceFeeUpdate[] memory u) {
        u = new Relay.GovernanceFeeUpdate[](2);
        u[0] = Relay.GovernanceFeeUpdate(a, 3, 111);
        u[1] = Relay.GovernanceFeeUpdate(b, 4, 222);
    }

    function _tx(bytes memory data, uint256 nonce) internal view returns (GnosisSafeTx.Transaction memory t) {
        return _txTo(address(checker), data, nonce);
    }

    function _txTo(address target, bytes memory data, uint256 nonce)
        internal
        pure
        returns (GnosisSafeTx.Transaction memory t)
    {
        t.to = target;
        t.data = data;
        t.nonce = nonce;
    }

    function _copyTransaction(GnosisSafeTx.Transaction memory source)
        internal
        pure
        returns (GnosisSafeTx.Transaction memory target)
    {
        target = GnosisSafeTx.Transaction(
            source.to,
            source.value,
            source.data,
            source.operation,
            source.safeTxGas,
            source.baseGas,
            source.gasPrice,
            source.gasToken,
            source.refundReceiver,
            source.nonce
        );
    }

    function _signWith(GnosisSafeTx.Transaction memory t, uint256[] memory signingKeys, uint256 signatureCount)
        internal
        view
        returns (bytes memory out)
    {
        require(signatureCount <= signingKeys.length, "too many requested signatures");
        // Safe v1.3.0 requires owner signatures in strictly ascending address order.
        for (uint256 i; i < signingKeys.length; ++i) {
            for (uint256 j = i + 1; j < signingKeys.length; ++j) {
                if (vm.addr(signingKeys[j]) < vm.addr(signingKeys[i])) {
                    (signingKeys[i], signingKeys[j]) = (signingKeys[j], signingKeys[i]);
                }
            }
        }
        bytes32 digest = IRealGSS(address(gss))
            .getTransactionHash(
                t.to,
                t.value,
                t.data,
                t.operation,
                t.safeTxGas,
                t.baseGas,
                t.gasPrice,
                t.gasToken,
                t.refundReceiver,
                t.nonce
            );
        for (uint256 i; i < signatureCount; ++i) {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKeys[i], digest);
            out = bytes.concat(out, abi.encodePacked(r, s, v));
        }
    }

    function _sort(address[] memory values) internal pure {
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

    function _executeThroughGSS(address target, bytes memory data)
        internal
        returns (GnosisSafeTx.Transaction memory txData, bytes memory signatures)
    {
        return _executeThroughGSSWithKeys(target, data, _ownerKeys(), THRESHOLD);
    }

    function _executeThroughGSSWithKeys(
        address target,
        bytes memory data,
        uint256[] memory signingKeys,
        uint256 signatureCount
    ) internal returns (GnosisSafeTx.Transaction memory txData, bytes memory signatures) {
        uint256 safeNonce = gss.nonce();
        txData = _txTo(target, data, safeNonce);
        signatures = _signWith(txData, signingKeys, signatureCount);
        bool success = gss.execTransaction(target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertTrue(success);
    }

    function _signedOwnerChange(
        uint256 actionNonce,
        bytes32 currentHash,
        address[] memory nextOwners,
        uint256[] memory signingKeys
    ) internal view returns (GnosisSafeTx.Transaction memory txData, bytes memory signatures, bytes32 nextHash) {
        nextHash = GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(gss), actionNonce, THRESHOLD, nextOwners);
        bytes memory action =
            abi.encodeWithSelector(checker.changeOwners.selector, actionNonce, currentHash, THRESHOLD, nextOwners);
        txData = _txTo(address(checker), action, actionNonce - 1);
        signatures = _signWith(txData, signingKeys, THRESHOLD);
    }

    function _applyOwnerChange(
        Relay target,
        uint256 actionNonce,
        bytes32 currentHash,
        address[] memory nextOwners,
        uint256[] memory signingKeys
    ) internal returns (bytes32 nextHash) {
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures, bytes32 expectedHash) =
            _signedOwnerChange(actionNonce, currentHash, nextOwners, signingKeys);
        vm.chainId(CHAIN_A);
        target.processGSSMessage(txData, signatures);
        return expectedHash;
    }

    function _ownerKeys() internal view returns (uint256[] memory result) {
        result = new uint256[](keys.length);
        for (uint256 i; i < keys.length; ++i) {
            result[i] = keys[i];
        }
    }

    function _keysIncludingOwner(address requiredOwner, uint256 count)
        internal
        view
        returns (uint256[] memory result)
    {
        result = new uint256[](count);
        uint256 requiredKey;
        for (uint256 i; i < keys.length; ++i) {
            if (vm.addr(keys[i]) == requiredOwner) {
                requiredKey = keys[i];
                break;
            }
        }
        require(requiredKey != 0, "required owner key not found");
        result[0] = requiredKey;
        uint256 position = 1;
        for (uint256 i; i < keys.length && position < count; ++i) {
            if (keys[i] != requiredKey) result[position++] = keys[i];
        }
        require(position == count, "not enough owner keys");
    }

    function _replaceOwner(address[] memory currentOwners, address oldOwner, address newOwner)
        internal
        pure
        returns (address[] memory result)
    {
        result = currentOwners;
        bool replaced;
        for (uint256 i; i < result.length; ++i) {
            if (result[i] == oldOwner) {
                result[i] = newOwner;
                replaced = true;
                break;
            }
        }
        require(replaced, "owner not found");
        _sort(result);
    }

    function _replaceOwnerKey(uint256[] memory currentKeys, address oldOwner, uint256 newKey)
        internal
        view
        returns (uint256[] memory result)
    {
        result = currentKeys;
        bool replaced;
        for (uint256 i; i < result.length; ++i) {
            if (vm.addr(result[i]) == oldOwner) {
                result[i] = newKey;
                replaced = true;
                break;
            }
        }
        require(replaced, "owner key not found");
    }
}
