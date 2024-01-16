// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/SigningPolicyWeightCalculator.sol";

contract SigningPolicyWeightCalculatorTest is Test {
  SigningPolicyWeightCalculator calcualtor;

  IGovernanceSettings govSetting;

  uint256 internal constant max = 2 ** 128;

  function setUp() public {
    govSetting = IGovernanceSettings(makeAddr("govSetting"));

    calcualtor = new SigningPolicyWeightCalculator(
      govSetting,
      makeAddr("initialGovernence"),
      makeAddr("AddressUpdater"),
      200000
    );

    bytes32[] memory contractNameHashes = new bytes32[](6);
    contractNameHashes[0] = keccak256(abi.encode("EntityManager"));
    contractNameHashes[1] = keccak256(abi.encode("RewardManager"));
    contractNameHashes[2] = keccak256(abi.encode("VoterRegistry"));
    contractNameHashes[3] = keccak256(abi.encode("PChainStakeMirror"));
    contractNameHashes[4] = keccak256(abi.encode("WNat"));
    contractNameHashes[5] = keccak256(abi.encode("AddressUpdater"));

    address[] memory contractAddresses = new address[](6);
    contractAddresses[0] = makeAddr("EntityManager");
    contractAddresses[1] = makeAddr("RewardManager");
    contractAddresses[2] = makeAddr("VoterRegistry");
    contractAddresses[3] = makeAddr("PChainStakeMirror");
    contractAddresses[4] = makeAddr("WNat");
    contractAddresses[5] = makeAddr("AddressUpdater");

    vm.prank(calcualtor.getAddressUpdater());
    calcualtor.updateContractAddresses(contractNameHashes, contractAddresses);
  }

  function testFuzz_perfectSquare(uint256 n) public {
    vm.assume(n < max);
    uint128 root = calcualtor.sqrt(n * n);
    assertEq(root, n);
  }

  function testFuzz_perfectSquareMinusOne(uint256 n) public {
    vm.assume(n < max);
    vm.assume(0 < n);
    uint128 root = calcualtor.sqrt((n * n) - 1);
    assertEq(root, n - 1);
  }

  function testFuzz_perfectSquarePlusN(uint256 n) public {
    vm.assume(n < max);
    uint128 root = calcualtor.sqrt(n * (n + 1));
    assertEq(root, n);
  }

  function testFuzz_perfectSquareMinusN(uint256 n) public {
    vm.assume(n < max);
    vm.assume(0 < n);

    uint128 root = calcualtor.sqrt(n * (n - 1));
    assertEq(root, n - 1);
  }

  function test_setWNatCapFail1() public {
    vm.expectRevert("only governance");
    calcualtor.setWNatCapPPM(1000);
  }

  function test_setWNatCapFail2() public {
    vm.expectRevert("_wNatCapPPM too high");

    vm.prank(makeAddr("initialGovernence"));

    calcualtor.setWNatCapPPM(1000001);
  }

  function test_setWNatCap() public {
    vm.prank(makeAddr("initialGovernence"));

    calcualtor.setWNatCapPPM(30000);

    assertEq(calcualtor.wNatCapPPM(), uint24(30000));
  }

  function test_calculateWeight() public {
    bytes20[] memory nodeIds = new bytes20[](3);
    nodeIds[0] = bytes20(makeAddr("1"));
    nodeIds[1] = bytes20(makeAddr("2"));
    nodeIds[2] = bytes20(makeAddr("3"));

    uint256[] memory nodeWeights = new uint256[](3);
    nodeWeights[0] = 1e9;
    nodeWeights[1] = 1e8;
    nodeWeights[2] = 1e9;

    uint256 totalWNatVotePower = 1e7;
    uint256 wNatWeight = 1e5;
    uint16 delegationFeeBIPS = 15;
    address voter = makeAddr("voter");
    address delegationAddress = makeAddr("delagation");
    uint256 rewardEpochId = 12345;
    uint256 votePowerBlockNumber = 1234567;

    vm.mockCall(
      address(calcualtor.entityManager()),
      abi.encodeWithSelector(EntityManager.getNodeIdsOfAt.selector, voter, votePowerBlockNumber),
      abi.encode(nodeIds)
    );

    vm.mockCall(
      address(calcualtor.pChainStakeMirror()),
      abi.encodeWithSelector(bytes4(keccak256("batchVotePowerOfAt(bytes20[],uint256)")), nodeIds, votePowerBlockNumber),
      abi.encode(nodeWeights)
    );

    vm.mockCall(
      address(calcualtor.wNat()),
      abi.encodeWithSelector(bytes4(keccak256("totalVotePowerAt(uint256)")), votePowerBlockNumber),
      abi.encode(totalWNatVotePower)
    );

    vm.mockCall(
      address(calcualtor.wNat()),
      abi.encodeWithSelector(
        bytes4(keccak256("votePowerOfAt(address,uint256)")),
        delegationAddress,
        votePowerBlockNumber
      ),
      abi.encode(wNatWeight)
    );

    vm.mockCall(
      address(calcualtor.rewardManager()),
      abi.encodeWithSelector(RewardManager.getDataProviderFeePercentage.selector, voter, rewardEpochId),
      abi.encode(delegationFeeBIPS)
    );

    vm.prank(makeAddr("VoterRegistry"));

    uint256 signingPolicyWeight = calcualtor.calculateWeight(
      voter,
      delegationAddress,
      rewardEpochId,
      votePowerBlockNumber
    );

    assertEq(signingPolicyWeight < 9809897, true);
  }
}
