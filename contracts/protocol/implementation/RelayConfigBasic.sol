// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IIRelayConfig.sol";

/**
 * Basic relay config contract.
 */
contract RelayConfigBasic is IIRelayConfig {

    uint256 public feeWei;
    address payable public feeCollectionAddressInternal;
    mapping(address => bool) public hasZeroFee;
    mapping(address => bool) public merkleRootGetters;
    mapping(address => bool) public signingPolicyGetters;
    mapping(address => bool) public signingPolicySetters;
    address private deployer;
    bool public isInProduction;

    modifier onlyIfNotInProduction() {
        require(msg.sender == deployer, "only deployer");
        require(!isInProduction, "only if not in production");
        _;
    }

    constructor(
        uint256 _feeWei,
        address payable _feeCollectionAddress,
        address[] memory _zeroFeeAddresses,
        address[] memory _merkleRootGetters,
        address[] memory _signingPolicyGetters,
        address[] memory _signingPolicySetters
    ) {
        deployer = msg.sender;
        feeWei = _feeWei;
        feeCollectionAddressInternal = payable(_feeCollectionAddress);
        isInProduction = false;
        for (uint256 i = 0; i < _zeroFeeAddresses.length; i++) {
            hasZeroFee[_zeroFeeAddresses[i]] = true;
        }
        for (uint256 i = 0; i < _merkleRootGetters.length; i++) {
            merkleRootGetters[_merkleRootGetters[i]] = true;
        }
        for (uint256 i = 0; i < _signingPolicyGetters.length; i++) {
            signingPolicyGetters[_signingPolicyGetters[i]] = true;
        }
        for (uint256 i = 0; i < _signingPolicySetters.length; i++) {
            signingPolicySetters[_signingPolicySetters[i]] = true;
        }
    }

    /**
     * @inheritdoc IIRelayConfig
     */
    function requiredFee(address _sender) external view returns (uint256 _minFeeInWei) {
        if (hasZeroFee[_sender]) {
            return 0;
        }
        return feeWei;
    }

    /**
     * @inheritdoc IIRelayConfig
     */
    function feeCollectionAddress() external view returns (address payable) {
        return feeCollectionAddressInternal;
    }

    function changeFeeCollectionAddress(address payable _feeCollectionAddress) external {
        feeCollectionAddressInternal = _feeCollectionAddress;
    }

    /**
     * @inheritdoc IIRelayConfig
     */
    function canGetMerkleRoot(address _sender) external view returns (bool) {
        return merkleRootGetters[_sender];
    }

    function addMerkleTreeGetter(address _merkleRootGetter) external onlyIfNotInProduction {
        merkleRootGetters[_merkleRootGetter] = true;
    }

    /**
     * @inheritdoc IIRelayConfig
     */
    function canGetSigningPolicy(address _sender) external view returns (bool) {
        return signingPolicyGetters[_sender];
    }

    function addSigningPolicyGetter(address _signingPolicyGetter) external onlyIfNotInProduction {
        signingPolicyGetters[_signingPolicyGetter] = true;
    }

    /**
     * @inheritdoc IIRelayConfig
     */
    function canSetSigningPolicy(address _sender) external view returns (bool) {
        return signingPolicySetters[_sender];
    }

    function addSigningPolicySetter(address _signingPolicySetter) external onlyIfNotInProduction {
        signingPolicySetters[_signingPolicySetter] = true;
    }

    function setInProduction() external onlyIfNotInProduction {
        isInProduction = true;
    }

}