// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeGovernance.sol";

/**
 * TeeGovernance is used for managing TEE governance.
 */
contract TeeGovernance is ITeeGovernance, Governed, AddressUpdatable {

    struct TeeGovernanceState {
        address[] signers;
        uint256 signersThreshold;
    }

    mapping(bytes32 governanceHash => TeeGovernanceState) private governanceHashToTeeGovernance;
    /// The latest TEE governance hash.
    bytes32 public latestTeeGovernanceHash;

    /**
     * Constructor.
     * @param _governanceSettings The address of the GovernanceSettings contract.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * Sets new TEE governance.
     * @param _signers The new governance signers.
     * @param _signersThreshold The new governance signers threshold.
     * Can only be called by the governance.
     */
    function setNewTeeGovernance(
        address[] calldata _signers,
        uint256 _signersThreshold
    )
        external onlyGovernance
    {
        require(_signers.length > 0, "no signers");
        require(_signersThreshold > 0 && _signersThreshold <= _signers.length, "invalid threshold");
        latestTeeGovernanceHash = keccak256(abi.encode(_signers, _signersThreshold));
        governanceHashToTeeGovernance[latestTeeGovernanceHash] = TeeGovernanceState({
            signers: _signers,
            signersThreshold: _signersThreshold
        });
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getTeeGovernance(bytes32 _governanceHash)
        external view
        returns(address[] memory _signers, uint256 _signersThreshold)
    {
        return _getGovernance(_governanceHash);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function getLatestTeeGovernance()
        external view
        returns(address[] memory _signers, uint256 _signersThreshold)
    {
        return _getGovernance(latestTeeGovernanceHash);
    }

    /**
     * @inheritdoc ITeeGovernance
     */
    function isGovernanceHashValid(
        bytes32 _governanceHash
    )
        external view
        returns (bool)
    {
        return governanceHashToTeeGovernance[_governanceHash].signersThreshold > 0;
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

    }

    function _getGovernance(bytes32 _governanceHash)
        internal view
        returns(address[] memory _signers, uint256 _signersThreshold)
    {
        _signersThreshold = governanceHashToTeeGovernance[_governanceHash].signersThreshold;
        require(_signersThreshold > 0, "invalid governance hash");
        _signers = governanceHashToTeeGovernance[_governanceHash].signers;
    }
}
