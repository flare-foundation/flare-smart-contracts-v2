// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";
import { TeeVerification } from "../implementation/TeeVerification.sol";

contract TeeVerificationProxy is ERC1967Proxy {
    constructor(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        uint64 _availabilityCheckValidityDurationSeconds,
        uint24 _signingPolicyValidityDurationInRewardEpochs,
        uint64 _challengeValidityDurationSeconds,
        address _implementationAddress
    )
        ERC1967Proxy(_implementationAddress,
            abi.encodeCall(
                TeeVerification.initialize,
                (
                    _governanceSettings,
                    _initialGovernance,
                    _addressUpdater,
                    _availabilityCheckValidityDurationSeconds,
                    _signingPolicyValidityDurationInRewardEpochs,
                    _challengeValidityDurationSeconds
                )
            )
        )
    { }
}