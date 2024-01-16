// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "flare-smart-contracts/contracts/userInterfaces/IPChainStakeMirror.sol";
import "../interface/IWNat.sol";
import "./EntityManager.sol";
import "./WNatDelegationFee.sol";
import "./VoterRegistry.sol";
import "../../utils/implementation/AddressUpdatable.sol";
import "../../governance/implementation/Governed.sol";

contract SigningPolicyWeightCalculator is Governed, AddressUpdatable {

    uint256 internal constant PPM_MAX = 1e6;

    // Addresses of the external contracts.
    EntityManager public entityManager;
    WNatDelegationFee public wNatDelegationFee;
    VoterRegistry public voterRegistry;
    IPChainStakeMirror public pChainStakeMirror;
    IWNat public wNat;
    uint24 public wNatCapPPM;

    event VoterRegistrationInfo(
        address voter,
        uint256 rewardEpochId,
        uint256 wNatWeight,
        uint256 wNatCappedWeight,
        bytes20[] nodeIds,
        uint256[] nodeWeights,
        uint16 delegationFeeBIPS
    );

    modifier onlyVoterRegistry {
        require(msg.sender == address(voterRegistry), "only voter registry");
        _;
    }

    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint24 _wNatCapPPM
    )
        Governed(_governanceSettings, _initialGovernance) AddressUpdatable(_addressUpdater)
    {
        require(_wNatCapPPM <= PPM_MAX, "_wNatCapPPM too high");
        wNatCapPPM = _wNatCapPPM;
    }

    function calculateWeight(
        address _voter,
        address _delegationAddress,
        uint256 _rewardEpochId,
        uint256 _votePowerBlockNumber
    )
        external onlyVoterRegistry
        returns (uint256 _signingPolicyWeight)
    {
        bytes20[] memory nodeIds = entityManager.getNodeIdsOfAt(_voter, _votePowerBlockNumber);
        uint256[] memory nodeWeights = pChainStakeMirror.batchVotePowerOfAt(nodeIds, _votePowerBlockNumber);
        for (uint256 i = 0; i < nodeWeights.length; i++) {
            _signingPolicyWeight += nodeWeights[i];
        }

        uint256 totalWNatVotePower = wNat.totalVotePowerAt(_votePowerBlockNumber);
        uint256 wNatWeightCap = totalWNatVotePower * wNatCapPPM / PPM_MAX; // no overflow possible
        uint256 wNatWeight = wNat.votePowerOfAt(_delegationAddress, _votePowerBlockNumber);
        uint256 wNatCappedWeight = Math.min(wNatWeightCap, wNatWeight);
        uint16 delegationFeeBIPS = wNatDelegationFee.getVoterFeePercentage(_voter, _rewardEpochId);

        _signingPolicyWeight = _sqrt(_signingPolicyWeight + wNatCappedWeight);
        _signingPolicyWeight *= _sqrt(_signingPolicyWeight);

        emit VoterRegistrationInfo(
            _voter,
            _rewardEpochId,
            wNatWeight,
            wNatCappedWeight,
            nodeIds,
            nodeWeights,
            delegationFeeBIPS
        );
    }

    /**
     * Sets the WNat cap used in signing policy weight
     * @dev Only governance can call this method.
     */
    function setWNatCapPPM(uint24 _wNatCapPPM) external onlyGovernance {
        require(_wNatCapPPM <= PPM_MAX, "_wNatCapPPM too high");
        wNatCapPPM = _wNatCapPPM;
    }

    function sqrt(uint256 x) external pure returns (uint128) {
        return _sqrt(x);
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
        entityManager = EntityManager(_getContractAddress(_contractNameHashes, _contractAddresses, "EntityManager"));
        wNatDelegationFee = WNatDelegationFee(
            _getContractAddress(_contractNameHashes, _contractAddresses, "WNatDelegationFee"));
        voterRegistry = VoterRegistry(_getContractAddress(_contractNameHashes, _contractAddresses, "VoterRegistry"));
        pChainStakeMirror = IPChainStakeMirror(
            _getContractAddress(_contractNameHashes, _contractAddresses, "PChainStakeMirror"));
        wNat = IWNat(_getContractAddress(_contractNameHashes, _contractAddresses, "WNat"));
    }

    // https://ethereum-magicians.org/t/eip-7054-gas-efficient-square-root-calculation-with-binary-search-approach
    function _sqrt(uint256 x) internal pure returns (uint128) {
        if (x == 0) return 0;
        else{
            uint256 xx = x;
            uint256 r = 1;
            if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
            if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
            if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
            if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
            if (xx >= 0x100) { xx >>= 8; r <<= 4; }
            if (xx >= 0x10) { xx >>= 4; r <<= 2; }
            if (xx >= 0x4) { r <<= 1; }
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            r = (r + x / r) >> 1;
            uint256 r1 = x / r;
            return uint128(r < r1 ? r : r1);
        }
    }
}
