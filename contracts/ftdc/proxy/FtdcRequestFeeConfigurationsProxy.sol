// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { FtdcRequestFeeConfigurations } from "../implementation/FtdcRequestFeeConfigurations.sol";

contract FtdcRequestFeeConfigurationsProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                FtdcRequestFeeConfigurations.initialize,
                (
                    _governanceSettings,
                    _initialGovernance
                )
            )
        )
    { }
}