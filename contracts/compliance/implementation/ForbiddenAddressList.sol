// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { FlareGovernance } from "../../governance/lib/FlareGovernance.sol";
import { IIForbiddenAddressList } from "../interface/IIForbiddenAddressList.sol";
import { IForbiddenAddressList } from "../../userInterfaces/IForbiddenAddressList.sol";
import { IPersonalAccountProvider } from "../../userInterfaces/IPersonalAccountProvider.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { BtcAddress } from "../../utils/lib/BtcAddress.sol";
import { XrpAddress } from "../../utils/lib/XrpAddress.sol";
import { SourceIds } from "../../utils/lib/SourceIds.sol";
import { IExternalNetwork } from "../../userInterfaces/IExternalNetwork.sol";

/**
 * ForbiddenAddressList contract — the governed lists of addresses value may not be accepted from or paid to: one per
 * non-EVM source, of address strings, and one EVM list for every EVM chain (see `IForbiddenAddressList`).
 *
 * Each source's list keeps two parallel arrays — the hash and the address string at the same index — and a mapping
 * from hash to index (plus one), which gives the membership check in one read and finds an entry to remove; the last
 * entry takes the removed one's place. The EVM list is an `EnumerableSet.AddressSet`, the same layout for `address`
 * values. Every list's version, raised by every call that changes it, lets a reader that pages through it know that
 * every page came from the same list.
 */
