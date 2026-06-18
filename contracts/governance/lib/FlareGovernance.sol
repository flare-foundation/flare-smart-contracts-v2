// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import { IGovernanceSettings } from "@flarenetwork/flare-periphery-contracts/flare/IGovernanceSettings.sol";
import { IFlareGovernance } from "../../userInterfaces/IFlareGovernance.sol";

/**
 * @title FlareGovernance
 * @notice Library implementing Flare governance with hash-based timelock.
 * @dev Uses ERC-7201 namespaced storage so all contracts sharing a delegatecall
 *      context (Diamond facets) — or a single UUPS implementation — access the
 *      same governance state without inheriting public functions.
 *
 *      Hash-based timelock: only the keccak256 hash of the encoded call is stored on-chain.
 *      At execution time the executor provides the full calldata which is verified against
 *      the stored hash. This is cheaper than storing the full encoded call.
 *
 *      Events and errors are defined in IFlareGovernance.
 */
library FlareGovernance {

    /// @custom:storage-location erc7201:flare.FlareGovernance.State
    struct State {
        IGovernanceSettings governanceSettings;
        bool initialised;
        bool productionMode;
        bool executing;
        address initialGovernance;
        mapping(bytes32 encodedCallHash => uint256 allowedAfterTimestamp) timelockedCalls;
    }

    // ERC-7201 namespaced storage slot
    // erc7201 builtin not recognized by slither's parser; the constant is initialized at declaration
    //slither-disable-next-line uninitialized-state
    bytes32 private constant STATE_POSITION = bytes32(erc7201("flare.FlareGovernance.State"));

    /**
     * Initialize governance. Can only be called once.
     */
    function initialise(
        IGovernanceSettings _governanceSettings,
        address _initialGovernance
    )
        internal
    {
        State storage state = getState();
        require(!state.initialised, IFlareGovernance.GovernedAlreadyInitialized());
        require(address(_governanceSettings) != address(0), IFlareGovernance.GovernedAddressZero());
        require(_initialGovernance != address(0), IFlareGovernance.GovernedAddressZero());
        state.initialised = true;
        state.governanceSettings = _governanceSettings;
        state.initialGovernance = _initialGovernance;
        emit IFlareGovernance.GovernanceInitialised(_initialGovernance);
    }

    /**
     * Called at the start of an onlyGovernance-guarded function.
     * If executing (re-entry from executeGovernanceCall), allows through.
     * If not in production mode, checks governance.
     * If in production mode, records the timelocked call hash.
     * @return _execute True if the guarded function body should execute.
     */
    function beforeOnlyGovernance()
        internal
        returns (bool _execute)
    {
        State storage state = getState();
        if (state.executing || !state.productionMode) {
            _beforeExecute(state);
            return true;
        } else {
            _recordTimelockedCall(state, msg.data);
            return false;
        }
    }

    /**
     * Execute a timelocked governance call.
     * @param _encodedCall The full encoded call data (hash verified against stored hash).
     */
    function executeGovernanceCall(
        bytes calldata _encodedCall
    )
        internal
    {
        State storage state = getState();
        require(isExecutor(msg.sender), IFlareGovernance.OnlyExecutor());
        bytes32 callHash = keccak256(_encodedCall);
        uint256 allowedAfterTimestamp = state.timelockedCalls[callHash];
        require(allowedAfterTimestamp != 0, IFlareGovernance.TimelockInvalidSelector());
        require(block.timestamp >= allowedAfterTimestamp, IFlareGovernance.TimelockNotAllowedYet());
        delete state.timelockedCalls[callHash];
        state.executing = true;
        //solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(this).call(_encodedCall);
        state.executing = false;
        emit IFlareGovernance.TimelockedGovernanceCallExecuted(callHash);
        _passReturnOrRevert(success);
    }

    /**
     * Cancel a timelocked governance call.
     * @param _encodedCall The full encoded call data to cancel.
     */
    function cancelGovernanceCall(
        bytes calldata _encodedCall
    )
        internal
    {
        checkOnlyGovernance();
        State storage state = getState();
        bytes32 callHash = keccak256(_encodedCall);
        require(state.timelockedCalls[callHash] != 0, IFlareGovernance.TimelockInvalidSelector());
        delete state.timelockedCalls[callHash];
        emit IFlareGovernance.TimelockedGovernanceCallCanceled(callHash);
    }

    /**
     * Enter production mode (enables timelocks).
     */
    function switchToProductionMode()
        internal
    {
        checkOnlyGovernance();
        State storage state = getState();
        require(!state.productionMode, IFlareGovernance.AlreadyInProductionMode());
        state.initialGovernance = address(0);
        state.productionMode = true;
        emit IFlareGovernance.GovernedProductionModeEntered(address(state.governanceSettings));
    }

    /**
     * Returns the governance settings contract.
     */
    function governanceSettings()
        internal view
        returns (IGovernanceSettings)
    {
        return getState().governanceSettings;
    }

    /**
     * True after switching to production mode.
     */
    function productionMode()
        internal view
        returns (bool)
    {
        return getState().productionMode;
    }

    /**
     * Returns the current effective governance address.
     */
    function governance()
        internal view
        returns (address)
    {
        State storage state = getState();
        return state.productionMode ? state.governanceSettings.getGovernanceAddress() : state.initialGovernance;
    }

    /**
     * Check that msg.sender is governance.
     */
    function checkOnlyGovernance()
        internal view
    {
        require(msg.sender == governance(), IFlareGovernance.OnlyGovernance());
    }

    /**
     * Check if an address is an executor.
     */
    function isExecutor(
        address _address
    )
        internal view
        returns (bool)
    {
        State storage state = getState();
        return state.initialised && state.governanceSettings.isExecutor(_address);
    }

    // =========================================================================
    // Private helpers
    // =========================================================================

    function _beforeExecute(
        State storage _state
    )
        private
    {
        if (_state.executing) {
            // can only be run from executeGovernanceCall(), where we check that only executor can call
            // make sure nothing else gets executed, even in case of reentrancy
            assert(msg.sender == address(this));
            _state.executing = false;
        } else {
            // must be called with: productionMode=false
            // must check governance in this case
            checkOnlyGovernance();
        }
    }

    function _recordTimelockedCall(
        State storage _state,
        bytes calldata _data
    )
        private
    {
        checkOnlyGovernance();
        uint256 timelock = _state.governanceSettings.getTimelock();
        uint256 allowedAt = block.timestamp + timelock;
        bytes32 callHash = keccak256(_data);
        _state.timelockedCalls[callHash] = allowedAt;
        emit IFlareGovernance.GovernanceCallTimelocked(_data, callHash, allowedAt);
    }

    /**
     * @dev Private — outside callers must use the dedicated accessor functions above.
     *      Mirrors the encapsulation of legacy `GovernedBase`'s private state vars and
     *      OZ `Initializable._getInitializableStorage`.
     */
    function getState()
        private pure
        returns (State storage _state)
    {
        bytes32 position = STATE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _state.slot := position
        }
    }

    function _passReturnOrRevert(
        bool _success
    )
        private pure
    {
        // pass exact return or revert data - needs to be done in assembly
        //solhint-disable-next-line no-inline-assembly
        assembly {
            let size := returndatasize()
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, size))
            returndatacopy(ptr, 0, size)
            if _success {
                return(ptr, size)
            }
            revert(ptr, size)
        }
    }
}
