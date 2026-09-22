// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ITeeRewardOffersManager } from "../../userInterfaces/tee/ITeeRewardOffersManager.sol";
import { RewardOffersManagerProxyBase } from "../../protocol/implementation/RewardOffersManagerProxyBase.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeeRewardOffersManager contract.
 *
 * This contract is used to manage the TEE reward offers and receive the inflation.
 * It is used by the Flare system to trigger the reward offers.
 */
contract TeeRewardOffersManager is RewardOffersManagerProxyBase, ITeeRewardOffersManager {

    uint256 internal constant PPM_MAX = 1e6;

    /// Part of the rewards that goes to the TEE owners.
    uint24 public teeOwnersPPM;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() RewardOffersManagerProxyBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint24 _teeOwnersPPM
    )
        external virtual
        initializer
    {
        initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
        _setTeeOwnersPPM(_teeOwnersPPM);
    }

    /**
     * Set the part of the rewards that goes to the TEE owners.
     * @param _teeOwnersPPM The part of the rewards that goes to the TEE owners.
     */
    function setTeeOwnersPPM(
        uint24 _teeOwnersPPM
    )
        external
        onlyGovernance
    {
        _setTeeOwnersPPM(_teeOwnersPPM);
    }

    /**
     * Implement this function to allow updating inflation receiver contracts through `AddressUpdater`.
     * @return Contract name.
     */
    function getContractName()
        external pure
        returns (string memory)
    {
        return "TeeRewardOffersManager";
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
        emit InflationRewardsOffered(_nextRewardEpochId, _amount, teeOwnersPPM);
    }

    function _setTeeOwnersPPM(
        uint24 _teeOwnersPPM
    )
        internal
    {
        require(_teeOwnersPPM <= PPM_MAX, InvalidTeeOwnersPPMValue());
        teeOwnersPPM = _teeOwnersPPM;
        emit TeeOwnersPPMSet(_teeOwnersPPM);
    }
}
