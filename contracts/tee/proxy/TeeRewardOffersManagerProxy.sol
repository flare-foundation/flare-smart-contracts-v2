// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { TeeRewardOffersManager } from "../implementation/TeeRewardOffersManager.sol";

contract TeeRewardOffersManagerProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint24 _teeOwnersPPM,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeeRewardOffersManager.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater,
                    _teeOwnersPPM
                )
            )
        )
    { }
}
