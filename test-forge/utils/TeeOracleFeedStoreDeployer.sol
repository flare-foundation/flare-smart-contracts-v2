// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    TeeOracleFeedStore
} from "../../contracts/tee/extensions/oracle/implementation/TeeOracleFeedStore.sol";
import {
    TeeOracleFeedStoreProxy
} from "../../contracts/tee/extensions/oracle/proxy/TeeOracleFeedStoreProxy.sol";
import {
    ITeeOracleFeedStore
} from "../../contracts/userInterfaces/tee/ITeeOracleFeedStore.sol";
import {
    ITeeOracleInstructionsSender
} from "../../contracts/userInterfaces/tee/ITeeOracleInstructionsSender.sol";
import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";

/**
 * @title TeeOracleFeedStoreDeployer
 * @notice Deploys a TeeOracleFeedStore implementation plus its UUPS proxy for tests.
 * @dev A deployed helper rather than a library, deliberately: Forge rewrites every `new`
 *      expression in a test file into generated argument-encoding code, and the feed store
 *      proxy's constructor is wide enough that this hits a Yul stack limit inside a large test
 *      contract (an `internal` library function would not help - it is inlined into the caller).
 *      Behind an external call the construction is compiled in this contract's own code instead.
 */
contract TeeOracleFeedStoreDeployer {

    function deploy(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance,
        address _addressUpdater,
        ITeeOracleInstructionsSender _instructionsSender,
        bytes21 _feedId,
        address _feeDestination,
        ITeeOracleFeedStore.SubmissionPolicy calldata _submissionPolicy
    )
        external
        returns (TeeOracleFeedStore _feedStore)
    {
        TeeOracleFeedStore implementation = new TeeOracleFeedStore();
        TeeOracleFeedStoreProxy proxy = new TeeOracleFeedStoreProxy(
            _governanceSettings,
            _initialGovernance,
            _addressUpdater,
            _instructionsSender,
            _feedId,
            _feeDestination,
            _submissionPolicy,
            address(implementation)
        );
        return TeeOracleFeedStore(address(proxy));
    }
}
