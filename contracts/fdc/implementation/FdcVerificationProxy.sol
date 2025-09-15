// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/songbird/IGovernanceSettings.sol";
import { FdcVerification } from "./FdcVerification.sol";


contract FdcVerificationProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint8 _fdcProtocolId,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                FdcVerification.initialize,
                (_governanceSettings, _initialGovernance, _addressUpdater, _fdcProtocolId)
            )
        )
    { }
}
