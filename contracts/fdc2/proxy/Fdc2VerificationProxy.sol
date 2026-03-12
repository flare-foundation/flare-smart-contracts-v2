// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { Fdc2Verification } from "../implementation/Fdc2Verification.sol";

contract Fdc2VerificationProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                Fdc2Verification.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater
                )
            )
        )
    { }
}