// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "./IAddressValidity.sol";

interface IAddressValidityVerification {

    function verifyAddressValidity(IAddressValidity.Proof calldata _proof)
        external view returns (bool _proved);
}
