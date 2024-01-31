// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/FlareSystemCalculator.sol";

contract FlareSystemCalculatorTest is Test {
    FlareSystemCalculator internal calculator;
    FlareSystemCalculator internal calculatorNoMirroring;

    IGovernanceSettings internal govSetting;
    address internal governance;

    uint256 internal constant MAX = 2 ** 128;
    uint24 internal constant WNAT_CAP = 10000;
    uint256 internal constant TOTAL_WNAT_VOTE_POWER = 1e7;
    uint256 internal constant WNAT_WEIGHT = 2e5;
    uint16 internal constant DELEGATION_FEE_BIPS = 15;

    event VoterRegistrationInfo(
        address indexed voter,
        uint24 indexed rewardEpochId,
        address delegationAddress,
        uint16 delegationFeeBIPS,
        uint256 wNatWeight,
        uint256 wNatCappedWeight,
        bytes20[] nodeIds,
        uint256[] nodeWeights
    );

    function setUp() public {
        govSetting = IGovernanceSettings(makeAddr("govSetting"));
        governance = makeAddr("initialGovernence");

        calculator =
            new FlareSystemCalculator(govSetting, governance, makeAddr("AddressUpdater"), WNAT_CAP, 20 * 60, 600, 600);

        calculatorNoMirroring =
            new FlareSystemCalculator(govSetting, governance, makeAddr("AddressUpdater"), WNAT_CAP, 20 * 60, 600, 600);

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
        vm.assume(n < MAX);
        uint128 root = calculator.sqrt(n * n);
        assertEq(root, n);
    }

    function testFuzz_perfectSquareMinusOne(uint256 n) public {
        vm.assume(n < MAX);
        vm.assume(0 < n);
        uint128 root = calculator.sqrt((n * n) - 1);
        assertEq(root, n - 1);
    }

    function testFuzz_perfectSquarePlusN(uint256 n) public {
        vm.assume(n < MAX);
        uint128 root = calculator.sqrt(n * (n + 1));
        assertEq(root, n);
    }

    function testFuzz_perfectSquareMinusN(uint256 n) public {
        vm.assume(n < MAX);
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
            address(calculator.entityManager()),
            abi.encodeWithSelector(IEntityManager.getDelegationAddressOfAt.selector, voter, votePowerBlockNumber),
            abi.encode(delegationAddress)
        );

        vm.mockCall(
            address(calculator.wNat()),
            abi.encodeWithSelector(bytes4(keccak256("totalVotePowerAt(uint256)")), votePowerBlockNumber),
            abi.encode(TOTAL_WNAT_VOTE_POWER)
        );

        vm.mockCall(
            address(calculator.wNat()),
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")), delegationAddress, votePowerBlockNumber
            ),
            abi.encode(WNAT_WEIGHT)
        );

        vm.mockCall(
            address(calculator.wNatDelegationFee()),
            abi.encodeWithSelector(IWNatDelegationFee.getVoterFeePercentage.selector, voter, rewardEpochId),
            abi.encode(DELEGATION_FEE_BIPS)
        );

        vm.expectEmit();
        emit VoterRegistrationInfo(
            voter,
            rewardEpochId,
            delegationAddress,
            DELEGATION_FEE_BIPS,
            WNAT_WEIGHT,
            Math.min(WNAT_WEIGHT, TOTAL_WNAT_VOTE_POWER * WNAT_CAP / 1e6), // 1e5
            nodeIds,
            nodeWeights
        );
        vm.prank(address(calculatorNoMirroring.voterRegistry()));
        uint256 registrationWeight =
            calculator.calculateRegistrationWeight(voter, rewardEpochId, votePowerBlockNumber);

        // sum of weights = 2100100000
        // sqrt(2100100000) = 45826
        // sqrt(45826) = 214
        assertEq(registrationWeight, 45826 * 214);
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
            address(calculator.entityManager()),
            abi.encodeWithSelector(IEntityManager.getDelegationAddressOfAt.selector, voter, votePowerBlockNumber),
            abi.encode(delegationAddress)
        );

        vm.mockCall(
            address(calculatorNoMirroring.wNat()),
            abi.encodeWithSelector(bytes4(keccak256("totalVotePowerAt(uint256)")), votePowerBlockNumber),
            abi.encode(TOTAL_WNAT_VOTE_POWER)
        );

        vm.mockCall(
            address(calculatorNoMirroring.wNat()),
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")), delegationAddress, votePowerBlockNumber
            ),
            abi.encode(WNAT_WEIGHT)
        );

        vm.mockCall(
            address(calculatorNoMirroring.wNatDelegationFee()),
            abi.encodeWithSelector(IWNatDelegationFee.getVoterFeePercentage.selector, voter, rewardEpochId),
            abi.encode(DELEGATION_FEE_BIPS)
        );

        // no mirroring
        nodeWeights[0] = 0;
        nodeWeights[1] = 0;
        nodeWeights[2] = 0;
        vm.expectEmit();
        emit VoterRegistrationInfo(
            voter,
            rewardEpochId,
            delegationAddress,
            DELEGATION_FEE_BIPS,
            WNAT_WEIGHT,
            Math.min(WNAT_WEIGHT, TOTAL_WNAT_VOTE_POWER * WNAT_CAP / 1e6), // 1e5
            nodeIds,
            nodeWeights
        );
        vm.prank(address(calculatorNoMirroring.voterRegistry()));
        uint256 registrationWeight = calculatorNoMirroring.calculateRegistrationWeight(
            voter, rewardEpochId, votePowerBlockNumber
        );

        // sum of weights = 100000
        // sqrt(100000) = 316
        // sqrt(316) = 17
        assertEq(registrationWeight, 316 * 17);
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
