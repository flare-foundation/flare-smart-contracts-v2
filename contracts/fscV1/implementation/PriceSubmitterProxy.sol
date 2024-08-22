// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IPriceSubmitter.sol";
import "flare-smart-contracts/contracts/genesis/interface/IFtsoManagerGenesis.sol";
import "flare-smart-contracts/contracts/genesis/interface/IFtsoRegistryGenesis.sol";
import "../../userInterfaces/IRandomProvider.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IRelay.sol";

/**
 * PriceSubmitterProxy is a compatibility contract replacing PriceSubmitter.
 */

contract PriceSubmitterProxy is IPriceSubmitter, AddressUpdatable {

    /// The Relay contract.
    IRelay public relay;
    IFtsoManagerGenesis internal ftsoManager;
    IFtsoRegistryGenesis internal ftsoRegistry;
    address internal voterWhitelister;

    constructor(
        address _addressUpdater
    )
        AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * @inheritdoc IPriceSubmitter
     * @dev Deprecated - reverts
     */
    function submitHash(uint256, bytes32) external {
        revert("not supported");
    }

    /**
     * Submits price hashes for current epoch (Songbird version)
     * @dev Deprecated - reverts
     */
    function submitPriceHashes(uint256, uint256[] memory, bytes32[] memory) external {
        revert("not supported");
    }

    /**
     * @inheritdoc IPriceSubmitter
     * @dev Deprecated - reverts
     */
    function revealPrices(uint256, uint256[] memory, uint256[] memory, uint256) external {
        revert("not supported");
    }

    /**
     * Reveals submitted prices during epoch reveal period (Songbird version)
     * @dev Deprecated - reverts
     */
    function revealPrices(uint256, uint256[] memory, uint256[] memory, uint256[] memory) external {
        revert("not supported");
    }

    /**
     * @inheritdoc IPriceSubmitter
     */
    function getCurrentRandom() external view returns (uint256 _currentRandom) {
        (_currentRandom, , ) = relay.getRandomNumber();
    }

    /**
     * @inheritdoc IPriceSubmitter
     * @dev Deprecated - reverts
     */
    function getRandom(uint256) external view returns (uint256) {
        revert("not supported");
    }

    /**
     * @inheritdoc IPriceSubmitter
     */
    function getFtsoManager() external view override returns (IFtsoManagerGenesis) {
        return ftsoManager;
    }

    /**
     * @inheritdoc IPriceSubmitter
     */
    function getFtsoRegistry() external view override returns (IFtsoRegistryGenesis) {
        return ftsoRegistry;
    }

    /**
     * @inheritdoc IPriceSubmitter
     */
    function getVoterWhitelister() external view override returns (address) {
        return voterWhitelister;
    }

    /**
     * @inheritdoc IPriceSubmitter
     * @dev Deprecated - reverts
     */
    function voterWhitelistBitmap(address) external view override returns (uint256) {
        revert("not supported");
    }

    /**
     * Returns current random number and a flag indicating if it was securely generated.
     * @return _currentRandom Current random number.
     * @return _isSecureRandom Indicates if current random number is secure.
     */
    function getCurrentRandomWithQuality() external view returns (uint256 _currentRandom, bool _isSecureRandom) {
        (_currentRandom, _isSecureRandom, ) = relay.getRandomNumber();
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
        ftsoRegistry = IFtsoRegistryGenesis(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FtsoRegistry"));
        ftsoManager = IFtsoManagerGenesis(_getContractAddress(_contractNameHashes, _contractAddresses, "FtsoManager"));
        voterWhitelister = _getContractAddress(_contractNameHashes, _contractAddresses, "VoterWhitelister");
    }

}