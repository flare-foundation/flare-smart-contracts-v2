// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {RelayDeployBase} from "../../../deployment/scripts/relay/RelayDeployBase.s.sol";
import {
    DeployRelayHome,
    IEntityManagerRead,
    IFlareSystemsManagerRead,
    IVoterRegistryRead
} from "../../../deployment/scripts/relay/DeployRelayHome.s.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IIRelay} from "../../../contracts/protocol/interface/IIRelay.sol";
import {Create3Factory} from "../../../contracts/utils/implementation/Create3Factory.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";

/// Exposes the deploy base's internal helpers so the flow can be driven from a test.
contract FlowHarness is RelayDeployBase {
    function factoryAddress() external pure returns (address) {
        return _factoryAddress();
    }

    function relayProxySalt(uint256 _sourceChainId) external pure returns (bytes32) {
        return _relayProxySalt(_sourceChainId);
    }

    function deployRelayProxyViaFactory(
        address _deployer,
        uint256 _sourceChainId,
        address _implementation,
        IRelay.RelayInitialConfig memory _config,
        address _signingPolicySetter,
        address _oldRelay,
        address _initialOwner
    )
        external
        returns (address)
    {
        return _deployRelayProxyViaFactory(
            _deployer, _sourceChainId, _implementation, _config, _signingPolicySetter, _oldRelay, _initialOwner
        );
    }

    function verifyRelay(
        address _relay,
        address _implementation,
        address _initialOwner,
        address _signingPolicySetter,
        uint256 _sourceChainId,
        uint256 _timelockDurationSeconds,
        uint32 _initialRewardEpochId,
        uint32 _startingVotingRoundId
    )
        external view
    {
        _verifyRelay(
            _relay, _implementation, _initialOwner, _signingPolicySetter,
            _sourceChainId, _timelockDurationSeconds, _initialRewardEpochId, _startingVotingRoundId
        );
    }

    function requireExpectedDeployer(address _deployer, address _expected) external pure {
        _requireExpectedDeployer(_deployer, _expected);
    }

    function requireField(string calldata _cfg, string calldata _key) external view {
        _requireField(_cfg, _key);
    }

    function encodeSigningPolicy(
        uint24 _rewardEpochId,
        uint32 _startVotingRoundId,
        uint16 _threshold,
        uint256 _seed,
        address[] memory _voters,
        uint16[] memory _weights
    )
        external pure
        returns (bytes memory)
    {
        return _encodeSigningPolicy(_rewardEpochId, _startVotingRoundId, _threshold, _seed, _voters, _weights);
    }

    function legacyPolicyContentHash(bytes memory _encodedPolicy) external pure returns (bytes32) {
        return _legacyPolicyContentHash(_encodedPolicy);
    }

    function signingPolicyHash(bytes memory _encodedPolicy, uint256 _sourceChainId) external pure returns (bytes32) {
        return _signingPolicyHash(_encodedPolicy, _sourceChainId);
    }
}

/// Exposes DeployRelayHome's migration helper so the reconstruction flow can be driven from a test.
contract HomeMigrationHarness is DeployRelayHome {
    function migratedPolicyHash(
        address _fsm,
        address _oldRelay,
        uint32 _nextRewardEpochId,
        uint32 _startVotingRoundId
    )
        external view
        returns (bytes32)
    {
        return _migratedPolicyHash(IFlareSystemsManagerRead(_fsm), _oldRelay, _nextRewardEpochId, _startVotingRoundId);
    }
}

/**
 * Exercises the shared deploy helpers (factory-CREATE3 proxy deployment and the post-deploy
 * verify suite) against real Relay bytecode — validating the home (setter-mode) and mirror
 * (relay-mode) paths that DeployRelayHome / DeployRelayMirror drive, without needing live RPC
 * forks.
 */
