// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

enum PaymentModel {
    UNKNOWN,
    ACCOUNT,
    UTXO
}

interface ITeePaymentsModel {

    /**
     * Returns the supported payment model.
     * @return _paymentModel The supported payment model.
     */
    function paymentModel()
        external pure
        returns (PaymentModel _paymentModel);
}
