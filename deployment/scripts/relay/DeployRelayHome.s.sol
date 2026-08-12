// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {console2} from "forge-std/Script.sol";
import {RelayDeployBase} from "./RelayDeployBase.s.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {IGovernanceSettings} from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";

/// The FlareSystemsManager reads the home Relay deployment needs (epoch anchors + policy params).
interface IFlareSystemsManagerRead {
    function getCurrentRewardEpochId() external view returns (uint24);

    function getStartVotingRoundId(uint256 _rewardEpochId) external view returns (uint32);

    function getSeed(uint256 _rewardEpochId) external view returns (uint256);

    function getThreshold(uint256 _rewardEpochId) external view returns (uint16);
}

/// The VoterRegistry reads needed to reconstruct the next reward epoch's signing policy.
interface IVoterRegistryRead {
    function getRegisteredVotersAndNormalisedWeights(
        uint256 _rewardEpochId
    ) external view returns (address[] memory _voters, uint16[] memory _normalisedWeights);

    function newSigningPolicyInitializationStartBlockNumber(
        uint256 _rewardEpochId
    ) external view returns (uint256);
}

/// The EntityManager read mapping voter identity addresses to their signing-policy addresses
/// (checkpointed history — callable any time after the policy snapshot block).
interface IEntityManagerRead {
    function getSigningPolicyAddresses(
        address[] memory _voters,
        uint256 _blockNumber
    ) external view returns (address[] memory);
}

