// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IUpgradeManagerFacet } from "../../userInterfaces/tee/IUpgradeManagerFacet.sol";
import { ITeeCommonErrors } from "../../userInterfaces/tee/ITeeCommonErrors.sol";
import { Signature } from "../../userInterfaces/ISignature.sol";

/**
 * @title UpgradeManager
 * @notice Library for managing TEE upgrade versions.
 * @dev Uses ERC-7201 namespaced storage.
 */
library UpgradeManager {

    struct TeeUpgradePathState {
        IUpgradeManagerFacet.TeeUpgradePath upgradePath;
        mapping(bytes32 sourceTeeNodeVersionHash => bool) sourceTeeNodeVersionExists;
        mapping(bytes32 targetTeeNodeVersionHash => bool) targetTeeNodeVersionExists;
    }

    struct TeeUpgrade {
        uint256 extensionId;
        bytes32 sourceTeeGovernanceHash;
        Signature[] sourceTeeGovernanceSignatures;
        mapping(address => bool) sourceTeeGovernanceSigners;
        bytes32 targetTeeGovernanceHash;
        Signature[] targetTeeGovernanceSignatures;
        mapping(address => bool) targetTeeGovernanceSigners;
        TeeUpgradePathState[] upgradePaths;
        /// keccak256(abi.encode(upgrade paths)), set when upgrade is finalized -> enables signing
        bytes32 messageHash;
        bool upgradeSigned;
    }

    /// @custom:storage-location erc7201:tee.UpgradeManager.State
    struct State {
        TeeUpgrade[] teeUpgrades;
    }

    bytes32 internal constant STATE_POSITION = keccak256(
        abi.encode(uint256(keccak256("tee.UpgradeManager.State")) - 1)
    ) & ~bytes32(uint256(0xff));

    function isTeeUpgradePathValid(
        uint256 _teeUpgradeId,
        uint256 _extensionId,
        bytes32 _sourceCodeHash,
        bytes32 _sourcePlatform,
        bytes32 _targetCodeHash,
        bytes32 _targetPlatform
    )
        internal view
        returns (bool)
    {
        State storage s = getState();
        require(_teeUpgradeId < s.teeUpgrades.length, IUpgradeManagerFacet.InvalidUpgradeId());
        TeeUpgrade storage teeUpgrade = s.teeUpgrades[_teeUpgradeId];
        require(_extensionId == teeUpgrade.extensionId, ITeeCommonErrors.ExtensionIdMismatch());
        require(teeUpgrade.messageHash != bytes32(0), IUpgradeManagerFacet.UpgradeNotFinalized());
        bytes32 sourceVersionHash = keccak256(
            abi.encode(IUpgradeManagerFacet.TeeNodeVersion(_sourceCodeHash, _sourcePlatform))
        );
        bytes32 targetVersionHash = keccak256(
            abi.encode(IUpgradeManagerFacet.TeeNodeVersion(_targetCodeHash, _targetPlatform))
        );
        for (uint256 i = 0; i < teeUpgrade.upgradePaths.length; i++) {
            TeeUpgradePathState storage upgradePathState = teeUpgrade.upgradePaths[i];
            if (upgradePathState.sourceTeeNodeVersionExists[sourceVersionHash] &&
                upgradePathState.targetTeeNodeVersionExists[targetVersionHash])
            {
                return true;
            }
        }
        return false;
    }

    function isTeeUpgradeSigned(
        uint256 _teeUpgradeId
    )
        internal view
        returns (bool)
    {
        State storage s = getState();
        require(_teeUpgradeId < s.teeUpgrades.length, IUpgradeManagerFacet.InvalidUpgradeId());
        return s.teeUpgrades[_teeUpgradeId].upgradeSigned;
    }

    function getState()
        internal pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }
}
