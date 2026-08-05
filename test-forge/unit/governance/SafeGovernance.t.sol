// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IRelayGovernance} from "../../../contracts/userInterfaces/IRelayGovernance.sol";
import {ISafeGovernance} from "../../../contracts/userInterfaces/ISafeGovernance.sol";
import {SafeGovernance} from "../../../contracts/governance/lib/SafeGovernance.sol";
import {SafeInstructions} from "../../../contracts/governance/implementation/SafeInstructions.sol";
import {SafeInstructionsProxy} from "../../../contracts/governance/implementation/SafeInstructionsProxy.sol";
import {RelayProxy} from "../../../contracts/protocol/implementation/RelayProxy.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {GnosisSafeL2} from "@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

interface IRealSafe {
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

contract SafeGovernanceTest is Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant CHAIN_A = 100;
    uint256 internal constant CHAIN_B = 200;
    uint256 internal constant THRESHOLD = 3;
    uint256 internal constant NEW_OWNER_KEY = 16;
    address internal constant SENTINEL_OWNERS = address(0x1);
    bytes4 internal constant CHANGE_FEES =
        bytes4(keccak256("changeProtocolFees(uint256,bytes32,(uint256,address,uint8,uint256)[])"));
    bytes4 internal constant CHANGE_EXEMPTIONS =
        bytes4(keccak256("changeFeeExemptions(uint256,bytes32,(uint256,address,address,bool)[])"));
    bytes4 internal constant CHANGE_FEE_COLLECTION =
        bytes4(keccak256("changeFeeCollectionAddresses(uint256,bytes32,(uint256,address,address)[])"));

    uint256[5] internal keys = [uint256(11), 12, 13, 14, 15];
    address[] internal owners;
    IRealSafe internal safe;
    SafeInstructions internal checker;
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
        safe = IRealSafe(address(proxy));
        safe.setup(owners, THRESHOLD, address(0), bytes(""), address(0), address(0), 0, payable(address(0)));
        SafeInstructions checkerImplementation = new SafeInstructions();
        checker = SafeInstructions(
            address(
                new SafeInstructionsProxy(
                    IGovernanceSettings(makeAddr("governanceSettings")),
                    makeAddr("flareGovernance"),
                    makeAddr("addressUpdater"),
                    address(checkerImplementation),
                    address(safe)
                )
            )
        );
        // initialize admits the live Safe configuration as generation 0 — no bootstrap.
        ownerConfigSafeNonce = checker.activeOwnerConfigSafeNonce();
        ownerHash = checker.activeOwnerConfigHash();
        // Advance the Safe past the deployment generation (mirrors a production Safe with
        // history; rotations must sign a nonce strictly above generation 0).
        _executeThroughSafe(address(0xCAFE), bytes(""));

