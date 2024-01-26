// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/FlareSystemCalculator.sol";

contract FlareSystemCalculatorTest is Test {
  FlareSystemCalculator private calculator;

  IGovernanceSettings private govSetting;
  address private governance;
  address private addressUpdater;

  bytes32[] private contractNameHashes;
  address[] private contractAddresses;

  uint256 internal constant MAX = 2 ** 128;

  function setUp() public {
    govSetting = IGovernanceSettings(makeAddr("govSetting"));
    governance = makeAddr("initialGovernence");
    addressUpdater = makeAddr("AddressUpdater");

    calculator = new FlareSystemCalculator(
      govSetting,
      governance,
      addressUpdater,
      200000,
      20 * 60,
      600,
      600
    );

    contractNameHashes = new bytes32[](7);
    contractNameHashes[0] = keccak256(abi.encode("EntityManager"));
    contractNameHashes[1] = keccak256(abi.encode("WNatDelegationFee"));
    contractNameHashes[2] = keccak256(abi.encode("VoterRegistry"));
    contractNameHashes[3] = keccak256(abi.encode("PChainStakeMirror"));
    contractNameHashes[4] = keccak256(abi.encode("WNat"));
    contractNameHashes[5] = keccak256(abi.encode("AddressUpdater"));
    contractNameHashes[6] = keccak256(abi.encode("FlareSystemManager"));

    contractAddresses = new address[](7);
    contractAddresses[0] = makeAddr("EntityManager");
    contractAddresses[1] = makeAddr("WNatDelegationFee");
    contractAddresses[2] = makeAddr("VoterRegistry");
    contractAddresses[3] = makeAddr("PChainStakeMirror");
    contractAddresses[4] = makeAddr("WNat");
    contractAddresses[5] = addressUpdater;
    contractAddresses[6] = makeAddr("FlareSystemManager");

    vm.prank(addressUpdater);
    calculator.updateContractAddresses(contractNameHashes, contractAddresses);
  }

  function testFuzzPerfectSquare(uint256 n) public {
    vm.assume(n < MAX);
    uint128 root = calculator.sqrt(n * n);
    assertEq(root, n);
  }

  function testFuzzPerfectSquareMinusOne(uint256 n) public {
    vm.assume(n < MAX);
    vm.assume(0 < n);
    uint128 root = calculator.sqrt((n * n) - 1);
    assertEq(root, n - 1);
  }

  function testFuzzPerfectSquarePlusN(uint256 n) public {
    vm.assume(n < MAX);
    uint128 root = calculator.sqrt(n * (n + 1));
    assertEq(root, n);
  }

  function testFuzzPerfectSquareMinusN(uint256 n) public {
    vm.assume(n < MAX);
    vm.assume(0 < n);

    uint128 root = calculator.sqrt(n * (n - 1));
    assertEq(root, n - 1);
  }

  function testWNatCapFail1() public {
    vm.expectRevert("only governance");
    calculator.setWNatCapPPM(1000);
  }

  function testWNatCapFail2() public {
    vm.expectRevert("_wNatCapPPM too high");

    vm.prank(makeAddr("initialGovernence"));

    calculator.setWNatCapPPM(1000001);
  }

  function testSetWNatCap() public {
    vm.prank(makeAddr("initialGovernence"));

    calculator.setWNatCapPPM(30000);

    assertEq(calculator.wNatCapPPM(), uint24(30000));
  }

  function testCalculateRegistrationWeight() public {
    vm.prank(governance);
    calculator.enablePChainStakeMirror();

    vm.prank(addressUpdater);
    calculator.updateContractAddresses(contractNameHashes, contractAddresses);

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
    address delegationAddress = makeAddr("delegation");
    uint24 rewardEpochId = 12345;
    uint256 votePowerBlockNumber = 1234567;

    vm.mockCall(
      address(calculator.entityManager()),
      abi.encodeWithSelector(IEntityManager.getNodeIdsOfAt.selector, voter, votePowerBlockNumber),
      abi.encode(nodeIds)
    );

    vm.mockCall(
      address(calculator.pChainStakeMirror()),
      abi.encodeWithSelector(bytes4(keccak256("batchVotePowerOfAt(bytes20[],uint256)")),
        nodeIds, votePowerBlockNumber),
      abi.encode(nodeWeights)
    );

    vm.mockCall(
      address(calculator.wNat()),
      abi.encodeWithSelector(bytes4(keccak256("totalVotePowerAt(uint256)")), votePowerBlockNumber),
      abi.encode(totalWNatVotePower)
    );

    vm.mockCall(
      address(calculator.wNat()),
      abi.encodeWithSelector(
        bytes4(keccak256("votePowerOfAt(address,uint256)")),
        delegationAddress,
        votePowerBlockNumber
      ),
      abi.encode(wNatWeight)
    );

    vm.mockCall(
      address(calculator.wNatDelegationFee()),
      abi.encodeWithSelector(IWNatDelegationFee.getVoterFeePercentage.selector, voter, rewardEpochId),
      abi.encode(delegationFeeBIPS)
    );

    vm.prank(makeAddr("VoterRegistry"));
    uint256 registrationWeight = calculator.calculateRegistrationWeight(
      voter,
      delegationAddress,
      rewardEpochId,
      votePowerBlockNumber
    );
    assertEq(registrationWeight < 9809897, true);
  }

  function testCalculateRegistrationWeightWithoutMirroring() public {
    bytes20[] memory nodeIds = new bytes20[](3);
    nodeIds[0] = bytes20(makeAddr("1"));
    nodeIds[1] = bytes20(makeAddr("2"));
    nodeIds[2] = bytes20(makeAddr("3"));

    uint256 totalWNatVotePower = 1e7;
    uint256 wNatWeight = 10000;
    uint16 delegationFeeBIPS = 15;
    address voter = makeAddr("voter");
    address delegationAddress = makeAddr("delegation");
    uint24 rewardEpochId = 12345;
    uint256 votePowerBlockNumber = 1234567;

    vm.mockCall(
      address(calculator.entityManager()),
      abi.encodeWithSelector(IEntityManager.getNodeIdsOfAt.selector, voter, votePowerBlockNumber),
      abi.encode(nodeIds)
    );

    vm.mockCall(
      address(calculator.wNat()),
      abi.encodeWithSelector(bytes4(keccak256("totalVotePowerAt(uint256)")), votePowerBlockNumber),
      abi.encode(totalWNatVotePower)
    );

    vm.mockCall(
      address(calculator.wNatDelegationFee()),
      abi.encodeWithSelector(IWNatDelegationFee.getVoterFeePercentage.selector, voter, rewardEpochId),
      abi.encode(delegationFeeBIPS)
    );

     vm.mockCall(
      address(calculator.wNat()),
      abi.encodeWithSelector(
        bytes4(keccak256("votePowerOfAt(address,uint256)")),
        delegationAddress,
        votePowerBlockNumber
      ),
      abi.encode(wNatWeight)
    );

    vm.prank(makeAddr("VoterRegistry"));
    uint256 registrationWeight = calculator.calculateRegistrationWeight(
      voter,
      delegationAddress,
      rewardEpochId,
      votePowerBlockNumber
    );
    assertEq(registrationWeight, 1000);
  }

  function testCalculateBurnFactorPPMSignedInTime() public {
    address voter = makeAddr("voter");
    uint24 rewardEpochId = 10000;

    uint64 startTs = 1e6;
    uint64 startBlock = 100000;
    uint64 endTs = 1e6 + 1000;
    uint64 endBlock = 100300;

    uint64 signTs = 1e6 + 1e5 + 1;
    uint64 signBlock = 110001;

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getSigningPolicySignInfo.selector, rewardEpochId),
      abi.encode(startTs, startBlock, endTs, endBlock)
    );

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getVoterSigningPolicySignInfo.selector, rewardEpochId, voter),
      abi.encode(signTs, signBlock)
    );

    uint256 burnFactor = calculator.calculateBurnFactorPPM(rewardEpochId - 1, voter);
    assertEq(burnFactor, 0);
  }

  function testCalculateBurnFactorPPMSignedInTimeBlock() public {
    address voter = makeAddr("voter");
    uint24 rewardEpochId = 10000;

    uint64 startTs = 1e6;
    uint64 startBlock = 100000;
    uint64 endTs = 1e6 + 1e5;
    uint64 endBlock = 100300;

    uint64 signTs = 1e6 + 1e5 + 1;
    uint64 signBlock = 110001;

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getSigningPolicySignInfo.selector, rewardEpochId),
      abi.encode(startTs, startBlock, endTs, endBlock)
    );

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getVoterSigningPolicySignInfo.selector, rewardEpochId, voter),
      abi.encode(signTs, signBlock)
    );

    uint256 burnFactor = calculator.calculateBurnFactorPPM(rewardEpochId - 1, voter);
    assertEq(burnFactor, 0);
  }

  function testCalculateBurnFactorPPMSignedLateVoterOnTime() public {
    address voter = makeAddr("voter");
    uint24 rewardEpochId = 10000;

    uint64 startTs = 1e6;
    uint64 startBlock = 100000;
    uint64 endTs = 1e6 + 1e5;
    uint64 endBlock = 101500;

    uint64 signTs = 1e6 + 100;
    uint64 signBlock = 100100;

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getSigningPolicySignInfo.selector, rewardEpochId),
      abi.encode(startTs, startBlock, endTs, endBlock)
    );

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getVoterSigningPolicySignInfo.selector, rewardEpochId, voter),
      abi.encode(signTs, signBlock)
    );

    uint256 burnFactor = calculator.calculateBurnFactorPPM(rewardEpochId - 1, voter);
    assertEq(burnFactor, 0);
  }

  function testCalculateBurnFactorPPMSignedLateVoterDidNotSign() public {
    address voter = makeAddr("voter");
    uint24 rewardEpochId = 10000;

    uint64 startTs = 1e6;
    uint64 startBlock = 100000;
    uint64 endTs = 1e6 + 1e5;
    uint64 endBlock = 101100;

    uint64 signTs = 0;
    uint64 signBlock = 0;

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getSigningPolicySignInfo.selector, rewardEpochId),
      abi.encode(startTs, startBlock, endTs, endBlock)
    );

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getVoterSigningPolicySignInfo.selector, rewardEpochId, voter),
      abi.encode(signTs, signBlock)
    );

    uint256 burnFactor = calculator.calculateBurnFactorPPM(rewardEpochId - 1, voter);
    assertEq(burnFactor > 0, true);
    assertEq(burnFactor < 1e6, true);
  }

  function testCalculateBurnFactorPPMSignedVeryLateVoterDidNotSign() public {
    address voter = makeAddr("voter");
    uint24 rewardEpochId = 10000;

    uint64 startTs = 1e6;
    uint64 startBlock = 100000;
    uint64 endTs = 1e6 + 1e5;
    uint64 endBlock = 101500;

    uint64 signTs = 0;
    uint64 signBlock = 0;

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getSigningPolicySignInfo.selector, rewardEpochId),
      abi.encode(startTs, startBlock, endTs, endBlock)
    );

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getVoterSigningPolicySignInfo.selector, rewardEpochId, voter),
      abi.encode(signTs, signBlock)
    );

    uint256 burnFactor = calculator.calculateBurnFactorPPM(rewardEpochId - 1, voter);
    assertEq(burnFactor, 1e6);
  }

  function testCalculateBurnFactorPPMPolicyNotSigned() public {
    address voter = makeAddr("voter");
    uint24 rewardEpochId = 10000;

    uint64 startTs = 1e6;
    uint64 startBlock = 100000;
    uint64 endTs = 0;
    uint64 endBlock = 0;

    uint64 signTs = 1e6 + 1e5 + 1;
    uint64 signBlock = 110001;

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getSigningPolicySignInfo.selector, rewardEpochId),
      abi.encode(startTs, startBlock, endTs, endBlock)
    );

    vm.mockCall(
      address(calculator.flareSystemManager()),
      abi.encodeWithSelector(IIFlareSystemManager.getVoterSigningPolicySignInfo.selector, rewardEpochId, voter),
      abi.encode(signTs, signBlock)
    );

    vm.expectRevert("signing policy not signed yet");
    calculator.calculateBurnFactorPPM(rewardEpochId - 1, voter);
  }
}
