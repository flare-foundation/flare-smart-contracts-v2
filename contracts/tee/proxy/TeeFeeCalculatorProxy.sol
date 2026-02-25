// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { TeeFeeCalculator } from "../implementation/TeeFeeCalculator.sol";

contract TeeFeeCalculatorProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        uint256 _defaultFee,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeeFeeCalculator.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _defaultFee
                )
            )
        )
    { }
}