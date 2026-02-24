// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IFlareContractRegistry } from "flare-smart-contracts/contracts/userInterfaces/IFlareContractRegistry.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { GovernedProxyImplementation } from "../../governance/implementation/GovernedProxyImplementation.sol";
import { GovernedBase } from "../../governance/implementation/GovernedBase.sol";
import { AggregatorV3Interface } from "../interface/AggregatorV3Interface.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

interface IFtsoV2View {
    /**
     * Returns value in wei and timestamp of a feed.
     * @param _feedId The id of the feed.
     * @return _value The value for the requested feed in wei (i.e. with 18 decimal places).
     * @return _timestamp The timestamp of the last update.
     */
    function getFeedByIdInWei(bytes21 _feedId) external view returns (uint256 _value, uint64 _timestamp);
}

/**
 * @title ChainlinkAdapter
 * @notice Adapter contract to expose FtsoV2 feed data through Chainlink AggregatorV3Interface.
 */
contract ChainlinkAdapter is AggregatorV3Interface, UUPSUpgradeable, GovernedProxyImplementation {

    //solhint-disable const-name-snakecase
    IFlareContractRegistry internal constant flareContractRegistry =
        IFlareContractRegistry(0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019);

    /// @inheritdoc AggregatorV3Interface
    uint8 constant public decimals = 18;
    /// @notice FTSO feed id
    bytes21 public ftsoFeedId;
    /// @notice Stale time for the feed data
    uint64 public staleTimeSeconds;
    /// @inheritdoc AggregatorV3Interface
    string public description;
    /// @inheritdoc AggregatorV3Interface
    uint256 public version;

    /**
     * @notice Emitted when stale time is set
     * @param staleTimeSeconds The new stale time in seconds
     */
    event StaleTimeSecondsSet(uint64 staleTimeSeconds);

    /// @notice Error thrown when no data is present
    error NoDataPresent();
    /// @notice Error thrown when data is stale
    error StaleData();
    /// @notice Error thrown when a function is not implemented
    error NotImplemented();

    /**
     * @notice Constructor.
     */
    constructor() GovernedProxyImplementation() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        bytes21 _ftsoFeedId,
        uint64 _staleTimeSeconds,
        string memory _description
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        ftsoFeedId = _ftsoFeedId;
        staleTimeSeconds = _staleTimeSeconds;
        description = _description;
        version = 2; // FTSO v2

        emit StaleTimeSecondsSet(_staleTimeSeconds);
    }

    /// @inheritdoc AggregatorV3Interface
    function latestRoundData()
        external view
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        IFtsoV2View ftsoV2 = IFtsoV2View(
            flareContractRegistry.getContractAddressByHash(keccak256(abi.encode("FtsoV2")))
        );
        (uint256 value, uint64 timestamp) = ftsoV2.getFeedByIdInWei(ftsoFeedId);

        require(timestamp != 0, NoDataPresent());
        // timestamp <= block.timestamp
        require(staleTimeSeconds == 0 || block.timestamp - timestamp < staleTimeSeconds, StaleData());

        _roundId = timestamp;
        _answer = int256(value);
        _startedAt = timestamp;
        _updatedAt = timestamp;
        _answeredInRound = timestamp;
    }

    /// @inheritdoc AggregatorV3Interface
    function getRoundData(uint80)
        external pure
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert NotImplemented();
    }

    /////////////////////////////// GOVERNANCE ///////////////////////////////

    /**
     * @notice Sets the stale time for the feed data.
     * @param _staleTimeSeconds The new stale time in seconds.
     * @dev Only governance can call this method.
     */
    function setStaleTimeSeconds(uint64 _staleTimeSeconds)
        external
        onlyGovernance
    {
        staleTimeSeconds = _staleTimeSeconds;
        emit StaleTimeSecondsSet(_staleTimeSeconds);
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address _newImplementation, bytes memory _data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(_newImplementation, _data);
    }

    /**
     * @notice Returns the address of the current implementation.
     * @return The address of the current implementation.
     */
    function implementation()
        external view
        returns (address)
    {
        return ERC1967Utils.getImplementation();
    }

    /**
     * Unused. Only present to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}
}
