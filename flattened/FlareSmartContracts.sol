// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

// Sources flattened with hardhat v2.4.3 https://hardhat.org

// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v3.4.0



/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// File contracts/extra-imports.sol



// File contracts/userInterfaces/IGovernanceSettings.sol



/**
 * Interface for the `GovernanceSettings` that hold the Flare governance address and its timelock.
 *
 * All governance calls are delayed by the timelock specified in this contract.
 *
 * **NOTE**: This contract enables updating the governance address and timelock only
 * by hard-forking the network, meaning only by updating validator code.
 */
interface IGovernanceSettings {
    /**
     * Gets the governance account address.
     * The governance address can only be changed by a hard fork.
     * @return _address The governance account address.
     */
    function getGovernanceAddress() external view returns (address _address);

    /**
     * Gets the time in seconds that must pass between a governance call and its execution.
     * The timelock value can only be changed by a hard fork.
     * @return _timelock Time in seconds that passes between the governance call and execution.
     */
    function getTimelock() external view returns (uint256 _timelock);

    /**
     * Gets the addresses of the accounts that are allowed to execute the timelocked governance calls,
     * once the timelock period expires.
     * Executors can be changed without a hard fork, via a normal governance call.
     * @return _addresses Array of executor addresses.
     */
    function getExecutors() external view returns (address[] memory _addresses);

    /**
     * Checks whether an address is one of the allowed executors. See `getExecutors`.
     * @param _address The address to check.
     * @return True if `_address` is in the executors list.
     */
    function isExecutor(address _address) external view returns (bool);
}


// File contracts/genesis/implementation/GovernanceSettings.sol

// (c) 2021, Flare Networks Limited. All rights reserved.
// Please see the file LICENSE for licensing terms.


/**
 * A special contract that holds the Flare governance address and its timelock.
 *
 * All governance calls are delayed by the timelock specified in this contract.
 *
 * This contract enables updating governance address and timelock only by hard-forking the network,
 * this is, only by updating validator code.
 */
contract GovernanceSettings is IGovernanceSettings {

    address public constant SIGNAL_COINBASE = address(0x00000000000000000000000000000000000dEAD0);

    uint256 internal constant MAX_TIMELOCK = 365 days;

    address internal constant GENESIS_GOVERNANCE = 0xfffEc6C83c8BF5c3F4AE0cCF8c45CE20E4560BD7;

    // governance address set by the validator (set in initialise call, can be changed by fork)
    address private governanceAddress;

    // global timelock setting (in seconds), also set by validator (set in initialise call, can be changed by fork)
    uint64 private timelock;

    // prevent double initialisation
    bool private initialised;

    // executor addresses, changeable anytime by the governance
    address[] private executors;
    mapping (address => bool) private executorMap;

    /**
     * Emitted when the governance address has been changed.
     * @param timestamp Timestamp of the block where the change happened, in seconds from UNIX epoch.
     * @param oldGovernanceAddress Governance address before the change.
     * @param newGovernanceAddress Governance address after the change.
     */
    event GovernanceAddressUpdated(
        uint256 timestamp,
        address oldGovernanceAddress,
        address newGovernanceAddress
    );

    /**
     * Emitted when the timelock has been changed.
     * @param timestamp Timestamp of the block where the change happened, in seconds from UNIX epoch.
     * @param oldTimelock Timelock before the change (in seconds).
     * @param newTimelock Timelock after the change (in seconds).
     */
    event GovernanceTimelockUpdated(
        uint256 timestamp,
        uint256 oldTimelock,
        uint256 newTimelock
    );

    /**
     * The list of addresses that are allowed to perform governance calls has been changed.
     * @param timestamp Timestamp of the block where the change happened, in seconds from UNIX epoch.
     * @param oldExecutors Array of executor addresses before the change.
     * @param newExecutors Array of executor addresses after the change.
     */
    event GovernanceExecutorsUpdated(
        uint256 timestamp,
        address[] oldExecutors,
        address[] newExecutors
    );

    /**
     * Perform initialization, which cannot be done in constructor, since this is a genesis contract.
     * Can only be called once.
     * @param _governanceAddress Initial governance address.
     * @param _timelock Initial timelock value, in seconds.
     * @param _executors Initial list of addresses allowed to perform governance calls.
     */
    function initialise(address _governanceAddress, uint256 _timelock, address[] memory _executors) external {
        require(msg.sender == GENESIS_GOVERNANCE, "only genesis governance");
        require(!initialised, "already initialised");
        require(_timelock < MAX_TIMELOCK, "timelock too large");
        // set the field values
        initialised = true;
        governanceAddress = _governanceAddress;
        timelock = uint64(_timelock);
        _setExecutors(_executors);
    }

    /**
     * Change the governance address.
     * Can only be called by validators via fork.
     * @param _newGovernance New governance address.
     */
    function setGovernanceAddress(address _newGovernance) external {
        require(governanceAddress != _newGovernance, "governanceAddress == _newGovernance");
        if (msg.sender == block.coinbase && block.coinbase == SIGNAL_COINBASE) {
            emit GovernanceAddressUpdated(block.timestamp, governanceAddress, _newGovernance);
            governanceAddress = _newGovernance;
        }
    }

    /**
     * Change the timelock, this is, the amount of time between a governance call and
     * its execution.
     * Can only be called by validators via fork.
     * @param _newTimelock New timelock value, in seconds.
     */
    function setTimelock(uint256 _newTimelock) external {
        require(timelock != _newTimelock, "timelock == _newTimelock");
        require(_newTimelock < MAX_TIMELOCK, "timelock too large");
        if (msg.sender == block.coinbase && block.coinbase == SIGNAL_COINBASE) {
            emit GovernanceTimelockUpdated(block.timestamp, timelock, _newTimelock);
            timelock = uint64(_newTimelock);
        }
    }

    /**
     * Set the addresses of the accounts that are allowed to execute the timelocked governance calls
     * once the timelock period expires.
     * It isn't very dangerous to allow for anyone to execute timelocked calls, but we reserve the right to
     * make sure the timing of the execution is under control.
     * Can only be called by the governance.
     * @param _newExecutors New list of allowed executors. The previous list is replaced.
     */
    function setExecutors(address[] memory _newExecutors) external {
        require(msg.sender == governanceAddress, "only governance");
        _setExecutors(_newExecutors);
    }

    /**
     * @inheritdoc IGovernanceSettings
     */
    function getGovernanceAddress() external view override returns (address) {
        return governanceAddress;
    }

    /**
     * @inheritdoc IGovernanceSettings
     */
    function getTimelock() external view override returns (uint256) {
        return timelock;
    }

    /**
     * @inheritdoc IGovernanceSettings
     */
    function getExecutors() external view override returns (address[] memory) {
        return executors;
    }

    /**
     * @inheritdoc IGovernanceSettings
     */
    function isExecutor(address _address) external view override returns (bool) {
        return executorMap[_address];
    }

    function _setExecutors(address[] memory _newExecutors) private {
        emit GovernanceExecutorsUpdated(block.timestamp, executors, _newExecutors);
        // clear old
        while (executors.length > 0) {
            executorMap[executors[executors.length - 1]] = false;
            executors.pop();
        }
        // set new
        for (uint256 i = 0; i < _newExecutors.length; i++) {
            executors.push(_newExecutors[i]);
            executorMap[_newExecutors[i]] = true;
        }
    }
}


// File @openzeppelin/contracts/math/Math.sol@v3.4.0



/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}


// File @openzeppelin/contracts/math/SafeMath.sol@v3.4.0



/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}


// File @openzeppelin/contracts/utils/SafeCast.sol@v3.4.0




/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value < 2**128, "SafeCast: value doesn\'t fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value < 2**64, "SafeCast: value doesn\'t fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value < 2**32, "SafeCast: value doesn\'t fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value < 2**16, "SafeCast: value doesn\'t fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value < 2**8, "SafeCast: value doesn\'t fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= -2**127 && value < 2**127, "SafeCast: value doesn\'t fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= -2**63 && value < 2**63, "SafeCast: value doesn\'t fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= -2**31 && value < 2**31, "SafeCast: value doesn\'t fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= -2**15 && value < 2**15, "SafeCast: value doesn\'t fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= -2**7 && value < 2**7, "SafeCast: value doesn\'t fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        require(value < 2**255, "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}


// File contracts/token/lib/CheckPointHistory.sol




/**
 * @title Check Point History library
 * @notice A contract to manage checkpoints as of a given block.
 * @dev Store value history by block number with detachable state.
 **/
library CheckPointHistory {
    using SafeMath for uint256;
    using SafeCast for uint256;

    /**
     * @dev `CheckPoint` is the structure that attaches a block number to a
     *  given value; the block number attached is the one that last changed the
     *  value
     **/
    struct CheckPoint {
        // `value` is the amount of tokens at a specific block number
        uint192 value;
        // `fromBlock` is the block number that the value was generated from
        uint64 fromBlock;
    }

    struct CheckPointHistoryState {
        // `checkpoints` is an array that tracks values at non-contiguous block numbers
        mapping(uint256 => CheckPoint) checkpoints;
        // `checkpoints` before `startIndex` have been deleted
        // INVARIANT: checkpoints.endIndex == 0 || startIndex < checkpoints.endIndex      (strict!)
        // startIndex and endIndex are both less then fromBlock, so 64 bits is enough
        uint64 startIndex;
        // the index AFTER last
        uint64 endIndex;
    }

    /**
     * @notice Binary search of _checkpoints array.
     * @param _checkpoints An array of CheckPoint to search.
     * @param _startIndex Smallest possible index to be returned.
     * @param _blockNumber The block number to search for.
     */
    function _indexOfGreatestBlockLessThan(
        mapping(uint256 => CheckPoint) storage _checkpoints, 
        uint256 _startIndex,
        uint256 _endIndex,
        uint256 _blockNumber
    )
        private view 
        returns (uint256 index)
    {
        // Binary search of the value by given block number in the array
        uint256 min = _startIndex;
        uint256 max = _endIndex.sub(1);
        while (max > min) {
            uint256 mid = (max.add(min).add(1)).div(2);
            if (_checkpoints[mid].fromBlock <= _blockNumber) {
                min = mid;
            } else {
                max = mid.sub(1);
            }
        }
        return min;
    }

    /**
     * @notice Queries the value at a specific `_blockNumber`
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _blockNumber The block number of the value active at that time
     * @return _value The value at `_blockNumber`     
     **/
    function valueAt(
        CheckPointHistoryState storage _self, 
        uint256 _blockNumber
    )
        internal view 
        returns (uint256 _value)
    {
        uint256 historyCount = _self.endIndex;

        // No _checkpoints, return 0
        if (historyCount == 0) return 0;

        // Shortcut for the actual value (extra optimized for current block, to save one storage read)
        // historyCount - 1 is safe, since historyCount != 0
        if (_blockNumber >= block.number || _blockNumber >= _self.checkpoints[historyCount - 1].fromBlock) {
            return _self.checkpoints[historyCount - 1].value;
        }
        
        // guard values at start    
        uint256 startIndex = _self.startIndex;
        if (_blockNumber < _self.checkpoints[startIndex].fromBlock) {
            // reading data before `startIndex` is only safe before first cleanup
            require(startIndex == 0, "CheckPointHistory: reading from cleaned-up block");
            return 0;
        }

        // Find the block with number less than or equal to block given
        uint256 index = _indexOfGreatestBlockLessThan(_self.checkpoints, startIndex, _self.endIndex, _blockNumber);

        return _self.checkpoints[index].value;
    }

    /**
     * @notice Queries the value at `block.number`
     * @param _self A CheckPointHistoryState instance to manage.
     * @return _value The value at `block.number`
     **/
    function valueAtNow(CheckPointHistoryState storage _self) internal view returns (uint256 _value) {
        uint256 historyCount = _self.endIndex;
        // No _checkpoints, return 0
        if (historyCount == 0) return 0;
        // Return last value
        return _self.checkpoints[historyCount - 1].value;
    }

    /**
     * @notice Writes the value at the current block.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _value Value to write.
     **/
    function writeValue(
        CheckPointHistoryState storage _self, 
        uint256 _value
    )
        internal
    {
        uint256 historyCount = _self.endIndex;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            _self.checkpoints[0] = 
                CheckPoint({ fromBlock: block.number.toUint64(), value: _toUint192(_value) });
            _self.endIndex = 1;
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            CheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                lastCheckpoint.value = _toUint192(_value);
            } else {
                // we should never have future blocks in history
                assert (block.number > lastBlock);
                // push new CheckPoint
                _self.checkpoints[historyCount] = 
                    CheckPoint({ fromBlock: block.number.toUint64(), value: _toUint192(_value) });
                _self.endIndex = uint64(historyCount + 1);  // 64 bit safe, because historyCount <= block.number
            }
        }
    }
    
    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain 
     * (unless the history was empty to start with).
     */    
    function cleanupOldCheckpoints(
        CheckPointHistoryState storage _self, 
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        if (_cleanupBlockNumber == 0) return 0;   // optimization for when cleaning is not enabled
        uint256 length = _self.endIndex;
        if (length == 0) return 0;
        uint256 startIndex = _self.startIndex;
        // length - 1 is safe, since length != 0 (check above)
        uint256 endIndex = Math.min(startIndex.add(_count), length - 1);    // last element can never be deleted
        uint256 index = startIndex;
        // we can delete `checkpoint[index]` while the next checkpoint is at `_cleanupBlockNumber` or before
        while (index < endIndex && _self.checkpoints[index + 1].fromBlock <= _cleanupBlockNumber) {
            delete _self.checkpoints[index];
            index++;
        }
        if (index > startIndex) {   // index is the first not deleted index
            _self.startIndex = index.toUint64();
        }
        return index - startIndex;  // safe: index >= startIndex at start and then increases
    }

    // SafeCast lib is missing cast to uint192    
    function _toUint192(uint256 _value) internal pure returns (uint192) {
        require(_value < 2**192, "value doesn't fit in 192 bits");
        return uint192(_value);
    }
}


// File contracts/token/lib/CheckPointsByAddress.sol



/**
 * @title Check Points By Address library
 * @notice A contract to manage checkpoint history for a collection of addresses.
 * @dev Store value history by address, and then by block number.
 **/
library CheckPointsByAddress {
    using SafeMath for uint256;
    using CheckPointHistory for CheckPointHistory.CheckPointHistoryState;

    struct CheckPointsByAddressState {
        // `historyByAddress` is the map that stores the check point history of each address
        mapping(address => CheckPointHistory.CheckPointHistoryState) historyByAddress;
    }

    /**
    /**
     * @notice Send `amount` value to `to` address from `from` address.
     * @param _self A CheckPointsByAddressState instance to manage.
     * @param _from Address of the history of from values 
     * @param _to Address of the history of to values 
     * @param _amount The amount of value to be transferred
     **/
    function transmit(
        CheckPointsByAddressState storage _self, 
        address _from, 
        address _to, 
        uint256 _amount
    )
        internal
    {
        // Shortcut
        if (_amount == 0) return;

        // Both from and to can never be zero
        assert(!(_from == address(0) && _to == address(0)));

        // Update transferer value
        if (_from != address(0)) {
            // Compute the new from balance
            uint256 newValueFrom = valueOfAtNow(_self, _from).sub(_amount);
            writeValue(_self, _from, newValueFrom);
        }

        // Update transferee value
        if (_to != address(0)) {
            // Compute the new to balance
            uint256 newValueTo = valueOfAtNow(_self, _to).add(_amount);
            writeValue(_self, _to, newValueTo);
        }
    }

    /**
     * @notice Queries the value of `_owner` at a specific `_blockNumber`.
     * @param _self A CheckPointsByAddressState instance to manage.
     * @param _owner The address from which the value will be retrieved.
     * @param _blockNumber The block number to query for the then current value.
     * @return The value at `_blockNumber` for `_owner`.
     **/
    function valueOfAt(
        CheckPointsByAddressState storage _self, 
        address _owner, 
        uint256 _blockNumber
    )
        internal view
        returns (uint256)
    {
        // Get history for _owner
        CheckPointHistory.CheckPointHistoryState storage history = _self.historyByAddress[_owner];
        // Return value at given block
        return history.valueAt(_blockNumber);
    }

    /**
     * @notice Get the value of the `_owner` at the current `block.number`.
     * @param _self A CheckPointsByAddressState instance to manage.
     * @param _owner The address of the value is being requested.
     * @return The value of `_owner` at the current block.
     **/
    function valueOfAtNow(CheckPointsByAddressState storage _self, address _owner) internal view returns (uint256) {
        // Get history for _owner
        CheckPointHistory.CheckPointHistoryState storage history = _self.historyByAddress[_owner];
        // Return value at now
        return history.valueAtNow();
    }

    /**
     * @notice Writes the `value` at the current block number for `_owner`.
     * @param _self A CheckPointsByAddressState instance to manage.
     * @param _owner The address of `_owner` to write.
     * @param _value The value to write.
     * @dev Sender must be the owner of the contract.
     **/
    function writeValue(
        CheckPointsByAddressState storage _self, 
        address _owner, 
        uint256 _value
    )
        internal
    {
        // Get history for _owner
        CheckPointHistory.CheckPointHistoryState storage history = _self.historyByAddress[_owner];
        // Write the value
        history.writeValue(_value);
    }
    
    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain 
     * (unless the history was empty to start with).
     */    
    function cleanupOldCheckpoints(
        CheckPointsByAddressState storage _self, 
        address _owner, 
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        if (_owner != address(0)) {
            return _self.historyByAddress[_owner].cleanupOldCheckpoints(_count, _cleanupBlockNumber);
        }
        return 0;
    }
}


// File contracts/token/lib/CheckPointHistoryCache.sol



library CheckPointHistoryCache {
    using SafeMath for uint256;
    using CheckPointHistory for CheckPointHistory.CheckPointHistoryState;
    
    struct CacheState {
        // mapping blockNumber => (value + 1)
        mapping(uint256 => uint256) cache;
    }
    
    function valueAt(
        CacheState storage _self,
        CheckPointHistory.CheckPointHistoryState storage _checkPointHistory,
        uint256 _blockNumber
    )
        internal returns (uint256 _value, bool _cacheCreated)
    {
        // is it in cache?
        uint256 cachedValue = _self.cache[_blockNumber];
        if (cachedValue != 0) {
            return (cachedValue - 1, false);    // safe, cachedValue != 0
        }
        // read from _checkPointHistory
        uint256 historyValue = _checkPointHistory.valueAt(_blockNumber);
        _self.cache[_blockNumber] = historyValue.add(1);  // store to cache (add 1 to differentiate from empty)
        return (historyValue, true);
    }
    
    function deleteAt(
        CacheState storage _self,
        uint256 _blockNumber
    )
        internal returns (uint256 _deleted)
    {
        if (_self.cache[_blockNumber] != 0) {
            _self.cache[_blockNumber] = 0;
            return 1;
        }
        return 0;
    }
}


// File contracts/token/implementation/CheckPointable.sol





/**
 * Check-Pointable ERC20 Behavior.
 *
 * ERC20 behavior that adds balance check-point features.
 **/
abstract contract CheckPointable {
    using CheckPointHistory for CheckPointHistory.CheckPointHistoryState;
    using CheckPointsByAddress for CheckPointsByAddress.CheckPointsByAddressState;
    using CheckPointHistoryCache for CheckPointHistoryCache.CacheState;
    using SafeMath for uint256;

    // The number of history cleanup steps executed for every write operation.
    // It is more than 1 to make as certain as possible that all history gets cleaned eventually.
    uint256 private constant CLEANUP_COUNT = 2;

    // Private member variables
    CheckPointsByAddress.CheckPointsByAddressState private balanceHistory;
    CheckPointHistory.CheckPointHistoryState private totalSupply;
    CheckPointHistoryCache.CacheState private totalSupplyCache;

    // Historic data for the blocks before `cleanupBlockNumber` can be erased,
    // history before that block should never be used since it can be inconsistent.
    uint256 private cleanupBlockNumber;

    /// Address of the contract that is allowed to call methods for history cleaning.
    address public cleanerContract;

    /**
     * Emitted when a total supply cache entry is created.
     * Allows history cleaners to track total supply cache cleanup opportunities off-chain.
     */
    event CreatedTotalSupplyCache(uint256 _blockNumber);

    // Most cleanup opportunities can be deduced from standard event
    // Transfer(from, to, amount):
    //   - balance history for `from` (if nonzero) and `to` (if nonzero)
    //   - total supply history when either `from` or `to` is zero

    /// This method cannot be called for `_blockNumber` lower than the current cleanup block number.
    modifier notBeforeCleanupBlock(uint256 _blockNumber) {
        require(_blockNumber >= cleanupBlockNumber, "CheckPointable: reading from cleaned-up block");
        _;
    }

    /// Only the `cleanerContract` can call this method.
    modifier onlyCleaner {
        require(msg.sender == cleanerContract, "Only cleaner contract");
        _;
    }

    /**
     * Queries the token balance of `_owner` at a specific `_blockNumber`.
     * @param _owner The address from which the balance will be retrieved.
     * @param _blockNumber The block number to query.
     * @return _balance The balance at `_blockNumber`.
     **/
    function balanceOfAt(address _owner, uint256 _blockNumber)
        public virtual view
        notBeforeCleanupBlock(_blockNumber)
        returns (uint256 _balance)
    {
        return balanceHistory.valueOfAt(_owner, _blockNumber);
    }

    /**
     * Burn current token `amount` for `owner` of checkpoints at current block.
     * @param _owner The address of the owner to burn tokens.
     * @param _amount The amount to burn.
     */
    function _burnForAtNow(address _owner, uint256 _amount) internal virtual {
        uint256 newBalance = balanceOfAt(_owner, block.number).sub(_amount, "Burn too big for owner");
        balanceHistory.writeValue(_owner, newBalance);
        balanceHistory.cleanupOldCheckpoints(_owner, CLEANUP_COUNT, cleanupBlockNumber);
        totalSupply.writeValue(totalSupplyAt(block.number).sub(_amount, "Burn too big for total supply"));
        totalSupply.cleanupOldCheckpoints(CLEANUP_COUNT, cleanupBlockNumber);
    }

    /**
     * Mint current token `amount` for `owner` of checkpoints at current block.
     * @param _owner The address of the owner to burn tokens.
     * @param _amount The amount to burn.
     */
    function _mintForAtNow(address _owner, uint256 _amount) internal virtual {
        uint256 newBalance = balanceOfAt(_owner, block.number).add(_amount);
        balanceHistory.writeValue(_owner, newBalance);
        balanceHistory.cleanupOldCheckpoints(_owner, CLEANUP_COUNT, cleanupBlockNumber);
        totalSupply.writeValue(totalSupplyAt(block.number).add(_amount));
        totalSupply.cleanupOldCheckpoints(CLEANUP_COUNT, cleanupBlockNumber);
    }

    /**
     * Total amount of tokens at a specific `_blockNumber`.
     * @param _blockNumber The block number when the _totalSupply is queried
     * @return _totalSupply The total amount of tokens at `_blockNumber`
     **/
    function totalSupplyAt(uint256 _blockNumber)
        public virtual view
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256 _totalSupply)
    {
        return totalSupply.valueAt(_blockNumber);
    }

    /**
     * Total amount of tokens at a specific `_blockNumber`.
     * @param _blockNumber The block number when the _totalSupply is queried
     * @return _totalSupply The total amount of tokens at `_blockNumber`
     **/
    function _totalSupplyAtCached(uint256 _blockNumber) internal
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256 _totalSupply)
    {
        // use cache only for the past (the value will never change)
        require(_blockNumber < block.number, "Can only be used for past blocks");
        (uint256 value, bool cacheCreated) = totalSupplyCache.valueAt(totalSupply, _blockNumber);
        if (cacheCreated) emit CreatedTotalSupplyCache(_blockNumber);
        return value;
    }

    /**
     * Transmit token `_amount` `_from` address `_to` address of checkpoints at current block.
     * @param _from The address of the sender.
     * @param _to The address of the receiver.
     * @param _amount The amount to transmit.
     */
    function _transmitAtNow(address _from, address _to, uint256 _amount) internal virtual {
        balanceHistory.transmit(_from, _to, _amount);
        balanceHistory.cleanupOldCheckpoints(_from, CLEANUP_COUNT, cleanupBlockNumber);
        balanceHistory.cleanupOldCheckpoints(_to, CLEANUP_COUNT, cleanupBlockNumber);
    }

    /**
     * Set the cleanup block number.
     */
    function _setCleanupBlockNumber(uint256 _blockNumber) internal {
        require(_blockNumber >= cleanupBlockNumber, "Cleanup block number must never decrease");
        require(_blockNumber < block.number, "Cleanup block must be in the past");
        cleanupBlockNumber = _blockNumber;
    }

    /**
     * Get the cleanup block number.
     */
    function _cleanupBlockNumber() internal view returns (uint256) {
        return cleanupBlockNumber;
    }

    /**
     * Update history at token transfer, the CheckPointable part of `_beforeTokenTransfer` hook.
     * @param _from The address of the sender.
     * @param _to The address of the receiver.
     * @param _amount The amount to transmit.
     */
    function _updateBalanceHistoryAtTransfer(address _from, address _to, uint256 _amount) internal virtual {
        if (_from == address(0)) {
            // mint checkpoint balance data for transferee
            _mintForAtNow(_to, _amount);
        } else if (_to == address(0)) {
            // burn checkpoint data for transferer
            _burnForAtNow(_from, _amount);
        } else {
            // transfer checkpoint balance data
            _transmitAtNow(_from, _to, _amount);
        }
    }

    // history cleanup methods

    /**
     * Set the contract that is allowed to call history cleaning methods.
     */
    function _setCleanerContract(address _cleanerContract) internal {
        cleanerContract = _cleanerContract;
    }

    /**
     * Delete balance checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner balance owner account address
     * @param _count maximum number of checkpoints to delete
     * @return the number of checkpoints deleted
     */
    function balanceHistoryCleanup(address _owner, uint256 _count) external onlyCleaner returns (uint256) {
        return balanceHistory.cleanupOldCheckpoints(_owner, _count, cleanupBlockNumber);
    }

    /**
     * Delete total supply checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _count maximum number of checkpoints to delete
     * @return the number of checkpoints deleted
     */
    function totalSupplyHistoryCleanup(uint256 _count) external onlyCleaner returns (uint256) {
        return totalSupply.cleanupOldCheckpoints(_count, cleanupBlockNumber);
    }

    /**
     * Delete total supply cache entry that expired (i.e. is before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _blockNumber the block number for which total supply value was cached
     * @return the number of cache entries deleted (always 0 or 1)
     */
    function totalSupplyCacheCleanup(uint256 _blockNumber) external onlyCleaner returns (uint256) {
        require(_blockNumber < cleanupBlockNumber, "No cleanup after cleanup block");
        return totalSupplyCache.deleteAt(_blockNumber);
    }
}


// File @openzeppelin/contracts/utils/Context.sol@v3.4.0



/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v3.4.0



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File @openzeppelin/contracts/token/ERC20/ERC20.sol@v3.4.0





/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}


// File contracts/utils/implementation/SafePct.sol



/**
 * @dev Compute percentages safely without phantom overflows.
 *
 * Intermediate operations can overflow even when the result will always
 * fit into computed type. Developers usually
 * assume that overflows raise errors. `SafePct` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafePct {
    using SafeMath for uint256;
    /**
     * Requirements:
     *
     * - intermediate operations must revert on overflow
     */
    function mulDiv(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        require(z > 0, "Division by zero");

        if (x == 0) return 0;
        uint256 xy = x * y;
        if (xy / x == y) { // no overflow happened - same as in SafeMath mul
            return xy / z;
        }

        //slither-disable-next-line divide-before-multiply
        uint256 a = x / z;
        uint256 b = x % z; // x = a * z + b

        //slither-disable-next-line divide-before-multiply
        uint256 c = y / z;
        uint256 d = y % z; // y = c * z + d

        return (a.mul(c).mul(z)).add(a.mul(d)).add(b.mul(c)).add(b.mul(d).div(z));
    }

    function mulDivRoundUp(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        uint256 resultRoundDown = mulDiv(x, y, z);
        // safe - if z == 0, above mulDiv call would revert
        uint256 remainder = mulmod(x, y, z);
        // safe - overflow only possible if z == 1, but then remainder == 0
        return remainder == 0 ? resultRoundDown : resultRoundDown + 1;
    }
}


// File contracts/userInterfaces/IGovernanceVotePower.sol


/**
 * Interface for contracts delegating their governance vote power.
 */
interface IGovernanceVotePower {
    /**
     * Delegates all governance vote power of `msg.sender` to address `_to`.
     * @param _to The address of the recipient.
     */
    function delegate(address _to) external;

    /**
     * Undelegates all governance vote power of `msg.sender`.
     */
    function undelegate() external;

    /**
     * Gets the governance vote power of an address at a given block number, including
     * all delegations made to it.
     * @param _who The address being queried.
     * @param _blockNumber The block number at which to fetch the vote power.
     * @return Governance vote power of `_who` at `_blockNumber`.
     */
    function votePowerOfAt(address _who, uint256 _blockNumber) external view returns(uint256);

    /**
     * Gets the governance vote power of an address at the latest block, including
     * all delegations made to it.
     * @param _who The address being queried.
     * @return Governance vote power of `account` at the lastest block.
     */
    function getVotes(address _who) external view returns (uint256);

    /**
     * Gets the address an account is delegating its governance vote power to, at a given block number.
     * @param _who The address being queried.
     * @param _blockNumber The block number at which to fetch the address.
     * @return Address where `_who` was delegating its governance vote power at block `_blockNumber`.
     */
    function getDelegateOfAt(address _who, uint256 _blockNumber) external view returns (address);

    /**
     * Gets the address an account is delegating its governance vote power to, at the latest block number.
     * @param _who The address being queried.
     * @return Address where `_who` is currently delegating its governance vote power.
     */
    function getDelegateOfAtNow(address _who) external view returns (address);
}


// File contracts/userInterfaces/IVPContractEvents.sol


/**
 * Events interface for vote-power related operations.
 */
interface IVPContractEvents {
    /**
     * Emitted when the amount of vote power delegated from one account to another changes.
     *
     * **Note**: This event is always emitted from VPToken's `writeVotePowerContract`.
     * @param from The account that has changed the amount of vote power it is delegating.
     * @param to The account whose received vote power has changed.
     * @param priorVotePower The vote power originally delegated.
     * @param newVotePower The new vote power that triggered this event.
     * It can be 0 if the delegation is completely canceled.
     */
    event Delegate(address indexed from, address indexed to, uint256 priorVotePower, uint256 newVotePower);

    /**
     * Emitted when an account revokes its vote power delegation to another account
     * for a single current or past block (typically the current vote block).
     *
     * **Note**: This event is always emitted from VPToken's `writeVotePowerContract` or `readVotePowerContract`.
     *
     * See `revokeDelegationAt` in `IVPToken`.
     * @param delegator The account that revoked the delegation.
     * @param delegatee The account that has been revoked.
     * @param votePower The revoked vote power.
     * @param blockNumber The block number at which the delegation has been revoked.
     */
    event Revoke(address indexed delegator, address indexed delegatee, uint256 votePower, uint256 blockNumber);
}


// File contracts/userInterfaces/IVPToken.sol




/**
 * Vote power token interface.
 */
interface IVPToken is IERC20 {
    /**
     * Delegate voting power to account `_to` from `msg.sender`, by percentage.
     * @param _to The address of the recipient.
     * @param _bips The percentage of voting power to be delegated expressed in basis points (1/100 of one percent).
     *   Not cumulative: every call resets the delegation value (and a value of 0 revokes all previous delegations).
     */
    function delegate(address _to, uint256 _bips) external;

    /**
     * Undelegate all percentage delegations from the sender and then delegate corresponding
     *   `_bips` percentage of voting power from the sender to each member of the `_delegatees` array.
     * @param _delegatees The addresses of the new recipients.
     * @param _bips The percentages of voting power to be delegated expressed in basis points (1/100 of one percent).
     *   The sum of all `_bips` values must be at most 10000 (100%).
     */
    function batchDelegate(address[] memory _delegatees, uint256[] memory _bips) external;

    /**
     * Explicitly delegate `_amount` voting power to account `_to` from `msg.sender`.
     * Compare with `delegate` which delegates by percentage.
     * @param _to The address of the recipient.
     * @param _amount An explicit vote power amount to be delegated.
     *   Not cumulative: every call resets the delegation value (and a value of 0 revokes all previous delegations).
     */
    function delegateExplicit(address _to, uint _amount) external;

    /**
    * Revoke all delegation from sender to `_who` at given block.
    * Only affects the reads via `votePowerOfAtCached()` in the block `_blockNumber`.
    * Block `_blockNumber` must be in the past.
    * This method should be used only to prevent rogue delegate voting in the current voting block.
    * To stop delegating use delegate / delegateExplicit with value of 0 or undelegateAll / undelegateAllExplicit.
    * @param _who Address of the delegatee.
    * @param _blockNumber The block number at which to revoke delegation..
    */
    function revokeDelegationAt(address _who, uint _blockNumber) external;

    /**
     * Undelegate all voting power of `msg.sender`. This effectively revokes all previous delegations.
     * Can only be used with percentage delegation.
     * Does not reset delegation mode back to NOT SET.
     */
    function undelegateAll() external;

    /**
     * Undelegate all explicit vote power by amount of `msg.sender`.
     * Can only be used with explicit delegation.
     * Does not reset delegation mode back to NOT SET.
     * @param _delegateAddresses Explicit delegation does not store delegatees' addresses,
     *   so the caller must supply them.
     * @return The amount still delegated (in case the list of delegates was incomplete).
     */
    function undelegateAllExplicit(address[] memory _delegateAddresses) external returns (uint256);


    /**
     * Returns the name of the token.
     * @dev Should be compatible with ERC20 method.
     */
    function name() external view returns (string memory);

    /**
     * Returns the symbol of the token, usually a shorter version of the name.
     * @dev Should be compatible with ERC20 method.
     */
    function symbol() external view returns (string memory);

    /**
     * Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals 2, a balance of 505 tokens should
     * be displayed to a user as 5.05 (505 / 10<sup>2</sup>).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * balanceOf and transfer.
     * @dev Should be compatible with ERC20 method.
     */
    function decimals() external view returns (uint8);


    /**
     * Total amount of tokens held by all accounts at a specific block number.
     * @param _blockNumber The block number to query.
     * @return The total amount of tokens at `_blockNumber`.
     */
    function totalSupplyAt(uint _blockNumber) external view returns(uint256);

    /**
     * Queries the token balance of `_owner` at a specific `_blockNumber`.
     * @param _owner The address from which the balance will be retrieved.
     * @param _blockNumber The block number to query.
     * @return The balance at `_blockNumber`.
     */
    function balanceOfAt(address _owner, uint _blockNumber) external view returns (uint256);


    /**
     * Get the current total vote power.
     * @return The current total vote power (sum of all accounts' vote power).
     */
    function totalVotePower() external view returns(uint256);

    /**
     * Get the total vote power at block `_blockNumber`.
     * @param _blockNumber The block number to query.
     * @return The total vote power at the queried block (sum of all accounts' vote powers).
     */
    function totalVotePowerAt(uint _blockNumber) external view returns(uint256);

    /**
     * Get the current vote power of `_owner`.
     * @param _owner The address to query.
     * @return Current vote power of `_owner`.
     */
    function votePowerOf(address _owner) external view returns(uint256);

    /**
     * Get the vote power of `_owner` at block `_blockNumber`
     * @param _owner The address to query.
     * @param _blockNumber The block number to query.
     * @return Vote power of `_owner` at block number `_blockNumber`.
     */
    function votePowerOfAt(address _owner, uint256 _blockNumber) external view returns(uint256);

    /**
     * Get the vote power of `_owner` at block `_blockNumber`, ignoring revocation information (and cache).
     * @param _owner The address to query.
     * @param _blockNumber The block number to query.
     * @return Vote power of `_owner` at block number `_blockNumber`. Result doesn't change if vote power is revoked.
     */
    function votePowerOfAtIgnoringRevocation(address _owner, uint256 _blockNumber) external view returns(uint256);

    /**
     * Get the delegation mode for account '_who'. This mode determines whether vote power is
     * allocated by percentage or by explicit amount. Once the delegation mode is set,
     * it can never be changed, even if all delegations are removed.
     * @param _who The address to get delegation mode.
     * @return Delegation mode: 0 = NOT SET, 1 = PERCENTAGE, 2 = AMOUNT (i.e. explicit).
     */
    function delegationModeOf(address _who) external view returns(uint256);

    /**
     * Get current delegated vote power from delegator `_from` to delegatee `_to`.
     * @param _from Address of delegator.
     * @param _to Address of delegatee.
     * @return votePower The delegated vote power.
     */
    function votePowerFromTo(address _from, address _to) external view returns(uint256);

    /**
     * Get delegated vote power from delegator `_from` to delegatee `_to` at `_blockNumber`.
     * @param _from Address of delegator.
     * @param _to Address of delegatee.
     * @param _blockNumber The block number to query.
     * @return The delegated vote power.
     */
    function votePowerFromToAt(address _from, address _to, uint _blockNumber) external view returns(uint256);

    /**
     * Compute the current undelegated vote power of the `_owner` account.
     * @param _owner The address to query.
     * @return The unallocated vote power of `_owner`.
     */
    function undelegatedVotePowerOf(address _owner) external view returns(uint256);

    /**
     * Get the undelegated vote power of the `_owner` account at a given block number.
     * @param _owner The address to query.
     * @param _blockNumber The block number to query.
     * @return The unallocated vote power of `_owner`.
     */
    function undelegatedVotePowerOfAt(address _owner, uint256 _blockNumber) external view returns(uint256);

    /**
     * Get the list of addresses to which `_who` is delegating, and their percentages.
     * @param _who The address to query.
     * @return _delegateAddresses Positional array of addresses being delegated to.
     * @return _bips Positional array of delegation percents specified in basis points (1/100 of 1 percent).
     *    Each one matches the address in the same position in the `_delegateAddresses` array.
     * @return _count The number of delegates.
     * @return _delegationMode Delegation mode: 0 = NOT SET, 1 = PERCENTAGE, 2 = AMOUNT (i.e. explicit).
     */
    function delegatesOf(address _who)
        external view
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        );

    /**
     * Get the list of addresses to which `_who` is delegating, and their percentages, at the given block.
     * @param _who The address to query.
     * @param _blockNumber The block number to query.
     * @return _delegateAddresses Positional array of addresses being delegated to.
     * @return _bips Positional array of delegation percents specified in basis points (1/100 of 1 percent).
     *    Each one matches the address in the same position in the `_delegateAddresses` array.
     * @return _count The number of delegates.
     * @return _delegationMode Delegation mode: 0 = NOT SET, 1 = PERCENTAGE, 2 = AMOUNT (i.e. explicit).
     */
    function delegatesOfAt(address _who, uint256 _blockNumber)
        external view
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        );

    /**
     * Returns VPContract event interface used for read-only operations (view methods).
     * The only non-view method that might be called on it is `revokeDelegationAt`.
     *
     * `readVotePowerContract` is almost always equal to `writeVotePowerContract`
     * except during an upgrade from one `VPContract` to a new version (which should happen
     * rarely or never and will be announced beforehand).
     *
     * Do not call any methods on `VPContract` directly.
     * State changing methods are forbidden from direct calls.
     * All methods are exposed via `VPToken`.
     * This is the reason that this method returns `IVPContractEvents`.
     * Use it only for listening to events and revoking.
     */
    function readVotePowerContract() external view returns (IVPContractEvents);

    /**
     * Returns VPContract event interface used for state-changing operations (non-view methods).
     * The only non-view method that might be called on it is `revokeDelegationAt`.
     *
     * `writeVotePowerContract` is almost always equal to `readVotePowerContract`,
     * except during upgrade from one `VPContract` to a new version (which should happen
     * rarely or never and will be announced beforehand).
     * In the case of an upgrade, `writeVotePowerContract` is replaced first to establish delegations.
     * After some period (e.g., after a reward epoch ends), `readVotePowerContract` is set equal to it.
     *
     * Do not call any methods on `VPContract` directly.
     * State changing methods are forbidden from direct calls.
     * All are exposed via `VPToken`.
     * This is the reason that this method returns `IVPContractEvents`
     * Use it only for listening to events, delegating, and revoking.
     */
    function writeVotePowerContract() external view returns (IVPContractEvents);

    /**
     * When set, allows token owners to participate in governance voting
     * and delegating governance vote power.
     */
    function governanceVotePower() external view returns (IGovernanceVotePower);
}


