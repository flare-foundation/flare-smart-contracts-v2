// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;
// solhint-disable no-console

import {Script, console2} from "forge-std/Script.sol";
import {IRelay} from "../../../contracts/userInterfaces/IRelay.sol";
import {Create3Factory} from "../../../contracts/utils/implementation/Create3Factory.sol";
import {Relay} from "../../../contracts/protocol/implementation/Relay.sol";
import {RelayProxy} from "../../../contracts/protocol/implementation/RelayProxy.sol";
import {IFlareContractRegistry} from
    "@flarenetwork/flare-periphery-contracts/flare/IFlareContractRegistry.sol";

/**
 * @title RelayDeployBase
 * @notice Shared plumbing for the owner-governed Relay deployment scripts
 *         (see the Deploy* scripts in this directory and docs/relay-governance.md).
 *
 * Address determinism chain of custody:
 *   1. the canonical keyless CREATE2 deployer (Arachnid) exists at the same address on every
 *      supported chain;
 *   2. `Create3Factory` is deployed through it from the FROZEN initcode committed at
 *      `deployment/create3/Create3Factory.initcode.hex` (pinned by `FACTORY_INITCODE_KECCAK`)
 *      under the fixed `FACTORY_CREATE2_SALT` — identical factory address everywhere, forever;
 *   3. the Relay proxy is deployed through the factory under a salt scoped to BOTH the designated
 *      deployer EOA (the permanent address authority) AND the source chain id — so all deployments
 *      of one source share an address across chains, while a chain's own home (a different source)
 *      gets its own address and can coexist with mirrors of other sources; independent of per-chain
 *      implementations and initializer data.
 *
 * NEVER deploy the factory from a fresh compile: any compiler/settings drift changes the
 * factory address (and with it every future Relay mirror address). The frozen bytes are the
 * source of truth; `FACTORY_INITCODE_KECCAK` guards against accidental edits.
 */
