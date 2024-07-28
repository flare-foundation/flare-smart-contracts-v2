// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../userInterfaces/IRandomProvider.sol";
import "../../utils/implementation/AddressUpdatable.sol";

contract FtsoV2Proxy is IRandomProvider, AddressUpdatable {

    IRandomProvider public submission;

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
        return submission.getCurrentRandom();
    }

    /**
     * @inheritdoc IRandomProvider
     */
    function getCurrentRandomWithQuality() external view returns (uint256, bool) {
        return submission.getCurrentRandomWithQuality();
    }

    /**
     * @inheritdoc IRandomProvider
     */
    function getCurrentRandomWithQualityAndTimestamp() external view returns (uint256, bool, uint256) {
        return submission.getCurrentRandomWithQualityAndTimestamp();
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
        submission = IRandomProvider(_getContractAddress(_contractNameHashes, _contractAddresses, "Submission"));
    }

}