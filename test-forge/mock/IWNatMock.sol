// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../contracts/userInterfaces/IWNat.sol";
import "flare-smart-contracts/contracts/token/interface/IIVPContract.sol";
import "flare-smart-contracts/contracts/token/interface/IIGovernanceVotePower.sol";

interface IWNatMock is IWNat {

    function setReadVpContract(IIVPContract vpContract) external;

    function setWriteVpContract(IIVPContract vpContract) external;

    function setGovernanceVotePower(IIGovernanceVotePower governanceVotePower) external;

}