        vm.chainId(CHAIN_A);
        relayA = _deployRelay(_relayConfig(address(safe)), address(0), IRelay(address(0)));
        vm.chainId(CHAIN_B);
        relayB = _deployRelay(_relayConfig(address(safe)), address(0), IRelay(address(0)));
    }

    function test_setupIsThreeOfFiveAndCheckerMatchesSafe() public {
        assertEq(ISafeGovernance.InvalidGovernanceSource.selector, bytes4(keccak256("InvalidGovernanceSource()")));
        assertEq(
            ISafeGovernance.InvalidGovernanceOwnerConfiguration.selector,
            bytes4(keccak256("InvalidGovernanceOwnerConfiguration()"))
        );
        assertEq(
            ISafeGovernance.InvalidGovernanceTransaction.selector, bytes4(keccak256("InvalidGovernanceTransaction()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceSignatures.selector, bytes4(keccak256("InvalidGovernanceSignatures()"))
        );
        assertEq(
            ISafeGovernance.UnknownGovernanceAction.selector, bytes4(keccak256("UnknownGovernanceAction(bytes4)"))
        );
        assertEq(
            ISafeGovernance.GovernanceOwnerHashMismatch.selector,
            bytes4(keccak256("GovernanceOwnerHashMismatch(bytes32,bytes32)"))
        );
        assertEq(
            ISafeGovernance.GovernanceNonceNotMonotonic.selector,
            bytes4(keccak256("GovernanceNonceNotMonotonic(uint256,uint256)"))
        );
        assertEq(
            ISafeGovernance.GovernanceNonceBeforeReplayFloor.selector,
            bytes4(keccak256("GovernanceNonceBeforeReplayFloor(uint256,uint256)"))
        );
        assertEq(
            ISafeGovernance.GovernanceNonceAlreadyConsumed.selector,
            bytes4(keccak256("GovernanceNonceAlreadyConsumed(uint256)"))
        );
        assertEq(
            ISafeGovernance.GovernanceOwnerConfigNonceNotIncreasing.selector,
            bytes4(keccak256("GovernanceOwnerConfigNonceNotIncreasing(uint256,uint256)"))
        );

        assertEq(checker.sourceChainId(), SOURCE_CHAIN);
        assertEq(checker.activeOwnerConfigHash(), ownerHash);
        assertEq(checker.activeOwnerConfigSafeNonce(), ownerConfigSafeNonce);
        assertEq(ownerConfigSafeNonce, 0); // the initialize-admitted deployment generation
        assertEq(checker.nextSafeNonce(), 0); // no instruction accepted yet
        assertTrue(checker.activeOwnerConfigurationIsLive());
        (, uint256 activeNonce) = relayA.governanceOwnerConfig();
        (uint256 floor,) = relayA.governanceNonces();
        assertEq(activeNonce, ownerConfigSafeNonce);
        assertEq(floor, ownerConfigSafeNonce);
    }

    function testFuzz_everySafeTransactionFieldIsBound(uint8 fieldSeed, uint64 mutationSeed) public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = safe.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory original = _txTo(address(checker), action, safeNonce);
        original.safeTxGas = 100_000;
        original.baseGas = 21_000;
        original.gasPrice = 7;
        original.gasToken = address(0x1234);
        original.refundReceiver = address(0x5678);
        bytes memory signatures = _signWith(original, _ownerKeys(), THRESHOLD);

        ISafeGovernance.SafeTx memory mutated = _copyTransaction(original);
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
        relayA.processSafeMessage(mutated, signatures);
        assertEq(relayA.protocolFeeInWei(3), 0);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, ownerConfigSafeNonce);
        assertFalse(relayA.governanceSafeNonceConsumed(safeNonce));
    }

    function test_feeMessageWorksOnTwoIndependentTargetChains() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = safe.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        assertEq(relayA.protocolFeeInWei(4), 0);

        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(txData, signatures);
        assertEq(relayB.protocolFeeInWei(4), 222);
        assertEq(relayB.protocolFeeInWei(3), 0);
    }

    function test_rejectsReplayAndModifiedAction() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = safe.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(checker), action);
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        vm.expectRevert();
        relayA.processSafeMessage(txData, signatures);

        bytes memory modified =
            abi.encodeWithSelector(CHANGE_FEES, uint256(2), ownerHash, _feeUpdates(CHAIN_A, CHAIN_A));
        vm.expectRevert();
        relayA.processSafeMessage(_tx(modified, 2), signatures);

        ISafeGovernance.SafeTx memory modifiedTarget = txData;
        modifiedTarget.to = address(0xBEEF);
        // Signatures over a different digest recover to pseudorandom non-owners; the exact
        // typed error (UnknownSigner vs SignersNotSorted) depends on the recovered values.
        vm.expectRevert();
        relayA.processSafeMessage(modifiedTarget, signatures);
    }

    function test_acceptsMessageExecutedThroughAnyCompatibleHelper() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory feeAction =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(0xCAFE), feeAction);
        assertEq(txData.to, address(0xCAFE));

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_targetDeploymentDoesNotRequireSourceSafeCode() public {
        vm.chainId(CHAIN_A);
        address sourceOnlySafe = address(0x123456789);
        assertEq(sourceOnlySafe.code.length, 0);
        Relay targetRelay = _deployRelay(_relayConfig(sourceOnlySafe), address(0), IRelay(address(0)));
        (address targetSafe,,) = targetRelay.governanceSigners();
        assertEq(targetSafe, sourceOnlySafe);
    }

    function test_rejectsActionNonceThatDoesNotMatchSafeTransactionNonce() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            // one above the envelope = exactly the retired (+1) convention; must be rejected
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, safe.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        vm.expectRevert(ISafeGovernance.InvalidGovernanceTransaction.selector);
        relayA.processSafeMessage(txData, signatures);
    }

    function test_irrelevantFeeMessageDoesNotConsumeLocalNonce() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, _feeUpdates(CHAIN_B, CHAIN_B));
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, ownerConfigSafeNonce);
        assertEq(relayA.protocolFeeInWei(3), 0);
        assertEq(relayA.protocolFeeInWei(4), 0);
    }

    function test_acceptsMoreValidSignaturesThanThreshold() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafeWithKeys(address(checker), action, _ownerKeys(), owners.length);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_ethSignFlavouredSignaturesAuthorizeGovernanceEndToEnd() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = safe.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, safeNonce);
        // Mixed signature set: alternating direct EIP-712 (v = 27/28) and eth_sign flavour
        // (v = 31/32) — exactly what Safe v1.3.0 checkNSignatures accepts.
        bytes memory signatures = _signWithMixedFlavours(txData, _ownerKeys(), THRESHOLD);
        bool success = safe.execTransaction(
            txData.to, 0, action, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        assertTrue(success);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_feeExemptionsApplyAcrossChainsFromOneInstruction() public {
        address dvn = makeAddr("dvnAdapter");
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = safe.nonce();
        bytes memory action =
            abi.encodeWithSelector(CHANGE_EXEMPTIONS, safeNonce, ownerHash, _feeExemptions(CHAIN_A, CHAIN_B, dvn));
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertTrue(relayA.feeExemptAddress(dvn));
        assertTrue(relayA.governanceSafeNonceConsumed(safeNonce));

        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(txData, signatures);
        assertTrue(relayB.feeExemptAddress(dvn));

        // revocation round-trips through the same grammar
        vm.chainId(SOURCE_CHAIN);
        SafeGovernance.GovernanceFeeExemption[] memory revocation =
            new SafeGovernance.GovernanceFeeExemption[](1);
        revocation[0] = SafeGovernance.GovernanceFeeExemption(CHAIN_A, address(relayA), dvn, false);
        bytes memory revokeAction =
            abi.encodeWithSelector(CHANGE_EXEMPTIONS, safe.nonce(), ownerHash, revocation);
        (ISafeGovernance.SafeTx memory revokeTx, bytes memory revokeSignatures) =
            _executeThroughSafe(address(checker), revokeAction);
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(revokeTx, revokeSignatures);
        assertFalse(relayA.feeExemptAddress(dvn));
    }

    function test_feeCollectionAddressUpdatesAcrossChainsFromOneInstruction() public {
        address collectorA = makeAddr("collectorA");
        address collectorB = makeAddr("collectorB");
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = safe.nonce();
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEE_COLLECTION,
            safeNonce,
            ownerHash,
            _feeCollections(CHAIN_A, address(relayA), collectorA, CHAIN_B, address(relayB), collectorB)
        );
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.feeCollectionAddress(), collectorA);
        assertTrue(relayA.governanceSafeNonceConsumed(safeNonce));

        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(txData, signatures);
        assertEq(relayB.feeCollectionAddress(), collectorB);
        assertTrue(relayB.governanceSafeNonceConsumed(safeNonce));
    }

    function test_sourceRejectsNonCanonicalFeeCollectionListButTargetAppliesLastWins() public {
        vm.chainId(SOURCE_CHAIN);
        address cx = makeAddr("collectorX");
        address cy = makeAddr("collectorY");
        SafeGovernance.GovernanceFeeCollection[] memory updates = new SafeGovernance.GovernanceFeeCollection[](2);
        // duplicate (chainId, targetAddress) pair — rejected at the source gate, last-write-wins on target
        updates[0] = SafeGovernance.GovernanceFeeCollection(CHAIN_A, address(relayA), cx);
        updates[1] = SafeGovernance.GovernanceFeeCollection(CHAIN_A, address(relayA), cy);
        bytes memory action = abi.encodeWithSelector(CHANGE_FEE_COLLECTION, safe.nonce(), ownerHash, updates);
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, safe.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        // Source SafeInstructions rejects the non-canonical (duplicate) list — quality gate intact.
        vm.expectRevert();
        safe.execTransaction(
            txData.to, 0, action, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );

        // A relayer could still carry the signed action to a target; it applies only its own
        // entries, last-write-wins for the duplicate (recipient nonzero, so no burn).
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.feeCollectionAddress(), cy);
    }

    function test_setterModeRelayCarriesSafeGovernanceAndAppliesExemptionsButNeverFees() public {
        // Home (Flare) deployment: signing-policy setter AND Safe governance. RLY-23
        // home-force requires the setter relay to live on the source chain itself.
        vm.chainId(SOURCE_CHAIN);
        IRelay.RelayInitialConfig memory config = _relayConfig(address(safe));
        config.feeCollectionAddress = payable(address(0));
        Relay setterRelay = _deployRelay(config, address(this), IRelay(address(0)));
        (address setterSafe,,) = setterRelay.governanceSigners();
        assertEq(setterSafe, address(safe));
        assertEq(setterRelay.sourceChainId(), SOURCE_CHAIN);

        address dvn = makeAddr("dvnAdapter");
        uint256 exemptionNonce = safe.nonce();
        bytes memory exemptionAction = abi.encodeWithSelector(
            CHANGE_EXEMPTIONS,
            exemptionNonce,
            ownerHash,
            _feeExemptionsFor(SOURCE_CHAIN, address(setterRelay), CHAIN_B, address(relayB), dvn)
        );
        (ISafeGovernance.SafeTx memory exemptionTx, bytes memory exemptionSignatures) =
            _executeThroughSafe(address(checker), exemptionAction);

        setterRelay.processSafeMessage(exemptionTx, exemptionSignatures);
        assertTrue(setterRelay.feeExemptAddress(dvn));
        assertTrue(setterRelay.governanceSafeNonceConsumed(exemptionNonce));

        // A fee action — even one addressed to THIS deployment — is foreign on a
        // setter-mode relay: verified but NOT consumed and no fee is ever set.
        uint256 feeNonce = safe.nonce();
        bytes memory feeAction = abi.encodeWithSelector(
            CHANGE_FEES,
            feeNonce,
            ownerHash,
            _feeUpdatesFor(SOURCE_CHAIN, address(setterRelay), CHAIN_B, address(relayB))
        );
        (ISafeGovernance.SafeTx memory feeTx, bytes memory feeSignatures) =
            _executeThroughSafe(address(checker), feeAction);
        setterRelay.processSafeMessage(feeTx, feeSignatures);
        assertEq(setterRelay.protocolFeeInWei(3), 0);
        assertFalse(setterRelay.governanceSafeNonceConsumed(feeNonce));
        (, uint256 lastNonce) = setterRelay.governanceNonces();
        assertEq(lastNonce, exemptionNonce);
    }

    function test_sourceRejectsNonCanonicalExemptionListButTargetApplies() public {
        address dvn = makeAddr("dvnAdapter");
        vm.chainId(SOURCE_CHAIN);
        SafeGovernance.GovernanceFeeExemption[] memory updates =
            new SafeGovernance.GovernanceFeeExemption[](2);
        // CHAIN_B before CHAIN_A — non-canonical, rejected at the source gate.
        updates[0] = SafeGovernance.GovernanceFeeExemption(CHAIN_B, address(relayB), dvn, true);
        updates[1] = SafeGovernance.GovernanceFeeExemption(CHAIN_A, address(relayA), dvn, true);
        bytes memory action = abi.encodeWithSelector(CHANGE_EXEMPTIONS, safe.nonce(), ownerHash, updates);
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, safe.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.expectRevert();
        safe.execTransaction(
            txData.to, 0, action, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );

        // The target applies its own entry (CHAIN_A) regardless of the list's global ordering.
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertTrue(relayA.feeExemptAddress(dvn));
    }

    function test_extraNonOwnerSignatureRevertsEvenWithThresholdOwners() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, safe.nonce());
        uint256 strangerKey = 99;
        uint256[] memory signingKeys = new uint256[](keys.length);
        signingKeys[0] = strangerKey;
        for (uint256 i = 1; i < keys.length; ++i) {
            signingKeys[i] = keys[i];
        }
        // Four valid owners reach the threshold, but the stranger's signature poisons the set:
        // relayers must strip non-owner chunks before submitting.
        bytes memory signatures = _signWith(txData, signingKeys, signingKeys.length);

        vm.chainId(CHAIN_A);
        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.UnknownSigner.selector, vm.addr(strangerKey)));
        relayA.processSafeMessage(txData, signatures);
    }

    function test_rejectsInvalidSignatureSetsAndNormalizesRecoveryErrors() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, safe.nonce());
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
        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.ThresholdNotReached.selector, THRESHOLD - 1, THRESHOLD)
        );
        relayA.processSafeMessage(txData, insufficient);

        vm.expectRevert(ISafeGovernance.SignersNotSorted.selector);
        relayA.processSafeMessage(txData, duplicate);

        vm.expectRevert(ISafeGovernance.InvalidSignaturesLength.selector);
        relayA.processSafeMessage(txData, malformed);

        // The appended all-zero chunk parses as v == 0 (EIP-1271 marker) — unsupported remotely.
        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.UnsupportedSignatureType.selector, 0));
        relayA.processSafeMessage(txData, oversized);

        vm.expectRevert(ECDSA.ECDSAInvalidSignature.selector);
        relayA.processSafeMessage(txData, invalidV);

        vm.expectRevert(
            abi.encodeWithSelector(ECDSA.ECDSAInvalidSignatureS.selector, bytes32(type(uint256).max))
        );
        relayA.processSafeMessage(txData, highS);
    }

    function test_duplicateLocalFeeAppliesLastWins() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 n = safe.nonce();
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](2);
        updates[0] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), 3, 111);
        updates[1] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), 3, 222);
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, n, ownerHash, updates);
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, n);
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        // The source rejects duplicates; if a signed duplicate still reaches a target it applies
        // deterministically (last write wins) and consumes the nonce — no partial-state hazard.
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 222);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, n);
    }

    function test_sourceRejectsNonCanonicalFeeListButTargetApplies() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 n = safe.nonce();
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](2);
        // CHAIN_B before CHAIN_A — non-canonical, rejected at the source gate.
        updates[0] = SafeGovernance.GovernanceFeeUpdate(CHAIN_B, address(relayB), 4, 222);
        updates[1] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), 3, 111);
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, n, ownerHash, updates);
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, n);
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.expectRevert();
        safe.execTransaction(
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

        // The target applies its own entry (CHAIN_A, protocol 3) regardless of global ordering.
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, n);
    }

    function test_emptyFeeListIsForeignNoOpOnTarget() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 n = safe.nonce();
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](0);
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, n, ownerHash, updates);
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, n);
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        // The source rejects an empty list; on a target no entry matches, so the action is
        // foreign — verified but not consumed, no state change (same as any irrelevant action).
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertFalse(relayA.governanceSafeNonceConsumed(n));
    }

    function test_maximumCanonicalFeeBatchIsExecutable() public {
        vm.chainId(SOURCE_CHAIN);
        // protocolId is uint8, so the maximum strictly-increasing (canonical) batch for one
        // deployment is protocol ids 2..255 = 254 entries.
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](254);
        for (uint256 i; i < updates.length; ++i) {
            updates[i] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), uint8(i + 2), i + 1);
        }
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, updates);
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(2), 1);
        assertEq(relayA.protocolFeeInWei(255), 254);
    }

    function test_feeBatchAboveSourceLimitStillAppliesOnTarget() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 n = safe.nonce();
        // 257 entries exceeds the source's 256-entry MAX bound; the target has no cap and allows
        // duplicates, so protocol ids repeat within uint8 (last-write-wins) and the batch applies.
        SafeGovernance.GovernanceFeeUpdate[] memory updates = new SafeGovernance.GovernanceFeeUpdate[](257);
        for (uint256 i; i < updates.length; ++i) {
            updates[i] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, address(relayA), uint8(2 + (i % 250)), i + 1);
        }
        bytes memory action = abi.encodeWithSelector(CHANGE_FEES, n, ownerHash, updates);
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, n);
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        // The source SafeInstructions bounds the batch to 256; a target has no explicit cap
        // (gas self-limits), so a hand-signed 257-entry batch applies (nonce consumed).
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        assertTrue(relayA.governanceSafeNonceConsumed(n));
        // protocol id 2 appears at i = 0 and i = 250; last write (i = 250) wins.
        assertEq(relayA.protocolFeeInWei(2), 251);
    }

    function test_gappedSafeNonceIsAccepted() public {
        vm.chainId(SOURCE_CHAIN);
        _executeThroughSafe(address(0xCAFE), bytes(""));
        bytes memory action =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures) =
            _executeThroughSafe(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(txData, signatures);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, 2);
    }

    function test_extremeFutureNonceCanExhaustFeeSequenceWithoutSourceExecution() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 terminalNonce = type(uint256).max;
        bytes memory terminalAction =
            abi.encodeWithSelector(CHANGE_FEES, terminalNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory terminalTx = _txTo(address(checker), terminalAction, terminalNonce);
        bytes memory terminalSignatures = _signWith(terminalTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(terminalTx, terminalSignatures);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, terminalNonce);
        assertEq(relayA.protocolFeeInWei(3), 111);

        vm.chainId(SOURCE_CHAIN);
        uint256 lowerNonce = terminalNonce - 1;
        bytes memory lowerAction =
            abi.encodeWithSelector(CHANGE_FEES, lowerNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory lowerTx = _txTo(address(checker), lowerAction, lowerNonce);
        bytes memory lowerSignatures = _signWith(lowerTx, _ownerKeys(), THRESHOLD);
        vm.chainId(CHAIN_A);
        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.GovernanceNonceNotMonotonic.selector, lowerNonce, terminalNonce)
        );
        relayA.processSafeMessage(lowerTx, lowerSignatures);
    }

    function test_higherNonceFeeDeliveredFirstSuppressesLowerNonceFee() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 lowerNonce = safe.nonce() + 2;
        uint256 higherNonce = lowerNonce + 2;
        SafeGovernance.GovernanceFeeUpdate[] memory lowerUpdates = _feeUpdates(CHAIN_A, CHAIN_B);
        lowerUpdates[0].feeInWei = 333;

        ISafeGovernance.SafeTx memory lowerTx = _txTo(
            address(checker), abi.encodeWithSelector(CHANGE_FEES, lowerNonce, ownerHash, lowerUpdates), lowerNonce
        );
        bytes memory lowerSignatures = _signWith(lowerTx, _ownerKeys(), THRESHOLD);
        ISafeGovernance.SafeTx memory higherTx = _txTo(
            address(checker),
            abi.encodeWithSelector(CHANGE_FEES, higherNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)),
            higherNonce
        );
        bytes memory higherSignatures = _signWith(higherTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(higherTx, higherSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, higherNonce);

        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.GovernanceNonceNotMonotonic.selector, lowerNonce, higherNonce)
        );
        relayA.processSafeMessage(lowerTx, lowerSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_feeEntriesAddressEachDeploymentOnOneChainIndividually() public {
        // Two deployments on the SAME chain: every fee entry addresses exactly one of
        // them, so one signed batch governs both independently while an entry addressed
        // to only one is verified-but-foreign (nonce not consumed) on the other.
        vm.chainId(CHAIN_A);
        Relay second = _deployRelay(_relayConfig(address(safe)), address(0), IRelay(address(0)));
        (address lo, address hi) = address(relayA) < address(second)
            ? (address(relayA), address(second))
            : (address(second), address(relayA));

        vm.chainId(SOURCE_CHAIN);
        SafeGovernance.GovernanceFeeUpdate[] memory batch = new SafeGovernance.GovernanceFeeUpdate[](2);
        batch[0] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, lo, 3, 111);
        batch[1] = SafeGovernance.GovernanceFeeUpdate(CHAIN_A, hi, 3, 333);
        uint256 batchNonce = safe.nonce();
        bytes memory batchAction = abi.encodeWithSelector(CHANGE_FEES, batchNonce, ownerHash, batch);
        (ISafeGovernance.SafeTx memory batchTx, bytes memory batchSignatures) =
            _executeThroughSafe(address(checker), batchAction);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(batchTx, batchSignatures);
        second.processSafeMessage(batchTx, batchSignatures);
        assertEq(relayA.protocolFeeInWei(3), address(relayA) == lo ? 111 : 333);
        assertEq(second.protocolFeeInWei(3), address(second) == lo ? 111 : 333);
        assertTrue(relayA.governanceSafeNonceConsumed(batchNonce));
        assertTrue(second.governanceSafeNonceConsumed(batchNonce));

        // Addressed to relayA only: `second` verifies it but applies and consumes nothing.
        vm.chainId(SOURCE_CHAIN);
        uint256 soloNonce = safe.nonce();
        bytes memory soloAction = abi.encodeWithSelector(
            CHANGE_FEES, soloNonce, ownerHash, _feeUpdatesFor(CHAIN_A, address(relayA), CHAIN_B, address(relayB))
        );
        (ISafeGovernance.SafeTx memory soloTx, bytes memory soloSignatures) =
            _executeThroughSafe(address(checker), soloAction);
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(soloTx, soloSignatures);
        second.processSafeMessage(soloTx, soloSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        assertEq(second.protocolFeeInWei(3), address(second) == lo ? 111 : 333);
        assertTrue(relayA.governanceSafeNonceConsumed(soloNonce));
        assertFalse(second.governanceSafeNonceConsumed(soloNonce));
    }

    function test_deploymentReplayFloorRejectsPredatingMessage() public {
        uint256 replayFloor = safe.nonce() + 5;
        IRelay.RelayInitialConfig memory config = _relayConfig(address(safe));
        config.governance.safeNonce = replayFloor;

        vm.chainId(CHAIN_A);
        Relay laterRelay = _deployRelay(config, address(0), IRelay(address(0)));

        vm.chainId(SOURCE_CHAIN);
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES,
            replayFloor - 1,
            ownerHash,
            _feeUpdatesFor(CHAIN_A, address(laterRelay), CHAIN_B, address(relayB))
        );
        ISafeGovernance.SafeTx memory txData = _txTo(address(checker), action, replayFloor - 1);
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISafeGovernance.GovernanceNonceBeforeReplayFloor.selector, replayFloor - 1, replayFloor
            )
        );
        laterRelay.processSafeMessage(txData, signatures);
        assertEq(laterRelay.protocolFeeInWei(3), 0);
        assertFalse(laterRelay.governanceSafeNonceConsumed(replayFloor - 1));

        // the floor itself is the FIRST accepted signed nonce
        bytes memory atFloorAction = abi.encodeWithSelector(
            CHANGE_FEES,
            replayFloor,
            ownerHash,
            _feeUpdatesFor(CHAIN_A, address(laterRelay), CHAIN_B, address(relayB))
        );
        ISafeGovernance.SafeTx memory atFloorTx = _txTo(address(checker), atFloorAction, replayFloor);
        bytes memory atFloorSignatures = _signWith(atFloorTx, _ownerKeys(), THRESHOLD);
        vm.chainId(CHAIN_A);
        laterRelay.processSafeMessage(atFloorTx, atFloorSignatures);
        assertEq(laterRelay.protocolFeeInWei(3), 111);
        assertTrue(laterRelay.governanceSafeNonceConsumed(replayFloor));
    }

    function test_conflictingTransactionsAtSameSafeNonceAreFirstDeliveryWins() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 actionNonce = safe.nonce();
        SafeGovernance.GovernanceFeeUpdate[] memory firstUpdates = _feeUpdates(CHAIN_A, CHAIN_B);
        SafeGovernance.GovernanceFeeUpdate[] memory secondUpdates = _feeUpdates(CHAIN_A, CHAIN_B);
        secondUpdates[0].feeInWei = 333;
        secondUpdates[1].feeInWei = 444;

        ISafeGovernance.SafeTx memory firstTx = _txTo(
            address(checker),
            abi.encodeWithSelector(CHANGE_FEES, actionNonce, ownerHash, firstUpdates),
            actionNonce
        );
        ISafeGovernance.SafeTx memory secondTx = _txTo(
            address(checker),
            abi.encodeWithSelector(CHANGE_FEES, actionNonce, ownerHash, secondUpdates),
            actionNonce
        );
        bytes memory firstSignatures = _signWith(firstTx, _ownerKeys(), THRESHOLD);
        bytes memory secondSignatures = _signWith(secondTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(firstTx, firstSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
        assertTrue(relayA.governanceSafeNonceConsumed(actionNonce));
        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.GovernanceNonceAlreadyConsumed.selector, actionNonce));
        relayA.processSafeMessage(secondTx, secondSignatures);

        // Without source execution evidence, another target can see the other valid
        // transaction first. Each target remains internally one-action-per-nonce.
        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(secondTx, secondSignatures);
        assertEq(relayB.protocolFeeInWei(4), 444);
        assertTrue(relayB.governanceSafeNonceConsumed(actionNonce));
        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.GovernanceNonceAlreadyConsumed.selector, actionNonce));
        relayB.processSafeMessage(firstTx, firstSignatures);
    }

    function test_delayedOwnerRotationCannotBeStrandedByHigherOldConfigFee() public {
        vm.chainId(SOURCE_CHAIN);
        address oldOwner = owners[0];
        address[] memory newOwners = _replaceOwner(owners, oldOwner, vm.addr(NEW_OWNER_KEY));
        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);

        uint256 rotationNonce = safe.nonce();
        (ISafeGovernance.SafeTx memory ownerTx, bytes memory ownerSignatures, bytes32 newOwnerHash) =
            _signedOwnerChange(rotationNonce, ownerHash, newOwners, _ownerKeys());

        uint256 oldConfigFeeNonce = rotationNonce + 5;
        bytes memory oldConfigFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, oldConfigFeeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory oldConfigFeeTx =
            _txTo(address(checker), oldConfigFeeAction, oldConfigFeeNonce);
        bytes memory oldConfigFeeSignatures = _signWith(oldConfigFeeTx, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(oldConfigFeeTx, oldConfigFeeSignatures);
        (, uint256 lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, oldConfigFeeNonce);

        relayA.processSafeMessage(ownerTx, ownerSignatures);
        (bytes32 activeHash, uint256 activeNonce) = relayA.governanceOwnerConfig();
        (, lastNonce) = relayA.governanceNonces();
        assertEq(activeHash, newOwnerHash);
        assertEq(activeNonce, rotationNonce);
        assertEq(lastNonce, oldConfigFeeNonce);

        {
            vm.chainId(SOURCE_CHAIN);
            uint256 staleNewConfigFeeNonce = rotationNonce + 1;
            bytes memory staleNewConfigFeeAction = abi.encodeWithSelector(
                CHANGE_FEES, staleNewConfigFeeNonce, newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B)
            );
            ISafeGovernance.SafeTx memory staleNewConfigFeeTx =
                _txTo(address(checker), staleNewConfigFeeAction, staleNewConfigFeeNonce);
            bytes memory staleNewConfigFeeSignatures = _signWith(staleNewConfigFeeTx, newKeys, THRESHOLD);
            vm.chainId(CHAIN_A);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISafeGovernance.GovernanceNonceNotMonotonic.selector, staleNewConfigFeeNonce, oldConfigFeeNonce
                )
            );
            relayA.processSafeMessage(staleNewConfigFeeTx, staleNewConfigFeeSignatures);
        }

        vm.chainId(SOURCE_CHAIN);
        uint256 newConfigFeeNonce = oldConfigFeeNonce + 1;
        bytes memory newConfigFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, newConfigFeeNonce, newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory newConfigFeeTx =
            _txTo(address(checker), newConfigFeeAction, newConfigFeeNonce);
        bytes memory newConfigFeeSignatures = _signWith(newConfigFeeTx, newKeys, THRESHOLD);
        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(newConfigFeeTx, newConfigFeeSignatures);
        (, lastNonce) = relayA.governanceNonces();
        assertEq(lastNonce, newConfigFeeNonce);
    }

    function test_returningToSameOwnersDoesNotReviveOldFutureNonceMessage() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 staleFeeNonce = 10;
        bytes memory staleFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, staleFeeNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory staleFeeTx = _txTo(address(checker), staleFeeAction, staleFeeNonce);
        bytes memory staleFeeSignatures = _signWith(staleFeeTx, _ownerKeys(), THRESHOLD);

        address oldOwner = owners[0];
        address[] memory newOwners = _replaceOwner(owners, oldOwner, vm.addr(NEW_OWNER_KEY));
        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);
        uint256 firstRotationNonce = safe.nonce();
        bytes32 intermediateHash = _applyOwnerChange(relayA, firstRotationNonce, ownerHash, newOwners, _ownerKeys());

        vm.chainId(SOURCE_CHAIN);
        uint256 secondRotationNonce = firstRotationNonce + 1;
        bytes32 returnedOwnerHash = _applyOwnerChange(relayA, secondRotationNonce, intermediateHash, owners, newKeys);
        (bytes32 activeHash,) = relayA.governanceOwnerConfig();
        assertEq(activeHash, returnedOwnerHash);
        assertNotEq(returnedOwnerHash, ownerHash);

        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.GovernanceOwnerHashMismatch.selector, ownerHash, returnedOwnerHash)
        );
        relayA.processSafeMessage(staleFeeTx, staleFeeSignatures);
    }

    function test_safeCancellationDoesNotRevokeRemoteAuthorization() public {
        vm.chainId(SOURCE_CHAIN);
        uint256 safeTxNonce = safe.nonce();
        bytes memory feeAction =
            abi.encodeWithSelector(CHANGE_FEES, safeTxNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory canceledTx = _txTo(address(checker), feeAction, safeTxNonce);
        bytes memory canceledSignatures = _signWith(canceledTx, _ownerKeys(), THRESHOLD);

        _executeThroughSafe(address(safe), bytes(""));
        assertEq(safe.nonce(), safeTxNonce + 1);
        vm.expectRevert();
        safe.execTransaction(
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
        relayA.processSafeMessage(canceledTx, canceledSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_removedOwnerRemainsAuthorizedUntilTargetInstallsRotation() public {
        vm.chainId(SOURCE_CHAIN);
        address oldOwner = safe.getOwners()[0];
        address newOwner = vm.addr(NEW_OWNER_KEY);
        address[] memory newOwners = _replaceOwner(owners, oldOwner, newOwner);
        // Attest-after ceremony: the Safe rotates natively first (signed by the old set)...
        bytes memory swapData =
            abi.encodeWithSignature("swapOwner(address,address,address)", SENTINEL_OWNERS, oldOwner, newOwner);
        _executeThroughSafe(address(safe), swapData);
        // ...then the old ∩ new owners attest the live configuration.
        uint256 rotationNonce = safe.nonce();
        bytes32 newOwnerHash =
            SafeGovernance.ownerConfigHash(SOURCE_CHAIN, address(safe), rotationNonce, THRESHOLD, newOwners);
        bytes memory ownerAction =
            abi.encodeWithSelector(checker.changeOwners.selector, rotationNonce, ownerHash, THRESHOLD, newOwners);
        (ISafeGovernance.SafeTx memory ownerTx, bytes memory ownerSignatures) =
            _executeThroughSafeWithKeys(address(checker), ownerAction, _keysExcludingOwner(oldOwner), THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(ownerTx, ownerSignatures);

        vm.chainId(SOURCE_CHAIN);
        uint256 staleActionNonce = safe.nonce();
        bytes memory staleFeeAction =
            abi.encodeWithSelector(CHANGE_FEES, staleActionNonce, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        ISafeGovernance.SafeTx memory staleFeeTx = _txTo(address(checker), staleFeeAction, staleActionNonce);
        bytes memory staleFeeSignatures = _signWith(staleFeeTx, _keysIncludingOwner(oldOwner, THRESHOLD), THRESHOLD);

        // Relay A has the rotation and rejects the removed owner's old generation.
        vm.chainId(CHAIN_A);
        vm.expectRevert(abi.encodeWithSelector(ISafeGovernance.UnknownSigner.selector, oldOwner));
        relayA.processSafeMessage(staleFeeTx, staleFeeSignatures);

        // Relay B has not received the rotation, so its locally admitted old
        // generation still authorizes the message despite the live Safe change.
        vm.chainId(CHAIN_B);
        relayB.processSafeMessage(staleFeeTx, staleFeeSignatures);
        assertEq(relayB.protocolFeeInWei(4), 222);
        relayB.processSafeMessage(ownerTx, ownerSignatures);
        (bytes32 activeHashB,) = relayB.governanceOwnerConfig();
        assertEq(activeHashB, newOwnerHash);
    }

    function test_ownerRotationRequiresLocalInstallationBeforeNewOwnersCanGovern() public {
        vm.chainId(SOURCE_CHAIN);

        address[] memory safeOwners = safe.getOwners();
        address oldOwner = safeOwners[0];
        address newOwner = vm.addr(NEW_OWNER_KEY);
        address[] memory newOwners = _replaceOwner(owners, oldOwner, newOwner);
        // Native Safe rotation first; the attestation is pending until issued.
        bytes memory swapData =
            abi.encodeWithSignature("swapOwner(address,address,address)", SENTINEL_OWNERS, oldOwner, newOwner);
        _executeThroughSafe(address(safe), swapData);
        address[] memory actualOwners = safe.getOwners();
        _sort(actualOwners);
        assertEq(keccak256(abi.encode(actualOwners)), keccak256(abi.encode(newOwners)));
        assertFalse(checker.activeOwnerConfigurationIsLive());

        uint256 rotationNonce = safe.nonce();
        bytes32 newOwnerHash =
            SafeGovernance.ownerConfigHash(SOURCE_CHAIN, address(safe), rotationNonce, THRESHOLD, newOwners);
        bytes memory ownerAction =
            abi.encodeWithSelector(checker.changeOwners.selector, rotationNonce, ownerHash, THRESHOLD, newOwners);
        (ISafeGovernance.SafeTx memory ownerTx, bytes memory ownerSignatures) =
            _executeThroughSafeWithKeys(address(checker), ownerAction, _keysExcludingOwner(oldOwner), THRESHOLD);
        assertEq(checker.activeOwnerConfigHash(), newOwnerHash);
        assertTrue(checker.activeOwnerConfigurationIsLive());

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(ownerTx, ownerSignatures);
        (bytes32 activeHash,) = relayA.governanceOwnerConfig();
        assertEq(activeHash, newOwnerHash);

        vm.chainId(SOURCE_CHAIN);
        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);
        bytes memory feeAction =
            abi.encodeWithSelector(CHANGE_FEES, safe.nonce(), newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B));
        (ISafeGovernance.SafeTx memory feeTx, bytes memory feeSignatures) =
            _executeThroughSafeWithKeys(address(checker), feeAction, newKeys, THRESHOLD);

        vm.chainId(CHAIN_A);
        relayA.processSafeMessage(feeTx, feeSignatures);
        assertEq(relayA.protocolFeeInWei(3), 111);

        vm.chainId(CHAIN_B);
        vm.expectRevert();
        relayB.processSafeMessage(feeTx, feeSignatures);
        relayB.processSafeMessage(ownerTx, ownerSignatures);
        relayB.processSafeMessage(feeTx, feeSignatures);
        assertEq(relayB.protocolFeeInWei(4), 222);
    }

    function test_checkerRejectsFeesWhileRotationAttestationIsPending() public {
        vm.chainId(SOURCE_CHAIN);

        address oldOwner = safe.getOwners()[0];
        address newOwner = vm.addr(NEW_OWNER_KEY);
        address[] memory newOwners = _replaceOwner(owners, oldOwner, newOwner);
        // The Safe rotates natively; until the attestation is issued, live != admitted.
        bytes memory swapData =
            abi.encodeWithSignature("swapOwner(address,address,address)", SENTINEL_OWNERS, oldOwner, newOwner);
        _executeThroughSafe(address(safe), swapData);
        assertFalse(checker.activeOwnerConfigurationIsLive());

        // Fee actions are embargoed while the attestation is pending.
        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);
        uint256 nonceBeforeRejectedFee = safe.nonce();
        bytes memory feeAction = abi.encodeWithSelector(
            CHANGE_FEES, nonceBeforeRejectedFee, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        bytes memory signatures =
            _signWith(_txTo(address(checker), feeAction, nonceBeforeRejectedFee), newKeys, THRESHOLD);
        vm.expectRevert();
        safe.execTransaction(address(checker), 0, feeAction, 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertEq(safe.nonce(), nonceBeforeRejectedFee);
        assertEq(checker.nextSafeNonce(), 0);

        // An attestation proposing anything but the live configuration is rejected too.
        bytes memory wrongAttestation =
            abi.encodeWithSelector(checker.changeOwners.selector, safe.nonce(), ownerHash, THRESHOLD, owners);
        bytes memory wrongSignatures =
            _signWith(_txTo(address(checker), wrongAttestation, safe.nonce()), newKeys, THRESHOLD);
        vm.expectRevert();
        safe.execTransaction(
            address(checker), 0, wrongAttestation, 0, 0, 0, 0, address(0), payable(address(0)), wrongSignatures
        );
        assertEq(safe.nonce(), nonceBeforeRejectedFee);
        assertEq(checker.activeOwnerConfigHash(), ownerHash);
        assertFalse(checker.activeOwnerConfigurationIsLive());

        // The proper attestation of the live configuration completes the rotation.
        uint256 rotationNonce = safe.nonce();
        bytes32 newOwnerHash =
            SafeGovernance.ownerConfigHash(SOURCE_CHAIN, address(safe), rotationNonce, THRESHOLD, newOwners);
        bytes memory attestation =
            abi.encodeWithSelector(checker.changeOwners.selector, rotationNonce, ownerHash, THRESHOLD, newOwners);
        _executeThroughSafeWithKeys(address(checker), attestation, _keysExcludingOwner(oldOwner), THRESHOLD);
        assertEq(checker.activeOwnerConfigHash(), newOwnerHash);
        assertEq(checker.nextSafeNonce(), rotationNonce + 1);
        assertTrue(checker.activeOwnerConfigurationIsLive());
    }

    function test_attestationMustMatchLiveSafeConfiguration() public {
        // The anti-typo core of attest-after: a threshold-signed changeOwners proposing a
        // set that is NOT the live Safe configuration can never become an issued
        // instruction — the gate compares against chain truth, not against the proposal.
        vm.chainId(SOURCE_CHAIN);
        address[] memory typoOwners = _replaceOwner(owners, owners[0], vm.addr(17));
        uint256 safeNonce = safe.nonce();
        bytes memory typoAction =
            abi.encodeWithSelector(checker.changeOwners.selector, safeNonce, ownerHash, THRESHOLD, typoOwners);
        bytes memory signatures = _signWith(_txTo(address(checker), typoAction, safeNonce), _ownerKeys(), THRESHOLD);
        vm.expectRevert(); // GS013: OwnerConfigurationMismatch(newHash, liveHash) inside
        safe.execTransaction(address(checker), 0, typoAction, 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertEq(safe.nonce(), safeNonce);
        assertEq(checker.activeOwnerConfigHash(), ownerHash);
        assertTrue(checker.activeOwnerConfigurationIsLive());
    }

    function test_freshSafeRotationAtGenerationZeroIsRejectedBySourceAndTargets() public {
        // A brand-new Safe signs its first transaction at nonce 0 — the same ordinal as the
        // initialize-admitted generation 0. A rotation there must fail identically on the
        // source gate and on every target (rotations strictly succeed the active generation);
        // accepting it on one side only would fork the generation lineage.
        vm.chainId(SOURCE_CHAIN);
        GnosisSafeProxy freshProxy = new GnosisSafeProxy(address(new GnosisSafeL2()));
        safe = IRealSafe(address(freshProxy));
        safe.setup(owners, THRESHOLD, address(0), bytes(""), address(0), address(0), 0, payable(address(0)));
        checker = SafeInstructions(
            address(
                new SafeInstructionsProxy(
                    IGovernanceSettings(makeAddr("governanceSettings")),
                    makeAddr("flareGovernance"),
                    makeAddr("addressUpdater"),
                    address(new SafeInstructions()),
                    address(safe)
                )
            )
        );
        ownerHash = checker.activeOwnerConfigHash();
        assertEq(safe.nonce(), 0);
        assertEq(checker.sourceChainId(), SOURCE_CHAIN);
        assertTrue(checker.activeOwnerConfigurationIsLive());

        vm.chainId(CHAIN_A);
        Relay freshRelay = _deployRelay(_relayConfig(address(safe)), address(0), IRelay(address(0)));

        vm.chainId(SOURCE_CHAIN);
        address[] memory newOwners = _replaceOwner(owners, owners[0], vm.addr(NEW_OWNER_KEY));
        (ISafeGovernance.SafeTx memory rotationTx, bytes memory rotationSignatures,) =
            _signedOwnerChange(0, ownerHash, newOwners, _ownerKeys());
        vm.expectRevert(); // GS013: the source gate rejects the inner call
        safe.execTransaction(
            rotationTx.to, 0, rotationTx.data, 0, 0, 0, 0, address(0), payable(address(0)), rotationSignatures
        );
        assertEq(checker.activeOwnerConfigHash(), ownerHash);

        vm.chainId(CHAIN_A);
        vm.expectRevert(
            abi.encodeWithSelector(ISafeGovernance.GovernanceOwnerConfigNonceNotIncreasing.selector, 0, 0)
        );
        freshRelay.processSafeMessage(rotationTx, rotationSignatures);
    }

    function test_governanceConfigurationAllowsSetterModeButNoOldRelay() public {
        Relay implementation = new Relay();
        // Setter-mode (home) deployments MAY carry Safe governance (fee actions are never
        // applied there; chain-agnostic actions like exemptions are). RLY-23 home-force:
        // the setter relay must be deployed on the source chain itself.
        vm.chainId(SOURCE_CHAIN);
        RelayProxy setterProxy = new RelayProxy(
            address(implementation), _relayConfig(address(safe)), address(this), IRelay(address(0)), address(this)
        );
        (address setterSafe,,) = Relay(address(setterProxy)).governanceSigners();
        assertEq(setterSafe, address(safe));

        vm.chainId(CHAIN_A);
        // Safe governance composes with an old-relay migration (the Flare home shape is
        // setter + old relay + governance; here the relay-mode variant is exercised).
        RelayProxy migratedProxy = new RelayProxy(
            address(implementation), _relayConfig(address(safe)), address(0), IRelay(address(relayA)), address(this)
        );
        (address migratedSafe,,) = Relay(address(migratedProxy)).governanceSigners();
        assertEq(migratedSafe, address(safe));

        IRelay.RelayInitialConfig memory invalidConfig = _relayConfig(address(safe));
        invalidConfig.governance.ownerConfigSafeNonce = invalidConfig.governance.safeNonce + 1;
        vm.expectRevert(ISafeGovernance.InvalidGovernanceOwnerConfiguration.selector);
        new RelayProxy(address(implementation), invalidConfig, address(0), IRelay(address(0)), address(this));
    }

    function _deployRelay(
        IRelay.RelayInitialConfig memory config,
        address signingPolicySetter,
        IRelay oldRelay
    ) internal returns (Relay) {
        Relay implementation = new Relay();
        RelayProxy proxy =
            new RelayProxy(address(implementation), config, signingPolicySetter, oldRelay, address(this));
        return Relay(address(proxy));
    }

    function _relayConfig(address safeAddress) internal view returns (IRelay.RelayInitialConfig memory c) {
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
        c.governance.sourceChainId = SOURCE_CHAIN;
        c.governance.safe = safeAddress;
        c.governance.threshold = THRESHOLD;
        c.governance.owners = owners;
        c.governance.ownerConfigSafeNonce = ownerConfigSafeNonce;
        c.governance.safeNonce = ownerConfigSafeNonce;
    }

    /// Default per-chain target: the suite deployment for that chain (tests addressing a
    /// custom deployment build their update lists explicitly).
    function _targetFor(uint256 chain_) internal view returns (address) {
        return chain_ == CHAIN_B ? address(relayB) : address(relayA);
    }

    function _feeUpdates(uint256 a, uint256 b) internal view returns (SafeGovernance.GovernanceFeeUpdate[] memory u) {
        return _feeUpdatesFor(a, _targetFor(a), b, _targetFor(b));
    }

    function _feeUpdatesFor(uint256 a, address targetA, uint256 b, address targetB)
        internal
        pure
        returns (SafeGovernance.GovernanceFeeUpdate[] memory u)
    {
        u = new SafeGovernance.GovernanceFeeUpdate[](2);
        u[0] = SafeGovernance.GovernanceFeeUpdate(a, targetA, 3, 111);
        u[1] = SafeGovernance.GovernanceFeeUpdate(b, targetB, 4, 222);
    }

    function _feeExemptions(uint256 a, uint256 b, address account)
        internal
        view
        returns (SafeGovernance.GovernanceFeeExemption[] memory u)
    {
        return _feeExemptionsFor(a, _targetFor(a), b, _targetFor(b), account);
    }

    function _feeExemptionsFor(uint256 a, address targetA, uint256 b, address targetB, address account)
        internal
        pure
        returns (SafeGovernance.GovernanceFeeExemption[] memory u)
    {
        u = new SafeGovernance.GovernanceFeeExemption[](2);
        u[0] = SafeGovernance.GovernanceFeeExemption(a, targetA, account, true);
        u[1] = SafeGovernance.GovernanceFeeExemption(b, targetB, account, true);
    }

    function _feeCollections(
        uint256 a,
        address targetA,
        address collectorA,
        uint256 b,
        address targetB,
        address collectorB
    )
        internal
        pure
        returns (SafeGovernance.GovernanceFeeCollection[] memory u)
    {
        u = new SafeGovernance.GovernanceFeeCollection[](2);
        u[0] = SafeGovernance.GovernanceFeeCollection(a, targetA, collectorA);
        u[1] = SafeGovernance.GovernanceFeeCollection(b, targetB, collectorB);
    }

    function _tx(bytes memory data, uint256 nonce) internal view returns (ISafeGovernance.SafeTx memory t) {
        return _txTo(address(checker), data, nonce);
    }

    function _txTo(address target, bytes memory data, uint256 nonce)
        internal
        pure
        returns (ISafeGovernance.SafeTx memory t)
    {
        t.to = target;
        t.data = data;
        t.nonce = nonce;
    }

    function _copyTransaction(ISafeGovernance.SafeTx memory source)
        internal
        pure
        returns (ISafeGovernance.SafeTx memory target)
    {
        target = ISafeGovernance.SafeTx(
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

    function _signWith(ISafeGovernance.SafeTx memory t, uint256[] memory signingKeys, uint256 signatureCount)
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
        bytes32 digest = IRealSafe(address(safe))
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

    function _signWithMixedFlavours(
        ISafeGovernance.SafeTx memory t,
        uint256[] memory signingKeys,
        uint256 signatureCount
    )
        internal
        view
        returns (bytes memory out)
    {
        require(signatureCount <= signingKeys.length, "too many requested signatures");
        for (uint256 i; i < signingKeys.length; ++i) {
            for (uint256 j = i + 1; j < signingKeys.length; ++j) {
                if (vm.addr(signingKeys[j]) < vm.addr(signingKeys[i])) {
                    (signingKeys[i], signingKeys[j]) = (signingKeys[j], signingKeys[i]);
                }
            }
        }
        bytes32 digest = IRealSafe(address(safe))
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
        bytes32 prefixedDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        for (uint256 i; i < signatureCount; ++i) {
            if (i % 2 == 1) {
                // eth_sign flavour: sign the prefixed digest and mark it with v + 4.
                (uint8 v, bytes32 r, bytes32 s_) = vm.sign(signingKeys[i], prefixedDigest);
                out = bytes.concat(out, abi.encodePacked(r, s_, v + 4));
            } else {
                (uint8 v, bytes32 r, bytes32 s_) = vm.sign(signingKeys[i], digest);
                out = bytes.concat(out, abi.encodePacked(r, s_, v));
            }
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

    function _executeThroughSafe(address target, bytes memory data)
        internal
        returns (ISafeGovernance.SafeTx memory txData, bytes memory signatures)
    {
        return _executeThroughSafeWithKeys(target, data, _ownerKeys(), THRESHOLD);
    }

    function _executeThroughSafeWithKeys(
        address target,
        bytes memory data,
        uint256[] memory signingKeys,
        uint256 signatureCount
    ) internal returns (ISafeGovernance.SafeTx memory txData, bytes memory signatures) {
        uint256 safeNonce = safe.nonce();
        txData = _txTo(target, data, safeNonce);
        signatures = _signWith(txData, signingKeys, signatureCount);
        bool success = safe.execTransaction(target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures);
        assertTrue(success);
    }

    function _signedOwnerChange(
        uint256 actionNonce,
        bytes32 currentHash,
        address[] memory nextOwners,
        uint256[] memory signingKeys
    ) internal view returns (ISafeGovernance.SafeTx memory txData, bytes memory signatures, bytes32 nextHash) {
        nextHash = SafeGovernance.ownerConfigHash(SOURCE_CHAIN, address(safe), actionNonce, THRESHOLD, nextOwners);
        bytes memory action =
            abi.encodeWithSelector(checker.changeOwners.selector, actionNonce, currentHash, THRESHOLD, nextOwners);
        txData = _txTo(address(checker), action, actionNonce);
        signatures = _signWith(txData, signingKeys, THRESHOLD);
    }

    function _applyOwnerChange(
        Relay target,
        uint256 actionNonce,
        bytes32 currentHash,
        address[] memory nextOwners,
        uint256[] memory signingKeys
    ) internal returns (bytes32 nextHash) {
        (ISafeGovernance.SafeTx memory txData, bytes memory signatures, bytes32 expectedHash) =
            _signedOwnerChange(actionNonce, currentHash, nextOwners, signingKeys);
        vm.chainId(CHAIN_A);
        target.processSafeMessage(txData, signatures);
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

    /// Keys of the old ∩ new intersection after removing one owner — the signer set a
    /// rotation attestation must use (valid on the rotated Safe AND on old-mirror targets).
    function _keysExcludingOwner(address excludedOwner) internal view returns (uint256[] memory result) {
        result = new uint256[](keys.length - 1);
        uint256 position;
        for (uint256 i; i < keys.length; ++i) {
            if (vm.addr(keys[i]) == excludedOwner) continue;
            result[position++] = keys[i];
        }
        require(position == result.length, "owner to exclude not found");
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
