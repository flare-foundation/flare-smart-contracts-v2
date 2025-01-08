// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/protocol/implementation/VoterPreRegistry.sol";
import "../../../../contracts/protocol/implementation/VoterRegistry.sol";

// solhint-disable-next-line max-states-count
contract VoterPreRegistryTest is Test {

    VoterPreRegistry private voterPreRegistry;
    VoterRegistry private voterRegistry;
    address private mockFlareSystemsManager;
    address private mockEntityManager;
    address private mockFlareSystemsCalculator;

    address private governance;
    address private addressUpdater;
    address[] private initialVoters;
    uint256[] private initialVotersSigningPolicyPk; // private keys
    uint256[] private initialWeights;
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

    uint256 private constant UINT16_MAX = type(uint16).max;

    event VoterPreRegistered(address indexed voter, uint256 indexed rewardEpochId);
    event VoterRegistrationFailed(address indexed voter, uint256 indexed rewardEpochId);
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
    event VoterRemoved(address indexed voter, uint256 indexed rewardEpochId);

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        _createInitialVoters(4);

        voterRegistry = new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            4,
            10,
            0,
            0,
            initialVoters,
            initialVotersWeights
        );

        voterPreRegistry = new VoterPreRegistry(addressUpdater);

        //// update contract addresses
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockEntityManager = makeAddr("entityManager");
        mockFlareSystemsCalculator = makeAddr("flareSystemsCalculator");
        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        // VoterRegistry
        contractNameHashes[0] = _keccak256AbiEncode("AddressUpdater");
        contractNameHashes[1] = _keccak256AbiEncode("FlareSystemsManager");
        contractNameHashes[2] = _keccak256AbiEncode("EntityManager");
        contractNameHashes[3] = _keccak256AbiEncode("FlareSystemsCalculator");
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = mockEntityManager;
        contractAddresses[3] = mockFlareSystemsCalculator;
        voterRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        // VoterPreRegistry
        contractNameHashes[3] = _keccak256AbiEncode("VoterRegistry");
        contractAddresses[3] = address(voterRegistry);
        voterPreRegistry.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();
    }

    function testPreRegisterVoterRevertNotOpened() public {
        _mockGetCurrentEpochId(10);
        _mockGetRandomAcquisitionInfo(11, 200);

        IVoterRegistry.Signature memory signature = _createSigningPolicyAddressSignature(0, 11);
        vm.expectRevert("pre-registration not opened anymore");
        voterPreRegistry.preRegisterVoter(initialVoters[0], signature);
    }

    function testPreRegisterVoterRevertInvalidSignature() public {
        _mockGetCurrentEpochId(10);
        vm.prank(mockFlareSystemsManager);
        vm.roll(90);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(10);
        _mockGetRandomAcquisitionInfo(11, 0);
        _mockGetVoterForSigningPolicyAddress(initialSigningPolicyAddresses[0], 90, initialVoters[0]);

        // create signature
        bytes32 messageHash = keccak256(abi.encode(11, initialVoters[1]));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(initialVotersSigningPolicyPk[0], signedMessageHash);
        IVoterRegistry.Signature memory signature = IVoterRegistry.Signature(v, r, s);

        vm.expectRevert("invalid signature");
        voterPreRegistry.preRegisterVoter(initialVoters[1], signature);
    }

    function testPreRegisterVoterRevertNotRegistered() public {
        _mockGetCurrentEpochId(10);
        vm.prank(mockFlareSystemsManager);
        vm.roll(90);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(10);
        _mockGetRandomAcquisitionInfo(11, 0);
        (address newVoterSigningPolicyAddr, uint256 pk) = makeAddrAndKey(
        "newVoterSigningPolicyAddr");
        address newVoter = makeAddr("newVoter");

        _mockGetVoterForSigningPolicyAddress(newVoterSigningPolicyAddr, 90, newVoter);
        // create signature
        bytes32 messageHash = keccak256(abi.encode(11, newVoter));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, signedMessageHash);
        IVoterRegistry.Signature memory signature = IVoterRegistry.Signature(v, r, s);
        vm.expectRevert("voter currently not registered");
        voterPreRegistry.preRegisterVoter(newVoter, signature);
    }

    function testPreRegisterVoter() public {
        _mockGetCurrentEpochId(10);
        _mockGetRandomAcquisitionInfo(11, 0);
        vm.prank(mockFlareSystemsManager);
        vm.roll(90);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(10);
        _mockGetVoterForSigningPolicyAddress(initialSigningPolicyAddresses[0], 90, initialVoters[0]);
        IVoterRegistry.Signature memory signature = _createSigningPolicyAddressSignature(0, 11);

        vm.expectEmit();
        emit VoterPreRegistered(initialVoters[0], 11);
        voterPreRegistry.preRegisterVoter(initialVoters[0], signature);
    }

    function testPreRegisterVoterRevertAlreadyRegistered() public {
        testPreRegisterVoter();
        IVoterRegistry.Signature memory signature = _createSigningPolicyAddressSignature(0, 11);
        vm.expectRevert("voter already pre-registered");
        voterPreRegistry.preRegisterVoter(initialVoters[0], signature);
    }

    function testPreRegisterVoters() public {
        // pre-register all four currently registered voters
        _mockGetCurrentEpochId(10);
        _mockGetRandomAcquisitionInfo(11, 0);
        vm.prank(mockFlareSystemsManager);
        vm.roll(90);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(10);
        for (uint256 i = 0; i < initialVoters.length; i++) {
            _mockGetVoterForSigningPolicyAddress(initialSigningPolicyAddresses[i], 90, initialVoters[i]);
            IVoterRegistry.Signature memory signature = _createSigningPolicyAddressSignature(i, 11);
            emit VoterPreRegistered(initialVoters[i], 11);
            voterPreRegistry.preRegisterVoter(initialVoters[i], signature);
        }
    }

    function testTriggerVoterRegistrationRevertOnlyFSM() public {
        vm.expectRevert("only flare systems manager");
        voterPreRegistry.triggerVoterRegistration(11);
    }

    function testTriggerVoterRegistration() public {
        testPreRegisterVoters();
        _mockGetVoterAddressesAt();
        vm.prank(governance);
        voterRegistry.setSystemRegistrationContractAddress(address(voterPreRegistry));
        vm.prank(mockFlareSystemsManager);
        vm.roll(190);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(11);
        _mockGetVoterRegistrationData(210, true);
        _mockGetDelegationAddressOfAt();
        _mockVoterWeights();
        _mockGetPublicKeyOfAt();
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(11),
                initialSigningPolicyAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialPublicKeyParts1[i],
                initialPublicKeyParts2[i],
                initialVotersWeights[i]
            );
        }
        vm.prank(mockFlareSystemsManager);
        voterPreRegistry.triggerVoterRegistration(11);
        assertEq(voterRegistry.getNumberOfRegisteredVoters(11), 4);
    }

    function testTriggerVoterRegistration1() public {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.signingPolicyMinNumberOfVoters.selector),
            abi.encode(3)
        );
        vm.prank(governance);
        voterRegistry.setMaxVoters(3);
        testPreRegisterVoters();
        _mockGetVoterAddressesAt();
        vm.prank(governance);
        voterRegistry.setSystemRegistrationContractAddress(address(voterPreRegistry));
        vm.prank(mockFlareSystemsManager);
        vm.roll(190);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(11);
        _mockGetVoterRegistrationData(210, true);
        _mockGetDelegationAddressOfAt();
        _mockVoterWeights();
        _mockGetPublicKeyOfAt();
        for (uint256 i = 0; i < initialVoters.length; i++) {
            if (i == 3) {
                vm.expectEmit();
                emit VoterRemoved(initialVoters[0], 11);
            }
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(11),
                initialSigningPolicyAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialPublicKeyParts1[i],
                initialPublicKeyParts2[i],
                initialVotersWeights[i]
            );
        }
        vm.prank(mockFlareSystemsManager);
        voterPreRegistry.triggerVoterRegistration(11);
        assertEq(voterRegistry.getNumberOfRegisteredVoters(11), 3);
    }

    function testTriggerVoterRegistration2() public {
        // pre-register all four currently registered voters
        _mockGetCurrentEpochId(10);
        _mockGetRandomAcquisitionInfo(11, 0);
        vm.prank(mockFlareSystemsManager);
        vm.roll(90);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(10);
        // order of pre-registration is different
        uint256 i = 4;
        while (i > 0) {
            i--;
            _mockGetVoterForSigningPolicyAddress(initialSigningPolicyAddresses[i], 90, initialVoters[i]);
            IVoterRegistry.Signature memory signature = _createSigningPolicyAddressSignature(i, 11);
            emit VoterPreRegistered(initialVoters[i], 11);
            voterPreRegistry.preRegisterVoter(initialVoters[i], signature);
        }

        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.signingPolicyMinNumberOfVoters.selector),
            abi.encode(3)
        );
        vm.prank(governance);
        voterRegistry.setMaxVoters(3);
        _mockGetVoterAddressesAt();
        vm.prank(governance);
        voterRegistry.setSystemRegistrationContractAddress(address(voterPreRegistry));
        vm.prank(mockFlareSystemsManager);
        vm.roll(190);
        voterRegistry.setNewSigningPolicyInitializationStartBlockNumber(11);
        _mockGetVoterRegistrationData(210, true);
        _mockGetDelegationAddressOfAt();
        _mockVoterWeights();
        _mockGetPublicKeyOfAt();

        i = 3;
        while (i > 0) {
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(11),
                initialSigningPolicyAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialPublicKeyParts1[i],
                initialPublicKeyParts2[i],
                initialVotersWeights[i]
            );
            i--;
        }
        // registration for last voter should fail because max voters is 3 and the last has lowest weight
        vm.expectEmit();
        emit VoterRegistrationFailed(initialVoters[0], 11);
        vm.prank(mockFlareSystemsManager);
        voterPreRegistry.triggerVoterRegistration(11);
        assertEq(voterRegistry.getNumberOfRegisteredVoters(11), 3);
    }

    function testGetPreRegisteredVoters() public {
        testPreRegisterVoters();
        address[] memory preRegisteredVoters = voterPreRegistry.getPreRegisteredVoters(11);
        assertEq(preRegisteredVoters.length, 4);
        for (uint256 i = 0; i < preRegisteredVoters.length; i++) {
            assertEq(preRegisteredVoters[i], initialVoters[i]);
        }

        preRegisteredVoters = voterPreRegistry.getPreRegisteredVoters(10);
        assertEq(preRegisteredVoters.length, 0);
        preRegisteredVoters = voterPreRegistry.getPreRegisteredVoters(12);
        assertEq(preRegisteredVoters.length, 0);
    }

    function testGetPreRegisteredVoters1() public {
        testTriggerVoterRegistration2();
        uint256 i = 4;
        while (i > 0) {
            i--;
            assert(voterPreRegistry.isVoterPreRegistered(11, initialVoters[i]));
        }
    }

    function testIsVoterPreRegistered() public {
        testPreRegisterVoters();
        for (uint256 i = 0; i < initialVoters.length; i++) {
            assert(voterPreRegistry.isVoterPreRegistered(11, initialVoters[i]));
        }
        address newVoter = makeAddr("newVoter");
        assert(!voterPreRegistry.isVoterPreRegistered(11, newVoter));
        assert(!voterPreRegistry.isVoterPreRegistered(10, initialVoters[0]));
        assert(!voterPreRegistry.isVoterPreRegistered(12, initialVoters[0]));
    }

    function testConstructorCoverage() public {
        voterPreRegistry = new VoterPreRegistry(addressUpdater);
    }

    ///// helper functions
    function _mockGetRandomAcquisitionInfo(uint256 _rewardEpoch, uint256 _randomAcquisitionEndBlock) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.getRandomAcquisitionInfo.selector, _rewardEpoch),
            abi.encode(50, 100, 150, _randomAcquisitionEndBlock)
        );
    }

    function _mockGetVoterForSigningPolicyAddress(
        address _signingPolicyAddress,
        uint256 _initBlock,
        address _voter
    )
        internal
    {
        vm.mockCall(
            mockEntityManager,
            abi.encodeWithSelector(
                IEntityManager.getVoterForSigningPolicyAddress.selector, _signingPolicyAddress, _initBlock),
            abi.encode(_voter)
        );
    }

    function _createInitialVoters(uint256 _num) internal {
        for (uint256 i = 0; i < _num; i++) {
            initialVoters.push(makeAddr(string.concat("initialVoter", vm.toString(i))));
            initialWeights.push(uint16(UINT16_MAX / _num));

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

    function _mockGetDelegationAddressOfAt() internal {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            vm.mockCall(
                mockEntityManager,
                abi.encodeWithSelector(IEntityManager.getDelegationAddressOfAt.selector, initialVoters[i]),
                abi.encode(initialDelegationAddresses[i])
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
            abi.encodeWithSelector(ProtocolsV2Interface.getCurrentRewardEpochId.selector),
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

    function _mockSigningPolicyMinNumberOfVoters(uint256 _signingPolicyMinNumberOfVoters) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IIFlareSystemsManager.signingPolicyMinNumberOfVoters.selector),
            abi.encode(_signingPolicyMinNumberOfVoters)
        );
    }

    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }

}