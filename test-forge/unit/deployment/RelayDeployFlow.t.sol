// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

// solhint-disable func-name-mixedcase

import {Test} from "forge-std/Test.sol";
import {RelayDeployBase} from "../../../deployment/scripts/relay/RelayDeployBase.s.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {ISafeGovernance} from "../../../contracts/userInterfaces/ISafeGovernance.sol";
import {Create3Factory} from "../../../contracts/utils/implementation/Create3Factory.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {SafeInstructions} from "../../../contracts/governance/implementation/SafeInstructions.sol";
import {SafeInstructionsProxy} from "../../../contracts/governance/implementation/SafeInstructionsProxy.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/// Minimal Safe stand-in exposing exactly the read surface the deploy path consumes.
contract MockSafe {
    address[] internal owners;
    uint256 internal threshold;
    uint256 public nonce;

    constructor(address[] memory _owners, uint256 _threshold, uint256 _nonce) {
        owners = _owners;
        threshold = _threshold;
        nonce = _nonce;
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getThreshold() external view returns (uint256) {
        return threshold;
    }

    function isOwner(address _owner) external view returns (bool) {
        for (uint256 i; i < owners.length; ++i) {
            if (owners[i] == _owner) return true;
        }
        return false;
    }
}

/// Exposes the deploy base's internal helpers so the flow can be driven from a test.
contract FlowHarness is RelayDeployBase {
    function factoryAddress() external pure returns (address) {
        return _factoryAddress();
    }

    function relayProxySalt(uint256 _sourceChainId) external pure returns (bytes32) {
        return _relayProxySalt(_sourceChainId);
    }

    function readGovernanceStack(address _instructions)
        external view
        returns (GovernanceStackRead memory)
    {
        return _readGovernanceStack(_instructions);
    }

    function governanceConfig(GovernanceStackRead memory _stack)
        external pure
        returns (ISafeGovernance.GovernanceConfig memory)
    {
        return _governanceConfig(_stack);
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
        GovernanceStackRead memory _stack,
        uint32 _initialRewardEpochId,
        uint32 _startingVotingRoundId
    )
        external view
    {
        _verifyRelay(
            _relay, _implementation, _initialOwner, _signingPolicySetter,
            _stack, _initialRewardEpochId, _startingVotingRoundId
        );
    }

    function requireExpectedDeployer(address _deployer, address _expected) external pure {
        _requireExpectedDeployer(_deployer, _expected);
    }

    function requireField(string calldata _cfg, string calldata _key) external view {
        _requireField(_cfg, _key);
    }
}

/**
 * Exercises the shared deploy helpers (factory-CREATE3 proxy deployment, live governance-stack
 * read, and the post-deploy verify suite) against real Relay + SafeInstructions bytecode with a
 * mock Safe — validating the home (setter-mode) and mirror (relay-mode) paths that
 * DeployRelayHome / DeployRelayMirror drive, without needing live RPC forks.
 */
contract RelayDeployFlowTest is Test {
    uint256 internal constant SOURCE_CHAIN = 14;
    uint256 internal constant MIRROR_CHAIN = 42161;

    FlowHarness internal harness;
    address internal deployer = address(0xDEA1);
    address internal owner = address(0x012E4);
    address internal fsm = address(0xF5A1);
    address[] internal safeOwners;

    function setUp() public {
        harness = new FlowHarness();
        // The factory scopes salts by msg.sender; the harness is what actually calls
        // factory.deploy(), so it is the deployer of record here (the broadcast EOA in the
        // real scripts). Aligning the two keeps computeAddress() and deploy() consistent.
        deployer = address(harness);
        // Etch the canonical factory address with real Create3Factory code.
        Create3Factory factory = new Create3Factory();
        vm.etch(harness.factoryAddress(), address(factory).code);

        safeOwners = new address[](3);
        safeOwners[0] = address(0x1001);
        safeOwners[1] = address(0x1002);
        safeOwners[2] = address(0x1003);
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
        MockSafe safe = new MockSafe(safeOwners, 2, 5);
        address instructions = _deploySafeInstructions(address(safe));
        RelayDeployBase.GovernanceStackRead memory homeStack = harness.readGovernanceStack(instructions);
        assertEq(homeStack.sourceChainId, SOURCE_CHAIN);
        assertEq(homeStack.replayFloor, 5);
        assertEq(homeStack.owners.length, 3);

        IRelay.RelayInitialConfig memory homeConfig = _baseConfig(homeStack);
        homeConfig.feeCollectionAddress = payable(address(0)); // setter mode: no collector
        Relay homeImpl = new Relay();
        address homeRelay = harness.deployRelayProxyViaFactory(
            deployer, block.chainid, address(homeImpl), homeConfig, fsm, address(0), owner
        );
        harness.verifyRelay(
            homeRelay, address(homeImpl), owner, fsm, homeStack,
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
        // Fresh chain state (a different chain than the home deploy) but the SAME source-bound
        // governance stack. The deployed address matches the same deterministic prediction as the
        // home deploy — that shared prediction is the cross-chain address invariance.
        vm.chainId(MIRROR_CHAIN);
        // The mirror consumes a snapshot of the Flare source stack (sourceChainId == 14).
        MockSafe safe = new MockSafe(safeOwners, 2, 5);
        vm.chainId(SOURCE_CHAIN);
        address instructions = _deploySafeInstructions(address(safe));
        RelayDeployBase.GovernanceStackRead memory sourceStack = harness.readGovernanceStack(instructions);

        vm.chainId(MIRROR_CHAIN);
        IRelay.RelayInitialConfig memory mirrorConfig = _baseConfig(sourceStack);
        mirrorConfig.feeCollectionAddress = payable(address(0xFEE));
        Relay mirrorImpl = new Relay();
        address mirrorRelay = harness.deployRelayProxyViaFactory(
            deployer, sourceStack.sourceChainId, address(mirrorImpl), mirrorConfig, address(0), address(0), owner
        );
        harness.verifyRelay(
            mirrorRelay, address(mirrorImpl), owner, address(0), sourceStack,
            mirrorConfig.initialRewardEpochId, mirrorConfig.startingVotingRoundIdForInitialRewardEpochId
        );
        // Same source (Flare) ⇒ same salt ⇒ same address as the home deploy, on a different chain.
        assertEq(mirrorRelay, _predictedRelayAddress(SOURCE_CHAIN), "mirror Relay not at the source-scoped address");
        // The mirror binds to the source (Flare), not its own chain.
        assertEq(Relay(mirrorRelay).sourceChainId(), SOURCE_CHAIN);
        assertEq(Relay(mirrorRelay).signingPolicySetter(), address(0));
        assertEq(Relay(mirrorRelay).feeCollectionAddress(), address(0xFEE));
    }

    function test_homeAndCrossSourceMirrorCoexistOnOneChain() public {
        // Songbird (chain 19) hosts BOTH its own home Relay (source 19) and a mirror of Flare
        // (source 14). Source-scoped salts put them at different addresses, so no clash.
        uint256 songbird = 19;
        uint256 flare = SOURCE_CHAIN; // 14

        // Flare source stack (SafeInstructions initialised while chainId == 14).
        vm.chainId(flare);
        RelayDeployBase.GovernanceStackRead memory flareStack =
            harness.readGovernanceStack(_deploySafeInstructions(address(new MockSafe(safeOwners, 2, 5))));

        // Songbird source stack (SafeInstructions initialised while chainId == 19).
        vm.chainId(songbird);
        RelayDeployBase.GovernanceStackRead memory songbirdStack =
            harness.readGovernanceStack(_deploySafeInstructions(address(new MockSafe(safeOwners, 2, 5))));

        // Songbird home (source == this chain == 19).
        IRelay.RelayInitialConfig memory homeConfig = _baseConfig(songbirdStack);
        homeConfig.feeCollectionAddress = payable(address(0));
        address home = harness.deployRelayProxyViaFactory(
            deployer, block.chainid, address(new Relay()), homeConfig, fsm, address(0), owner
        );

        // Flare mirror (source == 14) on the same Songbird chain.
        IRelay.RelayInitialConfig memory mirrorConfig = _baseConfig(flareStack);
        mirrorConfig.feeCollectionAddress = payable(address(0xFEE));
        address mirror = harness.deployRelayProxyViaFactory(
            deployer, flareStack.sourceChainId, address(new Relay()), mirrorConfig, address(0), address(0), owner
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
        MockSafe safe = new MockSafe(safeOwners, 2, 5);
        address instructions = _deploySafeInstructions(address(safe));
        RelayDeployBase.GovernanceStackRead memory stack = harness.readGovernanceStack(instructions);
        IRelay.RelayInitialConfig memory config = _baseConfig(stack);
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

    function _deploySafeInstructions(address _safe) internal returns (address) {
        SafeInstructions impl = new SafeInstructions();
        return address(new SafeInstructionsProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            makeAddr("flareGovernance"),
            makeAddr("addressUpdater"),
            address(impl),
            _safe
        ));
    }

    function _baseConfig(RelayDeployBase.GovernanceStackRead memory _stack)
        internal view
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
        _config.governance = harness.governanceConfig(_stack);
    }
}
