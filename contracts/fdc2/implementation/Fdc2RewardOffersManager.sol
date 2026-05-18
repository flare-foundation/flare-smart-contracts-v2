// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IFdc2RewardOffersManager } from "../../userInterfaces/fdc2/IFdc2RewardOffersManager.sol";
import { IFdc2InflationConfigurations } from "../../userInterfaces/fdc2/IFdc2InflationConfigurations.sol";
import { RewardOffersManagerProxyBase } from "../../protocol/implementation/RewardOffersManagerProxyBase.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * Fdc2RewardOffersManager contract.
 *
 * This contract is used to manage the FDC2 reward offers and receive the inflation.
 * It is triggered by the Flare systems manager to emit the inflation reward offers.
 */
contract Fdc2RewardOffersManager is RewardOffersManagerProxyBase, IFdc2RewardOffersManager {

    /// The FDC2 inflation configurations contract.
    IFdc2InflationConfigurations public fdc2InflationConfigurations;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() RewardOffersManagerProxyBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
    {
        initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * Implement this function to allow updating inflation receiver contracts through `AddressUpdater`.
     * @return Contract name.
     */
    function getContractName()
        external pure
        returns (string memory)
    {
        return "Fdc2RewardOffersManager";
    }

    /**
     * @inheritdoc RewardOffersManagerProxyBase
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        super._updateContractAddresses(_contractNameHashes, _contractAddresses);
        fdc2InflationConfigurations = IFdc2InflationConfigurations(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Fdc2InflationConfigurations"));
    }

    /**
     * @inheritdoc RewardOffersManagerProxyBase
     */
    function _emitInflationRewardsOffered(
        uint24 _nextRewardEpochId,
        uint256 _amount
    )
        internal override
    {
        emit InflationRewardsOffered(
            _nextRewardEpochId,
            fdc2InflationConfigurations.getFdc2Configurations(),
            _amount
        );
    }
}
