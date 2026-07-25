// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Relay } from "../../../contracts/protocol/implementation/Relay.sol";
import { IRelay } from "../../../contracts/userInterfaces/IRelay.sol";
import { IRelayGovernance } from "../../../contracts/userInterfaces/IRelayGovernance.sol";
import { GSSGovernance } from "../../../contracts/governance/GSSGovernance.sol";
import { GnosisSafeTx } from "../../../contracts/governance/GnosisSafeTx.sol";
import { GSSOwnerConfigurationChecker } from "../../../contracts/governance/GSSOwnerConfigurationChecker.sol";
import { GnosisSafeL2 } from "@gnosis.pm/safe-contracts/contracts/GnosisSafeL2.sol";
import { GnosisSafeProxy } from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

interface IRealGSS {
    function setup(address[] calldata owners, uint256 threshold, address to, bytes calldata data,
        address fallbackHandler, address paymentToken, uint256 payment, address payable paymentReceiver) external;
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function nonce() external view returns (uint256);
    function getTransactionHash(address to, uint256 value, bytes calldata data, uint8 operation,
        uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken,
        address refundReceiver, uint256 nonce_) external view returns (bytes32);
    function execTransaction(address to, uint256 value, bytes calldata data, uint8 operation,
        uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken,
        address payable refundReceiver, bytes calldata signatures) external payable returns (bool);
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

    function setUp() public {
        for (uint256 i; i < keys.length; ++i) owners.push(vm.addr(keys[i]));
        address[] memory sortedOwners = owners;
        _sort(sortedOwners);
        owners = sortedOwners;
        vm.chainId(SOURCE_CHAIN);
        GnosisSafeL2 singleton = new GnosisSafeL2();
        GnosisSafeProxy proxy = new GnosisSafeProxy(address(singleton));
        gss = IRealGSS(address(proxy));
        checker = new GSSOwnerConfigurationChecker(SOURCE_CHAIN, address(gss));
        gss.setup(owners, THRESHOLD, address(0), bytes(""), address(0), address(0), 0, payable(address(0)));
        ownerHash = GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(gss), THRESHOLD, owners);