// File contracts/token/interface/IICleanable.sol


/**
 * Internal interface for entities that can have their block history cleaned.
 */
interface IICleanable {
    /**
     * Set the contract that is allowed to call history cleaning methods.
     * @param _cleanerContract Address of the cleanup contract.
     * Usually this will be an instance of `CleanupBlockNumberManager`.
     */
    function setCleanerContract(address _cleanerContract) external;

    /**
     * Set the cleanup block number.
     * Historic data for the blocks before `cleanupBlockNumber` can be erased.
     * History before that block should never be used since it can be inconsistent.
     * In particular, cleanup block number must be lower than the current vote power block.
     * @param _blockNumber The new cleanup block number.
     */
    function setCleanupBlockNumber(uint256 _blockNumber) external;

    /**
     * Get the current cleanup block number set with `setCleanupBlockNumber()`.
     * @return The currently set cleanup block number.
     */
    function cleanupBlockNumber() external view returns (uint256);
}


// File contracts/token/interface/IIVPContract.sol




/**
 * Internal interface for helper contracts handling functionality for an associated VPToken.
 */
interface IIVPContract is IICleanable, IVPContractEvents {
    /**
     * Update vote powers when tokens are transferred.
     * Also update delegated vote powers for percentage delegation
     * and check for enough funds for explicit delegations.
     * @param _from Source account of the transfer.
     * @param _to Destination account of the transfer.
     * @param _fromBalance Balance of the source account before the transfer.
     * @param _toBalance Balance of the destination account before the transfer.
     * @param _amount Amount that has been transferred.
     */
    function updateAtTokenTransfer(
        address _from,
        address _to,
        uint256 _fromBalance,
        uint256 _toBalance,
        uint256 _amount
    ) external;

    /**
     * Delegate `_bips` percentage of voting power from a delegator address to a delegatee address.
     * @param _from The address of the delegator.
     * @param _to The address of the delegatee.
     * @param _balance The delegator's current balance
     * @param _bips The percentage of voting power to be delegated expressed in basis points (1/100 of one percent).
     * Not cumulative: every call resets the delegation value (and a value of 0 revokes delegation).
     */
    function delegate(
        address _from,
        address _to,
        uint256 _balance,
        uint256 _bips
    ) external;

    /**
     * Explicitly delegate `_amount` tokens of voting power from a delegator address to a delegatee address.
     * @param _from The address of the delegator.
     * @param _to The address of the delegatee.
     * @param _balance The delegator's current balance.
     * @param _amount An explicit vote power amount to be delegated.
     * Not cumulative: every call resets the delegation value (and a value of 0 undelegates `_to`).
     */
    function delegateExplicit(
        address _from,
        address _to,
        uint256 _balance,
        uint _amount
    ) external;

    /**
     * Revoke all vote power delegation from a delegator address to a delegatee address at a given block.
     * Only affects the reads via `votePowerOfAtCached()` in the block `_blockNumber`.
     * This method should be used only to prevent rogue delegate voting in the current voting block.
     * To stop delegating use `delegate` or `delegateExplicit` with value of 0,
     * or `undelegateAll`/ `undelegateAllExplicit`.
     * @param _from The address of the delegator.
     * @param _to Address of the delegatee.
     * @param _balance The delegator's current balance.
     * @param _blockNumber The block number at which to revoke delegation. Must be in the past.
     */
    function revokeDelegationAt(
        address _from,
        address _to,
        uint256 _balance,
        uint _blockNumber
    ) external;

    /**
     * Undelegate all voting power for a delegator address.
     * Can only be used with percentage delegation.
     * Does not reset delegation mode back to `NOTSET`.
     * @param _from The address of the delegator.
     * @param _balance The delegator's current balance.
     */
    function undelegateAll(
        address _from,
        uint256 _balance
    ) external;

    /**
     * Undelegate all explicit vote power by amount for a delegator address.
     * Can only be used with explicit delegation.
     * Does not reset delegation mode back to `NOTSET`.
     * @param _from The address of the delegator.
     * @param _delegateAddresses Explicit delegation does not store delegatees' addresses,
     * so the caller must supply them.
     * @return The amount still delegated (in case the list of delegates was incomplete).
     */
    function undelegateAllExplicit(
        address _from,
        address[] memory _delegateAddresses
    ) external returns (uint256);

    /**
     * Get the vote power of an address at a given block number.
     * Reads/updates cache and upholds revocations.
     * @param _who The address being queried.
     * @param _blockNumber The block number being queried.
     * @return Vote power of `_who` at `_blockNumber`, including any delegation received.
     */
    function votePowerOfAtCached(address _who, uint256 _blockNumber) external returns(uint256);

    /**
     * Get the current vote power of an address.
     * @param _who The address being queried.
     * @return Current vote power of `_who`, including any delegation received.
     */
    function votePowerOf(address _who) external view returns(uint256);

    /**
     * Get the vote power of an address at a given block number
     * @param _who The address being queried.
     * @param _blockNumber The block number being queried.
     * @return Vote power of `_who` at `_blockNumber`, including any delegation received.
     */
    function votePowerOfAt(address _who, uint256 _blockNumber) external view returns(uint256);

    /**
     * Get the vote power of an address at a given block number, ignoring revocation information and cache.
     * @param _who The address being queried.
     * @param _blockNumber The block number being queried.
     * @return Vote power of `_who` at `_blockNumber`, including any delegation received.
     * Result doesn't change if vote power is revoked.
     */
    function votePowerOfAtIgnoringRevocation(address _who, uint256 _blockNumber) external view returns(uint256);

    /**
     * Get the vote power of a set of addresses at a given block number.
     * @param _owners The list of addresses being queried.
     * @param _blockNumber The block number being queried.
     * @return Vote power of each address at `_blockNumber`, including any delegation received.
     */
    function batchVotePowerOfAt(
        address[] memory _owners,
        uint256 _blockNumber
    )
        external view returns(uint256[] memory);

    /**
     * Get current delegated vote power from a delegator to a delegatee.
     * @param _from Address of the delegator.
     * @param _to Address of the delegatee.
     * @param _balance The delegator's current balance.
     * @return The delegated vote power.
     */
    function votePowerFromTo(
        address _from,
        address _to,
        uint256 _balance
    ) external view returns(uint256);

    /**
    * Get delegated the vote power from a delegator to a delegatee at a given block number.
    * @param _from Address of the delegator.
    * @param _to Address of the delegatee.
    * @param _balance The delegator's current balance.
    * @param _blockNumber The block number being queried.
    * @return The delegated vote power.
    */
    function votePowerFromToAt(
        address _from,
        address _to,
        uint256 _balance,
        uint _blockNumber
    ) external view returns(uint256);

    /**
     * Compute the current undelegated vote power of an address.
     * @param _owner The address being queried.
     * @param _balance Current balance of that address.
     * @return The unallocated vote power of `_owner`, this is, the amount of vote power
     * currently not being delegated to other addresses.
     */
    function undelegatedVotePowerOf(
        address _owner,
        uint256 _balance
    ) external view returns(uint256);

    /**
     * Compute the undelegated vote power of an address at a given block.
     * @param _owner The address being queried.
     * @param _blockNumber The block number being queried.
     * @return The unallocated vote power of `_owner`, this is, the amount of vote power
     * that was not being delegated to other addresses at that block number.
     */
    function undelegatedVotePowerOfAt(
        address _owner,
        uint256 _balance,
        uint256 _blockNumber
    ) external view returns(uint256);

    /**
     * Get the delegation mode of an address. This mode determines whether vote power is
     * allocated by percentage or by explicit value and cannot be changed once set with
     * `delegate` or `delegateExplicit`.
     * @param _who The address being queried.
     * @return Delegation mode (NOTSET=0, PERCENTAGE=1, AMOUNT=2). See Delegatable.DelegationMode.
     */
    function delegationModeOf(address _who) external view returns (uint256);

    /**
     * Get the percentages and addresses being delegated to by a vote power delegator.
     * @param _owner The address of the delegator being queried.
     * @return _delegateAddresses Array of delegatee addresses.
     * @return _bips Array of delegation percents specified in basis points (1/100 or 1 percent), for each delegatee.
     * @return _count The number of returned delegatees.
     * @return _delegationMode The mode of the delegation (NOTSET=0, PERCENTAGE=1, AMOUNT=2).
     * See Delegatable.DelegationMode.
     */
    function delegatesOf(
        address _owner
    )
        external view
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        );

    /**
     * Get the percentages and addresses being delegated to by a vote power delegator,
     * at a given block.
     * @param _owner The address of the delegator being queried.
     * @param _blockNumber The block number being queried.
     * @return _delegateAddresses Array of delegatee addresses.
     * @return _bips Array of delegation percents specified in basis points (1/100 or 1 percent), for each delegatee.
     * @return _count The number of returned delegatees.
     * @return _delegationMode The mode of the delegation (NOTSET=0, PERCENTAGE=1, AMOUNT=2).
     * See Delegatable.DelegationMode.
     */
    function delegatesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        external view
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        );

    /**
     * The VPToken (or some other contract) that owns this VPContract.
     * All state changing methods may be called only from this address.
     * This is because original `msg.sender` is typically sent in a parameter
     * and we must make sure that it cannot be faked by directly calling
     * IIVPContract methods.
     * Owner token is also used in case of replacement to recover vote powers from balances.
     */
    function ownerToken() external view returns (IVPToken);

    /**
     * Return true if this IIVPContract is configured to be used as a replacement for other contract.
     * It means that vote powers are not necessarily correct at the initialization, therefore
     * every method that reads vote power must check whether it is initialized for that address and block.
     */
    function isReplacement() external view returns (bool);
}


// File contracts/userInterfaces/IPChainVotePower.sol


/**
 * Interface for the vote power part of the `PChainStakeMirror` contract.
 */
interface IPChainVotePower {

    /**
     * Event triggered when a stake is confirmed or at the time it ends.
     * Definition: `votePowerFromTo(owner, nodeId)` is `changed` from `priorVotePower` to `newVotePower`.
     * @param owner The account that has changed the amount of vote power it is staking.
     * @param nodeId The node id whose received vote power has changed.
     * @param priorVotePower The vote power originally on that node id.
     * @param newVotePower The new vote power that triggered this event.
     */
    event VotePowerChanged(
        address indexed owner,
        bytes20 indexed nodeId,
        uint256 priorVotePower,
        uint256 newVotePower
    );

    /**
     * Emitted when a vote power cache entry is created.
     * Allows history cleaners to track vote power cache cleanup opportunities off-chain.
     * @param nodeId The node id whose vote power has just been cached.
     * @param blockNumber The block number at which the vote power has been cached.
     */
    event VotePowerCacheCreated(bytes20 nodeId, uint256 blockNumber);

    /**
    * Get the vote power of `_owner` at block `_blockNumber` using cache.
    *   It tries to read the cached value and if not found, reads the actual value and stores it in cache.
    *   Can only be used if _blockNumber is in the past, otherwise reverts.
    * @param _owner The node id to get voting power.
    * @param _blockNumber The block number at which to fetch.
    * @return Vote power of `_owner` at `_blockNumber`.
    */
    function votePowerOfAtCached(bytes20 _owner, uint256 _blockNumber) external returns(uint256);

    /**
    * Get the total vote power at block `_blockNumber` using cache.
    *   It tries to read the cached value and if not found, reads the actual value and stores it in cache.
    *   Can only be used if `_blockNumber` is in the past, otherwise reverts.
    * @param _blockNumber The block number at which to fetch.
    * @return The total vote power at the block (sum of all accounts' vote powers).
    */
    function totalVotePowerAtCached(uint256 _blockNumber) external returns(uint256);

    /**
     * Get the current total vote power.
     * @return The current total vote power (sum of all accounts' vote powers).
     */
    function totalVotePower() external view returns(uint256);

    /**
    * Get the total vote power at block `_blockNumber`
    * @param _blockNumber The block number at which to fetch.
    * @return The total vote power at the block  (sum of all accounts' vote powers).
    */
    function totalVotePowerAt(uint _blockNumber) external view returns(uint256);

    /**
     * Get the amounts and node ids being staked to by a vote power owner.
     * @param _owner The address being queried.
     * @return _nodeIds Array of node ids.
     * @return _amounts Array of staked amounts, for each node id.
     */
    function stakesOf(address _owner)
        external view
        returns (
            bytes20[] memory _nodeIds,
            uint256[] memory _amounts
        );

    /**
     * Get the amounts and node ids being staked to by a vote power owner,
     * at a given block.
     * @param _owner The address being queried.
     * @param _blockNumber The block number being queried.
     * @return _nodeIds Array of node ids.
     * @return _amounts Array of staked amounts, for each node id.
     */
    function stakesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        external view
        returns (
            bytes20[] memory _nodeIds,
            uint256[] memory _amounts
        );

    /**
     * Get the current vote power of `_nodeId`.
     * @param _nodeId The node id to get voting power.
     * @return Current vote power of `_nodeId`.
     */
    function votePowerOf(bytes20 _nodeId) external view returns(uint256);

    /**
    * Get the vote power of `_nodeId` at block `_blockNumber`
    * @param _nodeId The node id to get voting power.
    * @param _blockNumber The block number at which to fetch.
    * @return Vote power of `_nodeId` at `_blockNumber`.
    */
    function votePowerOfAt(bytes20 _nodeId, uint256 _blockNumber) external view returns(uint256);

    /**
    * Get current staked vote power from `_owner` staked to `_nodeId`.
    * @param _owner Address of vote power owner.
    * @param _nodeId Node id.
    * @return The staked vote power.
    */
    function votePowerFromTo(address _owner, bytes20 _nodeId) external view returns(uint256);

    /**
    * Get current staked vote power from `_owner` staked to `_nodeId` at `_blockNumber`.
    * @param _owner Address of vote power owner.
    * @param _nodeId Node id.
    * @param _blockNumber The block number at which to fetch.
    * @return The staked vote power.
    */
    function votePowerFromToAt(address _owner, bytes20 _nodeId, uint _blockNumber) external view returns(uint256);

    /**
     * Return vote powers for several node ids in a batch.
     * @param _nodeIds The list of node ids to fetch vote power of.
     * @param _blockNumber The block number at which to fetch.
     * @return A list of vote powers.
     */
    function batchVotePowerOfAt(
        bytes20[] memory _nodeIds,
        uint256 _blockNumber
    ) external view returns(uint256[] memory);
}


// File contracts/userInterfaces/IPChainStakeMirrorVerifier.sol


/**
 * Interface with structure for P-chain stake mirror verifications.
 */
interface IPChainStakeMirrorVerifier {

    /**
     * Structure describing the P-chain stake.
     */
    struct PChainStake {
        // Hash of the transaction on the underlying chain.
        bytes32 txId;
        // Type of the staking/delegation transaction: '0' for 'ADD_VALIDATOR_TX' and '1' for 'ADD_DELEGATOR_TX'.
        uint8 stakingType;
        // Input address that triggered the staking or delegation transaction.
        // See https://support.avax.network/en/articles/4596397-what-is-an-address for address definition for P-chain.
        bytes20 inputAddress;
        // NodeID to which staking or delegation is done.
        // For definitions, see https://github.com/ava-labs/avalanchego/blob/master/ids/node_id.go.
        bytes20 nodeId;
        // Start time of the staking/delegation in seconds (Unix epoch).
        uint64 startTime;
        // End time of the staking/delegation in seconds (Unix epoch).
        uint64 endTime;
        // Staked or delegated amount in Gwei (nano FLR).
        uint64 weight;
    }
}


// File contracts/userInterfaces/IPChainStakeMirror.sol



/**
 * Interface for the `PChainStakeMirror` contract.
 */
interface IPChainStakeMirror is IPChainVotePower {

    /**
     * Event emitted when max updates per block is set.
     * @param maxUpdatesPerBlock new number of max updated per block
     */
    event MaxUpdatesPerBlockSet(uint256 maxUpdatesPerBlock);

    /**
     * Event emitted when the stake is confirmed.
     * @param owner The address who opened the stake.
     * @param nodeId Node id to which the stake was added.
     * @param txHash Unique tx hash - keccak256(abi.encode(PChainStake.txId, PChainStake.inputAddress));
     * @param amountWei Stake amount (in wei).
     * @param pChainTxId P-chain transaction id.
     */
    event StakeConfirmed(
        address indexed owner,
        bytes20 indexed nodeId,
        bytes32 indexed txHash,
        uint256 amountWei,
        bytes32 pChainTxId
    );

    /**
     * Event emitted when the stake has ended.
     * @param owner The address whose stake has ended.
     * @param nodeId Node id from which the stake was removed.
     * @param txHash Unique tx hash - keccak256(abi.encode(PChainStake.txId, PChainStake.inputAddress));
     * @param amountWei Stake amount (in wei).
     */
    event StakeEnded(
        address indexed owner,
        bytes20 indexed nodeId,
        bytes32 indexed txHash,
        uint256 amountWei
    );

    /**
     * Event emitted when the stake was revoked.
     * @param owner The address whose stake has ended.
     * @param nodeId Node id from which the stake was removed.
     * @param txHash Unique tx hash - keccak256(abi.encode(PChainStake.txId, PChainStake.inputAddress));
     * @param amountWei Stake amount (in wei).
     */
    event StakeRevoked(
        address indexed owner,
        bytes20 indexed nodeId,
        bytes32 indexed txHash,
        uint256 amountWei
    );

    /**
     * Method for P-chain stake mirroring using `PChainStake` data and Merkle proof.
     * @param _stakeData Information about P-chain stake.
     * @param _merkleProof Merkle proof that should be used to prove the P-chain stake.
     */
    function mirrorStake(
        IPChainStakeMirrorVerifier.PChainStake calldata _stakeData,
        bytes32[] calldata _merkleProof
    )
        external;

    /**
     * Method for checking if active stake (stake start time <= block.timestamp < stake end time) was already mirrored.
     * @param _txId P-chain stake transaction id.
     * @param _inputAddress P-chain address that opened stake.
     * @return True if stake is active and mirrored.
     */
    function isActiveStakeMirrored(bytes32 _txId, bytes20 _inputAddress) external view returns(bool);

    /**
     * Total amount of tokens at current block.
     * @return The current total amount of tokens.
     **/
    function totalSupply() external view returns (uint256);

    /**
     * Total amount of tokens at a specific `_blockNumber`.
     * @param _blockNumber The block number when the totalSupply is queried.
     * @return The total amount of tokens at `_blockNumber`.
     **/
    function totalSupplyAt(uint _blockNumber) external view returns(uint256);

    /**
     * Queries the token balance of `_owner` at current block.
     * @param _owner The address from which the balance will be retrieved.
     * @return The current balance.
     **/
    function balanceOf(address _owner) external view returns (uint256);

    /**
     * Queries the token balance of `_owner` at a specific `_blockNumber`.
     * @param _owner The address from which the balance will be retrieved.
     * @param _blockNumber The block number when the balance is queried.
     * @return The balance at `_blockNumber`.
     **/
    function balanceOfAt(address _owner, uint _blockNumber) external view returns (uint256);
}


// File contracts/token/interface/IIGovernanceVotePower.sol




/**
 * Internal interface for contracts delegating their governance vote power.
 */
interface IIGovernanceVotePower is IGovernanceVotePower {
    /**
     * Emitted when a delegate's vote power changes, as a result of a new delegation
     * or a token transfer, for example.
     *
     * The event is always emitted from a `GovernanceVotePower` contract.
     * @param delegate The account receiving the changing delegated vote power.
     * @param previousBalance Delegated vote power before the change.
     * @param newBalance Delegated vote power after the change.
     */
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    /**
     * Emitted when an account starts delegating vote power or switches its delegation
     * to another address.
     *
     * The event is always emitted from a `GovernanceVotePower` contract.
     * @param delegator Account delegating its vote power.
     * @param fromDelegate Account receiving the delegation before the change.
     * Can be address(0) if there was no previous delegation.
     * @param toDelegate Account receiving the delegation after the change.
     * Can be address(0) if `delegator` just undelegated all its vote power.
     */
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    /**
     * Update governance vote power of all involved delegates after tokens are transferred.
     *
     * This function **MUST** be called after each governance token transfer for the
     * delegates to reflect the correct balance.
     * @param _from Source address of the transfer.
     * @param _to Destination address of the transfer.
     * @param _fromBalance _Ignored._
     * @param _toBalance _Ignored._
     * @param _amount Amount being transferred.
     */
    function updateAtTokenTransfer(
        address _from,
        address _to,
        uint256 _fromBalance,
        uint256 _toBalance,
        uint256 _amount
    ) external;

    /**
     * Set the cleanup block number.
     * Historic data for the blocks before `cleanupBlockNumber` can be erased.
     * History before that block should never be used since it can be inconsistent.
     * In particular, cleanup block number must be lower than the current vote power block.
     * @param _blockNumber The new cleanup block number.
     */
    function setCleanupBlockNumber(uint256 _blockNumber) external;

    /**
     * Set the contract that is allowed to call history cleaning methods.
     * @param _cleanerContract Address of the cleanup contract.
     * Usually this will be an instance of `CleanupBlockNumberManager`.
     */
    function setCleanerContract(address _cleanerContract) external;

    /**
     * Get the token that this governance vote power contract belongs to.
     * @return The IVPToken interface owning this contract.
     */
    function ownerToken() external view returns (IVPToken);

    /**
     * Get the stake mirror contract that this governance vote power contract belongs to.
     * @return The IPChainStakeMirror interface owning this contract.
     */
    function pChainStakeMirror() external view returns (IPChainStakeMirror);

    /**
     * Get the current cleanup block number set with `setCleanupBlockNumber()`.
     * @return The currently set cleanup block number.
     */
    function getCleanupBlockNumber() external view returns(uint256);
}


// File contracts/token/interface/IIVPToken.sol






/**
 * Vote power token internal interface.
 */
interface IIVPToken is IVPToken, IICleanable {
    /**
     * Set the contract that is allowed to set cleanupBlockNumber.
     * Usually this will be an instance of CleanupBlockNumberManager.
     */
    function setCleanupBlockNumberManager(address _cleanupBlockNumberManager) external;

    /**
     * Sets new governance vote power contract that allows token owners to participate in governance voting
     * and delegate governance vote power.
     */
    function setGovernanceVotePower(IIGovernanceVotePower _governanceVotePower) external;

    /**
     * Get the total vote power at block `_blockNumber` using cache.
     *   It tries to read the cached value and if it is not found, reads the actual value and stores it in the cache.
     *   Can only be used if `_blockNumber` is in the past, otherwise reverts.
     * @param _blockNumber The block number to query.
     * @return The total vote power at the queried block (sum of all accounts' vote powers).
     */
    function totalVotePowerAtCached(uint256 _blockNumber) external returns(uint256);

    /**
     * Get the vote power of `_owner` at block `_blockNumber` using cache.
     *   It tries to read the cached value and if it is not found, reads the actual value and stores it in the cache.
     *   Can only be used if `_blockNumber` is in the past, otherwise reverts.
     * @param _owner The address to query.
     * @param _blockNumber The block number to query.
     * @return Vote power of `_owner` at `_blockNumber`.
     */
    function votePowerOfAtCached(address _owner, uint256 _blockNumber) external returns(uint256);

    /**
     * Return the vote power for several addresses.
     * @param _owners The list of addresses to query.
     * @param _blockNumber The block number to query.
     * @return Array of vote power for each queried address.
     */
    function batchVotePowerOfAt(
        address[] memory _owners,
        uint256 _blockNumber
    ) external view returns(uint256[] memory);
}


// File contracts/governance/implementation/GovernedBase.sol


/**
 * Abstract base class that defines behaviors for governed contracts.
 *
 * This class is abstract so that specific behaviors can be defined for the constructor.
 * Contracts should not be left ungoverned, but not all contract will have a constructor
 * (for example those pre-defined in genesis).
 */
abstract contract GovernedBase {
    struct TimelockedCall {
        uint256 allowedAfterTimestamp;
        bytes encodedCall;
    }

    /// Governance Settings.
    // solhint-disable-next-line const-name-snakecase
    IGovernanceSettings public constant governanceSettings =
        IGovernanceSettings(0x1000000000000000000000000000000000000007);

    address private initialGovernance;

    bool private initialised;

    /// When true, governance is enabled and cannot be disabled. See `switchToProductionMode`.
    bool public productionMode;

    bool private executing;

    /// List of pending timelocked governance calls.
    mapping(bytes4 => TimelockedCall) public timelockedCalls;

    /// Emitted when a new governance call has been recorded and is now waiting for the time lock to expire.
    event GovernanceCallTimelocked(bytes4 selector, uint256 allowedAfterTimestamp, bytes encodedCall);
    /// Emitted when a timelocked governance call is executed.
    event TimelockedGovernanceCallExecuted(bytes4 selector, uint256 timestamp);
    /// Emitted when a timelocked governance call is canceled before execution.
    event TimelockedGovernanceCallCanceled(bytes4 selector, uint256 timestamp);

    /// Emitted when the governance address is initialized.
    /// This address will be used until production mode is entered (see `GovernedProductionModeEntered`).
    /// At that point the governance address is taken from `GovernanceSettings`.
    event GovernanceInitialised(address initialGovernance);
    /// Emitted when governance is enabled and the governance address cannot be changed anymore
    /// (only through a network fork).
    event GovernedProductionModeEntered(address governanceSettings);

    modifier onlyGovernance {
        if (executing || !productionMode) {
            _beforeExecute();
            _;
        } else {
            _recordTimelockedCall(msg.data);
        }
    }

    modifier onlyImmediateGovernance () {
        _checkOnlyGovernance();
        _;
    }

    constructor(address _initialGovernance) {
        if (_initialGovernance != address(0)) {
            initialise(_initialGovernance);
        }
    }

    /**
     * Execute the timelocked governance calls once the timelock period expires.
     * @dev Only executor can call this method.
     * @param _selector The method selector (only one timelocked call per method is stored).
     */
    function executeGovernanceCall(bytes4 _selector) external {
        require(governanceSettings.isExecutor(msg.sender), "only executor");
        TimelockedCall storage call = timelockedCalls[_selector];
        require(call.allowedAfterTimestamp != 0, "timelock: invalid selector");
        require(block.timestamp >= call.allowedAfterTimestamp, "timelock: not allowed yet");
        bytes memory encodedCall = call.encodedCall;
        delete timelockedCalls[_selector];
        executing = true;
        //solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(this).call(encodedCall);
        executing = false;
        emit TimelockedGovernanceCallExecuted(_selector, block.timestamp);
        _passReturnOrRevert(success);
    }

    /**
     * Cancel a timelocked governance call before it has been executed.
     * @dev Only governance can call this method.
     * @param _selector The method selector.
     */
    function cancelGovernanceCall(bytes4 _selector) external onlyImmediateGovernance {
        require(timelockedCalls[_selector].allowedAfterTimestamp != 0, "timelock: invalid selector");
        emit TimelockedGovernanceCallCanceled(_selector, block.timestamp);
        delete timelockedCalls[_selector];
    }

    /**
     * Enter the production mode after all the initial governance settings have been set.
     * This enables timelocks and the governance can be obtained afterward by calling
     * governanceSettings.getGovernanceAddress().
     * Emits `GovernedProductionModeEntered`.
     */
    function switchToProductionMode() external {
        _checkOnlyGovernance();
        require(!productionMode, "already in production mode");
        initialGovernance = address(0);
        productionMode = true;
        emit GovernedProductionModeEntered(address(governanceSettings));
    }

    /**
     * Sets the initial governance address if it has not been set already.
     * This will be the governance address until production mode is entered and
     * `GovernanceSettings` take effect.
     * Emits `GovernanceInitialised`.
     * @param _initialGovernance Initial governance address.
     */
    function initialise(address _initialGovernance) public virtual {
        require(initialised == false, "initialised != false");
        initialised = true;
        initialGovernance = _initialGovernance;
        emit GovernanceInitialised(_initialGovernance);
    }

    /**
     * Returns the current effective governance address.
     */
    function governance() public view returns (address) {
        return productionMode ? governanceSettings.getGovernanceAddress() : initialGovernance;
    }

    function _beforeExecute() private {
        if (executing) {
            // can only be run from executeGovernanceCall(), where we check that only executor can call
            // make sure nothing else gets executed, even in case of reentrancy
            assert(msg.sender == address(this));
            executing = false;
        } else {
            // must be called with: productionMode=false
            // must check governance in this case
            _checkOnlyGovernance();
        }
    }

    function _recordTimelockedCall(bytes calldata _data) private {
        _checkOnlyGovernance();
        bytes4 selector;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            selector := calldataload(_data.offset)
        }
        uint256 timelock = governanceSettings.getTimelock();
        uint256 allowedAt = block.timestamp + timelock;
        timelockedCalls[selector] = TimelockedCall({
            allowedAfterTimestamp: allowedAt,
            encodedCall: _data
        });
        emit GovernanceCallTimelocked(selector, allowedAt, _data);
    }

    function _checkOnlyGovernance() private view {
        require(msg.sender == governance(), "only governance");
    }

    function _passReturnOrRevert(bool _success) private pure {
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


// File contracts/governance/implementation/Governed.sol


/**
 * Defines behaviors for governed contracts that must have a governor set at construction-time.
 */
contract Governed is GovernedBase {
    /**
     * @param _governance Governance contract. Must not be zero.
     */
    constructor(address _governance) GovernedBase(_governance) {
        require(_governance != address(0), "_governance zero");
    }
}


// File contracts/token/implementation/VPToken.sol












/**
 * Vote power token.
 *
 * An ERC20 token that enables the holder to delegate a voting power
 * equal to their balance, with history tracking by block height.
 * Actual vote power and delegation functionality is implemented in an associated VPContract.
 */
contract VPToken is IIVPToken, ERC20, CheckPointable, Governed {
    using SafeMath for uint256;
    using SafePct for uint256;

    // The VPContract to use for reading vote powers and delegations
    IIVPContract private readVpContract;

    // The VPContract to use for writing vote powers and delegations.
    // Normally same as `readVpContract` except during switch
    // when reading happens from the old and writing goes to the new VPContract.
    IIVPContract private writeVpContract;

    // The contract to use for governance vote power and delegation.
    // Here only to properly update governance VP during transfers;
    // all actual operations go directly to governance VP contract.
    IIGovernanceVotePower private governanceVP;

    /// The contract that is allowed to set `cleanupBlockNumber`.
    /// Usually this will be an instance of `CleanupBlockNumberManager`.
    address public cleanupBlockNumberManager;

    /**
     * When true, the argument to `setWriteVpContract` must be a vpContract
     * with `isReplacement` set to `true`. To be used for creating the correct VPContract.
     */
    bool public vpContractInitialized = false;

    /**
     * Emitted when one of the vote power contracts is changed.
     *
     * It is used to track the history of VPToken -> VPContract / GovernanceVotePower
     * associations (e.g. by external cleaners).
     * @param _contractType 0 = Read VPContract, 1 = Write VPContract, 2 = Governance vote power.
     * @param _oldContractAddress Contract address before change.
     * @param _newContractAddress Contract address after change.
     */
    event VotePowerContractChanged(uint256 _contractType, address _oldContractAddress, address _newContractAddress);

    constructor(
        address _governance,
        //slither-disable-next-line shadowing-local
        string memory _name,
        //slither-disable-next-line shadowing-local
        string memory _symbol
    )
        Governed(_governance) ERC20(_name, _symbol)
    {
        /* empty block */
    }

    /**
     * @inheritdoc IVPToken
     */
    function name() public view override(ERC20, IVPToken) returns (string memory) {
        return ERC20.name();
    }

    /**
     * @inheritdoc IVPToken
     */
    function symbol() public view override(ERC20, IVPToken) returns (string memory) {
        return ERC20.symbol();
    }

    /**
     * @inheritdoc IVPToken
     */
    function decimals() public view override(ERC20, IVPToken) returns (uint8) {
        return ERC20.decimals();
    }

    /**
     * @inheritdoc CheckPointable
     */
    function totalSupplyAt(uint256 _blockNumber) public view override(CheckPointable, IVPToken) returns(uint256) {
        return CheckPointable.totalSupplyAt(_blockNumber);
    }

    /**
     * @inheritdoc CheckPointable
     */
    function balanceOfAt(
        address _owner,
        uint256 _blockNumber
    )
        public view
        override(CheckPointable, IVPToken)
        returns (uint256)
    {
        return CheckPointable.balanceOfAt(_owner, _blockNumber);
    }

    /**
     * @inheritdoc IVPToken
     */
    function delegate(address _to, uint256 _bips) external override {
        // Get the current balance of sender and delegate by percentage _to recipient
        _checkWriteVpContract().delegate(msg.sender, _to, balanceOf(msg.sender), _bips);
    }

    /**
     * @inheritdoc IVPToken
     */
    function batchDelegate(address[] memory _delegatees, uint256[] memory _bips) external override {
        require(_delegatees.length == _bips.length, "Array length mismatch");
        IIVPContract vpContract = _checkWriteVpContract();
        uint256 balance = balanceOf(msg.sender);
        vpContract.undelegateAll(msg.sender, balance);
        for (uint256 i = 0; i < _delegatees.length; i++) {
            vpContract.delegate(msg.sender, _delegatees[i], balance, _bips[i]);
        }
    }

    /**
     * @inheritdoc IVPToken
     */
    function delegateExplicit(address _to, uint256 _amount) external override {
        _checkWriteVpContract().delegateExplicit(msg.sender, _to, balanceOf(msg.sender), _amount);
    }

    /**
     * @inheritdoc IVPToken
     */
    function undelegatedVotePowerOf(address _owner) external view override returns(uint256) {
        return _checkReadVpContract().undelegatedVotePowerOf(_owner, balanceOf(_owner));
    }

    /**
     * @inheritdoc IVPToken
     */
    function undelegatedVotePowerOfAt(address _owner, uint256 _blockNumber) external view override returns (uint256) {
        return _checkReadVpContract()
            .undelegatedVotePowerOfAt(_owner, balanceOfAt(_owner, _blockNumber), _blockNumber);
    }

    /**
     * @inheritdoc IVPToken
     */
    function undelegateAll() external override {
        _checkWriteVpContract().undelegateAll(msg.sender, balanceOf(msg.sender));
    }

    /**
     * @inheritdoc IVPToken
     */
    function undelegateAllExplicit(
        address[] memory _delegateAddresses
    )
        external override
        returns (uint256 _remainingDelegation)
    {
        return _checkWriteVpContract().undelegateAllExplicit(msg.sender, _delegateAddresses);
    }

    /**
     * @inheritdoc IVPToken
     */
    function revokeDelegationAt(address _who, uint256 _blockNumber) public override {
        IIVPContract writeVPC = writeVpContract;
        IIVPContract readVPC = readVpContract;
        if (address(writeVPC) != address(0)) {
            writeVPC.revokeDelegationAt(msg.sender, _who, balanceOfAt(msg.sender, _blockNumber), _blockNumber);
        }
        if (address(readVPC) != address(writeVPC) && address(readVPC) != address(0)) {
            try readVPC.revokeDelegationAt(msg.sender, _who, balanceOfAt(msg.sender, _blockNumber), _blockNumber) {
            } catch {
                // do nothing
            }
        }
    }

    /**
     * @inheritdoc IVPToken
     */
    function votePowerFromTo(
        address _from,
        address _to
    )
        external view override
        returns(uint256)
    {
        return _checkReadVpContract().votePowerFromTo(_from, _to, balanceOf(_from));
    }

    /**
     * @inheritdoc IVPToken
     */
    function votePowerFromToAt(
        address _from,
        address _to,
        uint256 _blockNumber
    )
        external view override
        returns(uint256)
    {
        return _checkReadVpContract().votePowerFromToAt(_from, _to, balanceOfAt(_from, _blockNumber), _blockNumber);
    }

    /**
     * @inheritdoc IVPToken
     */
    function totalVotePower() external view override returns(uint256) {
        return totalSupply();
    }

    /**
     * @inheritdoc IVPToken
     */
    function totalVotePowerAt(uint256 _blockNumber) external view override returns(uint256) {
        return totalSupplyAt(_blockNumber);
    }

    /**
     * @inheritdoc IIVPToken
    */
    function totalVotePowerAtCached(uint256 _blockNumber) public override returns(uint256) {
        return _totalSupplyAtCached(_blockNumber);
    }

    /**
     * @inheritdoc IVPToken
     */
    function delegationModeOf(address _who) external view override returns (uint256) {
        return _checkReadVpContract().delegationModeOf(_who);
    }

    /**
     * @inheritdoc IVPToken
     */
    function votePowerOf(address _owner) external view override returns(uint256) {
        return _checkReadVpContract().votePowerOf(_owner);
    }

    /**
     * @inheritdoc IVPToken
     */
    function votePowerOfAt(address _owner, uint256 _blockNumber) external view override returns(uint256) {
        return _checkReadVpContract().votePowerOfAt(_owner, _blockNumber);
    }

    /**
     * @inheritdoc IVPToken
     */
    function votePowerOfAtIgnoringRevocation(address _owner, uint256 _blockNumber)
        external view override
        returns(uint256)
    {
        return _checkReadVpContract().votePowerOfAtIgnoringRevocation(_owner, _blockNumber);
    }

    /**
     * @inheritdoc IIVPToken
     */
    function batchVotePowerOfAt(
        address[] memory _owners,
        uint256 _blockNumber
    )
        external view override
        returns(uint256[] memory)
    {
        return _checkReadVpContract().batchVotePowerOfAt(_owners, _blockNumber);
    }

    /**
     * @inheritdoc IIVPToken
     */
    function votePowerOfAtCached(address _owner, uint256 _blockNumber) public override returns(uint256) {
        return _checkReadVpContract().votePowerOfAtCached(_owner, _blockNumber);
    }

    /**
     * @inheritdoc IVPToken
     */
    function delegatesOf(
        address _owner
    )
        external view override
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        )
    {
        return _checkReadVpContract().delegatesOf(_owner);
    }

    /**
     * @inheritdoc IVPToken
     */
    function delegatesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        external view override
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        )
    {
        return _checkReadVpContract().delegatesOfAt(_owner, _blockNumber);
    }

    // Update vote power and balance checkpoints before balances are modified. This is implemented
    // in the _beforeTokenTransfer hook, which is executed for _mint, _burn, and _transfer operations.
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    )
        internal virtual
        override(ERC20)
    {
        require(_from != _to, "Cannot transfer to self");

        uint256 fromBalance = _from != address(0) ? balanceOf(_from) : 0;
        uint256 toBalance = _to != address(0) ? balanceOf(_to) : 0;

        // update vote powers
        IIVPContract vpc = writeVpContract;
        if (address(vpc) != address(0)) {
            vpc.updateAtTokenTransfer(_from, _to, fromBalance, toBalance, _amount);
        } else if (!vpContractInitialized) {
            // transfers without vpcontract are allowed, but after they are made
            // any added vpcontract must have isReplacement set
            vpContractInitialized = true;
        }

        // update governance vote powers
        IIGovernanceVotePower gvp = governanceVP;
        if (address(gvp) != address(0)) {
            gvp.updateAtTokenTransfer(_from, _to, fromBalance, toBalance, _amount);
        }

        // update balance history
        _updateBalanceHistoryAtTransfer(_from, _to, _amount);
    }

    /**
     * Call from governance to set read VpContract on token, e.g.
     * vpToken.setReadVpContract(new VPContract(vpToken)).
     *
     * Read VPContract must be set before any of the VPToken delegation or vote power reading methods are called,
     * otherwise they will revert.
     *
     * **NOTE**: If `readVpContract` differs from `writeVpContract` all reads will be "frozen" and will not reflect
     * changes (not even revokes; they may or may not reflect balance transfers).
     * @param _vpContract Read vote power contract to be used by this token.
     */
    function setReadVpContract(IIVPContract _vpContract) external onlyGovernance {
        if (address(_vpContract) != address(0)) {
            require(address(_vpContract.ownerToken()) == address(this),
                "VPContract not owned by this token");
            // set contract's cleanup block
            _vpContract.setCleanupBlockNumber(_cleanupBlockNumber());
        }
        emit VotePowerContractChanged(0, address(readVpContract), address(_vpContract));
        readVpContract = _vpContract;
    }

    /**
     * Call from governance to set write VpContract on token, e.g.
     * vpToken.setWriteVpContract(new VPContract(vpToken)).
     *
     * Write VPContract must be set before any of the VPToken delegation modifying methods are called,
     * otherwise they will revert.
     * @param _vpContract Write vote power contract to be used by this token.
     */
    function setWriteVpContract(IIVPContract _vpContract) external onlyGovernance {
        if (address(_vpContract) != address(0)) {
            require(address(_vpContract.ownerToken()) == address(this),
                "VPContract not owned by this token");
            require(!vpContractInitialized || _vpContract.isReplacement(),
                "VPContract not configured for replacement");
            // set contract's cleanup block
            _vpContract.setCleanupBlockNumber(_cleanupBlockNumber());
            // once a non-null vpcontract is set, every other has to have isReplacement flag set
            vpContractInitialized = true;
        }
        emit VotePowerContractChanged(1, address(writeVpContract), address(_vpContract));
        writeVpContract = _vpContract;
    }

    /**
     * Return read vpContract, ensuring that it is not zero.
     */
    function _checkReadVpContract() internal view returns (IIVPContract) {
        IIVPContract vpc = readVpContract;
        require(address(vpc) != address(0), "Token missing read VPContract");
        return vpc;
    }

    /**
     * Return write vpContract, ensuring that it is not zero.
     */
    function _checkWriteVpContract() internal view returns (IIVPContract) {
        IIVPContract vpc = writeVpContract;
        require(address(vpc) != address(0), "Token missing write VPContract");
        return vpc;
    }

    /**
     * Return vpContract used for reading, may be zero.
     */
    function _getReadVpContract() internal view returns (IIVPContract) {
        return readVpContract;
    }

    /**
     * Return vpContract used for writing, may be zero.
     */
    function _getWriteVpContract() internal view returns (IIVPContract) {
        return writeVpContract;
    }

    /**
     * @inheritdoc IVPToken
     */
    function readVotePowerContract() external view override returns (IVPContractEvents) {
        return readVpContract;
    }

    /**
     * @inheritdoc IVPToken
     */
    function writeVotePowerContract() external view override returns (IVPContractEvents) {
        return writeVpContract;
    }

    /**
     * @inheritdoc IICleanable
     */
    function setCleanupBlockNumber(uint256 _blockNumber) external override {
        require(msg.sender == cleanupBlockNumberManager, "only cleanup block manager");
        _setCleanupBlockNumber(_blockNumber);
        if (address(readVpContract) != address(0)) {
            readVpContract.setCleanupBlockNumber(_blockNumber);
        }
        if (address(writeVpContract) != address(0) && address(writeVpContract) != address(readVpContract)) {
            writeVpContract.setCleanupBlockNumber(_blockNumber);
        }
        if (address(governanceVP) != address(0)) {
            governanceVP.setCleanupBlockNumber(_blockNumber);
        }
    }

    /**
     * @inheritdoc IICleanable
     */
    function cleanupBlockNumber() external view override returns (uint256) {
        return _cleanupBlockNumber();
    }

    /**
     * @inheritdoc IIVPToken
     */
    function setCleanupBlockNumberManager(address _cleanupBlockNumberManager) external override onlyGovernance {
        cleanupBlockNumberManager = _cleanupBlockNumberManager;
    }

    /**
     * @inheritdoc IICleanable
     */
    function setCleanerContract(address _cleanerContract) external override onlyGovernance {
        _setCleanerContract(_cleanerContract);
        if (address(readVpContract) != address(0)) {
            readVpContract.setCleanerContract(_cleanerContract);
        }
        if (address(writeVpContract) != address(0) && address(writeVpContract) != address(readVpContract)) {
            writeVpContract.setCleanerContract(_cleanerContract);
        }
        if (address(governanceVP) != address(0)) {
            governanceVP.setCleanerContract(_cleanerContract);
        }
    }

    /**
     * @inheritdoc IIVPToken
     */
    function setGovernanceVotePower(IIGovernanceVotePower _governanceVotePower) external override onlyGovernance {
        require(address(_governanceVotePower.ownerToken()) == address(this),
            "Governance vote power contract does not belong to this token.");
        emit VotePowerContractChanged(2, address(governanceVP), address(_governanceVotePower));
        governanceVP = _governanceVotePower;
    }

    /**
     * When set, allows token owners to participate in governance voting
     * and delegate governance vote power.
     */
     function governanceVotePower() external view override returns (IGovernanceVotePower) {
         return governanceVP;
     }
}


