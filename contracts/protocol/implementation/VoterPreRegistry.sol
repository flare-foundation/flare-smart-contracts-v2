// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IIVoterRegistrationTrigger } from "../interface/IIVoterRegistrationTrigger.sol";
import { IVoterPreRegistry } from "../../userInterfaces/IVoterPreRegistry.sol";
import { IVoterRegistry } from "../../userInterfaces/IVoterRegistry.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";
import { AddressSet } from "../../utils/lib/AddressSet.sol";
import { IIVoterRegistry } from "../../protocol/interface/IIVoterRegistry.sol";
import { IIEntityManager } from "../interface/IIEntityManager.sol";
import { IIEntityManager } from "../interface/IIEntityManager.sol";
import { IIFlareSystemsManager } from "../interface/IIFlareSystemsManager.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract VoterPreRegistry is AddressUpdatable, IIVoterRegistrationTrigger, IVoterPreRegistry {

    struct VoterWithSignature {
        address voter;
        // Signature of the voter to pre-register.
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct PreRegistryState {
        VoterWithSignature[] list;
        mapping (address => uint256) index;
    }

    // Addresses of the external contracts.
    /// The FlareSystemsManager contract.
    IIFlareSystemsManager public flareSystemsManager;
    /// The EntityManager contract.
    IIEntityManager public entityManager;
    /// The VoterRegistry contract.
    IIVoterRegistry public voterRegistry;

    /// pre-registered voters for given reward epoch id
    mapping(uint256 rewardEpochId => PreRegistryState) internal preRegisteredVoters;

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
        VoterWithSignature[] storage voters = preRegisteredVoters[_rewardEpochId].list;
        for (uint256 i = 0; i < voters.length; i++) {
            VoterWithSignature memory voterData = voters[i];
            try voterRegistry.registerVoter(
                voterData.voter,
                Signature(voterData.v, voterData.r, voterData.s)
            )
            { }
            catch {
                emit VoterRegistrationFailed(voterData.voter, _rewardEpochId);
            }
        }
    }

    /**
     * @inheritdoc IVoterPreRegistry
     */
    function preRegisterVoter(address _voter, Signature calldata _signature) external {
        uint24 rewardEpochId = flareSystemsManager.getCurrentRewardEpochId() + 1;
        // check if pre-registration is still open
        (, , , uint256 randomAcquisitionEndBlock) = flareSystemsManager.getRandomAcquisitionInfo(rewardEpochId);
        require(randomAcquisitionEndBlock == 0, "pre-registration not opened anymore");
        // check if voter is registered in the current reward epoch
        require(voterRegistry.isVoterRegistered(_voter, rewardEpochId - 1), "voter currently not registered");
        // check signature
        bytes32 messageHash = keccak256(abi.encode(rewardEpochId, _voter));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        address signingPolicyAddress = ECDSA.recover(signedMessageHash, _signature.v, _signature.r, _signature.s);
        address voterAddress = entityManager.getVoterForSigningPolicyAddress(signingPolicyAddress, block.number);
        require(voterAddress == _voter, "invalid signature");
        // pre-register voter
        uint256 index = preRegisteredVoters[rewardEpochId].index[_voter];
        // if voter is not pre-registered yet, add it
        if (index == 0) {
            index = preRegisteredVoters[rewardEpochId].list.length + 1; // 1-based index
            preRegisteredVoters[rewardEpochId].index[_voter] = index;
            preRegisteredVoters[rewardEpochId].list.push();
        }
        // update the pre-registered voter data
        VoterWithSignature storage preRegisteredVoter = preRegisteredVoters[rewardEpochId].list[index - 1];
        preRegisteredVoter.voter = _voter;
        preRegisteredVoter.v = _signature.v;
        preRegisteredVoter.r = _signature.r;
        preRegisteredVoter.s = _signature.s;
        // emit event
        emit VoterPreRegistered(_voter, rewardEpochId);
    }

    /**
     * @inheritdoc IVoterPreRegistry
     */
    function getPreRegisteredVoters(uint256 _rewardEpochId) external view returns (address[] memory _voters) {
        PreRegistryState storage state = preRegisteredVoters[_rewardEpochId];
        uint256 length = state.list.length;
        _voters = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _voters[i] = state.list[i].voter;
        }
    }

    /**
     * @inheritdoc IVoterPreRegistry
     */
    function isVoterPreRegistered(uint256 _rewardEpochId, address _voter) external view returns (bool) {
        return preRegisteredVoters[_rewardEpochId].index[_voter] != 0;
    }

    /**
     * @inheritdoc IVoterPreRegistry
     */
    function getVoterSignature(uint256 _rewardEpochId, address _voter) external view returns (Signature memory) {
        uint256 index = preRegisteredVoters[_rewardEpochId].index[_voter];
        require(index != 0, "voter not pre-registered");
        VoterWithSignature storage preRegisteredVoter = preRegisteredVoters[_rewardEpochId].list[index - 1];
        return Signature(preRegisteredVoter.v, preRegisteredVoter.r, preRegisteredVoter.s);
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