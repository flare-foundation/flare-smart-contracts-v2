// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/FlareSystemCalculator.sol";

contract FlareSystemCalculatorTest is Test {
    FlareSystemCalculator calculator;
    FlareSystemCalculator calculatorNoMirroring;

    IGovernanceSettings govSetting;
    address governance;

    uint256 internal constant max = 2 ** 128;

    function setUp() public {
        govSetting = IGovernanceSettings(makeAddr("govSetting"));
        governance = makeAddr("initialGovernence");

        calculator =
            new FlareSystemCalculator(govSetting, governance, makeAddr("AddressUpdater"), 200000, 20 * 60, 600, 600);

        calculatorNoMirroring =
            new FlareSystemCalculator(govSetting, governance, makeAddr("AddressUpdater"), 200000, 20 * 60, 600, 600);

        bytes32[] memory contractNameHashes = new bytes32[](7);
        contractNameHashes[0] = keccak256(abi.encode("EntityManager"));
        contractNameHashes[1] = keccak256(abi.encode("WNatDelegationFee"));
        contractNameHashes[2] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[3] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[4] = keccak256(abi.encode("WNat"));
        contractNameHashes[5] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[6] = keccak256(abi.encode("FlareSystemManager"));

        address[] memory contractAddresses = new address[](7);
        contractAddresses[0] = makeAddr("EntityManager");
        contractAddresses[1] = makeAddr("WNatDelegationFee");
        contractAddresses[2] = makeAddr("VoterRegistry");
        contractAddresses[3] = makeAddr("PChainStakeMirror");
        contractAddresses[4] = makeAddr("WNat");
        contractAddresses[5] = makeAddr("AddressUpdater");
        contractAddresses[6] = makeAddr("FlareSystemManager");

        vm.prank(governance);
        calculator.enablePChainStakeMirror();

        vm.prank(calculator.getAddressUpdater());
        calculator.updateContractAddresses(contractNameHashes, contractAddresses);

        vm.prank(calculatorNoMirroring.getAddressUpdater());
        calculatorNoMirroring.updateContractAddresses(contractNameHashes, contractAddresses);
    }

    function testFuzz_perfectSquare(uint256 n) public {
        vm.assume(n < max);
        uint128 root = calculator.sqrt(n * n);
        assertEq(root, n);
    }

    function testFuzz_perfectSquareMinusOne(uint256 n) public {
        vm.assume(n < max);
        vm.assume(0 < n);
        uint128 root = calculator.sqrt((n * n) - 1);
        assertEq(root, n - 1);
    }

    function testFuzz_perfectSquarePlusN(uint256 n) public {
        vm.assume(n < max);
        uint128 root = calculator.sqrt(n * (n + 1));
        assertEq(root, n);
    }

    function testFuzz_perfectSquareMinusN(uint256 n) public {
        vm.assume(n < max);
        vm.assume(0 < n);

        uint128 root = calculator.sqrt(n * (n - 1));
        assertEq(root, n - 1);
    }

    function test_setWNatCapFail1() public {
        vm.expectRevert("only governance");
        calculator.setWNatCapPPM(1000);
    }

    function test_setWNatCapFail2() public {
        vm.expectRevert("_wNatCapPPM too high");

        vm.prank(makeAddr("initialGovernence"));

        calculator.setWNatCapPPM(1000001);
    }

    function test_setWNatCap() public {
        vm.prank(makeAddr("initialGovernence"));

        calculator.setWNatCapPPM(30000);

        assertEq(calculator.wNatCapPPM(), uint24(30000));
    }

    function test_calculateRegistrationWeight() public {
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
        uint24 rewardEpochId = 12345;
        uint256 votePowerBlockNumber = 1234567;

        vm.mockCall(
            address(calculator.voterRegistry()),
            abi.encodeWithSelector(IVoterRegistry.chilledUntilRewardEpochId.selector, bytes20(delegationAddress)),
            abi.encode(0)
        );
        for (uint256 i = 0; i < nodeIds.length; i++) {
            vm.mockCall(
                address(calculator.voterRegistry()),
                abi.encodeWithSelector(IVoterRegistry.chilledUntilRewardEpochId.selector, nodeIds[i]),
                abi.encode(0)
            );
        }

        vm.mockCall(
            address(calculator.entityManager()),
            abi.encodeWithSelector(IEntityManager.getNodeIdsOfAt.selector, voter, votePowerBlockNumber),
            abi.encode(nodeIds)
        );

        vm.mockCall(
            address(calculator.pChainStakeMirror()),
            abi.encodeWithSelector(
                bytes4(keccak256("batchVotePowerOfAt(bytes20[],uint256)")), nodeIds, votePowerBlockNumber
            ),
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
                bytes4(keccak256("votePowerOfAt(address,uint256)")), delegationAddress, votePowerBlockNumber
            ),
            abi.encode(wNatWeight)
        );

        vm.mockCall(
            address(calculator.wNatDelegationFee()),
            abi.encodeWithSelector(IWNatDelegationFee.getVoterFeePercentage.selector, voter, rewardEpochId),
            abi.encode(delegationFeeBIPS)
        );

        vm.prank(address(calculatorNoMirroring.voterRegistry()));

        uint256 registrationWeight =
            calculator.calculateRegistrationWeight(voter, delegationAddress, rewardEpochId, votePowerBlockNumber);

        assertEq(registrationWeight < 9809897, true);
        assertEq(registrationWeight > 5623, true);
    }

    function test_calculateRegistrationWeightNoMirroring() public {
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
        uint24 rewardEpochId = 12345;
        uint256 votePowerBlockNumber = 1234567;

        vm.mockCall(
            address(calculator.voterRegistry()),
            abi.encodeWithSelector(IVoterRegistry.chilledUntilRewardEpochId.selector, bytes20(delegationAddress)),
            abi.encode(0)
        );
        for (uint256 i = 0; i < nodeIds.length; i++) {
            vm.mockCall(
                address(calculator.voterRegistry()),
                abi.encodeWithSelector(IVoterRegistry.chilledUntilRewardEpochId.selector, nodeIds[i]),
                abi.encode(0)
            );
        }

        vm.mockCall(
            address(calculatorNoMirroring.entityManager()),
            abi.encodeWithSelector(IEntityManager.getNodeIdsOfAt.selector, voter, votePowerBlockNumber),
            abi.encode(nodeIds)
        );

        vm.mockCall(
            address(calculatorNoMirroring.pChainStakeMirror()),
            abi.encodeWithSelector(
                bytes4(keccak256("batchVotePowerOfAt(bytes20[],uint256)")), nodeIds, votePowerBlockNumber
            ),
            abi.encode(nodeWeights)
        );

        vm.mockCall(
            address(calculatorNoMirroring.wNat()),
            abi.encodeWithSelector(bytes4(keccak256("totalVotePowerAt(uint256)")), votePowerBlockNumber),
            abi.encode(totalWNatVotePower)
        );

        vm.mockCall(
            address(calculatorNoMirroring.wNat()),
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")), delegationAddress, votePowerBlockNumber
            ),
            abi.encode(wNatWeight)
        );

        vm.mockCall(
            address(calculatorNoMirroring.wNatDelegationFee()),
            abi.encodeWithSelector(IWNatDelegationFee.getVoterFeePercentage.selector, voter, rewardEpochId),
            abi.encode(delegationFeeBIPS)
        );

        vm.prank(address(calculatorNoMirroring.voterRegistry()));
        uint256 registrationWeight = calculatorNoMirroring.calculateRegistrationWeight(
            voter, delegationAddress, rewardEpochId, votePowerBlockNumber
        );

        assertEq(registrationWeight < 5623, true);
    }

    function test_calculateBurnFactorPPMSignedInTime() public {
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

    function test_calculateBurnFactorPPMSignedInTimeBlock() public {
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

    function test_calculateBurnFactorPPMSignedLateVoterOnTime() public {
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

    function test_calculateBurnFactorPPMSignedLateVoterDidNotSign() public {
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

    function test_calculateBurnFactorPPMSignedVeryLateVoterDidNotSign() public {
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

    function test_calculateBurnFactorPPMPolicyNotSigned() public {
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
