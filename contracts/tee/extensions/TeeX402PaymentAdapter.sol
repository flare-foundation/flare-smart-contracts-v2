// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

import { ITeeX402ReceiptValidator } from "../../userInterfaces/tee/ITeeX402ReceiptValidator.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";

/**
 * @title TeeX402PaymentAdapter
 * @notice Diamond facet providing x402 receipt validation for FlareTeeManager.
 */
contract TeeX402PaymentAdapter is ITeeX402ReceiptValidator {

    bytes32 private constant TEE_X402_STORAGE_POSITION =
        keccak256("flare.tee.payments.x402.storage");

    struct X402Storage {
        mapping(bytes32 => bool) settledReceipts;
        ITeePaymentsRegistry registry;
    }

    function _getX402Storage() internal pure returns (X402Storage storage s) {
        bytes32 position = TEE_X402_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    function verifyAndRecordReceipt(
        X402Receipt calldata _receipt
    )
        external
        override
        returns (bool _success)
    {
        X402Storage storage s = _getX402Storage();

        if (_receipt.evidenceRef == bytes32(0)) revert InvalidEvidenceRef(_receipt.evidenceRef);
        if (s.settledReceipts[_receipt.fingerprint]) revert ReceiptAlreadySpent(_receipt.fingerprint);

        // Verify sourceId is valid in the TeePaymentsRegistry
        address teePayments = s.registry.getTeePayments(_receipt.sourceId);
        if (teePayments == address(0)) revert SourceNotActive(_receipt.sourceId);

        // Record settlement to prevent double-spending
        s.settledReceipts[_receipt.fingerprint] = true;

        emit X402ReceiptSettled(
            _receipt.evidenceRef,
            _receipt.fingerprint,
            _receipt.sourceId,
            _receipt.payer,
            _receipt.amount
        );

        return true;
    }

    function isReceiptSettled(
        bytes32 _fingerprint
    )
        external view
        override
        returns (bool _settled)
    {
        return _getX402Storage().settledReceipts[_fingerprint];
    }
}
