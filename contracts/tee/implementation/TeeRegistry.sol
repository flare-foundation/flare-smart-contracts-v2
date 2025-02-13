// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";

/**
 * TeeRegistry is used for registration of TEE machines.
 */
contract TeeRegistry is ITeeRegistry, Governed, AddressUpdatable {

    struct TeeState {
        address owner;
        TeeStatus status; // 0: initialized, 1: production, 2: paused, 3: paused_for_upgrade
        uint64 lastStatusUpdateTs;
        bytes32 codeHash;
        bytes32 platform; // utf8 encoded
        string url;
    }

    struct TeeVersion {
        uint256 version;
        bytes32[] platforms; // utf8 encoded platform
    }

    address[] private teeIds;
    mapping(address teeId => TeeState) private teeStates;
    mapping(bytes32 codeHash => TeeVersion) private codeHashPlatforms;
    mapping(uint256 version => bytes32[]) private versionOpTypes; // utf8 encoded operation type


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
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
    }

    /**
     * @notice Returns hash from string value
     */
    function _keccak256AbiEncode(string memory _value) internal pure returns(bytes32) {
        return keccak256(abi.encode(_value));
    }
}
