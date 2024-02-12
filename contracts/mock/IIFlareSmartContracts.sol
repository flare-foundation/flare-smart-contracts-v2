// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

interface IIInflationAllocation {

    function setSharingPercentages(
        address[] memory _inflationReceivers,
        uint256[] memory _percentagePerReceiverBips
    )
        external;
}

interface IIInflation {

    enum TopupType{ FACTOROFDAILYAUTHORIZED, ALLAUTHORIZED }

    function setTopupConfiguration(
        address _inflationReceiver,
        TopupType _topupType,
        uint256 _topupFactorX100
    )
        external;
}

interface IIFlareDaemon {

    struct Registration {
        address daemonizedContract;
        uint256 gasLimit;
    }

    function registerToDaemonize(Registration[] memory _registrations) external;
}

interface IISupply {

    function addTokenPool(
        address _tokenPool,
        uint256 _increaseDistributedSupplyByAmountWei
    )
        external;
}
