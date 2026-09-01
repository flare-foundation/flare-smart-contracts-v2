// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
// solhint-disable no-console

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IGovernanceSettings} from
    "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {IFlareContractRegistry} from
    "@flarenetwork/flare-periphery-contracts/flare/IFlareContractRegistry.sol";
import {TeeOracleInstructionsSender} from
    "../../contracts/tee/extensions/oracle/implementation/TeeOracleInstructionsSender.sol";
import {TeeOracleInstructionsSenderProxy} from
    "../../contracts/tee/extensions/oracle/proxy/TeeOracleInstructionsSenderProxy.sol";
import {TeeOracleFeedStore} from
    "../../contracts/tee/extensions/oracle/implementation/TeeOracleFeedStore.sol";
import {TeeOracleFeedStoreProxy} from
    "../../contracts/tee/extensions/oracle/proxy/TeeOracleFeedStoreProxy.sol";
import {ITeeOracleFeedStore} from
    "../../contracts/userInterfaces/tee/ITeeOracleFeedStore.sol";
import {ITeeOracleInstructionsSender} from
    "../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol";

// solhint-disable-next-line max-line-length
// forge script deployment/scripts/DeployTeeOracle.s.sol:DeployTeeOracle --private-key $DEPLOYER_PRIVATE_KEY --rpc-url $COSTON2_RPC_URL --broadcast --sig "run()"

