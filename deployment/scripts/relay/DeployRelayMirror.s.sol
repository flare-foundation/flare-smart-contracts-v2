// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {console2} from "forge-std/Script.sol";
import {RelayDeployBase} from "./RelayDeployBase.s.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";

// Mirror Relay deployment for a target chain that mirrors a source. Deploys a Relay
// implementation (plain CREATE) + RelayProxy through the Create3Factory, giving the SAME
// chain-invariant address as every other mirror of that source and the source's home Relay.
//
// RELAY MODE: no signing-policy setter, no oldRelay. Both ends are named EXPLICITLY: RELAY_SOURCE
// selects the source (its `source-snapshot-<source>.json` + `<source>.json` config), RELAY_MIRROR
// names the entry under that config's `mirrors` map. The snapshot supplies the source chain id,
// epoch anchors and source-bound initial policy hash; the reader asserts the snapshot's
// sourceChainId maps back to RELAY_SOURCE, and the entry's `chainId` is asserted against the live
// chain — so neither a wrong-source snapshot nor a wrong RPC can slip through. Per-chain
// owner/fees/exemptions/timelock come from the entry.
//
// Usage — prefer the wrapper (sets RELAY_SOURCE + RELAY_MIRROR, derives the RPC from the mirror
// name; dry run unless --broadcast):
//   pnpm deploy_relay prepare-snapshot flare              # once per source (needs FLARE_RPC)
//   pnpm deploy_relay mirror flare arbitrum               # DRY RUN (needs ARBITRUM_RPC in .env)
//   pnpm deploy_relay mirror flare arbitrum --broadcast   # real deployment
// Raw equivalent:
//   RELAY_SOURCE=flare RELAY_MIRROR=arbitrum forge script .../DeployRelayMirror.s.sol:DeployRelayMirror \
//     --rpc-url $ARBITRUM_RPC --broadcast
contract DeployRelayMirror is RelayDeployBase {

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        // Both ends are explicit: RELAY_SOURCE names which source this mirrors (selects the
        // source-snapshot-<source>.json + <source>.json config), RELAY_MIRROR names the entry.
        string memory sourceName = vm.envString("RELAY_SOURCE");
        string memory mirrorName = vm.envString("RELAY_MIRROR");
        // The mirror NAME is the network label consumed by save-deployed-addresses.ts, so the
        // deployed addresses are recorded to deployment/deploys/<mirrorName>.json (not a chain id).
        console2.log(string.concat("NETWORK: ", mirrorName));
        console2.log(string.concat("Relay mirror of ", sourceName, " on ", mirrorName));

        _requireFactory();
        // Record the (shared) factory address in this chain's deploys file too.
        _logDeployed("Create3Factory", "Create3Factory.sol", _factoryAddress());

        // Read the snapshot for the NAMED source (asserts its sourceChainId maps back to that
        // name), then load that source's config — so an unintended source can never slip through.
        SourceSnapshot memory snapshot = _readSourceSnapshot(sourceName);
        require(
            snapshot.sourceChainId != block.chainid,
            "mirror deploy: source chain id equals this chain - use DeployRelayHome for the home chain"
        );
        (string memory cfg, ) = _readSourceConfig(snapshot.sourceChainId);

        // Bracket-quote the dynamic key so names with hyphens (e.g. "arbitrum-sepolia") parse.
        string memory base = string.concat(".mirrors[\"", mirrorName, "\"]");
        _requireMirrorConfig(cfg, base);
        // Name -> chain binding: the configured chainId must be the chain we are broadcasting on.
        require(
            vm.parseJsonUint(cfg, string.concat(base, ".chainId")) == block.chainid,
            "mirror deploy: configured chainId for this mirror does not match block.chainid (wrong RPC?)"
        );

        _requireExpectedDeployer(deployer, _jsonAddressOr(cfg, ".expectedDeployer", address(0)));

        address relayOwner = vm.parseJsonAddress(cfg, string.concat(base, ".relayOwner"));
        address payable feeCollectionAddress =
            payable(vm.parseJsonAddress(cfg, string.concat(base, ".feeCollectionAddress")));
        uint256 timelockDurationSeconds =
            vm.parseJsonUint(cfg, string.concat(base, ".timelockDurationSeconds"));
        IRelay.RelayInitialConfig memory config =
            _buildMirrorConfig(cfg, base, snapshot, feeCollectionAddress, timelockDurationSeconds);

        vm.startBroadcast(deployerPrivateKey);
        address relayImpl = address(new Relay());
        _logDeployed("RelayImplementation", "Relay.sol", relayImpl);
        // Mirror: salt (and address) is scoped to the SOURCE chain, so every mirror of the same
        // source shares one address — distinct from this chain's own home Relay, if any.
        address relay = _deployRelayProxyViaFactory(
            deployer, snapshot.sourceChainId, relayImpl, config, address(0), address(0), relayOwner
        );
        _logDeployed("Relay", "RelayProxy.sol", relay);
        vm.stopBroadcast();

        _verifyRelay(
            relay,
            relayImpl,
            relayOwner,
            address(0),
            snapshot.sourceChainId,
            timelockDurationSeconds,
            config.initialRewardEpochId,
            config.startingVotingRoundIdForInitialRewardEpochId
        );
        require(
            Relay(relay).feeCollectionAddress() == feeCollectionAddress,
            "verify: fee collection address mismatch"
        );

        RelayManifest memory manifest = RelayManifest({
            configName: mirrorName,
            factory: _factoryAddress(),
            relayImplementation: relayImpl,
            relay: relay,
            owner: relayOwner,
            signingPolicySetter: address(0),
            sourceChainId: snapshot.sourceChainId,
            timelockDurationSeconds: timelockDurationSeconds,
            initialRewardEpochId: config.initialRewardEpochId,
            startingVotingRoundId: config.startingVotingRoundIdForInitialRewardEpochId,
            initialSigningPolicyHash: config.initialSigningPolicyHash,
            deployer: deployer
        });
        _writeRelayManifest(string.concat(mirrorName, "-mirror"), manifest);
    }

    /**
     * Fails fast (before any broadcast) if the named mirror entry is missing or carries a zero
     * owner/fee-collection address (a zero collector would burn collected fees).
     */
    function _requireMirrorConfig(
        string memory _cfg,
        string memory _base
    )
        internal view
    {
        require(
            vm.keyExistsJson(_cfg, _base),
            string.concat("mirror entry not found in source config: ", _base)
        );
        _requireField(_cfg, string.concat(_base, ".chainId"));
        _requireField(_cfg, string.concat(_base, ".relayOwner"));
        _requireField(_cfg, string.concat(_base, ".feeCollectionAddress"));
        _requireField(_cfg, string.concat(_base, ".timelockDurationSeconds"));
        require(
            vm.parseJsonAddress(_cfg, string.concat(_base, ".relayOwner")) != address(0),
            "relayOwner is zero"
        );
        require(
            vm.parseJsonAddress(_cfg, string.concat(_base, ".feeCollectionAddress")) != address(0),
            "feeCollectionAddress is zero (fees would burn)"
        );
    }

    function _buildMirrorConfig(
        string memory _cfg,
        string memory _base,
        SourceSnapshot memory _snapshot,
        address payable _feeCollectionAddress,
        uint256 _timelockDurationSeconds
    )
        internal view
        returns (IRelay.RelayInitialConfig memory _config)
    {
        _config.initialRewardEpochId = _snapshot.initialRewardEpochId;
        _config.startingVotingRoundIdForInitialRewardEpochId = _snapshot.startingVotingRoundId;
        _config.initialSigningPolicyHash = _snapshot.initialSigningPolicyHash;
        _config.randomNumberProtocolId = _snapshot.randomNumberProtocolId;
        _config.firstVotingRoundStartTs = _snapshot.firstVotingRoundStartTs;
        _config.votingEpochDurationSeconds = _snapshot.votingEpochDurationSeconds;
        _config.firstRewardEpochStartVotingRoundId = _snapshot.firstRewardEpochStartVotingRoundId;
        _config.rewardEpochDurationInVotingEpochs = _snapshot.rewardEpochDurationInVotingEpochs;
        _config.thresholdIncreaseBIPS = _snapshot.thresholdIncreaseBIPS;
        _config.messageFinalizationWindowInRewardEpochs = _snapshot.messageFinalizationWindowInRewardEpochs;
        _config.feeCollectionAddress = _feeCollectionAddress;
        _config.feeConfigs = _readFeeConfigs(_cfg, _base);
        _config.feeExemptAddresses = _readFeeExemptAddresses(_cfg, _base);
        // The mirror binds to the snapshotted source, not to its own chain.
        _config.sourceChainId = _snapshot.sourceChainId;
        _config.timelockDurationSeconds = _timelockDurationSeconds;
    }

    /// Per-chain protocol fee configs. Parsed element-by-element (feeInWei may exceed 64 bits, so
    /// abi.decode of the object array is unreliable — see DeployTeeContracts note).
    function _readFeeConfigs(
        string memory _cfg,
        string memory _base
    )
        internal view
        returns (IRelay.FeeConfig[] memory _feeConfigs)
    {
        uint256 count = 0;
        while (vm.keyExistsJson(_cfg, string.concat(_base, ".feeConfigs[", vm.toString(count), "]"))) {
            count++;
        }
        _feeConfigs = new IRelay.FeeConfig[](count);
        for (uint256 i = 0; i < count; i++) {
            string memory entry = string.concat(_base, ".feeConfigs[", vm.toString(i), "]");
            _feeConfigs[i] = IRelay.FeeConfig({
                protocolId: uint8(vm.parseJsonUint(_cfg, string.concat(entry, ".protocolId"))),
                feeInWei: vm.parseJsonUint(_cfg, string.concat(entry, ".feeInWei"))
            });
        }
    }

    /// Accounts seeded as verify() fee-exempt (e.g. DVN adapters) for this mirror. Required in the
    /// schema (may be empty).
    function _readFeeExemptAddresses(
        string memory _cfg,
        string memory _base
    )
        internal view
        returns (address[] memory)
    {
        string memory key = string.concat(_base, ".feeExemptAddresses");
        if (!vm.keyExistsJson(_cfg, key)) return new address[](0);
        return vm.parseJsonAddressArray(_cfg, key);
    }
}
