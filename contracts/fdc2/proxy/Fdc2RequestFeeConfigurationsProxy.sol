// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { Fdc2RequestFeeConfigurations } from "../implementation/Fdc2RequestFeeConfigurations.sol";

contract Fdc2RequestFeeConfigurationsProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                Fdc2RequestFeeConfigurations.initialize,
                (
                    _governanceSettings,
                    _initialGovernance
                )
            )
        )
    { }
}