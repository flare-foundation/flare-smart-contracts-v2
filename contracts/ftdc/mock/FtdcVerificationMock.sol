// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/tee/ITeeRegistry.sol";
import "../../userInterfaces/IRelay.sol";
import "../../userInterfaces/ftdc/IFtdcVerification.sol";
import "../../utils/lib/AddressSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * FtdcVerification MOCK contract.
 *
 * This contract is used to verify FTDC attestations.
 */
contract FtdcVerificationMock is IFtdcVerification, AddressUpdatable {
    using AddressSet for AddressSet.State;

    /// The TEE registry contract.
    ITeeRegistry public teeRegistry;
    /// The Relay contract.
    IRelay public relay;

    bool private returnActiveTeeIds = true;
    AddressSet.State private signingTeeIds;

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(address _addressUpdater) AddressUpdatable(_addressUpdater) {
        // empty constructor
    }

    // Mock function for testing purposes only.
    function setSigningTeeIds(address[] calldata _signingTeeIds) external {
        returnActiveTeeIds = false;
        signingTeeIds.replaceAll(_signingTeeIds);
    }

    /**
     * @inheritdoc IFtdcVerification
     */
    function verifySigningPolicySignatures(
        bytes calldata _relayMessage,
        bytes32 _messageHash
    )
        external returns (uint256 _rewardEpochId)
    {
        // no verification
        // always return the latest reward epoch id
        (_rewardEpochId, ) = relay.lastInitializedRewardEpochData();
    }

    /**
     * @inheritdoc IFtdcVerification
     */
    function verifyTeeSignatures(
        Signature[] calldata _signatures,
        bytes32 _messageHash
    )
        external view returns(address[] memory _signingTeeIds)
    {
        // no verification
        if (returnActiveTeeIds) {
            _signingTeeIds = teeRegistry.getActiveTeeIds();
        } else {
            _signingTeeIds = signingTeeIds.list;
        }
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
        teeRegistry = ITeeRegistry(_getContractAddress(_contractNameHashes, _contractAddresses, "TeeRegistry"));
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}
