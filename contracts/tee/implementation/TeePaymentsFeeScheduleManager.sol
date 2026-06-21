// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { FlareUpgradeableBase } from "../../governance/implementation/FlareUpgradeableBase.sol";
import { IIFlareTeeManager } from "../interface/IIFlareTeeManager.sol";
import {
    IITeePaymentsFeeScheduleManager
} from "../interface/IITeePaymentsFeeScheduleManager.sol";
import { ITeePayments } from "../../userInterfaces/tee/ITeePayments.sol";
import { ITeePaymentsBase } from "../../userInterfaces/tee/ITeePaymentsBase.sol";
import {
    DEFAULT_FEE_SCHEDULE,
    ITeePaymentsFeeScheduleManager
} from "../../userInterfaces/tee/ITeePaymentsFeeScheduleManager.sol";
import { PaymentModel } from "../../userInterfaces/tee/ITeePaymentsModel.sol";
import { ITeePaymentsRegistry } from "../../userInterfaces/tee/ITeePaymentsRegistry.sol";
import { AddressUpdatable } from "../../utils/implementation/AddressUpdatable.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * TeePaymentsFeeScheduleManager — shared fee schedule registry for all TeePayments instances.
 *
 * Stores:
 *  - Per-sourceId governance configuration (max schedule entries, max delay seconds).
 *  - Per-(projectId, sourceId) default fee schedules set by the project owner.
 *  - Per-(sourceId, accountAddress) overrides set by the project owner.
 *
 * Fee schedule encoding (bytes): multiple of 4 bytes; each entry is
 *  2 bytes int16 factor (in BIPS) + 2 bytes uint16 delay (seconds from batch start).
 *
 * Account-level setters derive the projectId from the account itself (registry -> TeePayments
 * -> walletId -> projectId), so a project owner cannot stomp on another project's account
 * schedules.
 */
