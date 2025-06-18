// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IRelay.sol";
import "./fdc/IAddressValidityVerification.sol";
import "./fdc/IBalanceDecreasingTransactionVerification.sol";
import "./fdc/IConfirmedBlockHeightExistsVerification.sol";
import "./fdc/IEVMTransactionVerification.sol";
import "./fdc/IPaymentVerification.sol";
import "./fdc/IReferencedPaymentNonexistenceVerification.sol";


/**
 * FdcVerification interface.
 */
interface IFdcVerification is
    IAddressValidityVerification,
    IBalanceDecreasingTransactionVerification,
    IConfirmedBlockHeightExistsVerification,
    IEVMTransactionVerification,
    IPaymentVerification,
    IReferencedPaymentNonexistenceVerification
{
    /**
     * The FDC protocol id.
     */
    function fdcProtocolId() external view returns (uint8 _fdcProtocolId);

    /**
     * Relay contract address.
     */
    function relay() external view returns (IRelay);
}
