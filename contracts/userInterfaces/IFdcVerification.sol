// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IRelay.sol";
import "./fdc/IAddressValidityVerification.sol";
import "./fdc/IBalanceDecreasingTransactionVerification.sol";
import "./fdc/IConfirmedBlockHeightExistsVerification.sol";
import "./fdc/IEVMTransactionVerification.sol";
import "./fdc/IPaymentVerification.sol";
import "./fdc/IReferencedPaymentNonexistenceVerification.sol";
import "./fdc/IWeb2JsonVerification.sol";


/**
 * FdcVerification interface.
 */
interface IFdcVerification is
    IAddressValidityVerification,
    IBalanceDecreasingTransactionVerification,
    IConfirmedBlockHeightExistsVerification,
    IEVMTransactionVerification,
    IPaymentVerification,
    IReferencedPaymentNonexistenceVerification,
    IWeb2JsonVerification
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
