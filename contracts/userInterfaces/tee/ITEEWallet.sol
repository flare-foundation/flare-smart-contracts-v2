// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./ITEERegistry.sol";

/**
 * TEEWallet interface.
 */
interface ITEEWallet {

    /// Payment instruction structure
    struct PaymentInstruction {
        bytes32 walletId;
        string paymentAddress;
        uint256 value;
        uint256 initialFee;
        bytes32 paymentReference;
    }

    /// Payment instructed event - emitted when a pay method is called
    event PaymentInstructed (
        bytes32 walletId,
        uint256 rewardEpochId,
        string sourceAddress,
        string paymentAddress,
        uint256 sequenceNumber,
        uint256 value,
        uint256 initialFee,
        bytes32 paymentReference,
        ITEERegistry.TEEMachine[] teeMachines
    );

    /**
     * Payment instruction method.
     * Emits a PaymentInstructed event.
     * Can only be called by the payment initiator.
     * @param _paymentInstruction The payment instruction.
     * @return _sequenceNumber The sequence number of the payment instruction.
     */
    function pay(PaymentInstruction calldata _paymentInstruction) external returns (uint256 _sequenceNumber);
}