// File contracts/token/lib/DelegationHistory.sol





/**
 * @title DelegationHistory library
 * @notice A contract to manage checkpoints as of a given block.
 * @dev Store value history by block number with detachable state.
 **/
library DelegationHistory {
    using SafeMath for uint256;
    using SafePct for uint256;
    using SafeCast for uint256;

    uint256 public constant MAX_DELEGATES_BY_PERCENT = 2;
    string private constant MAX_DELEGATES_MSG = "Max delegates exceeded";
    
    struct Delegation {
        address delegate;
        uint16 value;
        
        // delegations[0] will also hold length and blockNumber to save 1 slot of storage per checkpoint
        // for all other indexes these fields will be 0
        // also, when checkpoint is empty, `length` will automatically be 0, which is ok
        uint64 fromBlock;
        uint8 length;       // length is limited to MAX_DELEGATES_BY_PERCENT which fits in 8 bits
    }
    
    /**
     * @dev `CheckPoint` is the structure that attaches a block number to a
     *  given value; the block number attached is the one that last changed the
     *  value
     **/
    struct CheckPoint {
        // the list of delegations at the time
        mapping(uint256 => Delegation) delegations;
    }

    struct CheckPointHistoryState {
        // `checkpoints` is an array that tracks delegations at non-contiguous block numbers
        mapping(uint256 => CheckPoint) checkpoints;
        // `checkpoints` before `startIndex` have been deleted
        // INVARIANT: checkpoints.length == 0 || startIndex < checkpoints.length      (strict!)
        uint64 startIndex;
        uint64 length;
    }

    /**
     * @notice Queries the value at a specific `_blockNumber`
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _delegate The delegate for which we need value.
     * @param _blockNumber The block number of the value active at that time
     * @return _value The value of the `_delegate` at `_blockNumber`     
     **/
    function valueOfAt(
        CheckPointHistoryState storage _self, 
        address _delegate, 
        uint256 _blockNumber
    )
        internal view 
        returns (uint256 _value)
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) return 0;
        return _getValueForDelegate(_self.checkpoints[index], _delegate);
    }

    /**
     * @notice Queries the value at `block.number`
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _delegate The delegate for which we need value.
     * @return _value The value at `block.number`
     **/
    function valueOfAtNow(
        CheckPointHistoryState storage _self, 
        address _delegate
    )
        internal view
        returns (uint256 _value)
    {
        uint256 length = _self.length;
        if (length == 0) return 0;
        return _getValueForDelegate(_self.checkpoints[length - 1], _delegate);
    }

    /**
     * @notice Writes the value at the current block.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _delegate The delegate tu update.
     * @param _value The new value to set for this delegate (value `0` deletes `_delegate` from the list).
     **/
    function writeValue(
        CheckPointHistoryState storage _self, 
        address _delegate, 
        uint256 _value
    )
        internal
    {
        uint256 historyCount = _self.length;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            if (_value != 0) {
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                cp.delegations[0] = Delegation({ 
                    delegate: _delegate,
                    value: _value.toUint16(),
                    fromBlock:  block.number.toUint64(),
                    length: 1 
                });
            }
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            CheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.delegations[0].fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                _updateDelegates(lastCheckpoint, _delegate, _value);
            } else {
                // we should never have future blocks in history
                assert(block.number > lastBlock); 
                // last check point block is before
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                _copyAndUpdateDelegates(cp, lastCheckpoint, _delegate, _value);
                cp.delegations[0].fromBlock = block.number.toUint64();
            }
        }
    }
    
    /**
     * Get all percentage delegations active at a time.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _blockNumber The block number to query. 
     * @return _delegates The active percentage delegates at the time. 
     * @return _values The delegates' values at the time. 
     **/
    function delegationsAt(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (
            address[] memory _delegates,
            uint256[] memory _values
        )
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) {
            return (new address[](0), new uint256[](0));
        }

        // copy delegates and values to memory arrays
        // (to prevent caller updating the stored value)
        CheckPoint storage cp = _self.checkpoints[index];
        uint256 length = cp.delegations[0].length;
        _delegates = new address[](length);
        _values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            Delegation storage dlg = cp.delegations[i];
            _delegates[i] = dlg.delegate;
            _values[i] = dlg.value;
        }
    }
    
    /**
     * Get all percentage delegations active now.
     * @param _self A CheckPointHistoryState instance to manage.
     * @return _delegates The active percentage delegates. 
     * @return _values The delegates' values. 
     **/
    function delegationsAtNow(
        CheckPointHistoryState storage _self
    )
        internal view
        returns (address[] memory _delegates, uint256[] memory _values)
    {
        return delegationsAt(_self, block.number);
    }
    
    /**
     * Get all percentage delegations active now.
     * @param _self A CheckPointHistoryState instance to manage.
     * @return _length The number of delegations. 
     * @return _delegations . 
     **/
    function delegationsAtNowRaw(
        CheckPointHistoryState storage _self
    )
        internal view
        returns (
            uint256 _length, 
            mapping(uint256 => Delegation) storage _delegations
        )
    {
        uint256 length = _self.length;
        if (length == 0) {
            return (0, _self.checkpoints[0].delegations);
        }
        CheckPoint storage cp = _self.checkpoints[length - 1];
        return (cp.delegations[0].length, cp.delegations);
    }
    
    /**
     * Get the number of delegations.
     * @param _self A CheckPointHistoryState instance to query.
     * @param _blockNumber The block number to query. 
     * @return _count Count of delegations at the time.
     **/
    function countAt(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (uint256 _count)
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) return 0;
        return _self.checkpoints[index].delegations[0].length;
    }
    
    /**
     * Get the sum of all delegation values.
     * @param _self A CheckPointHistoryState instance to query.
     * @param _blockNumber The block number to query. 
     * @return _total Total delegation value at the time.
     **/
    function totalValueAt(
        CheckPointHistoryState storage _self, 
        uint256 _blockNumber
    )
        internal view
        returns (uint256 _total)
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) return 0;
        
        CheckPoint storage cp = _self.checkpoints[index];
        uint256 length = cp.delegations[0].length;
        _total = 0;
        for (uint256 i = 0; i < length; i++) {
            _total = _total.add(cp.delegations[i].value);
        }
    }

    /**
     * Get the sum of all delegation values.
     * @param _self A CheckPointHistoryState instance to query.
     * @return _total Total delegation value at the time.
     **/
    function totalValueAtNow(
        CheckPointHistoryState storage _self
    )
        internal view
        returns (uint256 _total)
    {
        return totalValueAt(_self, block.number);
    }

    /**
     * Get the sum of all delegation values, every one scaled by `_mul/_div`.
     * @param _self A CheckPointHistoryState instance to query.
     * @param _mul The multiplier.
     * @param _div The divisor.
     * @param _blockNumber The block number to query. 
     * @return _total Total scaled delegation value at the time.
     **/
    function scaledTotalValueAt(
        CheckPointHistoryState storage _self, 
        uint256 _mul,
        uint256 _div,
        uint256 _blockNumber
    )
        internal view
        returns (uint256 _total)
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) return 0;
        
        CheckPoint storage cp = _self.checkpoints[index];
        uint256 length = cp.delegations[0].length;
        _total = 0;
        for (uint256 i = 0; i < length; i++) {
            _total = _total.add(uint256(cp.delegations[i].value).mulDiv(_mul, _div));
        }
    }

    /**
     * Clear all delegations at this moment.
     * @param _self A CheckPointHistoryState instance to manage.
     */    
    function clear(CheckPointHistoryState storage _self) internal {
        uint256 historyCount = _self.length;
        if (historyCount > 0) {
            // add an empty checkpoint
            CheckPoint storage cp = _self.checkpoints[historyCount];
            _self.length = SafeCast.toUint64(historyCount + 1);
            // create empty checkpoint = only set fromBlock
            cp.delegations[0] = Delegation({ 
                delegate: address(0),
                value: 0,
                fromBlock: block.number.toUint64(),
                length: 0
            });
        }
    }

    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain 
     * (unless the history was empty to start with).
     */    
    function cleanupOldCheckpoints(
        CheckPointHistoryState storage _self, 
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        if (_cleanupBlockNumber == 0) return 0;   // optimization for when cleaning is not enabled
        uint256 length = _self.length;
        if (length == 0) return 0;
        uint256 startIndex = _self.startIndex;
        // length - 1 is safe, since length != 0 (check above)
        uint256 endIndex = Math.min(startIndex.add(_count), length - 1);    // last element can never be deleted
        uint256 index = startIndex;
        // we can delete `checkpoint[index]` while the next checkpoint is at `_cleanupBlockNumber` or before
        while (index < endIndex && _self.checkpoints[index + 1].delegations[0].fromBlock <= _cleanupBlockNumber) {
            CheckPoint storage cp = _self.checkpoints[index];
            uint256 cplength = cp.delegations[0].length;
            for (uint256 i = 0; i < cplength; i++) {
                delete cp.delegations[i];
            }
            index++;
        }
        if (index > startIndex) {   // index is the first not deleted index
            _self.startIndex = SafeCast.toUint64(index);
        }
        return index - startIndex;  // safe: index = startIndex at start and increases in loop
    }

    /////////////////////////////////////////////////////////////////////////////////
    // helper functions for writeValueAt
    
    function _copyAndUpdateDelegates(
        CheckPoint storage _cp, 
        CheckPoint storage _orig, 
        address _delegate, 
        uint256 _value
    )
        private
    {
        uint256 length = _orig.delegations[0].length;
        bool updated = false;
        uint256 newlength = 0;
        for (uint256 i = 0; i < length; i++) {
            Delegation memory origDlg = _orig.delegations[i];
            if (origDlg.delegate == _delegate) {
                // copy delegate, but with new value
                newlength = _appendDelegate(_cp, origDlg.delegate, _value, newlength);
                updated = true;
            } else {
                // just copy the delegate with original value
                newlength = _appendDelegate(_cp, origDlg.delegate, origDlg.value, newlength);
            }
        }
        if (!updated) {
            // delegate is not in the original list, so add it
            newlength = _appendDelegate(_cp, _delegate, _value, newlength);
        }
        // safe - newlength <= length + 1 <= MAX_DELEGATES_BY_PERCENT
        _cp.delegations[0].length = uint8(newlength);
    }

    function _updateDelegates(CheckPoint storage _cp, address _delegate, uint256 _value) private {
        uint256 length = _cp.delegations[0].length;
        uint256 i = 0;
        while (i < length && _cp.delegations[i].delegate != _delegate) ++i;
        if (i < length) {
            if (_value != 0) {
                _cp.delegations[i].value = _value.toUint16();
            } else {
                _deleteDelegate(_cp, i, length - 1);  // length - 1 is safe:  0 <= i < length
                _cp.delegations[0].length = uint8(length - 1);
            }
        } else {
            uint256 newlength = _appendDelegate(_cp, _delegate, _value, length);
            _cp.delegations[0].length = uint8(newlength);  // safe - length <= MAX_DELEGATES_BY_PERCENT
        }
    }
    
    function _appendDelegate(CheckPoint storage _cp, address _delegate, uint256 _value, uint256 _length) 
        private 
        returns (uint256)
    {
        if (_value != 0) {
            require(_length < MAX_DELEGATES_BY_PERCENT, MAX_DELEGATES_MSG);
            Delegation storage dlg = _cp.delegations[_length];
            dlg.delegate = _delegate;
            dlg.value = _value.toUint16();
            // for delegations[0], fromBlock and length are assigned outside
            return _length + 1;
        }
        return _length;
    }
    
    function _deleteDelegate(CheckPoint storage _cp, uint256 _index, uint256 _last) private {
        Delegation storage dlg = _cp.delegations[_index];
        Delegation storage lastDlg = _cp.delegations[_last];
        if (_index < _last) {
            dlg.delegate = lastDlg.delegate;
            dlg.value = lastDlg.value;
        }
        lastDlg.delegate = address(0);
        lastDlg.value = 0;
    }
    
    /////////////////////////////////////////////////////////////////////////////////
    // helper functions for querying
    
    /**
     * @notice Binary search of _checkpoints array.
     * @param _checkpoints An array of CheckPoint to search.
     * @param _startIndex Smallest possible index to be returned.
     * @param _blockNumber The block number to search for.
     */
    function _binarySearchGreatestBlockLessThan(
        mapping(uint256 => CheckPoint) storage _checkpoints, 
        uint256 _startIndex,
        uint256 _endIndex,
        uint256 _blockNumber
    )
        private view
        returns (uint256 _index)
    {
        // Binary search of the value by given block number in the array
        uint256 min = _startIndex;
        uint256 max = _endIndex.sub(1);
        while (max > min) {
            uint256 mid = (max.add(min).add(1)).div(2);
            if (_checkpoints[mid].delegations[0].fromBlock <= _blockNumber) {
                min = mid;
            } else {
                max = mid.sub(1);
            }
        }
        return min;
    }

    /**
     * @notice Binary search of _checkpoints array. Extra optimized for the common case when we are 
     *   searching for the last block.
     * @param _self The state to query.
     * @param _blockNumber The block number to search for.
     * @return _found true if value was found (only `false` if `_blockNumber` is before first 
     *   checkpoint or the checkpoint array is empty)
     * @return _index index of the newest block with number less than or equal `_blockNumber`
     */
    function _findGreatestBlockLessThan(
        CheckPointHistoryState storage _self, 
        uint256 _blockNumber
    )
        private view
        returns (
            bool _found,
            uint256 _index
        )
    {
        uint256 startIndex = _self.startIndex;
        uint256 historyCount = _self.length;
        if (historyCount == 0) {
            _found = false;
        } else if (_blockNumber >= _self.checkpoints[historyCount - 1].delegations[0].fromBlock) {
            _found = true;
            _index = historyCount - 1;  // safe, historyCount != 0 in this branch
        } else if (_blockNumber < _self.checkpoints[startIndex].delegations[0].fromBlock) {
            // reading data before `_startIndex` is only safe before first cleanup
            require(startIndex == 0, "DelegationHistory: reading from cleaned-up block");
            _found = false;
        } else {
            _found = true;
            _index = _binarySearchGreatestBlockLessThan(_self.checkpoints, startIndex, historyCount, _blockNumber);
        }
    }
    
    /**
     * Find delegate and return its value or 0 if not found.
     */
    function _getValueForDelegate(CheckPoint storage _cp, address _delegate) internal view returns (uint256) {
        uint256 length = _cp.delegations[0].length;
        for (uint256 i = 0; i < length; i++) {
            Delegation storage dlg = _cp.delegations[i];
            if (dlg.delegate == _delegate) {
                return dlg.value;
            }
        }
        return 0;   // _delegate not found
    }
}


// File contracts/token/lib/PercentageDelegation.sol





/**
 * @title PercentageDelegation library
 * @notice Only handles percentage delegation  
 * @notice A library to manage a group of _delegates for allocating voting power by a delegator.
 **/
