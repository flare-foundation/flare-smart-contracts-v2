// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/VoterRegistry.sol";

// solhint-disable-next-line max-states-count
contract VoterRegistryTest is Test {

    VoterRegistry private voterRegistry;
    address private mockFlareSystemsManager;
    address private mockEntityManager;
    address private mockFlareSystemsCalculator;

    address private governance;
    address private addressUpdater;
    address[] private initialVoters;
    uint256[] private initialVotersSigningPolicyPk; // private keys
    uint16[] private initialNormWeights;
    bytes32[] private contractNameHashes;
    address[] private contractAddresses;
    address[] private initialDelegationAddresses;
    address[] private initialSubmitAddresses;
    address[] private initialSubmitSignaturesAddresses;
    address[] private initialSigningPolicyAddresses;
    bytes32[] private initialPublicKeyParts1;
    bytes32[] private initialPublicKeyParts2;
    bytes20[][] private initialNodeIds;
    IEntityManager.VoterAddresses[] private initialVotersRegisteredAddresses;
    uint256[] private initialVotersWeights;
    uint256 private pChainTotalVP;
    uint256 private cChainTotalVP;
    uint256 private wNatTotalVP;

    uint256 private constant UINT16_MAX = type(uint16).max;

    event BeneficiaryChilled(bytes20 indexed beneficiary, uint256 untilRewardEpochId);
    event VoterRemoved(address indexed voter, uint256 indexed rewardEpochId);
    event VoterRegistered(
        address indexed voter,
        uint24 indexed rewardEpochId,
        address indexed signingPolicyAddress,
        address submitAddress,
        address submitSignaturesAddress,
        bytes32 publicKeyPart1,
        bytes32 publicKeyPart2,
        uint256 registrationWeight
    );

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        _createInitialVoters(4);

        voterRegistry = new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            4,
            0,
            initialVoters,
            initialNormWeights
        );

        //// update contract addresses
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockEntityManager = makeAddr("entityManager");
        mockFlareSystemsCalculator = makeAddr("flareSystemsCalculator");
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = _keccak256AbiEncode("AddressUpdater");
        contractNameHashes[1] = _keccak256AbiEncode("FlareSystemsManager");
        contractNameHashes[2] = _keccak256AbiEncode("EntityManager");
        contractNameHashes[3] = _keccak256AbiEncode("FlareSystemsCalculator");
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = mockEntityManager;
        contractAddresses[3] = mockFlareSystemsCalculator;
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
        emit BeneficiaryChilled(bytes20(initialVoters[0]), 4);
        bytes20[] memory voters = new bytes20[](1);
        voters[0] = bytes20(initialVoters[0]);
        voterRegistry.chill(voters, 2);
    }

    function testChillBeneficiaries() public {
        vm.prank(governance);
        _mockGetCurrentEpochId(1);

        bytes20[] memory beneficiaryList = new bytes20[](2);
        beneficiaryList[0] = bytes20(initialVoters[0]);
        bytes20 nodeId = bytes20("node1");
        beneficiaryList[1] = nodeId;

        vm.expectEmit();
        emit BeneficiaryChilled(bytes20(initialVoters[0]), 4);
        vm.expectEmit();
        emit BeneficiaryChilled(nodeId, 4);
        voterRegistry.chill(beneficiaryList, 2);
    }

    function testSetMaxVoters() public {
        vm.startPrank(governance);
        vm.expectRevert("_maxVoters too high");
        voterRegistry.setMaxVoters(UINT16_MAX + 1);

        assertEq(voterRegistry.maxVoters(), 4);
        voterRegistry.setMaxVoters(100);
        assertEq(voterRegistry.maxVoters(), 100);
        vm.stopPrank();
    }

    function testSetNewSigningPolicyInitializationStartBlockNumber() public {
        vm.startPrank(mockFlareSystemsManager);
        vm.roll(123);
        assertEq(voterRegistry.newSigningPolicyInitializationStartBlockNumber(0), 0);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(0);
        assertEq(voterRegistry.newSigningPolicyInitializationStartBlockNumber(0), 123);

        vm.expectRevert();
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(0);
        vm.stopPrank();
    }

    function testRevertCreateSigningPolicySnapshot() public {
        vm.prank(mockFlareSystemsManager);
        vm.expectRevert();
        voterRegistry.createSigningPolicySnapshot(1);
    }


    function testCreateSigningPolicySnapshot() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getSigningPolicyAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSigningPolicyAddresses)
        );
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getPublicKeys.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialPublicKeyParts1, initialPublicKeyParts2)
        );
        vm.prank(mockFlareSystemsManager);
        (address[] memory signPolAddresses, uint16[] memory normWeights, uint16 normWeightsSum) =
            voterRegistry.createSigningPolicySnapshot(0);
        assertEq(initialSigningPolicyAddresses.length, signPolAddresses.length);
        uint16 sum = 0;
        for (uint256 i = 0; i < initialVoters.length; i++) {
            assertEq(signPolAddresses[i], initialSigningPolicyAddresses[i]);
            assertEq(normWeights[i], initialNormWeights[i]);
            sum += initialNormWeights[i];
        }
        assertEq(sum, normWeightsSum);
    }

    function testGetRegisteredVoters() public {
        address[] memory voters = voterRegistry.getRegisteredVoters(0);
        assertEq(voters.length, initialVoters.length);
        for (uint256 i = 0; i < initialVoters.length; i++) {
            assertEq(voters[i], initialVoters[i]);
        }
    }

    function testGetRegisteredSubmitAddresses() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getSubmitAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSubmitAddresses)
        );
        address[] memory submitAddresses = voterRegistry.getRegisteredSubmitAddresses(0);
        assertEq(submitAddresses.length, initialSubmitAddresses.length);
        for (uint256 i = 0; i < initialSubmitAddresses.length; i++) {
            assertEq(submitAddresses[i], initialSubmitAddresses[i]);
        }
    }

    function testRevertGetRegisteredSubmitAddresses() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getRegisteredSubmitAddresses(1);
    }

    function testGetRegisteredSubmitSignaturesAddresses() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getSubmitSignaturesAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSubmitSignaturesAddresses)
        );
        address[] memory submitSignaturesAddresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(0);
        assertEq(submitSignaturesAddresses.length, initialSubmitSignaturesAddresses.length);
        for (uint256 i = 0; i < initialSubmitSignaturesAddresses.length; i++) {
            assertEq(submitSignaturesAddresses[i], initialSubmitSignaturesAddresses[i]);
        }
    }

    function testRevertGetRegisteredSubmitSignaturesAddresses() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getRegisteredSubmitSignaturesAddresses(1);
    }

    function testGetRegisteredDelegationAddresses() public {
        uint256 votePowerBlock = 5;
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getVotePowerBlock.selector),
            abi.encode(votePowerBlock)
        );
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getDelegationAddresses.selector, initialVoters, votePowerBlock),
            abi.encode(initialDelegationAddresses)
        );
        address[] memory delegationAddresses = voterRegistry.getRegisteredDelegationAddresses(0);
        assertEq(delegationAddresses.length, initialDelegationAddresses.length);
        for (uint256 i = 0; i < initialDelegationAddresses.length; i++) {
            assertEq(delegationAddresses[i], initialDelegationAddresses[i]);
        }
    }

    function testRevertGetRegisteredDelegationAddresses() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getRegisteredDelegationAddresses(1);
    }

    function testGetRegisteredSigningPolicyAddresses() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getSigningPolicyAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSigningPolicyAddresses)
        );
        address[] memory signingPolicyAddresses = voterRegistry.getRegisteredSigningPolicyAddresses(0);
        assertEq(signingPolicyAddresses.length, initialSigningPolicyAddresses.length);
        for (uint256 i = 0; i < initialSigningPolicyAddresses.length; i++) {
            assertEq(signingPolicyAddresses[i], initialSigningPolicyAddresses[i]);
        }
    }

    function testRevertGetRegisteredSigningPolicyAddresses() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getRegisteredSigningPolicyAddresses(1);
    }

    function testGetRegisteredPublicKeys() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getPublicKeys.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialPublicKeyParts1, initialPublicKeyParts2)
        );
        (bytes32[] memory parts1, bytes32[] memory parts2) = voterRegistry.getRegisteredPublicKeys(0);
        assertEq(parts1.length, initialPublicKeyParts1.length);
        assertEq(parts2.length, initialPublicKeyParts2.length);
        for (uint256 i = 0; i < initialPublicKeyParts1.length; i++) {
            assertEq(parts1[i], initialPublicKeyParts1[i]);
        }
        for (uint256 i = 0; i < initialPublicKeyParts2.length; i++) {
            assertEq(parts2[i], initialPublicKeyParts2[i]);
        }
    }

    function testRevertGetRegisteredPublicKeys() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getRegisteredPublicKeys(1);
    }

    function testGetRegisteredNodeIds() public {
        uint256 votePowerBlock = 5;
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getVotePowerBlock.selector),
            abi.encode(votePowerBlock)
        );
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getNodeIds.selector, initialVoters, votePowerBlock),
            abi.encode(initialNodeIds)
        );
        bytes20[][] memory nodeIds = voterRegistry.getRegisteredNodeIds(0);
        assertEq(nodeIds.length, initialNodeIds.length);
        for (uint256 i = 0; i < initialNodeIds.length; i++) {
            assertEq(nodeIds[i].length, initialNodeIds[i].length);
            for (uint256 j = 0; j < initialNodeIds[i].length; j++) {
                assertEq(nodeIds[i][j], initialNodeIds[i][j]);
            }
        }
    }

    function testRevertGetRegisteredNodeIds() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getRegisteredNodeIds(1);
    }

    function testGetNumberOfRegisteredVoters() public {
        assertEq(voterRegistry.getNumberOfRegisteredVoters(0), initialVoters.length);
    }

    function testGetVoterWithNormalisedWeigth() public {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockEntityManager,
                abi.encodeWithSelector(IEntityManager.getVoterForSigningPolicyAddress.selector,
                    initialSigningPolicyAddresses[i], voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
                abi.encode(initialVoters[i])
            );
            (address voter, uint16 normWeight) =
                voterRegistry.getVoterWithNormalisedWeight(0, initialSigningPolicyAddresses[i]);
            assertEq(voter, initialVoters[i]);
            assertEq(normWeight, initialNormWeights[i]);
        }
        address notRegistered = makeAddr("notRegisteredVoter");
        address notRegisteredSignPolicyAddr = makeAddr("notRegisteredVoterSigningPolicyAddress");
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IEntityManager.getVoterForSigningPolicyAddress.selector,
                notRegisteredSignPolicyAddr, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(notRegistered)
        );
        vm.expectRevert("voter not registered");
        voterRegistry.getVoterWithNormalisedWeight(0, notRegisteredSignPolicyAddr);
    }

    function testRevertGetVoterWithNormalisedWeigth() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getVoterWithNormalisedWeight(1, initialSigningPolicyAddresses[0]);
    }

    function testIsVoterRegistered() public {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            assertEq(voterRegistry.isVoterRegistered(initialVoters[i], 0), true);
        }
        assertEq(voterRegistry.isVoterRegistered(makeAddr("addressNotRegistered"), 0), false);
    }

    //// register voter tests
    function testRegisterVoterEvenIfVoterChilled() public {
        _mockGetCurrentEpochId(0);

        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        IVoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 1);

        // chill voter
        vm.prank(governance);
        bytes20[] memory voters = new bytes20[](1);
        voters[0] = bytes20(initialVoters[0]);
        voterRegistry.chill(voters, 2);

        vm.expectEmit();
        emit VoterRegistered(
            initialVoters[0],
            uint24(1),
            initialSigningPolicyAddresses[0],
            initialSubmitAddresses[0],
            initialSubmitSignaturesAddresses[0],
            initialPublicKeyParts1[0],
            initialPublicKeyParts2[0],
            initialVotersWeights[0]
        );
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertInvalidSignature() public {
        _mockGetCurrentEpochId(0);
        // wrong epoch id -> signature is invalid
        IVoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 4);

        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        // try to register
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        vm.expectRevert("invalid signature");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertVpBlockZero() public {
        _mockGetCurrentEpochId(0);
        IVoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 1);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(0, true);
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.expectRevert("vote power block zero");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertRegistrationEnded() public {
        _mockGetCurrentEpochId(0);
        IVoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 1);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(1, false);
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.expectRevert("voter registration not enabled");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    // register 3 voters (max voters == 3)
    function testRegisterVoters() public {
        IVoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(governance);
        voterRegistry.setMaxVoters(3);
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        for (uint256 i = 0; i < initialVoters.length - 1; i++) {
            signature = _createSigningPolicyAddressSignature(i, 1);
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(1),
                initialSigningPolicyAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialPublicKeyParts1[i],
                initialPublicKeyParts2[i],
                initialVotersWeights[i]
            );
            voterRegistry.registerVoter(initialVoters[i], signature);
        }
    }

    function testRegisterVotersPublicKeyRequired() public {
        IVoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(governance);
        voterRegistry.setMaxVoters(2);
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        // voter must have the public key set when registering
        assertEq(voterRegistry.publicKeyRequired(), false);
        vm.prank(governance);
        voterRegistry.setPublicKeyRequired(true);
        assertEq(voterRegistry.publicKeyRequired(), true);

        // voter 1 has non-zero public key
        signature = _createSigningPolicyAddressSignature(0, 1);
        vm.expectEmit();
        emit VoterRegistered(
            initialVoters[0],
            uint24(1),
            initialSigningPolicyAddresses[0],
            initialSubmitAddresses[0],
            initialSubmitSignaturesAddresses[0],
            initialPublicKeyParts1[0],
            initialPublicKeyParts2[0],
            initialVotersWeights[0]
        );
        voterRegistry.registerVoter(initialVoters[0], signature);

        // voter 2 has zero public key
        signature = _createSigningPolicyAddressSignature(1, 1);
        vm.expectRevert("public key required");
        voterRegistry.registerVoter(initialVoters[1], signature);

        // voter 3 has zero part 1 of public key but non-zero part 2
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IEntityManager.getPublicKeyOfAt.selector, initialVoters[2]),
            abi.encode(bytes32("123"), bytes32(0))
        );
        signature = _createSigningPolicyAddressSignature(2, 1);
        vm.expectEmit();
        emit VoterRegistered(
            initialVoters[2],
            uint24(1),
            initialSigningPolicyAddresses[2],
            initialSubmitAddresses[2],
            initialSubmitSignaturesAddresses[2],
            bytes32("123"),
            bytes32(0),
            initialVotersWeights[2]
        );
        voterRegistry.registerVoter(initialVoters[2], signature);
    }

    function testRegisterVotersAndCreateSigningPolicySnapshot() public {
        IVoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        uint256 weightsSum = 0;
        for (uint256 i = 0; i < initialVoters.length ; i++) {
            signature = _createSigningPolicyAddressSignature(i, 1);
            voterRegistry.registerVoter(initialVoters[i], signature);
            weightsSum += initialVotersWeights[i];
        }

        // create signing policy snapshot
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getSigningPolicyAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(initialSigningPolicyAddresses)
        );
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getPublicKeys.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(initialPublicKeyParts1, initialPublicKeyParts2)
        );
        vm.prank(mockFlareSystemsManager);
        (address[] memory signPolAddresses, uint16[] memory normWeights, uint16 normWeightsSum) =
            voterRegistry.createSigningPolicySnapshot(1);

        assertEq(initialSigningPolicyAddresses.length, signPolAddresses.length);
        uint16 sum = 0;
        uint256 voterWeight;
        uint16 normVoterWeight;
        for (uint256 i = 0; i < initialVoters.length; i++) {
            assertEq(signPolAddresses[i], initialSigningPolicyAddresses[i]);
            voterWeight = initialVotersWeights[i];
            normVoterWeight = uint16(voterWeight * UINT16_MAX / weightsSum);
            assertEq(normWeights[i], normVoterWeight);
            sum += normVoterWeight;
        }
        assertEq(sum, normWeightsSum);

        (uint128 _sum, uint16 _normSum, uint16 _normSumPub) = voterRegistry.getWeightsSums(1);
        assertEq(_sum, weightsSum);
        assertEq(_normSum, normWeightsSum);
        // only voter0 registered public key
        assertEq(_normSumPub, uint16(initialVotersWeights[0] * UINT16_MAX / weightsSum));
    }

    function testGetWeightsSum() public {
        VoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        uint256 weightsSum = 0;
        for (uint256 i = 0; i < initialVoters.length ; i++) {
            signature = _createSigningPolicyAddressSignature(i, 1);
            voterRegistry.registerVoter(initialVoters[i], signature);
            weightsSum += initialVotersWeights[i];
        }

        // create signing policy snapshot
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getSigningPolicyAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(initialSigningPolicyAddresses)
        );
        initialPublicKeyParts1[0] = bytes32(0);
        initialPublicKeyParts2[0] = bytes32(0);
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IIEntityManager.getPublicKeys.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(initialPublicKeyParts1, initialPublicKeyParts2)
        );
        vm.prank(mockFlareSystemsManager);
        (, , uint16 normWeightsSum) =
            voterRegistry.createSigningPolicySnapshot(1);

        (uint128 _sum, uint16 _normSum, uint16 _normSumPub) = voterRegistry.getWeightsSums(1);
        assertEq(_sum, weightsSum);
        assertEq(_normSum, normWeightsSum);
        // no one registered public key
        assertEq(_normSumPub, 0);

        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getWeightsSums(2);
    }

    function testRemoveVoter() public {
        // add 3 voters
        testRegisterVoters();

        // add new voter and remove one with lowest weight (initialVoters[0])
        IVoterRegistry.Signature memory signature = _createSigningPolicyAddressSignature(3, 1);

        vm.expectEmit();
        emit VoterRemoved(initialVoters[0], 1);
        vm.expectEmit();
        emit VoterRegistered(
            initialVoters[3],
            uint24(1),
            initialSigningPolicyAddresses[3],
            initialSubmitAddresses[3],
            initialSubmitSignaturesAddresses[3],
            initialPublicKeyParts1[3],
            initialPublicKeyParts2[3],
            initialVotersWeights[3]
        );
        voterRegistry.registerVoter(initialVoters[3], signature);
    }

    // max voters = 1
    // register voter[1], try to register voter[0] -> not possible because voter[1] has higher vote power
    function testRegisterVoterRevertWeightTooLow() public {
        IVoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(governance);
        voterRegistry.setMaxVoters(1);
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        signature = _createSigningPolicyAddressSignature(1, 1);
        voterRegistry.registerVoter(initialVoters[1], signature);

        signature = _createSigningPolicyAddressSignature(0, 1);
        vm.expectRevert("vote power too low");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    // try to register voter twice
    function testRegisterVoterTwice() public {
        IVoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        // register
        signature = _createSigningPolicyAddressSignature(1, 1);
        vm.expectEmit();
        emit VoterRegistered(
            initialVoters[1],
            uint24(1),
            initialSigningPolicyAddresses[1],
            initialSubmitAddresses[1],
            initialSubmitSignaturesAddresses[1],
            initialPublicKeyParts1[1],
            initialPublicKeyParts2[1],
            initialVotersWeights[1]
        );
        voterRegistry.registerVoter(initialVoters[1], signature);

        // try to register again
        vm.recordLogs();
        vm.expectRevert("already registered");
        voterRegistry.registerVoter(initialVoters[1], signature);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // there were no logs emitted -> voter was not registered again
        assertEq(entries.length, 0);
    }

    function testRegisterVoterRevertWeightZero() public {
        IVoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.mockCall(
            mockFlareSystemsCalculator,
            abi.encodeWithSelector(IIFlareSystemsCalculator.calculateRegistrationWeight.selector,
                initialVoters[0], 1, 10),
            abi.encode(0)
        );

        signature = _createSigningPolicyAddressSignature(0, 1);
        vm.expectRevert("voter weight zero");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertRegistrationNotAvailable() public {
        IVoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemsManager);

        signature = _createSigningPolicyAddressSignature(0, 1);
        vm.expectRevert("registration not available yet");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testGetPublicKeyAndNormalisedWeight() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getPublicKeyAndNormalisedWeight(1, initialSigningPolicyAddresses[0]);

        // register voters
        testRegisterVotersAndCreateSigningPolicySnapshot();

        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockEntityManager,
                abi.encodeWithSelector(IEntityManager.getVoterForSigningPolicyAddress.selector,
                    initialSigningPolicyAddresses[i], voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
                abi.encode(initialVoters[i])
            );
        }
        address notRegistered = makeAddr("notRegisteredVoter");
        address notRegisteredSignPolicyAddr = makeAddr("notRegisteredVoterSigningPolicyAddress");
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IEntityManager.getVoterForSigningPolicyAddress.selector,
                notRegisteredSignPolicyAddr, voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(notRegistered)
        );

        vm.expectRevert("voter not registered");
        voterRegistry.getPublicKeyAndNormalisedWeight(1, notRegisteredSignPolicyAddr);

        bytes32 publicKey1 = initialPublicKeyParts1[0];
        bytes32 publicKey2 = initialPublicKeyParts2[0];
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(IEntityManager.getPublicKeyOfAt.selector,
                initialVoters[0], voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(publicKey1, publicKey2)
        );

        uint256 sum = initialVotersWeights[0] +
            initialVotersWeights[1] + initialVotersWeights[2] + initialVotersWeights[3];
        (bytes32 key1, bytes32 key2, uint16 normWeight, uint16 normWeightSum) =
            voterRegistry.getPublicKeyAndNormalisedWeight(1, initialSigningPolicyAddresses[0]);
        assertEq(key1, publicKey1);
        assertEq(key2, publicKey2);
        assertEq(normWeight, uint16(initialVotersWeights[0] * UINT16_MAX / sum));
        assertEq(normWeightSum, uint16(initialVotersWeights[0] * UINT16_MAX / sum));
    }

    function testSystemRegistration() public {
        vm.prank(governance);
        assertEq(voterRegistry.systemRegistrationContractAddress(), address(0));

        address mockSystemRegistrationContractAddress = makeAddr("systemRegistration");
        vm.prank(governance);
        voterRegistry.setSystemRegistrationContractAddress(mockSystemRegistrationContractAddress);
        assertEq(voterRegistry.systemRegistrationContractAddress(), mockSystemRegistrationContractAddress);

        // register voters
        _mockGetCurrentEpochId(0);
        _mockGetVoterAddressesAt();
        _mockGetPublicKeyOfAt();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemsManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.startPrank(mockSystemRegistrationContractAddress);
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(1),
                initialSigningPolicyAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialPublicKeyParts1[i],
                initialPublicKeyParts2[i],
                initialVotersWeights[i]
            );
            voterRegistry.systemRegistration(initialVoters[i]);
        }
        vm.stopPrank();
    }

    function testGetVoterRegistrationWeight() public {
        testRegisterVotersPublicKeyRequired();

        assertEq(voterRegistry.getVoterRegistrationWeight(initialVoters[0], 1), initialVotersWeights[0]);
        assertEq(voterRegistry.getVoterRegistrationWeight(initialVoters[2], 1), initialVotersWeights[2]);

        vm.expectRevert("voter not registered");
        voterRegistry.getVoterRegistrationWeight(initialVoters[1], 1);
    }

    function testGetVoterNormalisedWeight() public {
        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getVoterNormalisedWeight(initialVoters[0], 1);

        // register voters
        testRegisterVotersAndCreateSigningPolicySnapshot();

        uint256 sum = initialVotersWeights[0] +
            initialVotersWeights[1] + initialVotersWeights[2] + initialVotersWeights[3];
        uint16 normWeight = voterRegistry.getVoterNormalisedWeight(initialVoters[0], 1);
        assertEq(normWeight, uint16(initialVotersWeights[0] * UINT16_MAX / sum));

        vm.expectRevert("voter not registered");
        voterRegistry.getVoterNormalisedWeight(makeAddr("test_voter"), 1);
    }

    ///// helper functions
    function _createInitialVoters(uint256 _num) internal {
        for (uint256 i = 0; i < _num; i++) {
            initialVoters.push(makeAddr(string.concat("initialVoter", vm.toString(i))));
            initialNormWeights.push(uint16(UINT16_MAX / _num));

            initialDelegationAddresses.push(makeAddr(
                string.concat("delegationAddress", vm.toString(i))));
            initialSubmitAddresses.push(makeAddr(
                string.concat("submitAddress", vm.toString(i))));
            initialSubmitSignaturesAddresses.push(makeAddr(
                string.concat("submitSignaturesAddress", vm.toString(i))));

            (address addr, uint256 pk) = makeAddrAndKey(
                string.concat("signingPolicyAddress", vm.toString(i)));
            initialSigningPolicyAddresses.push(addr);
            initialVotersSigningPolicyPk.push(pk);

            // registered addresses
            initialVotersRegisteredAddresses.push(IEntityManager.VoterAddresses(
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialSigningPolicyAddresses[i]
            ));

            // weights
            initialVotersWeights.push(100 * (i + 1));

            // public keys
            if (i == 0) {
                initialPublicKeyParts1.push(keccak256(abi.encode("publicKey1")));
                initialPublicKeyParts2.push(keccak256(abi.encode("publicKey2")));
            } else {
                initialPublicKeyParts1.push(bytes32(0));
                initialPublicKeyParts2.push(bytes32(0));
            }

            initialNodeIds.push(new bytes20[](i));
            for (uint256 j = 0; j < i; j++) {
                initialNodeIds[i][j] = bytes20(bytes(string.concat("nodeId", vm.toString(i), vm.toString(j))));
            }
        }
    }

    function _mockGetVoterAddressesAt() internal {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockEntityManager,
                abi.encodeWithSelector(IEntityManager.getVoterAddressesAt.selector, initialVoters[i]),
                abi.encode(initialVotersRegisteredAddresses[i])
            );
        }
    }

    function _mockGetPublicKeyOfAt() internal {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockEntityManager,
                abi.encodeWithSelector(IEntityManager.getPublicKeyOfAt.selector, initialVoters[i]),
                abi.encode(initialPublicKeyParts1[i], initialPublicKeyParts2[i])
            );
        }
    }

    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _createSigningPolicyAddressSignature(
        uint256 _voterIndex,
        uint256 _nextRewardEpochId
    )
        internal
        returns (
            IVoterRegistry.Signature memory _signature
        )
    {
        bytes32 messageHash = keccak256(abi.encode(_nextRewardEpochId, initialVoters[_voterIndex]));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(initialVotersSigningPolicyPk[_voterIndex], signedMessageHash);
        _signature = IVoterRegistry.Signature(v, r, s);
    }

    function _mockGetVoterRegistrationData(uint256 _vpBlock, bool _enabled) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getVoterRegistrationData.selector),
            abi.encode(_vpBlock, _enabled)
        );
    }

    // mock calculate weight
    function _mockVoterWeights() internal {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockFlareSystemsCalculator,
                abi.encodeWithSelector(
                    IIFlareSystemsCalculator.calculateRegistrationWeight.selector,initialVoters[i]),
                abi.encode(initialVotersWeights[i])
            );
        }
    }

    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }


}