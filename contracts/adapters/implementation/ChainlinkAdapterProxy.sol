// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { ChainlinkAdapter } from "./ChainlinkAdapter.sol";


contract ChainlinkAdapterProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        bytes21 _ftsoFeedId,
        uint64 _staleTimeSeconds,
        string memory _description,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                ChainlinkAdapter.initialize,
                (_governanceSettings, _initialGovernance, _ftsoFeedId, _staleTimeSeconds, _description)
            )
        )
    { }
}
