// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import {
    ITeeOracleInstructionsSender
} from "../../../../userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import { TeeOracleFeedStore } from "../implementation/TeeOracleFeedStore.sol";


contract TeeOracleFeedStoreProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        ITeeOracleInstructionsSender _instructionsSender,
        bytes21 _feedId,
        address _feeDestination,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeeOracleFeedStore.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater,
                    _instructionsSender,
                    _feedId,
                    _feeDestination
                )
            )
        )
    { }
}
