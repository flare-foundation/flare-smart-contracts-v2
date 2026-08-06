// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {console2} from "forge-std/Script.sol";
import {RelayDeployBase} from "./RelayDeployBase.s.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {SafeInstructions} from "../../../contracts/governance/implementation/SafeInstructions.sol";
import {SafeInstructionsProxy} from "../../../contracts/governance/implementation/SafeInstructionsProxy.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";

/// The FlareSystemsManager reads the home Relay deployment needs (epoch anchors).
interface IFlareSystemsManagerRead {
    function getCurrentRewardEpochId() external view returns (uint24);

    function getStartVotingRoundId(uint256 _rewardEpochId) external view returns (uint32);
}

// Flare home deployment (chain id 14 / 19, or a dev chain for rehearsal). Deploys the full
// source-chain stack:
//   - SafeInstructions implementation + SafeInstructionsProxy (plain CREATE) — admits the live
//     Safe owner configuration as generation 0;
//   - Relay implementation (plain CREATE) + RelayProxy through the Create3Factory (chain-invariant
//     address) in SETTER MODE: signingPolicySetter = FlareSystemsManager, oldRelay migration
//     handshake, NO feeConfigs, and governance.sourceChainId forced to == block.chainid.
//
// The initial signing-policy hash is migrated from the currently deployed Relay for the next
// reward epoch (see redeploy-relay.ts); the migration scheme (legacy | chain-bound) is the only
// value taken from the config. Every epoch/protocol param is inherited from that Relay's
// stateData() (four are handshake-enforced to match it, the rest are preserved on redeploy), so
// the home config holds no duplicated protocol parameters.
//
// Usage:
//   forge script deployment/scripts/relay/DeployRelayHome.s.sol:DeployRelayHome \
//     --rpc-url $FLARE_RPC --broadcast
contract DeployRelayHome is RelayDeployBase {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        (string memory cfg, string memory network) = _readSourceConfig(block.chainid);
        // Exact "NETWORK: <label>" line consumed by save-deployed-addresses.ts.
        console2.log(string.concat("NETWORK: ", network));
        console2.log("Relay home (setter-mode) deployment");

        _requireExpectedDeployer(deployer, _jsonAddressOr(cfg, ".expectedDeployer", address(0)));
        _requireHomeConfig(cfg);
        _requireFactory();
        // Record the (shared) factory address in this network's deploys file too.
        _logDeployed("Create3Factory", "Create3Factory.sol", _factoryAddress());

        // Every address is read from chain — the FlareContractRegistry is the single source of
        // truth on a Flare network, so no addresses live in the config. GovernanceSettings is
        // resolved by name (its own address is not fixed across chains); the governance Safe is
        // its live getGovernanceAddress() and it governs SafeInstructions, owns the Relay UUPS
        // upgrade path, and is the source-chain Safe instructions target.
        address flareSystemsManager = _registryAddress("FlareSystemsManager");
        address oldRelay = _registryAddress("Relay");
        address addressUpdater = _registryAddress("AddressUpdater");
        address governanceSettings = _registryAddress("GovernanceSettings");
        address governanceSafe = IGovernanceSettings(governanceSettings).getGovernanceAddress();
        require(governanceSafe != address(0), "GovernanceSettings.getGovernanceAddress() returned zero");
        address safe = governanceSafe;
        address initialGovernance = governanceSafe;
        address relayOwner = governanceSafe;
        console2.log("Governance Safe (from GovernanceSettings):", governanceSafe);

        vm.startBroadcast(deployerPrivateKey);

        // 1. SafeInstructions (source-chain quality gate) — admits the live Safe config as gen 0.
        address safeInstructionsImpl = address(new SafeInstructions());
        address safeInstructions = address(new SafeInstructionsProxy(
            IGovernanceSettings(governanceSettings),
            initialGovernance,
            addressUpdater,
            safeInstructionsImpl,
            safe
        ));
        _logDeployed("SafeInstructionsImplementation", "SafeInstructions.sol", safeInstructionsImpl);
        _logDeployed("SafeInstructions", "SafeInstructionsProxy.sol", safeInstructions);

        // 2. Consistent governance stack read from the freshly deployed SafeInstructions.
        GovernanceStackRead memory stack = _readGovernanceStack(safeInstructions);
        require(stack.sourceChainId == block.chainid, "home deploy: SafeInstructions source chain id != this chain");

        // 3. Relay implementation + proxy (setter mode) through the factory.
        IRelay.RelayInitialConfig memory config =
            _buildHomeConfig(cfg, flareSystemsManager, oldRelay, stack);
        address relayImpl = address(new Relay());
        _logDeployed("RelayImplementation", "Relay.sol", relayImpl);
        // Home: source == this chain, so the salt (and address) is this network's own.
        address relay = _deployRelayProxyViaFactory(
            deployer, block.chainid, relayImpl, config, flareSystemsManager, oldRelay, relayOwner
        );
        _logDeployed("Relay", "RelayProxy.sol", relay);

        vm.stopBroadcast();

        _verifyRelay(
            relay,
            relayImpl,
            relayOwner,
            flareSystemsManager,
            stack,
            config.initialRewardEpochId,
            config.startingVotingRoundIdForInitialRewardEpochId
        );
        require(
            Relay(relay).toSigningPolicyHash(config.initialRewardEpochId) == config.initialSigningPolicyHash,
            "verify: initial signing policy hash mismatch"
        );

        RelayManifest memory manifest = RelayManifest({
            configName: network,
            factory: _factoryAddress(),
            relayImplementation: relayImpl,
            relay: relay,
            owner: relayOwner,
            signingPolicySetter: flareSystemsManager,
            safeInstructions: safeInstructions,
            safeInstructionsImplementation: safeInstructionsImpl,
            initialRewardEpochId: config.initialRewardEpochId,
            startingVotingRoundId: config.startingVotingRoundIdForInitialRewardEpochId,
            initialSigningPolicyHash: config.initialSigningPolicyHash,
            deployer: deployer
        });
        _writeRelayManifest(string.concat(_configLabel(), "-home"), manifest, stack);
    }

    function _buildHomeConfig(
        string memory _cfg,
        address _flareSystemsManager,
        address _oldRelay,
        GovernanceStackRead memory _stack
    )
        internal view
        returns (IRelay.RelayInitialConfig memory _config)
    {
        // Epoch anchors: migrate the next reward epoch's policy from the current Relay (redeploy-relay.ts).
        IFlareSystemsManagerRead fsm = IFlareSystemsManagerRead(_flareSystemsManager);
        uint32 nextRewardEpochId = uint32(fsm.getCurrentRewardEpochId()) + 1;
        uint32 startVotingRoundId = fsm.getStartVotingRoundId(nextRewardEpochId);
        bytes32 oldPolicyHash = IRelay(_oldRelay).toSigningPolicyHash(nextRewardEpochId);
        string memory scheme = vm.parseJsonString(_cfg, ".home.oldRelayPolicyHashScheme");

        // Protocol/epoch params are inherited from the currently deployed Relay rather than
        // configured: four of them (firstVotingRoundStartTs, votingEpochDurationSeconds,
        // firstRewardEpochStartVotingRoundId, rewardEpochDurationInVotingEpochs) are
        // handshake-enforced to equal the old Relay by Relay.initialize anyway, and the rest
        // (randomNumberProtocolId, thresholdIncreaseBIPS, messageFinalizationWindowInRewardEpochs)
        // are preserved across a redeploy. Reading them from stateData() removes duplication and a
        // whole class of misconfiguration (same 11-field read the initialize handshake relies on).
        (
            uint8 randomNumberProtocolId,
            uint32 firstVotingRoundStartTs,
            uint8 votingEpochDurationSeconds,
            uint32 firstRewardEpochStartVotingRoundId,
            uint16 rewardEpochDurationInVotingEpochs,
            uint16 thresholdIncreaseBIPS,
            , // randomVotingRoundId
            , // isSecureRandom
            , // lastInitializedRewardEpoch
            , // noSigningPolicyRelay
            uint32 messageFinalizationWindowInRewardEpochs
        ) = IRelay(_oldRelay).stateData();

        _config.initialRewardEpochId = nextRewardEpochId;
        _config.startingVotingRoundIdForInitialRewardEpochId = startVotingRoundId;
        _config.initialSigningPolicyHash =
            _migratedPolicyHash(oldPolicyHash, _stack.sourceChainId, scheme);
        _config.randomNumberProtocolId = randomNumberProtocolId;
        _config.firstVotingRoundStartTs = firstVotingRoundStartTs;
        _config.votingEpochDurationSeconds = votingEpochDurationSeconds;
        _config.firstRewardEpochStartVotingRoundId = firstRewardEpochStartVotingRoundId;
        _config.rewardEpochDurationInVotingEpochs = rewardEpochDurationInVotingEpochs;
        _config.thresholdIncreaseBIPS = thresholdIncreaseBIPS;
        _config.messageFinalizationWindowInRewardEpochs = messageFinalizationWindowInRewardEpochs;
        // Setter mode: no fee collection address, no fee configs (Relay.initialize enforces both).
        _config.feeCollectionAddress = payable(address(0));
        _config.feeConfigs = new IRelay.FeeConfig[](0);
        _config.governance = _governanceConfig(_stack);
    }

    /**
     * Fails fast (before any broadcast) if a home config is missing a required field or carries
     * an invalid migration scheme. The Relay constructor re-validates ranges authoritatively;
     * this just turns cryptic parse reverts into actionable messages.
     */
    function _requireHomeConfig(
        string memory _cfg
    )
        internal view
    {
        _requireField(_cfg, ".home");
        _requireField(_cfg, ".home.oldRelayPolicyHashScheme");
        string memory scheme = vm.parseJsonString(_cfg, ".home.oldRelayPolicyHashScheme");
        require(
            _streq(scheme, "legacy") || _streq(scheme, "chain-bound"),
            "home.oldRelayPolicyHashScheme must be 'legacy' or 'chain-bound'"
        );
        // Epoch/protocol params are read from the currently deployed Relay's stateData(), not
        // configured — see _buildHomeConfig.
    }

}
