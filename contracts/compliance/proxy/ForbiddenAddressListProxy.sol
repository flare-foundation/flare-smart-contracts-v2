// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { ForbiddenAddressList } from "../implementation/ForbiddenAddressList.sol";
import { IExternalNetwork } from "../../userInterfaces/IExternalNetwork.sol";

contract ForbiddenAddressListProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        IExternalNetwork.Network _network,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                ForbiddenAddressList.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater,
                    _network
                )
            )
        )
    { }
}