/**
 * Deploys the TEE oracle extension: one TeeOracleInstructionsSender UUPS proxy for the
 * extension plus one TeeOracleFeedStore UUPS proxy per configured feed (all reading the
 * same sender, so one machine fleet serves every feed), wired via the AddressUpdater and
 * switched to production mode.
 *
 * Steps that CANNOT be scripted here (governance / extension owner, see docs/specs/FCC/TeeOracle.md):
 * - FlareTeeManager.registerReserved(extensionId, owner)          - Flare governance (timelocked)
 * - FlareTeeManager.setExtensionContracts(extensionId, 0, sender) - extension owner (direct)
 * - addTeeVersion / addAllowedTeeMachineOwners                      - extension owner (direct)
 * - OperationFeesFacet.setOperationFees TEE_ORACLE rows           - Flare governance (timelocked)
 *   NOTE: until the fee rows are executed, the default fee applies
 * - FtsoV2.addCustomFeeds([feed stores])                          - Flare governance (timelocked)
 * - sender.setEndpoints / setAdmins per feed + claim-back address
 *                                                                  - Flare governance (timelocked)
 *   NOTE: no machines are named - the call resolves the extension's active set itself and
 *   dispatches to it. The EXECUTOR MUST ATTACH THE INSTRUCTION FEE to executeGovernanceCall.
 *   THE VERSION IS DERIVED AT EXECUTION TIME as the feed's next consecutive one for that kind.
 *   ORDERING IS THEREFORE A GOVERNANCE RESPONSIBILITY, as it is for every other timelocked setter:
 *   a call is keyed by the hash of its whole calldata, so two publications for one feed and kind
 *   can be pending at once, and the one EXECUTED LAST takes the higher version and becomes the
 *   feed's configuration - even if it was proposed first. A pending call that a later proposal
 *   SUPERSEDES must therefore be CANCELLED (cancelGovernanceCall), not left queued; the worst case
 *   of leaving it is a removed administrator re-authorised by the older publication landing last.
 *   Only whitelisted executors can execute a matured call, so that ordering is under the same
 *   operational control as the proposals themselves.
 *   TOOLING should display ALL pending calls per feed and kind, and refuse to schedule a second
 *   publication for the same feed and kind by default.
 *   The publication stores only the payload's HASH and emits the published EndpointGroup[] /
 *   AdminRole[] in EndpointsPublished / AdminsPublished. KEEP THAT LOG: it is the only record of
 *   the configuration, and the push step below takes exactly what it carries. An indexer, an
 *   archive query or simply the execution receipt all work; if it is lost, governance must
 *   republish.
 *   The claim-back argument is the dispatched instruction's PAYER OF RECORD - emitted in
 *   TeeInstructionsSent for the off-chain reward calculation, with no on-chain claim attached; it
 *   must be non-zero (ZeroClaimBackAddress). Pre-production, when governance calls execute
 *   immediately, that is the caller itself - the deployer / initial governance address below.
 *   For a PRODUCTION timelocked publication governance must name THE WALLET THAT WILL FUND THE
 *   EXECUTION: the executed body's msg.sender is the sender contract and FlareGovernance does
 *   not record who called executeGovernanceCall, so the payer cannot be identified on chain.
 *   Freezing that address at proposal time is safe - unlike a machine list it cannot make the
 *   execution revert; if the named wallet is retired in the meantime, cancel and re-propose.
 *   Size it with sender.getEndpointsPublicationFee() / getAdminsPublicationFee(), read in the
 *   block the execution lands in (NOT get*PushTargets - a fresh version targets every eligible
 *   machine, including those at the current latest version). Recording the timelocked call must
 *   still send NO value.
 *   READ THE VIEW IN THE BLOCK THE EXECUTION LANDS IN. The sender applies no fee rule of its own:
 *   it forwards the whole msg.value and the diamond enforces only a FLOOR (FeeTooLow), then hands
 *   the entire value to RewardManager.receiveRewards in the same transaction, holding no balance.
 *   So too little REVERTS and is retryable, while whatever IS attached is distributed as that
 *   epoch's rewards - no per-instruction accounting, no on-chain claim method, and nothing on
 *   chain separating fee from surplus. The claim-back address and the full value are only
 *   RECORDED in TeeInstructionsSent; what the OFF-CHAIN reward calculation does with a surplus, or
 *   with the value of an instruction that never executed, is its own policy decision and is not
 *   controlled here. A value quoted for a fleet that shrank in the meantime - a machine paused or
 *   suspended, or a changed fee row - therefore overpays rather than reverting.
 *   A short fee, an unset/wrong FlareTeeManager or a lost instructions-sender registration
 *   REVERT the execution; that is retryable - executeGovernanceCall's revert rolls back its own
 *   deletion of the timelock entry, so just re-execute with the right fee, no re-proposal.
 *   The dispatch is skipped (and the values published anyway) ONLY when the extension is
 *   emergency paused or its active set is empty. In those two cases attach NO value - no
 *   instruction is created at all, so the call reverts ValueNotNeeded - and use the push step below
 *   to deliver the configuration. get*PublicationFee reports no machines and no fee in both
 *   cases, which is exactly that signal (the get*PushTargets views, by contrast, are NOT
 *   pause-aware and keep reporting who is behind - check the pause state separately).
 * - store.setSubmissionPolicy(SubmissionPolicy{requiredSignatures, maxSpreadBIPS,
 *   maxSpreadAbsolute})                                           - Flare governance (timelocked)
 *   NOTE: only needed to CHANGE the policy after deployment - the initial one comes from the
 *   feed's chain-config entry (requiredSignatures / maxSpreadBIPS / maxSpreadAbsolute) and is set
 *   in the store's initializer. Raise the threshold once the fleet actually has that many
 *   PRODUCTION machines running the feed's latest published configuration: nothing on chain can
 *   check that, and a threshold above it silently stops the feed from updating.
 * - sender.pushEndpoints / pushAdmins per feed                    - ANYONE (pays the fee)
 *   NOTE: needed for machines registered after a publication, for a publication whose dispatch
 *   was skipped, and to retry an instruction that never reached its enclave.
 *   A KEEPER NEEDS THE CONFIGURATION VALUES, passed as the third argument (EndpointGroup[] /
 *   AdminRole[]): they are the `groups` / `roles` field of the feed's latest EndpointsPublished /
 *   AdminsPublished event, passed straight through. The contract re-encodes them with the
 *   version it holds in storage and requires the hash to match, else WrongConfigPayload - so the
 *   values of a superseded publication are refused and no version is ever supplied by the caller.
 *   The list is dispatched AS GIVEN and a target the push cannot deliver to REVERTS the whole
 *   call (empty / zero / duplicate id, foreign extension; a non-PRODUCTION target is refused by
 *   the diamond with TeeMachineNotAvailable). A keeper therefore builds the list from
 *   getEndpointsPushTargets / getAdminsPushTargets and prices it with the diamond's
 *   calculateFeeByTeeIds(TEE_ORACLE, SET_ENDPOINTS|SET_ADMINS, teeIds).
 */
