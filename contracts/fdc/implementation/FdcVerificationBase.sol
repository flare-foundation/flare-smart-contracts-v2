
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IRelay.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract FdcVerificationBase is AddressUpdatable {

    /// The FDC protocol id.
    uint8 public immutable fdcProtocolId;

    /// The Relay contract.
    IRelay public relay;

    /**
    * Constructor.
    * @param _addressUpdater The address of the AddressUpdater contract.
    * @param _fdcProtocolId The FDC protocol id.
    */
    constructor(
        address _addressUpdater,
        uint8 _fdcProtocolId
    )
        AddressUpdatable(_addressUpdater)
    {
        fdcProtocolId = _fdcProtocolId;
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     * @dev It can be overridden if other contracts are needed.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}
