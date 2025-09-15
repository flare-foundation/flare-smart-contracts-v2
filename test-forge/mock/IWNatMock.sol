// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import { IWNat } from "../../contracts/userInterfaces/IWNat.sol";
import { IIVPContract } from "@flarenetwork/flare-periphery-contracts/flare/token/interfaces/IIVPContract.sol";
import { IIGovernanceVotePower } from "@flarenetwork/flare-periphery-contracts/flare/token/interfaces/IIGovernanceVotePower.sol";

interface IWNatMock is IWNat {

    function setReadVpContract(IIVPContract vpContract) external;

    function setWriteVpContract(IIVPContract vpContract) external;

    function setGovernanceVotePower(IIGovernanceVotePower governanceVotePower) external;

}