contract ForbiddenAddressList is IIForbiddenAddressList, FlareUpgradeableBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// One source's list.
    struct SourceList {
        /// The address hashes, `keccak256(bytes(address))`, at the indices of `addresses`.
        bytes32[] hashes;
        /// The addresses as they were added, at the indices of `hashes`.
        string[] addresses;
        /// The index of an address hash in `hashes` plus one; zero: not on the list.
        mapping(bytes32 addressHash => uint256 indexPlusOne) indexOf;
        /// The list's version, raised by every call that changes it, and the block timestamp of the last call that
        /// added an address, in one slot.
        uint64 version;
        uint64 lastAddedAt;
    }

    /// The chains the list holds string lists for, by their mainnet source id (a test network's adds `test`).
    bytes32 internal constant BTC = "BTC";
    bytes32 internal constant XRP = "XRP";

    /// The lists, by FDC source id.
    mapping(bytes32 sourceId => SourceList) private lists;
    /// The maintainers, the addresses besides governance that may add addresses to any list.
    EnumerableSet.AddressSet private maintainers;
    /// The EVM list, one for every EVM chain.
    EnumerableSet.AddressSet private evmAddresses;
    /// The EVM list's version, raised by every call that changes it, and the block timestamp of the last call that
    /// added an address, in one slot.
    uint64 private evmVersion;
    uint64 private evmLastAddedAt;
    /// The external network this deployment serves.
    IExternalNetwork.Network private network;
    /// The personal account provider of each source (zero: none).
    mapping(bytes32 sourceId => address) private personalAccountProviders;

    /**
     * Only a maintainer, or governance without timelock (as `onlyImmediateGovernance`), adds addresses.
     */
    modifier onlyMaintainerOrImmediateGovernance() {
        require(
            maintainers.contains(msg.sender) || msg.sender == FlareGovernance.governance(),
            OnlyMaintainerOrImmediateGovernance()
        );
        _;
    }

    /**
     * Only a source the list holds a string list under.
     */
    modifier onlySupportedSource(bytes32 _sourceId) {
        require(_isSupported(_sourceId), UnsupportedSourceId(_sourceId));
        _;
    }

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        IExternalNetwork.Network _network
    )
        external
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        network = _network;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function addForbiddenAddresses(
        bytes32 _sourceId,
        string[] calldata _addresses
    )
        external
        onlyMaintainerOrImmediateGovernance
        onlySupportedSource(_sourceId)
    {
        SourceList storage list = lists[_sourceId];
        address provider = personalAccountProviders[_sourceId];
        bool added;
        bool evmAdded;
        for (uint256 i = 0; i < _addresses.length; i++) {
            string calldata forbiddenAddress = _addresses[i];
            require(_isCanonical(_sourceId, forbiddenAddress), NonCanonicalAddress(_sourceId, forbiddenAddress));
            bytes32 addressHash = keccak256(bytes(forbiddenAddress));
            if (list.indexOf[addressHash] != 0) {
                continue;     // a repeat is skipped with its derivation
            }
            list.hashes.push(addressHash);
            list.addresses.push(forbiddenAddress);
            list.indexOf[addressHash] = list.hashes.length;
            added = true;
            emit ForbiddenAddressAdded(_sourceId, forbiddenAddress);
            if (provider != address(0) && _listPersonalAccount(_sourceId, provider, forbiddenAddress)) {
                evmAdded = true;
            }
        }
        if (added) {
            list.version += 1;
            list.lastAddedAt = uint64(block.timestamp);
            emit ListVersionChanged(_sourceId, list.version);
        }
        if (evmAdded) {
            evmVersion += 1;
            evmLastAddedAt = uint64(block.timestamp);
            emit EvmListVersionChanged(evmVersion);
        }
    }

    /**
     * @inheritdoc IIForbiddenAddressList
     */
    function removeForbiddenAddresses(
        bytes32 _sourceId,
        string[] calldata _addresses
    )
        external
        onlyGovernance
        onlySupportedSource(_sourceId)
    {
        SourceList storage list = lists[_sourceId];
        bool removed;
        for (uint256 i = 0; i < _addresses.length; i++) {
            bytes32 addressHash = keccak256(bytes(_addresses[i]));
            uint256 indexPlusOne = list.indexOf[addressHash];
            if (indexPlusOne == 0) {
                continue;
            }
            uint256 last = list.hashes.length - 1;
            if (indexPlusOne - 1 != last) {
                bytes32 movedHash = list.hashes[last];
                list.hashes[indexPlusOne - 1] = movedHash;
                list.addresses[indexPlusOne - 1] = list.addresses[last];
                list.indexOf[movedHash] = indexPlusOne;
            }
            list.hashes.pop();
            list.addresses.pop();
            delete list.indexOf[addressHash];
            removed = true;
            emit ForbiddenAddressRemoved(_sourceId, _addresses[i]);
        }
        if (removed) {
            list.version += 1;
            emit ListVersionChanged(_sourceId, list.version);
        }
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function addForbiddenEvmAddresses(
        address[] calldata _addresses
    )
        external
        onlyMaintainerOrImmediateGovernance
    {
        bool added;
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0), EvmAddressZero());
            if (evmAddresses.add(_addresses[i])) {
                added = true;
                emit ForbiddenEvmAddressAdded(_addresses[i]);
            }
        }
        if (added) {
            evmVersion += 1;
            evmLastAddedAt = uint64(block.timestamp);
            emit EvmListVersionChanged(evmVersion);
        }
    }

    /**
     * @inheritdoc IIForbiddenAddressList
     */
    function removeForbiddenEvmAddresses(
        address[] calldata _addresses
    )
        external
        onlyGovernance
    {
        bool removed;
        for (uint256 i = 0; i < _addresses.length; i++) {
            if (evmAddresses.remove(_addresses[i])) {
                removed = true;
                emit ForbiddenEvmAddressRemoved(_addresses[i]);
            }
        }
        if (removed) {
            evmVersion += 1;
            emit EvmListVersionChanged(evmVersion);
        }
    }

    /**
     * @inheritdoc IIForbiddenAddressList
     */
    function setPersonalAccountProvider(
        bytes32 _sourceId,
        address _provider
    )
        external
        onlyGovernance
        onlySupportedSource(_sourceId)
    {
        require(_provider == address(0) || _provider.code.length > 0, PersonalAccountProviderWithoutCode());
        personalAccountProviders[_sourceId] = _provider;
        emit PersonalAccountProviderSet(_sourceId, _provider);
    }

    /**
     * @inheritdoc IIForbiddenAddressList
     */
    function addMaintainers(
        address[] calldata _maintainers
    )
        external
        onlyGovernance
    {
        for (uint256 i = 0; i < _maintainers.length; i++) {
            require(_maintainers[i] != address(0), MaintainerZero());
            maintainers.add(_maintainers[i]);
        }
        emit MaintainersAdded(_maintainers);
    }

    /**
     * @inheritdoc IIForbiddenAddressList
     */
    function removeMaintainers(
        address[] calldata _maintainers
    )
        external
        onlyImmediateGovernance
    {
        for (uint256 i = 0; i < _maintainers.length; i++) {
            maintainers.remove(_maintainers[i]);
        }
        emit MaintainersRemoved(_maintainers);
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function isForbiddenHash(
        bytes32 _sourceId,
        bytes32 _addressHash
    )
        external view
        onlySupportedSource(_sourceId)
        returns (bool)
    {
        return lists[_sourceId].indexOf[_addressHash] != 0;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function isForbidden(
        bytes32 _sourceId,
        string calldata _address
    )
        external view
        onlySupportedSource(_sourceId)
        returns (bool)
    {
        require(_isCanonical(_sourceId, _address), NonCanonicalAddress(_sourceId, _address));
        return lists[_sourceId].indexOf[keccak256(bytes(_address))] != 0;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function isCanonicalAddress(
        bytes32 _sourceId,
        string calldata _address
    )
        external view
        onlySupportedSource(_sourceId)
        returns (bool)
    {
        return _isCanonical(_sourceId, _address);
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function isForbiddenEvmAddress(
        address _address
    )
        external view
        returns (bool)
    {
        return evmAddresses.contains(_address);
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getForbiddenAddressHashes(
        bytes32 _sourceId,
        uint256 _start,
        uint256 _count
    )
        external view
        onlySupportedSource(_sourceId)
        returns (
            bytes32[] memory _hashes,
            uint256 _totalCount,
            uint64 _version
        )
    {
        SourceList storage list = lists[_sourceId];
        _totalCount = list.hashes.length;
        _version = list.version;
        uint256 end = _pageEnd(_start, _count, _totalCount);
        _hashes = new bytes32[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            _hashes[i - _start] = list.hashes[i];
        }
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getForbiddenAddresses(
        bytes32 _sourceId,
        uint256 _start,
        uint256 _count
    )
        external view
        onlySupportedSource(_sourceId)
        returns (
            string[] memory _addresses,
            uint256 _totalCount,
            uint64 _version
        )
    {
        SourceList storage list = lists[_sourceId];
        _totalCount = list.addresses.length;
        _version = list.version;
        uint256 end = _pageEnd(_start, _count, _totalCount);
        _addresses = new string[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            _addresses[i - _start] = list.addresses[i];
        }
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getForbiddenEvmAddresses(
        uint256 _start,
        uint256 _count
    )
        external view
        returns (
            address[] memory _addresses,
            uint256 _totalCount,
            uint64 _version
        )
    {
        _totalCount = evmAddresses.length();
        _version = evmVersion;
        _addresses = evmAddresses.values(_start, _pageEnd(_start, _count, _totalCount));
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getVersion(
        bytes32 _sourceId
    )
        external view
        onlySupportedSource(_sourceId)
        returns (uint64 _version)
    {
        return lists[_sourceId].version;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function lastAdditionTimestamp(
        bytes32 _sourceId
    )
        external view
        onlySupportedSource(_sourceId)
        returns (uint64)
    {
        return lists[_sourceId].lastAddedAt;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getEvmVersion()
        external view
        returns (uint64 _version)
    {
        return evmVersion;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function lastEvmAdditionTimestamp()
        external view
        returns (uint64)
    {
        return evmLastAddedAt;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getPersonalAccountProvider(
        bytes32 _sourceId
    )
        external view
        onlySupportedSource(_sourceId)
        returns (address)
    {
        return personalAccountProviders[_sourceId];
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getNetwork()
        external view
        returns (IExternalNetwork.Network)
    {
        return network;
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function isMaintainer(
        address _address
    )
        external view
        returns (bool)
    {
        return maintainers.contains(_address);
    }

    /**
     * @inheritdoc IForbiddenAddressList
     */
    function getMaintainers()
        external view
        returns (address[] memory _maintainers)
    {
        return maintainers.values();
    }

    /**
     * The list reads no other contract.
     */
    function _updateContractAddresses(
        bytes32[] memory /* _contractNameHashes */,
        address[] memory /* _contractAddresses */
    )
        internal override
    {}

    /**
     * Lists the Personal Account `_owner` owns, as `_provider` derives it, on the EVM list; returns whether the EVM
     * list gained an address.
     */
    function _listPersonalAccount(
        bytes32 _sourceId,
        address _provider,
        string calldata _owner
    )
        private
        returns (bool _added)
    {
        address personalAccount = IPersonalAccountProvider(_provider).getPersonalAccount(_owner);
        require(personalAccount != address(0), EvmAddressZero());
        _added = evmAddresses.add(personalAccount);
        if (_added) {
            emit ForbiddenEvmAddressAdded(personalAccount);
        }
        emit PersonalAccountDerived(_sourceId, _owner, personalAccount);
    }

    /**
     * The canonical-form rule of a supported source's list (see `isCanonicalAddress`): the address validators, on
     * the deployment's network. `BtcAddress` takes Bech32 in lowercase only. The validators' networks are
     * `IExternalNetwork.Network` in the same order — Mainnet, Testnet, and Regtest for Local — which the tests of
     * the three deployments pin. Every caller is behind `onlySupportedSource`; a chain admitted there without a rule
     * here reverts `UnsupportedSourceId` rather than being validated as another chain.
     */
    function _isCanonical(
        bytes32 _sourceId,
        string calldata _address
    )
        private view
        returns (bool)
    {
        bytes32 chain = SourceIds.mainnetId(_sourceId);
        if (chain == BTC) {
            return BtcAddress.isValid(_address, BtcAddress.Network(uint8(network)));
        }
        if (chain == XRP) {
            return XrpAddress.isValidClassic(_address);
        }
        revert UnsupportedSourceId(_sourceId);
    }

    /**
     * Whether the list holds a string list under `_sourceId`: the id names Bitcoin or XRPL, and the
     * deployment's kind of network (`SourceIds.fitsNetwork`).
     */
    function _isSupported(
        bytes32 _sourceId
    )
        private view
        returns (bool)
    {
        bytes32 chain = SourceIds.mainnetId(_sourceId);
        return (chain == BTC || chain == XRP) && SourceIds.fitsNetwork(_sourceId, network);
    }

    /**
     * The end (exclusive) of a page starting at `_start`: `_start` itself when it is at or past the end.
     */
    function _pageEnd(
        uint256 _start,
        uint256 _count,
        uint256 _totalCount
    )
        private pure
        returns (uint256)
    {
        if (_start >= _totalCount) {
            return _start;
        }
        return _totalCount - _start < _count ? _totalCount : _start + _count;
    }
}
