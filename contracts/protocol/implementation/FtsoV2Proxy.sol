// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/songbird/IGovernanceSettings.sol";
import { FtsoV2 } from "./FtsoV2.sol";


contract FtsoV2Proxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                FtsoV2.initialize,
                (_governanceSettings, _initialGovernance, _addressUpdater)
            )
        )
    { }
}