library PercentageDelegation {
    using CheckPointHistory for CheckPointHistory.CheckPointHistoryState;
    using DelegationHistory for DelegationHistory.CheckPointHistoryState;
    using SafeMath for uint256;
    using SafePct for uint256;

    uint256 public constant MAX_BIPS = 10000;
    string private constant MAX_BIPS_MSG = "Max delegation bips exceeded";
    
    /**
     * @dev `DelegationState` is the state structure used by this library to contain/manage
     *  a grouing of _delegates (a PercentageDelegation) for a delegator.
     */
    struct DelegationState {
        // percentages by _delegates
        DelegationHistory.CheckPointHistoryState delegation;
    }

    /**
     * @notice Add or replace an existing _delegate with allocated vote power in basis points.
     * @param _self A DelegationState instance to manage.
     * @param _delegate The address of the _delegate to add/replace
     * @param _bips Allocation of the delegation specified in basis points (1/100 of 1 percent)
     * @dev If you send a `_bips` of zero, `_delegate` will be deleted if one
     *  exists in the delegation; if zero and `_delegate` does not exist, it will not be added.
     */
    function addReplaceDelegate(
        DelegationState storage _self, 
        address _delegate, 
        uint256 _bips
    )
        internal
    {
        // Check for max delegation basis points
        assert(_bips <= MAX_BIPS);

        // Change the delegate's percentage
        _self.delegation.writeValue(_delegate, _bips);
        
        // check the total
        require(_self.delegation.totalValueAtNow() <= MAX_BIPS, MAX_BIPS_MSG);
    }

    /**
     * @notice Get the total of the explicit vote power delegation bips of all delegates at given block.
     * @param _self A DelegationState instance to manage.
     * @param _blockNumber The block to query.
     * @return _totalBips The total vote power bips delegated.
     */
    function getDelegatedTotalAt(
        DelegationState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (uint256 _totalBips)
    {
        return _self.delegation.totalValueAt(_blockNumber);
    }

    /**
     * @notice Get the total of the bips vote power delegation bips of all _delegates.
     * @param _self A DelegationState instance to manage.
     * @return _totalBips The total vote power bips delegated.
     */
    function getDelegatedTotal(
        DelegationState storage _self
    )
        internal view
        returns (uint256 _totalBips)
    {
        return _self.delegation.totalValueAtNow();
    }

    /**
     * @notice Given a _delegate address, return the bips of the vote power delegation.
     * @param _self A DelegationState instance to manage.
     * @param _delegate The delegate address to find.
     * @param _blockNumber The block to query.
     * @return _bips The percent of vote power allocated to the delegate address.
     */
    function getDelegatedValueAt(
        DelegationState storage _self, 
        address _delegate,
        uint256 _blockNumber
    )
        internal view 
        returns (uint256 _bips)
    {
        return _self.delegation.valueOfAt(_delegate, _blockNumber);
    }

    /**
     * @notice Given a delegate address, return the bips of the vote power delegation.
     * @param _self A DelegationState instance to manage.
     * @param _delegate The delegate address to find.
     * @return _bips The percent of vote power allocated to the delegate address.
     */
    function getDelegatedValue(
        DelegationState storage _self, 
        address _delegate
    )
        internal view
        returns (uint256 _bips)
    {
        return _self.delegation.valueOfAtNow(_delegate);
    }

    /**
     * @notice Returns lists of delegate addresses and corresponding values at given block.
     * @param _self A DelegationState instance to manage.
     * @param _blockNumber The block to query.
     * @return _delegates Positional array of delegation addresses.
     * @return _values Positional array of delegation percents specified in basis points (1/100 or 1 percent)
     */
    function getDelegationsAt(
        DelegationState storage _self,
        uint256 _blockNumber
    )
        internal view 
        returns (
            address[] memory _delegates,
            uint256[] memory _values
        )
    {
        return _self.delegation.delegationsAt(_blockNumber);
    }
    
    /**
     * @notice Returns lists of delegate addresses and corresponding values.
     * @param _self A DelegationState instance to manage.
     * @return _delegates Positional array of delegation addresses.
     * @return _values Positional array of delegation percents specified in basis points (1/100 or 1 percent)
     */
    function getDelegations(
        DelegationState storage _self
    )
        internal view
        returns (
            address[] memory _delegates,
            uint256[] memory _values
        ) 
    {
        return _self.delegation.delegationsAtNow();
    }
    
    /**
     * Get all percentage delegations active now.
     * @param _self A CheckPointHistoryState instance to manage.
     * @return _length The number of delegations. 
     * @return _delegations . 
     **/
    function getDelegationsRaw(
        DelegationState storage _self
    )
        internal view
        returns (
            uint256 _length, 
            mapping(uint256 => DelegationHistory.Delegation) storage _delegations
        )
    {
        return _self.delegation.delegationsAtNowRaw();
    }
    
    /**
     * Get the number of delegations.
     * @param _self A DelegationState instance to manage.
     * @param _blockNumber The block number to query. 
     * @return _count Count of delegations at the time.
     **/
    function getCountAt(
        DelegationState storage _self,
        uint256 _blockNumber
    )
        internal view 
        returns (uint256 _count)
    {
        return _self.delegation.countAt(_blockNumber);
    }

    /**
     * Get the number of delegations.
     * @param _self A DelegationState instance to manage.
     * @return _count Count of delegations at the time.
     **/
    function getCount(
        DelegationState storage _self
    )
        internal view
        returns (uint256 _count)
    {
        return _self.delegation.countAt(block.number);
    }
    
    /**
     * @notice Get the total amount (absolute) of the vote power delegation of all delegates.
     * @param _self A DelegationState instance to manage.
     * @param _balance Owner's balance.
     * @return _totalAmount The total vote power amount delegated.
     */
    function getDelegatedTotalAmountAt(
        DelegationState storage _self, 
        uint256 _balance,
        uint256 _blockNumber
    )
        internal view 
        returns (uint256 _totalAmount)
    {
        return _self.delegation.scaledTotalValueAt(_balance, MAX_BIPS, _blockNumber);
    }
    
    /**
     * @notice Clears all delegates.
     * @param _self A DelegationState instance to manage.
     * @dev Delegation mode remains PERCENTAGE, even though the delgation is now empty.
     */
    function clear(DelegationState storage _self) internal {
        _self.delegation.clear();
    }


    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain 
     * (unless the history was empty to start with).
     */    
    function cleanupOldCheckpoints(
        DelegationState storage _self, 
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        return _self.delegation.cleanupOldCheckpoints(_count, _cleanupBlockNumber);
    }
}


// File contracts/token/lib/ExplicitDelegation.sol





/**
 * @title ExplicitDelegation library
 * @notice A library to manage a group of delegates for allocating voting power by a delegator.
 **/
library ExplicitDelegation {
    using CheckPointHistory for CheckPointHistory.CheckPointHistoryState;
    using CheckPointsByAddress for CheckPointsByAddress.CheckPointsByAddressState;
    using SafeMath for uint256;
    using SafePct for uint256;

    /**
     * @dev `DelegationState` is the state structure used by this library to contain/manage
     *  a grouing of delegates (a ExplicitDelegation) for a delegator.
     */
    struct DelegationState {
        CheckPointHistory.CheckPointHistoryState delegatedTotal;

        // `delegatedVotePower` is a map of delegators pointing to a map of delegates
        // containing a checkpoint history of delegated vote power balances.
        CheckPointsByAddress.CheckPointsByAddressState delegatedVotePower;
    }

    /**
     * @notice Add or replace an existing _delegate with new vote power (explicit).
     * @param _self A DelegationState instance to manage.
     * @param _delegate The address of the _delegate to add/replace
     * @param _amount Allocation of the delegation as explicit amount
     */
    function addReplaceDelegate(
        DelegationState storage _self, 
        address _delegate, 
        uint256 _amount
    )
        internal
    {
        uint256 prevAmount = _self.delegatedVotePower.valueOfAtNow(_delegate);
        uint256 newTotal = _self.delegatedTotal.valueAtNow().sub(prevAmount, "Total < 0").add(_amount);
        _self.delegatedVotePower.writeValue(_delegate, _amount);
        _self.delegatedTotal.writeValue(newTotal);
    }
    

    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain 
     * (unless the history was empty to start with).
     */    
    function cleanupOldCheckpoints(
        DelegationState storage _self, 
        address _owner, 
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns(uint256 _deleted)
    {
        _deleted = _self.delegatedTotal.cleanupOldCheckpoints(_count, _cleanupBlockNumber);
        // safe: cleanupOldCheckpoints always returns the number of deleted elements which is small, so no owerflow
        _deleted += _self.delegatedVotePower.cleanupOldCheckpoints(_owner, _count, _cleanupBlockNumber);
    }
    
    /**
     * @notice Get the _total of the explicit vote power delegation amount.
     * @param _self A DelegationState instance to manage.
     * @param _blockNumber The block to query.
     * @return _total The _total vote power amount delegated.
     */
    function getDelegatedTotalAt(
        DelegationState storage _self, uint256 _blockNumber
    )
        internal view 
        returns (uint256 _total)
    {
        return _self.delegatedTotal.valueAt(_blockNumber);
    }
    
    /**
     * @notice Get the _total of the explicit vote power delegation amount.
     * @param _self A DelegationState instance to manage.
     * @return _total The total vote power amount delegated.
     */
    function getDelegatedTotal(
        DelegationState storage _self
    )
        internal view 
        returns (uint256 _total)
    {
        return _self.delegatedTotal.valueAtNow();
    }
    
    /**
     * @notice Given a delegate address, return the explicit amount of the vote power delegation.
     * @param _self A DelegationState instance to manage.
     * @param _delegate The _delegate address to find.
     * @param _blockNumber The block to query.
     * @return _value The percent of vote power allocated to the _delegate address.
     */
    function getDelegatedValueAt(
        DelegationState storage _self, 
        address _delegate,
        uint256 _blockNumber
    )
        internal view
        returns (uint256 _value)
    {
        return _self.delegatedVotePower.valueOfAt(_delegate, _blockNumber);
    }

    /**
     * @notice Given a delegate address, return the explicit amount of the vote power delegation.
     * @param _self A DelegationState instance to manage.
     * @param _delegate The _delegate address to find.
     * @return _value The percent of vote power allocated to the _delegate address.
     */
    function getDelegatedValue(
        DelegationState storage _self, 
        address _delegate
    )
        internal view 
        returns (uint256 _value)
    {
        return _self.delegatedVotePower.valueOfAtNow(_delegate);
    }
}


// File contracts/token/lib/VotePower.sol




/**
 * @title Vote power library
 * @notice A library to record delegate vote power balances by delegator 
 *  and delegatee.
 **/
library VotePower {
    using CheckPointHistory for CheckPointHistory.CheckPointHistoryState;
    using CheckPointsByAddress for CheckPointsByAddress.CheckPointsByAddressState;
    using SafeMath for uint256;

    /**
     * @dev `VotePowerState` is state structure used by this library to manage vote
     *  power amounts by delegator and it's delegates.
     */
    struct VotePowerState {
        // `votePowerByAddress` is the map that tracks the voting power balance
        //  of each address, by block.
        CheckPointsByAddress.CheckPointsByAddressState votePowerByAddress;
    }

    /**
     * @notice This modifier checks that both addresses are non-zero.
     * @param _delegator A delegator address.
     * @param _delegatee A delegatee address.
     */
    modifier addressesNotZero(address _delegator, address _delegatee) {
        // Both addresses cannot be zero
        assert(!(_delegator == address(0) && _delegatee == address(0)));
        _;
    }


    /**
     * @notice Delegate vote power `_amount` to `_delegatee` address from `_delegator` address.
     * @param _delegator Delegator address 
     * @param _delegatee Delegatee address
     * @param _amount The _amount of vote power to send from _delegator to _delegatee
     * @dev Amount recorded at the current block.
     **/
    function delegate(
        VotePowerState storage _self, 
        address _delegator, 
        address _delegatee,
        uint256 _amount
    )
        internal 
        addressesNotZero(_delegator, _delegatee)
    {
        // Shortcut
        if (_amount == 0) {
            return;
        }

        // Transmit vote power
        _self.votePowerByAddress.transmit(_delegator, _delegatee, _amount);
    }

    /**
     * @notice Change the current vote power value.
     * @param _owner Address of vote power owner.
     * @param _add The amount to add to the vote power.
     * @param _sub The amount to subtract from the vote power.
     */
    function changeValue(
        VotePowerState storage _self, 
        address _owner,
        uint256 _add,
        uint256 _sub
    )
        internal
    {
        assert(_owner != address(0));
        if (_add == _sub) return;
        uint256 value = _self.votePowerByAddress.valueOfAtNow(_owner);
        value = value.add(_add).sub(_sub);
        _self.votePowerByAddress.writeValue(_owner, value);
    }
    
    /**
     * @notice Undelegate vote power `_amount` from `_delegatee` address 
     *  to `_delegator` address
     * @param _delegator Delegator address 
     * @param _delegatee Delegatee address
     * @param _amount The amount of vote power recovered by delegator from delegatee
     **/
    function undelegate(
        VotePowerState storage _self, 
        address _delegator, 
        address _delegatee,
        uint256 _amount
    )
        internal
        addressesNotZero(_delegator, _delegatee)
    {
        // Shortcut
        if (_amount == 0) {
            return;
        }

        // Recover vote power
        _self.votePowerByAddress.transmit(_delegatee, _delegator, _amount);
    }

    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain 
     * (unless the history was empty to start with).
     */    
    function cleanupOldCheckpoints(
        VotePowerState storage _self, 
        address _owner, 
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        return _self.votePowerByAddress.cleanupOldCheckpoints(_owner, _count, _cleanupBlockNumber);
    }

    /**
     * @notice Get the vote power of `_who` at `_blockNumber`.
     * @param _self A VotePowerState instance to manage.
     * @param _who Address to get vote power.
     * @param _blockNumber Block number of the block to fetch vote power.
     * @return _votePower The fetched vote power.
     */
    function votePowerOfAt(
        VotePowerState storage _self, 
        address _who, 
        uint256 _blockNumber
    )
        internal view 
        returns(uint256 _votePower)
    {
        return _self.votePowerByAddress.valueOfAt(_who, _blockNumber);
    }

    /**
     * @notice Get the current vote power of `_who`.
     * @param _self A VotePowerState instance to manage.
     * @param _who Address to get vote power.
     * @return _votePower The fetched vote power.
     */
    function votePowerOfAtNow(
        VotePowerState storage _self, 
        address _who
    )
        internal view
        returns(uint256 _votePower)
    {
        return _self.votePowerByAddress.valueOfAtNow(_who);
    }
}


// File contracts/token/lib/VotePowerCache.sol



/**
 * @title Vote power library
 * @notice A library to record delegate vote power balances by delegator 
 *  and delegatee.
 **/
library VotePowerCache {
    using SafeMath for uint256;
    using VotePower for VotePower.VotePowerState;

    struct RevocationCacheRecord {
        // revoking delegation only affects cached value therefore we have to track
        // the revocation in order not to revoke twice
        // mapping delegatee => revokedValue
        mapping(address => uint256) revocations;
    }
    
    /**
     * @dev `CacheState` is state structure used by this library to manage vote
     *  power amounts by delegator and it's delegates.
     */
    struct CacheState {
        // map keccak256([address, _blockNumber]) -> (value + 1)
        mapping(bytes32 => uint256) valueCache;
        
        // map keccak256([address, _blockNumber]) -> RevocationCacheRecord
        mapping(bytes32 => RevocationCacheRecord) revocationCache;
    }

    /**
    * @notice Get the cached value at given block. If there is no cached value, original
    *    value is returned and stored to cache. Cache never gets stale, because original
    *    value can never change in a past block.
    * @param _self A VotePowerCache instance to manage.
    * @param _votePower A VotePower instance to read from if cache is empty.
    * @param _who Address to get vote power.
    * @param _blockNumber Block number of the block to fetch vote power.
    * precondition: _blockNumber < block.number
    */
    function valueOfAt(
        CacheState storage _self,
        VotePower.VotePowerState storage _votePower,
        address _who,
        uint256 _blockNumber
    )
        internal 
        returns (uint256 _value, bool _createdCache)
    {
        bytes32 key = keccak256(abi.encode(_who, _blockNumber));
        // is it in cache?
        uint256 cachedValue = _self.valueCache[key];
        if (cachedValue != 0) {
            return (cachedValue - 1, false);    // safe, cachedValue != 0
        }
        // read from _votePower
        uint256 votePowerValue = _votePower.votePowerOfAt(_who, _blockNumber);
        _writeCacheValue(_self, key, votePowerValue);
        return (votePowerValue, true);
    }

    /**
    * @notice Get the cached value at given block. If there is no cached value, original
    *    value is returned. Cache is never modified.
    * @param _self A VotePowerCache instance to manage.
    * @param _votePower A VotePower instance to read from if cache is empty.
    * @param _who Address to get vote power.
    * @param _blockNumber Block number of the block to fetch vote power.
    * precondition: _blockNumber < block.number
    */
    function valueOfAtReadonly(
        CacheState storage _self,
        VotePower.VotePowerState storage _votePower,
        address _who,
        uint256 _blockNumber
    )
        internal view 
        returns (uint256 _value)
    {
        bytes32 key = keccak256(abi.encode(_who, _blockNumber));
        // is it in cache?
        uint256 cachedValue = _self.valueCache[key];
        if (cachedValue != 0) {
            return cachedValue - 1;     // safe, cachedValue != 0
        }
        // read from _votePower
        return _votePower.votePowerOfAt(_who, _blockNumber);
    }
    
    /**
    * @notice Delete cached value for `_who` at given block.
    *   Only used for history cleanup.
    * @param _self A VotePowerCache instance to manage.
    * @param _who Address to get vote power.
    * @param _blockNumber Block number of the block to fetch vote power.
    * @return _deleted The number of cache items deleted (always 0 or 1).
    * precondition: _blockNumber < cleanupBlockNumber
    */
    function deleteValueAt(
        CacheState storage _self,
        address _who,
        uint256 _blockNumber
    )
        internal
        returns (uint256 _deleted)
    {
        bytes32 key = keccak256(abi.encode(_who, _blockNumber));
        if (_self.valueCache[key] != 0) {
            delete _self.valueCache[key];
            return 1;
        }
        return 0;
    }
    
    /**
    * @notice Revoke vote power delegation from `from` to `to` at given block.
    *   Updates cached values for the block, so they are the only vote power values respecting revocation.
    * @dev Only delegatees cached value is changed, delegator doesn't get the vote power back; so
    *   the revoked vote power is forfeit for as long as this vote power block is in use. This is needed to
    *   prevent double voting.
    * @param _self A VotePowerCache instance to manage.
    * @param _votePower A VotePower instance to read from if cache is empty.
    * @param _from The delegator.
    * @param _to The delegatee.
    * @param _revokedValue Value of delegation is not stored here, so it must be supplied by caller.
    * @param _blockNumber Block number of the block to modify.
    * precondition: _blockNumber < block.number
    */
    function revokeAt(
        CacheState storage _self,
        VotePower.VotePowerState storage _votePower,
        address _from,
        address _to,
        uint256 _revokedValue,
        uint256 _blockNumber
    )
        internal
    {
        if (_revokedValue == 0) return;
        bytes32 keyFrom = keccak256(abi.encode(_from, _blockNumber));
        if (_self.revocationCache[keyFrom].revocations[_to] != 0) {
            revert("Already revoked");
        }
        // read values and prime cacheOf
        (uint256 valueTo,) = valueOfAt(_self, _votePower, _to, _blockNumber);
        // write new values
        bytes32 keyTo = keccak256(abi.encode(_to, _blockNumber));
        _writeCacheValue(_self, keyTo, valueTo.sub(_revokedValue, "Revoked value too large"));
        // mark as revoked
        _self.revocationCache[keyFrom].revocations[_to] = _revokedValue;
    }
    
    /**
    * @notice Delete revocation from `_from` to `_to` at block `_blockNumber`.
    *   Only used for history cleanup.
    * @param _self A VotePowerCache instance to manage.
    * @param _from The delegator.
    * @param _to The delegatee.
    * @param _blockNumber Block number of the block to modify.
    * precondition: _blockNumber < cleanupBlockNumber
    */
    function deleteRevocationAt(
        CacheState storage _self,
        address _from,
        address _to,
        uint256 _blockNumber
    )
        internal
        returns (uint256 _deleted)
    {
        bytes32 keyFrom = keccak256(abi.encode(_from, _blockNumber));
        RevocationCacheRecord storage revocationRec = _self.revocationCache[keyFrom];
        uint256 value = revocationRec.revocations[_to];
        if (value != 0) {
            delete revocationRec.revocations[_to];
            return 1;
        }
        return 0;
    }

    /**
    * @notice Returns true if `from` has revoked vote pover delgation of `to` in block `_blockNumber`.
    * @param _self A VotePowerCache instance to manage.
    * @param _from The delegator.
    * @param _to The delegatee.
    * @param _blockNumber Block number of the block to fetch result.
    * precondition: _blockNumber < block.number
    */
    function revokedFromToAt(
        CacheState storage _self,
        address _from,
        address _to,
        uint256 _blockNumber
    )
        internal view
        returns (bool revoked)
    {
        bytes32 keyFrom = keccak256(abi.encode(_from, _blockNumber));
        return _self.revocationCache[keyFrom].revocations[_to] != 0;
    }
    
    function _writeCacheValue(CacheState storage _self, bytes32 _key, uint256 _value) private {
        // store to cacheOf (add 1 to differentiate from empty)
        _self.valueCache[_key] = _value.add(1);
    }
}


// File contracts/token/implementation/Delegatable.sol








/**
 * Delegatable ERC20 behavior.
 *
 * Adds delegation capabilities to tokens. This contract orchestrates interaction between
 * managing a delegation and the vote power allocations that result.
 */
contract Delegatable is IVPContractEvents {
    using PercentageDelegation for PercentageDelegation.DelegationState;
    using ExplicitDelegation for ExplicitDelegation.DelegationState;
    using SafeMath for uint256;
    using SafePct for uint256;
    using VotePower for VotePower.VotePowerState;
    using VotePowerCache for VotePowerCache.CacheState;

    /**
     * Delegation mode of an account. Once set, it cannot be changed.
     *
     * * `NOTSET`: Delegation mode not set yet.
     * * `PERCENTAGE`: Delegation by percentage.
     * * `AMOUNT`: Delegation by amount (explicit).
     */
    enum DelegationMode {
        NOTSET,
        PERCENTAGE,
        AMOUNT
    }

    // The number of history cleanup steps executed for every write operation.
    // It is more than 1 to make as certain as possible that all history gets cleaned eventually.
    uint256 private constant CLEANUP_COUNT = 2;

    string constant private UNDELEGATED_VP_TOO_SMALL_MSG =
        "Undelegated vote power too small";

    // Map that tracks delegation mode of each address.
    mapping(address => DelegationMode) private delegationModes;

    // `percentageDelegations` is the map that tracks the percentage voting power delegation of each address.
    // Explicit delegations are tracked directly through votePower.
    mapping(address => PercentageDelegation.DelegationState) private percentageDelegations;

    mapping(address => ExplicitDelegation.DelegationState) private explicitDelegations;

    // `votePower` tracks all voting power balances
    VotePower.VotePowerState private votePower;

    // `votePower` tracks all voting power balances
    VotePowerCache.CacheState private votePowerCache;

    // Historic data for the blocks before `cleanupBlockNumber` can be erased,
    // history before that block should never be used since it can be inconsistent.
    uint256 private cleanupBlockNumber;

    /// Address of the contract that is allowed to call methods for history cleaning.
    address public cleanerContract;

    /**
     * Emitted when a vote power cache entry is created.
     * Allows history cleaners to track vote power cache cleanup opportunities off-chain.
     * @param _owner The address whose vote power has just been cached.
     * @param _blockNumber The block number at which the vote power has been cached.
     */
    event CreatedVotePowerCache(address _owner, uint256 _blockNumber);

    // Most history cleanup opportunities can be deduced from standard events:
    // Transfer(from, to, amount):
    //  - vote power checkpoints for `from` (if nonzero) and `to` (if nonzero)
    //  - vote power checkpoints for percentage delegatees of `from` and `to` are also created,
    //    but they don't have to be checked since Delegate events are also emitted in case of
    //    percentage delegation vote power change due to delegators balance change
    //  - Note: Transfer event is emitted from VPToken but vote power checkpoint delegationModes
    //    must be called on its writeVotePowerContract
    // Delegate(from, to, priorVP, newVP):
    //  - vote power checkpoints for `from` and `to`
    //  - percentage delegation checkpoint for `from` (if `from` uses percentage delegation mode)
    //  - explicit delegation checkpoint from `from` to `to` (if `from` uses explicit delegation mode)
    // Revoke(from, to, vp, block):
    //  - vote power cache for `from` and `to` at `block`
    //  - revocation cache block from `from` to `to` at `block`

    /**
     * Reading from history is not allowed before `cleanupBlockNumber`, since data before that
     * might have been deleted and is thus unreliable.
     * @param _blockNumber The block number being checked for validity.
     */
    modifier notBeforeCleanupBlock(uint256 _blockNumber) {
        require(_blockNumber >= cleanupBlockNumber, "Delegatable: reading from cleaned-up block");
        _;
    }

    /**
     * History cleaning methods can be called only from `cleanerContract`.
     */
    modifier onlyCleaner {
        require(msg.sender == cleanerContract, "Only cleaner contract");
        _;
    }

    /**
     * (Un)Allocate `_owner` vote power of `_amount` across owner delegate
     *  vote power percentages.
     * @param _owner The address of the vote power owner.
     * @param _priorBalance The owner's balance before change.
     * @param _newBalance The owner's balance after change.
     * @dev precondition: delegationModes[_owner] == DelegationMode.PERCENTAGE
     */
    function _allocateVotePower(address _owner, uint256 _priorBalance, uint256 _newBalance) private {
        // Get the voting delegation for the _owner
        PercentageDelegation.DelegationState storage delegation = percentageDelegations[_owner];
        // Track total owner vp change
        uint256 ownerVpAdd = _newBalance;
        uint256 ownerVpSub = _priorBalance;
        // Iterate over the delegates
        (uint256 length, mapping(uint256 => DelegationHistory.Delegation) storage delegations) =
            delegation.getDelegationsRaw();
        for (uint256 i = 0; i < length; i++) {
            DelegationHistory.Delegation storage dlg = delegations[i];
            address delegatee = dlg.delegate;
            uint256 value = dlg.value;
            // Compute the delegated vote power for the delegatee
            uint256 priorValue = _priorBalance.mulDiv(value, PercentageDelegation.MAX_BIPS);
            uint256 newValue = _newBalance.mulDiv(value, PercentageDelegation.MAX_BIPS);
            ownerVpAdd = ownerVpAdd.add(priorValue);
            ownerVpSub = ownerVpSub.add(newValue);
            // could optimize next lines by checking that priorValue != newValue, but that can only happen
            // for the transfer of 0 amount, which is prevented by the calling function
            votePower.changeValue(delegatee, newValue, priorValue);
            votePower.cleanupOldCheckpoints(delegatee, CLEANUP_COUNT, cleanupBlockNumber);
            emit Delegate(_owner, delegatee, priorValue, newValue);
        }
        // (ownerVpAdd - ownerVpSub) is how much the owner vp changes - will be 0 if delegation is 100%
        if (ownerVpAdd != ownerVpSub) {
            votePower.changeValue(_owner, ownerVpAdd, ownerVpSub);
            votePower.cleanupOldCheckpoints(_owner, CLEANUP_COUNT, cleanupBlockNumber);
        }
    }

    /**
     * Burn `_amount` of vote power for `_owner`.
     * @param _owner The address of the _owner vote power to burn.
     * @param _ownerCurrentBalance The current token balance of the owner (which is their allocatable vote power).
     * @param _amount The amount of vote power to burn.
     */
    function _burnVotePower(address _owner, uint256 _ownerCurrentBalance, uint256 _amount) internal {
        // revert with the same error as ERC20 in case transfer exceeds balance
        uint256 newOwnerBalance = _ownerCurrentBalance.sub(_amount, "ERC20: transfer amount exceeds balance");
        if (delegationModes[_owner] == DelegationMode.PERCENTAGE) {
            // for PERCENTAGE delegation: reduce owner vote power allocations
            _allocateVotePower(_owner, _ownerCurrentBalance, newOwnerBalance);
        } else {
            // for AMOUNT delegation: is there enough unallocated VP _to burn if explicitly delegated?
            require(_isTransmittable(_owner, _ownerCurrentBalance, _amount), UNDELEGATED_VP_TOO_SMALL_MSG);
            // burn vote power
            votePower.changeValue(_owner, 0, _amount);
            votePower.cleanupOldCheckpoints(_owner, CLEANUP_COUNT, cleanupBlockNumber);
        }
    }

    /**
     * Get whether `_owner` current delegation can be delegated by percentage.
     * @param _owner Address of delegation to check.
     * @return True if delegation can be delegated by percentage.
     */
    function _canDelegateByPct(address _owner) internal view returns(bool) {
        // Get the delegation mode.
        DelegationMode delegationMode = delegationModes[_owner];
        // Return true if delegation is safe _to store percents, which can also
        // apply if there is not delegation mode set.
        return delegationMode == DelegationMode.NOTSET || delegationMode == DelegationMode.PERCENTAGE;
    }

    /**
     * Get whether `_owner` current delegation can be delegated by amount.
     * @param _owner Address of delegation to check.
     * @return True if delegation can be delegated by amount.
     */
    function _canDelegateByAmount(address _owner) internal view returns(bool) {
        // Get the delegation mode.
        DelegationMode delegationMode = delegationModes[_owner];
        // Return true if delegation is safe to store explicit amounts, which can also
        // apply if there is not delegation mode set.
        return delegationMode == DelegationMode.NOTSET || delegationMode == DelegationMode.AMOUNT;
    }

    /**
     * Delegate `_amount` of voting power to `_to` from `_from`
     * @param _from The address of the delegator
     * @param _to The address of the recipient
     * @param _senderCurrentBalance The senders current balance (not their voting power)
     * @param _amount The amount of voting power to be delegated
     */
    function _delegateByAmount(
        address _from,
        address _to,
        uint256 _senderCurrentBalance,
        uint256 _amount
    )
        internal virtual
    {
        require (_to != address(0), "Cannot delegate to zero");
        require (_to != _from, "Cannot delegate to self");
        require (_canDelegateByAmount(_from), "Cannot delegate by amount");

        // Get the vote power delegation for the sender
        ExplicitDelegation.DelegationState storage delegation = explicitDelegations[_from];

        // the prior value
        uint256 priorAmount = delegation.getDelegatedValue(_to);

        // Delegate new power
        if (_amount < priorAmount) {
            // Prior amount is greater, just reduce the delegated amount.
            // subtraction is safe since _amount < priorAmount
            votePower.undelegate(_from, _to, priorAmount - _amount);
        } else {
            // Is there enough undelegated vote power?
            uint256 availableAmount = _undelegatedVotePowerOf(_from, _senderCurrentBalance).add(priorAmount);
            require(availableAmount >= _amount, UNDELEGATED_VP_TOO_SMALL_MSG);
            // Increase the delegated amount of vote power.
            // subtraction is safe since _amount >= priorAmount
            votePower.delegate(_from, _to, _amount - priorAmount);
        }
        votePower.cleanupOldCheckpoints(_from, CLEANUP_COUNT, cleanupBlockNumber);
        votePower.cleanupOldCheckpoints(_to, CLEANUP_COUNT, cleanupBlockNumber);

        // Add/replace delegate
        delegation.addReplaceDelegate(_to, _amount);
        delegation.cleanupOldCheckpoints(_to, CLEANUP_COUNT, cleanupBlockNumber);

        // update mode if needed
        if (delegationModes[_from] != DelegationMode.AMOUNT) {
            delegationModes[_from] = DelegationMode.AMOUNT;
        }

        // emit event for delegation change
        emit Delegate(_from, _to, priorAmount, _amount);
    }

    /**
     * Delegate `_bips` of voting power to `_to` from `_from`
     * @param _from The address of the delegator
     * @param _to The address of the recipient
     * @param _senderCurrentBalance The senders current balance (not their voting power)
     * @param _bips The percentage of voting power in basis points (1/100 of 1 percent) to be delegated
     */
    function _delegateByPercentage(
        address _from,
        address _to,
        uint256 _senderCurrentBalance,
        uint256 _bips
    )
        internal virtual
    {
        require (_to != address(0), "Cannot delegate to zero");
        require (_to != _from, "Cannot delegate to self");
        require (_canDelegateByPct(_from), "Cannot delegate by percentage");

        // Get the vote power delegation for the sender
        PercentageDelegation.DelegationState storage delegation = percentageDelegations[_from];

        // Get prior percent for delegate if exists
        uint256 priorBips = delegation.getDelegatedValue(_to);
        uint256 reverseVotePower = 0;
        uint256 newVotePower = 0;

        // Add/replace delegate
        delegation.addReplaceDelegate(_to, _bips);
        delegation.cleanupOldCheckpoints(CLEANUP_COUNT, cleanupBlockNumber);

        // First, back out old voting power percentage, if not zero
        if (priorBips != 0) {
            reverseVotePower = _senderCurrentBalance.mulDiv(priorBips, PercentageDelegation.MAX_BIPS);
        }

        // Calculate the new vote power
        if (_bips != 0) {
            newVotePower = _senderCurrentBalance.mulDiv(_bips, PercentageDelegation.MAX_BIPS);
        }

        // Delegate new power
        if (newVotePower < reverseVotePower) {
            // subtraction is safe since newVotePower < reverseVotePower
            votePower.undelegate(_from, _to, reverseVotePower - newVotePower);
        } else {
            // subtraction is safe since newVotePower >= reverseVotePower
            votePower.delegate(_from, _to, newVotePower - reverseVotePower);
        }
        votePower.cleanupOldCheckpoints(_from, CLEANUP_COUNT, cleanupBlockNumber);
        votePower.cleanupOldCheckpoints(_to, CLEANUP_COUNT, cleanupBlockNumber);

        // update mode if needed
        if (delegationModes[_from] != DelegationMode.PERCENTAGE) {
            delegationModes[_from] = DelegationMode.PERCENTAGE;
        }

        // emit event for delegation change
        emit Delegate(_from, _to, reverseVotePower, newVotePower);
    }

    /**
     * @notice Get the delegation mode for '_who'. This mode determines whether vote power is
     *  allocated by percentage or by explicit value.
     * @param _who The address to get delegation mode.
     * @return Delegation mode
     */
    function _delegationModeOf(address _who) internal view returns (DelegationMode) {
        return delegationModes[_who];
    }

    /**
     * Get the vote power delegation `delegationAddresses`
     *  and `_bips` of an `_owner`. Returned in two separate positional arrays.
     * @param _owner The address to get delegations.
     * @param _blockNumber The block for which we want to know the delegations.
     * @return _delegateAddresses Positional array of delegation addresses.
     * @return _bips Positional array of delegation percents specified in basis points (1/100 or 1 percent)
     */
    function _percentageDelegatesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        internal view
        notBeforeCleanupBlock(_blockNumber)
        returns (
            address[] memory _delegateAddresses, 
            uint256[] memory _bips
        )
    {
        PercentageDelegation.DelegationState storage delegation = percentageDelegations[_owner];
        address[] memory allDelegateAddresses;
        uint256[] memory allBips;
        (allDelegateAddresses, allBips) = delegation.getDelegationsAt(_blockNumber);
        // delete revoked addresses
        for (uint256 i = 0; i < allDelegateAddresses.length; i++) {
            if (votePowerCache.revokedFromToAt(_owner, allDelegateAddresses[i], _blockNumber)) {
                allBips[i] = 0;
            }
        }
        uint256 length = 0;
        for (uint256 i = 0; i < allDelegateAddresses.length; i++) {
            if (allBips[i] != 0) length++;
        }
        _delegateAddresses = new address[](length);
        _bips = new uint256[](length);
        uint256 destIndex = 0;
        for (uint256 i = 0; i < allDelegateAddresses.length; i++) {
            if (allBips[i] != 0) {
                _delegateAddresses[destIndex] = allDelegateAddresses[i];
                _bips[destIndex] = allBips[i];
                destIndex++;
            }
        }
    }

    /**
     * Checks if enough undelegated vote power exists to allow a token
     *  transfer to occur if vote power is explicitly delegated.
     * @param _owner The address of transmittable vote power to check.
     * @param _ownerCurrentBalance The current balance of `_owner`.
     * @param _amount The amount to check.
     * @return True is `_amount` is transmittable.
     */
    function _isTransmittable(
        address _owner,
        uint256 _ownerCurrentBalance,
        uint256 _amount
    )
        private view returns(bool)
    {
        // Only proceed if we have a delegation by _amount
        if (delegationModes[_owner] == DelegationMode.AMOUNT) {
            // Return true if there is enough vote power _to cover the transfer
            return _undelegatedVotePowerOf(_owner, _ownerCurrentBalance) >= _amount;
        } else {
            // Not delegated by _amount, so transfer always allowed
            return true;
        }
    }

    /**
     * Mint `_amount` of vote power for `_owner`.
     * @param _owner The address of the owner to receive new vote power.
     * @param _amount The amount of vote power to mint.
     */
    function _mintVotePower(address _owner, uint256 _ownerCurrentBalance, uint256 _amount) internal {
        if (delegationModes[_owner] == DelegationMode.PERCENTAGE) {
            // Allocate newly minted vote power over delegates
            _allocateVotePower(_owner, _ownerCurrentBalance, _ownerCurrentBalance.add(_amount));
        } else {
            votePower.changeValue(_owner, _amount, 0);
            votePower.cleanupOldCheckpoints(_owner, CLEANUP_COUNT, cleanupBlockNumber);
        }
    }

    /**
     * Revoke the vote power of `_to` at block `_blockNumber`
     * @param _from The address of the delegator
     * @param _to The delegatee address of vote power to revoke.
     * @param _senderBalanceAt The sender's balance at the block to be revoked.
     * @param _blockNumber The block number at which to revoke.
     */
    function _revokeDelegationAt(
        address _from,
        address _to,
        uint256 _senderBalanceAt,
        uint256 _blockNumber
    )
        internal
        notBeforeCleanupBlock(_blockNumber)
    {
        require(_blockNumber < block.number, "Revoke is only for the past, use undelegate for the present");

        // Get amount revoked
        uint256 votePowerRevoked = _votePowerFromToAtNoRevokeCheck(_from, _to, _senderBalanceAt, _blockNumber);

        // Revoke vote power
        votePowerCache.revokeAt(votePower, _from, _to, votePowerRevoked, _blockNumber);

        // Emit revoke event
        emit Revoke(_from, _to, votePowerRevoked, _blockNumber);
    }

    /**
     * Transmit `_amount` of vote power `_from` address `_to` address.
     * @param _from The address of the sender.
     * @param _to The address of the receiver.
     * @param _fromCurrentBalance The current token balance of the transmitter.
     * @param _toCurrentBalance The current token balance of the receiver.
     * @param _amount The amount of vote power to transmit.
     */
    function _transmitVotePower(
        address _from,
        address _to,
        uint256 _fromCurrentBalance,
        uint256 _toCurrentBalance,
        uint256 _amount
    )
        internal
    {
        _burnVotePower(_from, _fromCurrentBalance, _amount);
        _mintVotePower(_to, _toCurrentBalance, _amount);
    }

    /**
     * Undelegate all vote power by percentage for `delegation` of `_who`.
     * @param _from The address of the delegator
     * @param _senderCurrentBalance The current balance of message sender.
     * precondition: delegationModes[_who] == DelegationMode.PERCENTAGE
     */
    function _undelegateAllByPercentage(address _from, uint256 _senderCurrentBalance) internal {
        DelegationMode delegationMode = delegationModes[_from];
        if (delegationMode == DelegationMode.NOTSET) return;
        require(delegationMode == DelegationMode.PERCENTAGE,
            "undelegateAll can only be used in percentage delegation mode");

        PercentageDelegation.DelegationState storage delegation = percentageDelegations[_from];

        // Iterate over the delegates
        (address[] memory delegates, uint256[] memory _bips) = delegation.getDelegations();
        for (uint256 i = 0; i < delegates.length; i++) {
            address to = delegates[i];
            // Compute vote power to be reversed for the delegate
            uint256 reverseVotePower = _senderCurrentBalance.mulDiv(_bips[i], PercentageDelegation.MAX_BIPS);
            // Transmit vote power back to _owner
            votePower.undelegate(_from, to, reverseVotePower);
            votePower.cleanupOldCheckpoints(_from, CLEANUP_COUNT, cleanupBlockNumber);
            votePower.cleanupOldCheckpoints(to, CLEANUP_COUNT, cleanupBlockNumber);
            // Emit vote power reversal event
            emit Delegate(_from, to, reverseVotePower, 0);
        }

        // Clear delegates
        delegation.clear();
        delegation.cleanupOldCheckpoints(CLEANUP_COUNT, cleanupBlockNumber);
    }

    /**
     * Undelegate all vote power by amount delegates for `_from`.
     * @param _from The address of the delegator
     * @param _delegateAddresses Explicit delegation does not store delegatees' addresses,
     * so the caller must supply them.
     */
    function _undelegateAllByAmount(
        address _from,
        address[] memory _delegateAddresses
    )
        internal
        returns (uint256 _remainingDelegation)
    {
        DelegationMode delegationMode = delegationModes[_from];
        if (delegationMode == DelegationMode.NOTSET) return 0;
        require(delegationMode == DelegationMode.AMOUNT,
            "undelegateAllExplicit can only be used in explicit delegation mode");

        ExplicitDelegation.DelegationState storage delegation = explicitDelegations[_from];

        // Iterate over the delegates
        for (uint256 i = 0; i < _delegateAddresses.length; i++) {
            address to = _delegateAddresses[i];
            // Compute vote power _to be reversed for the delegate
            uint256 reverseVotePower = delegation.getDelegatedValue(to);
            if (reverseVotePower == 0) continue;
            // Transmit vote power back _to _owner
            votePower.undelegate(_from, to, reverseVotePower);
            votePower.cleanupOldCheckpoints(_from, CLEANUP_COUNT, cleanupBlockNumber);
            votePower.cleanupOldCheckpoints(to, CLEANUP_COUNT, cleanupBlockNumber);
            // change delagation
            delegation.addReplaceDelegate(to, 0);
            delegation.cleanupOldCheckpoints(to, CLEANUP_COUNT, cleanupBlockNumber);
            // Emit vote power reversal event
            emit Delegate(_from, to, reverseVotePower, 0);
        }

        return delegation.getDelegatedTotal();
    }

    /**
     * @notice Check if the `_owner` has made any delegations.
     * @param _owner The address of owner to get delegated vote power.
     * @return The total delegated vote power at block.
     */
    function _hasAnyDelegations(address _owner) internal view returns(bool) {
        DelegationMode delegationMode = delegationModes[_owner];
        if (delegationMode == DelegationMode.NOTSET) {
            return false;
        } else if (delegationMode == DelegationMode.AMOUNT) {
            return explicitDelegations[_owner].getDelegatedTotal() > 0;
        } else { // delegationMode == DelegationMode.PERCENTAGE
            return percentageDelegations[_owner].getCount() > 0;
        }
    }

    /**
     * Get the total delegated vote power of `_owner` at some block.
     * @param _owner The address of owner to get delegated vote power.
     * @param _ownerBalanceAt The balance of the owner at that block (not their vote power).
     * @param _blockNumber The block number at which to fetch.
     * @return _votePower The total delegated vote power at block.
     */
    function _delegatedVotePowerOfAt(
        address _owner,
        uint256 _ownerBalanceAt,
        uint256 _blockNumber
    )
        internal view
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256 _votePower)
    {
        // Get the vote power delegation for the _owner
        DelegationMode delegationMode = delegationModes[_owner];
        if (delegationMode == DelegationMode.NOTSET) {
            return 0;
        } else if (delegationMode == DelegationMode.AMOUNT) {
            return explicitDelegations[_owner].getDelegatedTotalAt(_blockNumber);
        } else { // delegationMode == DelegationMode.PERCENTAGE
            return percentageDelegations[_owner].getDelegatedTotalAmountAt(_ownerBalanceAt, _blockNumber);
        }
    }

    /**
     * Get the undelegated vote power of `_owner` at some block.
     * @param _owner The address of owner to get undelegated vote power.
     * @param _ownerBalanceAt The balance of the owner at that block (not their vote power).
     * @param _blockNumber The block number at which to fetch.
     * @return _votePower The undelegated vote power at block.
     */
    function _undelegatedVotePowerOfAt(
        address _owner,
        uint256 _ownerBalanceAt,
        uint256 _blockNumber
    )
        internal view
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256 _votePower)
    {
        // Return the current balance less delegations or zero if negative
        uint256 delegated = _delegatedVotePowerOfAt(_owner, _ownerBalanceAt, _blockNumber);
        bool overflow;
        uint256 result;
        (overflow, result) = _ownerBalanceAt.trySub(delegated);
        return result;
    }

    /**
     * Get the undelegated vote power of `_owner`.
     * @param _owner The address of owner to get undelegated vote power.
     * @param _ownerCurrentBalance The current balance of the owner (not their vote power).
     * @return _votePower The undelegated vote power.
     */
    function _undelegatedVotePowerOf(
        address _owner,
        uint256 _ownerCurrentBalance
    )
        internal view
        returns(uint256 _votePower)
    {
        return _undelegatedVotePowerOfAt(_owner, _ownerCurrentBalance, block.number);
    }

    /**
    * Get current delegated vote power `_from` delegator delegated `_to` delegatee.
    * @param _from Address of delegator
    * @param _to Address of delegatee
    * @return _votePower The delegated vote power.
    */
    function _votePowerFromTo(
        address _from,
        address _to,
        uint256 _currentFromBalance
    )
        internal view
        returns(uint256 _votePower)
    {
        DelegationMode delegationMode = delegationModes[_from];
        if (delegationMode == DelegationMode.NOTSET) {
            return 0;
        } else if (delegationMode == DelegationMode.PERCENTAGE) {
            uint256 _bips = percentageDelegations[_from].getDelegatedValue(_to);
            return _currentFromBalance.mulDiv(_bips, PercentageDelegation.MAX_BIPS);
        } else { // delegationMode == DelegationMode.AMOUNT
            return explicitDelegations[_from].getDelegatedValue(_to);
        }
    }

    /**
    * Get delegated the vote power `_from` delegator delegated `_to` delegatee at `_blockNumber`.
    * @param _from Address of delegator
    * @param _to Address of delegatee
    * @param _fromBalanceAt From's balance at the block `_blockNumber`.
    * @param _blockNumber The block number at which to fetch.
    * @return _votePower The delegated vote power.
    */
    function _votePowerFromToAt(
        address _from,
        address _to,
        uint256 _fromBalanceAt,
        uint256 _blockNumber
    )
        internal view
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256 _votePower)
    {
        // if revoked, return 0
        if (votePowerCache.revokedFromToAt(_from, _to, _blockNumber)) return 0;
        return _votePowerFromToAtNoRevokeCheck(_from, _to, _fromBalanceAt, _blockNumber);
    }

    /**
     * Get delegated the vote power `_from` delegator delegated `_to` delegatee at `_blockNumber`.
     * Private use only - ignores revocations.
     * @param _from Address of delegator
     * @param _to Address of delegatee
     * @param _fromBalanceAt From's balance at the block `_blockNumber`.
     * @param _blockNumber The block number at which to fetch.
     * @return _votePower The delegated vote power.
     */
    function _votePowerFromToAtNoRevokeCheck(
        address _from,
        address _to,
        uint256 _fromBalanceAt,
        uint256 _blockNumber
    )
        private view
        returns(uint256 _votePower)
    {
        // assumed: notBeforeCleanupBlock(_blockNumber)
        DelegationMode delegationMode = delegationModes[_from];
        if (delegationMode == DelegationMode.NOTSET) {
            return 0;
        } else if (delegationMode == DelegationMode.PERCENTAGE) {
            uint256 _bips = percentageDelegations[_from].getDelegatedValueAt(_to, _blockNumber);
            return _fromBalanceAt.mulDiv(_bips, PercentageDelegation.MAX_BIPS);
        } else { // delegationMode == DelegationMode.AMOUNT
            return explicitDelegations[_from].getDelegatedValueAt(_to, _blockNumber);
        }
    }

    /**
     * Get the current vote power of `_who`.
     * @param _who The address to get voting power.
     * @return Current vote power of `_who`.
     */
    function _votePowerOf(address _who) internal view returns(uint256) {
        return votePower.votePowerOfAtNow(_who);
    }

    /**
     * Get the vote power of `_who` at block `_blockNumber`
     * @param _who The address to get voting power.
     * @param _blockNumber The block number at which to fetch.
     * @return Vote power of `_who` at `_blockNumber`.
     */
    function _votePowerOfAt(
        address _who,
        uint256 _blockNumber
    )
        internal view
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256)
    {
        // read cached value for past blocks to respect revocations (and possibly get a cache speedup)
        if (_blockNumber < block.number) {
            return votePowerCache.valueOfAtReadonly(votePower, _who, _blockNumber);
        } else {
            return votePower.votePowerOfAtNow(_who);
        }
    }

    /**
     * Get the vote power of `_who` at block `_blockNumber`, ignoring revocation information (and cache).
     * @param _who The address to get voting power.
     * @param _blockNumber The block number at which to fetch.
     * @return Vote power of `_who` at `_blockNumber`. Result doesn't change if vote power is revoked.
     */
    function _votePowerOfAtIgnoringRevocation(
        address _who,
        uint256 _blockNumber
    )
        internal view
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256)
    {
        return votePower.votePowerOfAt(_who, _blockNumber);
    }

    /**
     * Return vote powers for several addresses in a batch.
     * Only works for past blocks.
     * @param _owners The list of addresses to fetch vote power of.
     * @param _blockNumber The block number at which to fetch.
     * @return _votePowers A list of vote powers corresponding to _owners.
     */
    function _batchVotePowerOfAt(
        address[] memory _owners,
        uint256 _blockNumber
    )
        internal view
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256[] memory _votePowers)
    {
        require(_blockNumber < block.number, "Can only be used for past blocks");
        _votePowers = new uint256[](_owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            // read through cache, much faster if it has been set
            _votePowers[i] = votePowerCache.valueOfAtReadonly(votePower, _owners[i], _blockNumber);
        }
    }

    /**
     * Get the vote power of `_who` at block `_blockNumber`
     *   Reads/updates cache and upholds revocations.
     * @param _who The address to get voting power.
     * @param _blockNumber The block number at which to fetch.
     * @return Vote power of `_who` at `_blockNumber`.
     */
    function _votePowerOfAtCached(
        address _who,
        uint256 _blockNumber
    )
        internal
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256)
    {
        require(_blockNumber < block.number, "Can only be used for past blocks");
        (uint256 vp, bool createdCache) = votePowerCache.valueOfAt(votePower, _who, _blockNumber);
        if (createdCache) emit CreatedVotePowerCache(_who, _blockNumber);
        return vp;
    }

    /**
     * Set the cleanup block number.
     */
    function _setCleanupBlockNumber(uint256 _blockNumber) internal {
        require(_blockNumber >= cleanupBlockNumber, "Cleanup block number must never decrease");
        require(_blockNumber < block.number, "Cleanup block must be in the past");
        cleanupBlockNumber = _blockNumber;
    }

    /**
     * Get the cleanup block number.
     */
    function _cleanupBlockNumber() internal view returns (uint256) {
        return cleanupBlockNumber;
    }

    /**
     * Set the contract that is allowed to call history cleaning methods.
     */
    function _setCleanerContract(address _cleanerContract) internal {
        cleanerContract = _cleanerContract;
    }

    // history cleanup methods

    /**
     * Delete vote power checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner Vote power owner account address.
     * @param _count Maximum number of checkpoints to delete.
     * @return Number of deleted checkpoints.
     */
    function votePowerHistoryCleanup(address _owner, uint256 _count) external onlyCleaner returns (uint256) {
        return votePower.cleanupOldCheckpoints(_owner, _count, cleanupBlockNumber);
    }

    /**
     * Delete vote power cache entry that expired (i.e. is before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner Vote power owner account address.
     * @param _blockNumber Block number for which total supply value was cached.
     * @return Number of deleted cache entries (always 0 or 1).
     */
    function votePowerCacheCleanup(address _owner, uint256 _blockNumber) external onlyCleaner returns (uint256) {
        require(_blockNumber < cleanupBlockNumber, "No cleanup after cleanup block");
        return votePowerCache.deleteValueAt(_owner, _blockNumber);
    }

    /**
     * Delete revocation entry that expired (i.e. is before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _from Delegator address.
     * @param _to Delegatee address.
     * @param _blockNumber Block number for which total supply value was cached.
     * @return Number of revocation entries deleted (always 0 or 1).
     */
    function revocationCleanup(
        address _from,
        address _to,
        uint256 _blockNumber
    )
        external onlyCleaner
        returns (uint256)
    {
        require(_blockNumber < cleanupBlockNumber, "No cleanup after cleanup block");
        return votePowerCache.deleteRevocationAt(_from, _to, _blockNumber);
    }

    /**
     * Delete percentage delegation checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner Balance owner account address.
     * @param _count Maximum number of checkpoints to delete.
     * @return Number of deleted checkpoints.
     */
    function percentageDelegationHistoryCleanup(address _owner, uint256 _count)
        external onlyCleaner
        returns (uint256)
    {
        return percentageDelegations[_owner].cleanupOldCheckpoints(_count, cleanupBlockNumber);
    }

    /**
     * Delete explicit delegation checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _from Delegator address.
     * @param _to Delegatee address.
     * @param _count Maximum number of checkpoints to delete.
     * @return Number of checkpoints deleted.
     */
    function explicitDelegationHistoryCleanup(address _from, address _to, uint256 _count)
        external
        onlyCleaner
        returns (uint256)
    {
        return explicitDelegations[_from].cleanupOldCheckpoints(_to, _count, cleanupBlockNumber);
    }
}


// File contracts/token/implementation/VPContract.sol







/**
 * Helper contract handling all the vote power and delegation functionality for an associated VPToken.
 */
