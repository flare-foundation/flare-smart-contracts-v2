// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import "./TeeExtensionRegistry.sol";

contract TeeExtensionRegistryProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeeExtensionRegistry.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater
                )
            )
        )
    { }
}