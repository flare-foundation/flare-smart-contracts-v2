// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../contracts/protocol/implementation/VoterRegistry.sol";
import "../../contracts/protocol/implementation/EntityManager.sol";
import "../../contracts/protocol/implementation/FlareSystemsCalculator.sol";
import "../../contracts/protocol/implementation/FlareSystemsManager.sol";
import "../mock/MockNodePossessionVerification.sol";
import "../mock/MockPublicKeyVerification.sol";
import "../../contracts/protocol/implementation/VoterPreRegistry.sol";

// solhint-disable-next-line max-states-count
contract VoterRegistryAndFlareSystemsManagerTest is Test {

    uint24 internal constant WNAT_CAP_PPM = 200000;
    uint16 private constant REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS = 3360; // 3.5 days
    uint8 private constant VOTING_EPOCH_DURATION_SEC = 90;
    uint64 private constant REWARD_EPOCH_DURATION_IN_SEC =
    uint64(REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS) * VOTING_EPOCH_DURATION_SEC;

    VoterRegistry private voterRegistry;
    address private mockFlareSystemsManager;
    EntityManager private entityManager;
    FlareSystemsCalculator private calculator;
    address private mockWNatDelegationFee;
    address private mockPChainStakeMirror;
    address private mockWNat;
    MockPublicKeyVerification private mockPublicKeyVerification;
    MockNodePossessionVerification private mockNodePossessionVerification;
    FlareSystemsManager private flareSystemsManager;
    VoterPreRegistry private voterPreRegistry;

    // for flare systems manager
    address private mockRelay;
    address private mockRewardManager;
    address private mockCleanupBlockNumberManager;
    address private mockSubmission;
    FlareSystemsManager.Settings private settings;
    FlareSystemsManager.InitialSettings private initialSettings;
    address private flareDaemon;

    address private governance;
    address private addressUpdater;
    address[] private initialVoters;
    uint256[] private initialVotersPK;
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
    uint256[] private initialVotersRegistrationWeight;
    IEntityManager.VoterAddresses[] private initialVotersRegisteredAddresses;
    uint256[] private initialVotersWNatVP;
    uint256[][] private initialVotersPChainVP;
    uint256 private pChainTotalVP;
    uint256 private cChainTotalVP;
    uint256 private wNatTotalVP;
    bytes private validPublicKeyData = abi.encode(1, 2, 3);
    bytes20[] private voter3RegisteredNodesAtVpBlock;
    uint256[] private voter3RegisteredPChainVPAtVpBlock;
    IVoterRegistry.Signature private signature;
    IFlareSystemsManager.Signature private signatureFSM;

    bytes32 private newSigningPolicyHash;
    bytes32 private signedMessageHash;
    uint8 private v;
    bytes32 private r;
    bytes32 private s;

    uint256 private constant UINT16_MAX = type(uint16).max;

    bytes private certificateRawTest;
    bytes private signatureTest;

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
    event VotePowerBlockSelected(
        uint24 indexed rewardEpochId,   // Reward epoch id
        uint64 votePowerBlock,          // Vote power block for given reward epoch
        uint64 timestamp                // Timestamp when this happened
    );
    event SigningPolicySigned(
        uint24 indexed rewardEpochId,           // Reward epoch id
        address indexed signingPolicyAddress,   // Address which signed this
        address indexed voter,                  // Voter (entity)
        uint64 timestamp,                       // Timestamp when this happened
        bool thresholdReached                   // Indicates if signing threshold was reached
    );
    event UptimeVoteSigned(
        uint24 indexed rewardEpochId,           // Reward epoch id
        address indexed signingPolicyAddress,   // Address which signed this
        address indexed voter,                  // Voter (entity)
        bytes32 uptimeVoteHash,                 // Uptime vote hash
        uint64 timestamp,                       // Timestamp when this happened
        bool thresholdReached                   // Indicates if signing threshold was reached
    );
    event VoterPreRegistered(address indexed voter, uint256 indexed rewardEpochId);

    function setUp() public {
        vm.warp(1000);
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");
        _createInitialVoters(4);

        voterRegistry = new VoterRegistry(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            4,
            0,
            0,
            0,
            initialVoters,
            initialWeights
        );

        // entity manager contract
        entityManager = new EntityManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            4
        );

        // calculator contract
        calculator = new FlareSystemsCalculator(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            WNAT_CAP_PPM,
            1200,
            600,
            600
        );

        // flare systems manager contract
        flareDaemon = makeAddr("flareDaemon");
        settings = FlareSystemsManager.Settings(
            3600 * 8,
            15000,
            3600 * 2,
            0,
            30 * 60,
            20,
            10,
            2,
            500000,
            2,
            1000
        );
        initialSettings = FlareSystemsManager.InitialSettings(
            100,
            0,
            10000
        );
        flareSystemsManager = new FlareSystemsManager(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            flareDaemon,
            settings,
            uint32(block.timestamp),
            VOTING_EPOCH_DURATION_SEC,
            0,
            REWARD_EPOCH_DURATION_IN_VOTING_EPOCHS,
            initialSettings
        );

        voterPreRegistry = new VoterPreRegistry(addressUpdater);

        //// update contract addresses
        mockFlareSystemsManager = makeAddr("flareSystemsManager");
        mockWNatDelegationFee = makeAddr("wNatDelegationFee");
        mockPChainStakeMirror = makeAddr("pChainStakeMirror");
        mockWNat = makeAddr("wNat");
        mockSubmission = makeAddr("submission");
        mockRelay = makeAddr("relay");
        mockRewardManager = makeAddr("rewardManager");
        mockCleanupBlockNumberManager = makeAddr("cleanupBlockNumberManager");

        vm.startPrank(addressUpdater);
        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("EntityManager"));
        contractNameHashes[3] = keccak256(abi.encode("FlareSystemsCalculator"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(flareSystemsManager);
        contractAddresses[2] = address(entityManager);
        contractAddresses[3] = address(calculator);
        voterRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](6);
        contractAddresses = new address[](6);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("Submission"));
        contractNameHashes[3] = keccak256(abi.encode("Relay"));
        contractNameHashes[4] = keccak256(abi.encode("RewardManager"));
        contractNameHashes[5] = keccak256(abi.encode("CleanupBlockNumberManager"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(voterRegistry);
        contractAddresses[2] = mockSubmission;
        contractAddresses[3] = mockRelay;
        contractAddresses[4] = mockRewardManager;
        contractAddresses[5] = mockCleanupBlockNumberManager;
        flareSystemsManager.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](4);
        contractAddresses = new address[](4);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("EntityManager"));
        contractNameHashes[3] = keccak256(abi.encode("VoterRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = address(flareSystemsManager);
        contractAddresses[2] = address(entityManager);
        contractAddresses[3] = address(voterRegistry);
        voterPreRegistry.updateContractAddresses(contractNameHashes, contractAddresses);

        contractNameHashes = new bytes32[](7);
        contractAddresses = new address[](7);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("FlareSystemsManager"));
        contractNameHashes[2] = keccak256(abi.encode("EntityManager"));
        contractNameHashes[3] = keccak256(abi.encode("WNatDelegationFee"));
        contractNameHashes[4] = keccak256(abi.encode("VoterRegistry"));
        contractNameHashes[5] = keccak256(abi.encode("PChainStakeMirror"));
        contractNameHashes[6] = keccak256(abi.encode("WNat"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockFlareSystemsManager;
        contractAddresses[2] = address(entityManager);
        contractAddresses[3] = mockWNatDelegationFee;
        contractAddresses[4] = address(voterRegistry);
        contractAddresses[5] = mockPChainStakeMirror;
        contractAddresses[6] = mockWNat;
        calculator.updateContractAddresses(contractNameHashes, contractAddresses);
        vm.stopPrank();

        mockPublicKeyVerification = new MockPublicKeyVerification();
        vm.startPrank(governance);
        entityManager.setPublicKeyVerifier(mockPublicKeyVerification);
        voterRegistry.setMaxVoters(3);

        mockNodePossessionVerification = new MockNodePossessionVerification();
        entityManager.setNodePossessionVerifier(mockNodePossessionVerification);
        certificateRawTest = mockNodePossessionVerification.CERTIFICATE_RAW_TEST();
        signatureTest = mockNodePossessionVerification.SIGNATURE_TEST();

        vm.mockCall(
            mockSubmission,
            abi.encodeWithSelector(IISubmission.initNewVotingRound.selector),
            abi.encode()
        );
        _mockCleanupBlockNumber(0);
    }

    function testRegisterVoters1() public {
        _registerAddressesAndNodes();

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(1, bytes32(0));
        vm.roll(128);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(103, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        uint256 epoch1VpBlock = flareSystemsManager.getVotePowerBlock(1);
        assertEq(epoch1VpBlock, 125);
        vm.stopPrank();

        _setVotePowers(epoch1VpBlock);

        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(100);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 20);
        initialVotersRegistrationWeight[2] = _calculateWeight(200 + 30 + 40);
        initialVotersRegistrationWeight[3] = _calculateWeight(200 + 40 + 50 + 60);

        vm.prank(governance);
        calculator.enablePChainStakeMirror();
        assertEq(calculator.pChainStakeMirrorEnabled(), true);
        vm.prank(addressUpdater);
        calculator.updateContractAddresses(contractNameHashes, contractAddresses);
        assertEq(address(calculator.pChainStakeMirror()), mockPChainStakeMirror);

        for (uint256 i = 0; i < initialVoters.length; i++) {
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
                initialVotersRegistrationWeight[i]
            );
            voterRegistry.registerVoter(initialVoters[i], signature);
        }

        address[] memory addresses = voterRegistry.getRegisteredVoters(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialVoters[3]); // voter3 kicked out voter0
        assertEq(addresses[1], initialVoters[1]);
        assertEq(addresses[2], initialVoters[2]);

        vm.expectRevert("reward epoch id not supported");
        voterRegistry.getRegisteredDelegationAddresses(1);

        // create signing policy snapshot
        _createSigningPolicySnapshot();

        addresses = voterRegistry.getRegisteredDelegationAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialDelegationAddresses[3]);
        assertEq(addresses[1], initialDelegationAddresses[1]);
        assertEq(addresses[2], initialDelegationAddresses[2]);

        addresses = voterRegistry.getRegisteredSubmitAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialSubmitAddresses[3]);
        assertEq(addresses[1], initialSubmitAddresses[1]);
        assertEq(addresses[2], initialSubmitAddresses[2]);

        addresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialSubmitSignaturesAddresses[3]);
        assertEq(addresses[1], initialSubmitSignaturesAddresses[1]);
        assertEq(addresses[2], initialSubmitSignaturesAddresses[2]);

        addresses = voterRegistry.getRegisteredSigningPolicyAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialSigningPolicyAddresses[3]);
        assertEq(addresses[1], initialSigningPolicyAddresses[1]);
        assertEq(addresses[2], initialSigningPolicyAddresses[2]);
    }

    // voter3 confirms its addresses after vp block
    function testRegisterVoters2() public {

        // voter2 registers addresses for its delegation address
        (address fakeSigningPolicyAddr, uint256 fakeSubmitSignatureAddressPK) =
            makeAddrAndKey("fakeSigningPolicyAddr");
        vm.startPrank(initialDelegationAddresses[2]);
        entityManager.proposeSubmitAddress(makeAddr("fakeSubmitAddress2"));
        entityManager.proposeSubmitSignaturesAddress(makeAddr("fakeSubmitSignaturesAddress2"));
        entityManager.proposeSigningPolicyAddress(fakeSigningPolicyAddr);
        vm.stopPrank();
        vm.prank(makeAddr("fakeSubmitAddress2"));
        entityManager.confirmSubmitAddressRegistration(initialDelegationAddresses[2]);
        vm.prank(makeAddr("fakeSubmitSignaturesAddress2"));
        entityManager.confirmSubmitSignaturesAddressRegistration(initialDelegationAddresses[2]);
        vm.prank(fakeSigningPolicyAddr);
        entityManager.confirmSigningPolicyAddressRegistration(initialDelegationAddresses[2]);

        _registerAddressesAndNodes();

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(1, bytes32(0));
        vm.roll(128);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(118, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        uint256 epoch1VpBlock = flareSystemsManager.getVotePowerBlock(1);
        assertEq(epoch1VpBlock, 110);
        vm.stopPrank();

        _setVotePowers(epoch1VpBlock);

        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")),
                initialVoters[3],
                epoch1VpBlock),
            abi.encode(0)
        );

        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(100);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 20);
        initialVotersRegistrationWeight[2] = _calculateWeight(200 + 30 + 40);
        initialVotersRegistrationWeight[3] = _calculateWeight(0 + 40 + 50 + 60);

        vm.prank(governance);
        calculator.enablePChainStakeMirror();
        assertEq(calculator.pChainStakeMirrorEnabled(), true);
        vm.prank(addressUpdater);
        calculator.updateContractAddresses(contractNameHashes, contractAddresses);
        assertEq(address(calculator.pChainStakeMirror()), mockPChainStakeMirror);

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
                initialVotersRegistrationWeight[i]
            );
            voterRegistry.registerVoter(initialVoters[i], signature);
        }

        // voter2 tries to register again, this time with its delegation address (initialDelegationAddresses[2])
        // for its delegation address it did not register delegation address
        // -> it defaults to initialDelegationAddresses[2] -> should revert
        bytes32 messageHash = keccak256(abi.encode(1, initialDelegationAddresses[2]));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(fakeSubmitSignatureAddressPK, signedMessageHash);
        signature = IVoterRegistry.Signature(v, r, s);
        vm.expectRevert("delegation address not set");
        voterRegistry.registerVoter(initialDelegationAddresses[2], signature);

        // voter 3 registered (confirmed) its delegation address after vp block for reward epoch 1
        // -> should not be able to register
        signature = _createSigningPolicyAddressSignature(3, 1);
        vm.expectRevert("delegation address not set");
        voterRegistry.registerVoter(initialVoters[3], signature);

        // create signing policy snapshot
        _createSigningPolicySnapshot();

        address[] memory addresses = voterRegistry.getRegisteredVoters(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialVoters[0]);
        assertEq(addresses[1], initialVoters[1]);
        assertEq(addresses[2], initialVoters[2]);

        // delegations address voter voter3 is registered too late
        addresses = voterRegistry.getRegisteredDelegationAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialDelegationAddresses[0]);
        assertEq(addresses[1], initialDelegationAddresses[1]);
        assertEq(addresses[2], initialDelegationAddresses[2]);

        addresses = voterRegistry.getRegisteredSubmitAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialSubmitAddresses[0]);
        assertEq(addresses[1], initialSubmitAddresses[1]);
        assertEq(addresses[2], initialSubmitAddresses[2]);

        addresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialSubmitSignaturesAddresses[0]);
        assertEq(addresses[1], initialSubmitSignaturesAddresses[1]);
        assertEq(addresses[2], initialSubmitSignaturesAddresses[2]);

        addresses = voterRegistry.getRegisteredSigningPolicyAddresses(1);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialSigningPolicyAddresses[0]);
        assertEq(addresses[1], initialSigningPolicyAddresses[1]);
        assertEq(addresses[2], initialSigningPolicyAddresses[2]);
    }

    // voter3 confirms its delegation address and registers its third node after vp block
    // newSigningPolicyInitializationStartBlockNumber is set before voter3 confirms its addresses
    function testRegisterVoters3() public {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            // register voters' addresses, public keys and node IDs
            vm.roll(block.number + 10);
            vm.startPrank(initialVoters[i]);
            entityManager.proposeDelegationAddress(initialDelegationAddresses[i]);
            entityManager.proposeSubmitAddress(initialSubmitAddresses[i]);
            entityManager.proposeSubmitSignaturesAddress(initialSubmitSignaturesAddresses[i]);
            entityManager.proposeSigningPolicyAddress(initialSigningPolicyAddresses[i]);
            if (i == 0) {
                entityManager.registerPublicKey(
                    initialPublicKeyParts1[i],
                    initialPublicKeyParts2[i],
                    validPublicKeyData
                );
            }

            // set pChain voter power
            for (uint256 j = 0; j < i; j++) {
                if (i == 3 && j == 2) {
                    vm.roll(block.number + 20);
                }
                mockNodePossessionVerification.setVoterAndNodeId(initialVoters[i], initialNodeIds[i][j]);
                entityManager.registerNodeId(
                    initialNodeIds[i][j],
                    certificateRawTest,
                    signatureTest
                );
            }
            vm.stopPrank();

            // confirm addresses
            if (i != 3) {
                vm.roll(block.number + 15);
                vm.prank(initialDelegationAddresses[i]);
                entityManager.confirmDelegationAddressRegistration(initialVoters[i]);
                vm.prank(initialSubmitAddresses[i]);
                entityManager.confirmSubmitAddressRegistration(initialVoters[i]);
                vm.prank(initialSubmitSignaturesAddresses[i]);
                entityManager.confirmSubmitSignaturesAddressRegistration(initialVoters[i]);
                vm.prank(initialSigningPolicyAddresses[i]);
                entityManager.confirmSigningPolicyAddressRegistration(initialVoters[i]);
            }
        }

        // select voter power block and set new signing policy initialization start block number
        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(1, bytes32(0));
        vm.roll(128);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(voterRegistry.newSigningPolicyInitializationStartBlockNumber(1), 128);
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(40, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        uint256 epochVpBlock = flareSystemsManager.getVotePowerBlock(1);
        assertEq(epochVpBlock, 88);
        vm.stopPrank();

        _setVotePowers(epochVpBlock);

        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")),
                initialVoters[3],
                epochVpBlock),
            abi.encode(0)
        );

        vm.roll(block.number + 15);
        vm.prank(initialDelegationAddresses[3]);
        entityManager.confirmDelegationAddressRegistration(initialVoters[3]);
        vm.prank(initialSubmitAddresses[3]);
        entityManager.confirmSubmitAddressRegistration(initialVoters[3]);
        vm.prank(initialSubmitSignaturesAddresses[3]);
        entityManager.confirmSubmitSignaturesAddressRegistration(initialVoters[3]);
        vm.prank(initialSigningPolicyAddresses[3]);
        entityManager.confirmSigningPolicyAddressRegistration(initialVoters[3]);

        _setVotePowers(epochVpBlock);

        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")),
                initialVoters[3],
                epochVpBlock),
            abi.encode(0)
        );

        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(100);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 20);
        initialVotersRegistrationWeight[2] = _calculateWeight(200 + 30 + 40);
        initialVotersRegistrationWeight[3] = _calculateWeight(0 + 40 + 50 + 0);

        vm.prank(governance);
        calculator.enablePChainStakeMirror();
        assertEq(calculator.pChainStakeMirrorEnabled(), true);
        vm.prank(addressUpdater);
        calculator.updateContractAddresses(contractNameHashes, contractAddresses);
        assertEq(address(calculator.pChainStakeMirror()), mockPChainStakeMirror);

        for (uint256 i = 1; i < initialVoters.length - 1; i++) {
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
                initialVotersRegistrationWeight[i]
            );
            voterRegistry.registerVoter(initialVoters[i], signature);
        }

        // register voter3; did not register its addresses before new signing policy initialization start block number
        // therefore its signing policy address is the same as its voter address
        // should not be able to register
        bytes32 messageHash = keccak256(abi.encode(1, initialVoters[3]));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(initialVotersPK[3], signedMessageHash);
        signature = IVoterRegistry.Signature(v, r, s);
        voter3RegisteredNodesAtVpBlock = new bytes20[](2);
        voter3RegisteredNodesAtVpBlock[0] = initialNodeIds[3][0];
        voter3RegisteredNodesAtVpBlock[1] = initialNodeIds[3][1];
        voter3RegisteredPChainVPAtVpBlock = new uint256[](2);
        voter3RegisteredPChainVPAtVpBlock[0] = initialVotersPChainVP[3][0];
        voter3RegisteredPChainVPAtVpBlock[1] = initialVotersPChainVP[3][1];
        vm.mockCall(
            mockPChainStakeMirror,
            abi.encodeWithSelector(
                bytes4(keccak256("batchVotePowerOfAt(bytes20[],uint256)")),
                voter3RegisteredNodesAtVpBlock,
                epochVpBlock
            ),
            abi.encode(voter3RegisteredPChainVPAtVpBlock)
        );

        vm.expectRevert("signing policy address not set");
        voterRegistry.registerVoter(initialVoters[3], signature);

        assertEq(voterRegistry.isVoterRegistered(initialVoters[0], 1), false);

        address[] memory addresses = voterRegistry.getRegisteredVoters(1);
        assertEq(addresses.length, 2);
        assertEq(addresses[0], initialVoters[1]);
        assertEq(addresses[1], initialVoters[2]);

        // create signing policy snapshot
        _createSigningPolicySnapshot();

        vm.expectRevert("voter not registered");
        voterRegistry.getPublicKeyAndNormalisedWeight(1, initialSigningPolicyAddresses[0]);

        addresses = voterRegistry.getRegisteredDelegationAddresses(1);
        assertEq(addresses.length, 2);
        assertEq(addresses[0], initialDelegationAddresses[1]);
        assertEq(addresses[1], initialDelegationAddresses[2]);

        addresses = voterRegistry.getRegisteredSubmitAddresses(1);
        assertEq(addresses.length, 2);
        assertEq(addresses[0], initialSubmitAddresses[1]);
        assertEq(addresses[1], initialSubmitAddresses[2]);

        addresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(1);
        assertEq(addresses.length, 2);
        assertEq(addresses[0], initialSubmitSignaturesAddresses[1]);
        assertEq(addresses[1], initialSubmitSignaturesAddresses[2]);

        addresses = voterRegistry.getRegisteredSigningPolicyAddresses(1);
        assertEq(addresses.length, 2);
        assertEq(addresses[0], initialSigningPolicyAddresses[1]);
        assertEq(addresses[1], initialSigningPolicyAddresses[2]);

        // move to the reward epoch 1
        newSigningPolicyHash = keccak256("signingPolicyHash1");
        _mockToSigningPolicyHash(1, newSigningPolicyHash);
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 1);

        // sign new signing policy (for reward epoch 1)
        // all voters have the same initial weight but only registered can sign
        addresses = voterRegistry.getRegisteredVoters(0);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialVoters[0]);
        assertEq(addresses[1], initialVoters[1]);
        assertEq(addresses[2], initialVoters[2]);
        assertEq(addresses[3], initialVoters[3]);
        // voter0 did not register its signing policy address
        // before new signing policy initialization start block number
        vm.expectRevert("invalid signing policy address");
        voterRegistry.getVoterWithNormalisedWeight(0, initialSigningPolicyAddresses[0]);


        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(newSigningPolicyHash);
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[0], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("invalid signing policy address");
        flareSystemsManager.signNewSigningPolicy(1, newSigningPolicyHash, signatureFSM);

        // voter signs with its identity address -> should revert
        (v, r, s) = vm.sign(initialVotersPK[0], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("invalid signing policy address");
        flareSystemsManager.signNewSigningPolicy(1, newSigningPolicyHash, signatureFSM);


        // select vote power block for the reward epoch 2
        currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(2, bytes32(0));
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(voterRegistry.newSigningPolicyInitializationStartBlockNumber(1), 128);
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(55, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        epochVpBlock = flareSystemsManager.getVotePowerBlock(2);
        assertEq(epochVpBlock, block.number - 55);
        vm.stopPrank();
        _setVotePowers(epochVpBlock);

        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(100);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 20);
        initialVotersRegistrationWeight[2] = _calculateWeight(200 + 30 + 40);
        initialVotersRegistrationWeight[3] = _calculateWeight(200 + 40 + 50 + 60);

        vm.prank(governance);
        voterRegistry.setMaxVoters(4);

        for (uint256 i = 0; i < initialVoters.length; i++) {
            signature = _createSigningPolicyAddressSignature(i, 2);
            vm.expectEmit();
            emit VoterRegistered(
                initialVoters[i],
                uint24(2),
                initialSigningPolicyAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialPublicKeyParts1[i],
                initialPublicKeyParts2[i],
                initialVotersRegistrationWeight[i]
            );
            voterRegistry.registerVoter(initialVoters[i], signature);
        }

        addresses = voterRegistry.getRegisteredVoters(2);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialVoters[0]);
        assertEq(addresses[1], initialVoters[1]);
        assertEq(addresses[2], initialVoters[2]);
        assertEq(addresses[3], initialVoters[3]);

        assertEq(voterRegistry.isVoterRegistered(initialVoters[0], 2), true);


        // create signing policy snapshot
        _createSigningPolicySnapshot();

        (uint256 weightsSum, ,) = voterRegistry.getWeightsSums(2);
        for (uint256 i = 0; i < initialVoters.length; i++) {
            (address voter, uint16 normWeight) =
                voterRegistry.getVoterWithNormalisedWeight(2, initialSigningPolicyAddresses[i]);
            uint256 weight = voterRegistry.getVoterRegistrationWeight(initialVoters[i], 2);
            assertEq(voter, initialVoters[i]);
            assertEq(normWeight, uint16((weight * UINT16_MAX) / weightsSum));
        }

        addresses = voterRegistry.getRegisteredDelegationAddresses(2);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialDelegationAddresses[0]);
        assertEq(addresses[1], initialDelegationAddresses[1]);
        assertEq(addresses[2], initialDelegationAddresses[2]);
        assertEq(addresses[3], initialDelegationAddresses[3]);

        addresses = voterRegistry.getRegisteredSubmitAddresses(2);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialSubmitAddresses[0]);
        assertEq(addresses[1], initialSubmitAddresses[1]);
        assertEq(addresses[2], initialSubmitAddresses[2]);
        assertEq(addresses[3], initialSubmitAddresses[3]);

        addresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(2);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialSubmitSignaturesAddresses[0]);
        assertEq(addresses[1], initialSubmitSignaturesAddresses[1]);
        assertEq(addresses[2], initialSubmitSignaturesAddresses[2]);
        assertEq(addresses[3], initialSubmitSignaturesAddresses[3]);

        addresses = voterRegistry.getRegisteredSigningPolicyAddresses(2);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialSigningPolicyAddresses[0]);
        assertEq(addresses[1], initialSigningPolicyAddresses[1]);
        assertEq(addresses[2], initialSigningPolicyAddresses[2]);
        assertEq(addresses[3], initialSigningPolicyAddresses[3]);
    }

    function testChillVoterAndSign() public {
        testRegisterVoters3();

        // chill voter2 -> its delegation address and both nodes
        bytes20[] memory beneficiaries = new bytes20[](3);
        beneficiaries[0] = bytes20(initialDelegationAddresses[2]);
        beneficiaries[1] = initialNodeIds[2][0];
        beneficiaries[2] = initialNodeIds[2][1];
        vm.prank(governance);
        voterRegistry.chill(beneficiaries, 2);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            assertEq(voterRegistry.chilledUntilRewardEpochId(beneficiaries[i]), 4);
        }

        // for voter3 we don't chill its third node -> voter can register
        beneficiaries = new bytes20[](3);
        beneficiaries[0] = bytes20(initialDelegationAddresses[3]);
        beneficiaries[1] = initialNodeIds[3][0];
        beneficiaries[2] = initialNodeIds[3][1];
        vm.prank(governance);
        voterRegistry.chill(beneficiaries, 2);
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            assertEq(voterRegistry.chilledUntilRewardEpochId(beneficiaries[i]), 4);
        }

        // move to the reward epoch 2
        _mockToSigningPolicyHash(2, keccak256("signingPolicy2"));
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 2);

        // cant yet sign uptime
        bytes32 uptimeHash = keccak256("uptimeVote1");
        bytes32 messageHash = keccak256(abi.encode(1, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[0], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("sign uptime vote not started yet");
        flareSystemsManager.signUptimeVote(1, uptimeHash, signatureFSM);


        // select vote power block for the reward epoch 3
        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(3, bytes32(0));
        vm.roll(block.number + 75);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(40, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        uint256 epochVpBlock = flareSystemsManager.getVotePowerBlock(3);
        vm.stopPrank();

        _setVotePowers(epochVpBlock);

        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(100);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 20);
        initialVotersRegistrationWeight[2] = _calculateWeight(0 + 0 + 0);
        initialVotersRegistrationWeight[3] = _calculateWeight(0 + 0 + 0 + 60);

        //// sign uptime vote
        // voter0 can't sign because it is not registered for reward epoch 1
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[0], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("voter not registered");
        flareSystemsManager.signUptimeVote(1, uptimeHash, signatureFSM);

        // voter 1 signs
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[1], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit UptimeVoteSigned(
            1,
            initialSigningPolicyAddresses[1],
            initialVoters[1],
            uptimeHash,
            uint64(block.timestamp),
            false
        );
        flareSystemsManager.signUptimeVote(1, uptimeHash, signatureFSM);

        // voter3 can't sign because its signing policy address was not registered
        // before new signing policy initialization start block number
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[3], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("invalid signing policy address");
        flareSystemsManager.signUptimeVote(1, uptimeHash, signatureFSM);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[2], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signUptimeVote(1, uptimeHash, signatureFSM);

        // can't yet sign rewards, because new signing policy (for epoch 2) is not yet signed
        bytes32 rewardsHash = keccak256("rewards1");
        IFlareSystemsManager.NumberOfWeightBasedClaims[] memory noOfWeightBasedClaims =
            new IFlareSystemsManager.NumberOfWeightBasedClaims[](1);
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 3);
        messageHash = keccak256(abi.encode(1, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[2], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("signing policy not signed yet");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signatureFSM);

        //// sign new signing policy
        newSigningPolicyHash = keccak256("signingPolicy2");
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(newSigningPolicyHash);

        // voter2 signs
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[2], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            2,
            initialSigningPolicyAddresses[2],
            initialVoters[2],
            uint64(block.timestamp),
            true
        );
        flareSystemsManager.signNewSigningPolicy(2, newSigningPolicyHash, signatureFSM);

        //// sign rewards for reward epoch 1
        assertEq(flareSystemsManager.rewardsHash(1), bytes32(0));
        messageHash = keccak256(abi.encode(1, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[2], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signatureFSM);
        assertEq(flareSystemsManager.rewardsHash(1), rewardsHash);

        vm.expectRevert("rewards hash already signed");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signatureFSM);

        (v, r, s) = vm.sign(initialVotersPK[3], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("rewards hash already signed");
        flareSystemsManager.signRewards(1, noOfWeightBasedClaims, rewardsHash, signatureFSM);

        for (uint256 i = 0; i < initialVoters.length; i++) {
            signature = _createSigningPolicyAddressSignature(i, 3);
            if (i == 2) {
                vm.expectRevert("voter weight zero");
            } else {
                vm.expectEmit();
                emit VoterRegistered(
                    initialVoters[i],
                    uint24(3),
                    initialSigningPolicyAddresses[i],
                    initialSubmitAddresses[i],
                    initialSubmitSignaturesAddresses[i],
                    initialPublicKeyParts1[i],
                    initialPublicKeyParts2[i],
                    initialVotersRegistrationWeight[i]
                );
            }
            voterRegistry.registerVoter(initialVoters[i], signature);
        }

        address[] memory addresses = voterRegistry.getRegisteredVoters(3);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialVoters[0]);
        assertEq(addresses[1], initialVoters[1]);
        assertEq(addresses[2], initialVoters[3]);

        assertEq(voterRegistry.isVoterRegistered(initialVoters[2], 3), false);

        // create signing policy snapshot
        _createSigningPolicySnapshot();

        addresses = voterRegistry.getRegisteredDelegationAddresses(3);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialDelegationAddresses[0]);
        assertEq(addresses[1], initialDelegationAddresses[1]);
        assertEq(addresses[2], initialDelegationAddresses[3]);

        addresses = voterRegistry.getRegisteredSubmitAddresses(3);
        assertEq(addresses.length, 3);
        assertEq(addresses[0], initialSubmitAddresses[0]);
        assertEq(addresses[1], initialSubmitAddresses[1]);
        assertEq(addresses[2], initialSubmitAddresses[3]);

        // move to the reward epoch 3
        _mockToSigningPolicyHash(3, keccak256("signingPolicy3"));
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 3);

        //// sign new signing policy (for reward epoch 3)
        newSigningPolicyHash = keccak256("signingPolicy3");
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(newSigningPolicyHash);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[0], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signNewSigningPolicy(3, newSigningPolicyHash, signatureFSM);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[1], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            3,
            initialSigningPolicyAddresses[1],
            initialVoters[1],
            uint64(block.timestamp),
            false
        );
        flareSystemsManager.signNewSigningPolicy(3, newSigningPolicyHash, signatureFSM);

        // voter3 now has registered its signing policy address and can sign with it
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[3], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            3,
            initialSigningPolicyAddresses[3],
            initialVoters[3],
            uint64(block.timestamp),
            true
        );
        flareSystemsManager.signNewSigningPolicy(3, newSigningPolicyHash, signatureFSM);

        // unregister node; change delegation address
        vm.prank(initialVoters[1]);
        entityManager.unregisterNodeId(initialNodeIds[1][0]);
        vm.prank(initialVoters[0]);
        address newDelegationAddress = makeAddr("newDelegationAddress");
        entityManager.proposeDelegationAddress(newDelegationAddress);
        vm.prank(newDelegationAddress);
        entityManager.confirmDelegationAddressRegistration(initialVoters[0]);
        (address newSigningPolicyAddress, uint256 newSigningPolicyPK) = makeAddrAndKey("newSigningPolicyAddress");
        vm.prank(initialVoters[1]);
        entityManager.proposeSigningPolicyAddress(newSigningPolicyAddress);
        vm.prank(newSigningPolicyAddress);
        entityManager.confirmSigningPolicyAddressRegistration(initialVoters[1]);

        address newSubmitAddress = makeAddr("newSubmitAddress");
        vm.prank(initialVoters[3]);
        entityManager.proposeSubmitAddress(newSubmitAddress);
        vm.prank(newSubmitAddress);
        entityManager.confirmSubmitAddressRegistration(initialVoters[3]);

        // select vote power block for the reward epoch 4
        currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(4, bytes32(0));
        vm.roll(block.number + 75);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(40, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        epochVpBlock = flareSystemsManager.getVotePowerBlock(4);
        vm.stopPrank();

        _setVotePowers(epochVpBlock);
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")),
                newDelegationAddress,
                epochVpBlock),
            abi.encode(23)
        );

        //// sign uptime vote for epoch 2
        uptimeHash = keccak256("uptimeVote2");
        messageHash = keccak256(abi.encode(2, uptimeHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[2], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signUptimeVote(2, uptimeHash, signatureFSM);
        assertEq(flareSystemsManager.uptimeVoteHash(2), bytes32(0));

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[3], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signUptimeVote(2, uptimeHash, signatureFSM);
        assertEq(flareSystemsManager.uptimeVoteHash(2), uptimeHash);

        //// sign rewards for reward epoch 2
        rewardsHash = keccak256("rewards2");
        noOfWeightBasedClaims[0] = IFlareSystemsManager.NumberOfWeightBasedClaims(0, 6);
        messageHash = keccak256(abi.encode(2, keccak256(abi.encode(noOfWeightBasedClaims)), rewardsHash));
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[2], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signRewards(2, noOfWeightBasedClaims, rewardsHash, signatureFSM);
        assertEq(flareSystemsManager.rewardsHash(2), bytes32(0));

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[3], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        flareSystemsManager.signRewards(2, noOfWeightBasedClaims, rewardsHash, signatureFSM);
        assertEq(flareSystemsManager.rewardsHash(2), rewardsHash);


        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(23);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 0);
        initialVotersRegistrationWeight[2] = _calculateWeight(200 + 30 + 40);
        initialVotersRegistrationWeight[3] = _calculateWeight(200 + 40 + 50 + 60);

        for (uint256 i = 0; i < initialVoters.length; i++) {
            signature = _createSigningPolicyAddressSignature(i, 4);
            vm.expectEmit();
            if (i == 1) {
                bytes32 messageHashRegister = keccak256(abi.encode(4, initialVoters[i]));
                bytes32 signedMessageHashRegister = MessageHashUtils.toEthSignedMessageHash(messageHashRegister);
                (v, r, s) = vm.sign(newSigningPolicyPK, signedMessageHashRegister);
                signature = IVoterRegistry.Signature(v, r, s);
                emit VoterRegistered(
                    initialVoters[i],
                    uint24(4),
                    newSigningPolicyAddress,
                    initialSubmitAddresses[i],
                    initialSubmitSignaturesAddresses[i],
                    initialPublicKeyParts1[i],
                    initialPublicKeyParts2[i],
                    initialVotersRegistrationWeight[i]
                );
            } else if (i != 3) {
                emit VoterRegistered(
                    initialVoters[i],
                    uint24(4),
                    initialSigningPolicyAddresses[i],
                    initialSubmitAddresses[i],
                    initialSubmitSignaturesAddresses[i],
                    initialPublicKeyParts1[i],
                    initialPublicKeyParts2[i],
                    initialVotersRegistrationWeight[i]
                );
            } else {
                emit VoterRegistered(
                    initialVoters[i],
                    uint24(4),
                    initialSigningPolicyAddresses[i],
                    newSubmitAddress,
                    initialSubmitSignaturesAddresses[i],
                    initialPublicKeyParts1[i],
                    initialPublicKeyParts2[i],
                    initialVotersRegistrationWeight[i]
                );
            }
            voterRegistry.registerVoter(initialVoters[i], signature);
        }

        addresses = voterRegistry.getRegisteredVoters(4);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialVoters[0]);
        assertEq(addresses[1], initialVoters[1]);
        assertEq(addresses[2], initialVoters[2]);
        assertEq(addresses[3], initialVoters[3]);


        // create signing policy snapshot
        _createSigningPolicySnapshot();

        addresses = voterRegistry.getRegisteredDelegationAddresses(4);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], newDelegationAddress);
        assertEq(addresses[1], initialDelegationAddresses[1]);
        assertEq(addresses[2], initialDelegationAddresses[2]);
        assertEq(addresses[3], initialDelegationAddresses[3]);

        addresses = voterRegistry.getRegisteredSubmitAddresses(4);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialSubmitAddresses[0]);
        assertEq(addresses[1], initialSubmitAddresses[1]);
        assertEq(addresses[2], initialSubmitAddresses[2]);
        assertEq(addresses[3], newSubmitAddress);

        addresses = voterRegistry.getRegisteredSubmitSignaturesAddresses(4);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialSubmitSignaturesAddresses[0]);
        assertEq(addresses[1], initialSubmitSignaturesAddresses[1]);
        assertEq(addresses[2], initialSubmitSignaturesAddresses[2]);
        assertEq(addresses[3], initialSubmitSignaturesAddresses[3]);

        addresses = voterRegistry.getRegisteredSigningPolicyAddresses(4);
        assertEq(addresses.length, 4);
        assertEq(addresses[0], initialSigningPolicyAddresses[0]);
        assertEq(addresses[1], newSigningPolicyAddress);
        assertEq(addresses[2], initialSigningPolicyAddresses[2]);
        assertEq(addresses[3], initialSigningPolicyAddresses[3]);

        //// sign new signing policy (for reward epoch 4)
        // voters 0, 1 and 3 are registered for reward epoch 3
        // registration weights for epoch 3: 30, 0, 42, 14 -> voter2 can't confirm alone
        _mockToSigningPolicyHash(4, keccak256("signingPolicy4"));
        newSigningPolicyHash = keccak256("signingPolicy4");
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(newSigningPolicyHash);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[1], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            4,
            initialSigningPolicyAddresses[1],
            initialVoters[1],
            uint64(block.timestamp),
            false
        );
        flareSystemsManager.signNewSigningPolicy(4, newSigningPolicyHash, signatureFSM);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[2], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("voter not registered");
        flareSystemsManager.signNewSigningPolicy(4, newSigningPolicyHash, signatureFSM);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[3], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            4,
            initialSigningPolicyAddresses[3],
            initialVoters[3],
            uint64(block.timestamp),
            true
        );
        flareSystemsManager.signNewSigningPolicy(4, newSigningPolicyHash, signatureFSM);

        // move to the reward epoch 4
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 4);

        // select vote power block for the reward epoch 5
        currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(5, bytes32(0));
        vm.roll(block.number + 75);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(40, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        epochVpBlock = flareSystemsManager.getVotePowerBlock(5);
        vm.stopPrank();

        _setVotePowers(epochVpBlock);
        vm.mockCall(
            mockWNat,
            abi.encodeWithSelector(
                bytes4(keccak256("votePowerOfAt(address,uint256)")),
                newDelegationAddress,
                epochVpBlock),
            abi.encode(23)
        );

        _createSigningPolicySnapshot();

        // sign new signing policy (for reward epoch 5)
        // all 4 voter are registered; voter1 change its signing policy address
        newSigningPolicyHash = keccak256("signingPolicy5");
        _mockToSigningPolicyHash(5, newSigningPolicyHash);
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(newSigningPolicyHash);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[0], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            5,
            initialSigningPolicyAddresses[0],
            initialVoters[0],
            uint64(block.timestamp),
            false
        );
        flareSystemsManager.signNewSigningPolicy(5, newSigningPolicyHash, signatureFSM);

        // voter1 changed its signing policy address
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[1], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectRevert("invalid signing policy address");
        flareSystemsManager.signNewSigningPolicy(5, newSigningPolicyHash, signatureFSM);

        (v, r, s) = vm.sign(newSigningPolicyPK, signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            5,
            newSigningPolicyAddress,
            initialVoters[1],
            uint64(block.timestamp),
            false
        );
        flareSystemsManager.signNewSigningPolicy(5, newSigningPolicyHash, signatureFSM);

        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[3], signedMessageHash);
        signatureFSM = IFlareSystemsManager.Signature(v, r, s);
        vm.expectEmit();
        emit SigningPolicySigned(
            5,
            initialSigningPolicyAddresses[3],
            initialVoters[3],
            uint64(block.timestamp),
            true
        );
        flareSystemsManager.signNewSigningPolicy(5, newSigningPolicyHash, signatureFSM);
    }

    function testX() public {
        _registerAddressesAndNodes();
        // set voter registration trigger contract on FSM
        vm.prank(governance);
        flareSystemsManager.setVoterRegistrationTriggerContract(voterPreRegistry);
        // set system registration contract on voter registry
        vm.prank(governance);
        voterRegistry.setSystemRegistrationContractAddress(address(voterPreRegistry));

        uint64 currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(1, bytes32(0));
        vm.roll(128);
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(103, true, currentTime + 1)
        );
        flareSystemsManager.daemonize();
        uint256 epoch1VpBlock = flareSystemsManager.getVotePowerBlock(1);
        assertEq(epoch1VpBlock, 125);
        vm.stopPrank();

        _setVotePowers(epoch1VpBlock);

        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(100);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 20);
        initialVotersRegistrationWeight[2] = _calculateWeight(200 + 30 + 40);
        initialVotersRegistrationWeight[3] = _calculateWeight(200 + 40 + 50 + 60);

        vm.prank(governance);
        calculator.enablePChainStakeMirror();
        assertEq(calculator.pChainStakeMirrorEnabled(), true);
        vm.prank(addressUpdater);
        calculator.updateContractAddresses(contractNameHashes, contractAddresses);
        assertEq(address(calculator.pChainStakeMirror()), mockPChainStakeMirror);

        vm.prank(governance);
        voterRegistry.setMaxVoters(4);
        for (uint256 i = 0; i < initialVoters.length; i++) {
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
                initialVotersRegistrationWeight[i]
            );
            voterRegistry.registerVoter(initialVoters[i], signature);
        }

        address[] memory registeredAddresses = voterRegistry.getRegisteredVoters(1);
        assertEq(registeredAddresses.length, 4);

        // create signing policy snapshot
        _createSigningPolicySnapshot();

        // move to the reward epoch 1
        newSigningPolicyHash = keccak256("signingPolicyHash1");
        _mockToSigningPolicyHash(1, newSigningPolicyHash);
        vm.warp(block.timestamp + 5400);
        vm.roll(block.number + 100);
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(flareSystemsManager.getCurrentRewardEpochId(), 1);

        uint256 currentEpochId = flareSystemsManager.getCurrentRewardEpochId();
        // pre-register voters
        for (uint256 i = 0; i < initialVoters.length; i++) {
            signature = _createSigningPolicyAddressSignature(i, currentEpochId + 1);
            emit VoterPreRegistered(initialVoters[i], 11 + 1);
            voterPreRegistry.preRegisterVoter(initialVoters[i], signature);
        }
        registeredAddresses = voterRegistry.getRegisteredVoters(2);
        assertEq(registeredAddresses.length, 0);

        // move to registration period
        currentTime = uint64(block.timestamp) + REWARD_EPOCH_DURATION_IN_SEC - 2 * 3600;
        vm.warp(currentTime);
        _mockToSigningPolicyHash(2, bytes32(0));
        vm.startPrank(flareDaemon);
        flareSystemsManager.daemonize();
        assertEq(voterRegistry.newSigningPolicyInitializationStartBlockNumber(1), 128);
        vm.warp(currentTime + uint64(11));
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(RandomNumberV2Interface.getRandomNumber.selector),
            abi.encode(55, true, currentTime + 1)
        );
        _setVotePowers(block.number - 55);
        initialVotersRegistrationWeight = new uint256[](4);
        initialVotersRegistrationWeight[0] = _calculateWeight(100);
        initialVotersRegistrationWeight[1] = _calculateWeight(200 + 20);
        initialVotersRegistrationWeight[2] = _calculateWeight(200 + 30 + 40);
        initialVotersRegistrationWeight[3] = _calculateWeight(200 + 40 + 50 + 60);
        for (uint256 i = 0; i < initialVoters.length; i++) {
        vm.expectEmit();
        emit VoterRegistered(
                initialVoters[i],
                uint24(2),
                initialSigningPolicyAddresses[i],
                initialSubmitAddresses[i],
                initialSubmitSignaturesAddresses[i],
                initialPublicKeyParts1[i],
                initialPublicKeyParts2[i],
                initialVotersRegistrationWeight[i]
            );
        }
        // trigger voter registration
        flareSystemsManager.daemonize();
        // all four voters should be registered
        registeredAddresses = voterRegistry.getRegisteredVoters(2);
        assertEq(registeredAddresses.length, 4);
    }


    ////////

    function _registerAddressesAndNodes() private {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            // register voters' addresses, public keys and node IDs
            vm.roll(block.number + 10);
            vm.startPrank(initialVoters[i]);
            entityManager.proposeDelegationAddress(initialDelegationAddresses[i]);
            entityManager.proposeSubmitAddress(initialSubmitAddresses[i]);
            entityManager.proposeSubmitSignaturesAddress(initialSubmitSignaturesAddresses[i]);
            entityManager.proposeSigningPolicyAddress(initialSigningPolicyAddresses[i]);
            if (i == 0) {
                entityManager.registerPublicKey(
                    initialPublicKeyParts1[i],
                    initialPublicKeyParts2[i],
                    validPublicKeyData
                );
            }

            // set pChain voter power
            for (uint256 j = 0; j < i; j++) {
                if (i == 3 && j == 2) {
                    vm.roll(block.number + 20);
                }
                mockNodePossessionVerification.setVoterAndNodeId(initialVoters[i], initialNodeIds[i][j]);
                entityManager.registerNodeId(
                    initialNodeIds[i][j],
                    certificateRawTest,
                    signatureTest
                );
            }
            vm.stopPrank();

            // confirm addresses
            vm.roll(block.number + 15);
            vm.prank(initialDelegationAddresses[i]);
            entityManager.confirmDelegationAddressRegistration(initialVoters[i]);
            vm.prank(initialSubmitAddresses[i]);
            entityManager.confirmSubmitAddressRegistration(initialVoters[i]);
            vm.prank(initialSubmitSignaturesAddresses[i]);
            entityManager.confirmSubmitSignaturesAddressRegistration(initialVoters[i]);
            vm.prank(initialSigningPolicyAddresses[i]);
            entityManager.confirmSigningPolicyAddressRegistration(initialVoters[i]);
        }
    }

    function _setVotePowers(uint256 _vpBlock) private {
        for (uint256 i = 0; i < initialVoters.length; i++) {
            // set wNat voter power
            vm.mockCall(
                mockWNat,
                abi.encodeWithSelector(
                    bytes4(keccak256("votePowerOfAt(address,uint256)")),
                    initialDelegationAddresses[i],
                    _vpBlock),
                abi.encode(initialVotersWNatVP[i])
            );

            vm.mockCall(
                mockPChainStakeMirror,
                abi.encodeWithSelector(
                    bytes4(keccak256("batchVotePowerOfAt(bytes20[],uint256)")),
                    initialNodeIds[i],
                    _vpBlock
                ),
                abi.encode(initialVotersPChainVP[i])
            );

            // voter fee percentage
            vm.mockCall(
                mockWNatDelegationFee,
                abi.encodeWithSelector(IWNatDelegationFee.getVoterFeePercentage.selector, initialVoters[i]),
                abi.encode(2000)
            );

            // total WNat vote power
            vm.mockCall(
                mockWNat,
                abi.encodeWithSelector(bytes4(keccak256("totalVotePowerAt(uint256)")), _vpBlock),
                abi.encode(1000)
            );
        }
    }

    ///// helper functions
    function _createInitialVoters(uint256 _num) internal {
        for (uint256 i = 0; i < _num; i++) {
            (address addr, uint256 pk) = makeAddrAndKey(
                string.concat("initialVoter", vm.toString(i)));
            initialVoters.push(addr);
            initialVotersPK.push(pk);
            initialWeights.push(uint16(UINT16_MAX / _num));

            initialDelegationAddresses.push(makeAddr(
                string.concat("delegationAddress", vm.toString(i))));
            initialSubmitAddresses.push(makeAddr(
                string.concat("submitAddress", vm.toString(i))));
            initialSubmitSignaturesAddresses.push(makeAddr(
                string.concat("submitSignaturesAddress", vm.toString(i))));

            (addr, pk) = makeAddrAndKey(
                string.concat("signingPolicyAddress", vm.toString(i)));
            initialSigningPolicyAddresses.push(addr);
            initialVotersSigningPolicyPk.push(pk);

            // weights
            initialVotersWNatVP.push(100 * (i + 1));

            // public keys
            if (i == 0) {
                initialPublicKeyParts1.push(keccak256(abi.encode("publicKey1")));
                initialPublicKeyParts2.push(keccak256(abi.encode("publicKey2")));
            } else {
                initialPublicKeyParts1.push(bytes32(0));
                initialPublicKeyParts2.push(bytes32(0));
            }

            initialNodeIds.push(new bytes20[](i));
            initialVotersPChainVP.push(new uint256[](i));
            for (uint256 j = 0; j < i; j++) {
                initialNodeIds[i][j] = bytes20(bytes(string.concat("nodeId", vm.toString(i), vm.toString(j))));
                initialVotersPChainVP[i][j] = 10 * (i + j + 1);
            }
        }
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
        signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (v, r, s) = vm.sign(initialVotersSigningPolicyPk[_voterIndex], signedMessageHash);
        _signature = IVoterRegistry.Signature(v, r, s);
    }

    function _mockGetVoterRegistrationData(uint256 _vpBlock, bool _enabled) internal {
        vm.mockCall(
            mockFlareSystemsManager,
            abi.encodeWithSelector(IFlareSystemsManager.getVoterRegistrationData.selector),
            abi.encode(_vpBlock, _enabled)
        );
    }

    function _calculateWeight(uint256 _value) internal view returns (uint256) {
        return calculator.sqrt(_value) * calculator.sqrt(calculator.sqrt(_value));
    }

    function _mockToSigningPolicyHash(uint256 _epochId, bytes32 _hash) private {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, _epochId),
            abi.encode(_hash)
        );
    }

    function _mockCleanupBlockNumber(uint256 _cleanupBlock) internal {
        vm.mockCall(
            mockRewardManager,
            abi.encodeWithSelector(bytes4(keccak256("cleanupBlockNumber()"))),
            abi.encode(_cleanupBlock)
        );
    }

    function _createSigningPolicySnapshot() internal {
        vm.warp(block.timestamp + 30 * 60 + 1); // after 30 minutes
        vm.roll(block.number + 21); // after 20 blocks
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IIRelay.setSigningPolicy.selector),
            abi.encode(bytes32(0))
        );
        vm.prank(flareDaemon);
        flareSystemsManager.daemonize();
    }
}