// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {IRelay} from "../../../../contracts/userInterfaces/IRelay.sol";

/// Pins the literal 4-byte selectors baked into Relay's assembly revert table (ERR_* constants)
/// to the compiler-derived selectors of the IRelay error declarations. Any drift between the
/// generated literals and the declared errors fails here.
contract RelayErrorSelectorsTest is Test {
    function test_assemblyErrorSelectorTableMatchesDeclarations() public pure {
        assertEq(bytes4(0xd0ebeb4b), IRelay.AlreadyRelayed.selector, "AlreadyRelayed");
        assertEq(bytes4(0xf54d11f5), IRelay.BadS.selector, "BadS");
        assertEq(bytes4(0x8320c358), IRelay.BadV.selector, "BadV");
        assertEq(bytes4(0x0c01bf37), IRelay.DelayedSignPolicy.selector, "DelayedSignPolicy");
        assertEq(bytes4(0xc859b3f5), IRelay.EcrecoverError.selector, "EcrecoverError");
        assertEq(bytes4(0x62bd175a), IRelay.EcrecoverReturnedBadData.selector, "EcrecoverReturnedBadData");
        assertEq(bytes4(0x5d2f8a05), IRelay.IncorrectMerkleProof.selector, "IncorrectMerkleProof");
        assertEq(bytes4(0x297f31e1), IRelay.IndexOutOfOrder.selector, "IndexOutOfOrder");
        assertEq(bytes4(0x1390f2a1), IRelay.IndexOutOfRange.selector, "IndexOutOfRange");
        assertEq(bytes4(0x987d1299), IRelay.InvalidRandomNumberProof.selector, "InvalidRandomNumberProof");
        assertEq(bytes4(0x5509ecdf), IRelay.InvalidSignPolicyLength.selector, "InvalidSignPolicyLength");
        assertEq(bytes4(0x3fcc839e), IRelay.InvalidSignPolicyMetadata.selector, "InvalidSignPolicyMetadata");
        assertEq(bytes4(0x01ed5f84), IRelay.InvalidVotingRoundId.selector, "InvalidVotingRoundId");
        assertEq(bytes4(0x4ed02d0d), IRelay.MessageTooOld.selector, "MessageTooOld");
        assertEq(bytes4(0xf64fd99c), IRelay.MustUseNewSignPolicy.selector, "MustUseNewSignPolicy");
        assertEq(bytes4(0xf63c072c), IRelay.NoNewSignPolicySize.selector, "NoNewSignPolicySize");
        assertEq(bytes4(0xd76adcd1), IRelay.NoRandomNumber.selector, "NoRandomNumber");
        assertEq(bytes4(0xf8139caf), IRelay.NoSignatureCount.selector, "NoSignatureCount");
        assertEq(bytes4(0xe246dc63), IRelay.NotEnoughSignatures.selector, "NotEnoughSignatures");
        assertEq(bytes4(0x124f824d), IRelay.NotNextRewardEpoch.selector, "NotNextRewardEpoch");
        assertEq(bytes4(0xbe8b3520), IRelay.NotWithLastInitialized.selector, "NotWithLastInitialized");
        assertEq(bytes4(0xf0059553), IRelay.SignPolicyRelayDisabled.selector, "SignPolicyRelayDisabled");
        assertEq(bytes4(0x53c236da), IRelay.SigningPolicyEmpty.selector, "SigningPolicyEmpty");
        assertEq(bytes4(0x143fc35c), IRelay.SigningPolicyHashMismatch.selector, "SigningPolicyHashMismatch");
        assertEq(bytes4(0xe56d58cf), IRelay.ThresholdTooHigh.selector, "ThresholdTooHigh");
        assertEq(bytes4(0x398ecf8a), IRelay.ThresholdTooLow.selector, "ThresholdTooLow");
        assertEq(bytes4(0x4647aac9), IRelay.TooManyVoters.selector, "TooManyVoters");
        assertEq(bytes4(0x43a69646), IRelay.TooShortMessage.selector, "TooShortMessage");
        assertEq(bytes4(0x8dd23571), IRelay.TotalWeightTooBig.selector, "TotalWeightTooBig");
        assertEq(bytes4(0xe0c9078c), IRelay.UnreachableCode.selector, "UnreachableCode");
        assertEq(bytes4(0xe3427225), IRelay.WrongMessageFormat.selector, "WrongMessageFormat");
        assertEq(bytes4(0x4913ec0d), IRelay.WrongMessageFormat2.selector, "WrongMessageFormat2");
        assertEq(bytes4(0x8134d963), IRelay.WrongSignPolicyRewardEpoch.selector, "WrongSignPolicyRewardEpoch");
        assertEq(bytes4(0x356a4418), IRelay.WrongSignature.selector, "WrongSignature");
        assertEq(bytes4(0x60c18b0d), IRelay.WrongSizeForNewSignPolicy.selector, "WrongSizeForNewSignPolicy");
        assertEq(bytes4(0x9266ee62), IRelay.ZeroMerkleRoot.selector, "ZeroMerkleRoot");
        assertEq(bytes4(0xe5c48ac5), IRelay.ZeroSigner.selector, "ZeroSigner");
    }
}