        vm.chainId(CHAIN_A);
        relayA = new Relay(_relayConfig(address(gss)), address(0), IRelay(address(0)));
        vm.chainId(CHAIN_B);
        relayB = new Relay(_relayConfig(address(gss)), address(0), IRelay(address(0)));
    }

    function test_setupIsThreeOfFiveAndCheckerMatchesGSS() public {
        assertEq(
            IRelayGovernance.InvalidGovernanceSource.selector,
            bytes4(keccak256("InvalidGovernanceSource()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceDeployment.selector,
            bytes4(keccak256("InvalidGovernanceDeployment()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceOwnerConfiguration.selector,
            bytes4(keccak256("InvalidGovernanceOwnerConfiguration()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceTransaction.selector,
            bytes4(keccak256("InvalidGovernanceTransaction()"))
        );
        assertEq(
            IRelayGovernance.InvalidGovernanceSignatures.selector,
            bytes4(keccak256("InvalidGovernanceSignatures()"))
        );
        assertEq(
            IRelayGovernance.UnknownGovernanceAction.selector,
            bytes4(keccak256("UnknownGovernanceAction(bytes4)"))
        );
        assertEq(
            IRelayGovernance.GovernanceOwnerHashMismatch.selector,
            bytes4(keccak256("GovernanceOwnerHashMismatch(bytes32,bytes32)"))
        );
        assertEq(
            IRelayGovernance.GovernanceNonceNotMonotonic.selector,
            bytes4(keccak256("GovernanceNonceNotMonotonic(uint256,uint256)"))
        );

        vm.chainId(SOURCE_CHAIN);
        bytes memory action = abi.encodeWithSelector(
            checker.changeOwners.selector, 1, bytes32(0), THRESHOLD, owners
        );
        _executeThroughGSS(address(checker), action);
        assertEq(checker.activeOwnerConfigHash(), ownerHash);
        assertEq(checker.latestSafeNonce(), 1);
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

    function test_feeMessageWorksOnTwoIndependentTargetChains() public {
        _establishInitialConfiguration();
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = gss.nonce();
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES,
            safeNonce + 1,
            ownerHash,
            _feeUpdates(CHAIN_A, CHAIN_B)
        );
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
        _establishInitialConfiguration();
        vm.chainId(SOURCE_CHAIN);
        uint256 safeNonce = gss.nonce();
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES, safeNonce + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);
        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        vm.expectRevert();
        relayA.processGSSMessage(txData, signatures);

        bytes memory modified = abi.encodeWithSelector(
            CHANGE_FEES, uint256(2), ownerHash, _feeUpdates(CHAIN_A, CHAIN_A)
        );
        vm.expectRevert();
        relayA.processGSSMessage(_tx(modified, 2), signatures);

        GnosisSafeTx.Transaction memory modifiedTarget = txData;
        modifiedTarget.to = address(0xBEEF);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceSignatures.selector);
        relayA.processGSSMessage(modifiedTarget, signatures);
    }

    function test_acceptsMessageExecutedThroughAnyCompatibleHelper() public {
        vm.chainId(SOURCE_CHAIN);
        GSSOwnerConfigurationChecker alternateChecker =
            new GSSOwnerConfigurationChecker(SOURCE_CHAIN, address(gss));
        bytes memory ownerAction = abi.encodeWithSelector(
            alternateChecker.changeOwners.selector, gss.nonce() + 1, bytes32(0), THRESHOLD, owners
        );
        _executeThroughGSS(address(alternateChecker), ownerAction);

        bytes memory feeAction = abi.encodeWithSelector(
            CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(alternateChecker), feeAction);
        assertEq(txData.to, address(alternateChecker));

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
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES, gss.nonce() + 2, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory signatures = _signWith(txData, _ownerKeys(), THRESHOLD);

        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceTransaction.selector);
        relayA.processGSSMessage(txData, signatures);
    }

    function test_irrelevantFeeMessageDoesNotConsumeLocalNonce() public {
        _establishInitialConfiguration();
        vm.chainId(SOURCE_CHAIN);
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_B, CHAIN_B)
        );
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.lastGovernanceSafeNonce(), 0);
        assertEq(relayA.protocolFeeInWei(3), 0);
        assertEq(relayA.protocolFeeInWei(4), 0);
    }

    function test_acceptsMoreValidSignaturesThanThreshold() public {
        _establishInitialConfiguration();
        vm.chainId(SOURCE_CHAIN);
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSSWithKeys(address(checker), action, _ownerKeys(), owners.length);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.protocolFeeInWei(3), 111);
    }

    function test_rejectsInvalidSignatureSetsAndNormalizesRecoveryErrors() public {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        GnosisSafeTx.Transaction memory txData = _txTo(address(checker), action, gss.nonce());
        bytes memory insufficient = _signWith(txData, _ownerKeys(), THRESHOLD - 1);

        uint256[] memory duplicateKeys = new uint256[](3);
        duplicateKeys[0] = keys[0];
        duplicateKeys[1] = keys[0];
        duplicateKeys[2] = keys[1];
        bytes memory duplicate = _signWith(txData, duplicateKeys, duplicateKeys.length);
        bytes memory malformed = bytes.concat(_signWith(txData, _ownerKeys(), THRESHOLD), hex"00");
        bytes memory oversized =
            bytes.concat(_signWith(txData, _ownerKeys(), owners.length), new bytes(65));
        bytes memory invalidV = bytes.concat(_signWith(txData, _ownerKeys(), THRESHOLD));
        invalidV[64] = bytes1(uint8(29));
        bytes memory highS = bytes.concat(_signWith(txData, _ownerKeys(), THRESHOLD));
        for (uint256 i = 32; i < 64; ++i) highS[i] = 0xff;

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
        assertEq(relayA.lastGovernanceSafeNonce(), 0);
    }

    function test_gappedSafeNonceIsAccepted() public {
        _establishInitialConfiguration();
        vm.chainId(SOURCE_CHAIN);
        _executeThroughGSS(address(0xCAFE), bytes(""));
        bytes memory action = abi.encodeWithSelector(
            CHANGE_FEES, gss.nonce() + 1, ownerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
        (GnosisSafeTx.Transaction memory txData, bytes memory signatures) =
            _executeThroughGSS(address(checker), action);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(txData, signatures);
        assertEq(relayA.lastGovernanceSafeNonce(), 3);
    }

    function test_ownerRotationRequiresLocalInstallationBeforeNewOwnersCanGovern() public {
        _establishInitialConfiguration();
        vm.chainId(SOURCE_CHAIN);

        address[] memory safeOwners = gss.getOwners();
        address oldOwner = safeOwners[0];
        address newOwner = vm.addr(NEW_OWNER_KEY);
        address[] memory newOwners = _replaceOwner(owners, oldOwner, newOwner);
        bytes32 newOwnerHash =
            GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(gss), THRESHOLD, newOwners);
        bytes memory ownerAction = abi.encodeWithSelector(
            checker.changeOwners.selector,
            gss.nonce() + 1,
            ownerHash,
            THRESHOLD,
            newOwners
        );
        (GnosisSafeTx.Transaction memory ownerTx, bytes memory ownerSignatures) =
            _executeThroughGSS(address(checker), ownerAction);
        assertEq(checker.activeOwnerConfigHash(), newOwnerHash);

        vm.chainId(CHAIN_A);
        relayA.processGSSMessage(ownerTx, ownerSignatures);
        assertEq(relayA.activeOwnerConfigHash(), newOwnerHash);

        vm.chainId(SOURCE_CHAIN);
        bytes memory swapData = abi.encodeWithSignature(
            "swapOwner(address,address,address)",
            SENTINEL_OWNERS,
            oldOwner,
            newOwner
        );
        _executeThroughGSS(address(gss), swapData);
        address[] memory actualOwners = gss.getOwners();
        _sort(actualOwners);
        assertEq(keccak256(abi.encode(actualOwners)), keccak256(abi.encode(newOwners)));

        uint256[] memory newKeys = _replaceOwnerKey(_ownerKeys(), oldOwner, NEW_OWNER_KEY);
        bytes memory feeAction = abi.encodeWithSelector(
            CHANGE_FEES, gss.nonce() + 1, newOwnerHash, _feeUpdates(CHAIN_A, CHAIN_B)
        );
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
        _establishInitialConfiguration();
        vm.chainId(SOURCE_CHAIN);

        address oldOwner = gss.getOwners()[0];
        address[] memory newOwners = _replaceOwner(owners, oldOwner, vm.addr(NEW_OWNER_KEY));
        bytes32 newOwnerHash =
            GSSGovernance.ownerConfigHash(SOURCE_CHAIN, address(gss), THRESHOLD, newOwners);
        bytes memory ownerAction = abi.encodeWithSelector(
            checker.changeOwners.selector,
            gss.nonce() + 1,
            ownerHash,
            THRESHOLD,
            newOwners
        );
        _executeThroughGSS(address(checker), ownerAction);

        uint256 nonceBeforeRejectedFee = gss.nonce();
        bytes memory feeAction = abi.encodeWithSelector(
            CHANGE_FEES,
            nonceBeforeRejectedFee + 1,
            newOwnerHash,
            _feeUpdates(CHAIN_A, CHAIN_B)
        );
        GnosisSafeTx.Transaction memory feeTx =
            _txTo(address(checker), feeAction, nonceBeforeRejectedFee);
        bytes memory signatures = _signWith(feeTx, _ownerKeys(), THRESHOLD);

        vm.expectRevert();
        gss.execTransaction(
            address(checker),
            0,
            feeAction,
            0,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
        assertEq(gss.nonce(), nonceBeforeRejectedFee);
        assertEq(checker.latestSafeNonce(), nonceBeforeRejectedFee);
    }

    function test_governanceConfigurationRequiresRelayModeAndNoOldRelay() public {
        vm.chainId(CHAIN_A);
        vm.expectRevert(IRelayGovernance.InvalidGovernanceDeployment.selector);
        new Relay(_relayConfig(address(gss)), address(this), IRelay(address(0)));

        vm.expectRevert(IRelayGovernance.InvalidGovernanceDeployment.selector);
        new Relay(_relayConfig(address(gss)), address(0), IRelay(address(relayA)));
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
        c.governanceSourceChainId = SOURCE_CHAIN;
        c.governanceSafe = safe;
        c.governanceThreshold = THRESHOLD;
        c.governanceOwners = owners;
        c.governanceSafeNonce = 0;
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
        internal pure returns (GnosisSafeTx.Transaction memory t)
    {
        t.to = target;
        t.data = data;
        t.nonce = nonce;
    }

    function _signWith(
        GnosisSafeTx.Transaction memory t,
        uint256[] memory signingKeys,
        uint256 signatureCount
    )
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
        bytes32 digest = IRealGSS(address(gss)).getTransactionHash(
            t.to, t.value, t.data, t.operation, t.safeTxGas, t.baseGas, t.gasPrice,
            t.gasToken, t.refundReceiver, t.nonce
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
            while (j > 0 && values[j - 1] > value) { values[j] = values[j - 1]; --j; }
            values[j] = value;
        }
    }
    function _executeThroughGSS(address target, bytes memory data)
        internal returns (GnosisSafeTx.Transaction memory txData, bytes memory signatures)
    {
        return _executeThroughGSSWithKeys(target, data, _ownerKeys(), THRESHOLD);
    }

    function _executeThroughGSSWithKeys(
        address target,
        bytes memory data,
        uint256[] memory signingKeys,
        uint256 signatureCount
    )
        internal returns (GnosisSafeTx.Transaction memory txData, bytes memory signatures)
    {
        uint256 safeNonce = gss.nonce();
        txData = _txTo(target, data, safeNonce);
        signatures = _signWith(txData, signingKeys, signatureCount);
        bool success = gss.execTransaction(
            target, 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        assertTrue(success);
    }

    function _establishInitialConfiguration() internal {
        vm.chainId(SOURCE_CHAIN);
        bytes memory action = abi.encodeWithSelector(
            checker.changeOwners.selector, gss.nonce() + 1, bytes32(0), THRESHOLD, owners
        );
        _executeThroughGSS(address(checker), action);
    }

    function _ownerKeys() internal view returns (uint256[] memory result) {
        result = new uint256[](keys.length);
        for (uint256 i; i < keys.length; ++i) result[i] = keys[i];
    }

    function _replaceOwner(
        address[] memory currentOwners,
        address oldOwner,
        address newOwner
    ) internal pure returns (address[] memory result) {
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

    function _replaceOwnerKey(
        uint256[] memory currentKeys,
        address oldOwner,
        uint256 newKey
    ) internal view returns (uint256[] memory result) {
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
