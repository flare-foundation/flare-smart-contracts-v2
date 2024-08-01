// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IRandomProvider.sol";
import "../../utils/implementation/AddressUpdatable.sol";

contract RandomNumberV2 is IRandomProvider, AddressUpdatable {

    IRandomProvider public randomProvider;

    constructor(
        address _addressUpdater
    )
        AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * @inheritdoc IRandomProvider
     */
    function getCurrentRandom() external view returns (uint256) {
        return randomProvider.getCurrentRandom();
    }

    /**
     * @inheritdoc IRandomProvider
     */
    function getCurrentRandomWithQuality() external view returns (uint256, bool) {
        return randomProvider.getCurrentRandomWithQuality();
    }

    /**
     * @inheritdoc IRandomProvider
     */
    function getCurrentRandomWithQualityAndTimestamp() external view returns (uint256, bool, uint256) {
        return randomProvider.getCurrentRandomWithQualityAndTimestamp();
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        randomProvider = IRandomProvider(_getContractAddress(_contractNameHashes, _contractAddresses, "Submission"));
    }

}