// Flare home deployment (chain id 14 / 19, or a dev chain for rehearsal). Deploys the
// Relay implementation (plain CREATE) + RelayProxy through the Create3Factory (chain-invariant
// address) in SETTER MODE: signingPolicySetter = FlareSystemsManager, oldRelay migration
// handshake, NO feeConfigs, and sourceChainId forced to == block.chainid. The Relay owner
// (governance and upgrade authority via the OwnableWithTimelock queue) is the governance
// address read from GovernanceSettings.
//
// The initial signing-policy hash for the next reward epoch is ALWAYS RECONSTRUCTED from chain
// state (VoterRegistry + EntityManager + FlareSystemsManager views), verified byte-exactly
// against the old Relay's stored hash (legacy chained fold or single-keccak — either must match
// the reconstruction), and seeded as the new single-keccak hash
// (keccak256(sourceChainId ‖ encoded policy)). The owner-timelock duration is the only value
// taken from the config. Every epoch/protocol param is inherited from that Relay's stateData()
// (four are handshake-enforced to match it, the rest are preserved on redeploy), so the home
// config holds no duplicated protocol parameters.
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
        // resolved by name (its own address is not fixed across chains); the Relay owner —
        // authorizing fee setters and UUPS upgrades through the owner-timelock — is its live
        // getGovernanceAddress().
        address flareSystemsManager = _registryAddress("FlareSystemsManager");
        address oldRelay = _registryAddress("Relay");
        address governanceSettings = _registryAddress("GovernanceSettings");
        address relayOwner = IGovernanceSettings(governanceSettings).getGovernanceAddress();
        require(relayOwner != address(0), "GovernanceSettings.getGovernanceAddress() returned zero");
        console2.log("Relay owner (from GovernanceSettings):", relayOwner);

        uint256 timelockDurationSeconds = vm.parseJsonUint(cfg, ".home.timelockDurationSeconds");

        vm.startBroadcast(deployerPrivateKey);

        // Relay implementation + proxy (setter mode) through the factory.
        IRelay.RelayInitialConfig memory config =
            _buildHomeConfig(flareSystemsManager, oldRelay, timelockDurationSeconds);
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
            block.chainid,
            timelockDurationSeconds,
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
            sourceChainId: block.chainid,
            timelockDurationSeconds: timelockDurationSeconds,
            initialRewardEpochId: config.initialRewardEpochId,
            startingVotingRoundId: config.startingVotingRoundIdForInitialRewardEpochId,
            initialSigningPolicyHash: config.initialSigningPolicyHash,
            deployer: deployer
        });
        _writeRelayManifest(string.concat(_configLabel(), "-home"), manifest);
    }

    function _buildHomeConfig(
        address _flareSystemsManager,
        address _oldRelay,
        uint256 _timelockDurationSeconds
    )
        internal view
        returns (IRelay.RelayInitialConfig memory _config)
    {
        // Epoch anchors: migrate the next reward epoch's policy from the current Relay (redeploy-relay.ts).
        IFlareSystemsManagerRead fsm = IFlareSystemsManagerRead(_flareSystemsManager);
        uint32 nextRewardEpochId = uint32(fsm.getCurrentRewardEpochId()) + 1;
        uint32 startVotingRoundId = fsm.getStartVotingRoundId(nextRewardEpochId);

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
            _migratedPolicyHash(fsm, _oldRelay, nextRewardEpochId, startVotingRoundId);
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
        // RLY-23 home-force: a home deployment binds its own chain.
        _config.sourceChainId = block.chainid;
        _config.timelockDurationSeconds = _timelockDurationSeconds;
    }

    /**
     * The initial signing-policy hash for the new Relay. ALWAYS reconstructed and verified —
     * there is deliberately no configured scheme and no pass-through branch (a mistaken config
     * could otherwise seed the canonical proxy with a hash no policy can satisfy):
     *   1. (identity voters, normalised weights) from VoterRegistry
     *   2. voter identity -> signing-policy address via EntityManager at the policy's
     *      registration snapshot block (checkpointed history)
     *   3. seed / threshold from FlareSystemsManager
     * The old Relay's stored hash must equal ONE of the two hashes of the reconstructed bytes —
     * the retired legacy chained fold (every live deployment today) or the single-keccak hash
     * (a future migration from a new-scheme Relay). Either way the byte-exact reconstruction is
     * proven against the old contract, and the returned value is always the single-keccak hash,
     * keccak256(sourceChainId ‖ encoded policy).
     */
    function _migratedPolicyHash(
        IFlareSystemsManagerRead _fsm,
        address _oldRelay,
        uint32 _nextRewardEpochId,
        uint32 _startVotingRoundId
    )
        internal view
        returns (bytes32)
    {
        bytes32 oldPolicyHash = IRelay(_oldRelay).toSigningPolicyHash(_nextRewardEpochId);
        require(oldPolicyHash != bytes32(0), "source Relay signing policy hash is zero");

        IVoterRegistryRead voterRegistry = IVoterRegistryRead(_registryAddress("VoterRegistry"));
        IEntityManagerRead entityManager = IEntityManagerRead(_registryAddress("EntityManager"));
        (address[] memory identityVoters, uint16[] memory weights) =
            voterRegistry.getRegisteredVotersAndNormalisedWeights(_nextRewardEpochId);
        uint256 snapshotBlock = voterRegistry.newSigningPolicyInitializationStartBlockNumber(_nextRewardEpochId);
        require(snapshotBlock != 0, "signing policy snapshot block not set for the next reward epoch");
        address[] memory policyVoters = entityManager.getSigningPolicyAddresses(identityVoters, snapshotBlock);

        bytes memory encodedPolicy = _encodeSigningPolicy(
            uint24(_nextRewardEpochId),
            _startVotingRoundId,
            _fsm.getThreshold(_nextRewardEpochId),
            _fsm.getSeed(_nextRewardEpochId),
            policyVoters,
            weights
        );
        // Byte-exact reconstruction proof against the old Relay before seeding the new one.
        bytes32 newHash = _signingPolicyHash(encodedPolicy, block.chainid);
        require(
            oldPolicyHash == _legacyPolicyContentHash(encodedPolicy) || oldPolicyHash == newHash,
            "old Relay's stored policy hash matches neither hash of the reconstructed signing policy"
        );
        console2.log("Reconstructed signing policy verified against the old Relay; voters:", policyVoters.length);
        return newHash;
    }

    /**
     * Fails fast (before any broadcast) if a home config is missing a required field. The Relay
     * constructor re-validates ranges authoritatively; this just turns cryptic parse reverts
     * into actionable messages.
     */
    function _requireHomeConfig(
        string memory _cfg
    )
        internal view
    {
        _requireField(_cfg, ".home");
        _requireField(_cfg, ".home.timelockDurationSeconds");
        // Epoch/protocol params are read from the currently deployed Relay's stateData(), not
        // configured — see _buildHomeConfig. The initial signing-policy hash is always
        // reconstructed from chain state and verified — see _migratedPolicyHash.
    }

}
