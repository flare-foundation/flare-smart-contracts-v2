// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IFlareTeeManager } from "../../userInterfaces/tee/IFlareTeeManager.sol";
import { ITeeExtensionRegistryFacet } from "../../userInterfaces/tee/ITeeExtensionRegistryFacet.sol";
import { ITeeWalletManagerFacet } from "../../userInterfaces/tee/ITeeWalletManagerFacet.sol";
import { TeeIdKeyIdPair } from "../../userInterfaces/tee/ITeeIdKeyIdPair.sol";

/**
 * TeeExtensionInstructionsSenderMock is a mock contract used for testing extension instructions sending functionality.
 */
contract TeeExtensionInstructionsSenderMock {

    struct SignTransaction {
        bytes32 walletId;
        TeeIdKeyIdPair[] teeIdKeyIdPairs;
        Transaction transaction;
    }

    struct Transaction {
        uint256 nonce;
        uint256 chainId;
        address to;
        bytes data;
        uint256 value;
        uint256 gasPrice;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        uint256 gas;
    }

    bytes32 public constant KEY_TYPE = bytes32("EVM");
    bytes32 public constant OP_TYPE = bytes32("DEMO_EVM");
    bytes32 public constant OP_COMMAND = bytes32("SIGN");

    /// FlareTeeManager Diamond contract.
    IFlareTeeManager public flareTeeManager;

    mapping(bytes32 walletId => address) private authorizationAddresses;

    error OnlyAuthorizationAddress();
    error WrongKeyType();
    error WalletNotInProduction();
    error OnlyOwner();

    /**
     * Constructor.
     * @param _flareTeeManager The address of the FlareTeeManager Diamond contract.
     */
    constructor(
        IFlareTeeManager _flareTeeManager
    ) {
        flareTeeManager = _flareTeeManager;
    }

    /**
     * Request signing of a transaction by the TEE wallet keys.
     * @param _walletId The ID of the wallet to use for signing.
     * @param _transaction The transaction to be signed.
     * @param _claimBackAddress An address that can claim back the fee if the instructions are not executed (optional).
     */
    function signTransaction(
        bytes32 _walletId,
        Transaction calldata _transaction,
        address _claimBackAddress
    )
        external payable
    {
        require(authorizationAddresses[_walletId] == msg.sender, OnlyAuthorizationAddress());
        bytes32 projectId = flareTeeManager.getWalletProjectId(_walletId);
        require(flareTeeManager.getKeyType(projectId) == KEY_TYPE, WrongKeyType());
        require(
            flareTeeManager.getWalletStatus(_walletId) == ITeeWalletManagerFacet.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );

        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = flareTeeManager.receivingTeesAndKeys(_walletId);

        SignTransaction memory message = SignTransaction({
            walletId: _walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            transaction: _transaction
        });

        (address[] memory cosigners, uint64 cosignersThreshold) =
            flareTeeManager.getWalletCosignersAndThreshold(_walletId);

        flareTeeManager.sendInstructions{value: msg.value}(
            _toTeeIds(teeIdKeyIdPairs),
            ITeeExtensionRegistryFacet.TeeInstructionParams(
                OP_TYPE,
                OP_COMMAND,
                abi.encode(message),
                cosigners,
                cosignersThreshold,
                _claimBackAddress
            )
        );
    }

    /**
     * Send custom instructions to available TEEs via the FlareTeeManager.
     * @param _teeIds The TEE machine IDs to which the instructions are sent (must all belong to the same extension).
     * @param _instructionParams The instruction parameters.
     */
    function sendInstructions(
        address[] calldata _teeIds,
        ITeeExtensionRegistryFacet.TeeInstructionParams calldata _instructionParams
    )
        external payable
    {
        flareTeeManager.sendInstructions{value: msg.value}(
            _teeIds,
            _instructionParams
        );
    }

    function setAuthorizationAddress(
        bytes32 _walletId,
        address _authorizationAddress
    )
        external
    {
        bytes32 projectId = flareTeeManager.getWalletProjectId(_walletId);
        require(flareTeeManager.getOwner(projectId) == msg.sender, OnlyOwner());
        authorizationAddresses[_walletId] = _authorizationAddress;
    }

    function getAuthorizationAddress(
        bytes32 _walletId
    )
        external view
        returns (address)
    {
        return authorizationAddresses[_walletId];
    }

    function _toTeeIds(
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    )
        internal pure
        returns (address[] memory _teeIds)
    {
        _teeIds = new address[](_teeIdKeyIdPairs.length);
        for (uint256 i = 0; i < _teeIdKeyIdPairs.length; i++) {
            _teeIds[i] = _teeIdKeyIdPairs[i].teeId;
        }
    }
}
