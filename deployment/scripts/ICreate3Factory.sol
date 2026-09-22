// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

/**
 * @title ICreate3Factory
 * @notice Call interface for the deployed canonical `Create3Factory`
 *         ([contracts/utils/implementation/Create3Factory.sol]), for use by deployment
 *         scripts and any future tooling that talks to the live factory.
 * @dev Deliberately a standalone interface instead of importing the factory source:
 *      `Create3Factory.sol` is pinned to `bytecode_hash = "None"` in foundry.toml (its
 *      keyless-CREATE2 address depends on the frozen initcode), and solc's metadata setting
 *      is per-compilation-job — importing the source would strip the metadata hash from
 *      EVERYTHING compiled alongside the importer, including deployed artifacts, capping
 *      their explorer verification at a partial match. The factory is never compiled for
 *      deployment anyway — `DeployCreate3Factory` deploys the frozen initcode bytes.
 *
 *      Do not retrofit `Create3Factory` itself to inherit this interface: that file must
 *      never change (see the exact-version pragma pin in its header — any drift breaks the
 *      frozen-initcode address pin).
 */
interface ICreate3Factory {

    /// Emitted for every successful deployment through the factory.
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
     * constructor.
     */
    function deploy(
        bytes32 _salt,
        bytes calldata _initCode
    )
        external payable
        returns (address _deployed);

    /**
     * Predicts the CREATE3 address for a (deployer, salt) pair — identical on every chain
     * where the factory has its canonical address.
     */
    function computeAddress(
        address _deployer,
        bytes32 _salt
    )
        external view
        returns (address);
}
