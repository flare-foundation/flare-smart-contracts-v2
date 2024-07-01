// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interface/IFdcHub.sol";
import "../../protocol/implementation/RewardOffersManagerBase.sol";

contract FdcHub is IFdcHub {
// contract FdcHub is RewardOffersManagerBase, IFdcHub {
    uint256 public constant MINIMAL_FEE = 1 wei;

    mapping(bytes32 => uint256) public typeAndSourcePrices;

    // /**
    //  * Constructor.
    //  * @param _governanceSettings The address of the GovernanceSettings contract.
    //  * @param _initialGovernance The initial governance address.
    //  * @param _addressUpdater The address of the AddressUpdater contract.
    //  */
    // constructor(
    //     IGovernanceSettings _governanceSettings,
    //     address _initialGovernance,
    //     address _addressUpdater
    // )
    //     RewardOffersManagerBase(_governanceSettings, _initialGovernance, _addressUpdater)
    // { }

    function requestAttestation(bytes calldata _data) external payable {
        require(msg.value >= MINIMAL_FEE, "fee to low");

        emit AttestationRequest(_data, msg.value);
    }

    // TODO: add governance
    function setTypeAndSourcePrice(bytes32 _type, bytes32 _source, uint256 _price) external {
        typeAndSourcePrices[__joinTypeAndSource(_type, _source)] = _price;
        emit TypeAndSourcePriceSet(_type, _source, _price);
    }

    function getBaseFee(bytes calldata _data) external view returns (uint256) {
        require(_data.length >= 64, "Request data too short, shoudl at least specify type and source");
        bytes32 _type = abi.decode(_data[:32], (bytes32));
        bytes32 _source = abi.decode(_data[32:64], (bytes32));
        return _getTypeAndSourcePrice(_type, _source);
    }

    function _getTypeAndSourcePrice(bytes32 _type, bytes32 _source) internal view returns (uint256 value) {
        value = typeAndSourcePrices[ __joinTypeAndSource(_type, _source)];
        if (value == 0) {
            value = MINIMAL_FEE;
        }
    }

    function __joinTypeAndSource(bytes32 _type, bytes32 _source) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_type, _source));
    }

}