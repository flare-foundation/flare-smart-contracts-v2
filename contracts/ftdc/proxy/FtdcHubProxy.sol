// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { FtdcHub } from "../implementation/FtdcHub.sol";

contract FtdcHubProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint16 _minThresholdBIPS,
        uint8 _defaultNumberOfTees,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                FtdcHub.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater,
                    _minThresholdBIPS,
                    _defaultNumberOfTees
                )
            )
        )
    { }
}