contract TeePaymentsFeeScheduleManager is IITeePaymentsFeeScheduleManager, FlareUpgradeableBase {

    /// FlareTeeManager Diamond contract.
    IIFlareTeeManager public flareTeeManager;
    /// Shared sourceId -> TeePayments registry.
    ITeePaymentsRegistry public teePaymentsRegistry;

    mapping(bytes32 sourceId => FeeScheduleConfig) private feeScheduleConfig;
    mapping(bytes32 projectId => mapping(bytes32 sourceId => bytes)) private projectSchedules;
    mapping(bytes32 accountHash => bytes) private accountOverrides;

    /**
     * Constructor that initializes with invalid parameters to prevent direct deployment/updates.
     */
    constructor() FlareUpgradeableBase() {}

    /**
     * Proxyable initialization method. Can be called only once, from the proxy constructor
     * (single call is assured by the `initializer` modifier).
     * @param _governanceSettings The governance settings interface.
     * @param _initialGovernance The initial governance address.
     * @param _addressUpdater The address updater contract.
     */
    function initialize(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater
    )
        external virtual
        initializer
    {
        FlareUpgradeableBase.initializeBase(_governanceSettings, _initialGovernance, _addressUpdater);
    }

    /**
     * @inheritdoc IITeePaymentsFeeScheduleManager
     */
    function setFeeScheduleConfigs(
        FeeScheduleConfigInput[] calldata _configs
    )
        external
        onlyGovernance
    {
        for (uint256 i = 0; i < _configs.length; i++) {
            FeeScheduleConfigInput calldata config = _configs[i];
            require(
                config.maxSchedules > 0 && config.maxSchedules - 1 <= config.maxDelaySeconds,
                InvalidFeeScheduleConfig(config.sourceId, config.maxSchedules, config.maxDelaySeconds)
            );
            require(
                teePaymentsRegistry.getSourcePaymentModel(config.sourceId) == PaymentModel.ACCOUNT,
                UnsupportedSourceId(config.sourceId)
            );
            feeScheduleConfig[config.sourceId] = FeeScheduleConfig({
                maxSchedules: config.maxSchedules,
                maxDelaySeconds: config.maxDelaySeconds
            });
        }
        emit FeeScheduleConfigsSet(_configs);
    }

    /**
     * @inheritdoc IITeePaymentsFeeScheduleManager
     */
    function clearFeeScheduleConfigs(
        bytes32[] calldata _sourceIds
    )
        external
        onlyGovernance
    {
        for (uint256 i = 0; i < _sourceIds.length; i++) {
            bytes32 sourceId = _sourceIds[i];
            require(feeScheduleConfig[sourceId].maxSchedules > 0, FeeScheduleConfigNotSet(sourceId));
            delete feeScheduleConfig[sourceId];
        }
        emit FeeScheduleConfigsCleared(_sourceIds);
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function setProjectFeeSchedule(
        bytes32 _projectId,
        bytes32 _sourceId,
        FeeSchedule[] calldata _schedule
    )
        external
    {
        require(_schedule.length > 0, EmptyScheduleNotAllowed());
        _checkProjectOwner(_projectId);
        // PMW payment accounts — the only consumers of project schedules — can only be registered
        // under the system extension (id 0), so a schedule on any other project would be dead state.
        require(flareTeeManager.getExtensionId(_projectId) == 0, OnlySystemExtensionId());
        bytes memory encoded = _validateAndEncodeSchedule(_sourceId, _schedule);
        projectSchedules[_projectId][_sourceId] = encoded;
        emit ProjectFeeScheduleSet(_projectId, _sourceId, _schedule);
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function clearProjectFeeSchedule(
        bytes32 _projectId,
        bytes32 _sourceId
    )
        external
    {
        _checkProjectOwner(_projectId);
        require(projectSchedules[_projectId][_sourceId].length > 0, FeeScheduleNotSet());
        delete projectSchedules[_projectId][_sourceId];
        emit ProjectFeeScheduleCleared(_projectId, _sourceId);
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function setAccountFeeSchedule(
        ITeePaymentsBase.PMWMultisigAccount calldata _account,
        FeeSchedule[] calldata _schedule
    )
        external
    {
        require(_schedule.length > 0, EmptyScheduleNotAllowed());
        bytes32 projectId = _checkAccountProjectOwner(_account);
        bytes memory encoded = _validateAndEncodeSchedule(_account.sourceId, _schedule);
        bytes32 accountHash = _toAccountHash(_account);
        accountOverrides[accountHash] = encoded;
        emit AccountFeeScheduleSet(
            projectId,
            _account.sourceId,
            _account.accountAddress,
            accountHash,
            _schedule
        );
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function clearAccountFeeSchedule(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        external
    {
        bytes32 projectId = _checkAccountProjectOwner(_account);
        bytes32 accountHash = _toAccountHash(_account);
        require(accountOverrides[accountHash].length > 0, FeeScheduleNotSet());
        delete accountOverrides[accountHash];
        emit AccountFeeScheduleCleared(
            projectId,
            _account.sourceId,
            _account.accountAddress,
            accountHash
        );
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function getEffectiveSchedule(
        bytes32 _projectId,
        bytes32 _sourceId,
        bytes32 _accountHash
    )
        external view
        returns (bytes memory _feeSchedule)
    {
        bytes storage accountOverride = accountOverrides[_accountHash];
        if (accountOverride.length > 0) {
            return accountOverride;
        }
        bytes storage projectSchedule = projectSchedules[_projectId][_sourceId];
        if (projectSchedule.length > 0) {
            return projectSchedule;
        }
        return DEFAULT_FEE_SCHEDULE;
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function validateAndEncodeSchedules(
        bytes32 _sourceId,
        int16[][] calldata _factorsBIPSPerPayment,
        uint16[] calldata _delaysSeconds
    )
        external view
        returns (bytes[] memory _encodedPerPayment)
    {
        // If governance has not configured the source, reissue is still permitted with the
        // trivial schedule shape (1 entry, delay 0, any valid non-zero factor) — this covers
        // the invalidation use case (negative factor) on sources without a custom fee policy.
        FeeScheduleConfig storage config = feeScheduleConfig[_sourceId];
        uint8 effectiveMaxSchedules = config.maxSchedules == 0 ? 1 : config.maxSchedules;
        uint16 effectiveMaxDelay = config.maxSchedules == 0 ? 0 : config.maxDelaySeconds;
        uint256 entries = _delaysSeconds.length;
        require(entries <= effectiveMaxSchedules, TooManySchedules());
        uint16 lastDelay;
        for (uint256 k = 0; k < entries; k++) {
            uint16 delay = _delaysSeconds[k];
            require(k == 0 || delay > lastDelay, InvalidFeeDelay(k));
            lastDelay = delay;
        }
        require(lastDelay <= effectiveMaxDelay, DelayTooLarge(lastDelay, effectiveMaxDelay));
        _encodedPerPayment = new bytes[](_factorsBIPSPerPayment.length);
        for (uint256 i = 0; i < _factorsBIPSPerPayment.length; i++) {
            int16[] calldata factors = _factorsBIPSPerPayment[i];
            require(factors.length == entries, LengthsMismatch());
            bytes memory encoded = new bytes(entries * 4);
            for (uint256 k = 0; k < entries; k++) {
                int16 factor = factors[k];
                require(-10000 <= factor && factor <= 10000 && factor != 0, InvalidFeeFactor(k));
                uint16 delay = _delaysSeconds[k];
                uint256 offset = k * 4;
                encoded[offset] = bytes1(uint8(uint16(factor) >> 8));
                encoded[offset + 1] = bytes1(uint8(uint16(factor)));
                encoded[offset + 2] = bytes1(uint8(delay >> 8));
                encoded[offset + 3] = bytes1(uint8(delay));
            }
            _encodedPerPayment[i] = encoded;
        }
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function getProjectFeeSchedule(
        bytes32 _projectId,
        bytes32 _sourceId
    )
        external view
        returns (FeeSchedule[] memory _schedule)
    {
        _schedule = _decodeSchedule(projectSchedules[_projectId][_sourceId]);
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function getAccountFeeSchedule(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        external view
        returns (FeeSchedule[] memory _schedule)
    {
        _schedule = _decodeSchedule(accountOverrides[_toAccountHash(_account)]);
    }

    /**
     * @inheritdoc ITeePaymentsFeeScheduleManager
     */
    function getFeeScheduleConfig(
        bytes32 _sourceId
    )
        external view
        returns (FeeScheduleConfig memory _config)
    {
        _config = feeScheduleConfig[_sourceId];
    }

    /**
     * @inheritdoc AddressUpdatable
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal virtual override
    {
        flareTeeManager = IIFlareTeeManager(
            _getContractAddress(_contractNameHashes, _contractAddresses, "FlareTeeManager"));
        teePaymentsRegistry = ITeePaymentsRegistry(
            _getContractAddress(_contractNameHashes, _contractAddresses, "TeePaymentsRegistry"));
    }

    function _checkProjectOwner(
        bytes32 _projectId
    )
        internal view
    {
        require(flareTeeManager.getOwner(_projectId) == msg.sender, OnlyProjectOwner());
    }

    function _checkAccountProjectOwner(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        internal view
        returns (bytes32 _projectId)
    {
        address teePayments = teePaymentsRegistry.getTeePaymentsForSource(_account.sourceId);
        require(teePayments != address(0), UnsupportedSourceId(_account.sourceId));
        bytes32 walletId = ITeePayments(teePayments).getWalletId(_account);
        require(walletId != bytes32(0), AccountNotRegistered());
        _projectId = flareTeeManager.getWalletProjectId(walletId);
        require(flareTeeManager.getOwner(_projectId) == msg.sender, OnlyProjectOwner());
    }

    function _validateAndEncodeSchedule(
        bytes32 _sourceId,
        FeeSchedule[] calldata _schedule
    )
        internal view
        returns (bytes memory _encoded)
    {
        FeeScheduleConfig storage config = feeScheduleConfig[_sourceId];
        require(config.maxSchedules > 0, SourceLimitsNotConfigured(_sourceId));
        require(_schedule.length <= config.maxSchedules, TooManySchedules());
        uint16 lastDelay;
        _encoded = new bytes(_schedule.length * 4);
        for (uint256 i = 0; i < _schedule.length; i++) {
            int16 factor = _schedule[i].factorBIPS;
            uint16 delay = _schedule[i].delaySeconds;
            require(-10000 <= factor && factor <= 10000 && factor != 0, InvalidFeeFactor(i));
            require(i == 0 || delay > lastDelay, InvalidFeeDelay(i));
            lastDelay = delay;
            uint256 offset = i * 4;
            _encoded[offset] = bytes1(uint8(uint16(factor) >> 8));
            _encoded[offset + 1] = bytes1(uint8(uint16(factor)));
            _encoded[offset + 2] = bytes1(uint8(delay >> 8));
            _encoded[offset + 3] = bytes1(uint8(delay));
        }
        require(lastDelay <= config.maxDelaySeconds, DelayTooLarge(lastDelay, config.maxDelaySeconds));
    }

    function _decodeSchedule(
        bytes storage _feeSchedule
    )
        internal view
        returns (FeeSchedule[] memory _schedule)
    {
        uint256 length = _feeSchedule.length / 4;
        _schedule = new FeeSchedule[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 offset = i * 4;
            int16 factor = int16(uint16(uint8(_feeSchedule[offset])) << 8 | uint16(uint8(_feeSchedule[offset + 1])));
            uint16 delay = uint16(uint8(_feeSchedule[offset + 2])) << 8 | uint16(uint8(_feeSchedule[offset + 3]));
            _schedule[i] = FeeSchedule({ factorBIPS: factor, delaySeconds: delay });
        }
    }

    function _toAccountHash(
        ITeePaymentsBase.PMWMultisigAccount calldata _account
    )
        internal pure
        returns (bytes32)
    {
        return keccak256(abi.encode(_account.sourceId, _account.accountAddress));
    }
}