contract RelayDeployFlowTest is Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant MIRROR_CHAIN = 42161;
    uint256 internal constant MIRROR_TIMELOCK = 86400;

    FlowHarness internal harness;
    address internal deployer = address(0xDEA1);
    address internal owner = address(0x012E4);
    address internal fsm = address(0xF5A1);

    function setUp() public {
        harness = new FlowHarness();
        // The factory scopes salts by msg.sender; the harness is what actually calls
        // factory.deploy(), so it is the deployer of record here (the broadcast EOA in the
        // real scripts). Aligning the two keeps computeAddress() and deploy() consistent.
        deployer = address(harness);
        // Etch the canonical factory address with real Create3Factory code.
        Create3Factory factory = new Create3Factory();
        vm.etch(harness.factoryAddress(), address(factory).code);
    }

    /// The chain-invariant address every deployment of the given source (home or mirror, on any
    /// chain) must land at.
    function _predictedRelayAddress(uint256 _sourceChainId) internal view returns (address) {
        return Create3Factory(harness.factoryAddress()).computeAddress(
            deployer, harness.relayProxySalt(_sourceChainId)
        );
    }

    function test_homeDeploySetterMode() public {
        vm.chainId(SOURCE_CHAIN);
        IRelay.RelayInitialConfig memory homeConfig = _baseConfig(SOURCE_CHAIN, 0);
        homeConfig.feeCollectionAddress = payable(address(0)); // setter mode: no collector
        Relay homeImpl = new Relay();
        address homeRelay = harness.deployRelayProxyViaFactory(
            deployer, block.chainid, address(homeImpl), homeConfig, fsm, address(0), owner
        );
        harness.verifyRelay(
            homeRelay, address(homeImpl), owner, fsm, SOURCE_CHAIN, 0,
            homeConfig.initialRewardEpochId, homeConfig.startingVotingRoundIdForInitialRewardEpochId
        );
        assertEq(homeRelay, _predictedRelayAddress(SOURCE_CHAIN), "home Relay not at the source-scoped address");
        assertEq(Relay(homeRelay).sourceChainId(), SOURCE_CHAIN);
        assertEq(Relay(homeRelay).signingPolicySetter(), fsm);
        assertEq(
            Relay(homeRelay).toSigningPolicyHash(homeConfig.initialRewardEpochId),
            homeConfig.initialSigningPolicyHash
        );
    }

    function test_mirrorDeployRelayModeSameAddress() public {
        // A different chain than the home deploy, but the SAME source binding. The deployed
        // address matches the same deterministic prediction as the home deploy — that shared
        // prediction is the cross-chain address invariance.
        vm.chainId(MIRROR_CHAIN);
        IRelay.RelayInitialConfig memory mirrorConfig = _baseConfig(SOURCE_CHAIN, MIRROR_TIMELOCK);
        mirrorConfig.feeCollectionAddress = payable(address(0xFEE));
        Relay mirrorImpl = new Relay();
        address mirrorRelay = harness.deployRelayProxyViaFactory(
            deployer, SOURCE_CHAIN, address(mirrorImpl), mirrorConfig, address(0), address(0), owner
        );
        harness.verifyRelay(
            mirrorRelay, address(mirrorImpl), owner, address(0), SOURCE_CHAIN, MIRROR_TIMELOCK,
            mirrorConfig.initialRewardEpochId, mirrorConfig.startingVotingRoundIdForInitialRewardEpochId
        );
        // Same source (Flare) ⇒ same salt ⇒ same address as the home deploy, on a different chain.
        assertEq(mirrorRelay, _predictedRelayAddress(SOURCE_CHAIN), "mirror Relay not at the source-scoped address");
        // The mirror binds to the source (Flare), not its own chain.
        assertEq(Relay(mirrorRelay).sourceChainId(), SOURCE_CHAIN);
        assertEq(Relay(mirrorRelay).signingPolicySetter(), address(0));
        assertEq(Relay(mirrorRelay).feeCollectionAddress(), address(0xFEE));
        assertEq(Relay(mirrorRelay).feeToken(), address(0), "feeToken defaults to native when unconfigured");
        assertEq(Relay(mirrorRelay).getTimelockDurationSeconds(), MIRROR_TIMELOCK);
    }

    function test_mirrorDeployWithFeeToken() public {
        // A mirror on a chain without a spendable native token (e.g. Tempo) seeds an ERC-20
        // fee token; the fee table is then denominated in that token's base units.
        vm.chainId(MIRROR_CHAIN);
        IRelay.RelayInitialConfig memory mirrorConfig = _baseConfig(SOURCE_CHAIN, MIRROR_TIMELOCK);
        mirrorConfig.feeCollectionAddress = payable(address(0xFEE));
        mirrorConfig.feeToken = address(0x70CE2);
        mirrorConfig.feeConfigs = new IRelay.FeeConfig[](1);
        mirrorConfig.feeConfigs[0] = IRelay.FeeConfig(100, 5_000_000);
        address mirrorRelay = harness.deployRelayProxyViaFactory(
            deployer, SOURCE_CHAIN, address(new Relay()), mirrorConfig, address(0), address(0), owner
        );
        assertEq(Relay(mirrorRelay).feeToken(), address(0x70CE2), "fee token seeded at deploy");
        assertEq(Relay(mirrorRelay).protocolFee(100), 5_000_000);
        vm.expectRevert(IRelay.FeeTokenActive.selector);
        Relay(mirrorRelay).protocolFeeInWei(100);
    }

    function test_homeAndCrossSourceMirrorCoexistOnOneChain() public {
        // Songbird (chain 19) hosts BOTH its own home Relay (source 19) and a mirror of Flare
        // (source 14). Source-scoped salts put them at different addresses, so no clash.
        uint256 songbird = 19;
        uint256 flare = SOURCE_CHAIN; // 14

        vm.chainId(songbird);

        // Songbird home (source == this chain == 19).
        IRelay.RelayInitialConfig memory homeConfig = _baseConfig(songbird, 0);
        homeConfig.feeCollectionAddress = payable(address(0));
        address home = harness.deployRelayProxyViaFactory(
            deployer, block.chainid, address(new Relay()), homeConfig, fsm, address(0), owner
        );

        // Flare mirror (source == 14) on the same Songbird chain.
        IRelay.RelayInitialConfig memory mirrorConfig = _baseConfig(flare, MIRROR_TIMELOCK);
        mirrorConfig.feeCollectionAddress = payable(address(0xFEE));
        address mirror = harness.deployRelayProxyViaFactory(
            deployer, flare, address(new Relay()), mirrorConfig, address(0), address(0), owner
        );

        assertTrue(home != mirror, "home and cross-source mirror must have distinct addresses");
        assertEq(home, _predictedRelayAddress(songbird));
        assertEq(mirror, _predictedRelayAddress(flare));
        assertGt(home.code.length, 0);
        assertGt(mirror.code.length, 0);
        assertEq(Relay(home).sourceChainId(), songbird);
        assertEq(Relay(mirror).sourceChainId(), flare);
    }

    function test_secondDeployAtSameSaltReverts() public {
        vm.chainId(SOURCE_CHAIN);
        IRelay.RelayInitialConfig memory config = _baseConfig(SOURCE_CHAIN, 0);
        config.feeCollectionAddress = payable(address(0));
        Relay impl = new Relay();
        harness.deployRelayProxyViaFactory(deployer, block.chainid, address(impl), config, fsm, address(0), owner);
        // Redeploy at the predicted address must abort (upgrades go through upgradeToAndCall).
        vm.expectRevert(
            bytes("Relay proxy already deployed at the predicted address; upgrades go through upgradeToAndCall")
        );
        harness.deployRelayProxyViaFactory(deployer, block.chainid, address(impl), config, fsm, address(0), owner);
    }

    function test_expectedDeployerIsMandatory() public {
        // Missing expectedDeployer (zero) is rejected on EVERY chain, dev included.
        vm.chainId(114); // coston2 (dev)
        vm.expectRevert(bytes("expectedDeployer is required in the config (nonzero)"));
        harness.requireExpectedDeployer(deployer, address(0));
    }

    function test_expectedDeployerMustMatchBroadcastKey() public {
        vm.expectRevert(bytes("deployer key does not match the config's expectedDeployer"));
        harness.requireExpectedDeployer(address(0xBEEF), address(0xCAFE));
        // Matching passes.
        harness.requireExpectedDeployer(address(0xCAFE), address(0xCAFE));
    }

    function test_requireFieldRejectsMissingKey() public {
        string memory cfg = "{\"present\":1}";
        harness.requireField(cfg, ".present");
        vm.expectRevert(bytes("required config field missing: .absent"));
        harness.requireField(cfg, ".absent");
    }

    // ---- signing-policy migration (reconstruction) ----

    uint32 internal constant NEXT_EPOCH = 101;
    uint32 internal constant NEXT_START_ROUND = 343360;
    uint16 internal constant POLICY_THRESHOLD = 330; // total weight 600 -> [300, 396] allowed
    uint256 internal constant POLICY_SEED = uint256(keccak256("policy-seed"));

    function _policyVotersAndWeights()
        internal pure
        returns (
            address[] memory _identityVoters,
            address[] memory _policyVoters,
            uint16[] memory _weights
        )
    {
        _identityVoters = new address[](2);
        _identityVoters[0] = address(0x1001);
        _identityVoters[1] = address(0x1002);
        _policyVoters = new address[](2);
        _policyVoters[0] = address(0x2001);
        _policyVoters[1] = address(0x2002);
        _weights = new uint16[](2);
        _weights[0] = 300;
        _weights[1] = 300;
    }

    /// Mocks the FlareContractRegistry + VoterRegistry + EntityManager + FSM view surface the
    /// home migration reads, returning the encoded policy those mocks describe.
    function _mockMigrationSources(
        address _fsmAddr,
        address _voterRegistryAddr,
        address _entityManagerAddr
    )
        internal
        returns (bytes memory _encoded)
    {
        (address[] memory identityVoters, address[] memory policyVoters, uint16[] memory weights) =
            _policyVotersAndWeights();

        address registry = 0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019; // FLARE_CONTRACT_REGISTRY
        vm.etch(registry, hex"00");
        vm.mockCall(
            registry,
            abi.encodeWithSignature("getContractAddressByName(string)", "VoterRegistry"),
            abi.encode(_voterRegistryAddr)
        );
        vm.mockCall(
            registry,
            abi.encodeWithSignature("getContractAddressByName(string)", "EntityManager"),
            abi.encode(_entityManagerAddr)
        );
        vm.mockCall(
            _voterRegistryAddr,
            abi.encodeWithSelector(
                IVoterRegistryRead.getRegisteredVotersAndNormalisedWeights.selector, uint256(NEXT_EPOCH)
            ),
            abi.encode(identityVoters, weights)
        );
        vm.mockCall(
            _voterRegistryAddr,
            abi.encodeWithSelector(
                IVoterRegistryRead.newSigningPolicyInitializationStartBlockNumber.selector, uint256(NEXT_EPOCH)
            ),
            abi.encode(uint256(123456))
        );
        vm.mockCall(
            _entityManagerAddr,
            abi.encodeWithSelector(
                IEntityManagerRead.getSigningPolicyAddresses.selector, identityVoters, uint256(123456)
            ),
            abi.encode(policyVoters)
        );
        vm.mockCall(
            _fsmAddr,
            abi.encodeWithSelector(IFlareSystemsManagerRead.getSeed.selector, uint256(NEXT_EPOCH)),
            abi.encode(POLICY_SEED)
        );
        vm.mockCall(
            _fsmAddr,
            abi.encodeWithSelector(IFlareSystemsManagerRead.getThreshold.selector, uint256(NEXT_EPOCH)),
            abi.encode(POLICY_THRESHOLD)
        );

        _encoded = harness.encodeSigningPolicy(
            uint24(NEXT_EPOCH), NEXT_START_ROUND, POLICY_THRESHOLD, POLICY_SEED, policyVoters, weights
        );
    }

    /// Migration from a legacy old Relay: the policy is reconstructed from the mocked views, its
    /// legacy chained fold must equal the old Relay's stored hash, and the result is the
    /// single-keccak hash of the reconstructed bytes.
    function test_migration_reconstructsVerifiesAndRehashes() public {
        vm.chainId(SOURCE_CHAIN);
        HomeMigrationHarness home = new HomeMigrationHarness();
        address oldRelay = address(0x01dbe1a);
        bytes memory encoded = _mockMigrationSources(fsm, address(0xbe61), address(0xe171));
        vm.mockCall(
            oldRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, uint256(NEXT_EPOCH)),
            abi.encode(harness.legacyPolicyContentHash(encoded))
        );
        bytes32 result = home.migratedPolicyHash(fsm, oldRelay, NEXT_EPOCH, NEXT_START_ROUND);
        assertEq(
            result,
            keccak256(abi.encodePacked(uint256(SOURCE_CHAIN), encoded)),
            "migrated hash must be the single keccak over sourceChainId || encoded policy"
        );
        assertEq(result, harness.signingPolicyHash(encoded, SOURCE_CHAIN), "helper disagrees with literal hash");
    }

    /// Migration from a new-scheme old Relay: the reconstruction is STILL performed and verified
    /// (there is no pass-through branch) — the stored single-keccak hash matches the second
    /// candidate and is re-derived from the reconstructed bytes.
    function test_migration_verifiesAgainstNewSchemeStoredHash() public {
        vm.chainId(SOURCE_CHAIN);
        HomeMigrationHarness home = new HomeMigrationHarness();
        address oldRelay = address(0x01dbe1a);
        bytes memory encoded = _mockMigrationSources(fsm, address(0xbe61), address(0xe171));
        bytes32 newSchemeHash = harness.signingPolicyHash(encoded, SOURCE_CHAIN);
        vm.mockCall(
            oldRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, uint256(NEXT_EPOCH)),
            abi.encode(newSchemeHash)
        );
        assertEq(
            home.migratedPolicyHash(fsm, oldRelay, NEXT_EPOCH, NEXT_START_ROUND),
            newSchemeHash,
            "new-scheme stored hash must verify against the reconstruction and be re-derived"
        );
    }

    /// The byte-exact sanity check fails closed: a stored hash matching NEITHER candidate hash of
    /// the reconstructed policy (e.g. an arbitrary/corrupted value) aborts the deploy before
    /// seeding anything — there is no scheme knob that could skip this check.
    function test_migration_revertsOnReconstructionMismatch() public {
        vm.chainId(SOURCE_CHAIN);
        HomeMigrationHarness home = new HomeMigrationHarness();
        address oldRelay = address(0x01dbe1a);
        _mockMigrationSources(fsm, address(0xbe61), address(0xe171));
        vm.mockCall(
            oldRelay,
            abi.encodeWithSelector(IRelay.toSigningPolicyHash.selector, uint256(NEXT_EPOCH)),
            abi.encode(keccak256("not the reconstructed policy"))
        );
        vm.expectRevert(
            bytes("old Relay's stored policy hash matches neither hash of the reconstructed signing policy")
        );
        home.migratedPolicyHash(fsm, oldRelay, NEXT_EPOCH, NEXT_START_ROUND);
    }

    /// End-to-end coherence: the deploy-script encoder + single-keccak hash reproduce EXACTLY the
    /// hash a live setter-mode Relay stores for the same policy.
    function test_encoderAndHashMatchLiveRelay() public {
        vm.chainId(SOURCE_CHAIN);
        IRelay.RelayInitialConfig memory config = _baseConfig(SOURCE_CHAIN, 0);
        config.feeCollectionAddress = payable(address(0)); // setter mode: no collector
        Relay impl = new Relay();
        address relayAddr = harness.deployRelayProxyViaFactory(
            deployer, block.chainid, address(impl), config, address(this), address(0), owner
        );

        (, address[] memory policyVoters, uint16[] memory weights) = _policyVotersAndWeights();
        IIRelay.SigningPolicy memory sp;
        sp.rewardEpochId = uint24(NEXT_EPOCH); // initialRewardEpochId (100) + 1
        sp.startVotingRoundId = NEXT_START_ROUND;
        sp.threshold = POLICY_THRESHOLD;
        sp.seed = POLICY_SEED;
        sp.voters = policyVoters;
        sp.weights = weights;
        bytes32 stored = Relay(relayAddr).setSigningPolicy(sp);

        bytes memory encoded = harness.encodeSigningPolicy(
            uint24(NEXT_EPOCH), NEXT_START_ROUND, POLICY_THRESHOLD, POLICY_SEED, policyVoters, weights
        );
        assertEq(
            stored,
            harness.signingPolicyHash(encoded, SOURCE_CHAIN),
            "deploy-script encoder/hash disagrees with the live Relay"
        );
    }

    function _baseConfig(
        uint256 _sourceChainId,
        uint256 _timelockDurationSeconds
    )
        internal pure
        returns (IRelay.RelayInitialConfig memory _config)
    {
        _config.initialRewardEpochId = 100;
        // Must satisfy firstRewardEpochStartVotingRoundId + epoch * duration <= startingVotingRoundId.
        _config.startingVotingRoundIdForInitialRewardEpochId = 340000;
        _config.initialSigningPolicyHash = bytes32(uint256(0xABCDEF));
        _config.randomNumberProtocolId = 100;
        _config.firstVotingRoundStartTs = 1658430000;
        _config.votingEpochDurationSeconds = 90;
        _config.firstRewardEpochStartVotingRoundId = 0;
        _config.rewardEpochDurationInVotingEpochs = 3360;
        _config.thresholdIncreaseBIPS = 12000;
        _config.messageFinalizationWindowInRewardEpochs = 10;
        _config.feeConfigs = new IRelay.FeeConfig[](0);
        _config.sourceChainId = _sourceChainId;
        _config.timelockDurationSeconds = _timelockDurationSeconds;
    }
}
