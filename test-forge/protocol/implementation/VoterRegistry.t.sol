// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/protocol/implementation/VoterRegistry.sol";
import "../../../contracts/protocol/implementation/FlareSystemManager.sol";
import "../../../contracts/protocol/implementation/EntityManager.sol";
import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirror.sol";
import "../../../contracts/protocol/interface/IWNat.sol";
import "../../../contracts/protocol/interface/ICChainStake.sol";

contract VoterRegistryTest is Test {

    VoterRegistry private voterRegistry;
    address private mockFlareSystemManager;
    address private mockEntityManager;
    address private mockFlareSystemCalculator;

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
    EntityManager.VoterAddresses[] private initialVotersRegisteredAddresses;
    uint256[] private initialVotersWeights;
    uint256 private pChainTotalVP;
    uint256 private cChainTotalVP;
    uint256 private wNatTotalVP;

    uint16 private constant UINT16_MAX = type(uint16).max;

    event VoterChilled(address voter, uint256 untilRewardEpochId);
    event VoterRemoved(address voter, uint256 rewardEpochId);
    event VoterRegistered(
        address voter,
        uint24 rewardEpochId,
        address signingPolicyAddress,
        address delegationAddress,
        address submitAddress,
        address submitSignaturesAddress,
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
        mockFlareSystemManager = makeAddr("flareSystemManager");
        mockEntityManager = makeAddr("entityManager");
        mockFlareSystemCalculator = makeAddr("flareSystemCalculator");
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = _keccak256AbiEncode("AddressUpdater");
        contractNameHashes[1] = _keccak256AbiEncode("FlareSystemManager");
        contractNameHashes[2] = _keccak256AbiEncode("EntityManager");
        contractNameHashes[3] = _keccak256AbiEncode("FlareSystemCalculator");
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemManager;
        contractAddresses[2] = mockEntityManager;
        contractAddresses[3] = mockFlareSystemCalculator;
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

        assertEq(voterRegistry.maxVoters(), 4);
        voterRegistry.setMaxVoters(100);
        assertEq(voterRegistry.maxVoters(), 100);
        vm.stopPrank();
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

    function testRevertCreateSigningPolicySnapshot() public {
        vm.prank(mockFlareSystemManager);
        vm.expectRevert();
        voterRegistry.createSigningPolicySnapshot(1);
    }


    function testCreateSigningPolicySnapshot() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(EntityManager.getSigningPolicyAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSigningPolicyAddresses)
        );
        vm.prank(mockFlareSystemManager);
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
            abi.encodeWithSelector(EntityManager.getSubmitAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSubmitAddresses)
        );
        address[] memory submitAddresses = voterRegistry.getRegisteredSubmitAddresses(0);
        assertEq(submitAddresses.length, initialSubmitAddresses.length);
        for (uint256 i = 0; i < initialSubmitAddresses.length; i++) {
            assertEq(submitAddresses[i], initialSubmitAddresses[i]);
        }
    }

    function testGetRegisteredSubmitSignaturesAddresses() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(EntityManager.getSubmitSignaturesAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSubmitSignaturesAddresses)
        );
        address[] memory submitSignaturesAddresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(0);
        assertEq(submitSignaturesAddresses.length, initialSubmitSignaturesAddresses.length);
        for (uint256 i = 0; i < initialSubmitSignaturesAddresses.length; i++) {
            assertEq(submitSignaturesAddresses[i], initialSubmitSignaturesAddresses[i]);
        }
    }

    function testGetRegisteredDelegationAddresses() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(EntityManager.getDelegationAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialDelegationAddresses)
        );
        address[] memory delegationAddresses = voterRegistry.getRegisteredDelegationAddresses(0);
        assertEq(delegationAddresses.length, initialDelegationAddresses.length);
        for (uint256 i = 0; i < initialDelegationAddresses.length; i++) {
            assertEq(delegationAddresses[i], initialDelegationAddresses[i]);
        }
    }

    function testGetRegisteredSigningPolicyAddresses() public {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(EntityManager.getSigningPolicyAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(0)),
            abi.encode(initialSigningPolicyAddresses)
        );
        address[] memory signingPolicyAddresses = voterRegistry.getRegisteredSigningPolicyAddresses(0);
        assertEq(signingPolicyAddresses.length, initialSigningPolicyAddresses.length);
        for (uint256 i = 0; i < initialSigningPolicyAddresses.length; i++) {
            assertEq(signingPolicyAddresses[i], initialSigningPolicyAddresses[i]);
        }
    }

    function testGetNumberOfRegisteredVoters() public {
        assertEq(voterRegistry.getNumberOfRegisteredVoters(0), initialVoters.length);
    }

    function testGetVoterWithNormalisedWeigth() public {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockEntityManager,
                abi.encodeWithSelector(EntityManager.getVoterForSigningPolicyAddress.selector,
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
            abi.encodeWithSelector(EntityManager.getVoterForSigningPolicyAddress.selector,
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
    function testRegisterVoterRevertVoterChilled() public {
        _mockGetCurrentEpochId(0);
        VoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 1);

        // chill voter
        vm.prank(governance);
        voterRegistry.chillVoter(initialVoters[0], 2);

        // try to register
        vm.expectRevert("voter chilled");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertInvalidSignature() public {
        _mockGetCurrentEpochId(0);
        // wrong epoch id -> signature is invalid
        VoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 4);

        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        // try to register
        _mockGetVoterAddresses();
        vm.expectRevert("invalid signature");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertVpBlockZero() public {
        _mockGetCurrentEpochId(0);
        VoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 1);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(0, true);
        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.expectRevert("vote power block zero");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertRegistrationEnded() public {
        _mockGetCurrentEpochId(0);
        VoterRegistry.Signature memory signature =
            _createSigningPolicyAddressSignature(0, 1);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(1, false);
        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.expectRevert("voter registration not enabled");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    // register 3 voters (max voters == 3)
    function testRegisterVoters() public {
        VoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(governance);
        voterRegistry.setMaxVoters(3);
        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        for (uint256 i = 0; i < initialVoters.length - 1; i++) {
            signature = _createSigningPolicyAddressSignature(i, 1);
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(1),
                initialSigningPolicyAddresses[i],
                initialDelegationAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialVotersWeights[i]
            );
            voterRegistry.registerVoter(initialVoters[i], signature);
        }
    }

    function testRegisterVotersAndCreateSigningPolicySnapshot() public {
        VoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemManager);
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
            abi.encodeWithSelector(EntityManager.getSigningPolicyAddresses.selector,
                initialVoters, voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(initialSigningPolicyAddresses)
        );
        vm.prank(mockFlareSystemManager);
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
    }

    function testRemoveVoter() public {
        // add 3 voters
        testRegisterVoters();

        // add new voter and remove one with lowest weight (initialVoters[0])
        VoterRegistry.Signature memory signature = _createSigningPolicyAddressSignature(3, 1);

        vm.expectEmit();
        emit VoterRemoved(initialVoters[0], 1);
        vm.expectEmit();
        emit VoterRegistered(
            initialVoters[3],
            uint24(1),
            initialSigningPolicyAddresses[3],
            initialDelegationAddresses[3],
            initialSubmitAddresses[3],
            initialSubmitSignaturesAddresses[3],
            initialVotersWeights[3]
        );
        voterRegistry.registerVoter(initialVoters[3], signature);
    }

    // max voters = 1
    // register voter[1], try to register voter[0] -> not possible because voter[1] has higher vote power
    function testRegisterVoterRevertWeightTooLow() public {
        VoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(governance);
        voterRegistry.setMaxVoters(1);
        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        signature = _createSigningPolicyAddressSignature(1, 1);
        voterRegistry.registerVoter(initialVoters[1], signature);

        signature = _createSigningPolicyAddressSignature(0, 1);
        vm.expectRevert("vote power too low");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    // try to register voter twice
    function testRegisterVoterTwice() public {
        VoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        // register
        signature = _createSigningPolicyAddressSignature(1, 1);
        vm.expectEmit();
        emit VoterRegistered(
            initialVoters[1],
            uint24(1),
            initialSigningPolicyAddresses[1],
            initialDelegationAddresses[1],
            initialSubmitAddresses[1],
            initialSubmitSignaturesAddresses[1],
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
        VoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.mockCall(
            mockFlareSystemCalculator,
            abi.encodeWithSelector(FlareSystemCalculator.calculateRegistrationWeight.selector,
                initialVoters[0], initialDelegationAddresses[0], 1, 10),
            abi.encode(0)
        );

        signature = _createSigningPolicyAddressSignature(0, 1);
        vm.expectRevert("voter weight zero");
        voterRegistry.registerVoter(initialVoters[0], signature);
    }

    function testRegisterVoterRevertRegistrationNotAvailable() public {
        VoterRegistry.Signature memory signature;

        _mockGetCurrentEpochId(0);
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemManager);

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
                abi.encodeWithSelector(EntityManager.getVoterForSigningPolicyAddress.selector,
                    initialSigningPolicyAddresses[i], voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
                abi.encode(initialVoters[i])
            );
        }
        address notRegistered = makeAddr("notRegisteredVoter");
        address notRegisteredSignPolicyAddr = makeAddr("notRegisteredVoterSigningPolicyAddress");
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(EntityManager.getVoterForSigningPolicyAddress.selector,
                notRegisteredSignPolicyAddr, voterRegistry.newSigningPolicyInitializationStartBlockNumber(1)),
            abi.encode(notRegistered)
        );

        vm.expectRevert("voter not registered");
        voterRegistry.getPublicKeyAndNormalisedWeight(1, notRegisteredSignPolicyAddr);

        bytes32 publicKey1 = keccak256(abi.encode("publicKey1"));
        bytes32 publicKey2 = keccak256(abi.encode("publicKey2"));
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(EntityManager.getPublicKeyOfAt.selector,
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
        _mockGetVoterAddresses();
        _mockGetVoterRegistrationData(10, true);
        _mockVoterWeights();
        vm.prank(mockFlareSystemManager);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(1);

        vm.startPrank(mockSystemRegistrationContractAddress);
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(1),
                initialSigningPolicyAddresses[i],
                initialDelegationAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialVotersWeights[i]
            );
            voterRegistry.systemRegistration(initialVoters[i]);
        }
        vm.stopPrank();
    }

    // TODO test with more than one node id for one of the voters


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
            initialVotersRegisteredAddresses.push(EntityManager.VoterAddresses(
                initialDelegationAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialSigningPolicyAddresses[i]
            ));

            // weights
            initialVotersWeights.push(100 * (i + 1));
        }
    }

    function _mockGetVoterAddresses() internal {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockEntityManager,
                abi.encodeWithSelector(EntityManager.getVoterAddresses.selector, initialVoters[i]),
                abi.encode(initialVotersRegisteredAddresses[i])
            );
        }
    }

    function _mockGetCurrentEpochId(uint256 _epochId) internal {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getCurrentRewardEpochId.selector),
            abi.encode(_epochId)
        );
    }

    function _createSigningPolicyAddressSignature(
        uint256 _voterIndex,
        uint256 _nextRewardEpochId
    )
        internal
        returns (
            VoterRegistry.Signature memory _signature
        )
    {
        bytes32 messageHash = keccak256(abi.encode(_nextRewardEpochId, initialVoters[_voterIndex]));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(initialVotersSigningPolicyPk[_voterIndex], signedMessageHash);
        _signature = VoterRegistry.Signature(v, r, s);
    }

    function _mockGetVoterRegistrationData(uint256 _vpBlock, bool _enabled) internal {
        vm.mockCall(
            mockFlareSystemManager,
            abi.encodeWithSelector(FlareSystemManager.getVoterRegistrationData.selector),
            abi.encode(_vpBlock, _enabled)
        );
    }

    // mock calculate weight
    function _mockVoterWeights() internal {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockFlareSystemCalculator,
                abi.encodeWithSelector(FlareSystemCalculator.calculateRegistrationWeight.selector,
                    initialVoters[i], initialDelegationAddresses[i]),
                abi.encode(initialVotersWeights[i])
            );
        }
    }

    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }


}