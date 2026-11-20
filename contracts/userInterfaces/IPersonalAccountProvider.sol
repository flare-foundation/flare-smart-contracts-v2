// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9;

/**
 * IPersonalAccountProvider interface — what the forbidden address list asks a source's personal account provider: the
 * EVM address of the Personal Account an underlying address owns. Implemented by the smart-account controllers
 * (`PersonalAccountsFacet`); the list lists that address on its EVM list whenever it lists the owner
 * (`IForbiddenAddressList.getPersonalAccountProvider`).
 */
interface IPersonalAccountProvider {

    /**
     * The Personal Account `_owner` owns — its address whether or not it is deployed yet (it is deterministic).
     * @param _owner The owner's address on the underlying chain, in its canonical form.
     */
    function getPersonalAccount(
        string calldata _owner
    )
        external view
        returns (address);
}
