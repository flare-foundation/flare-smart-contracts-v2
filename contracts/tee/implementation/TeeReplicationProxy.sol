// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import "./TeeReplication.sol";

contract TeeReplicationProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint256 _pauseBeforeUpgradeMinDurationSeconds,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeeReplication.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater,
                    _pauseBeforeUpgradeMinDurationSeconds
                )
            )
        )
    { }
}