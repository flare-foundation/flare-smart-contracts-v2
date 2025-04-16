// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import "./TeePaymentsEVM.sol";

contract TeePaymentsEVMProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _maxBatchSize,
        uint64 _maxBatchDurationSeconds,
        bytes32 _opType,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeePaymentsEVM.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater,
                    _maxBatchSize,
                    _maxBatchDurationSeconds,
                    _opType
                )
            )
        )
    { }
}