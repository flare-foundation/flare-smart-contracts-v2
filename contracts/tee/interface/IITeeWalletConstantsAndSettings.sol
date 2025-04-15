// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9;

import "../../userInterfaces/tee/ITeeWalletOpTypeSettings.sol";
import "./IITeeWalletOpTypeConstants.sol";

interface IITeeWalletConstantsAndSettings is ITeeWalletOpTypeSettings, IITeeWalletOpTypeConstants {}
