// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { Fdc2InflationConfigurations } from "../implementation/Fdc2InflationConfigurations.sol";

contract Fdc2InflationConfigurationsProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                Fdc2InflationConfigurations.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater
                )
            )
        )
    { }
}