abstract contract RelayDeployBase is Script {

    /// One entry of `deployment/deploys/<network>.json`. NOTE: stdJson decodes struct fields in
    /// alphabetical order of the JSON keys (address, contractName, name) — keep this order.
    struct DeployedContract {
        address addr;
        string contractName;
        string name;
    }

    /// A point-in-time capture of the live Flare source stack, taken by the prepare script and
    /// consumed by the mirror deploy. Every mirror binds to the SAME source (sourceChainId ==
    /// Flare), so the source-bound signing-policy hash is identical on every target — the
    /// snapshot makes that reuse explicit and auditable.
    struct SourceSnapshot {
        uint256 sourceChainId;              // the home Relay's source network id
        uint32 initialRewardEpochId;
        uint32 startingVotingRoundId;
        bytes32 initialSigningPolicyHash;   // already source-bound (bound to Flare) — pass through
        uint32 firstVotingRoundStartTs;
        uint8 votingEpochDurationSeconds;
        uint32 firstRewardEpochStartVotingRoundId;
        uint16 rewardEpochDurationInVotingEpochs;
        uint16 thresholdIncreaseBIPS;
        uint32 messageFinalizationWindowInRewardEpochs;
        uint8 randomNumberProtocolId;
    }

    /// Everything the deployment manifest records for one Relay deployment.
    /// Human-facing deployment record written to deployment/deploys/relay/ — the artifact the
    /// post-deployment checklist (docs/relay-governance.md §6) compares against on-chain
    /// getters. Nothing reads it programmatically. It records the COMPLETE fee surface:
    /// recipient, token, fee table and exemption list (the mirror deploy additionally asserts
    /// each of these against the live contract before writing it).
    struct RelayManifest {
        string configName;
        address factory;
        address relayImplementation;
        address relay;
        address owner;
        address signingPolicySetter;
        uint256 sourceChainId;
        uint256 timelockDurationSeconds;
        uint32 initialRewardEpochId;
        uint32 startingVotingRoundId;
        bytes32 initialSigningPolicyHash;
        address feeCollectionAddress;
        address feeToken;
        IRelay.FeeConfig[] feeConfigs;
        address[] feeExemptAddresses;
        address deployer;
    }

    /// Canonical keyless CREATE2 deployer (Arachnid), verified live on all 21 EVM USDT0 chains
    /// and on Flare, Songbird, Coston and Coston2.
    address internal constant ARACHNID_CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /// Fixed CREATE2 salt for the Create3Factory deployment through the Arachnid deployer.
    /// Changing it changes the factory address on every not-yet-deployed chain.
    bytes32 internal constant FACTORY_CREATE2_SALT = keccak256("flare.create3-factory.v1");

    /// keccak256 of the frozen factory initcode (deployment/create3/Create3Factory.initcode.hex).
    /// The factory is compiled metadata-free (foundry.toml `no-metadata` profile) so this hash —
    /// and thus the CREATE2 address below — depends only on the factory code + solc + optimizer,
    /// not on unrelated metadata/remappings churn. Factory address = f(Arachnid, FACTORY_CREATE2_SALT,
    /// this hash) — see deployment/create3/README.md.
    bytes32 internal constant FACTORY_INITCODE_KECCAK =
        0x527b93054ed37ffa9db40d5b403b0c72aa7b5c50cd28a0e344a25684fbe0f567;

    /// The frozen factory initcode committed in the repo.
    string internal constant FACTORY_INITCODE_FILE = "deployment/create3/Create3Factory.initcode.hex";

    /// Base label for the deployer-scoped CREATE3 salt of the Relay proxy. The actual salt is
    /// SOURCE-CHAIN-SCOPED (`_relayProxySalt(sourceChainId)`): every deployment that mirrors the
    /// same source shares one address, while a network's own home (a different source) gets its
    /// own — so a chain can host both its home Relay and cross-source mirrors without a clash.
    bytes32 internal constant RELAY_PROXY_SALT_BASE = keccak256("flare.relay-proxy.v1");

    /// ERC-1967 implementation slot (eip1967.proxy.implementation).
    bytes32 internal constant ERC1967_IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// Directory the per-chain deployment manifests are written to.
    string internal constant MANIFEST_DIR = "deployment/deploys/relay/";

    /// Well-known FlareContractRegistry address (identical on every Flare network).
    IFlareContractRegistry internal constant FLARE_CONTRACT_REGISTRY =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);

    /**
     * The deployer-scoped CREATE3 salt for a Relay of the given source chain. All deployments
     * that mirror the same source share this salt (hence one address); a network's own home has
     * `_sourceChainId == block.chainid` and therefore its own salt distinct from any mirror it
     * also hosts.
     */
    function _relayProxySalt(
        uint256 _sourceChainId
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(RELAY_PROXY_SALT_BASE, _sourceChainId));
    }

    /**
     * Deploys the Relay proxy through the Create3Factory under the source-scoped salt.
     * Aborts if the predicted address already has code: upgrades go through the owner's
     * `upgradeToAndCall`, never through a redeploy.
     */
    function _deployRelayProxyViaFactory(
        address _deployer,
        uint256 _sourceChainId,
        address _implementation,
        IRelay.RelayInitialConfig memory _initialConfig,
        address _signingPolicySetter,
        address _oldRelay,
        address _initialOwner
    )
        internal
        returns (address _relay)
    {
        bytes32 salt = _relayProxySalt(_sourceChainId);
        Create3Factory factory = Create3Factory(_factoryAddress());
        address predicted = factory.computeAddress(_deployer, salt);
        require(
            predicted.code.length == 0,
            "Relay proxy already deployed at the predicted address; upgrades go through upgradeToAndCall"
        );
        bytes memory initCode = bytes.concat(
            type(RelayProxy).creationCode,
            abi.encode(_implementation, _initialConfig, _signingPolicySetter, _oldRelay, _initialOwner)
        );
        _relay = factory.deploy(salt, initCode);
        require(_relay == predicted, "CREATE3 address prediction mismatch");
    }

    /**
     * Writes the per-chain deployment manifest to `deployment/deploys/relay/<stem>.json`
     * (feeds the docs/relay-governance.md deployment checklist). Skipped on a dry run
     * (RELAY_DRY_RUN set by the wrapper) so a simulation never overwrites a committed manifest
     * with simulated data.
     */
    function _writeRelayManifest(
        string memory _fileStem,
        RelayManifest memory _manifest
    )
        internal
    {
        if (vm.envOr("RELAY_DRY_RUN", false)) {
            console2.log("DRY RUN: skipping deploy manifest write for", _fileStem);
            return;
        }
        vm.createDir(MANIFEST_DIR, true);
        string memory key = "relayManifest";
        vm.serializeString(key, "configName", _manifest.configName);
        vm.serializeUint(key, "chainId", block.chainid);
        vm.serializeAddress(key, "create3Factory", _manifest.factory);
        vm.serializeAddress(key, "relayImplementation", _manifest.relayImplementation);
        vm.serializeAddress(key, "relay", _manifest.relay);
        vm.serializeAddress(key, "owner", _manifest.owner);
        vm.serializeAddress(key, "signingPolicySetter", _manifest.signingPolicySetter);
        vm.serializeUint(key, "sourceChainId", _manifest.sourceChainId);
        vm.serializeUint(key, "timelockDurationSeconds", _manifest.timelockDurationSeconds);
        vm.serializeUint(key, "initialRewardEpochId", _manifest.initialRewardEpochId);
        vm.serializeUint(key, "startingVotingRoundId", _manifest.startingVotingRoundId);
        vm.serializeBytes32(key, "initialSigningPolicyHash", _manifest.initialSigningPolicyHash);
        vm.serializeAddress(key, "feeCollectionAddress", _manifest.feeCollectionAddress);
        vm.serializeAddress(key, "feeToken", _manifest.feeToken);
        // Fee table as parallel arrays (forge's serializer has no struct-array support);
        // amounts are native wei, or feeToken base units when a token is set.
        uint256[] memory feeProtocolIds = new uint256[](_manifest.feeConfigs.length);
        uint256[] memory feeAmounts = new uint256[](_manifest.feeConfigs.length);
        for (uint256 i = 0; i < _manifest.feeConfigs.length; i++) {
            feeProtocolIds[i] = _manifest.feeConfigs[i].protocolId;
            feeAmounts[i] = _manifest.feeConfigs[i].fee;
        }
        vm.serializeUint(key, "feeProtocolIds", feeProtocolIds);
        vm.serializeUint(key, "feeAmounts", feeAmounts);
        vm.serializeAddress(key, "feeExemptAddresses", _manifest.feeExemptAddresses);
        vm.serializeBytes32(key, "relayProxySalt", _relayProxySalt(_manifest.sourceChainId));
        string memory json = vm.serializeAddress(key, "deployer", _manifest.deployer);
        string memory path = string.concat(MANIFEST_DIR, _fileStem, ".json");
        vm.writeJson(json, path);
        console2.log(string.concat("MANIFEST: ", path));
    }

    /**
     * Path of the per-source snapshot: `deployment/deploys/relay/source-snapshot-<source>.json`.
     * Naming it by source (rather than one shared file) means several sources' snapshots coexist
     * and a mirror deploy selects the intended one by name — it cannot silently pick up whichever
     * `prepare` ran last.
     */
    function _sourceSnapshotPath(
        string memory _sourceName
    )
        internal pure
        returns (string memory)
    {
        return string.concat(MANIFEST_DIR, "source-snapshot-", _sourceName, ".json");
    }

    /**
     * Serializes a source snapshot to `source-snapshot-<source>.json` (keyed by the source name
     * derived from the snapshot's own sourceChainId).
     */
    function _writeSourceSnapshot(
        SourceSnapshot memory _snapshot
    )
        internal
    {
        string memory path = _sourceSnapshotPath(_networkName(_snapshot.sourceChainId));
        vm.createDir(MANIFEST_DIR, true);
        string memory key = "sourceSnapshot";
        vm.serializeUint(key, "sourceChainId", _snapshot.sourceChainId);
        vm.serializeUint(key, "initialRewardEpochId", _snapshot.initialRewardEpochId);
        vm.serializeUint(key, "startingVotingRoundId", _snapshot.startingVotingRoundId);
        vm.serializeBytes32(key, "initialSigningPolicyHash", _snapshot.initialSigningPolicyHash);
        vm.serializeUint(key, "firstVotingRoundStartTs", _snapshot.firstVotingRoundStartTs);
        vm.serializeUint(key, "votingEpochDurationSeconds", _snapshot.votingEpochDurationSeconds);
        vm.serializeUint(key, "firstRewardEpochStartVotingRoundId", _snapshot.firstRewardEpochStartVotingRoundId);
        vm.serializeUint(key, "rewardEpochDurationInVotingEpochs", _snapshot.rewardEpochDurationInVotingEpochs);
        vm.serializeUint(key, "thresholdIncreaseBIPS", _snapshot.thresholdIncreaseBIPS);
        vm.serializeUint(
            key, "messageFinalizationWindowInRewardEpochs", _snapshot.messageFinalizationWindowInRewardEpochs
        );
        string memory json =
            vm.serializeUint(key, "randomNumberProtocolId", _snapshot.randomNumberProtocolId);
        vm.writeJson(json, path);
        console2.log(string.concat("SNAPSHOT: ", path));
    }

    /**
     * Reads the snapshot for the named source (`source-snapshot-<source>.json`) and asserts its
     * embedded sourceChainId maps back to that same source name — so a snapshot that was hand-
     * edited or copied for the wrong source is rejected before any deploy.
     */
    function _readSourceSnapshot(
        string memory _sourceName
    )
        internal view
        returns (SourceSnapshot memory _snapshot)
    {
        string memory path = _sourceSnapshotPath(_sourceName);
        require(
            vm.exists(path),
            string.concat("source snapshot not found: ", path, " (run `prepare-snapshot ", _sourceName, "` first)")
        );
        string memory json = vm.readFile(path);
        _snapshot.sourceChainId = vm.parseJsonUint(json, ".sourceChainId");
        _snapshot.initialRewardEpochId = uint32(vm.parseJsonUint(json, ".initialRewardEpochId"));
        _snapshot.startingVotingRoundId = uint32(vm.parseJsonUint(json, ".startingVotingRoundId"));
        _snapshot.initialSigningPolicyHash = vm.parseJsonBytes32(json, ".initialSigningPolicyHash");
        _snapshot.firstVotingRoundStartTs = uint32(vm.parseJsonUint(json, ".firstVotingRoundStartTs"));
        _snapshot.votingEpochDurationSeconds = uint8(vm.parseJsonUint(json, ".votingEpochDurationSeconds"));
        _snapshot.firstRewardEpochStartVotingRoundId =
            uint32(vm.parseJsonUint(json, ".firstRewardEpochStartVotingRoundId"));
        _snapshot.rewardEpochDurationInVotingEpochs =
            uint16(vm.parseJsonUint(json, ".rewardEpochDurationInVotingEpochs"));
        _snapshot.thresholdIncreaseBIPS = uint16(vm.parseJsonUint(json, ".thresholdIncreaseBIPS"));
        _snapshot.messageFinalizationWindowInRewardEpochs =
            uint32(vm.parseJsonUint(json, ".messageFinalizationWindowInRewardEpochs"));
        _snapshot.randomNumberProtocolId = uint8(vm.parseJsonUint(json, ".randomNumberProtocolId"));
        // The snapshot's own sourceChainId must name the source we were asked to read — guards
        // against a snapshot file copied/edited for the wrong source.
        require(
            _streq(_networkName(_snapshot.sourceChainId), _sourceName),
            "source snapshot sourceChainId does not match the requested source name"
        );
    }

    /**
     * Post-deploy assertion suite: the deployed Relay must expose exactly the configured
     * implementation, owner, setter, source chain id, owner-timelock duration, epoch anchors
     * and initial (source-bound, single-keccak) signing policy hash.
     */
    function _verifyRelay(
        address _relay,
        address _implementation,
        address _initialOwner,
        address _signingPolicySetter,
        uint256 _sourceChainId,
        uint256 _timelockDurationSeconds,
        uint32 _initialRewardEpochId,
        uint32 _startingVotingRoundId
    )
        internal view
    {
        Relay relay = Relay(_relay);
        require(
            address(uint160(uint256(vm.load(_relay, ERC1967_IMPLEMENTATION_SLOT)))) == _implementation,
            "verify: ERC1967 implementation mismatch"
        );
        require(relay.owner() == _initialOwner, "verify: owner mismatch");
        require(relay.signingPolicySetter() == _signingPolicySetter, "verify: signing policy setter mismatch");
        require(relay.sourceChainId() == _sourceChainId, "verify: source chain id mismatch");
        require(
            relay.getTimelockDurationSeconds() == _timelockDurationSeconds,
            "verify: timelock duration mismatch"
        );
        (uint32 lastEpoch, uint32 startRound) = relay.lastInitializedRewardEpochData();
        require(lastEpoch == _initialRewardEpochId, "verify: initial reward epoch mismatch");
        require(startRound == _startingVotingRoundId, "verify: starting voting round mismatch");
        // The initial signing-policy hash is asserted via toSigningPolicyHash() by the home
        // script (accessible only in setter mode). On mirrors it is fixed by the constructor's
        // own nonzero require and recorded in the manifest.
    }

    /**
     * Reads the frozen factory initcode and checks it against the committed pin.
     */
    function _frozenFactoryInitCode()
        internal view
        returns (bytes memory _initCode)
    {
        _initCode = vm.parseBytes(_trim(vm.readFile(FACTORY_INITCODE_FILE)));
        require(
            keccak256(_initCode) == FACTORY_INITCODE_KECCAK,
            "frozen Create3Factory initcode does not match FACTORY_INITCODE_KECCAK - never regenerate it"
        );
    }

    /**
     * Requires the canonical Create3Factory to be present (run DeployCreate3Factory first).
     */
    function _requireFactory()
        internal view
        returns (address _factory)
    {
        _factory = _factoryAddress();
        require(
            _factory.code.length > 0,
            "Create3Factory not deployed on this chain - run DeployCreate3Factory first"
        );
    }

    /**
     * Enforces the designated deployer EOA (the permanent address authority for the
     * deployer-scoped Relay proxy salt). MANDATORY on every chain: `expectedDeployer` must be
     * present and nonzero in the config, and the broadcasting key must match it — so a Relay is
     * never minted at an address derived from an unintended key.
     */
    function _requireExpectedDeployer(
        address _deployer,
        address _expected
    )
        internal pure
    {
        require(_expected != address(0), "expectedDeployer is required in the config (nonzero)");
        require(_deployer == _expected, "deployer key does not match the config's expectedDeployer");
    }

    /**
     * Reverts with a clear message if a required config field is absent.
     */
    function _requireField(
        string memory _cfg,
        string memory _key
    )
        internal view
    {
        require(vm.keyExistsJson(_cfg, _key), string.concat("required config field missing: ", _key));
    }

    /**
     * Resolves a protocol contract address by name from the live FlareContractRegistry — the
     * single source of truth for every protocol address on a Flare network (the registry has a
     * uniform address on all of them, so no per-network config or deploys file is needed).
     * Reverts if the registry is absent (non-Flare chain) or does not know the name.
     */
    function _registryAddress(
        string memory _name
    )
        internal view
        returns (address _addr)
    {
        require(
            address(FLARE_CONTRACT_REGISTRY).code.length > 0,
            "FlareContractRegistry not present on this chain"
        );
        _addr = FLARE_CONTRACT_REGISTRY.getContractAddressByName(_name);
        require(_addr != address(0), string.concat(_name, " not found in FlareContractRegistry"));
    }

    /**
     * Resolves a deployed contract address by name from the committed, persistent
     * `deployment/deploys/<network>.json` — the deployed-address registry the repo maintains
     * (latest address per name, `all/` keeps history). This carries contracts not (yet) in the
     * FlareContractRegistry, such as a freshly redeployed `Relay` before governance cuts the
     * registry over. Returns address(0) if the file or name is absent.
     */
    function _readDeployedAddress(
        string memory _network,
        string memory _name
    )
        internal view
        returns (address)
    {
        string memory path = string.concat("deployment/deploys/", _network, ".json");
        if (!vm.exists(path)) return address(0);
        DeployedContract[] memory contracts =
            abi.decode(vm.parseJson(vm.readFile(path)), (DeployedContract[]));
        bytes32 nameHash = keccak256(bytes(_name));
        for (uint256 i = 0; i < contracts.length; i++) {
            if (keccak256(bytes(contracts[i].name)) == nameHash) {
                return contracts[i].addr;
            }
        }
        return address(0);
    }

    /**
     * The config/manifest label for the current chain: the repo network name for the known
     * Flare-family chains, otherwise the numeric chain id (so each USDT0 mirror chain gets its
     * own `<chainId>.json`).
     */
    function _networkName(
        uint256 _chainId
    )
        internal view
        returns (string memory)
    {
        if (_chainId == 14) return "flare";
        if (_chainId == 19) return "songbird";
        if (_chainId == 16) return "coston";
        if (_chainId == 114) return "coston2";
        if (_chainId == 31337) return "scdev";
        return vm.toString(_chainId);
    }

    function _configLabel()
        internal view
        returns (string memory)
    {
        return _networkName(block.chainid);
    }

    /**
     * Reads the per-SOURCE relay deploy config (`deployment/chain-config/relay/<sourceName>.json`,
     * or the `RELAY_CONFIG` env override). Home deploys pass their own chain id; mirror deploys
     * pass the source chain id from the snapshot, so a mirror reads the SAME source config that
     * lists it under `mirrors`.
     */
    function _readSourceConfig(
        uint256 _sourceChainId
    )
        internal view
        returns (
            string memory _json,
            string memory _name
        )
    {
        _name = _networkName(_sourceChainId);
        string memory path = vm.envOr("RELAY_CONFIG", string(""));
        if (bytes(path).length == 0) {
            path = string.concat("deployment/chain-config/relay/", _name, ".json");
        }
        require(vm.exists(path), string.concat("relay config not found: ", path));
        _json = vm.readFile(path);
    }

    /// Optional JSON address: zero when the key is absent.
    function _jsonAddressOr(
        string memory _json,
        string memory _key,
        address _default
    )
        internal view
        returns (address)
    {
        if (!vm.keyExistsJson(_json, _key)) return _default;
        return vm.parseJsonAddress(_json, _key);
    }

    /**
     * The canonical Create3Factory address, derived from the frozen initcode pin — identical
     * on every chain where the Arachnid deployer exists.
     */
    function _factoryAddress()
        internal pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            hex"ff", ARACHNID_CREATE2_DEPLOYER, FACTORY_CREATE2_SALT, FACTORY_INITCODE_KECCAK
        )))));
    }

    /**
     * The Relay source-bound signing-policy hash:
     * keccak256(sourceChainId ‖ raw encoded policy bytes) — one keccak over the 32-byte source
     * id followed by the exact 43 + 22·n encoded bytes, no padding. Must match
     * Relay.setSigningPolicy / relay() and SigningPolicy.hashEncoded (SigningPolicy.ts).
     */
    function _signingPolicyHash(
        bytes memory _encodedPolicy,
        uint256 _sourceChainId
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_sourceChainId, _encodedPolicy));
    }

    /**
     * Encodes a signing policy into the Relay wire format:
     * 2B numberOfVoters ‖ 3B rewardEpochId ‖ 4B startVotingRoundId ‖ 2B threshold ‖ 32B seed ‖
     * n × (20B voter ‖ 2B weight). Must match SigningPolicy.encode (SigningPolicy.ts).
     */
    function _encodeSigningPolicy(
        uint24 _rewardEpochId,
        uint32 _startVotingRoundId,
        uint16 _threshold,
        uint256 _seed,
        address[] memory _voters,
        uint16[] memory _weights
    )
        internal pure
        returns (bytes memory _encoded)
    {
        require(_voters.length > 0, "reconstructed signing policy has no voters");
        require(_voters.length == _weights.length, "reconstructed voters/weights length mismatch");
        _encoded = abi.encodePacked(
            uint16(_voters.length), _rewardEpochId, _startVotingRoundId, _threshold, _seed
        );
        for (uint256 i = 0; i < _voters.length; i++) {
            _encoded = bytes.concat(_encoded, bytes20(_voters[i]), bytes2(_weights[i]));
        }
    }

    /**
     * The migration-compatible chained-fold signing-policy content hash: the
     * encoded policy is zero-padded to a multiple of 32 bytes, the first two 32-byte chunks are
     * hashed together, and every further chunk is folded in with keccak256(hash ‖ chunk).
     * Used only as a migration sanity check to prove that a policy reconstructed from chain
     * state is byte-identical to the source Relay's policy — never to seed the target Relay.
     */
    function _legacyPolicyContentHash(
        bytes memory _encodedPolicy
    )
        internal pure
        returns (bytes32 _hash)
    {
        require(_encodedPolicy.length > 32, "encoded policy too short");
        uint256 paddedLength = ((_encodedPolicy.length + 31) / 32) * 32;
        bytes memory padded = bytes.concat(_encodedPolicy, new bytes(paddedLength - _encodedPolicy.length));
        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            let dataPtr := add(padded, 0x20)
            _hash := keccak256(dataPtr, 64)
            for { let pos := 64 } lt(pos, paddedLength) { pos := add(pos, 32) } {
                mstore(0x00, _hash)
                mstore(0x20, mload(add(dataPtr, pos)))
                _hash := keccak256(0x00, 64)
            }
        }
    }

    /// Strips ASCII whitespace from both ends (frozen initcode file may end with a newline).
    function _trim(string memory _value) internal pure returns (string memory) {
        bytes memory data = bytes(_value);
        uint256 start = 0;
        uint256 end = data.length;
        while (start < end && _isWhitespace(data[start])) start++;
        while (end > start && _isWhitespace(data[end - 1])) end--;
        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = data[start + i];
        }
        return string(result);
    }

    function _streq(string memory _a, string memory _b) internal pure returns (bool) {
        return keccak256(bytes(_a)) == keccak256(bytes(_b));
    }

    function _isWhitespace(bytes1 _char) internal pure returns (bool) {
        return _char == 0x20 || _char == 0x0a || _char == 0x0d || _char == 0x09;
    }

    function _logDeployed(
        string memory _name,
        string memory _contractName,
        address _addr
    )
        internal pure
    {
        console2.log(string.concat("DEPLOYED: ", _name, ", ", _contractName, ": ", vm.toString(_addr)));
    }
}