contract VPContract is IIVPContract, Delegatable {
    using SafeMath for uint256;

    /**
     * @inheritdoc IIVPContract
     */
    IVPToken public immutable override ownerToken;

    /**
     * @inheritdoc IIVPContract
     */
    bool public immutable override isReplacement;

    // The block number when vote power for an address was first set.
    // Reading vote power before this block would return incorrect result and must revert.
    mapping (address => uint256) private votePowerInitializationBlock;

    // Vote power cache for past blocks when vote power was not initialized.
    // Reading vote power at that block would return incorrect result, so cache must be set by some other means.
    // No need for revocation info, since there can be no delegations at such block.
    mapping (bytes32 => uint256) private uninitializedVotePowerCache;

    string constant private ALREADY_EXPLICIT_MSG = "Already delegated explicitly";
    string constant private ALREADY_PERCENT_MSG = "Already delegated by percentage";

    string constant internal VOTE_POWER_NOT_INITIALIZED = "Vote power not initialized";

    /// All external methods in VPContract can only be executed by the owner token.
    modifier onlyOwnerToken {
        require(msg.sender == address(ownerToken), "only owner token");
        _;
    }

    /// If a delegate cannot be added by percentage, revert.
    modifier onlyPercent(address sender) {
        require(_canDelegateByPct(sender), ALREADY_EXPLICIT_MSG);
        _;
    }

    /// If a delegate cannot be added by explicit amount, revert.
    modifier onlyExplicit(address sender) {
        require(_canDelegateByAmount(sender), ALREADY_PERCENT_MSG);
        _;
    }

    /**
     * Construct VPContract for given VPToken.
     */
    constructor(IVPToken _ownerToken, bool _isReplacement) {
        require(address(_ownerToken) != address(0), "VPContract must belong to a VPToken");
        ownerToken = _ownerToken;
        isReplacement = _isReplacement;
    }

    /**
     * @inheritdoc IICleanable
     * @dev The method can be called only by the owner token.
     */
    function setCleanupBlockNumber(uint256 _blockNumber) external override onlyOwnerToken {
        _setCleanupBlockNumber(_blockNumber);
    }

    /**
     * @inheritdoc IICleanable
     */
    function setCleanerContract(address _cleanerContract) external override onlyOwnerToken {
        _setCleanerContract(_cleanerContract);
    }

    /**
     * @inheritdoc IIVPContract
     */
    function updateAtTokenTransfer(
        address _from,
        address _to,
        uint256 _fromBalance,
        uint256 _toBalance,
        uint256 _amount
    )
        external override
        onlyOwnerToken
    {
        if (_from == address(0)) {
            // mint new vote power
            _initializeVotePower(_to, _toBalance);
            _mintVotePower(_to, _toBalance, _amount);
        } else if (_to == address(0)) {
            // burn vote power
            _initializeVotePower(_from, _fromBalance);
            _burnVotePower(_from, _fromBalance, _amount);
        } else {
            // transmit vote power _to receiver
            _initializeVotePower(_from, _fromBalance);
            _initializeVotePower(_to, _toBalance);
            _transmitVotePower(_from, _to, _fromBalance, _toBalance, _amount);
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function delegate(
        address _from,
        address _to,
        uint256 _balance,
        uint256 _bips
    )
        external override
        onlyOwnerToken
        onlyPercent(_from)
    {
        _initializeVotePower(_from, _balance);
        if (!_votePowerInitialized(_to)) {
            _initializeVotePower(_to, ownerToken.balanceOf(_to));
        }
        _delegateByPercentage(_from, _to, _balance, _bips);
    }

    /**
     * @inheritdoc IIVPContract
     */
    function delegateExplicit(
        address _from,
        address _to,
        uint256 _balance,
        uint _amount
    )
        external override
        onlyOwnerToken
        onlyExplicit(_from)
    {
        _initializeVotePower(_from, _balance);
        if (!_votePowerInitialized(_to)) {
            _initializeVotePower(_to, ownerToken.balanceOf(_to));
        }
        _delegateByAmount(_from, _to, _balance, _amount);
    }

    /**
     * @inheritdoc IIVPContract
     */
    function revokeDelegationAt(
        address _from,
        address _to,
        uint256 _balance,
        uint _blockNumber
    )
        external override
        onlyOwnerToken
    {
        // ASSERT: if there was a delegation, _from and _to must be initialized
        if (!isReplacement ||
            (_votePowerInitializedAt(_from, _blockNumber) && _votePowerInitializedAt(_to, _blockNumber))) {
            _revokeDelegationAt(_from, _to, _balance, _blockNumber);
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function undelegateAll(
        address _from,
        uint256 _balance
    )
        external override
        onlyOwnerToken
        onlyPercent(_from)
    {
        if (_hasAnyDelegations(_from)) {
            // ASSERT: since there were delegations, _from and its targets must be initialized
            _undelegateAllByPercentage(_from, _balance);
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function undelegateAllExplicit(
        address _from,
        address[] memory _delegateAddresses
    )
        external override
        onlyOwnerToken
        onlyExplicit(_from)
        returns (uint256)
    {
        if (_hasAnyDelegations(_from)) {
            // ASSERT: since there were delegations, _from and its targets must be initialized
            return _undelegateAllByAmount(_from, _delegateAddresses);
        }
        return 0;
    }

    /**
     * @inheritdoc IIVPContract
     */
    function votePowerOfAtCached(address _who, uint256 _blockNumber) external override returns(uint256) {
        if (!isReplacement || _votePowerInitializedAt(_who, _blockNumber)) {
            // use standard method
            return _votePowerOfAtCached(_who, _blockNumber);
        } else {
            // use uninitialized vote power cache
            bytes32 key = keccak256(abi.encode(_who, _blockNumber));
            uint256 cached = uninitializedVotePowerCache[key];
            if (cached != 0) {
                return cached - 1;  // safe, cached != 0
            }
            uint256 balance = ownerToken.balanceOfAt(_who, _blockNumber);
            uninitializedVotePowerCache[key] = balance.add(1);
            return balance;
        }
    }

    /**
     * @inheritdoc IICleanable
     */
    function cleanupBlockNumber() external view override returns (uint256) {
        return _cleanupBlockNumber();
    }

    /**
     * @inheritdoc IIVPContract
     */
    function votePowerOf(address _who) external view override returns(uint256) {
        if (_votePowerInitialized(_who)) {
            return _votePowerOf(_who);
        } else {
            return ownerToken.balanceOf(_who);
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function votePowerOfAt(address _who, uint256 _blockNumber) public view override returns(uint256) {
        if (!isReplacement || _votePowerInitializedAt(_who, _blockNumber)) {
            return _votePowerOfAt(_who, _blockNumber);
        } else {
            return ownerToken.balanceOfAt(_who, _blockNumber);
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function votePowerOfAtIgnoringRevocation(address _who, uint256 _blockNumber)
        external view override
        returns(uint256)
    {
        if (!isReplacement || _votePowerInitializedAt(_who, _blockNumber)) {
            return _votePowerOfAtIgnoringRevocation(_who, _blockNumber);
        } else {
            return ownerToken.balanceOfAt(_who, _blockNumber);
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function batchVotePowerOfAt(
        address[] memory _owners,
        uint256 _blockNumber
    )
        external view override
        returns(uint256[] memory _votePowers)
    {
        _votePowers = _batchVotePowerOfAt(_owners, _blockNumber);
        // zero results might not have been initialized
        if (isReplacement) {
            for (uint256 i = 0; i < _votePowers.length; i++) {
                if (_votePowers[i] == 0 && !_votePowerInitializedAt(_owners[i], _blockNumber)) {
                    _votePowers[i] = ownerToken.balanceOfAt(_owners[i], _blockNumber);
                }
            }
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function votePowerFromTo(
        address _from,
        address _to,
        uint256 _balance
    )
        external view override
        returns (uint256)
    {
        // ASSERT: if the result is nonzero, _from and _to are initialized
        return _votePowerFromTo(_from, _to, _balance);
    }

    /**
     * @inheritdoc IIVPContract
     */
    function votePowerFromToAt(
        address _from,
        address _to,
        uint256 _balance,
        uint _blockNumber
    )
        external view override
        returns (uint256)
    {
        // ASSERT: if the result is nonzero, _from and _to were initialized at _blockNumber
        return _votePowerFromToAt(_from, _to, _balance, _blockNumber);
    }

    /**
     * @inheritdoc IIVPContract
     */
    function delegationModeOf(address _who) external view override returns (uint256) {
        return uint256(_delegationModeOf(_who));
    }

    /**
     * @inheritdoc IIVPContract
     */
    function undelegatedVotePowerOf(
        address _owner,
        uint256 _balance
    )
        external view override
        returns (uint256)
    {
        if (_votePowerInitialized(_owner)) {
            return _undelegatedVotePowerOf(_owner, _balance);
        } else {
            // ASSERT: there are no delegations
            return _balance;
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function undelegatedVotePowerOfAt(
        address _owner,
        uint256 _balance,
        uint256 _blockNumber
    )
        external view override
        returns (uint256)
    {
        if (_votePowerInitialized(_owner)) {
            return _undelegatedVotePowerOfAt(_owner, _balance, _blockNumber);
        } else {
            // ASSERT: there were no delegations at _blockNumber
            return _balance;
        }
    }

    /**
     * @inheritdoc IIVPContract
     */
    function delegatesOf(address _owner)
        external view override
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        )
    {
        // ASSERT: either _owner is initialized or there are no delegations
        return delegatesOfAt(_owner, block.number);
    }

    /**
     * @inheritdoc IIVPContract
     */
    function delegatesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        public view override
        returns (
            address[] memory _delegateAddresses,
            uint256[] memory _bips,
            uint256 _count,
            uint256 _delegationMode
        )
    {
        // ASSERT: either _owner was initialized or there were no delegations
        DelegationMode mode = _delegationModeOf(_owner);
        if (mode == DelegationMode.PERCENTAGE) {
            // Get the vote power delegation for the _owner
            (_delegateAddresses, _bips) = _percentageDelegatesOfAt(_owner, _blockNumber);
        } else if (mode == DelegationMode.NOTSET) {
            _delegateAddresses = new address[](0);
            _bips = new uint256[](0);
        } else {
            revert ("delegatesOf does not work in AMOUNT delegation mode");
        }
        _count = _delegateAddresses.length;
        _delegationMode = uint256(mode);
    }

    /**
     * Initialize vote power to current balance if not initialized already.
     * @param _owner The address to initialize voting power.
     * @param _balance The owner's current balance.
     */
    function _initializeVotePower(address _owner, uint256 _balance) internal {
        if (!isReplacement) return;
        if (_owner == address(0)) return;    // 0 address is special (usually marks no source/dest - no init needed)
        if (votePowerInitializationBlock[_owner] == 0) {
            // consistency check - no delegations should be made from or to owner before vote power is initialized
            // (that would be dangerous, because vote power would have been delegated incorrectly)
            assert(_votePowerOf(_owner) == 0 && !_hasAnyDelegations(_owner));
            _mintVotePower(_owner, 0, _balance);
            votePowerInitializationBlock[_owner] = block.number.add(1);
        }
    }

    /**
     * Has the vote power of `_owner` been initialized?
     * @param _owner The address to check.
     * @return true if vote power of _owner is initialized
     */
    function _votePowerInitialized(address _owner) internal view returns (bool) {
        if (!isReplacement) return true;
        return votePowerInitializationBlock[_owner] != 0;
    }

    /**
     * Was vote power of `_owner` initialized at some block?
     * @param _owner The address to check.
     * @param _blockNumber The block for which we want to check.
     * @return true if vote power of _owner was initialized at _blockNumber
     */
    function _votePowerInitializedAt(address _owner, uint256 _blockNumber) internal view returns (bool) {
        if (!isReplacement) return true;
        uint256 initblock = votePowerInitializationBlock[_owner];
        return initblock != 0 && initblock - 1 <= _blockNumber;
    }
}


// File contracts/userInterfaces/IWNat.sol


/**
 * Wrapped native token interface.
 *
 * This contract converts native tokens into `WNAT` (wrapped native) tokens and vice versa.
 * `WNAT` tokens are a one-to-one [ERC20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/)
 * representation of native tokens, which are minted and burned as needed by this contract.
 *
 * The wrapped versions of the native `FLR` and `SGB` tokens are called `WFLR` and `WSGB` respectively.
 *
 * Code attribution: WETH9.
 */
interface IWNat {
    /**
     * Deposits native tokens and mints the same amount of `WNAT` tokens,
     * which are added to the `msg.sender`'s balance.
     * This operation is commonly known as "wrapping".
     */
    function deposit() external payable;

    /**
     * Burns `_amount` of `WNAT` tokens from `msg.sender`'s `WNAT` balance and
     * transfers the same amount of native tokens to `msg.sender`.
     * This operation is commonly known as "unwrapping".
     *
     * Reverts if `_amount` is higher than `msg.sender`'s `WNAT` balance.
     * @param _amount            The amount to withdraw.
     */
    function withdraw(uint256 _amount) external;

    /**
     * Deposits native tokens and mints the same amount of `WNAT` tokens,
     * which are added to `_recipient`'s balance.
     * This operation is commonly known as "wrapping".
     *
     * This is equivalent to using `deposit` followed by `transfer`.
     * @param _recipient         The address to receive the minted `WNAT`.
     */
    function depositTo(address _recipient) external payable;

    /**
     * Burns `_amount` of `WNAT` tokens from `_owner`'s `WNAT` balance and
     * transfers the same amount of native tokens to `msg.sender`.
     * This operation is commonly known as "unwrapping".
     *
     * `msg.sender` must have been authorized to withdraw from `_owner`'s account
     * through ERC-20's approve mechanism.
     *
     * Reverts if `_amount` is higher than `_owners`'s `WNAT` balance or than
     * `msg.sender`'s allowance over `_owner`'s tokens.
     * @param _owner             The address containing the tokens to withdraw.
     * @param _amount            The amount to withdraw.
     */
    function withdrawFrom(address _owner, uint256 _amount) external;
}


// File contracts/token/implementation/WNat.sol





/**
 * Wrapped native token.
 *
 * This contract converts native tokens into `WNAT` (wrapped native) tokens and vice versa.
 * `WNAT` tokens are a one-to-one [ERC20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/)
 * representation of native tokens, which are minted and burned as needed by this contract.
 *
 * The wrapped versions of the native `FLR` and `SGB` tokens are called `WFLR` and `WSGB` respectively.
 *
 * Besides the standard ERC20 operations, this contract supports
 * [FTSO delegation](https://docs.flare.network/tech/ftso/#delegation) and
 * [governance vote delegation](https://docs.flare.network/tech/governance/#vote-transfer).
 *
 * Code attribution: WETH9.
 */
contract WNat is VPToken, IWNat {
    using SafeMath for uint256;
    /**
     * Emitted when tokens have been wrapped.
     * @param dst The account that received the wrapped tokens.
     * @param amount The amount that was wrapped.
     */
    event Deposit(address indexed dst, uint amount);
    /**
     * Emitted when tokens have been unwrapped.
     * @param src The account that received the unwrapped tokens.
     * @param amount The amount that was unwrapped.
     */
    event Withdrawal(address indexed src, uint amount);

    /**
     * Construct an ERC20 token.
     */
    constructor(address _governance, string memory _name, string memory _symbol)
        VPToken(_governance, _name, _symbol)
    {
    }

    /**
     * A proxy for the deposit method.
     */
    receive() external payable {
        deposit();
    }

    /**
     * @inheritdoc IWNat
     *
     * @dev Emits a Withdrawal event.
     */
    function withdrawFrom(address _owner, uint256 _amount) external override {
        // Reduce senders allowance
        _approve(_owner, msg.sender, allowance(_owner, msg.sender).sub(_amount, "allowance below zero"));
        // Burn the owners balance
        _burn(_owner, _amount);
        // Emit withdraw event
        emit Withdrawal(_owner, _amount);
        // Move value to sender (last statement, to prevent reentrancy)
        msg.sender.transfer(_amount);
    }

    /**
     * @inheritdoc IWNat
     *
     * @dev Emits a Deposit event.
     */
    function depositTo(address _recipient) external payable override {
        require(_recipient != address(0), "Cannot deposit to zero address");
        // Mint WNAT
        _mint(_recipient, msg.value);
        // Emit deposit event
        emit Deposit(_recipient, msg.value);
    }

    /**
     * @inheritdoc IWNat
     *
     * @dev Emits a Deposit event.
     */
    function deposit() public payable override {
        // Mint WNAT
        _mint(msg.sender, msg.value);
        // Emit deposit event
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @inheritdoc IWNat
     *
     * @dev Emits a Withdrawal event.
     */
    function withdraw(uint256 _amount) external override {
        // Burn WNAT tokens
        _burn(msg.sender, _amount);
        // Emit withdrawal event
        emit Withdrawal(msg.sender, _amount);
        // Send Native to sender (last statement, to prevent reentrancy)
        msg.sender.transfer(_amount);
    }
}


// File contracts/token/lib/DelegateCheckPointHistory.sol




/**
 * @title Check Point History library
 * @notice A contract to manage checkpoints as of a given block.
 * @dev Store value history by block number with detachable state.
 **/
library DelegateCheckPointHistory {
    using SafeMath for uint256;
    using SafeCast for uint256;

    /**
     * @dev `DelegateCheckPoint` is the structure that attaches a block number to a
     *  given address; the block number attached is the one that last changed the
     *  value
     **/
    struct DelegateCheckPoint {
        // `to` is the delegate's address
        address to;
        // `fromBlock` is the block number that the value was generated from
        uint64 fromBlock;
    }

    struct DelegateCheckPointHistoryState {
        // `checkpoints` is an array that tracks values at non-contiguous block numbers
        mapping(uint256 => DelegateCheckPoint) checkpoints;
        // `checkpoints` before `startIndex` have been deleted
        // INVARIANT: checkpoints.endIndex == 0 || startIndex < checkpoints.endIndex      (strict!)
        // startIndex and endIndex are both less then fromBlock, so 64 bits is enough
        uint64 startIndex;
        // the index AFTER last
        uint64 endIndex;
    }

    /**
     * @notice Binary search of _checkpoints array.
     * @param _checkpoints An array of CheckPoint to search.
     * @param _startIndex Smallest possible index to be returned.
     * @param _blockNumber The block number to search for.
     */
    function _indexOfGreatestBlockLessThan(
        mapping(uint256 => DelegateCheckPoint) storage _checkpoints, 
        uint256 _startIndex,
        uint256 _endIndex,
        uint256 _blockNumber
    )
        private view 
        returns (uint256 index)
    {
        // Binary search of the value by given block number in the array
        uint256 min = _startIndex;
        uint256 max = _endIndex.sub(1);
        while (max > min) {
            uint256 mid = (max.add(min).add(1)).div(2);
            if (_checkpoints[mid].fromBlock <= _blockNumber) {
                min = mid;
            } else {
                max = mid.sub(1);
            }
        }
        return min;
    }

    /**
     * @notice Queries the value at a specific `_blockNumber`
     * @param _self A CheckPointHistoryState instance to manage
     * @param _blockNumber The block number of the value active at that time
     * @return _to Delegator's address at `_blockNumber`     
     **/
    function delegateAddressAt(
        DelegateCheckPointHistoryState storage _self, 
        uint256 _blockNumber
    )
        internal view 
        returns (address _to)
    {
        uint256 historyCount = _self.endIndex;

        // No _checkpoints, return 0
        if (historyCount == 0) return address(0);

        // Shortcut for the actual address (extra optimized for current block, to save one storage read)
        // historyCount - 1 is safe, since historyCount != 0
        if (_blockNumber >= block.number || _blockNumber >= _self.checkpoints[historyCount - 1].fromBlock) {
            return _self.checkpoints[historyCount - 1].to;
        }
        
        // guard values at start    
        uint256 startIndex = _self.startIndex;
        if (_blockNumber < _self.checkpoints[startIndex].fromBlock) {
            // reading data before `startIndex` is only safe before first cleanup
            require(startIndex == 0, "CheckPointHistory: reading from cleaned-up block");
            return address(0);
        }

        // Find the block with number less than or equal to block given
        uint256 index = _indexOfGreatestBlockLessThan(_self.checkpoints, startIndex, _self.endIndex, _blockNumber);

        return _self.checkpoints[index].to;
    }

    /**
     * @notice Queries the value at `block.number`
     * @param _self A CheckPointHistoryState instance to manage.
     * @return _to Delegator's address at `block.number`
     **/
    function delegateAddressAtNow(DelegateCheckPointHistoryState storage _self) internal view returns (address _to) {
        uint256 historyCount = _self.endIndex;
        // No _checkpoints, return 0
        if (historyCount == 0) return address(0);
        // Return last value
        return _self.checkpoints[historyCount - 1].to;
    }

    /**
     * @notice Writes the address at the current block.
     * @param _self A DelegateCheckPointHistoryState instance to manage.
     * @param _to Delegate's address.
     **/
    function writeAddress(
        DelegateCheckPointHistoryState storage _self, 
        address _to
    )
        internal
    {
        uint256 historyCount = _self.endIndex;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            _self.checkpoints[0] = 
                DelegateCheckPoint({ fromBlock: block.number.toUint64(), to: _to });
            _self.endIndex = 1;
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            DelegateCheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                lastCheckpoint.to = _to;
            } else {
                // we should never have future blocks in history
                assert (block.number > lastBlock);
                // push new CheckPoint
                _self.checkpoints[historyCount] = 
                    DelegateCheckPoint({ fromBlock: block.number.toUint64(), to: _to });
                _self.endIndex = uint64(historyCount + 1);  // 64 bit safe, because historyCount <= block.number
            }
        }
    }
    
    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain 
     * (unless the history was empty to start with).
     */    
    function cleanupOldCheckpoints(
        DelegateCheckPointHistoryState storage _self, 
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        if (_cleanupBlockNumber == 0) return 0;   // optimization for when cleaning is not enabled
        uint256 length = _self.endIndex;
        if (length == 0) return 0;
        uint256 startIndex = _self.startIndex;
        // length - 1 is safe, since length != 0 (check above)
        uint256 endIndex = Math.min(startIndex.add(_count), length - 1);    // last element can never be deleted
        uint256 index = startIndex;
        // we can delete `checkpoint[index]` while the next checkpoint is at `_cleanupBlockNumber` or before
        while (index < endIndex && _self.checkpoints[index + 1].fromBlock <= _cleanupBlockNumber) {
            delete _self.checkpoints[index];
            index++;
        }
        if (index > startIndex) {   // index is the first not deleted index
            _self.startIndex = index.toUint64();
        }
        return index - startIndex;  // safe: index >= startIndex at start and then increases
    }

}


// File contracts/token/lib/DelegateCheckPointsByAddress.sol



/**
 * @title Check Points By Address library
 * @notice A contract to manage checkpoint history for a collection of addresses.
 * @dev Store value history by address, and then by block number.
 **/
library DelegateCheckPointsByAddress {
    using SafeMath for uint256;
    using DelegateCheckPointHistory for DelegateCheckPointHistory.DelegateCheckPointHistoryState;

    struct DelegateCheckPointsByAddressState {
        // `historyByAddress` is the map that stores the delegate check point history of each address
        mapping(address => DelegateCheckPointHistory.DelegateCheckPointHistoryState) historyByAddress;
    }

    /**
     * @notice Queries the address of `_owner` at a specific `_blockNumber`.
     * @param _self A DelegateCheckPointsByAddressState instance to manage.
     * @param _owner The address from which the value will be retrieved.
     * @param _blockNumber The block number to query for the then current value.
     * @return The value at `_blockNumber` for `_owner`.
     **/
    function delegateAddressOfAt(
        DelegateCheckPointsByAddressState storage _self,
        address _owner,
        uint256 _blockNumber
    ) internal view returns (address) {
        // Get history for _owner
        DelegateCheckPointHistory.DelegateCheckPointHistoryState
            storage history = _self.historyByAddress[_owner];
        // Return value at given block
        return history.delegateAddressAt(_blockNumber);
    }

    /**
     * @notice Get the value of the `_owner` at the current `block.number`.
     * @param _self A DelegateCheckPointsByAddressState instance to manage.
     * @param _owner The address of the value is being requested.
     * @return The value of `_owner` at the current block.
     **/
    function delegateAddressOfAtNow(
        DelegateCheckPointsByAddressState storage _self,
        address _owner
    ) internal view returns (address) {
        // Get history for _owner
        DelegateCheckPointHistory.DelegateCheckPointHistoryState storage history = _self
            .historyByAddress[_owner];
        // Return value at now
        return history.delegateAddressAtNow();
    }

    /**
     * @notice Writes the `to` at the current block number for `_owner`.
     * @param _self A DelegateCheckPointsByAddressState instance to manage.
     * @param _owner The address of `_owner` to write.
     * @param _to The value to write.
     * @dev Sender must be the owner of the contract.
     **/
    function writeAddress(
        DelegateCheckPointsByAddressState storage _self,
        address _owner,
        address _to
    ) internal {
        // Get history for _owner
        DelegateCheckPointHistory.DelegateCheckPointHistoryState storage history = _self
            .historyByAddress[_owner];
        // Write the value
        history.writeAddress(_to);
    }

    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain
     * (unless the history was empty to start with).
     */
    function cleanupOldCheckpoints(
        DelegateCheckPointsByAddressState storage _self,
        address _owner,
        uint256 _count,
        uint256 _cleanupBlockNumber
    ) internal returns (uint256) {
        if (_owner != address(0)) {
            return
                _self.historyByAddress[_owner].cleanupOldCheckpoints(
                    _count,
                    _cleanupBlockNumber
                );
        }
        return 0;
    }
}


// File contracts/addressUpdater/interface/IIAddressUpdatable.sol



/**
 * Internal interface for contracts that depend on other contracts whose addresses can change.
 *
 * See `AddressUpdatable`.
 */
interface IIAddressUpdatable {
    /**
     * Updates contract addresses.
     * Can only be called from the `AddressUpdater` contract typically set at construction time.
     * @param _contractNameHashes List of keccak256(abi.encode(...)) contract names.
     * @param _contractAddresses List of contract addresses corresponding to the contract names.
     */
    function updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
        ) external;
}


// File contracts/addressUpdater/implementation/AddressUpdatable.sol


/**
 * Abstract base class for contracts that depend on other contracts whose addresses can change.
 *
 * The `AddressUpdater` contract keeps a list of addresses for all unique and special
 * platform contracts. By inheriting from `AddressUpdatable` a contract will receive updates
 * if any of the platform contract addresses change.
 *
 * A contract's address changes when it is redeployed, so `AddressUpdatable` offers a way
 * to keep up to date with the latest address for all dependencies.
 */
abstract contract AddressUpdatable is IIAddressUpdatable {

    // https://docs.soliditylang.org/en/v0.8.7/contracts.html#constant-and-immutable-state-variables
    // No storage slot is allocated
    bytes32 internal constant ADDRESS_STORAGE_POSITION =
        keccak256("flare.diamond.AddressUpdatable.ADDRESS_STORAGE_POSITION");

    /// Only the `AdressUpdater` contract can call this method.
    /// Its address is set at construction time but it can also update itself.
    modifier onlyAddressUpdater() {
        require (msg.sender == getAddressUpdater(), "only address updater");
        _;
    }

    constructor(address _addressUpdater) {
        setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * Returns the configured address updater.
     * @return _addressUpdater The `AddresUpdater` contract that can update our
     * contract address list, as a response to a governance call.
     */
    function getAddressUpdater() public view returns (address _addressUpdater) {
        // Only direct constants are allowed in inline assembly, so we assign it here
        bytes32 position = ADDRESS_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _addressUpdater := sload(position)
        }
    }

    /**
     * External method called from AddressUpdater only.
     */
    function updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        external override
        onlyAddressUpdater
    {
        // update addressUpdater address
        setAddressUpdaterValue(_getContractAddress(_contractNameHashes, _contractAddresses, "AddressUpdater"));
        // update all other addresses
        _updateContractAddresses(_contractNameHashes, _contractAddresses);
    }

    /**
     * Informs contracts extending `AddressUpdatable` that some contract addresses have changed.
     * This is a virtual method that must be implemented.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    ) internal virtual;

    /**
     * Helper method to get a contract's address.
     * It reverts if contract name does not exist.
     */
    function _getContractAddress(
        bytes32[] memory _nameHashes,
        address[] memory _addresses,
        string memory _nameToFind
    )
        internal pure
        returns(address)
    {
        bytes32 nameHash = keccak256(abi.encode(_nameToFind));
        address a = address(0);
        for (uint256 i = 0; i < _nameHashes.length; i++) {
            if (nameHash == _nameHashes[i]) {
                a = _addresses[i];
                break;
            }
        }
        require(a != address(0), "address zero");
        return a;
    }

    function setAddressUpdaterValue(address _addressUpdater) internal {
        // Only direct constants are allowed in inline assembly, so we assign it here
        bytes32 position = ADDRESS_STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(position, _addressUpdater)
        }
    }
}


// File contracts/token/implementation/CleanupBlockNumberManager.sol




/**
 * Token history cleanup manager.
 *
 * Maintains the list of cleanable tokens for which history cleanup can be collectively executed.
 */
contract CleanupBlockNumberManager is Governed, AddressUpdatable {

    string internal constant ERR_CONTRACT_NOT_FOUND = "contract not found";
    string internal constant ERR_TRIGGER_CONTRACT_ONLY = "trigger contract only";

    /// Current list of token contracts being managed.
    IICleanable[] public registeredTokens;
    /// Address of the contract that can trigger a cleanup.
    address public triggerContract;
    /// Name of the contract that can trigger a cleanup.
    /// Needed to update the trigger contract address through the `AddressUpdater`.
    string public triggerContractName;

    /**
     * Emitted when a new token has been registered to have its history managed by us, or
     * an old one unregistered.
     * @param theContract The token contract address.
     * @param add **true** is the token has been registered, **false** if unregistered.
     */
    event RegistrationUpdated (IICleanable theContract, bool add);

    /**
     * Emitted when an attempt has been made to set the cleanup block number.
     * @param theContract The token contract address.
     * @param blockNumber The block number being set.
     * @param success Whether it succeeded or not.
     */
    event CleanupBlockNumberSet (IICleanable theContract, uint256 blockNumber, bool success);

    /// Only the trigger contract can call this method.
    /// This contract is set at construction time and updated through `AddressUpdatable`.
    modifier onlyTrigger {
        require(msg.sender == triggerContract, ERR_TRIGGER_CONTRACT_ONLY);
        _;
    }

    /**
     * Build a new instance.
     * @param   _governance Contract address that can make governance calls. See `Governed`.
     * @param   _addressUpdater Contract address that can update redeployable addresses. See `AdressUpdatable`.
     * @param   _triggerContractName Contract name that can trigger history cleanups.
     */
    constructor(
        address _governance,
        address _addressUpdater,
        string memory _triggerContractName
    )
        Governed(_governance) AddressUpdatable(_addressUpdater)
    {
        triggerContractName = _triggerContractName;
    }

    /**
     * Register a token contract whose history cleanup index is to be managed.
     * The registered contracts must allow calling `setCleanupBlockNumber`.
     * @param _cleanableToken The address of the contract to be managed.
     */
    function registerToken(IICleanable _cleanableToken) external onlyGovernance {
        uint256 len = registeredTokens.length;

        for (uint256 i = 0; i < len; i++) {
            if (_cleanableToken == registeredTokens[i]) {
                return; // already registered
            }
        }

        registeredTokens.push(_cleanableToken);
        emit RegistrationUpdated (_cleanableToken, true);
    }

    /**
     * Unregister a token contract from history cleanup index management.
     * @param _cleanableToken The address of the contract to unregister.
     */
    function unregisterToken(IICleanable _cleanableToken) external onlyGovernance {
        uint256 len = registeredTokens.length;

        for (uint256 i = 0; i < len; i++) {
            if (_cleanableToken == registeredTokens[i]) {
                registeredTokens[i] = registeredTokens[len -1];
                registeredTokens.pop();
                emit RegistrationUpdated (_cleanableToken, false);
                return;
            }
        }

        revert(ERR_CONTRACT_NOT_FOUND);
    }

    /**
     * Sets clean up block number on managed cleanable tokens.
     * @param _blockNumber cleanup block number
     */
    function setCleanUpBlockNumber(uint256 _blockNumber) external onlyTrigger {
        uint256 len = registeredTokens.length;
        for (uint256 i = 0; i < len; i++) {
            try registeredTokens[i].setCleanupBlockNumber(_blockNumber) {
                emit CleanupBlockNumberSet(registeredTokens[i], _blockNumber, true);
            } catch {
                emit CleanupBlockNumberSet(registeredTokens[i], _blockNumber, false);
            }
        }
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        triggerContract = _getContractAddress(_contractNameHashes, _contractAddresses, triggerContractName);
    }
}


// File contracts/governance/implementation/GovernedAtGenesis.sol


/**
 * Defines behaviors for governed contracts that have their governor set at genesis.
 *
 * This contract enforces a fixed governance address when the constructor
 * is not executed on a contract (for instance when directly loaded to the genesis block).
 * This is required to fix governance on a contract when the network starts, at such point
 * where theoretically no accounts yet exist, and leaving it ungoverned could result in a race
 * to claim governance by an unauthorized address.
 */
contract GovernedAtGenesis is GovernedBase {
    constructor(address _governance) GovernedBase(_governance) { }

    /**
     * Sets governance to a fixed address when constructor is not called.
     */
    function initialiseFixedAddress() public virtual returns (address) {
        address governanceAddress = address(0xfffEc6C83c8BF5c3F4AE0cCF8c45CE20E4560BD7);

        super.initialise(governanceAddress);
        return governanceAddress;
    }

    /**
     * Disallow initialise to be called.
     * @param _governance The governance address for initial claiming.
     **/
    // solhint-disable-next-line no-unused-vars
    function initialise(address _governance) public override pure {
        assert(false);
    }
}


// File contracts/genesis/interface/IInflationGenesis.sol



/**
 * Portion of the Inflation contract that is available to contracts deployed at genesis.
 */
interface IInflationGenesis {
    /**
     * Receive newly minted native tokens from the FlareDaemon.
     *
     * Assume that the received amount will be >= last topup requested across all services.
     * If there is not enough balance sent to cover the topup request, expect the library method to revert.
     * Also assume that any received balance greater than the calculated topup request
     * came from self-destructor sending a balance to this contract.
     */
    function receiveMinting() external payable;
}


// File contracts/genesis/interface/IFlareDaemonize.sol



/**
 * Interface for contracts that receive triggers from the `FlareDaemon` contract.
 */
interface IFlareDaemonize {

    /**
     * Implement this function to receive a trigger from the `FlareDaemon`.
     * The trigger method is called by the validator right at the end of block state transition.
     * @return bool Whether the contract is still active after the call.
     * Currently unused.
     */
    function daemonize() external returns (bool);

    /**
     * This function will be called after an error is caught in daemonize().
     * It will switch the contract to a simpler fallback mode, which hopefully works when full mode doesn't.
     * Not every contract needs to support fallback mode (FtsoManager does), so this method may be empty.
     * Switching back to normal mode is left to the contract (typically a governed method call).
     * This function may be called due to low-gas error, so it shouldn't use more than ~30.000 gas.
     * @return True if switched to fallback mode, false if already in fallback mode or
     * if fallback mode is not supported.
     */
    function switchToFallbackMode() external returns (bool);

    /**
     * Implement this function to allow updating daemonized contracts through the `AddressUpdater`.
     * @return string Contract name.
     */
    function getContractName() external view returns (string memory);
}


// File contracts/genesis/implementation/FlareDaemon.sol

// WARNING, WARNING, WARNING
// If you modify this contract, you need to re-install the binary into the validator
// genesis file for the chain you wish to run. See ./docs/CompilingContracts.md for more information.
// You have been warned. That is all.






/**
 * Flare Daemon contract.
 *
 * This contract exists to coordinate regular daemon-like polling of contracts
 * that are registered to receive said polling. The trigger method is called by the
 * validator right at the end of block state transition.
 */
contract FlareDaemon is GovernedAtGenesis, AddressUpdatable {
    using SafeMath for uint256;
    using SafePct for uint256;

    //====================================================================
    // Data Structures
    //====================================================================
    struct DaemonizedError {
        uint192 lastErrorBlock;
        uint64 numErrors;
        address fromContract;
        uint64 errorTypeIndex;
        string errorMessage;
    }

    struct LastErrorData {
        uint192 totalDaemonizedErrors;
        uint64 lastErrorTypeIndex;
    }

    struct Registration {
        IFlareDaemonize daemonizedContract;
        uint256 gasLimit;
    }

    string internal constant ERR_ALREADY_SET = "already set";
    string internal constant ERR_OUT_OF_BALANCE = "out of balance";
    string internal constant ERR_NOT_INFLATION = "not inflation";
    string internal constant ERR_TOO_MANY = "too many";
    string internal constant ERR_TOO_BIG = "too big";
    string internal constant ERR_TOO_OFTEN = "too often";
    string internal constant ERR_INFLATION_ZERO = "inflation zero";
    string internal constant ERR_BLOCK_NUMBER_SMALL = "block.number small";
    string internal constant INDEX_TOO_HIGH = "start index high";
    string internal constant UPDATE_GAP_TOO_SHORT = "time gap too short";
    string internal constant MAX_MINT_TOO_HIGH = "max mint too high";
    string internal constant MAX_MINT_IS_ZERO = "max mint is zero";
    string internal constant ERR_DUPLICATE_ADDRESS = "dup address";
    string internal constant ERR_ADDRESS_ZERO = "address zero";
    string internal constant ERR_OUT_OF_GAS = "out of gas";
    string internal constant ERR_INFLATION_MINT_RECEIVE_FAIL = "unknown error. receiveMinting";

    uint256 internal constant MAX_DAEMONIZE_CONTRACTS = 10;
    // Initial max mint request - 60 million native token
    uint256 internal constant MAX_MINTING_REQUEST_DEFAULT = 60000000 ether;
    // How often can inflation request minting from the validator - 23 hours constant
    uint256 internal constant MAX_MINTING_FREQUENCY_SEC = 23 hours;
    // How often can the maximal mint request amount be updated
    uint256 internal constant MAX_MINTING_REQUEST_FREQUENCY_SEC = 24 hours;
    // By how much can the maximum be increased (as a percentage of the previous maximum)
    uint256 internal constant MAX_MINTING_REQUEST_INCREASE_PERCENT = 110;
    // upper estimate of gas needed after error occurs in call to daemonizedContract.daemonize()
    uint256 internal constant MIN_GAS_LEFT_AFTER_DAEMONIZE = 300000;
    // lower estimate for gas needed for daemonize() call in trigger
    uint256 internal constant MIN_GAS_FOR_DAEMONIZE_CALL = 5000;

    IInflationGenesis public inflation;
    uint256 public systemLastTriggeredAt;
    uint256 public totalMintingRequestedWei;
    uint256 public totalMintingReceivedWei;
    uint256 public totalMintingWithdrawnWei;
    uint256 public totalSelfDestructReceivedWei;
    uint256 public maxMintingRequestWei;
    uint256 public lastMintRequestTs;
    uint256 public lastUpdateMaxMintRequestTs;
    LastErrorData public errorData;
    uint256 public blockHoldoff;

    uint256 private lastBalance;
    uint256 private expectedMintRequest;
    bool private initialized;

    // track deamonized contracts
    IFlareDaemonize[] internal daemonizeContracts;
    mapping (IFlareDaemonize => uint256) internal gasLimits;
    mapping (IFlareDaemonize => uint256) internal blockHoldoffsRemaining;

    // track daemonize errors
    mapping(bytes32 => DaemonizedError) internal daemonizedErrors;
    bytes32 [] internal daemonizeErrorHashes;

    event ContractDaemonized(address theContract, uint256 gasConsumed);
    event ContractDaemonizeErrored(address theContract, uint256 atBlock, string theMessage, uint256 gasConsumed);
    event ContractHeldOff(address theContract, uint256 blockHoldoffsRemaining);
    event ContractsSkippedOutOfGas(uint256 numberOfSkippedConstracts);
    event MintingRequestReceived(uint256 amountWei);
    event MintingRequestTriggered(uint256 amountWei);
    event MintingReceived(uint256 amountWei);
    event MintingWithdrawn(uint256 amountWei);
    event RegistrationUpdated(IFlareDaemonize theContract, bool add);
    event SelfDestructReceived(uint256 amountWei);
    event InflationSet(IInflationGenesis theNewContract, IInflationGenesis theOldContract);

    /**
     * @dev As there is not a constructor, this modifier exists to make sure the inflation
     *   contract is set for methods that require it.
     */
    modifier inflationSet {
        // Don't revert...just report.
        if (address(inflation) == address(0)) {
            addDaemonizeError(address(this), ERR_INFLATION_ZERO, 0);
        }
        _;
    }

    /**
     * @dev Access control to protect methods to allow only minters to call select methods
     *   (like transferring balance out).
     */
    modifier onlyInflation (address _inflation) {
        require (address(inflation) == _inflation, ERR_NOT_INFLATION);
        _;
    }
    
    /**
     * @dev Access control to protect trigger() method. 
     * Please note that the sender address is the same as deployed FlareDaemon address in this case.
     */
    modifier onlySystemTrigger {
        require (msg.sender == 0x1000000000000000000000000000000000000002);
        _;
    }

    //====================================================================
    // Constructor for pre-compiled code
    //====================================================================

    /**
     * @dev This constructor should contain no code as this contract is pre-loaded into the genesis block.
     *   The super constructor is called for testing convenience.
     */
    constructor() GovernedAtGenesis(address(0)) AddressUpdatable(address(0)) {
        /* empty block */
    }

    //====================================================================
    // Functions
    //====================================================================  

    /**
     * @notice Register contracts to be polled by the daemon process.
     * @param _registrations    An array of Registration structures of IFlareDaemonize contracts to daemonize
     *                          and gas limits for each contract.
     * @dev A gas limit of zero will set no limit for the contract but the validator has an overall
     *   limit for the trigger() method.
     * @dev If any registrations already exist, they will be unregistered.
     * @dev Contracts will be daemonized in the order in which presented via the _registrations array.
     */
    function registerToDaemonize(Registration[] memory _registrations) external onlyGovernance {
        _registerToDaemonize(_registrations);
    }

    /**
     * @notice Queue up a minting request to send to the validator at next trigger.
     * @param _amountWei    The amount to mint.
     */
    function requestMinting(uint256 _amountWei) external onlyInflation(msg.sender) {
        require(_amountWei <= maxMintingRequestWei, ERR_TOO_BIG);
        require(_getNextMintRequestAllowedTs() < block.timestamp, ERR_TOO_OFTEN);
        if (_amountWei > 0) {
            lastMintRequestTs = block.timestamp;
            totalMintingRequestedWei = totalMintingRequestedWei.add(_amountWei);
            emit MintingRequestReceived(_amountWei);
        }
    }

    /**
     * @notice Set number of blocks that must elapse before a daemonized contract exceeding gas limit can have
     *   its daemonize() method called again.
     * @param _blockHoldoff    The number of blocks to holdoff.
     */
    function setBlockHoldoff(uint256 _blockHoldoff) external onlyGovernance {
        blockHoldoff = _blockHoldoff;
    }

    /**
     * @notice Set limit on how much can be minted per request.
     * @param _maxMintingRequestWei    The request maximum in wei.
     * @notice this number can't be udated too often
     */
    function setMaxMintingRequest(uint256 _maxMintingRequestWei) external onlyGovernance {
        // make sure increase amount is reasonable
        require(
            _maxMintingRequestWei <= (maxMintingRequestWei.mulDiv(MAX_MINTING_REQUEST_INCREASE_PERCENT,100)),
            MAX_MINT_TOO_HIGH
        );
        require(_maxMintingRequestWei > 0, MAX_MINT_IS_ZERO);
        // make sure enough time since last update
        require(
            block.timestamp > lastUpdateMaxMintRequestTs + MAX_MINTING_REQUEST_FREQUENCY_SEC,
            UPDATE_GAP_TOO_SHORT
        );

        maxMintingRequestWei = _maxMintingRequestWei;
        lastUpdateMaxMintRequestTs = block.timestamp;
    }

    /**
     * @notice Sets the address udpater contract.
     * @param _addressUpdater   The address updater contract.
     */
    function setAddressUpdater(address _addressUpdater) external onlyGovernance {
        require(getAddressUpdater() == address(0), ERR_ALREADY_SET);
        setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * @notice The meat of this contract. Poll all registered contracts, calling the daemonize() method of each,
     *   in the order in which registered.
     * @return  _toMintWei     Return the amount to mint back to the validator. The asked for balance will show
     *                          up in the next block (it is actually added right before this block's state transition,
     *                          but well after this method call will see it.)
     * @dev This method watches for balances being added to this contract and handles appropriately - legit
     *   mint requests as made via requestMinting, and also self-destruct sending to this contract, should
     *   it happen for some reason.
     */
    //slither-disable-next-line reentrancy-eth      // method protected by reentrancy guard (see comment below)
    function trigger() external virtual inflationSet onlySystemTrigger returns (uint256 _toMintWei) {
        return triggerInternal();
    }

    function getDaemonizedContractsData() external view 
        returns(
            IFlareDaemonize[] memory _daemonizeContracts,
            uint256[] memory _gasLimits,
            uint256[] memory _blockHoldoffsRemaining
        )
    {
        uint256 len = daemonizeContracts.length;
        _daemonizeContracts = new IFlareDaemonize[](len);
        _gasLimits = new uint256[](len);
        _blockHoldoffsRemaining = new uint256[](len);

        for (uint256 i; i < len; i++) {
            IFlareDaemonize daemonizeContract = daemonizeContracts[i];
            _daemonizeContracts[i] = daemonizeContract;
            _gasLimits[i] = gasLimits[daemonizeContract];
            _blockHoldoffsRemaining[i] = blockHoldoffsRemaining[daemonizeContract];
        }
    }

    function getNextMintRequestAllowedTs() external view returns(uint256) {
        return _getNextMintRequestAllowedTs();
    }

    function showLastDaemonizedError () external view 
        returns(
            uint256[] memory _lastErrorBlock,
            uint256[] memory _numErrors,
            string[] memory _errorString,
            address[] memory _erroringContract,
            uint256 _totalDaemonizedErrors
        )
    {
        return showDaemonizedErrors(errorData.lastErrorTypeIndex, 1);
    }

    /**
     * @notice Set the governance address to a hard-coded known address.
     * @dev This should be done at contract deployment time.
     * @return The governance address.
     */
    function initialiseFixedAddress() public override returns(address) {
        if (!initialized) {
            initialized = true;
            address governanceAddress = super.initialiseFixedAddress();
            return governanceAddress;
        } else {
            return governance();
        }
    }

    function showDaemonizedErrors (uint startIndex, uint numErrorTypesToShow) public view 
        returns(
            uint256[] memory _lastErrorBlock,
            uint256[] memory _numErrors,
            string[] memory _errorString,
            address[] memory _erroringContract,
            uint256 _totalDaemonizedErrors
        )
    {
        require(startIndex < daemonizeErrorHashes.length, INDEX_TOO_HIGH);
        uint256 numReportElements = 
            daemonizeErrorHashes.length >= startIndex + numErrorTypesToShow ?
            numErrorTypesToShow :
            daemonizeErrorHashes.length - startIndex;

        _lastErrorBlock = new uint256[] (numReportElements);
        _numErrors = new uint256[] (numReportElements);
        _errorString = new string[] (numReportElements);
        _erroringContract = new address[] (numReportElements);

        // we have error data error type.
        // error type is hash(error_string, source contract)
        // per error type we report how many times it happened.
        // what was last block it happened.
        // what is the error string.
        // what is the erroring contract
        for (uint i = 0; i < numReportElements; i++) {
            bytes32 hash = daemonizeErrorHashes[startIndex + i];

            _lastErrorBlock[i] = daemonizedErrors[hash].lastErrorBlock;
            _numErrors[i] = daemonizedErrors[hash].numErrors;
            _errorString[i] = daemonizedErrors[hash].errorMessage;
            _erroringContract[i] = daemonizedErrors[hash].fromContract;
        }
        _totalDaemonizedErrors = errorData.totalDaemonizedErrors;
    }

    /**
     * @notice Implementation of the AddressUpdatable abstract method - updates Inflation and daemonized contracts.
     * @dev It also sets `maxMintingRequestWei` if it was not set before.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        IInflationGenesis _inflation = IInflationGenesis(
            _getContractAddress(_contractNameHashes, _contractAddresses, "Inflation"));
        emit InflationSet(_inflation, inflation);
        inflation = _inflation;
        if (maxMintingRequestWei == 0) {
            maxMintingRequestWei = MAX_MINTING_REQUEST_DEFAULT;
        }

        uint256 len = daemonizeContracts.length;
        if (len == 0) {
            return;
        }

        Registration[] memory registrations = new Registration[](len);
        for (uint256 i = 0; i < len; i++) {
            IFlareDaemonize daemonizeContract = daemonizeContracts[i];
            registrations[i].daemonizedContract = IFlareDaemonize(
                _getContractAddress(_contractNameHashes, _contractAddresses, daemonizeContract.getContractName()));
            registrations[i].gasLimit = gasLimits[daemonizeContract];
        }

        _registerToDaemonize(registrations);
    }

    /**
     * @notice Implementation of the trigger() method. The external wrapper has extra guard for msg.sender.
     */
    //slither-disable-next-line reentrancy-eth      // method protected by reentrancy guard (see comment below)
    function triggerInternal() internal returns (uint256 _toMintWei) {
        // only one trigger() call per block allowed
        // this also serves as reentrancy guard, since any re-entry will happen in the same block
        if(block.number == systemLastTriggeredAt) return 0;
        systemLastTriggeredAt = block.number;

        uint256 currentBalance = address(this).balance;

        // Did the validator or a self-destructor conjure some native token?
        if (currentBalance > lastBalance) {
            uint256 balanceExpected = lastBalance.add(expectedMintRequest);
            // Did we get what was last asked for?
            if (currentBalance == balanceExpected) {
                // Yes, so assume it all came from the validator.
                uint256 minted = expectedMintRequest;
                totalMintingReceivedWei = totalMintingReceivedWei.add(minted);
                emit MintingReceived(minted);
                //slither-disable-next-line arbitrary-send-eth          // only sent to inflation, set by governance
                try inflation.receiveMinting{ value: minted }() {
                    totalMintingWithdrawnWei = totalMintingWithdrawnWei.add(minted);
                    emit MintingWithdrawn(minted);
                } catch Error(string memory message) {
                    addDaemonizeError(address(this), message, 0);
                } catch {
                    addDaemonizeError(address(this), ERR_INFLATION_MINT_RECEIVE_FAIL, 0);
                }
            } else if (currentBalance < balanceExpected) {
                // No, and if less, there are two possibilities: 1) the validator did not
                // send us what we asked (not possible unless a bug), or 2) an attacker
                // sent us something in between a request and a mint. Assume 2.
                uint256 selfDestructReceived = currentBalance.sub(lastBalance);
                totalSelfDestructReceivedWei = totalSelfDestructReceivedWei.add(selfDestructReceived);
                emit SelfDestructReceived(selfDestructReceived);
            } else {
                // No, so assume we got a minting request (perhaps zero...does not matter)
                // and some self-destruct proceeds (unlikely but can happen).
                totalMintingReceivedWei = totalMintingReceivedWei.add(expectedMintRequest);
                uint256 selfDestructReceived = currentBalance.sub(lastBalance).sub(expectedMintRequest);
                totalSelfDestructReceivedWei = totalSelfDestructReceivedWei.add(selfDestructReceived);
                emit MintingReceived(expectedMintRequest);
                emit SelfDestructReceived(selfDestructReceived);
                //slither-disable-next-line arbitrary-send-eth          // only sent to inflation, set by governance
                try inflation.receiveMinting{ value: expectedMintRequest }() {
                    totalMintingWithdrawnWei = totalMintingWithdrawnWei.add(expectedMintRequest);
                    emit MintingWithdrawn(expectedMintRequest);
                } catch Error(string memory message) {
                    addDaemonizeError(address(this), message, 0);
                } catch {
                    addDaemonizeError(address(this), ERR_INFLATION_MINT_RECEIVE_FAIL, 0);
                }
            }
        }

        uint256 len = daemonizeContracts.length;

        // Perform trigger operations here
        for (uint256 i = 0; i < len; i++) {
            IFlareDaemonize daemonizedContract = daemonizeContracts[i];
            uint256 blockHoldoffRemainingForContract = blockHoldoffsRemaining[daemonizedContract];
            if (blockHoldoffRemainingForContract > 0) {
                blockHoldoffsRemaining[daemonizedContract] = blockHoldoffRemainingForContract - 1;
                emit ContractHeldOff(address(daemonizedContract), blockHoldoffRemainingForContract);
            } else {
                // Figure out what gas to limit call by
                uint256 gasLimit = gasLimits[daemonizedContract];
                uint256 startGas = gasleft();
                // End loop if there isn't enough gas left for any daemonize call
                if (startGas < MIN_GAS_LEFT_AFTER_DAEMONIZE + MIN_GAS_FOR_DAEMONIZE_CALL) {
                    emit ContractsSkippedOutOfGas(len - i);
                    break;
                }
                // Calculate the gas limit for the next call
                uint256 useGas = startGas - MIN_GAS_LEFT_AFTER_DAEMONIZE;
                if (gasLimit > 0 && gasLimit < useGas) {
                    useGas = gasLimit;
                }
                // Run daemonize for the contract, consume errors, and record
                try daemonizedContract.daemonize{gas: useGas}() {
                    emit ContractDaemonized(address(daemonizedContract), (startGas - gasleft()));
                // Catch all requires with messages
                } catch Error(string memory message) {
                    addDaemonizeError(address(daemonizedContract), message, (startGas - gasleft()));
                    daemonizedContract.switchToFallbackMode();
                // Catch everything else...out of gas, div by zero, asserts, etc.
                } catch {
                    uint256 endGas = gasleft();
                    // Interpret out of gas errors
                    if (gasLimit > 0 && startGas.sub(endGas) >= gasLimit) {
                        addDaemonizeError(address(daemonizedContract), ERR_OUT_OF_GAS, (startGas - endGas));
                        // When daemonize() fails with out-of-gas, try to fix it in two steps:
                        // 1) try to switch contract to fallback mode
                        //    (to allow the contract's daemonize() to recover in fallback mode in next block)
                        // 2) if constract is already in fallback mode or fallback mode is not supported
                        //    (switchToFallbackMode() returns false), start the holdoff for this contract
                        bool switchedToFallback = daemonizedContract.switchToFallbackMode();
                        if (!switchedToFallback) {
                            blockHoldoffsRemaining[daemonizedContract] = blockHoldoff;
                        }
                    } else {
                        // Don't know error cause...just log it as unknown
                        addDaemonizeError(address(daemonizedContract), "unknown", (startGas - endGas));
                        daemonizedContract.switchToFallbackMode();
                    }
                }
            }
        }

        // Get any requested minting and return to validator
        _toMintWei = getPendingMintRequest();
        if (_toMintWei > 0) {
            expectedMintRequest = _toMintWei;
            emit MintingRequestTriggered(_toMintWei);
        } else {
            expectedMintRequest = 0;            
        }

        // Update balance
        lastBalance = address(this).balance;
        
        // We should be in balance - don't revert, just report...
        uint256 contractBalanceExpected = getExpectedBalance();
        if (contractBalanceExpected != address(this).balance) {
            addDaemonizeError(address(this), ERR_OUT_OF_BALANCE, 0);
        }
    }

    function addDaemonizeError(address daemonizedContract, string memory message, uint256 gasConsumed) internal {
        bytes32 errorStringHash = keccak256(abi.encode(daemonizedContract, message));

        DaemonizedError storage daemonizedError = daemonizedErrors[errorStringHash];
        if (daemonizedError.numErrors == 0) {
            // first time we recieve this error string.
            daemonizeErrorHashes.push(errorStringHash);
            daemonizedError.fromContract = daemonizedContract;
            // limit message length to fit in fixed number of storage words (to make gas usage predictable)
            daemonizedError.errorMessage = truncateString(message, 64);
            daemonizedError.errorTypeIndex = uint64(daemonizeErrorHashes.length - 1);
        }
        daemonizedError.numErrors += 1;
        daemonizedError.lastErrorBlock = uint192(block.number);
        emit ContractDaemonizeErrored(daemonizedContract, block.number, message, gasConsumed);

        errorData.totalDaemonizedErrors += 1;
        errorData.lastErrorTypeIndex = daemonizedError.errorTypeIndex;        
    }

    /**
     * @notice Register contracts to be polled by the daemon process.
     * @param _registrations    An array of Registration structures of IFlareDaemonize contracts to daemonize
     *                          and gas limits for each contract.
     * @dev A gas limit of zero will set no limit for the contract but the validator has an overall
     *   limit for the trigger() method.
     * @dev If any registrations already exist, they will be unregistered.
     * @dev Contracts will be daemonized in the order in which presented via the _registrations array.
     */
    function _registerToDaemonize(Registration[] memory _registrations) internal {
        // Make sure there are not too many contracts to register.
        uint256 registrationsLength = _registrations.length;
        require(registrationsLength <= MAX_DAEMONIZE_CONTRACTS, ERR_TOO_MANY);

        // Unregister everything first
        _unregisterAll();

        // Loop over all contracts to register
        for (uint256 registrationIndex = 0; registrationIndex < registrationsLength; registrationIndex++) {
            // Address cannot be zero
            require(address(_registrations[registrationIndex].daemonizedContract) != address(0), ERR_ADDRESS_ZERO);

            uint256 daemonizeContractsLength = daemonizeContracts.length;
            // Make sure no dups...yes, inefficient. Registration should not be done often.
            for (uint256 i = 0; i < daemonizeContractsLength; i++) {
                require(_registrations[registrationIndex].daemonizedContract != daemonizeContracts[i], 
                    ERR_DUPLICATE_ADDRESS); // already registered
            }
            // Store off the registered contract to daemonize, in the order presented.
            daemonizeContracts.push(_registrations[registrationIndex].daemonizedContract);
            // Record the gas limit for the contract.
            gasLimits[_registrations[registrationIndex].daemonizedContract] = 
                _registrations[registrationIndex].gasLimit;
            // Clear any blocks being held off for the given contract, if any. Contracts may be re-presented
            // if only order is being modified, for example.
            blockHoldoffsRemaining[_registrations[registrationIndex].daemonizedContract] = 0;
            emit RegistrationUpdated (_registrations[registrationIndex].daemonizedContract, true);
        }
    }

    /**
     * @notice Unregister all contracts from being polled by the daemon process.
     */
    function _unregisterAll() private {

        uint256 len = daemonizeContracts.length;

        for (uint256 i = 0; i < len; i++) {
            IFlareDaemonize daemonizedContract = daemonizeContracts[daemonizeContracts.length - 1];
            daemonizeContracts.pop();
            emit RegistrationUpdated (daemonizedContract, false);
        }
    }

    /**
     * @notice Net totals to obtain the expected balance of the contract.
     */
    function getExpectedBalance() private view returns(uint256 _balanceExpectedWei) {
        _balanceExpectedWei = totalMintingReceivedWei.
            sub(totalMintingWithdrawnWei).
            add(totalSelfDestructReceivedWei);
    }

    /**
     * @notice Net total received from total requested.
     */
    function getPendingMintRequest() private view returns(uint256 _mintRequestPendingWei) {
        _mintRequestPendingWei = totalMintingRequestedWei.sub(totalMintingReceivedWei);
    }


    function _getNextMintRequestAllowedTs() internal view returns (uint256) {
        return (lastMintRequestTs + MAX_MINTING_FREQUENCY_SEC);
    }

    function truncateString(string memory _str, uint256 _maxlength) private pure returns (string memory) {
        bytes memory strbytes = bytes(_str);
        if (strbytes.length <= _maxlength) {
            return _str;
        }
        bytes memory result = new bytes(_maxlength);
        for (uint256 i = 0; i < _maxlength; i++) {
            result[i] = strbytes[i];
        }
        return string(result);
    }
}


// File contracts/utils/implementation/GovernedAndFlareDaemonized.sol



/**
 * Base class for contracts that are governed and triggered from the FlareDaemon.
 *
 * See `Governed` and `IFlareDaemonize`.
 */
contract GovernedAndFlareDaemonized is Governed {

    /// The FlareDaemon contract, set at construction time.
    FlareDaemon public immutable flareDaemon;

    /// Only the `flareDaemon` can call this method.
    modifier onlyFlareDaemon () {
        require (msg.sender == address(flareDaemon), "only flare daemon");
        _;
    }

    constructor(address _governance, FlareDaemon _flareDaemon) Governed(_governance) {
        require(address(_flareDaemon) != address(0), "flare daemon zero");
        flareDaemon = _flareDaemon;
    }
}


// File contracts/staking/interface/IIPChainStakeMirrorVerifier.sol


/**
 * Internal interface for P-chain stake mirror verifications.
 */
interface IIPChainStakeMirrorVerifier is IPChainStakeMirrorVerifier {

    /**
     * Method for P-chain stake verification using `IPChainStakeMirrorVerifier.PChainStake` data and Merkle proof.
     * @param _stakeData Information about P-chain stake.
     * @param _merkleProof Merkle proof that should be used to prove the P-chain stake.
     * @return True if stake can be verified using provided Merkle proof.
     */
    function verifyStake(
        IPChainStakeMirrorVerifier.PChainStake calldata _stakeData,
        bytes32[] calldata _merkleProof
    )
        external view returns(bool);
}


// File contracts/userInterfaces/IAddressBinder.sol


/**
 * Interface for the `AddressBinder` contract.
 */
interface IAddressBinder {

    /**
     * @notice Event emitted when c-chan and P-chain addresses are registered
     */
    event AddressesRegistered(bytes publicKey, bytes20 pAddress, address cAddress);

    /**
     * Register P-chain and C-chain addresses.
     * @param _publicKey Public key from which addresses to register are derived from.
     * @param _pAddress P-chain address to register.
     * @param _cAddress C-chain address to register.
     */
    function registerAddresses(bytes calldata _publicKey, bytes20 _pAddress, address _cAddress) external;

    /**
     * Register P-chain and C-chain addresses derived from given public key.
     * @param _publicKey Public key from which addresses to register are derived from.
     * @return _pAddress Registered P-chain address.
     * @return _cAddress Registered C-chain address.
     */
    function registerPublicKey(bytes calldata _publicKey) external returns(bytes20 _pAddress, address _cAddress);

    /**
     * @dev Queries the C-chain address for given P-chain address.
     * @param _pAddress The P-chain address for which corresponding C-chain address will be retrieved.
     * @return _cAddress The corresponding c-address.
     **/
    function pAddressToCAddress(bytes20 _pAddress) external view returns(address _cAddress);

    /**
     * @dev Queries the P-chain address for given C-chain address.
     * @param _cAddress The C-chain address for which corresponding P-chain address will be retrieved.
     * @return _pAddress The corresponding p-address.
     **/
    function cAddressToPAddress(address _cAddress) external view returns(bytes20 _pAddress);
}


// File contracts/staking/lib/PChainStakeHistory.sol





/**
 * PChainStakeHistory library
 * A contract to manage checkpoints as of a given block.
 * Store value history by block number with detachable state.
 **/
library PChainStakeHistory {
    using SafeMath for uint256;
    using SafePct for uint256;
    using SafeCast for uint256;

    /**
     * Structure describing stake parameters.
     */
    struct Stake {
        uint256 value;
        bytes20 nodeId;

        // stakes[0] will also hold length and blockNumber to save 1 slot of storage per checkpoint
        // for all other indexes these fields will be 0
        // also, when checkpoint is empty, `length` will automatically be 0, which is ok
        uint64 fromBlock;
        uint8 length;       // length is limited to MAX_NODE_IDS which fits in 8 bits
    }

    /**
     * `CheckPoint` is the structure that attaches a block number to a
     * given value; the block number attached is the one that last changed the value
     **/
    struct CheckPoint {
        // the list of stakes at the time
        mapping(uint256 => Stake) stakes;
    }

    /**
     * Structure for saving checkpoints per address.
     */
    struct CheckPointHistoryState {
        // `checkpoints` is an array that tracks stakes at non-contiguous block numbers
        mapping(uint256 => CheckPoint) checkpoints;
        // `checkpoints` before `startIndex` have been deleted
        // INVARIANT: checkpoints.length == 0 || startIndex < checkpoints.length      (strict!)
        uint64 startIndex;
        uint64 length;
    }

    /// Number of max staking node ids per address
    uint256 public constant MAX_NODE_IDS = 3;
    string private constant MAX_NODE_IDS_MSG = "Max node ids exceeded";

    /**
     * Writes the value at the current block.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _nodeId The node id to update.
     * @param _value The new value to set for this stake (value `0` deletes `_nodeId` from the list).
     **/
    function writeValue(
        CheckPointHistoryState storage _self,
        bytes20 _nodeId,
        uint256 _value
    )
        internal
    {
        uint256 historyCount = _self.length;
        if (historyCount == 0) {
            // checkpoints array empty, push new CheckPoint
            if (_value != 0) {
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                cp.stakes[0] = Stake({
                    nodeId: _nodeId,
                    value: _value,
                    fromBlock:  block.number.toUint64(),
                    length: 1
                });
            }
        } else {
            // historyCount - 1 is safe, since historyCount != 0
            CheckPoint storage lastCheckpoint = _self.checkpoints[historyCount - 1];
            uint256 lastBlock = lastCheckpoint.stakes[0].fromBlock;
            // slither-disable-next-line incorrect-equality
            if (block.number == lastBlock) {
                // If last check point is the current block, just update
                _updateStakes(lastCheckpoint, _nodeId, _value);
            } else {
                // we should never have future blocks in history
                assert(block.number > lastBlock);
                // last check point block is before
                CheckPoint storage cp = _self.checkpoints[historyCount];
                _self.length = SafeCast.toUint64(historyCount + 1);
                _copyAndUpdateStakes(cp, lastCheckpoint, _nodeId, _value);
                cp.stakes[0].fromBlock = block.number.toUint64();
            }
        }
    }

    /**
     * Delete at most `_count` of the oldest checkpoints.
     * At least one checkpoint at or before `_cleanupBlockNumber` will remain
     * (unless the history was empty to start with).
     */
    function cleanupOldCheckpoints(
        CheckPointHistoryState storage _self,
        uint256 _count,
        uint256 _cleanupBlockNumber
    )
        internal
        returns (uint256)
    {
        if (_cleanupBlockNumber == 0) return 0;   // optimization for when cleaning is not enabled
        uint256 length = _self.length;
        if (length == 0) return 0;
        uint256 startIndex = _self.startIndex;
        // length - 1 is safe, since length != 0 (check above)
        uint256 endIndex = Math.min(startIndex.add(_count), length - 1);    // last element can never be deleted
        uint256 index = startIndex;
        // we can delete `checkpoint[index]` while the next checkpoint is at `_cleanupBlockNumber` or before
        while (index < endIndex && _self.checkpoints[index + 1].stakes[0].fromBlock <= _cleanupBlockNumber) {
            CheckPoint storage cp = _self.checkpoints[index];
            uint256 cplength = cp.stakes[0].length;
            for (uint256 i = 0; i < cplength; i++) {
                delete cp.stakes[i];
            }
            index++;
        }
        if (index > startIndex) {   // index is the first not deleted index
            _self.startIndex = SafeCast.toUint64(index);
        }
        return index - startIndex;  // safe: index = startIndex at start and increases in loop
    }

    /**
     * Queries the value at a specific `_blockNumber`
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _nodeId The node id for which we need value.
     * @param _blockNumber The block number of the value active at that time
     * @return _value The value of the `_nodeId` at `_blockNumber`
     **/
    function valueOfAt(
        CheckPointHistoryState storage _self,
        bytes20 _nodeId,
        uint256 _blockNumber
    )
        internal view
        returns (uint256 _value)
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) return 0;
        return _getValueForNodeId(_self.checkpoints[index], _nodeId);
    }

    /**
     * Queries the value at `block.number`
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _nodeId The node id for which we need value.
     * @return _value The value at `block.number`
     **/
    function valueOfAtNow(
        CheckPointHistoryState storage _self,
        bytes20 _nodeId
    )
        internal view
        returns (uint256 _value)
    {
        uint256 length = _self.length;
        if (length == 0) return 0;
        return _getValueForNodeId(_self.checkpoints[length - 1], _nodeId);
    }

    /**
     * Get all node stakes active at a time.
     * @param _self A CheckPointHistoryState instance to manage.
     * @param _blockNumber The block number to query.
     * @return _nodeIds The active node ids at the time.
     * @return _values The node ids' values at the time.
     **/
    function stakesAt(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        internal view
        returns (
            bytes20[] memory _nodeIds,
            uint256[] memory _values
        )
    {
        (bool found, uint256 index) = _findGreatestBlockLessThan(_self, _blockNumber);
        if (!found) {
            return (new bytes20[](0), new uint256[](0));
        }

        // copy stakes and values to memory arrays
        // (to prevent caller updating the stored value)
        CheckPoint storage cp = _self.checkpoints[index];
        uint256 length = cp.stakes[0].length;
        _nodeIds = new bytes20[](length);
        _values = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            Stake storage stake = cp.stakes[i];
            _nodeIds[i] = stake.nodeId;
            _values[i] = stake.value;
        }
    }

    /**
     * Get all node stakes active now.
     * @param _self A CheckPointHistoryState instance to manage.
     * @return _nodeIds The active node ids stakes.
     * @return _values The stakes' values.
     **/
    function stakesAtNow(
        CheckPointHistoryState storage _self
    )
        internal view
        returns (bytes20[] memory _nodeIds, uint256[] memory _values)
    {
        return stakesAt(_self, block.number);
    }

    /////////////////////////////////////////////////////////////////////////////////
    // helper functions for writeValueAt

    function _copyAndUpdateStakes(
        CheckPoint storage _cp,
        CheckPoint storage _orig,
        bytes20 _nodeId,
        uint256 _value
    )
        private
    {
        uint256 length = _orig.stakes[0].length;
        bool updated = false;
        uint256 newlength = 0;
        for (uint256 i = 0; i < length; i++) {
            Stake memory origStake = _orig.stakes[i];
            if (origStake.nodeId == _nodeId) {
                // copy nodeId, but with new value
                newlength = _appendStake(_cp, origStake.nodeId, _value, newlength);
                updated = true;
            } else {
                // just copy the stake with original value
                newlength = _appendStake(_cp, origStake.nodeId, origStake.value, newlength);
            }
        }
        if (!updated) {
            // _nodeId is not in the original list, so add it
            newlength = _appendStake(_cp, _nodeId, _value, newlength);
        }
        // safe - newlength <= length + 1 <= MAX_NODE_IDS
        _cp.stakes[0].length = uint8(newlength);
    }

    function _updateStakes(CheckPoint storage _cp, bytes20 _nodeId, uint256 _value) private {
        uint256 length = _cp.stakes[0].length;
        uint256 i = 0;
        while (i < length && _cp.stakes[i].nodeId != _nodeId) ++i;
        if (i < length) {
            if (_value != 0) {
                _cp.stakes[i].value = _value;
            } else {
                _deleteStake(_cp, i, length - 1);  // length - 1 is safe:  0 <= i < length
                _cp.stakes[0].length = uint8(length - 1);
            }
        } else {
            uint256 newlength = _appendStake(_cp, _nodeId, _value, length);
            _cp.stakes[0].length = uint8(newlength);  // safe - length <= MAX_NODE_IDS
        }
    }

    function _appendStake(CheckPoint storage _cp, bytes20 _nodeId, uint256 _value, uint256 _length)
        private
        returns (uint256)
    {
        if (_value != 0) {
            require(_length < MAX_NODE_IDS, MAX_NODE_IDS_MSG);
            Stake storage stake = _cp.stakes[_length];
            stake.nodeId = _nodeId;
            stake.value = _value;
            // for stakes[0], fromBlock and length are assigned outside
            return _length + 1;
        }
        return _length;
    }

    function _deleteStake(CheckPoint storage _cp, uint256 _index, uint256 _last) private {
        Stake storage stake = _cp.stakes[_index];
        Stake storage lastStake = _cp.stakes[_last];
        if (_index < _last) {
            stake.nodeId = lastStake.nodeId;
            stake.value = lastStake.value;
        }
        lastStake.nodeId = bytes20(0);
        lastStake.value = 0;
    }

    /////////////////////////////////////////////////////////////////////////////////
    // helper functions for querying

    /**
     * Binary search of _checkpoints array.
     * @param _checkpoints An array of CheckPoint to search.
     * @param _startIndex Smallest possible index to be returned.
     * @param _blockNumber The block number to search for.
     */
    function _binarySearchGreatestBlockLessThan(
        mapping(uint256 => CheckPoint) storage _checkpoints,
        uint256 _startIndex,
        uint256 _endIndex,
        uint256 _blockNumber
    )
        private view
        returns (uint256 _index)
    {
        // Binary search of the value by given block number in the array
        uint256 min = _startIndex;
        uint256 max = _endIndex.sub(1);
        while (max > min) {
            uint256 mid = (max.add(min).add(1)).div(2);
            if (_checkpoints[mid].stakes[0].fromBlock <= _blockNumber) {
                min = mid;
            } else {
                max = mid.sub(1);
            }
        }
        return min;
    }

    /**
     * Binary search of _checkpoints array. Extra optimized for the common case when we are
     *   searching for the last block.
     * @param _self The state to query.
     * @param _blockNumber The block number to search for.
     * @return _found true if value was found (only `false` if `_blockNumber` is before first
     *   checkpoint or the checkpoint array is empty)
     * @return _index index of the newest block with number less than or equal `_blockNumber`
     */
    function _findGreatestBlockLessThan(
        CheckPointHistoryState storage _self,
        uint256 _blockNumber
    )
        private view
        returns (
            bool _found,
            uint256 _index
        )
    {
        uint256 startIndex = _self.startIndex;
        uint256 historyCount = _self.length;
        if (historyCount == 0) {
            _found = false;
        } else if (_blockNumber >= _self.checkpoints[historyCount - 1].stakes[0].fromBlock) {
            _found = true;
            _index = historyCount - 1;  // safe, historyCount != 0 in this branch
        } else if (_blockNumber < _self.checkpoints[startIndex].stakes[0].fromBlock) {
            // reading data before `_startIndex` is only safe before first cleanup
            assert(startIndex == 0);
            _found = false;
        } else {
            _found = true;
            _index = _binarySearchGreatestBlockLessThan(_self.checkpoints, startIndex, historyCount, _blockNumber);
        }
    }

    /**
     * Find stake and return its value or 0 if not found.
     */
    function _getValueForNodeId(CheckPoint storage _cp, bytes20 _nodeId) private view returns (uint256) {
        uint256 length = _cp.stakes[0].length;
        for (uint256 i = 0; i < length; i++) {
            Stake storage stake = _cp.stakes[i];
            if (stake.nodeId == _nodeId) {
                return stake.value;
            }
        }
        return 0;   // _nodeId not found
    }
}


// File contracts/staking/implementation/PChainStake.sol








/**
 * Helper contract handling all the vote power and balance functionality for the PChainStakeMirror.
 */
contract PChainStake is IPChainVotePower, CheckPointable {
    using PChainStakeHistory for PChainStakeHistory.CheckPointHistoryState;
    using SafeMath for uint256;
    using SafePct for uint256;
    using VotePower for VotePower.VotePowerState;
    using VotePowerCache for VotePowerCache.CacheState;

    // The number of history cleanup steps executed for every write operation.
    // It is more than 1 to make as certain as possible that all history gets cleaned eventually.
    uint256 private constant CHECKPOINTS_CLEANUP_COUNT = 2;

    mapping(address => PChainStakeHistory.CheckPointHistoryState) private stakes;

    // `votePower` tracks all vote power balances
    VotePower.VotePowerState private votePower;

    // `votePowerCache` tracks all cached vote power balances
    VotePowerCache.CacheState private votePowerCache;

    // history cleanup methods

    /**
     * Delete vote power checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _nodeId vote power node id
     * @param _count maximum number of checkpoints to delete
     * @return the number of checkpoints deleted
     */
    function votePowerHistoryCleanup(bytes20 _nodeId, uint256 _count) external onlyCleaner returns (uint256) {
        return votePower.cleanupOldCheckpoints(address(_nodeId), _count, _cleanupBlockNumber());
    }

    /**
     * Delete vote power cache entry that expired (i.e. is before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _nodeId vote power node id
     * @param _blockNumber the block number for which total supply value was cached
     * @return the number of cache entries deleted (always 0 or 1)
     */
    function votePowerCacheCleanup(bytes20 _nodeId, uint256 _blockNumber) external onlyCleaner returns (uint256) {
        require(_blockNumber < _cleanupBlockNumber(), "No cleanup after cleanup block");
        return votePowerCache.deleteValueAt(address(_nodeId), _blockNumber);
    }

    /**
     * Delete stakes checkpoints that expired (i.e. are before `cleanupBlockNumber`).
     * Method can only be called from the `cleanerContract` (which may be a proxy to external cleaners).
     * @param _owner Balance owner account address.
     * @param _count Maximum number of checkpoints to delete.
     * @return Number of deleted checkpoints.
     */
    function stakesHistoryCleanup(address _owner, uint256 _count) external onlyCleaner returns (uint256) {
        return stakes[_owner].cleanupOldCheckpoints(_count, _cleanupBlockNumber());
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function totalVotePowerAtCached(uint256 _blockNumber) external override returns(uint256) {
        return _totalSupplyAtCached(_blockNumber);
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function votePowerOfAtCached(
        bytes20 _nodeId,
        uint256 _blockNumber
    )
        external override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256)
    {
        require(_blockNumber < block.number, "Can only be used for past blocks");
        (uint256 vp, bool createdCache) = votePowerCache.valueOfAt(votePower, address(_nodeId), _blockNumber);
        if (createdCache) emit VotePowerCacheCreated(_nodeId, _blockNumber);
        return vp;
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function totalVotePower() external view override returns(uint256) {
        return totalSupplyAt(block.number);
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function totalVotePowerAt(uint256 _blockNumber) external view override returns(uint256) {
        return totalSupplyAt(_blockNumber);
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function stakesOf(address _owner)
        external view override
        returns (
            bytes20[] memory _nodeIds,
            uint256[] memory _amounts
        )
    {
        return stakes[_owner].stakesAtNow();
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function stakesOfAt(
        address _owner,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns (
            bytes20[] memory _nodeIds,
            uint256[] memory _amounts
        )
    {
        return stakes[_owner].stakesAt(_blockNumber);
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function votePowerFromTo(
        address _owner,
        bytes20 _nodeId
    )
        external view override
        returns(uint256 _votePower)
    {
        return stakes[_owner].valueOfAtNow(_nodeId);
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function votePowerFromToAt(
        address _owner,
        bytes20 _nodeId,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256 _votePower)
    {
        return stakes[_owner].valueOfAt(_nodeId, _blockNumber);
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function votePowerOf(bytes20 _nodeId) external view override returns(uint256) {
        return votePower.votePowerOfAtNow(address(_nodeId));
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function votePowerOfAt(
        bytes20 _nodeId,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256)
    {
        // read cached value for past blocks (and possibly get a cache speedup)
        if (_blockNumber < block.number) {
            return votePowerCache.valueOfAtReadonly(votePower, address(_nodeId), _blockNumber);
        } else {
            return votePower.votePowerOfAtNow(address(_nodeId));
        }
    }

    /**
     * @inheritdoc IPChainVotePower
     */
    function batchVotePowerOfAt(
        bytes20[] memory _owners,
        uint256 _blockNumber
    )
        external view override
        notBeforeCleanupBlock(_blockNumber)
        returns(uint256[] memory _votePowers)
    {
        require(_blockNumber < block.number, "Can only be used for past blocks");
        _votePowers = new uint256[](_owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            // read through cache, much faster if it has been set
            _votePowers[i] = votePowerCache.valueOfAtReadonly(votePower, address(_owners[i]), _blockNumber);
        }
    }

    /**
     * Increase vote power by `_amount` for `_nodeId` from `_owner`
     * @param _owner The address of the owner
     * @param _nodeId The node id of the recipient
     * @param _amount The increasing amount of vote power
     **/
    function _increaseVotePower(
        address _owner,
        bytes20 _nodeId,
        uint256 _amount
    )
        internal virtual
    {
        require (_nodeId != bytes20(0), "Cannot stake to zero");
        votePower.changeValue(address(_nodeId), _amount, 0);
        votePower.cleanupOldCheckpoints(address(_nodeId), CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // Get the vote power of the sender
        PChainStakeHistory.CheckPointHistoryState storage ownerStake = stakes[_owner];

        // the amounts
        uint256 priorAmount = ownerStake.valueOfAtNow(_nodeId);
        uint256 newAmount = priorAmount.add(_amount);

        // Add/replace stake
        ownerStake.writeValue(_nodeId, newAmount);
        ownerStake.cleanupOldCheckpoints(CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // emit event for stake change
        emit VotePowerChanged(_owner, _nodeId, priorAmount, newAmount);
    }

    /**
     * Decrease vote power by `_amount` for `_nodeId` from `_owner`
     * @param _owner The address of the owner
     * @param _nodeId The node id of the recipient
     * @param _amount The decreasing amount of vote power
     **/
    function _decreaseVotePower(
        address _owner,
        bytes20 _nodeId,
        uint256 _amount
    )
        internal virtual
    {
        require (_nodeId != bytes20(0), "Cannot stake to zero");
        votePower.changeValue(address(_nodeId), 0, _amount);
        votePower.cleanupOldCheckpoints(address(_nodeId), CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // Get the vote power of the sender
        PChainStakeHistory.CheckPointHistoryState storage ownerStake = stakes[_owner];

        // the amounts
        uint256 priorAmount = ownerStake.valueOfAtNow(_nodeId);
        uint256 newAmount = priorAmount.sub(_amount);

        // Add/replace stake
        ownerStake.writeValue(_nodeId, newAmount);
        ownerStake.cleanupOldCheckpoints(CHECKPOINTS_CLEANUP_COUNT, _cleanupBlockNumber());

        // emit event for stake change
        emit VotePowerChanged(_owner, _nodeId, priorAmount, newAmount);
    }
}


// File contracts/staking/implementation/PChainStakeMirror.sol













/**
 * Contract used to mirror all stake amounts from P-chain.
 */
contract PChainStakeMirror is IPChainStakeMirror, PChainStake, GovernedAndFlareDaemonized,
        IFlareDaemonize, IICleanable, AddressUpdatable {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafePct for uint256;

    /**
     * Structure with data needed to end stakes
     */
    struct PChainStakingData {
        address owner;
        bytes20 nodeId;
        uint64 weightGwei;
    }

    uint256 constant internal GWEI = 1e9;

    /// Indicates if stakes can be mirrored.
    bool public active;
    /// Max number of stake ends that Flare daemon updates per block.
    uint256 public maxUpdatesPerBlock;
    /// Indicates timestamp of stake ends that Flare daemon will trigger next.
    uint256 public nextTimestampToTrigger;

    /// Mapping from stake end time to the list of tx hashes - `keccak256(abi.encode(txId, inputAddress))`
    mapping(uint256 => bytes32[]) public endTimeToTransactionHashList;
    /// Return staking data for given tx hash - `keccak256(abi.encode(txId, inputAddress))`
    mapping(bytes32 => PChainStakingData) public transactionHashToPChainStakingData;

    // addresses
    /// The contract to use for governance vote power and delegation.
    /// Here only to properly update governance VP at stake start/end,
    /// all actual operations go directly to governance VP contract.
    IIGovernanceVotePower public governanceVotePower;
    /// The contract used for P-chain stake verifications.
    IIPChainStakeMirrorVerifier public verifier;
    /// The contract used for converting P-chain address to C-chain address - both derived from the same public key.
    IAddressBinder public addressBinder;
    /// The contract that is allowed to set cleanupBlockNumber.
    /// Usually this will be an instance of CleanupBlockNumberManager.
    address public cleanupBlockNumberManager;

    /// This method can only be called when the PChainStakeMirror is active.
    modifier whenActive {
        require(active, "not active");
        _;
    }

    /**
     * Initializes the contract with default parameters
     * @param _governance Address identifying the governance address
     * @param _flareDaemon Address identifying the flare daemon contract
     * @param _addressUpdater Address identifying the address updater contract
     * @param _maxUpdatesPerBlock Max number of updates (stake ends) per block
     */
    constructor(
        address _governance,
        FlareDaemon _flareDaemon,
        address _addressUpdater,
        uint256 _maxUpdatesPerBlock
    )
        GovernedAndFlareDaemonized(_governance, _flareDaemon) AddressUpdatable(_addressUpdater)
    {
        maxUpdatesPerBlock = _maxUpdatesPerBlock;
        emit MaxUpdatesPerBlockSet(_maxUpdatesPerBlock);
    }

    /**
     * Activates PChainStakeMirror contract - enable mirroring.
     * @dev Only governance can call this.
     */
    function activate() external onlyImmediateGovernance {
        active = true;
        if (nextTimestampToTrigger == 0) {
            nextTimestampToTrigger = block.timestamp;
        }
    }

    /**
     * Deactivates PChainStakeMirror contract - disable mirroring.
     * @dev Only governance can call this.
     */
    function deactivate() external onlyImmediateGovernance {
        active = false;
    }

    /**
     * @inheritdoc IFlareDaemonize
     * @dev Only flare daemon can call this.
     * Reduce balances and vote powers for stakes that just ended.
     */
    function daemonize() external override onlyFlareDaemon returns (bool) {
        uint256 nextTimestampToTriggerTmp = nextTimestampToTrigger;
        // flare daemon trigger. once every block
        if (nextTimestampToTriggerTmp == 0) return false;

        uint256 maxUpdatesPerBlockTemp = maxUpdatesPerBlock;
        uint256 noOfUpdates = 0;
        while (nextTimestampToTriggerTmp <= block.timestamp) {
            for (uint256 i = endTimeToTransactionHashList[nextTimestampToTriggerTmp].length; i > 0; i--) {
                noOfUpdates++;
                if (noOfUpdates > maxUpdatesPerBlockTemp) {
                    break;
                } else {
                    bytes32 txHash = endTimeToTransactionHashList[nextTimestampToTriggerTmp][i - 1];
                    endTimeToTransactionHashList[nextTimestampToTriggerTmp].pop();
                    _decreaseStakeAmount(transactionHashToPChainStakingData[txHash], txHash);
                    delete transactionHashToPChainStakingData[txHash];
                }
            }
            if (noOfUpdates > maxUpdatesPerBlockTemp) {
                break;
            } else {
                nextTimestampToTriggerTmp++;
            }
        }

        nextTimestampToTrigger = nextTimestampToTriggerTmp;
        return true;
    }

    /**
     * @inheritdoc IPChainStakeMirror
     */
    function mirrorStake(
        IPChainStakeMirrorVerifier.PChainStake calldata _stakeData,
        bytes32[] calldata _merkleProof
    )
        external override whenActive
    {
        bytes32 txHash = _getTxHash(_stakeData.txId, _stakeData.inputAddress);
        require(transactionHashToPChainStakingData[txHash].owner == address(0), "transaction already mirrored");
        require(_stakeData.startTime <= block.timestamp, "staking not started yet");
        require(_stakeData.endTime > block.timestamp, "staking already ended");
        address cChainAddress = addressBinder.pAddressToCAddress(_stakeData.inputAddress);
        require(cChainAddress != address(0), "unknown staking address");
        require(verifier.verifyStake(_stakeData, _merkleProof), "staking data invalid");

        PChainStakingData memory pChainStakingData =
            PChainStakingData(cChainAddress, _stakeData.nodeId, _stakeData.weight);
        transactionHashToPChainStakingData[txHash] = pChainStakingData;
        endTimeToTransactionHashList[_stakeData.endTime].push(txHash);
        _increaseStakeAmount(pChainStakingData, txHash, _stakeData.txId);
    }

    /**
     * Sets max number of updates (stake ends) per block (a daemonize call).
     * @param _maxUpdatesPerBlock Max number of updates (stake ends) per block
     * @dev Only governance can call this.
     */
    function setMaxUpdatesPerBlock(uint256 _maxUpdatesPerBlock) external onlyGovernance {
        maxUpdatesPerBlock = _maxUpdatesPerBlock;
        emit MaxUpdatesPerBlockSet(_maxUpdatesPerBlock);
    }

    /**
     * Revokes stake in case of invalid stakes - voting should be reset first,
     * so that Merkle root is not valid and it cannot be used for mirroring again.
     * @param _txId P-chain stake transaction id.
     * @param _inputAddress P-chain address that opened stake.
     * @param _endTime Time when stake ends, in seconds from UNIX epoch.
     * @param _endTimeTxHashIndex Index of `txHash = keccak256(abi.encode(_txId, _inputAddress))`
     *                            in the `endTimeToTransactionHashList[_endTime]` list.
     * @dev Only governance can call this.
     */
    function revokeStake(
        bytes32 _txId,
        bytes20 _inputAddress,
        uint256 _endTime,
        uint256 _endTimeTxHashIndex)
        external
        onlyImmediateGovernance
    {
        bytes32 txHash = _getTxHash(_txId, _inputAddress);
        require(transactionHashToPChainStakingData[txHash].owner != address(0), "stake not mirrored");
        bytes32[] storage txHashList = endTimeToTransactionHashList[_endTime];
        uint256 length = txHashList.length;
        require(length > _endTimeTxHashIndex && txHashList[_endTimeTxHashIndex] == txHash, "wrong end time or index");
        if (length - 1 != _endTimeTxHashIndex) {  // length >= 1
            txHashList[_endTimeTxHashIndex] = txHashList[length - 1];
        }
        txHashList.pop();
        PChainStakingData memory stakingData = transactionHashToPChainStakingData[txHash];
        emit StakeRevoked(stakingData.owner, stakingData.nodeId, txHash, GWEI.mul(stakingData.weightGwei));
        _decreaseStakeAmount(stakingData, txHash);
        delete transactionHashToPChainStakingData[txHash];
    }

    /**
     * @inheritdoc IFlareDaemonize
     * @dev Only flare daemon can call this.
     */
    function switchToFallbackMode() external override onlyFlareDaemon returns (bool) {
        if (maxUpdatesPerBlock > 0) {
            maxUpdatesPerBlock = maxUpdatesPerBlock.mulDiv(4, 5);
            emit MaxUpdatesPerBlockSet(maxUpdatesPerBlock);
            return true;
        }
        return false;
    }

    /**
     * @inheritdoc IICleanable
     * @dev The method can be called only by `cleanupBlockNumberManager`.
     */
    function setCleanupBlockNumber(uint256 _blockNumber) external override {
        require(msg.sender == cleanupBlockNumberManager, "only cleanup block manager");
        _setCleanupBlockNumber(_blockNumber);
    }

    /**
     * @inheritdoc IICleanable
     * @dev Only governance can call this.
     */
    function setCleanerContract(address _cleanerContract) external override onlyGovernance {
        _setCleanerContract(_cleanerContract);
    }

    /**
     * @inheritdoc IICleanable
     */
    function cleanupBlockNumber() external view override returns (uint256) {
        return _cleanupBlockNumber();
    }

    /**
     * @inheritdoc IPChainStakeMirror
     */
    function isActiveStakeMirrored(
        bytes32 _txId,
        bytes20 _inputAddress
    )
        external view override returns(bool)
    {
        bytes32 txHash = _getTxHash(_txId, _inputAddress);
        return transactionHashToPChainStakingData[txHash].owner != address(0);
    }

    /**
     * Returns the list of transaction hashes of stakes that end at given `_endTime`.
     * @param _endTime Time when stakes end, in seconds from UNIX epoch.
     * @return List of transaction hashes - `keccak256(abi.encode(txId, inputAddress))`.
     */
    function getTransactionHashList(uint256 _endTime) external view returns (bytes32[] memory) {
        return endTimeToTransactionHashList[_endTime];
    }

    /**
     * @inheritdoc IFlareDaemonize
     */
    function getContractName() external pure override returns (string memory) {
        return "PChainStakeMirror";
    }

    /**
     * @inheritdoc IPChainStakeMirror
     */
    function totalSupply() public view override returns(uint256) {
        return CheckPointable.totalSupplyAt(block.number);
    }

    /**
     * @inheritdoc IPChainStakeMirror
     */
    function balanceOf(address _owner) public view override returns (uint256) {
        return CheckPointable.balanceOfAt(_owner, block.number);
    }

    /**
     * @inheritdoc IPChainStakeMirror
     */
    function totalSupplyAt(
        uint256 _blockNumber
    )
        public view
        override(IPChainStakeMirror, CheckPointable)
        returns(uint256)
    {
        return CheckPointable.totalSupplyAt(_blockNumber);
    }

    /**
     * @inheritdoc IPChainStakeMirror
     */
    function balanceOfAt(
        address _owner,
        uint256 _blockNumber
    )
        public view
        override(IPChainStakeMirror, CheckPointable)
        returns (uint256)
    {
        return CheckPointable.balanceOfAt(_owner, _blockNumber);
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        addressBinder = IAddressBinder(
            _getContractAddress(_contractNameHashes, _contractAddresses, "AddressBinder"));
        cleanupBlockNumberManager =
            _getContractAddress(_contractNameHashes, _contractAddresses, "CleanupBlockNumberManager");
        governanceVotePower = IIGovernanceVotePower(
            _getContractAddress(_contractNameHashes, _contractAddresses, "GovernanceVotePower"));
        verifier = IIPChainStakeMirrorVerifier(
            _getContractAddress(_contractNameHashes, _contractAddresses, "PChainStakeMirrorVerifier"));
    }

    /**
     * Increase balance for owner and add vote power to nodeId.
     */
    function _increaseStakeAmount(PChainStakingData memory _data, bytes32 _txHash, bytes32 _txId) internal {
        uint256 amountWei = GWEI.mul(_data.weightGwei);
        _mintForAtNow(_data.owner, amountWei); // increase balance
        _increaseVotePower(_data.owner, _data.nodeId, amountWei);

        // update governance vote powers
        governanceVotePower.updateAtTokenTransfer(address(0), _data.owner, 0, 0, amountWei);

        emit StakeConfirmed(_data.owner, _data.nodeId, _txHash, amountWei, _txId);
    }

    /**
     * Decrease balance for owner and remove vote power from nodeId.
     */
    function _decreaseStakeAmount(PChainStakingData memory _data, bytes32 _txHash) internal {
        uint256 amountWei = GWEI.mul(_data.weightGwei);
        _burnForAtNow(_data.owner, amountWei); // decrease balance
        _decreaseVotePower(_data.owner, _data.nodeId, amountWei);

        // update governance vote powers
        governanceVotePower.updateAtTokenTransfer(_data.owner, address(0), 0, 0, amountWei);

        emit StakeEnded(_data.owner, _data.nodeId, _txHash, amountWei);
    }

    /**
     * unique tx hash is combination of transaction id and input address as
     * staking can be done from multiple P-chain addresses in one transaction
     */
    function _getTxHash(
        bytes32 _txId,
        bytes20 _inputAddress
    )
        internal pure returns(bytes32)
    {
        return keccak256(abi.encode(_txId, _inputAddress));
    }
}


// File contracts/utils/implementation/BytesLib.sol

/*
 * @title Solidity Bytes Arrays Utils
 * @author Gonçalo Sá <goncalo.sa@consensys.net>
 *
 * @dev Bytes tightly packed arrays utility library for ethereum contracts written in Solidity.
 *      The library lets you concatenate, slice and type cast bytes arrays both in memory and storage.
 */


library BytesLib {

    //solhint-disable no-inline-assembly
    function concat(
        bytes memory _preBytes,
        bytes memory _postBytes
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory tempBytes;
        assembly {
            // Get a location of some free memory and store it in tempBytes as
            // Solidity does for memory variables.
            tempBytes := mload(0x40)

            // Store the length of the first bytes array at the beginning of
            // the memory for tempBytes.
            let length := mload(_preBytes)
            mstore(tempBytes, length)

            // Maintain a memory counter for the current write location in the
            // temp bytes array by adding the 32 bytes for the array length to
            // the starting location.
            let mc := add(tempBytes, 0x20)
            // Stop copying when the memory counter reaches the length of the
            // first bytes array.
            let end := add(mc, length)

            for {
                // Initialize a copy counter to the start of the _preBytes data,
                // 32 bytes into its memory.
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                // Increase both counters by 32 bytes each iteration.
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                // Write the _preBytes data into the tempBytes memory 32 bytes
                // at a time.
                mstore(mc, mload(cc))
            }

            // Add the length of _postBytes to the current length of tempBytes
            // and store it as the new length in the first 32 bytes of the
            // tempBytes memory.
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))

            // Move the memory counter back from a multiple of 0x20 to the
            // actual end of the _preBytes data.
            mc := end
            // Stop copying when the memory counter reaches the new combined
            // length of the arrays.
            end := add(mc, length)

            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }

            // Update the free-memory pointer by padding our last write location
            // to 32 bytes: add 31 bytes to the end of tempBytes to move to the
            // next 32 byte block, then round down to the nearest multiple of
            // 32. If the sum of the length of the two arrays is zero then add
            // one before rounding down to leave a blank 32 bytes (the length block with 0).
            mstore(0x40, and(
              add(add(end, iszero(add(length, mload(_preBytes)))), 31),
              not(31) // Round down to the nearest 32 bytes.
            ))
        }

        return tempBytes;
    }

    function toBytes32(bytes memory _bytes, uint256 _start) internal pure returns (bytes32) {
        require(_bytes.length >= _start + 32, "toBytes32_outOfBounds");
        bytes32 tempBytes32;

        assembly {
            tempBytes32 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes32;
    }
}


// File contracts/staking/implementation/AddressBinder.sol



/**
 * Contract used to register P-chain and C-chain address pairs.
 */
contract AddressBinder is IAddressBinder {

    /**
     * @inheritdoc IAddressBinder
     */
    mapping(bytes20 => address) public override pAddressToCAddress;
    /**
     * @inheritdoc IAddressBinder
     */
    mapping(address => bytes20) public override cAddressToPAddress;

    uint256 constant private P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    /**
     * @inheritdoc IAddressBinder
     */
    // register validator/delegator (self-bonding/delegating) P-chain and C-chain addresses
    function registerAddresses(bytes calldata _publicKey, bytes20 _pAddress, address _cAddress) external override {
        require(_pAddress == _publicKeyToPAddress(_publicKey), "p chain address doesn't match public key");
        require(_cAddress == _publicKeyToCAddress(_publicKey), "c chain address doesn't match public key");
        pAddressToCAddress[_pAddress] = _cAddress;
        cAddressToPAddress[_cAddress] = _pAddress;
        emit AddressesRegistered(_publicKey, _pAddress, _cAddress);
    }

    /**
     * @inheritdoc IAddressBinder
     */
    function registerPublicKey(
        bytes calldata _publicKey
    )
        external override
        returns(bytes20 _pAddress, address _cAddress)
    {
        _pAddress = _publicKeyToPAddress(_publicKey);
        _cAddress = _publicKeyToCAddress(_publicKey);
        pAddressToCAddress[_pAddress] = _cAddress;
        cAddressToPAddress[_cAddress] = _pAddress;
        emit AddressesRegistered(_publicKey, _pAddress, _cAddress);
    }


    function _publicKeyToCAddress(
        bytes calldata publicKey
    )
        internal pure
        returns (address)
    {
        (uint256 x, uint256 y) = _extractPublicKeyPair(publicKey);
        uint256[2] memory publicKeyPair = [x, y];
        bytes32 hash = keccak256(abi.encodePacked(publicKeyPair));
        return address(uint160(uint256(hash)));
    }

    function _publicKeyToPAddress(
        bytes calldata publicKey
    )
        internal pure
        returns (bytes20)
    {
        (uint256 x, uint256 y) = _extractPublicKeyPair(publicKey);
        bytes memory compressedPublicKey = _compressPublicKey(x, y);
        bytes32 sha = sha256(abi.encodePacked(compressedPublicKey));
        return ripemd160(abi.encodePacked(sha));
    }


    ///// helper methods
    function _extractPublicKeyPair(
        bytes calldata encodedPublicKey
    )
        internal pure
        returns (uint256, uint256)
    {
        bytes1 prefix = encodedPublicKey[0];
        if (encodedPublicKey.length == 64) {
            // ethereum specific public key encoding
            return (
                uint256(BytesLib.toBytes32(encodedPublicKey, 0)),
                uint256(BytesLib.toBytes32(encodedPublicKey, 32)));
        } else if (encodedPublicKey.length == 65 && prefix == bytes1(0x04)) {
                return (
                    uint256(BytesLib.toBytes32(encodedPublicKey, 1)),
                    uint256(BytesLib.toBytes32(encodedPublicKey, 33))
                );
        } else if (encodedPublicKey.length == 33) {
                uint256 x = uint256(BytesLib.toBytes32(encodedPublicKey, 1));
                // Tonelli–Shanks algorithm for calculating square root modulo prime of x^3 + 7
                uint256 y = _powmod(mulmod(x, mulmod(x, x, P), P) + 7, (P + 1) / 4, P);
                if (prefix == bytes1(0x02)) {
                    return (x, (y % 2 == 0) ? y : P - y);
                } else if (prefix == bytes1(0x03)) {
                    return (x, (y % 2 == 0) ? P - y : y);
                }
        }
        revert("wrong format of public key");
    }

    function _compressPublicKey(uint256 x, uint256 y) internal pure returns (bytes memory) {
        return BytesLib.concat(_compressedPublicKeyBytePrefix(y % 2 == 0), abi.encodePacked(bytes32(x)));
    }

    function _compressedPublicKeyBytePrefix(bool evenY) internal pure returns (bytes memory) {
        return abi.encodePacked(evenY ? bytes1(0x02) : bytes1(0x03));
    }

    function _powmod(uint256 x, uint256 n, uint256 p) private pure returns (uint256) {
        uint256 result = 1;
        while (n > 0) {
            if (n & 1 == 1) {
                result = mulmod(result, x, p);
            }
            x = mulmod(x, x, p);
            n >>= 1;
        }
        return result;
    }

}


// File contracts/genesis/mock/TestableFlareDaemon.sol


contract TestableFlareDaemon is FlareDaemon {
    // allow testable flare daemon to receive funds
    receive() external payable {
        // do nothing - just like original FlareDaemon, which receives funds silently
    }
    
    /**
     * Testable version of trigger - no check for message origin.
     */
    function trigger() external override inflationSet returns (uint256 _toMintWei) {
        return triggerInternal();
    }
}


// File contracts/genesis/interface/IFtsoGenesis.sol



/**
 * Portion of the IFtso interface that is available to contracts deployed at genesis.
 */
interface IFtsoGenesis {

    /**
     * Reveals the price submitted by a voter on a specific epoch.
     * The hash of _price and _random must be equal to the submitted hash
     * @param _voter Voter address.
     * @param _epochId ID of the epoch in which the price hash was submitted.
     * @param _price Submitted price.
     * @param _voterWNatVP Voter's vote power in WNat units.
     */
    function revealPriceSubmitter(
        address _voter,
        uint256 _epochId,
        uint256 _price,
        uint256 _voterWNatVP
    ) external;

    /**
     * Get and cache the vote power of a voter on a specific epoch, in WNat units.
     * @param _voter Voter address.
     * @param _epochId ID of the epoch in which the price hash was submitted.
     * @return Voter's vote power in WNat units.
     */
    function wNatVotePowerCached(address _voter, uint256 _epochId) external returns (uint256);
}


// File contracts/userInterfaces/IFtso.sol


/**
 * Interface for each of the FTSO contracts that handles an asset.
 * Read the [FTSO documentation page](https://docs.flare.network/tech/ftso/)
 * for general information about the FTSO system.
 */
interface IFtso {
    /**
     * How did a price epoch finalize.
     *
     * * `NOT_FINALIZED`: The epoch has not been finalized yet. This is the initial state.
     * * `WEIGHTED_MEDIAN`: The median was used to calculate the final price.
     *     This is the most common state in normal operation.
     * * `TRUSTED_ADDRESSES`: Due to low turnout, the final price was calculated using only
     *     the median of trusted addresses.
     * * `PREVIOUS_PRICE_COPIED`: Due to low turnout and absence of votes from trusted addresses,
     *     the final price was copied from the previous epoch.
     * * `TRUSTED_ADDRESSES_EXCEPTION`: Due to an exception, the final price was calculated
     *     using only the median of trusted addresses.
     * * `PREVIOUS_PRICE_COPIED_EXCEPTION`: Due to an exception, the final price was copied
     *     from the previous epoch.
     */
    enum PriceFinalizationType {
        NOT_FINALIZED,
        WEIGHTED_MEDIAN,
        TRUSTED_ADDRESSES,
        PREVIOUS_PRICE_COPIED,
        TRUSTED_ADDRESSES_EXCEPTION,
        PREVIOUS_PRICE_COPIED_EXCEPTION
    }

    /**
     * A voter has revealed its price.
     * @param voter The voter.
     * @param epochId The ID of the epoch for which the price has been revealed.
     * @param price The revealed price.
     * @param timestamp Timestamp of the block where the reveal happened.
     * @param votePowerNat Vote power of the voter in this epoch. This includes the
     * vote power derived from its WNat holdings and the delegations.
     * @param votePowerAsset _Unused_.
     */
    event PriceRevealed(
        address indexed voter, uint256 indexed epochId, uint256 price, uint256 timestamp,
        uint256 votePowerNat, uint256 votePowerAsset
    );

    /**
     * An epoch has ended and the asset price is available.
     * @param epochId The ID of the epoch that has just ended.
     * @param price The asset's price for that epoch.
     * @param rewardedFtso Whether the next 4 parameters contain data.
     * @param lowIQRRewardPrice Lowest price in the primary (inter-quartile) reward band.
     * @param highIQRRewardPrice Highest price in the primary (inter-quartile) reward band.
     * @param lowElasticBandRewardPrice Lowest price in the secondary (elastic) reward band.
     * @param highElasticBandRewardPrice Highest price in the secondary (elastic) reward band.
     * @param finalizationType Reason for the finalization of the epoch.
     * @param timestamp Timestamp of the block where the price has been finalized.
     */
    event PriceFinalized(
        uint256 indexed epochId, uint256 price, bool rewardedFtso,
        uint256 lowIQRRewardPrice, uint256 highIQRRewardPrice,
        uint256 lowElasticBandRewardPrice, uint256 highElasticBandRewardPrice,
        PriceFinalizationType finalizationType, uint256 timestamp
    );

    /**
     * All necessary parameters have been set for an epoch and prices can start being _revealed_.
     * Note that prices can already be _submitted_ immediately after the previous price epoch submit end time is over.
     *
     * This event is not emitted in fallback mode (see `getPriceEpochData`).
     * @param epochId The ID of the epoch that has just started.
     * @param endTime Deadline to submit prices, in seconds since UNIX epoch.
     * @param timestamp Current on-chain timestamp.
     */
    event PriceEpochInitializedOnFtso(
        uint256 indexed epochId, uint256 endTime, uint256 timestamp
    );

    /**
     * Not enough votes were received for this asset during a price epoch that has just ended.
     * @param epochId The ID of the epoch.
     * @param natTurnout Total received vote power, as a percentage of the circulating supply in BIPS.
     * @param lowNatTurnoutThresholdBIPS Minimum required vote power, as a percentage
     * of the circulating supply in BIPS.
     * The fact that this number is higher than `natTurnout` is what triggered this event.
     * @param timestamp Timestamp of the block where the price epoch ended.
     */
    event LowTurnout(
        uint256 indexed epochId,
        uint256 natTurnout,
        uint256 lowNatTurnoutThresholdBIPS,
        uint256 timestamp
    );

    /**
     * Returns whether FTSO is active or not.
     */
    function active() external view returns (bool);

    /**
     * Returns the FTSO symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * Returns the current epoch ID.
     * @return Currently running epoch ID. IDs are consecutive numbers starting from zero.
     */
    function getCurrentEpochId() external view returns (uint256);

    /**
     * Returns the ID of the epoch that was opened for price submission at the specified timestamp.
     * @param _timestamp Queried timestamp in seconds from UNIX epoch.
     * @return Epoch ID corresponding to that timestamp. IDs are consecutive numbers starting from zero.
     */
    function getEpochId(uint256 _timestamp) external view returns (uint256);

    /**
     * Returns the random number used in a specific past epoch, obtained from the random numbers
     * provided by all data providers along with their data submissions.
     * @param _epochId ID of the queried epoch.
     * Current epoch cannot be queried, and the previous epoch is constantly updated
     * as data providers reveal their prices and random numbers.
     * Only the last 50 epochs can be queried and there is no bounds checking
     * for this parameter. Out-of-bounds queries return undefined values.

     * @return The random number used in that epoch.
     */
    function getRandom(uint256 _epochId) external view returns (uint256);

    /**
     * Returns agreed asset price in the specified epoch.
     * @param _epochId ID of the epoch.
     * Only the last 200 epochs can be queried. Out-of-bounds queries revert.
     * @return Price in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     */
    function getEpochPrice(uint256 _epochId) external view returns (uint256);

    /**
     * Returns current epoch data.
     * Intervals are open on the right: End times are not included.
     * @return _epochId Current epoch ID.
     * @return _epochSubmitEndTime End time of the price submission window in seconds from UNIX epoch.
     * @return _epochRevealEndTime End time of the price reveal window in seconds from UNIX epoch.
     * @return _votePowerBlock Vote power block for the current epoch.
     * @return _fallbackMode Whether the current epoch is in fallback mode.
     * Only votes from trusted addresses are used in this mode.
     */
    function getPriceEpochData() external view returns (
        uint256 _epochId,
        uint256 _epochSubmitEndTime,
        uint256 _epochRevealEndTime,
        uint256 _votePowerBlock,
        bool _fallbackMode
    );

    /**
     * Returns current epoch's configuration.
     * @return _firstEpochStartTs First epoch start timestamp in seconds from UNIX epoch.
     * @return _submitPeriodSeconds Submit period in seconds.
     * @return _revealPeriodSeconds Reveal period in seconds.
     */
    function getPriceEpochConfiguration() external view returns (
        uint256 _firstEpochStartTs,
        uint256 _submitPeriodSeconds,
        uint256 _revealPeriodSeconds
    );

    /**
     * Returns asset price submitted by a voter in the specified epoch.
     * @param _epochId ID of the epoch being queried.
     * Only the last 200 epochs can be queried. Out-of-bounds queries revert.
     * @param _voter Address of the voter being queried.
     * @return Price in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     */
    function getEpochPriceForVoter(uint256 _epochId, address _voter) external view returns (uint256);

    /**
     * Returns the current asset price.
     * @return _price Price in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     * @return _timestamp Time when price was updated for the last time,
     * in seconds from UNIX epoch.
     */
    function getCurrentPrice() external view returns (uint256 _price, uint256 _timestamp);

    /**
     * Returns current asset price and number of decimals.
     * @return _price Price in USD multiplied by 10^`_assetPriceUsdDecimals`.
     * @return _timestamp Time when price was updated for the last time,
     * in seconds from UNIX epoch.
     * @return _assetPriceUsdDecimals Number of decimals used to return the USD price.
     */
    function getCurrentPriceWithDecimals() external view returns (
        uint256 _price,
        uint256 _timestamp,
        uint256 _assetPriceUsdDecimals
    );

    /**
     * Returns current asset price calculated only using input from trusted providers.
     * @return _price Price in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     * @return _timestamp Time when price was updated for the last time,
     * in seconds from UNIX epoch.
     */
    function getCurrentPriceFromTrustedProviders() external view returns (uint256 _price, uint256 _timestamp);

    /**
     * Returns current asset price calculated only using input from trusted providers and number of decimals.
     * @return _price Price in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     * @return _timestamp Time when price was updated for the last time,
     * in seconds from UNIX epoch.
     * @return _assetPriceUsdDecimals Number of decimals used to return the USD price.
     */
    function getCurrentPriceWithDecimalsFromTrustedProviders() external view returns (
        uint256 _price,
        uint256 _timestamp,
        uint256 _assetPriceUsdDecimals
    );

    /**
     * Returns asset's current price details.
     * All timestamps are in seconds from UNIX epoch.
     * @return _price Price in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     * @return _priceTimestamp Time when price was updated for the last time.
     * @return _priceFinalizationType Finalization type when price was updated for the last time.
     * @return _lastPriceEpochFinalizationTimestamp Time when last price epoch was finalized.
     * @return _lastPriceEpochFinalizationType Finalization type of last finalized price epoch.
     */
    function getCurrentPriceDetails() external view returns (
        uint256 _price,
        uint256 _priceTimestamp,
        PriceFinalizationType _priceFinalizationType,
        uint256 _lastPriceEpochFinalizationTimestamp,
        PriceFinalizationType _lastPriceEpochFinalizationType
    );

    /**
     * Returns the random number for the previous price epoch, obtained from the random numbers
     * provided by all data providers along with their data submissions.
     */
    function getCurrentRandom() external view returns (uint256);
}


// File contracts/ftso/interface/IIFtso.sol




/**
 * Internal interface for each of the FTSO contracts that handles an asset.
 * Read the [FTSO documentation page](https://docs.flare.network/tech/ftso/)
 * for general information about the FTSO system.
 */
interface IIFtso is IFtso, IFtsoGenesis {

    /**
     * Computes epoch price based on gathered votes.
     *
     * * If the price reveal window for the epoch has ended, finalize the epoch.
     * * Iterate list of price submissions.
     * * Find weighted median.
     * * Find adjacent 50% of price submissions.
     * * Allocate rewards for price submissions.
     * @param _epochId ID of the epoch to finalize.
     * @param _returnRewardData Parameter that determines if the reward data is returned.
     * @return _eligibleAddresses List of addresses eligible for reward.
     * @return _natWeights List of native token weights corresponding to the eligible addresses.
     * @return _totalNatWeight Sum of weights in `_natWeights`.
     */
    function finalizePriceEpoch(uint256 _epochId, bool _returnRewardData) external
        returns(
            address[] memory _eligibleAddresses,
            uint256[] memory _natWeights,
            uint256 _totalNatWeight
        );

    /**
     * Forces finalization of a price epoch, calculating the median price from trusted addresses only.
     *
     * Used as a fallback method, for example, due to an unexpected error during normal epoch finalization or
     * because the `ftsoManager` enabled the fallback mode.
     * @param _epochId ID of the epoch to finalize.
     */
    function fallbackFinalizePriceEpoch(uint256 _epochId) external;

    /**
     * Forces finalization of a price epoch by copying the price from the previous epoch.
     *
     * Used as a fallback method if `fallbackFinalizePriceEpoch` fails due to an exception.
     * @param _epochId ID of the epoch to finalize.
     */
    function forceFinalizePriceEpoch(uint256 _epochId) external;

    /**
     * Initializes FTSO immutable settings and activates the contract.
     * @param _firstEpochStartTs Timestamp of the first epoch in seconds from UNIX epoch.
     * @param _submitPeriodSeconds Duration of epoch submission window in seconds.
     * @param _revealPeriodSeconds Duration of epoch reveal window in seconds.
     */
    function activateFtso(
        uint256 _firstEpochStartTs,
        uint256 _submitPeriodSeconds,
        uint256 _revealPeriodSeconds
    ) external;

    /**
     * Deactivates the contract.
     */
    function deactivateFtso() external;

    /**
     * Updates initial asset price when the contract is not active yet.
     */
    function updateInitialPrice(uint256 _initialPriceUSD, uint256 _initialPriceTimestamp) external;

    /**
     * Sets configurable settings related to epochs.
     * @param _maxVotePowerNatThresholdFraction High threshold for native token vote power per voter.
     * @param _maxVotePowerAssetThresholdFraction High threshold for asset vote power per voter.
     * @param _lowAssetUSDThreshold Threshold for low asset vote power (in scaled USD).
     * @param _highAssetUSDThreshold Threshold for high asset vote power (in scaled USD).
     * @param _highAssetTurnoutThresholdBIPS Threshold for high asset turnout (in BIPS).
     * @param _lowNatTurnoutThresholdBIPS Threshold for low nat turnout (in BIPS).
     * @param _elasticBandRewardBIPS Percentage of the rewards (in BIPS) that go to the [secondary
     * reward band](https://docs.flare.network/tech/ftso/#rewards). The rest go to the primary reward band.
     * @param _elasticBandWidthPPM Width of the secondary reward band, in parts-per-milion of the median.
     * @param _trustedAddresses Trusted voters that will be used if low voter turnout is detected.
     */
    function configureEpochs(
        uint256 _maxVotePowerNatThresholdFraction,
        uint256 _maxVotePowerAssetThresholdFraction,
        uint256 _lowAssetUSDThreshold,
        uint256 _highAssetUSDThreshold,
        uint256 _highAssetTurnoutThresholdBIPS,
        uint256 _lowNatTurnoutThresholdBIPS,
        uint256 _elasticBandRewardBIPS,
        uint256 _elasticBandWidthPPM,
        address[] memory _trustedAddresses
    ) external;

    /**
     * Sets asset for FTSO to operate as single-asset oracle.
     * @param _asset Address of the `IIVPToken` contract that will be the asset tracked by this FTSO.
     */
    function setAsset(IIVPToken _asset) external;

    /**
     * Sets an array of FTSOs for FTSO to operate as multi-asset oracle.
     * FTSOs implicitly determine the FTSO assets.
     * @param _assetFtsos Array of FTSOs.
     */
    function setAssetFtsos(IIFtso[] memory _assetFtsos) external;

    /**
     * Sets the current vote power block.
     * Current vote power block will update per reward epoch.
     * The FTSO doesn't have notion of reward epochs.
     * @param _blockNumber Vote power block.
     */
    function setVotePowerBlock(uint256 _blockNumber) external;

    /**
     * Initializes current epoch instance for reveal.
     * @param _circulatingSupplyNat Epoch native token circulating supply.
     * @param _fallbackMode Whether the current epoch is in fallback mode.
     */
    function initializeCurrentEpochStateForReveal(uint256 _circulatingSupplyNat, bool _fallbackMode) external;

    /**
     * Returns the FTSO manager's address.
     * @return Address of the FTSO manager contract.
     */
    function ftsoManager() external view returns (address);

    /**
     * Returns the FTSO asset.
     * @return Address of the `IIVPToken` tracked by this FTSO.
     * `null` in case of multi-asset FTSO.
     */
    function getAsset() external view returns (IIVPToken);

    /**
     * Returns the asset FTSOs.
     * @return Array of `IIFtso` contract addresses.
     * `null` in case of single-asset FTSO.
     */
    function getAssetFtsos() external view returns (IIFtso[] memory);

    /**
     * Returns current configuration of epoch state.
     * @return _maxVotePowerNatThresholdFraction High threshold for native token vote power per voter.
     * @return _maxVotePowerAssetThresholdFraction High threshold for asset vote power per voter.
     * @return _lowAssetUSDThreshold Threshold for low asset vote power (in scaled USD).
     * @return _highAssetUSDThreshold Threshold for high asset vote power (in scaled USD).
     * @return _highAssetTurnoutThresholdBIPS Threshold for high asset turnout (in BIPS).
     * @return _lowNatTurnoutThresholdBIPS Threshold for low nat turnout (in BIPS).
     * @return _elasticBandRewardBIPS Percentage of the rewards (in BIPS) that go to the [secondary
     * reward band](https://docs.flare.network/tech/ftso/#rewards). The rest go to the primary reward band.
     * @return _elasticBandWidthPPM Width of the secondary reward band, in parts-per-milion of the median.
     * @return _trustedAddresses Trusted voters that will be used if low voter turnout is detected.
     */
    function epochsConfiguration() external view
        returns (
            uint256 _maxVotePowerNatThresholdFraction,
            uint256 _maxVotePowerAssetThresholdFraction,
            uint256 _lowAssetUSDThreshold,
            uint256 _highAssetUSDThreshold,
            uint256 _highAssetTurnoutThresholdBIPS,
            uint256 _lowNatTurnoutThresholdBIPS,
            uint256 _elasticBandRewardBIPS,
            uint256 _elasticBandWidthPPM,
            address[] memory _trustedAddresses
        );

    /**
     * Returns parameters necessary for replicating vote weighting (used in VoterWhitelister).
     * @return _assets The list of assets that are accounted in vote.
     * @return _assetMultipliers Weight multiplier of each asset in (multiasset) FTSO.
     * @return _totalVotePowerNat Total native token vote power at block.
     * @return _totalVotePowerAsset Total combined asset vote power at block.
     * @return _assetWeightRatio Ratio of combined asset vote power vs. native token vp (in BIPS).
     * @return _votePowerBlock Vote power block for the epoch.
     */
    function getVoteWeightingParameters() external view
        returns (
            IIVPToken[] memory _assets,
            uint256[] memory _assetMultipliers,
            uint256 _totalVotePowerNat,
            uint256 _totalVotePowerAsset,
            uint256 _assetWeightRatio,
            uint256 _votePowerBlock
        );

    /**
     * Address of the WNat contract.
     * @return Address of the WNat contract.
     */
    function wNat() external view returns (IIVPToken);
}


// File contracts/genesis/interface/IFtsoRegistryGenesis.sol


/**
 * Portion of the `IFtsoRegistry` interface that is available to contracts deployed at genesis.
 */
interface IFtsoRegistryGenesis {

    /**
     * Get the addresses of the active FTSOs at the given indices.
     * Reverts if any of the provided indices is non-existing or inactive.
     * @param _indices Array of FTSO indices to query.
     * @return _ftsos The array of FTSO addresses.
     */
    function getFtsos(uint256[] memory _indices) external view returns(IFtsoGenesis[] memory _ftsos);
}


// File contracts/userInterfaces/IFtsoRegistry.sol



/**
 * Interface for the `FtsoRegistry` contract.
 */
interface IFtsoRegistry is IFtsoRegistryGenesis {

    /**
     * Structure describing the price of an FTSO asset at a particular point in time.
     */
    struct PriceInfo {
        // Index of the asset.
        uint256 ftsoIndex;
        // Price of the asset in USD, multiplied by 10^`ASSET_PRICE_USD_DECIMALS`
        uint256 price;
        // Number of decimals used in the `price` field.
        uint256 decimals;
        // Timestamp for when this price was updated, in seconds since UNIX epoch.
        uint256 timestamp;
    }

    /**
     * Returns the address of the FTSO contract for a given index.
     * Reverts if unsupported index is passed.
     * @param _activeFtso The queried index.
     * @return _activeFtsoAddress FTSO contract address for the queried index.
     */

    function getFtso(uint256 _activeFtso) external view returns(IIFtso _activeFtsoAddress);
    /**
     * Returns the address of the FTSO contract for a given symbol.
     * Reverts if unsupported symbol is passed.
     * @param _symbol The queried symbol.
     * @return _activeFtsoAddress FTSO contract address for the queried symbol.
     */

    function getFtsoBySymbol(string memory _symbol) external view returns(IIFtso _activeFtsoAddress);
    /**
     * Returns the indices of the currently supported FTSOs.
     * Active FTSOs are ones that currently receive price feeds.
     * @return _supportedIndices Array of all active FTSO indices in increasing order.
     */
    function getSupportedIndices() external view returns(uint256[] memory _supportedIndices);

    /**
     * Returns the symbols of the currently supported FTSOs.
     * Active FTSOs are ones that currently receive price feeds.
     * @return _supportedSymbols Array of all active FTSO symbols in increasing order.
     */
    function getSupportedSymbols() external view returns(string[] memory _supportedSymbols);

    /**
     * Get array of all FTSO contracts for all supported asset indices.
     * The index of FTSO in returned array does not necessarily correspond to the asset's index.
     * Due to deletion, some indices might be unsupported.
     *
     * Use `getSupportedIndicesAndFtsos` to retrieve pairs of correct indices and FTSOs,
     * where possible "null" holes are readily apparent.
     * @return _ftsos Array of all supported FTSOs.
     */
    function getSupportedFtsos() external view returns(IIFtso[] memory _ftsos);

    /**
     * Returns the FTSO index corresponding to a given asset symbol.
     * Reverts if the symbol is not supported.
     * @param _symbol Symbol to query.
     * @return _assetIndex The corresponding asset index.
     */
    function getFtsoIndex(string memory _symbol) external view returns (uint256 _assetIndex);

    /**
     * Returns the asset symbol corresponding to a given FTSO index.
     * Reverts if the index is not supported.
     * @param _ftsoIndex Index to query.
     * @return _symbol The corresponding asset symbol.
     */
    function getFtsoSymbol(uint256 _ftsoIndex) external view returns (string memory _symbol);

    /**
     * Public view function to get the current price of a given active FTSO index.
     * Reverts if the index is not supported.
     * @param _ftsoIndex Index to query.
     * @return _price Current price of the asset in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     * @return _timestamp Timestamp for when this price was updated, in seconds since UNIX epoch.
     */
    function getCurrentPrice(uint256 _ftsoIndex) external view returns(uint256 _price, uint256 _timestamp);

    /**
     * Public view function to get the current price of a given active asset symbol.
     * Reverts if the symbol is not supported.
     * @param _symbol Symbol to query.
     * @return _price Current price of the asset in USD multiplied by 10^`ASSET_PRICE_USD_DECIMALS`.
     * @return _timestamp Timestamp for when this price was updated, in seconds since UNIX epoch.
     */
    function getCurrentPrice(string memory _symbol) external view returns(uint256 _price, uint256 _timestamp);

    /**
     * Public view function to get the current price and decimals of a given active FTSO index.
     * Reverts if the index is not supported.
     * @param _assetIndex Index to query.
     * @return _price Current price of the asset in USD multiplied by 10^`_assetPriceUsdDecimals`.
     * @return _timestamp Timestamp for when this price was updated, in seconds since UNIX epoch.
     * @return _assetPriceUsdDecimals Number of decimals used to return the `_price`.
     */
    function getCurrentPriceWithDecimals(uint256 _assetIndex) external view
        returns(uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals);

    /**
     * Public view function to get the current price and decimals of a given active asset symbol.
     * Reverts if the symbol is not supported.
     * @param _symbol Symbol to query.
     * @return _price Current price of the asset in USD multiplied by 10^`_assetPriceUsdDecimals`.
     * @return _timestamp Timestamp for when this price was updated, in seconds since UNIX epoch.
     * @return _assetPriceUsdDecimals Number of decimals used to return the `_price`.
     */
    function getCurrentPriceWithDecimals(string memory _symbol) external view
        returns(uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals);

    /**
     * Returns the current price of all supported assets.
     * @return Array of `PriceInfo` structures.
     */
    function getAllCurrentPrices() external view returns (PriceInfo[] memory);

    /**
     * Returns the current price of a list of indices.
     * Reverts if any of the indices is not supported.
     * @param _indices Array of indices to query.
     * @return Array of `PriceInfo` structures.
     */
    function getCurrentPricesByIndices(uint256[] memory _indices) external view returns (PriceInfo[] memory);

    /**
     * Returns the current price of a list of asset symbols.
     * Reverts if any of the symbols is not supported.
     * @param _symbols Array of symbols to query.
     * @return Array of `PriceInfo` structures.
     */
    function getCurrentPricesBySymbols(string[] memory _symbols) external view returns (PriceInfo[] memory);

    /**
     * Get all supported indices and corresponding FTSO addresses.
     * Active FTSOs are ones that currently receive price feeds.
     * @return _supportedIndices Array of all supported indices.
     * @return _ftsos Array of all supported FTSO addresses.
     */
    function getSupportedIndicesAndFtsos() external view
        returns(uint256[] memory _supportedIndices, IIFtso[] memory _ftsos);

    /**
     * Get all supported symbols and corresponding FTSO addresses.
     * Active FTSOs are ones that currently receive price feeds.
     * @return _supportedSymbols Array of all supported symbols.
     * @return _ftsos Array of all supported FTSO addresses.
     */
    function getSupportedSymbolsAndFtsos() external view
        returns(string[] memory _supportedSymbols, IIFtso[] memory _ftsos);

    /**
     * Get all supported indices and corresponding symbols.
     * Active FTSOs are ones that currently receive price feeds.
     * @return _supportedIndices Array of all supported indices.
     * @return _supportedSymbols Array of all supported symbols.
     */
    function getSupportedIndicesAndSymbols() external view
        returns(uint256[] memory _supportedIndices, string[] memory _supportedSymbols);

    /**
     * Get all supported indices, symbols, and corresponding FTSO addresses.
     * Active FTSOs are ones that currently receive price feeds.
     * @return _supportedIndices Array of all supported indices.
     * @return _supportedSymbols Array of all supported symbols.
     * @return _ftsos Array of all supported FTSO addresses.
     */
    function getSupportedIndicesSymbolsAndFtsos() external view
        returns(uint256[] memory _supportedIndices, string[] memory _supportedSymbols, IIFtso[] memory _ftsos);
}


// File contracts/utils/interface/IIFtsoRegistry.sol



/**
 * Internal interface for the `FtsoRegistry` contract.
 */
interface IIFtsoRegistry is IFtsoRegistry {

    /**
     * Add a new FTSO contract to the registry.
     * @param _ftsoContract New target FTSO contract.
     * @return The FTSO index assigned to the new asset.
     */
    function addFtso(IIFtso _ftsoContract) external returns(uint256);

    /**
     * Removes the FTSO and keeps part of the history.
     * Reverts if the provided address is not supported.
     *
     * From now on, the index this asset was using is "reserved" and cannot be used again.
     * It will not be returned in any list of currently supported assets.
     * @param _ftso Address of the FTSO contract to remove.
     */
    function removeFtso(IIFtso _ftso) external;
}


// File contracts/genesis/interface/IFtsoManagerGenesis.sol



/**
 * Portion of the `IFtsoManager` interface that is available to contracts deployed at genesis.
 */
interface IFtsoManagerGenesis {

    /**
     * Returns current price epoch ID.
     * @return _priceEpochId Currently running epoch ID. IDs are consecutive numbers starting from zero.
     */
    function getCurrentPriceEpochId() external view returns (uint256 _priceEpochId);

}


// File contracts/userInterfaces/IFtsoManager.sol



/**
 * Interface for the `FtsoManager` contract.
 */
interface IFtsoManager is IFtsoManagerGenesis {

    /**
     * Emitted when a new FTSO has been added or an existing one has been removed.
     * @param ftso Contract address of the FTSO.
     * @param add True if added, removed otherwise.
     */
    event FtsoAdded(IIFtso ftso, bool add);

    /**
     * Emitted when the fallback mode of the FTSO manager changes its state.
     * Fallback mode is a recovery mode, where only data from a trusted subset of FTSO
     * data providers is used to calculate the final price.
     *
     * The FTSO Manager enters the fallback mode when ALL FTSOs are in fallback mode.
     * @param fallbackMode New state of the FTSO Manager fallback mode.
     */
    event FallbackMode(bool fallbackMode);

    /**
     * Emitted when the fallback mode of an FTSO changes its state.
     * @param ftso Contract address of the FTSO.
     * @param fallbackMode New state of its fallback mode.
     */
    event FtsoFallbackMode(IIFtso ftso, bool fallbackMode);

    /**
     * Emitted when a [reward epoch](https://docs.flare.network/tech/ftso/#procedure-overview)
     * ends and rewards are available.
     * @param votepowerBlock The [vote power block](https://docs.flare.network/tech/ftso/#vote-power)
     * of the epoch.
     * @param startBlock The first block of the epoch.
     */
    event RewardEpochFinalized(uint256 votepowerBlock, uint256 startBlock);

    /**
     * Emitted when a [price epoch](https://docs.flare.network/tech/ftso/#procedure-overview) ends, this is,
     * after the reveal phase, when final prices are calculated.
     * @param chosenFtso Contract address of the FTSO asset that was randomly chosen to be
     * the basis for reward calculation. On this price epoch, rewards will be calculated based
     * on how close each data provider was to the median of all submitted prices FOR THIS FTSO.
     * @param rewardEpochId Reward epoch ID this price epoch belongs to.
     */
    event PriceEpochFinalized(address chosenFtso, uint256 rewardEpochId);

    /**
     * Unexpected failure while initializing a price epoch.
     * This should be a rare occurrence.
     * @param ftso Contract address of the FTSO where the failure happened.
     * @param epochId Epoch ID that failed initialization.
     */
    event InitializingCurrentEpochStateForRevealFailed(IIFtso ftso, uint256 epochId);

    /**
     * Unexpected failure while finalizing a price epoch.
     * This should be a rare occurrence.
     * @param ftso Contract address of the FTSO where the failure happened.
     * @param epochId Epoch ID of the failure.
     * @param failingType How was the epoch finalized.
     */
    event FinalizingPriceEpochFailed(IIFtso ftso, uint256 epochId, IFtso.PriceFinalizationType failingType);

    /**
     * Unexpected failure while distributing rewards.
     * This should be a rare occurrence.
     * @param ftso Contract address of the FTSO where the failure happened.
     * @param epochId Epoch ID of the failure.
     */
    event DistributingRewardsFailed(address ftso, uint256 epochId);

    /**
     * Unexpected failure while accruing unearned rewards.
     * This should be a rare occurrence.
     * @param epochId Epoch ID of the failure.
     */
    event AccruingUnearnedRewardsFailed(uint256 epochId);

    /**
     * Emitted when the requirement to provide good random numbers has changed.
     *
     * As part of [the FTSO protocol](https://docs.flare.network/tech/ftso/#data-submission-process),
     * data providers must submit a random number along with their price reveals.
     * When good random numbers are enforced, all providers that submit a hash must then
     * submit a reveal with a random number or they will be punished.
     * This is a measure against random number manipulation.
     * @param useGoodRandom Whether good random numbers are now enforced or not.
     * @param maxWaitForGoodRandomSeconds Max number of seconds to wait for a good random
     * number to be submitted.
     */
    event UseGoodRandomSet(bool useGoodRandom, uint256 maxWaitForGoodRandomSeconds);

    /**
     * Returns whether the FTSO Manager is active or not.
     * @return bool Active status.
     */
    function active() external view returns (bool);

    /**
     * Returns current reward epoch ID (the one currently running).
     * @return Reward epoch ID. A monotonically increasing integer.
     */
    function getCurrentRewardEpoch() external view returns (uint256);

    /**
     * Returns the [vote power block](https://docs.flare.network/tech/ftso/#vote-power)
     * that was used for a past reward epoch.
     * @param _rewardEpoch The queried reward epoch ID.
     * @return uint256 The block number of that reward epoch's vote power block.
     */
    function getRewardEpochVotePowerBlock(uint256 _rewardEpoch) external view returns (uint256);

    /**
     * Return reward epoch that will expire next, when a new reward epoch is initialized.
     *
     * Reward epochs older than 90 days expire, and any unclaimed rewards in them become
     * inaccessible.
     * @return uint256 Reward epoch ID.
     */
    function getRewardEpochToExpireNext() external view returns (uint256);

    /**
     * Returns timing information for the current price epoch.
     * All intervals are half-closed: end time is not included.
     * All timestamps are in seconds since UNIX epoch.
     *
     * See the [FTSO page](https://docs.flare.network/tech/ftso/#data-submission-process)
     * for information about the different submission phases.
     * @return _priceEpochId Price epoch ID.
     * @return _priceEpochStartTimestamp Beginning of the commit phase.
     * @return _priceEpochEndTimestamp End of the commit phase.
     * @return _priceEpochRevealEndTimestamp End of the reveal phase.
     * @return _currentTimestamp Current time.
     */
    function getCurrentPriceEpochData() external view
        returns (
            uint256 _priceEpochId,
            uint256 _priceEpochStartTimestamp,
            uint256 _priceEpochEndTimestamp,
            uint256 _priceEpochRevealEndTimestamp,
            uint256 _currentTimestamp
        );

    /**
     * Returns the list of currently active FTSOs.
     * @return _ftsos Array of contract addresses for the FTSOs.
     */
    function getFtsos() external view returns (IIFtso[] memory _ftsos);

    /**
     * Returns the current values for price epoch timing configuration.
     *
     * See the [FTSO page](https://docs.flare.network/tech/ftso/#data-submission-process)
     * for information about the different submission phases.
     * @return _firstPriceEpochStartTs Timestamp, in seconds since UNIX epoch, of the
     * first price epoch.
     * @return _priceEpochDurationSeconds Duration in seconds of the commit phase.
     * @return _revealEpochDurationSeconds Duration in seconds of the reveal phase.
     */
    function getPriceEpochConfiguration() external view
        returns (
            uint256 _firstPriceEpochStartTs,
            uint256 _priceEpochDurationSeconds,
            uint256 _revealEpochDurationSeconds
        );

    /**
     * Returns the current values for reward epoch timing configuration.
     *
     * See the [Reward epochs](https://docs.flare.network/tech/ftso/#vote-power) box.
     * @return _firstRewardEpochStartTs Timestamp, in seconds since UNIX epoch, of the
     * first reward epoch.
     * @return _rewardEpochDurationSeconds Duration in seconds of the reward epochs.
     */
    function getRewardEpochConfiguration() external view
        returns (
            uint256 _firstRewardEpochStartTs,
            uint256 _rewardEpochDurationSeconds
        );

    /**
     * Returns whether the FTSO Manager is currently in fallback mode.
     *
     * In this mode only submissions from trusted providers are used.
     * @return _fallbackMode True if fallback mode is enabled for the manager.
     * @return _ftsos Array of all currently active FTSO assets.
     * @return _ftsoInFallbackMode Boolean array indicating which FTSO assets are in
     * fallback mode.
     * If the FTSO Manager is in fallback mode then ALL FTSOs are in fallback mode.
     */
    function getFallbackMode() external view
        returns (
            bool _fallbackMode,
            IIFtso[] memory _ftsos,
            bool[] memory _ftsoInFallbackMode
        );
}


// File contracts/ftso/interface/IIFtsoManager.sol





/**
 * Internal interface for the `FtsoManager` contract.
 */
interface IIFtsoManager is IFtsoManager, IFlareDaemonize {

    /**
     * Information about a reward epoch.
     */
    struct RewardEpochData {
        uint256 votepowerBlock;
        uint256 startBlock;
        uint256 startTimestamp;
    }

    /// Unexpected failure. This should be a rare occurrence.
    event ClosingExpiredRewardEpochFailed(uint256 rewardEpoch);

    /// Unexpected failure. This should be a rare occurrence.
    event CleanupBlockNumberManagerFailedForBlock(uint256 blockNumber);

    /// Unexpected failure. This should be a rare occurrence.
    event UpdatingActiveValidatorsTriggerFailed(uint256 rewardEpoch);

    /// Unexpected failure. This should be a rare occurrence.
    event FtsoDeactivationFailed(IIFtso ftso);

    /// Unexpected failure. This should be a rare occurrence.
    event ChillingNonrevealingDataProvidersFailed();

    /**
     * Activates FTSO manager (daemonize() will run jobs).
     */
    function activate() external;

    /**
     * Set reward data to values from old ftso manager.
     * Can only be called before activation.
     * @param _nextRewardEpochToExpire See `getRewardEpochToExpireNext`.
     * @param _rewardEpochsLength See `getRewardEpochConfiguration`.
     * @param _currentRewardEpochEnds See `getCurrentRewardEpoch`.
     */
    function setInitialRewardData(
        uint256 _nextRewardEpochToExpire,
        uint256 _rewardEpochsLength,
        uint256 _currentRewardEpochEnds
    ) external;

    /**
     * Sets governance parameters for FTSOs
     * @param _updateTs Time, in seconds since UNIX epoch, when updated settings should be pushed to FTSOs.
     * @param _maxVotePowerNatThresholdFraction High threshold for native token vote power per voter.
     * @param _maxVotePowerAssetThresholdFraction High threshold for asset vote power per voter
     * @param _lowAssetUSDThreshold Threshold for low asset vote power (in scaled USD).
     * @param _highAssetUSDThreshold Threshold for high asset vote power (in scaled USD).
     * @param _highAssetTurnoutThresholdBIPS Threshold for high asset turnout (in BIPS).
     * @param _lowNatTurnoutThresholdBIPS Threshold for low nat turnout (in BIPS).
     * @param _elasticBandRewardBIPS Secondary reward band, where _elasticBandRewardBIPS goes to the
     * secondary band and 10000 - _elasticBandRewardBIPS to the primary (IQR) band.
     * @param _rewardExpiryOffsetSeconds Reward epochs closed earlier than
     * block.timestamp - _rewardExpiryOffsetSeconds expire.
     * @param _trustedAddresses Trusted addresses will be used as a fallback mechanism for setting the price.
     */
    function setGovernanceParameters(
        uint256 _updateTs,
        uint256 _maxVotePowerNatThresholdFraction,
        uint256 _maxVotePowerAssetThresholdFraction,
        uint256 _lowAssetUSDThreshold,
        uint256 _highAssetUSDThreshold,
        uint256 _highAssetTurnoutThresholdBIPS,
        uint256 _lowNatTurnoutThresholdBIPS,
        uint256 _elasticBandRewardBIPS,
        uint256 _rewardExpiryOffsetSeconds,
        address[] memory _trustedAddresses
    ) external;

    /**
     * Adds FTSO to the list of managed FTSOs, to support a new price pair.
     * All FTSOs in a multi-asset FTSO must be managed by the same FTSO manager.
     * @param _ftso FTSO contract address to add.
     */
    function addFtso(IIFtso _ftso) external;

    /**
     * Adds a list of FTSOs to the list of managed FTSOs, to support new price pairs.
     * All FTSOs in a multi-asset FTSO must be managed by the same FTSO manager.
     * @param _ftsos Array of FTSO contract addresses to add.
     */
    function addFtsosBulk(IIFtso[] memory _ftsos) external;

    /**
     * Removes an FTSO from the list of managed FTSOs.
     * Reverts if FTSO is used in a multi-asset FTSO.
     * Deactivates the `_ftso`.
     * @param _ftso FTSO contract address to remove.
     */
    function removeFtso(IIFtso _ftso) external;

    /**
     * Replaces one FTSO with another with the same symbol.
     * All FTSOs in a multi-asset FTSO must be managed by the same FTSO manager.
     * Deactivates the old FTSO.
     * @param _ftsoToAdd FTSO contract address to add.
     * An existing FTSO with the same symbol will be removed.
     * @param copyCurrentPrice When true, initializes the new FTSO with the
     * current price of the previous FTSO.
     * @param copyAssetOrAssetFtsos When true, initializes the new FTSO with the
     * current asset or asset FTSOs of the previous FTSO.
     */
    function replaceFtso(
        IIFtso _ftsoToAdd,
        bool copyCurrentPrice,
        bool copyAssetOrAssetFtsos
    ) external;

    /**
     * Replaces a list of FTSOs with other FTSOs with the same symbol.
     * All FTSOs in a multi-asset FTSO must be managed by the same FTSO manager.
     * Deactivates the old FTSOs.
     * @param _ftsosToAdd Array of FTSO contract addresses to add.
     * Every existing FTSO with the same symbols will be removed.
     * @param copyCurrentPrice When true, initializes the new FTSOs with the
     * current price of the previous FTSOs.
     * @param copyAssetOrAssetFtsos When true, initializes the new FTSOs with the
     * current asset or asset FTSOs of the previous FTSOs.
     */
    function replaceFtsosBulk(
        IIFtso[] memory _ftsosToAdd,
        bool copyCurrentPrice,
        bool copyAssetOrAssetFtsos
    ) external;

    /**
     * Sets the asset tracked by an FTSO.
     * @param _ftso The FTSO contract address.
     * @param _asset The `VPToken` contract address of the asset to track.
     */
    function setFtsoAsset(IIFtso _ftso, IIVPToken _asset) external;

    /**
     * Sets an array of FTSOs to be tracked by a multi-asset FTSO.
     * FTSOs implicitly determine the FTSO assets.
     * @param _ftso The multi-asset FTSO contract address.
     * @param _assetFtsos Array of FTSOs to be tracked.
     */
    function setFtsoAssetFtsos(IIFtso _ftso, IIFtso[] memory _assetFtsos) external;

    /**
     * Sets whether the FTSO Manager is currently in fallback mode.
     * In this mode only submissions from trusted providers are used.
     * @param _fallbackMode True if fallback mode is enabled.
     */
    function setFallbackMode(bool _fallbackMode) external;

    /**
     * Sets whether an FTSO is currently in fallback mode.
     * In this mode only submissions from trusted providers are used.
     * @param _ftso The FTSO contract address.
     * @param _fallbackMode Fallback mode.
     */
    function setFtsoFallbackMode(IIFtso _ftso, bool _fallbackMode) external;

    /**
     * Returns whether an FTSO has been initialized.
     * @return bool Initialization state.
     */
    function notInitializedFtsos(IIFtso) external view returns (bool);

    /**
     * Returns data regarding a specific reward epoch ID.
     * @param _rewardEpochId Epoch ID.
     * @return RewardEpochData Its associated data.
     */
    function getRewardEpochData(uint256 _rewardEpochId) external view returns (RewardEpochData memory);

    /**
     * Returns when the current reward epoch finishes.
     * @return uint256 Time in seconds since the UNIX epoch when the current reward
     * epoch will finish.
     */
    function currentRewardEpochEnds() external view returns (uint256);

    /**
     * Returns information regarding the currently unprocessed price epoch.
     * This epoch is not necessarily the last one, in case the network halts for some
     * time due to validator node problems, for example.
     * @return _lastUnprocessedPriceEpoch ID of the price epoch that is currently waiting
     * finalization.
     * @return _lastUnprocessedPriceEpochRevealEnds When that price epoch can be finalized,
     * in seconds since UNIX epoch.
     * @return _lastUnprocessedPriceEpochInitialized Whether this price epoch has been
     * already initialized and therefore it must be finalized before the corresponding
     * reward epoch can be finalized.
     */
    function getLastUnprocessedPriceEpochData() external view
        returns (
            uint256 _lastUnprocessedPriceEpoch,
            uint256 _lastUnprocessedPriceEpochRevealEnds,
            bool _lastUnprocessedPriceEpochInitialized
        );

    /**
     * Time when the current reward epoch started.
     * @return uint256 Timestamp, in seconds since UNIX epoch.
     */
    function rewardEpochsStartTs() external view returns (uint256);

    /**
     * Currently configured reward epoch duration.
     * @return uint256 Reward epoch duration, in seconds.
     */
    function rewardEpochDurationSeconds() external view returns (uint256);

    /**
     * Returns information about a reward epoch.
     * @param _rewardEpochId The epoch ID to query.
     * @return _votepowerBlock The [vote power block](https://docs.flare.network/tech/ftso/#vote-power)
     * of the epoch.
     * @return _startBlock The first block of the epoch.
     * @return _startTimestamp Timestamp of the epoch start, in seconds since UNIX epoch.
     */
    function rewardEpochs(uint256 _rewardEpochId) external view
        returns (
            uint256 _votepowerBlock,
            uint256 _startBlock,
            uint256 _startTimestamp
        );

    /**
     * Returns the currently configured reward expiration time.
     * @return uint256 Unclaimed rewards accrued in reward epochs more than this
     * amount of seconds in the past expire and become inaccessible.
     */
    function getRewardExpiryOffsetSeconds() external view returns (uint256);

    /**
     * Returns the secondary band's width in PPM (parts-per-million) of the median value,
     * for a given FTSO.
     * @param _ftso The queried FTSO contract address.
     * @return uint256 Secondary band width in PPM. To obtain the actual band width,
     * divide this number by 10^6 and multiply by the price median value.
     */
    function getElasticBandWidthPPMFtso(IIFtso _ftso) external view returns (uint256);
}


// File contracts/utils/implementation/FtsoRegistry.sol





/**
 * Handles registration of assets to the [FTSO system](https://docs.flare.network/tech/ftso).
 */
contract FtsoRegistry is IIFtsoRegistry, AddressUpdatable, GovernedBase {

    // constants
    uint256 internal constant MAX_HISTORY_LENGTH = 5;
    address internal constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // errors
    string internal constant ERR_TOKEN_NOT_SUPPORTED = "FTSO index not supported";
    string internal constant ERR_FTSO_MANAGER_ONLY = "FTSO manager only";

    // storage
    IIFtso[MAX_HISTORY_LENGTH][] internal ftsoHistory;
    mapping(string => uint256) internal ftsoIndex;

    // addresses
    /// `FtsoManager` contract that can add and remove assets to the registry.
    IIFtsoManager public ftsoManager;

    /// Only the `ftsoManager` can call this method.
    modifier onlyFtsoManager () {
        require (msg.sender == address(ftsoManager), ERR_FTSO_MANAGER_ONLY);
        _;
    }

    // Using a governed proxy pattern - no constructor will run. Using initialiseRegistry function instead.
    constructor() GovernedBase(DEAD_ADDRESS) AddressUpdatable(address(0)) {
        /* empty block */
    }

    function initialiseRegistry(address _addressUpdater) external onlyGovernance {
        require(getAddressUpdater() == address(0), "already initialized");
        require(_addressUpdater != address(0), "_addressUpdater zero");
        setAddressUpdaterValue(_addressUpdater);
    }

    /**
     * @inheritdoc IIFtsoRegistry
     * @dev Only the ftsoManager can call this method.
     */
    function addFtso(IIFtso _ftsoContract) external override onlyFtsoManager returns(uint256 _assetIndex) {
        string memory symbol = _ftsoContract.symbol();
        _assetIndex = ftsoIndex[symbol];
        // ftso with the symbol is not yet in history array, add it
        if (_assetIndex == 0) {
            _assetIndex = ftsoHistory.length;
            ftsoIndex[symbol] = _assetIndex + 1;
            ftsoHistory.push();
        } else {
            // Shift history
            _assetIndex = _assetIndex - 1;
            _shiftHistory(_assetIndex);
        }
        ftsoHistory[_assetIndex][0] = _ftsoContract;
    }

    /**
     * @inheritdoc IIFtsoRegistry
     * @dev Only the ftsoManager can call this method.
     */
    function removeFtso(IIFtso _ftso) external override onlyFtsoManager {
        string memory symbol = _ftso.symbol();
        uint256 assetIndex = ftsoIndex[symbol];
        if (assetIndex > 0) {
            assetIndex = assetIndex - 1;
            _shiftHistory(assetIndex);
            ftsoHistory[assetIndex][0] = IIFtso(address(0));
            delete ftsoIndex[symbol];
            return;
        }

        revert(ERR_TOKEN_NOT_SUPPORTED);
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getFtso(uint256 _assetIndex) external view override returns(IIFtso _activeFtso) {
        return _getFtso(_assetIndex);
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getFtsoBySymbol(string memory _symbol) external view override returns(IIFtso _activeFtso) {
        return _getFtsoBySymbol(_symbol);
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getCurrentPrice(uint256 _assetIndex) external view override
        returns(uint256 _price, uint256 _timestamp)
    {
        return _getFtso(_assetIndex).getCurrentPrice();
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getCurrentPrice(string memory _symbol) external view override
        returns(uint256 _price, uint256 _timestamp)
    {
        return _getFtsoBySymbol(_symbol).getCurrentPrice();
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getCurrentPriceWithDecimals(uint256 _assetIndex) external view override
        returns(uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals)
    {
        return _getFtso(_assetIndex).getCurrentPriceWithDecimals();
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getCurrentPriceWithDecimals(string memory _symbol) external view override
        returns(uint256 _price, uint256 _timestamp, uint256 _assetPriceUsdDecimals)
    {
        return _getFtsoBySymbol(_symbol).getCurrentPriceWithDecimals();
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getSupportedIndices() external view override returns(uint256[] memory _supportedIndices) {
        (_supportedIndices, ) = _getSupportedIndicesAndFtsos();
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getSupportedSymbols() external view override returns(string[] memory _supportedSymbols) {
        (, IIFtso[] memory ftsos) = _getSupportedIndicesAndFtsos();
        uint256 len = ftsos.length;
        _supportedSymbols = new string[](len);
        while (len > 0) {
            --len;
            _supportedSymbols[len] = ftsos[len].symbol();
        }
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getSupportedIndicesAndFtsos() external view override
        returns(uint256[] memory _supportedIndices, IIFtso[] memory _ftsos)
    {
        (_supportedIndices, _ftsos) = _getSupportedIndicesAndFtsos();
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getSupportedSymbolsAndFtsos() external view override
        returns(string[] memory _supportedSymbols, IIFtso[] memory _ftsos)
    {
        (, _ftsos) = _getSupportedIndicesAndFtsos();
        uint256 len = _ftsos.length;
        _supportedSymbols = new string[](len);
        while (len > 0) {
            --len;
            _supportedSymbols[len] = _ftsos[len].symbol();
        }
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getSupportedIndicesAndSymbols() external view override
        returns(uint256[] memory _supportedIndices, string[] memory _supportedSymbols)
    {
        IIFtso[] memory ftsos;
        (_supportedIndices, ftsos) = _getSupportedIndicesAndFtsos();
        uint256 len = _supportedIndices.length;
        _supportedSymbols = new string[](len);
        while (len > 0) {
            --len;
            _supportedSymbols[len] = ftsos[len].symbol();
        }
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getSupportedIndicesSymbolsAndFtsos() external view override
        returns(uint256[] memory _supportedIndices, string[] memory _supportedSymbols, IIFtso[] memory _ftsos)
    {
        (_supportedIndices, _ftsos) = _getSupportedIndicesAndFtsos();
        uint256 len = _supportedIndices.length;
        _supportedSymbols = new string[](len);
        while (len > 0) {
            --len;
            _supportedSymbols[len] = _ftsos[len].symbol();
        }
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getSupportedFtsos() external view override returns(IIFtso[] memory _ftsos) {
        (, _ftsos) = _getSupportedIndicesAndFtsos();
    }

    /**
     * @inheritdoc IFtsoRegistryGenesis
     */
    function getFtsos(uint256[] memory _assetIndices) external view override returns(IFtsoGenesis[] memory _ftsos) {
        uint256 ftsoLength = ftsoHistory.length;
        uint256 len = _assetIndices.length;
        _ftsos = new IFtsoGenesis[](len);
        while (len > 0) {
            --len;
            uint256 assetIndex = _assetIndices[len];
            require(assetIndex < ftsoLength, ERR_TOKEN_NOT_SUPPORTED);
            _ftsos[len] = ftsoHistory[assetIndex][0];
            if (address(_ftsos[len]) == address(0)) {
                // Invalid index, revert if address is zero address
                revert(ERR_TOKEN_NOT_SUPPORTED);
            }
        }
    }

    /**
     * Return all currently supported FTSO contracts.
     * @return _ftsos Array of FTSO contract addresses.
     */
    function getAllFtsos() external view returns(IIFtso[] memory _ftsos) {
        uint256 len = ftsoHistory.length;
        IIFtso[] memory ftsos = new IIFtso[](len);
        while (len > 0) {
            --len;
            ftsos[len] = ftsoHistory[len][0];
        }
        return ftsos;
    }

    /**
     * Get the history of FTSOs for given index.
     * If there are less then MAX_HISTORY_LENGTH the remaining addresses will be 0 addresses.
     * Reverts if index is not supported.
     * @param _assetIndex Asset index to query.
     * @return _ftsoAddressHistory History of FTSOs contract for provided index.
     */
    function getFtsoHistory(uint256 _assetIndex) external view
        returns(IIFtso[MAX_HISTORY_LENGTH] memory _ftsoAddressHistory)
    {
        require(_assetIndex < ftsoHistory.length &&
                address(ftsoHistory[_assetIndex][0]) != address(0), ERR_TOKEN_NOT_SUPPORTED);
        return ftsoHistory[_assetIndex];
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getFtsoIndex(string memory _symbol) external view override returns (uint256 _assetIndex) {
        return _getFtsoIndex(_symbol);
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getFtsoSymbol(uint256 _assetIndex) external view override returns (string memory _symbol) {
        return _getFtso(_assetIndex).symbol();
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getAllCurrentPrices() external view override returns (PriceInfo[] memory) {
        (uint256[] memory indices, IIFtso[] memory ftsos) = _getSupportedIndicesAndFtsos();
        return _getCurrentPrices(indices, ftsos);
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getCurrentPricesByIndices(uint256[] memory _indices) external view override returns (PriceInfo[] memory) {
        IIFtso[] memory ftsos = new IIFtso[](_indices.length);

        for (uint256 i = 0; i < _indices.length; i++) {
            ftsos[i] = _getFtso(_indices[i]);
        }
        return _getCurrentPrices(_indices, ftsos);
    }

    /**
     * @inheritdoc IFtsoRegistry
     */
    function getCurrentPricesBySymbols(string[] memory _symbols) external view override returns (PriceInfo[] memory) {
        uint256[] memory indices = new uint256[](_symbols.length);
        IIFtso[] memory ftsos = new IIFtso[](_symbols.length);

        for (uint256 i = 0; i < _symbols.length; i++) {
            indices[i] = _getFtsoIndex(_symbols[i]);
            ftsos[i] = ftsoHistory[indices[i]][0];
        }
        return _getCurrentPrices(indices, ftsos);
    }

    /**
     * Implementation of the AddressUpdatable abstract method.
     */
    function _updateContractAddresses(
        bytes32[] memory _contractNameHashes,
        address[] memory _contractAddresses
    )
        internal override
    {
        ftsoManager = IIFtsoManager(_getContractAddress(_contractNameHashes, _contractAddresses, "FtsoManager"));
    }

    /**
     * Shift the FTSOs history by one so the FTSO at index 0 can be overwritten.
     * Internal helper function.
     */
    function _shiftHistory(uint256 _assetIndex) internal {
        for (uint256 i = MAX_HISTORY_LENGTH-1; i > 0; i--) {
            ftsoHistory[_assetIndex][i] = ftsoHistory[_assetIndex][i-1];
        }
    }

    function _getCurrentPrices(
        uint256[] memory indices,
        IIFtso[] memory ftsos
    )
        internal view
        returns (PriceInfo[] memory _result)
    {
        uint256 length = ftsos.length;
        _result = new PriceInfo[](length);

        for(uint256 i = 0; i < length; i++) {
            _result[i].ftsoIndex = indices[i];
            (_result[i].price, _result[i].timestamp, _result[i].decimals) = ftsos[i].getCurrentPriceWithDecimals();
        }
    }

    function _getFtsoIndex(string memory _symbol) internal view returns (uint256) {
        uint256 assetIndex = ftsoIndex[_symbol];
        require(assetIndex > 0, ERR_TOKEN_NOT_SUPPORTED);
        return assetIndex - 1;
    }

    /**
     * Get the active FTSO for given index.
     * Internal get ftso function so it can be used within other methods.
     */
    function _getFtso(uint256 _assetIndex) internal view returns(IIFtso _activeFtso) {
        require(_assetIndex < ftsoHistory.length, ERR_TOKEN_NOT_SUPPORTED);

        IIFtso ftso = ftsoHistory[_assetIndex][0];
        if (address(ftso) == address(0)) {
            // Invalid index, revert if address is zero address
            revert(ERR_TOKEN_NOT_SUPPORTED);
        }
        _activeFtso = ftso;
    }

    /**
     * Get the active FTSO for given symbol.
     * Internal get ftso function so it can be used within other methods.
     */
    function _getFtsoBySymbol(string memory _symbol) internal view returns(IIFtso _activeFtso) {
        uint256 assetIndex = _getFtsoIndex(_symbol);
        _activeFtso = ftsoHistory[assetIndex][0];
    }

    function _getSupportedIndicesAndFtsos() internal view
        returns(uint256[] memory _supportedIndices, IIFtso[] memory _ftsos)
    {
        uint256 len = ftsoHistory.length;
        uint256[] memory supportedIndices = new uint256[](len);
        IIFtso[] memory ftsos = new IIFtso[](len);
        address zeroAddress = address(0);
        uint256 taken = 0;
        for (uint256 i = 0; i < len; ++i) {
            IIFtso ftso = ftsoHistory[i][0];
            if (address(ftso) != zeroAddress) {
                supportedIndices[taken] = i;
                ftsos[taken] = ftso;
                ++taken;
            }
        }
        _supportedIndices = new uint256[](taken);
        _ftsos = new IIFtso[](taken);
        while (taken > 0) {
            --taken;
            _supportedIndices[taken] = supportedIndices[taken];
            _ftsos[taken] = ftsos[taken];
        }
    }
}


// File contracts/utils/implementation/ProxyGoverned.sol


/**
 * @title A governed proxy contract
 */
abstract contract ProxyGoverned is Governed {

    // Storage position of the address of the current implementation
    bytes32 private constant IMPLEMENTATION_POSITION = 
        keccak256("flare.diamond.ProxyGoverned.IMPLEMENTATION_POSITION");

    string internal constant ERR_IMPLEMENTATION_ZERO = "implementation zero";

    event ImplementationSet(address newImplementation);

    constructor(
        address _governance,
        address _initialImplementation
    ) 
        Governed(_governance)
    {
        _setImplementation(_initialImplementation);
    }
    
    /**
     * @dev Fallback function that delegates calls to the address returned by `implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable {
        _delegate();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable {
        _delegate();
    }

    /**
     * @dev Sets the address of the current implementation
     * @param _newImplementation address representing the new implementation to be set
     */
    function setImplementation(address _newImplementation) external onlyGovernance {
        _setImplementation(_newImplementation);
    }

    /**
     * @dev Tells the address of the current implementation
     */
    function implementation() public view returns (address _impl) {
        bytes32 position = IMPLEMENTATION_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _impl := sload(position)
        }
    }

    // solhint-disable no-complex-fallback
    function _delegate() internal {
        address impl = implementation();
            
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)

            switch result
            case 0 { revert(0, size) }
            default { return(0, size) }
        }
    }

    /**
     * @dev Sets the address of the current implementation
     * @param _newImplementation address representing the new implementation to be set
     */
    function _setImplementation(address _newImplementation) internal {
        require(_newImplementation != address(0), ERR_IMPLEMENTATION_ZERO);
        bytes32 position = IMPLEMENTATION_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(position, _newImplementation)
        }
        emit ImplementationSet(_newImplementation);
    }
}


// File contracts/utils/implementation/FtsoRegistryProxy.sol


/**
 * @title A ftso registry governed proxy contract
 */
contract FtsoRegistryProxy is ProxyGoverned {

    constructor(
        address _governance,
        address _initialImplementation
    )
        ProxyGoverned(
            _governance,
            _initialImplementation
        )
    {}
}
