// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IRelay } from "./IRelay.sol";
import { IAddressValidityVerification } from "./fdc/IAddressValidityVerification.sol";
import { IBalanceDecreasingTransactionVerification } from "./fdc/IBalanceDecreasingTransactionVerification.sol";
import { IConfirmedBlockHeightExistsVerification } from "./fdc/IConfirmedBlockHeightExistsVerification.sol";
import { IEVMTransactionVerification } from "./fdc/IEVMTransactionVerification.sol";
import { IPaymentVerification } from "./fdc/IPaymentVerification.sol";
import { IReferencedPaymentNonexistenceVerification } from "./fdc/IReferencedPaymentNonexistenceVerification.sol";
import { IWeb2JsonVerification } from "./fdc/IWeb2JsonVerification.sol";
import { IXRPPaymentVerification } from "./fdc/IXRPPaymentVerification.sol";
import { IXRPPaymentNonexistenceVerification } from "./fdc/IXRPPaymentNonexistenceVerification.sol";


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
    IWeb2JsonVerification,
    IXRPPaymentVerification,
    IXRPPaymentNonexistenceVerification
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
