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
/// (checkpointed state, callable any time after the policy snapshot block).
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
// (governance and upgrade authority via the OwnableWithTimelock path) is the governance
// address read from GovernanceSettings.
//
// The initial signing-policy hash for the next reward epoch is ALWAYS RECONSTRUCTED from chain
// state (VoterRegistry + EntityManager + FlareSystemsManager views), verified byte-exactly
// against the source Relay's stored hash (the chained-fold migration format or source-bound
// single-keccak — either must match the reconstruction), and seeded as the target hash
// (keccak256(sourceChainId ‖ encoded policy)). The owner-timelock duration is the only value
// taken from the config. Every epoch/protocol param is inherited from that Relay's stateData()
// (four are handshake-enforced to match it, the rest are preserved on redeploy), so the home
// config holds no duplicated protocol parameters.
//
// Usage — prefer the wrapper (any forge signer: --ledger/--trezor/--account/--gcp/…, or the
// DEPLOYER_PRIVATE_KEY fallback; dry run unless --broadcast):
//   pnpm deploy_relay home flare [--ledger --sender 0x...] [--broadcast]
// Raw equivalent:
//   forge script deployment/scripts/relay/DeployRelayHome.s.sol:DeployRelayHome \
//     --rpc-url $FLARE_RPC --ledger --sender 0x... --broadcast
contract DeployRelayHome is RelayDeployBase {

    function run() external {
        // Whatever forge signs with — --private-key, --account, --ledger, --gcp, … — so keystore,
        // hardware-wallet and KMS paths all work. The address matters (it scopes the CREATE3
        // salt), so it is checked against the config's expectedDeployer and the pinned Relay
        // address before anything is broadcast. Forge's unsigned default sender fails those
        // checks on real networks.
        address deployer = msg.sender;
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
        // authorizing every guarded call (fee settings, UUPS upgrades, the timelock duration
        // and ownership transfer) through the owner-timelock — is its live
        // getGovernanceAddress().
        address flareSystemsManager = _registryAddress("FlareSystemsManager");
        address oldRelay = _registryAddress("Relay");
        address governanceSettings = _registryAddress("GovernanceSettings");
        address relayOwner = IGovernanceSettings(governanceSettings).getGovernanceAddress();
        require(relayOwner != address(0), "GovernanceSettings.getGovernanceAddress() returned zero");
        console2.log("Relay owner (from GovernanceSettings):", relayOwner);

        uint256 timelockDurationSeconds = vm.parseJsonUint(cfg, ".home.timelockDurationSeconds");

        // Explicit, so the broadcast signer is provably the checked account rather than
        // aligning with it by default.
        vm.startBroadcast(deployer);

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
            feeCollectionAddress: address(0), // setter mode: no fee surface
            feeToken: address(0),
            feeConfigs: new IRelay.FeeConfig[](0),
            feeExemptAddresses: new address[](0),
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
        // handshake-enforced to equal the source Relay by Relay.initialize, and the rest
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
        // Setter mode: no fee collection address, no fee configs, no fee token — there is no
        // home config parameter for any of them (Relay.initialize enforces all three zero).
        _config.feeCollectionAddress = payable(address(0));
        _config.feeConfigs = new IRelay.FeeConfig[](0);
        _config.feeToken = address(0);
        // A home deployment binds its own chain as the signing source.
        _config.sourceChainId = block.chainid;
        _config.timelockDurationSeconds = _timelockDurationSeconds;
    }

    /**
     * The initial signing-policy hash for the target Relay. ALWAYS reconstructed and verified —
     * there is deliberately no configured scheme and no pass-through branch (a mistaken config
     * could otherwise seed the canonical proxy with a hash no policy can satisfy):
     *   1. (identity voters, normalised weights) from VoterRegistry
     *   2. voter identity -> signing-policy address via EntityManager at the policy's
     *      registration snapshot block (checkpointed state)
     *   3. seed / threshold from FlareSystemsManager
     * The source Relay's stored hash must equal one of the two supported hashes of the
     * reconstructed bytes: the chained-fold migration format or the source-bound
     * single-keccak format. Either way, the byte-exact reconstruction is proven against the
     * source contract and the returned value is the source-bound single-keccak hash,
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
        // Byte-exact reconstruction proof against the source Relay before seeding the target.
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
