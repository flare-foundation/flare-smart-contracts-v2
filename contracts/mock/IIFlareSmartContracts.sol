// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface IIInflationAllocationGovernance {

    function setSharingPercentages(
        address[] memory _inflationReceivers,
        uint256[] memory _percentagePerReceiverBips
    )
        external;
}

interface IIInflationGovernance {

    enum TopupType{ FACTOROFDAILYAUTHORIZED, ALLAUTHORIZED }

    function setTopupConfiguration(
        address _inflationReceiver,
        TopupType _topupType,
        uint256 _topupFactorX100
    )
        external;
}

interface IIFlareDaemonGovernance {

    struct Registration {
        address daemonizedContract;
        uint256 gasLimit;
    }

    function registerToDaemonize(Registration[] memory _registrations) external;
}

interface IISupplyGovernance {

    function addTokenPool(
        address _tokenPool,
        uint256 _increaseDistributedSupplyByAmountWei
    )
        external;
}
