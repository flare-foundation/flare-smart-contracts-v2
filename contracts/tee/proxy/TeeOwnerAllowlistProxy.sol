// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import "../implementation/TeeOwnerAllowlist.sol";

contract TeeOwnerAllowlistProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeeOwnerAllowlist.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater
                )
            )
        )
    { }
}