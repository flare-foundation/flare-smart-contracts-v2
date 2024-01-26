// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/IEntityManager.sol";

/**
 * EntityManager internal interface.
 */
interface IIEntityManager is IEntityManager {

    /**
     * Gets voters' delegation addresses at a specific block number.
     * @param _voters Voters' addresses.
     * @param _blockNumber Block number.
     * @return _delegationAddresses Delegation addresses.
     */
    function getDelegationAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _delegationAddresses);

    /**
     * Gets voters' submit addresses at a specific block number.
     * @param _voters Voters' addresses.
     * @param _blockNumber Block number.
     * @return _submitAddresses Submit addresses.
     */
    function getSubmitAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _submitAddresses);

    /**
     * Gets voters' submit signatures addresses at a specific block number.
     * @param _voters Voters' addresses.
     * @param _blockNumber Block number.
     * @return _submitSignaturesAddresses Submit signatures addresses.
     */
    function getSubmitSignaturesAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _submitSignaturesAddresses);

    /**
     * Gets voters' signing policy addresses at a specific block number.
     * @param _voters Voters' addresses.
     * @param _blockNumber Block number.
     * @return _signingPolicyAddresses Signing policy addresses.
     */
    function getSigningPolicyAddresses(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (address[] memory _signingPolicyAddresses);

    /**
     * Gets voters' public keys at a specific block number.
     * @param _voters Voters' addresses.
     * @param _blockNumber Block number.
     * @return _parts1 Parts 1 of the public keys.
     * @return _parts2 Parts 2 of the public keys.
     */
    function getPublicKeys(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (bytes32[] memory _parts1, bytes32[] memory _parts2);

    /**
     * Gets voters' node ids at a specific block number.
     * @param _voters Voters' addresses.
     * @param _blockNumber Block number.
     * @return _nodeIds Node ids.
     */
    function getNodeIds(address[] memory _voters, uint256 _blockNumber)
        external view
        returns (bytes20[][] memory _nodeIds);
}
