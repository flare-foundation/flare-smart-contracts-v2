// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITeeWalletProjectManager } from "../../userInterfaces/tee/ITeeWalletProjectManager.sol";
import { ITeeWalletManager } from "../../userInterfaces/tee/ITeeWalletManager.sol";
import { ITeeWalletKeyManager } from "../../userInterfaces/tee/ITeeWalletKeyManager.sol";
import { ITeeExtensionRegistry } from "../../userInterfaces/tee/ITeeExtensionRegistry.sol";
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
    bytes32 public constant OP_TYPE = bytes32("EVM_TX");
    bytes32 public constant OP_COMMAND = bytes32("SIGN");

    /// TeeExtensionRegistry contract.
    ITeeExtensionRegistry public teeExtensionRegistry;
    /// TeeWalletProjectManager contract.
    ITeeWalletProjectManager public teeWalletProjectManager;
    /// TeeWalletManager contract.
    ITeeWalletManager public teeWalletManager;
    /// TeeWalletKeyManager contract.
    ITeeWalletKeyManager public teeWalletKeyManager;

    /// mapping from wallet id to sign calls counter
    mapping(bytes32 walletId => uint256) internal signCounter;

    error OnlyAuthorizationAddress();
    error WrongKeyType();
    error WalletNotInProduction();

    /**
     * Constructor.
     * @param _teeExtensionRegistry The address of the TeeExtensionRegistry contract.
     * @param _teeWalletProjectManager The address of the TeeWalletProjectManager contract.
     * @param _teeWalletManager The address of the TeeWalletManager contract.
     * @param _teeWalletKeyManager The address of the TeeWalletKeyManager contract.
     */
    constructor(
        ITeeExtensionRegistry _teeExtensionRegistry,
        ITeeWalletProjectManager _teeWalletProjectManager,
        ITeeWalletManager _teeWalletManager,
        ITeeWalletKeyManager _teeWalletKeyManager
    ) {
        teeExtensionRegistry = _teeExtensionRegistry;
        teeWalletProjectManager = _teeWalletProjectManager;
        teeWalletManager = _teeWalletManager;
        teeWalletKeyManager = _teeWalletKeyManager;
    }

    /**
     * Request signing of a transaction by the TEE wallet keys.
     * @param _walletId The ID of the wallet to use for signing.
     * @param _transaction The transaction to be signed.
     */
    function signTransaction(
        bytes32 _walletId,
        Transaction calldata _transaction
    )
        external payable
    {
        bytes32 projectId = teeWalletManager.getWalletProjectId(_walletId);
        require(
            teeWalletProjectManager.getAuthorizationAddress(projectId) == msg.sender,
            OnlyAuthorizationAddress()
        );
        require(teeWalletProjectManager.getKeyType(projectId) == KEY_TYPE, WrongKeyType());
        require(
            teeWalletManager.getWalletStatus(_walletId) == ITeeWalletManager.WalletStatus.PRODUCTION,
            WalletNotInProduction()
        );

        TeeIdKeyIdPair[] memory teeIdKeyIdPairs = teeWalletKeyManager.receivingTeesAndKeys(_walletId);

        SignTransaction memory message = SignTransaction({
            walletId: _walletId,
            teeIdKeyIdPairs: teeIdKeyIdPairs,
            transaction: _transaction
        });

        (address[] memory cosigners, uint64 cosignersThreshold) =
            teeWalletManager.getWalletCosignersAndThreshold(_walletId);

        bytes32 instructionId = keccak256(abi.encode(
            OP_TYPE, OP_COMMAND, _walletId, signCounter[_walletId]++
        ));
        teeExtensionRegistry.sendInstructions{value: msg.value}(
            instructionId,
            _toTeeIds(teeIdKeyIdPairs),
            OP_TYPE,
            OP_COMMAND,
            abi.encode(message),
            cosigners,
            cosignersThreshold
        );
    }

    function _toTeeIds(
        TeeIdKeyIdPair[] memory _teeIdKeyIdPairs
    )
        internal pure
        returns(address[] memory _teeIds)
    {
        _teeIds = new address[](_teeIdKeyIdPairs.length);
        for (uint256 i = 0; i < _teeIdKeyIdPairs.length; i++) {
            _teeIds[i] = _teeIdKeyIdPairs[i].teeId;
        }
    }
}
