// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

/**
 * TeeVrf interface.
 */
interface ITeeVrf {

    struct VrfInstructionMessage {
        bytes32 walletId;
        uint64 keyId;
        bytes nonce;
    }

    event VrfRequested(bytes32 indexed walletId, uint64 keyId, bytes32 instructionId);

    error NonceEmpty();
    error WalletNotInProduction();
    error NoTeesForKey();
    error OnlyWalletOwner();

    /**
     * Sends a F_WALLET VRF instruction to the TEE machines holding the specified wallet key.
     * The TEE will generate a VRF proof for the given nonce using the key identified by _keyId.
     * Emits a VrfRequested event.
     * @param _walletId The wallet id.
     * @param _keyId The key id within the wallet to use for VRF proof generation.
     * @param _nonce The nonce (must be non-empty) used as input to the VRF.
     * @return _instructionId The instruction ID assigned by the extension registry.
     */
    function requestVrf(
        bytes32 _walletId,
        uint64 _keyId,
        bytes calldata _nonce
    )
        external payable
        returns (bytes32 _instructionId);
}
