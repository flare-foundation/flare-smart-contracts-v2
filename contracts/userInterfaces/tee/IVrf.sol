// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * @title IVrf
 * @notice Public interface for the VrfFacet.
 */
interface IVrf {

    struct VrfInstructionMessage {
        bytes32 walletId;
        uint64 keyId;
        bytes nonce;
    }

    event VrfRequested(
        bytes32 indexed walletId,
        uint64 keyId,
        bytes32 instructionId
    );

    event VrfAuthorizationAddressSet(
        bytes32 indexed walletId,
        address authorizationAddress
    );

    error NonceEmpty();
    error WalletNotInProduction();
    error NoTeesForKey();
    error OnlyWalletOwner();
    error OnlyAuthorizationAddress();

    /**
     * Sends a F_WALLET VRF instruction to the TEE machines holding the specified wallet key.
     * The TEE will generate a VRF proof for the given nonce using the key identified by _keyId.
     * Emits VrfRequested event.
     * @param _walletId The wallet id.
     * @param _keyId The key id within the wallet to use for VRF proof generation.
     * @param _nonce The nonce (must be non-empty) used as input to the VRF.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     * @return _instructionId The instruction ID assigned by the extension registry.
     * Can only be called by the authorization address set for the wallet.
     */
    function requestVrf(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _nonce,
        address _claimBackAddress
    )
        external payable
        returns (bytes32 _instructionId);

    /**
     * Sets the authorization address that can request VRF for the given wallet.
     * Emits VrfAuthorizationAddressSet event.
     * @param _walletId The wallet id.
     * @param _authorizationAddress The address authorized to request VRF for the wallet.
     * NOTE: Setting the authorization address to `address(0)` disables VRF requests for the wallet.
     * Can only be called by the wallet owner.
     */
    function setVrfAuthorizationAddress(
        bytes32 _walletId,
        address _authorizationAddress
    )
        external;

    /**
     * Gets the authorization address that can request VRF for the given wallet.
     * @param _walletId The wallet id.
     * @return The address authorized to request VRF for the wallet.
     */
    function getVrfAuthorizationAddress(
        bytes32 _walletId
    )
        external view
        returns (address);
}
