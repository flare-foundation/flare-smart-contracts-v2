// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/VoterRegistry.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";

contract VoterRegistryTest is Test {

    VoterRegistry private voterRegistry;
    address private mockFlareSystemManager;
    address private mockEntityManager;
    address private mockPChainStakeMirror;
    address private mockCChainStake;
    address private mockWNat;

    address private governance;
    address private addressUpdater;
    address[] private initialVoters;
    uint16[] private initialNormWeights;
    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint256 private constant UINT16_MAX = type(uint16).max;

    event VoterChilled(address voter, uint256 untilRewardEpochId);
    event VoterRemoved(address voter, uint256 rewardEpochId);
    event VoterRegistered(
        uint256 rewardEpochId,
        address voter,
        address signingPolicyAddress,
        address delegationAddress,
        address submitAddress,
        address submitSignaturesAddress,
        uint256 weight,
        uint256 wNatWeight,
        uint256 cChainStakeWeight,
        bytes20[] nodeIds,
        uint256[] nodeWeights
    );


    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        _createInitialVoters(4);

        voterRegistry = new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5,
            0,
            initialVoters,
            initialNormWeights
        );

        //// update contract addresses
        mockFlareSystemManager = makeAddr("flareSystemManager");
        mockEntityManager = makeAddr("entityManager");
        mockPChainStakeMirror = makeAddr("pChainStakeMirror");
        mockCChainStake = makeAddr("cChainStake");
        mockWNat = makeAddr("wNat");
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = _keccak256AbiEncode("AddressUpdater");
        contractNameHashes[1] = _keccak256AbiEncode("FlareSystemManager");
        contractNameHashes[2] = _keccak256AbiEncode("EntityManager");
        contractNameHashes[3] = _keccak256AbiEncode("PChainStakeMirror");
        contractNameHashes[4] = _keccak256AbiEncode("CChainStake");
        contractNameHashes[5] = _keccak256AbiEncode("WNat");
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemManager;
        contractAddresses[2] = mockEntityManager;
        contractAddresses[3] = mockPChainStakeMirror;
        contractAddresses[4] = mockCChainStake;
        contractAddresses[5] = mockWNat;
        voterRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();
    }

    function testRevertMaxVotersTooHigh() public {
        vm.expectRevert("_maxVoters too high");
        new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            UINT16_MAX + 1,
            0,
            initialVoters,
            initialNormWeights
        );
    }

    function testRevertInitialVotersInvalidLength() public {
        vm.expectRevert("_initialVoters length invalid");
        new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            1,
            0,
            initialVoters,
            initialNormWeights
        );
    }

    function testRevertArrayLengthsDontMatch() public {
        initialVoters.pop();
        vm.expectRevert("array lengths do not match");
        new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            5,
            0,
            initialVoters,
            initialNormWeights
        );
    }

    function testChillVoter() public {
        vm.prank(governance);
        _mockGetCurrentEpochId(1);
        vm.expectEmit();
        emit VoterChilled(initialVoters[0], 3);
        voterRegistry.chillVoter(initialVoters[0], 2);
    }

    function testSetMaxVoters() public {
        vm.startPrank(governance);
        vm.expectRevert("_maxVoters too high");
        voterRegistry.setMaxVoters(UINT16_MAX + 1);

        assertEq(voterRegistry.maxVoters(), 5);
        voterRegistry.setMaxVoters(100);
        assertEq(voterRegistry.maxVoters(), 100);
        vm.stopPrank();
    }

    function testEnableCChainStake() public {
        assertEq(voterRegistry.cChainStakeEnabled(), false);
        vm.prank(governance);
        voterRegistry.enableCChainStake();
        assertEq(voterRegistry.cChainStakeEnabled(), true);
        assertEq(address(voterRegistry.cChainStake()), address(0));
        vm.prank(addressUpdater);
        voterRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        assertEq(address(voterRegistry.cChainStake()), mockCChainStake);
    }

    function testSetNewSigningPolicyInitializationStartBlockNumber() public {
        vm.startPrank(mockFlareSystemManager);
        vm.roll(123);
        assertEq(voterRegistry.newSigningPolicyInitializationStartBlockNumber(0), 0);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(0);
        assertEq(voterRegistry.newSigningPolicyInitializationStartBlockNumber(0), 123);

        vm.expectRevert();
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(0);
        vm.stopPrank();
    }



    ///// helper functions
    function _createInitialVoters(uint256 _num) internal {
        for (uint256 i = 0; i < _num; i++) {
            initialVoters.push(makeAddr(
                string.concat("initialVoter", vm.toString(i))));
            initialNormWeights.push(uint16(UINT16_MAX / _num));
        }
    }

    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }


}