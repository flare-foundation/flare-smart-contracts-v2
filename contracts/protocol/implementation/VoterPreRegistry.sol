// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../utils/implementation/AddressUpdatable.sol";
import "../interface/IIVoterRegistrationTrigger.sol";
import "../../userInterfaces/IVoterPreRegistry.sol";
import "../../utils/lib/AddressSet.sol";
import "../../protocol/interface/IIVoterRegistry.sol";
import "../interface/IIEntityManager.sol";
import "../interface/IIEntityManager.sol";
import "../interface/IIFlareSystemsManager.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract VoterPreRegistry is AddressUpdatable, IIVoterRegistrationTrigger, IVoterPreRegistry {
    using AddressSet for AddressSet.State;

    // Addresses of the external contracts.
    /// The FlareSystemsManager contract.
    IIFlareSystemsManager public flareSystemsManager;
    /// The EntityManager contract.
    IIEntityManager public entityManager;
    /// The VoterRegistry contract.
    IIVoterRegistry public voterRegistry;

    /// pre-registered voters for given reward epoch id
    mapping(uint256 rewardEpochId => AddressSet.State) internal preRegisteredVoters;

    /// Only flare systems manager can call this method.
    modifier onlyFlareSystemsManager() {
        require(msg.sender == address(flareSystemsManager), "only flare systems manager");
        _;
    }

    /**
     * Constructor.
     * @param _addressUpdater The address of the AddressUpdater contract.
     */
    constructor(
        address _addressUpdater
    )
        AddressUpdatable(_addressUpdater)
    {
    }

    /**
     * @inheritdoc IIVoterRegistrationTrigger
     */
    function triggerVoterRegistration(uint24 _rewardEpochId) external onlyFlareSystemsManager {
        address[] memory voters = preRegisteredVoters[_rewardEpochId].list;
        for (uint256 i = 0; i < voters.length; i++) {
            try voterRegistry.systemRegistration(voters[i]) {
            } catch {
                emit VoterRegistrationFailed(voters[i], _rewardEpochId);
            }
        }
    }

    /**
     * @inheritdoc IVoterPreRegistry
     */
    function preRegisterVoter(address _voter, IIVoterRegistry.Signature calldata _signature) external {
        uint24 rewardEpochId = flareSystemsManager.getCurrentRewardEpochId() + 1;
        // check if pre-registration is still open
        (, , , uint256 randomAcquisitionEndBlock) = flareSystemsManager.getRandomAcquisitionInfo(rewardEpochId);
        require(randomAcquisitionEndBlock == 0, "pre-registration not opened anymore");
        // check if voter is already pre-registered
        require(preRegisteredVoters[rewardEpochId].index[_voter] == 0, "voter already pre-registered");
        // check if voter is registered in the current reward epoch
        require(voterRegistry.isVoterRegistered(_voter, rewardEpochId - 1), "voter currently not registered");
        // check signature
        bytes32 messageHash = keccak256(abi.encode(rewardEpochId, _voter));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        uint256 initBlock = voterRegistry.newSigningPolicyInitializationStartBlockNumber(rewardEpochId - 1);
        address voterAddress = entityManager.getVoterForSigningPolicyAddress(signingPolicyAddress, initBlock);
        require(voterAddress == _voter, "invalid signature");
        // pre-register voter
        preRegisteredVoters[rewardEpochId].add(_voter);
        emit VoterPreRegistered(_voter, rewardEpochId);
    }

    /**
     * @inheritdoc IVoterPreRegistry
     */
    function getPreRegisteredVoters(uint24 _rewardEpochId) external view returns (address[] memory) {
        return preRegisteredVoters[_rewardEpochId].list;
    }

    /**
     * @inheritdoc IVoterPreRegistry
     */
    function isVoterPreRegistered(uint24 _rewardEpochId, address _voter) external view returns (bool) {
        return preRegisteredVoters[_rewardEpochId].index[_voter] != 0;
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        voterRegistry = IIVoterRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry"));
        flareSystemsManager = IIFlareSystemsManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareSystemsManager"));
        entityManager = IIEntityManager(_getContractAddress(_contractNameHashes, _contractAddresses, "EntityManager"));
    }
}