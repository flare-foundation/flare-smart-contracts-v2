// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../governance/implementation/GovernedProxyImplementation.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../userInterfaces/IFdcVerification.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * FdcVerification contract.
 *
 * This contract is used to verify FDC attestations.
 */
contract FdcVerification is IFdcVerification, UUPSUpgradeable, GovernedProxyImplementation, AddressUpdatable {
    using MerkleProof for bytes32[];

    /// The FDC protocol id.
    uint8 public fdcProtocolId;

    /// The Relay contract.
    IRelay public relay;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor()
        GovernedProxyImplementation() AddressUpdatable(address(0))
    { }

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by GovernedBase.initialise).
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint8 _fdcProtocolId
    )
        external
    {
        GovernedBase.initialise(_governanceSettings, _initialGovernance);
        AddressUpdatable.setAddressUpdaterValue(_addressUpdater);
        fdcProtocolId = _fdcProtocolId;
    }

    /**
     * @inheritdoc IAddressValidityVerification
     */
    function verifyAddressValidity(IAddressValidity.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("AddressValidity") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IBalanceDecreasingTransactionVerification
     */
    function verifyBalanceDecreasingTransaction(IBalanceDecreasingTransaction.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("BalanceDecreasingTransaction") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IConfirmedBlockHeightExistsVerification
     */
    function verifyConfirmedBlockHeightExists(IConfirmedBlockHeightExists.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("ConfirmedBlockHeightExists") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
   }

    /**
     * @inheritdoc IEVMTransactionVerification
     */
    function verifyEVMTransaction(IEVMTransaction.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("EVMTransaction") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IPaymentVerification
     */
    function verifyPayment(IPayment.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("Payment") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IReferencedPaymentNonexistenceVerification
     */
    function verifyReferencedPaymentNonexistence(IReferencedPaymentNonexistence.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("ReferencedPaymentNonexistence") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /**
     * @inheritdoc IWeb2JsonVerification
     */
    function verifyWeb2Json(IWeb2Json.Proof calldata _proof)
        external view returns (bool _proved)
    {
        bytes32 merkleRoot = relay.merkleRoots(fdcProtocolId, _proof.data.votingRound);
        return
            _proof.data.attestationType == bytes32("Web2Json") &&
            _proof.merkleProof.verifyCalldata(merkleRoot, keccak256(abi.encode(_proof.data)));
    }

    /////////////////////////////// UUPS UPGRADABLE ///////////////////////////////

    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /**
     * @inheritdoc UUPSUpgradeable
     * @dev Only governance can call this method.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data)
        public payable override
        onlyGovernance
        onlyProxy
    {
        super.upgradeToAndCall(newImplementation, data);
    }

    /**
     * Unused. just to present to satisfy UUPSUpgradeable requirement.
     * The real check is in onlyGovernance modifier on upgradeTo and upgradeToAndCall.
     */
    function _authorizeUpgrade(address newImplementation) internal override {}

    /////////////////////////////// INTERNAL FUNCTIONS ///////////////////////////////

    /**
     * Implementation of the AddressUpdatable abstract method.
     * @dev It can be overridden if other contracts are needed.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        relay = IRelay(_getContractAddress(_contractNameHashes, _contractAddresses, "Relay"));
    }
}
