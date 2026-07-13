// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { IIAddressValidator } from "../interface/IIAddressValidator.sol";
import { IAddressValidator } from "../../userInterfaces/tee/IAddressValidator.sol";
import { BitcoinAddress } from "../library/BitcoinAddress.sol";
import { DogecoinAddress } from "../library/DogecoinAddress.sol";
import { EvmAddress } from "../library/EvmAddress.sol";
import { XrplAddress } from "../library/XrplAddress.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Validates external-chain payout addresses on-chain, dispatched by a governance-configured
 * per-source `{chainKind, network}` profile. See {IAddressValidator}.
 */
contract AddressValidator is IIAddressValidator, FlareUpgradeableBase {

    struct Profile {
        ChainKind chainKind;
        Network network;
        bool configured;
    }

    mapping(bytes32 sourceId => Profile) internal sourceProfiles;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc IIAddressValidator
     */
    function setSourceConfigs(
        SourceConfig[] calldata _configs
    )
        external
        onlyGovernance
    {
        require(_configs.length > 0, EmptyArray());
        for (uint256 i = 0; i < _configs.length; i++) {
            SourceConfig calldata config = _configs[i];
            sourceProfiles[config.sourceId] = Profile(config.chainKind, config.network, true);
            emit SourceConfigSet(config.sourceId, config.chainKind, config.network);
        }
    }

    /**
     * @inheritdoc IAddressValidator
     */
    function isValidAddress(
        bytes32 _sourceId,
        string calldata _address
    )
        external view
        returns (bool _valid)
    {
        Profile storage profile = sourceProfiles[_sourceId];
        if (!profile.configured) {
            return false; // fail-closed: unconfigured sources never validate
        }
        ChainKind kind = profile.chainKind;
        if (kind == ChainKind.Bitcoin) {
            return BitcoinAddress.isValid(_address, BitcoinAddress.Network(uint8(profile.network)));
        }
        if (kind == ChainKind.Dogecoin) {
            // Dogecoin has only mainnet/testnet (regtest, if ever configured, maps to testnet).
            return DogecoinAddress.isValid(_address, profile.network != Network.Mainnet);
        }
        if (kind == ChainKind.Xrpl) {
            // X-addresses carry the network (X = mainnet, T = testnet), enforced here; classic
            // r-addresses carry no network and are accepted for either. XRPL has no regtest.
            return XrplAddress.isValid(_address, profile.network != Network.Mainnet);
        }
        if (kind == ChainKind.Evm) {
            // EVM addresses are chain-agnostic; network is not enforced for EVM.
            return EvmAddress.isValid(_address);
        }
        return false;
    }

    /**
     * @inheritdoc IAddressValidator
     */
    function getSourceConfig(
        bytes32 _sourceId
    )
        external view
        returns (
            ChainKind _chainKind,
            Network _network,
            bool _configured
        )
    {
        Profile storage profile = sourceProfiles[_sourceId];
        return (profile.chainKind, profile.network, profile.configured);
    }

    /**
     * AddressValidator has no external contract dependencies.
     */
    function _updateContractAddresses(
        bytes32[] memory /* _contractNameHashes */,
        address[] memory /* _contractAddresses */
    )
        internal override
    {
    }
}
