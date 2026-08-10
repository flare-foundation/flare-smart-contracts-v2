// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { Create3 } from "@openzeppelin/contracts/utils/Create3.sol";

/**
 * @title Create3Factory
 * @notice Ownerless, permissionless CREATE3 deployer used to give contracts (e.g. the Relay
 *         proxy) the SAME address on every chain, present and future.
 * @dev Deployed addresses depend only on (this factory, msg.sender, salt) — NOT on the
 *      deployed initcode or constructor arguments — so per-chain implementations and
 *      initializer data do not change the address. Salts are deployer-scoped
 *      (`keccak256(msg.sender, salt)`): only the same deployer account can ever reproduce an
 *      address on another chain, which makes address squatting/front-running impossible.
 *
 *      The factory itself must live at one address everywhere: it is deployed through the
 *      canonical keyless CREATE2 deployer (0x4e59b44847b379578588920cA78FbF26c0B4956C) with a
 *      fixed salt, so ANYONE can (re)deploy the byte-identical, stateless factory on any new
 *      chain at any time. The designated deployer account is therefore the permanent address
 *      authority for the contracts deployed through it (see docs/relay-governance.md).
 */
contract Create3Factory {

    event ContractDeployed(address indexed deployer, bytes32 indexed salt, address deployed);

    /// The (deployer, salt) pair already holds a contract; addresses are single-use.
    error SaltAlreadyUsed(bytes32 salt);
    /// The init code returned no runtime code; reverting keeps the single-use salt usable.
    error EmptyRuntimeCode();

    /**
     * Deploys `_initCode` via CREATE3 under the caller-scoped `_salt`.
     * @param _salt The deployer-chosen salt (scoped to `msg.sender`).
     * @param _initCode The full creation code (including constructor arguments); it does NOT
     * influence the resulting address.
     * @return _deployed The deployed contract address; any attached value is forwarded to the
     * constructor. Reverts with `SaltAlreadyUsed` if the (deployer, salt) pair was already used
     * on this chain, and with `EmptyRuntimeCode` if the init code returns no runtime code.
     */
    function deploy(
        bytes32 _salt,
        bytes calldata _initCode
    )
        external payable
        returns (address _deployed)
    {
        bytes32 guardedSalt = _guardedSalt(msg.sender, _salt);
        require(Create3.computeAddress(guardedSalt).code.length == 0, SaltAlreadyUsed(_salt));
        _deployed = Create3.deploy(msg.value, guardedSalt, _initCode);
        require(_deployed.code.length > 0, EmptyRuntimeCode());
        emit ContractDeployed(msg.sender, _salt, _deployed);
    }

    /**
     * Predicts the CREATE3 address for a (deployer, salt) pair — identical on every chain
     * where this factory has its canonical address.
     */
    function computeAddress(
        address _deployer,
        bytes32 _salt
    )
        external view
        returns (address)
    {
        return Create3.computeAddress(_guardedSalt(_deployer, _salt));
    }

    function _guardedSalt(address _deployer, bytes32 _salt) internal pure returns (bytes32) {
        return keccak256(abi.encode(_deployer, _salt));
    }
}