contract DeployTeeOracle is Script {
    using stdJson for string;

    struct DeployedContract {
        address addr;
        string contractName;
        string name;
    }

    struct FeedParams {
        string registryName;
        bytes21 feedId;
        uint8 requiredSignatures;
        uint16 maxSpreadBIPS;
        uint64 maxSpreadAbsolute;
    }

    // Well-known FlareContractRegistry address (same on all Flare networks)
    IFlareContractRegistry private constant FLARE_CONTRACT_REGISTRY =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);

    address private deployer;
    address private governanceSettings;
    address private addressUpdater;
    address private flareTeeManager;
    address private fdc2Verification;
    address private feeCalculator;

    string private config;

    uint256 private extensionId;
    address private feeDestination;
    FeedParams[] private feeds;

    TeeOracleInstructionsSender private sender;
    TeeOracleFeedStore[] private feedStores;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        string memory network = _resolveNetwork();
        console2.log(string.concat("NETWORK: ", network));
        config = vm.readFile(
            string.concat("deployment/chain-config/", network, ".json"));
        _readParams();
        _readDeployedAddresses(network);

        vm.startBroadcast();
        _deployInstructionsSender();
        _deployFeedStores();
        _wireInstructionsSender();
        _wireFeedStores();
        sender.switchToProductionMode();
        for (uint256 i = 0; i < feedStores.length; i++) {
            feedStores[i].switchToProductionMode();
        }
        vm.stopBroadcast();

        _logManualSteps();
    }

    // =========================================================================
    // Parameters
    // =========================================================================

    function _readParams() internal {
        extensionId = vm.parseJsonUint(config, ".teeOracleExtensionId");
        require(extensionId != 0, "extension id must not be zero");
        feeDestination =
            vm.parseJsonAddress(config, ".teeOracleFeeDestinationAddress");
        require(feeDestination != address(0), "fee destination not set");

        for (
            uint256 i = 0;
            vm.keyExistsJson(
                config,
                string.concat(".teeOracleFeeds[", vm.toString(i), "]")
            );
            i++
        ) {
            string memory base =
                string.concat(".teeOracleFeeds[", vm.toString(i), "]");
            string memory registryName =
                vm.parseJsonString(config, string.concat(base, ".registryName"));
            uint256 category =
                vm.parseJsonUint(config, string.concat(base, ".feedCategory"));
            string memory feedName =
                vm.parseJsonString(config, string.concat(base, ".feedName"));

            require(bytes(registryName).length > 0, "empty registry name");
            require(
                category >= 0x20 && category < 0x40, "invalid feed category"
            );
            bytes memory nameBytes = bytes(feedName);
            require(
                nameBytes.length > 0 && nameBytes.length <= 20,
                "invalid feed name length"
            );

            uint256 requiredSignatures = vm.parseJsonUint(
                config, string.concat(base, ".requiredSignatures"));
            uint256 maxSpreadBIPS =
                vm.parseJsonUint(config, string.concat(base, ".maxSpreadBIPS"));
            uint256 maxSpreadAbsolute = vm.parseJsonUint(
                config, string.concat(base, ".maxSpreadAbsolute"));

            // mirrors the store's own InvalidSubmissionPolicy check, so a bad parameter fails
            // before anything is broadcast
            require(
                requiredSignatures != 0 && requiredSignatures <= 32,
                "requiredSignatures out of range"
            );
            require(maxSpreadBIPS <= 10000, "maxSpreadBIPS above 100%");
            require(
                maxSpreadAbsolute <= type(uint64).max, "maxSpreadAbsolute too large"
            );
            if (requiredSignatures > 1) {
                // the store cannot check this: a threshold above the number of PRODUCTION
                // machines running the feed's published configuration silently stops the feed
                console2.log(string.concat(
                    "WARNING: ", registryName, " requires ",
                    vm.toString(requiredSignatures),
                    " signatures - the fleet must already have that many PRODUCTION machines "
                    "at the feed's latest published configuration"
                ));
            }

            feeds.push(FeedParams({
                registryName: registryName,
                feedId: bytes21(
                    bytes.concat(bytes1(uint8(category)), nameBytes)),
                requiredSignatures: uint8(requiredSignatures),
                maxSpreadBIPS: uint16(maxSpreadBIPS),
                maxSpreadAbsolute: uint64(maxSpreadAbsolute)
            }));
        }
        require(feeds.length > 0, "no feeds configured");
    }

    // =========================================================================
    // Pre-deployed addresses
    // =========================================================================

    function _readDeployedAddresses(string memory _network) internal {
        if (_isScdev(_network)) {
            _readDeployedAddressesFromJson(_network);
        } else {
            _readDeployedAddressesFromRegistry();
        }
    }

    function _readDeployedAddressesFromRegistry() internal {
        string[] memory names = new string[](5);
        names[0] = "GovernanceSettings";
        names[1] = "AddressUpdater";
        names[2] = "FlareTeeManager";
        names[3] = "Fdc2Verification";
        names[4] = "FeeCalculator";
        address[] memory addrs =
            FLARE_CONTRACT_REGISTRY.getContractAddressesByName(names);

        governanceSettings = addrs[0];
        addressUpdater = addrs[1];
        flareTeeManager = addrs[2];
        fdc2Verification = addrs[3];
        feeCalculator = addrs[4];
    }

    function _readDeployedAddressesFromJson(
        string memory _network
    )
        internal
    {
        string memory deploysFile =
            string.concat("deployment/deploys/", _network, ".json");
        string memory deploys = vm.readFile(deploysFile);
        DeployedContract[] memory contracts =
            abi.decode(vm.parseJson(deploys), (DeployedContract[]));

        governanceSettings =
            _findDeployedAddress(contracts, "GovernanceSettings");
        addressUpdater = _findDeployedAddress(contracts, "AddressUpdater");
        flareTeeManager = _findDeployedAddress(contracts, "FlareTeeManager");
        fdc2Verification =
            _findDeployedAddress(contracts, "Fdc2Verification");
        feeCalculator = _findDeployedAddress(contracts, "FeeCalculator");
    }

    function _findDeployedAddress(
        DeployedContract[] memory _contracts,
        string memory _name
    )
        internal pure
        returns (address)
    {
        bytes32 nameHash = keccak256(bytes(_name));
        for (uint256 i = 0; i < _contracts.length; i++) {
            if (keccak256(bytes(_contracts[i].name)) == nameHash) {
                return _contracts[i].addr;
            }
        }
        return address(0);
    }

    // =========================================================================
    // Deployment
    // =========================================================================

    function _deployInstructionsSender() internal {
        TeeOracleInstructionsSender impl = new TeeOracleInstructionsSender();
        _logDeployed(
            "TeeOracleInstructionsSenderImplementation",
            "TeeOracleInstructionsSender",
            address(impl)
        );
        // deployer acts as initial governance and address updater; the wiring call
        // below hands the updater role to the real AddressUpdater and
        // switchToProductionMode() hands governance to GovernanceSettings
        TeeOracleInstructionsSenderProxy proxy =
            new TeeOracleInstructionsSenderProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                extensionId,
                address(impl)
            );
        sender = TeeOracleInstructionsSender(address(proxy));
        _logDeployed(
            "TeeOracleInstructionsSender",
            "TeeOracleInstructionsSender",
            address(proxy)
        );
    }

    function _deployFeedStores() internal {
        // one implementation shared by all feed store proxies
        TeeOracleFeedStore impl = new TeeOracleFeedStore();
        _logDeployed(
            "TeeOracleFeedStoreImplementation",
            "TeeOracleFeedStore",
            address(impl)
        );

        for (uint256 i = 0; i < feeds.length; i++) {
            FeedParams memory feed = feeds[i];
            TeeOracleFeedStoreProxy proxy = new TeeOracleFeedStoreProxy(
                IGovernanceSettings(governanceSettings),
                deployer,
                deployer,
                ITeeOracleInstructionsSender(address(sender)),
                feed.feedId,
                feeDestination,
                ITeeOracleFeedStore.SubmissionPolicy({
                    requiredSignatures: feed.requiredSignatures,
                    maxSpreadBIPS: feed.maxSpreadBIPS,
                    maxSpreadAbsolute: feed.maxSpreadAbsolute
                }),
                address(impl)
            );
            feedStores.push(TeeOracleFeedStore(address(proxy)));
            _logDeployed(
                feed.registryName, "TeeOracleFeedStore", address(proxy)
            );
        }
    }

    // =========================================================================
    // Wiring
    // =========================================================================

    function _wireInstructionsSender() internal {
        bytes32[] memory names = new bytes32[](2);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("FlareTeeManager");
        address[] memory addrs = new address[](2);
        addrs[0] = addressUpdater;
        addrs[1] = flareTeeManager;
        sender.updateContractAddresses(names, addrs);
    }

    function _wireFeedStores() internal {
        bytes32[] memory names = new bytes32[](3);
        names[0] = _encodeContractName("AddressUpdater");
        names[1] = _encodeContractName("Fdc2Verification");
        names[2] = _encodeContractName("FeeCalculator");
        address[] memory addrs = new address[](3);
        addrs[0] = addressUpdater;
        addrs[1] = fdc2Verification;
        addrs[2] = feeCalculator;
        for (uint256 i = 0; i < feedStores.length; i++) {
            feedStores[i].updateContractAddresses(names, addrs);
        }
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _resolveNetwork()
        internal view
        returns (string memory)
    {
        uint256 chainId = block.chainid;
        if (chainId == 14) return "flare";
        if (chainId == 19) return "songbird";
        if (chainId == 16) return "coston";
        if (chainId == 114) return "coston2";
        return "scdev";
    }

    function _isScdev(string memory _network)
        internal pure
        returns (bool)
    {
        return keccak256(bytes(_network)) == keccak256(bytes("scdev"));
    }

    function _encodeContractName(
        string memory _name
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_name));
    }

    function _logDeployed(
        string memory _name,
        string memory _contractName,
        address _addr
    )
        internal pure
    {
        console2.log(
            string.concat(
                "DEPLOYED: ", _name, ", ", _contractName, ": ",
                vm.toString(_addr)
            )
        );
    }

    function _logManualSteps() internal view {
        console2.log("");
        console2.log("Manual follow-up steps (governance / extension owner):");
        console2.log(string.concat(
            "1. governance: FlareTeeManager.registerReserved(",
            vm.toString(extensionId), ", <extension owner>)"
        ));
        console2.log(string.concat(
            "2. extension owner: FlareTeeManager.setExtensionContracts(",
            vm.toString(extensionId), ", 0x0, ",
            vm.toString(address(sender)), ")"
        ));
        console2.log(
            "3. extension owner: addTeeVersion / addAllowedTeeMachineOwners"
        );
        for (uint256 i = 0; i < feedStores.length; i++) {
            console2.log(string.concat(
                "4. governance: FtsoV2.addCustomFeeds([",
                vm.toString(address(feedStores[i])), "]) // ",
                feeds[i].registryName
            ));
        }
        console2.log(
            "5. governance: sender.setEndpoints / setAdmins per feed "
            "(no machines named; the EXECUTOR ATTACHES THE FEE from "
            "sender.getEndpointsPublicationFee() / getAdminsPublicationFee(), READ IN THE BLOCK "
            "THE EXECUTION LANDS IN, to executeGovernanceCall - too little reverts in the diamond "
            "(FeeTooLow) and is retryable, and whatever is attached joins that epoch's rewards in "
            "full, with no on-chain claim; recording "
            "must send no value; attach nothing if that view reports an empty machine list or the "
            "extension is paused)"
        );
        console2.log(
            "   VERSION: derived when the call EXECUTES, as the feed's next consecutive one for "
            "that kind. Two publications for one feed can be pending at once and the one executed "
            "LAST wins, whichever was proposed first"
        );
        console2.log(
            "   CANCEL a superseded pending call (cancelGovernanceCall) instead of leaving it "
            "queued - otherwise the older publication can land last and become the feed's "
            "configuration. Tooling should show ALL pending calls per feed and kind"
        );
        console2.log(
            "   claim-back address argument (non-zero) - the instruction's payer of record, "
            "emitted for the off-chain reward calculation: pre-production the caller itself,",
            deployer
        );
        console2.log(
            "   in production name the wallet that will FUND the executeGovernanceCall - the "
            "payer cannot be identified on chain"
        );
        console2.log(
            "   the publication stores only the payload HASH and logs the published groups / roles "
            "in EndpointsPublished / AdminsPublished - KEEP THAT LOG, the push below needs them"
        );
        for (uint256 i = 0; i < feedStores.length; i++) {
            console2.log(string.concat(
                "   ", feeds[i].registryName, " submission policy: requiredSignatures=",
                vm.toString(uint256(feeds[i].requiredSignatures)),
                ", maxSpreadBIPS=", vm.toString(uint256(feeds[i].maxSpreadBIPS)),
                ", maxSpreadAbsolute=",
                vm.toString(uint256(feeds[i].maxSpreadAbsolute)),
                " (change later with governance setSubmissionPolicy; raise the threshold only "
                "once the fleet has that many PRODUCTION machines at the latest configuration)"
            ));
        }
        console2.log(
            "6. anyone: sender.pushEndpoints / pushAdmins per feed "
            "(for machines added later or a skipped dispatch - build the list from "
            "get*PushTargets; the push dispatches it as given and REVERTS on a target it cannot "
            "deliver to, and the diamond's calculateFeeByTeeIds prices it)"
        );
        console2.log(
            "   the push also takes the CONFIGURATION VALUES (EndpointGroup[] / AdminRole[]), taken "
            "verbatim from groups / roles in the feed's latest publication event; the "
            "contract re-encodes them with the stored version and checks the hash "
            "(WrongConfigPayload)"
        );
    }
}
