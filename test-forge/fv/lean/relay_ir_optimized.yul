/// @use-src 0:"contracts/protocol/implementation/Relay.sol", 1:"contracts/protocol/interface/IIRelay.sol", 2:"contracts/userInterfaces/IOwnableWithTimelock.sol", 3:"contracts/userInterfaces/IRelay.sol", 4:"contracts/userInterfaces/LTS/RandomNumberV2Interface.sol", 5:"contracts/utils/implementation/OwnableWithTimelock.sol", 11:"dependencies/@openzeppelin-contracts-5.7.0/interfaces/draft-IERC1822.sol", 14:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/Initializable.sol", 15:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/UUPSUpgradeable.sol", 33:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/access/OwnableUpgradeable.sol", 34:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/utils/ContextUpgradeable.sol"
object "Relay_2273" {
    code {
        {
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            let _1 := memoryguard(0xa0)
            mstore(64, _1)
            if callvalue() { revert(0, 0) }
            /// @src 15:1076:1089  "address(this)"
            mstore(128, /** @src 15:1084:1088  "this" */ address())
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            let _2 := sload(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)
            /// @src 14:7894:7970  "if ($._initializing) {..."
            if /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(64, _2), 0xff)
            /// @src 14:7894:7970  "if ($._initializing) {..."
            {
                /// @src 14:7936:7959  "InvalidInitialization()"
                mstore(/** @src -1:-1:-1 */ 0, /** @src 14:7936:7959  "InvalidInitialization()" */ shl(224, 0xf92ee8a9))
                revert(/** @src -1:-1:-1 */ 0, /** @src 14:7936:7959  "InvalidInitialization()" */ 4)
            }
            /// @src 14:7979:8125  "if ($._initialized != type(uint64).max) {..."
            if /** @src 14:7983:8017  "$._initialized != type(uint64).max" */ iszero(eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_2, sub(shl(64, 1), 1)), sub(shl(64, 1), 1)))
            /// @src 14:7979:8125  "if ($._initialized != type(uint64).max) {..."
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_2, not(sub(shl(64, 1), 1))), sub(shl(64, 1), 1)))
                mstore(_1, sub(shl(64, 1), 1))
                /// @src 14:8085:8114  "Initialized(type(uint64).max)"
                log1(_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32, /** @src 14:8085:8114  "Initialized(type(uint64).max)" */ 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            let _3 := mload(64)
            let _4 := datasize("Relay_2273_deployed")
            codecopy(_3, dataoffset("Relay_2273_deployed"), _4)
            setimmutable(_3, "4008", mload(/** @src 15:1076:1089  "address(this)" */ 128))
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            return(_3, _4)
        }
    }
    /// @use-src 0:"contracts/protocol/implementation/Relay.sol", 5:"contracts/utils/implementation/OwnableWithTimelock.sol", 12:"dependencies/@openzeppelin-contracts-5.7.0/proxy/ERC1967/ERC1967Utils.sol", 14:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/Initializable.sol", 15:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/UUPSUpgradeable.sol", 18:"dependencies/@openzeppelin-contracts-5.7.0/token/ERC20/utils/SafeERC20.sol", 19:"dependencies/@openzeppelin-contracts-5.7.0/utils/Address.sol", 23:"dependencies/@openzeppelin-contracts-5.7.0/utils/LowLevelCall.sol", 26:"dependencies/@openzeppelin-contracts-5.7.0/utils/StorageSlot.sol", 27:"dependencies/@openzeppelin-contracts-5.7.0/utils/cryptography/Hashes.sol", 28:"dependencies/@openzeppelin-contracts-5.7.0/utils/cryptography/MerkleProof.sol", 32:"dependencies/@openzeppelin-contracts-5.7.0/utils/structs/EnumerableSet.sol", 33:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/access/OwnableUpgradeable.sol", 34:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/utils/ContextUpgradeable.sol"
    object "Relay_2273_deployed" {
        code {
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(64, 128)
                if iszero(lt(calldatasize(), 4))
                {
                    switch shr(224, calldataload(0))
                    case 0x0c85bf07 {
                        external_fun_toSigningPolicyHash()
                    }
                    case 0x150fea09 {
                        external_fun_setTimelockDuration()
                    }
                    case 0x1544298e { external_fun_sourceChainId() }
                    case 0x1e8fb36a { external_fun_stateData() }
                    case 0x1f9da642 {
                        external_fun_executeTimelockedCall()
                    }
                    case 0x317ad33c { external_fun_isFinalized() }
                    case 0x377c50d4 {
                        external_fun_feeCollectionAddress()
                    }
                    case 0x37ea4938 {
                        external_fun_setFeeExemptions()
                    }
                    case 0x39436b00 { external_fun_merkleRoots() }
                    case 0x42c3f237 {
                        external_fun_setSigningPolicySetter()
                    }
                    case 0x47e1818b {
                        external_fun_startingVotingRoundIdForInitialRewardEpochId()
                    }
                    case 0x4f1ef286 {
                        external_fun_upgradeToAndCall()
                    }
                    case 0x52d1902d { external_fun_proxiableUUID() }
                    case 0x5c60da1b { external_fun_implementation() }
                    case 0x5cb9ba54 { external_fun_getFeeConfigs() }
                    case 0x647846a5 { external_fun_feeToken() }
                    case 0x686a5e5d {
                        external_fun_initialRewardEpochId()
                    }
                    case 0x6c59978d {
                        external_fun_feeExemptAddress()
                    }
                    case 0x715018a6 {
                        external_fun_renounceOwnership()
                    }
                    case 0x7297c0a2 {
                        external_fun_startingVotingRoundIds()
                    }
                    case 0x808506aa { external_fun_verify() }
                    case 0x83534125 {
                        external_fun_setSigningPolicy()
                    }
                    case 0x8af0c307 {
                        external_fun_lastInitializedRewardEpochData()
                    }
                    case 0x8da5cb5b { external_fun_owner() }
                    case 0x91e7d42f {
                        external_fun_protocolFeeInWei()
                    }
                    case 0x9932185e {
                        external_fun_verifyCustomSignature()
                    }
                    case 0xa032b5f4 { external_fun_protocolFee() }
                    case 0xa64ad51b { external_fun_initialize() }
                    case 0xa87f1438 {
                        external_fun_getRandomNumberHistorical()
                    }
                    case 0xa9dbe8ed {
                        external_fun_signingPolicySetter()
                    }
                    case 0xab97db37 {
                        external_fun_getVotingRoundId()
                    }
                    case 0xad3cb1cc {
                        external_fun_UPGRADE_INTERFACE_VERSION()
                    }
                    case 0xb071614b {
                        external_fun_getExecuteTimelockedCallTimestamp()
                    }
                    case 0xb59589d1 { external_fun_relay() }
                    case 0xb8cc76fb {
                        external_fun_setFeeCollectionAddress()
                    }
                    case 0xc00dbe0c {
                        external_fun_setProtocolFees()
                    }
                    case 0xd15cc493 {
                        external_fun_verifyCustomSignatureWithThreshold()
                    }
                    case 0xdbdff2c1 {
                        external_fun_getRandomNumber()
                    }
                    case 0xf1dd663e {
                        external_fun_getTimelockDurationSeconds()
                    }
                    case 0xf2fde38b {
                        external_fun_transferOwnership()
                    }
                    case 0xf485a005 {
                        external_fun_cancelTimelockedCall()
                    }
                    case 0xffc1f8ef { external_fun_oldRelay() }
                }
                revert(0, 0)
            }
            function abi_decode_uint256() -> value
            { value := calldataload(4) }
            function abi_decode_t_uint256() -> value
            { value := calldataload(36) }
            function abi_encode_bytes32(value0) -> tail
            {
                tail := 36
                mstore(4, value0)
            }
            function abi_encode_tuple_bytes32(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                mstore(headStart, value0)
            }
            function external_fun_toSigningPolicyHash()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let ret := fun_toSigningPolicyHash(value)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function external_fun_setTimelockDuration()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1893:1923  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:2037:2045  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 5:3619:3712  "require(_timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS, TimelockDurationTooLong())"
                    require_helper_error_TimelockDurationTooLong(/** @src 5:3627:3684  "_timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS" */ iszero(gt(value, /** @src 5:1578:1584  "7 days" */ 0x093a80)))
                    sstore(/** @src 5:3722:3751  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01, /** @src 5:1578:1584  "7 days" */ value)
                    /// @src 5:3793:3838  "TimelockDurationSet(_timelockDurationSeconds)"
                    let _1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    mstore(_1, value)
                    /// @src 5:3793:3838  "TimelockDurationSet(_timelockDurationSeconds)"
                    log1(_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32, /** @src 5:3793:3838  "TimelockDurationSet(_timelockDurationSeconds)" */ 0xf15cdeff5f6a37216412a72678ec978762dc7264a85f30590ed54b14ab51bbdf)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function extract_from_storage_value_dynamict_uint256(slot_value, offset) -> value
            {
                value := shr(shl(3, offset), slot_value)
            }
            function external_fun_sourceChainId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:17143:17180  "uint256 public override sourceChainId" */ 14)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function cleanup_from_storage_uint8(value) -> cleaned
            { cleaned := and(value, 0xff) }
            function cleanup_from_storage_uint32(value) -> cleaned
            {
                cleaned := and(value, 0xffffffff)
            }
            function extract_from_storage_value_offset_uint32(slot_value) -> value
            {
                value := and(shr(8, slot_value), 0xffffffff)
            }
            function extract_from_storage_value_offset_uint8(slot_value) -> value
            {
                value := and(shr(40, slot_value), 0xff)
            }
            function cleanup_from_storage_uint16(value) -> cleaned
            { cleaned := and(value, 0xffff) }
            function extract_from_storage_value_offset_19_uint32(slot_value) -> value
            {
                value := and(shr(152, slot_value), 0xffffffff)
            }
            function extract_from_storage_value_offset_bool(slot_value) -> value
            {
                value := and(shr(184, slot_value), 0xff)
            }
            function extract_from_storage_value_offset_t_uint32(slot_value) -> value
            {
                value := and(shr(192, slot_value), 0xffffffff)
            }
            function abi_encode_uint32(value, pos)
            {
                mstore(pos, and(value, 0xffffffff))
            }
            function cleanup_bool(value) -> cleaned
            {
                cleaned := iszero(iszero(value))
            }
            function abi_encode_bool_to_bool(value, pos)
            {
                mstore(pos, iszero(iszero(value)))
            }
            function abi_encode_uint8_uint32_uint8_uint32_uint16_uint16_uint32_bool_uint32_bool_uint32(headStart, value0, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10) -> tail
            {
                tail := add(headStart, 352)
                mstore(headStart, and(value0, 0xff))
                mstore(add(headStart, 32), and(value1, 0xffffffff))
                mstore(add(headStart, 64), and(value2, 0xff))
                mstore(add(headStart, 96), and(value3, 0xffffffff))
                mstore(add(headStart, 128), and(value4, 0xffff))
                mstore(add(headStart, 160), and(value5, 0xffff))
                abi_encode_uint32(value6, add(headStart, 192))
                abi_encode_bool_to_bool(value7, add(headStart, 224))
                abi_encode_uint32(value8, add(headStart, 256))
                abi_encode_bool_to_bool(value9, add(headStart, 288))
                abi_encode_uint32(value10, add(headStart, 320))
            }
            function external_fun_stateData()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:16187:16213  "StateData public stateData" */ 11)
                let ret := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_bool(_1)
                /// @src 0:16187:16213  "StateData public stateData"
                let ret_1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint8_uint32_uint8_uint32_uint16_uint16_uint32_bool_uint32_bool_uint32(memPos, and(_1, 0xff), and(shr(8, _1), 0xffffffff), and(shr(40, _1), 0xff), and(shr(48, _1), 0xffffffff), and(shr(80, _1), 0xffff), and(shr(96, _1), 0xffff), and(shr(112, _1), 0xffffffff), and(shr(144, _1), 0xff), and(shr(152, _1), 0xffffffff), ret, ret_1), memPos))
            }
            function abi_decode_bytes_calldata_ptr(offset, end) -> arrayPos, length
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                length := calldataload(offset)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                arrayPos := add(offset, 0x20)
                if gt(add(add(offset, length), 0x20), end) { revert(0, 0) }
            }
            function abi_decode_bytes_calldata(dataEnd) -> value0, value1
            {
                if slt(add(dataEnd, not(3)), 32) { revert(0, 0) }
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                let value0_1, value1_1 := abi_decode_bytes_calldata_ptr(add(4, offset), dataEnd)
                value0 := value0_1
                value1 := value1_1
            }
            function external_fun_executeTimelockedCall()
            {
                if callvalue() { revert(0, 0) }
                let param, param_1 := abi_decode_bytes_calldata(calldatasize())
                /// @src 5:2299:2322  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:2299:2322  "keccak256(_encodedCall)" */ param, param_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                /// @src 5:2299:2322  "keccak256(_encodedCall)"
                let expr := keccak256(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:2299:2322  "keccak256(_encodedCall)" */ _mpos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:2299:2322  "keccak256(_encodedCall)" */ _mpos))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:2364:2385  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                /// @src 5:2412:2474  "require(allowedAfterTimestamp != 0, TimelockInvalidSelector())"
                require_helper_error_TimelockInvalidSelector(/** @src 5:2420:2446  "allowedAfterTimestamp != 0" */ iszero(iszero(_1)))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(/** @src 5:2492:2532  "block.timestamp >= allowedAfterTimestamp" */ iszero(lt(/** @src 5:2492:2507  "block.timestamp" */ timestamp(), /** @src 5:2492:2532  "block.timestamp >= allowedAfterTimestamp" */ _1)))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(0, shl(225, 0x309272e1))
                    revert(0, 4)
                }
                let slot := /** @src 5:2575:2613  "state.timelockedCalls[encodedCallHash]" */ mapping_index_access_t_mapping_t_uint256_t_uint256_of_t_uint256(expr)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let result := /** @src 5:2445:2446  "0" */ 0x00
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                result := /** @src 5:2445:2446  "0" */ 0x00
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(slot, /** @src 5:2445:2446  "0" */ 0x00)
                /// @src 5:2623:2645  "state.executing = true"
                update_storage_value_offset_bool_to_bool_18957()
                /// @src 5:2731:2763  "address(this).call(_encodedCall)"
                let _2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                /// @src 5:2731:2763  "address(this).call(_encodedCall)"
                let expr_component := call(gas(), /** @src 5:2739:2743  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 5:2731:2763  "address(this).call(_encodedCall)" */ _2, sub(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_encode_bytes_calldata(/** @src 5:2731:2763  "address(this).call(_encodedCall)" */ param, param_1, _2), _2), /** @src -1:-1:-1 */ 0, 0)
                /// @src 5:2731:2763  "address(this).call(_encodedCall)"
                pop(extract_returndata())
                /// @src 5:2773:2796  "state.executing = false"
                update_storage_value_offset_bool_to_bool_18958()
                /// @src 5:2811:2850  "TimelockedCallExecuted(encodedCallHash)"
                let _3 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                /// @src 5:2811:2850  "TimelockedCallExecuted(encodedCallHash)"
                log1(_3, sub(abi_encode_tuple_bytes32(_3, expr), _3), 0x4730df91415d0dc5bbdb12bc2edbf9b11242938ab0e851d9fb37e3ca802cea21)
                /// @src 5:2880:2887  "success"
                fun_passReturnOrRevert(expr_component)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function abi_encode_bool(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(headStart, /** @src 0:20826:20827  "1" */ 0x01)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function abi_encode_tuple_bool(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                mstore(headStart, iszero(iszero(value0)))
            }
            function external_fun_isFinalized()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(36)
                let ret := fun_isFinalized(value, value_1)
                let memPos := mload(64)
                mstore(memPos, iszero(iszero(ret)))
                return(memPos, 32)
            }
            function cleanup_address_payable(value) -> cleaned
            {
                cleaned := and(value, sub(shl(160, 1), 1))
            }
            function external_fun_feeCollectionAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:14641:14684  "address payable public feeCollectionAddress" */ 5), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function abi_decode_array_struct_FeeExemption_calldata_dyn_calldata(offset, end) -> arrayPos, length
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                length := calldataload(offset)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                arrayPos := add(offset, 0x20)
                if gt(add(add(offset, shl(6, length)), 0x20), end) { revert(0, 0) }
            }
            function external_fun_setFeeExemptions()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value0, value1 := abi_decode_array_struct_FeeExemption_calldata_dyn_calldata(add(4, offset), calldatasize())
                /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1893:1923  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:2037:2045  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:34792:34861  "require(signingPolicySetter == address(0), FeeExemptionsNotAllowed())"
                    require_helper_error_FeeExemptionsNotAllowed(/** @src 0:34800:34833  "signingPolicySetter == address(0)" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:34800:34819  "signingPolicySetter" */ 0x03), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                    /// @src 0:34876:34889  "uint256 i = 0"
                    let var_i := /** @src -1:-1:-1 */ 0
                    /// @src 0:34871:35182  "for (uint256 i = 0; i < _exemptions.length; i++) {..."
                    for { }
                    /** @src 0:34891:34913  "i < _exemptions.length" */ lt(var_i, /** @src 0:34895:34913  "_exemptions.length" */ value1)
                    /// @src 0:34876:34889  "uint256 i = 0"
                    {
                        /// @src 0:34915:34918  "i++"
                        var_i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:34915:34918  "i++" */ var_i, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1)
                    }
                    /// @src 0:34915:34918  "i++"
                    {
                        /// @src 0:34952:34974  "_exemptions[i].account"
                        let expr := read_from_calldatat_address(/** @src 0:34952:34966  "_exemptions[i]" */ calldata_array_index_access_struct_FeeExemption_calldata_dyn_calldata(value0, value1, var_i))
                        /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                        let _1 := and(/** @src 0:34996:35017  "account != address(0)" */ expr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                        /// @src 0:34988:35042  "require(account != address(0), FeeExemptAddressZero())"
                        require_helper_error_FeeExemptAddressZero(/** @src 0:34996:35017  "account != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1)))
                        /// @src 0:35056:35105  "feeExemptAddress[account] = _exemptions[i].exempt"
                        update_storage_value_offset_0_bool_to_bool(/** @src 0:35056:35081  "feeExemptAddress[account]" */ mapping_index_access_mapping_address_bool_of_address(expr), /** @src 0:35084:35105  "_exemptions[i].exempt" */ read_from_calldatat_bool(add(/** @src 0:35084:35098  "_exemptions[i]" */ calldata_array_index_access_struct_FeeExemption_calldata_dyn_calldata(value0, value1, var_i), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32)))
                        /// @src 0:35149:35170  "_exemptions[i].exempt"
                        let expr_1 := read_from_calldatat_bool(add(/** @src 0:35149:35163  "_exemptions[i]" */ calldata_array_index_access_struct_FeeExemption_calldata_dyn_calldata(value0, value1, var_i), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32))
                        /// @src 0:35124:35171  "FeeExemptionSet(account, _exemptions[i].exempt)"
                        let _2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                        /// @src 0:35124:35171  "FeeExemptionSet(account, _exemptions[i].exempt)"
                        log2(_2, sub(abi_encode_tuple_bool(_2, expr_1), _2), 0x210f2a4a589e25d95b24cbdb060d26ae79bbe123a564d0f973503d48badd00ca, _1)
                    }
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_merkleRoots()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(36)
                let ret := fun_merkleRoots(value, value_1)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function validator_revert_address(value)
            {
                if iszero(eq(value, and(value, sub(shl(160, 1), 1)))) { revert(0, 0) }
            }
            function abi_decode_address_18989() -> value
            {
                value := calldataload(36)
                validator_revert_address(value)
            }
            function abi_decode_address_18991() -> value
            {
                value := calldataload(100)
                validator_revert_address(value)
            }
            function abi_decode_address(offset) -> value
            {
                value := calldataload(offset)
                validator_revert_address(value)
            }
            function external_fun_setSigningPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address(value)
                /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1893:1923  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:2037:2045  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _1 := sload(/** @src 0:36292:36311  "signingPolicySetter" */ 0x03)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if /** @src 0:36292:36325  "signingPolicySetter != address(0)" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_1, sub(shl(160, 1), 1)))
                    {
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xd029c629))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                    }
                    let _2 := and(/** @src 0:36377:36411  "_signingPolicySetter != address(0)" */ value, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    if /** @src 0:36377:36411  "_signingPolicySetter != address(0)" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _2)
                    {
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x60ba70d1))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                    }
                    sstore(/** @src 0:36292:36311  "signingPolicySetter" */ 0x03, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, shl(160, 0xffffffffffffffffffffffff)), _2))
                    /// @src 0:36506:36550  "SigningPolicySetterSet(_signingPolicySetter)"
                    log2(/** @src -1:-1:-1 */ 0, 0, /** @src 0:36506:36550  "SigningPolicySetterSet(_signingPolicySetter)" */ 0x78cbfa03aa310db13b3d8fcb316ae48a77d62315fccfe098fc146374d6edb309, _2)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_startingVotingRoundIdForInitialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(192, sload(/** @src 0:16614:16672  "uint32 public startingVotingRoundIdForInitialRewardEpochId" */ 13)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function panic_error_0x41()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(0, 0x24)
            }
            function finalize_allocation_18969(memPtr)
            {
                let newFreePtr := add(memPtr, 64)
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr)) { panic_error_0x41() }
                mstore(64, newFreePtr)
            }
            function finalize_allocation(memPtr, size)
            {
                let newFreePtr := add(memPtr, and(add(size, 31), not(31)))
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr)) { panic_error_0x41() }
                mstore(64, newFreePtr)
            }
            function allocate_memory() -> memPtr
            {
                memPtr := mload(64)
                finalize_allocation(memPtr, 64)
            }
            function allocate_memory_18979() -> memPtr
            {
                memPtr := mload(64)
                finalize_allocation(memPtr, 0xc0)
            }
            function allocate_memory_18988() -> memPtr
            {
                memPtr := mload(64)
                finalize_allocation(memPtr, 0x0200)
            }
            function array_allocation_size_bytes(length) -> size
            {
                if gt(length, 0xffffffffffffffff) { panic_error_0x41() }
                size := add(and(add(length, 31), not(31)), 0x20)
            }
            function abi_decode_available_length_bytes(src, length, end) -> array
            {
                let _1 := array_allocation_size_bytes(length)
                let memPtr := mload(64)
                finalize_allocation(memPtr, _1)
                array := memPtr
                mstore(memPtr, length)
                if gt(add(src, length), end)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                calldatacopy(add(memPtr, 0x20), src, length)
                mstore(add(add(memPtr, length), 0x20), /** @src -1:-1:-1 */ 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_upgradeToAndCall()
            {
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address(value)
                let offset := calldataload(36)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let array := abi_decode_available_length_bytes(add(offset, 36), calldataload(add(4, offset)), calldatasize())
                /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1893:1923  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:2037:2045  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 15:4400:4423  "address(this) == __self"
                    let _1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 15:4417:4423  "__self" */ loadimmutable("4008"), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    /// @src 15:4400:4520  "address(this) == __self || // Must be called through delegatecall..."
                    let expr := /** @src 15:4400:4423  "address(this) == __self" */ eq(/** @src 15:4408:4412  "this" */ address(), /** @src 15:4400:4423  "address(this) == __self" */ _1)
                    /// @src 15:4400:4520  "address(this) == __self || // Must be called through delegatecall..."
                    if iszero(expr)
                    {
                        expr := /** @src 15:4478:4520  "ERC1967Utils.getImplementation() != __self" */ iszero(eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 12:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)), /** @src 15:4478:4520  "ERC1967Utils.getImplementation() != __self" */ _1))
                    }
                    /// @src 15:4383:4634  "if (..."
                    if expr
                    {
                        /// @src 15:4594:4623  "UUPSUnauthorizedCallContext()"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 15:4594:4623  "UUPSUnauthorizedCallContext()" */ shl(225, 0x703e46dd))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                    }
                    /// @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    let _2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    mstore(_2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x52d1902d))
                    /// @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    let trySuccessCondition := staticcall(gas(), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 15:5881:5917  "IERC1822Proxiable(newImplementation)" */ value, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)), /** @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()" */ _2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4, /** @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()" */ _2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32)
                    /// @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    let expr_1 := /** @src -1:-1:-1 */ 0
                    /// @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    if trySuccessCondition
                    {
                        let _3 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32
                        /// @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                        if gt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32, /** @src 15:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()" */ returndatasize()) { _3 := returndatasize() }
                        finalize_allocation(_2, _3)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _3))
                    }
                    /// @src 15:5877:6314  "try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {..."
                    switch iszero(trySuccessCondition)
                    case 0 {
                        /// @src 15:5971:6091  "if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {..."
                        if /** @src 15:5975:6015  "slot != ERC1967Utils.IMPLEMENTATION_SLOT" */ iszero(eq(expr_1, /** @src 12:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
                        /// @src 15:5971:6091  "if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {..."
                        {
                            /// @src 15:6042:6076  "UUPSUnsupportedProxiableUUID(slot)"
                            mstore(/** @src -1:-1:-1 */ 0, /** @src 15:6042:6076  "UUPSUnsupportedProxiableUUID(slot)" */ shl(226, 0x2a875269))
                            revert(/** @src -1:-1:-1 */ 0, /** @src 15:6042:6076  "UUPSUnsupportedProxiableUUID(slot)" */ abi_encode_bytes32(expr_1))
                        }
                        /// @src 15:6153:6157  "data"
                        fun_upgradeToAndCall(value, array)
                    }
                    default /// @src 15:5877:6314  "try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {..."
                    {
                        /// @src 15:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 15:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)" */ shl(224, 0x4c9c8ce3))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 15:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)" */ abi_encode_address(value))
                    }
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_proxiableUUID()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 15:4819:4964  "if (address(this) != __self) {..."
                if /** @src 15:4823:4846  "address(this) != __self" */ iszero(eq(/** @src 15:4831:4835  "this" */ address(), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 15:4840:4846  "__self" */ loadimmutable("4008"), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 15:4819:4964  "if (address(this) != __self) {..."
                {
                    /// @src 15:4924:4953  "UUPSUnauthorizedCallContext()"
                    mstore(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 15:4594:4623  "UUPSUnauthorizedCallContext()" */ shl(225, 0x703e46dd))
                    /// @src 15:4924:4953  "UUPSUnauthorizedCallContext()"
                    revert(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 4)
                }
                let memPos := mload(64)
                mstore(memPos, /** @src 12:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(memPos, 32)
            }
            function abi_encode_address(value0) -> tail
            {
                tail := 36
                mstore(4, and(value0, sub(shl(160, 1), 1)))
            }
            function external_fun_implementation()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let cleaned := and(sload(/** @src 12:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, cleaned)
                return(memPos, 32)
            }
            function abi_encode_array_struct_FeeConfig_dyn(headStart, value0) -> tail
            {
                let tail_1 := add(headStart, 32)
                mstore(headStart, 32)
                let pos := tail_1
                let length := mload(value0)
                mstore(tail_1, length)
                pos := add(headStart, 64)
                let srcPtr := add(value0, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    let _1 := mload(srcPtr)
                    mstore(pos, and(mload(_1), 0xff))
                    mstore(add(pos, 32), mload(add(_1, 32)))
                    pos := add(pos, 64)
                    srcPtr := add(srcPtr, 32)
                }
                tail := pos
            }
            function external_fun_getFeeConfigs()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let length := sload(/** @src 0:94067:94088  "feeProtocolIdsPrivate" */ 0x07)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := array_allocation_size_array_address_dyn(length)
                let memPtr := mload(64)
                finalize_allocation(memPtr, _1)
                mstore(memPtr, length)
                let _2 := add(array_allocation_size_array_address_dyn(length), not(31))
                let i := 0
                for { } lt(i, _2) { i := add(i, 32) }
                {
                    let memPtr_1 := mload(64)
                    finalize_allocation_18969(memPtr_1)
                    mstore(memPtr_1, 0)
                    mstore(add(memPtr_1, 32), 0)
                    mstore(add(add(memPtr, i), 32), memPtr_1)
                }
                /// @src 0:94158:94171  "uint256 i = 0"
                let var_i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:94153:94347  "for (uint256 i = 0; i < count; i++) {..."
                for { }
                /** @src 0:94173:94182  "i < count" */ lt(var_i, length)
                /// @src 0:94158:94171  "uint256 i = 0"
                {
                    /// @src 0:94184:94187  "i++"
                    var_i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:94184:94187  "i++" */ var_i, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1)
                }
                /// @src 0:94184:94187  "i++"
                {
                    /// @src 32:23238:23261  "_pos(set._inner, index)"
                    let _3 := fun_pos(/** @src 0:94224:94252  "feeProtocolIdsPrivate.pos(i)" */ var_i)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _4 := sload(/** @src 0:94312:94335  "protocolFee[protocolId]" */ mapping_index_access_mapping_uint256__uint256__of_uint256(_3))
                    /// @src 0:94283:94336  "FeeConfig(uint8(protocolId), protocolFee[protocolId])"
                    let expr_mpos := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ allocate_memory()
                    /// @src 0:94283:94336  "FeeConfig(uint8(protocolId), protocolFee[protocolId])"
                    write_to_memory_uint8(expr_mpos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:94293:94310  "uint8(protocolId)" */ _3, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff))
                    mstore(/** @src 0:94283:94336  "FeeConfig(uint8(protocolId), protocolFee[protocolId])" */ add(expr_mpos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32), _4)
                    /// @src 0:94266:94336  "_feeConfigs[i] = FeeConfig(uint8(protocolId), protocolFee[protocolId])"
                    mstore(memory_array_index_access_struct_FeeConfig_dyn(memPtr, var_i), expr_mpos)
                    pop(memory_array_index_access_struct_FeeConfig_dyn(memPtr, var_i))
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_array_struct_FeeConfig_dyn(memPos, memPtr), memPos))
            }
            function external_fun_feeToken()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:15228:15260  "address public override feeToken" */ 6), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function external_fun_initialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(160, sload(/** @src 0:16521:16555  "uint32 public initialRewardEpochId" */ 13)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function mapping_index_access_mapping_address_bool_of_address(key) -> dataSlot
            {
                mstore(0, and(key, sub(shl(160, 1), 1)))
                mstore(0x20, /** @src 0:35056:35072  "feeExemptAddress" */ 0x09)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function external_fun_feeExemptAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address(value)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(value, sub(shl(160, 1), 1)))
                mstore(32, /** @src 0:15721:15786  "mapping(address account => bool) public override feeExemptAddress" */ 9)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value_1 := and(sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40)), 0xff)
                let memPos := mload(0x40)
                mstore(memPos, iszero(iszero(value_1)))
                return(memPos, 32)
            }
            function external_fun_renounceOwnership()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 5:4832:4850  "RenounceDisabled()"
                mstore(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 5:4832:4850  "RenounceDisabled()" */ shl(224, 0x89051165))
                revert(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 4)
            }
            function mapping_index_access_t_mapping_t_uint256_t_uint256_of_t_uint256(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 5:2364:2385  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256__uint256__of_uint256(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, 4)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19046(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, 0)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19054(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:94878:94896  "merkleRootsPrivate" */ 0x01)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19144(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:97092:97113  "toRandomNumberPrivate" */ 0x0c)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_t_mapping_t_uint256__t_uint256__of_t_uint256(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:97170:97187  "isSecureRandomMap" */ 0x0a)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256(slot, key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, slot)
                dataSlot := keccak256(0, 0x40)
            }
            function external_fun_startingVotingRoundIds()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value)
                mstore(32, /** @src 0:14268:14339  "mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds" */ 2)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                let memPos := mload(0x40)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function abi_decode_bytes32() -> value
            { value := calldataload(68) }
            function external_fun_verify()
            {
                if slt(add(calldatasize(), not(3)), 128)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value0 := abi_decode_uint256()
                let value1 := abi_decode_t_uint256()
                let value2 := abi_decode_bytes32()
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let length := calldataload(add(4, offset))
                if gt(length, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if gt(add(add(offset, shl(5, length)), 36), calldatasize())
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let ret := fun_verify(value0, value1, value2, add(offset, 36), length)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_tuple_bool(memPos, ret), memPos))
            }
            function cleanup_uint24(value) -> cleaned
            {
                cleaned := and(value, 0xffffff)
            }
            function abi_decode_uint24(offset) -> value
            {
                value := calldataload(offset)
                if iszero(eq(value, and(value, 0xffffff))) { revert(0, 0) }
            }
            function validator_revert_uint32(value)
            {
                if iszero(eq(value, and(value, 0xffffffff))) { revert(0, 0) }
            }
            function abi_decode_uint32(offset) -> value
            {
                value := calldataload(offset)
                validator_revert_uint32(value)
            }
            function validator_revert_uint16(value)
            {
                if iszero(eq(value, and(value, 0xffff))) { revert(0, 0) }
            }
            function abi_decode_uint16(offset) -> value
            {
                value := calldataload(offset)
                validator_revert_uint16(value)
            }
            function array_allocation_size_array_address_dyn(length) -> size
            {
                if gt(length, 0xffffffffffffffff) { panic_error_0x41() }
                size := add(shl(5, length), 0x20)
            }
            function abi_decode_array_address_dyn(offset, end) -> array
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                let length := calldataload(offset)
                let _1 := array_allocation_size_array_address_dyn(length)
                let memPtr := mload(64)
                finalize_allocation(memPtr, _1)
                let dst := memPtr
                mstore(memPtr, length)
                dst := add(memPtr, 0x20)
                let srcEnd := add(add(offset, shl(5, length)), 0x20)
                if gt(srcEnd, end)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let src := add(offset, 0x20)
                for { } lt(src, srcEnd) { src := add(src, 0x20) }
                {
                    let value := calldataload(src)
                    validator_revert_address(value)
                    mstore(dst, value)
                    dst := add(dst, 0x20)
                }
                array := memPtr
            }
            function abi_decode_array_uint16_dyn(offset, end) -> array
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                let length := calldataload(offset)
                let _1 := array_allocation_size_array_address_dyn(length)
                let memPtr := mload(64)
                finalize_allocation(memPtr, _1)
                let dst := memPtr
                mstore(memPtr, length)
                dst := add(memPtr, 0x20)
                let srcEnd := add(add(offset, shl(5, length)), 0x20)
                if gt(srcEnd, end)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let src := add(offset, 0x20)
                for { } lt(src, srcEnd) { src := add(src, 0x20) }
                {
                    let value := calldataload(src)
                    validator_revert_uint16(value)
                    mstore(dst, value)
                    dst := add(dst, 0x20)
                }
                array := memPtr
            }
            function external_fun_setSigningPolicy()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0xc0)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := allocate_memory_18979()
                mstore(value, abi_decode_uint24(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                mstore(add(value, 64), abi_decode_uint16(add(offset, 68)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(add(offset, 100))
                mstore(add(value, 96), value_1)
                let offset_1 := calldataload(add(offset, 132))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 128), abi_decode_array_address_dyn(add(add(offset, offset_1), 4), calldatasize()))
                let offset_2 := calldataload(add(offset, 164))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 160), abi_decode_array_uint16_dyn(add(add(offset, offset_2), 4), calldatasize()))
                /// @src 0:27464:27471  "bytes32"
                let var := modifier_onlySigningPolicySetter(value)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_tuple_bytes32(memPos, var), memPos))
            }
            function external_fun_lastInitializedRewardEpochData()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(152, sload(/** @src 0:98552:98561  "stateData" */ 0x0b)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 0:98671:98693  "startingVotingRoundIds" */ 0x02)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let cleaned := and(sload(keccak256(0, 0x40)), 0xffffffff)
                let memPos := mload(0x40)
                mstore(memPos, value)
                mstore(add(memPos, 0x20), cleaned)
                return(memPos, 0x40)
            }
            function external_fun_owner()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let cleaned := and(sload(/** @src 33:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, cleaned)
                return(memPos, 32)
            }
            function external_fun_protocolFeeInWei()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                if iszero(/** @src 0:93804:93826  "feeToken == address(0)" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:93804:93812  "feeToken" */ 0x06), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(226, 0x23c97187))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value)
                mstore(32, 4)
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                let memPos := mload(0x40)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_verifyCustomSignature()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value0, value1 := abi_decode_bytes_calldata_ptr(add(4, offset), calldatasize())
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(36)
                let ret := /** @src 0:32247:32298  "_verifyCustomSignature(_relayMessage, _messageHash)" */ fun_verifyCustomSignature(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value0, value1, value)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function external_fun_protocolFee()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value)
                mstore(32, 4)
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                let memPos := mload(0x40)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function validator_revert_uint8(value)
            {
                if iszero(eq(value, and(value, 0xff))) { revert(0, 0) }
            }
            function abi_decode_uint8(offset) -> value
            {
                value := calldataload(offset)
                validator_revert_uint8(value)
            }
            function abi_decode_available_length_array_struct_FeeConfig_dyn(offset, length, end) -> array
            {
                let _1 := array_allocation_size_array_address_dyn(length)
                let memPtr := mload(64)
                finalize_allocation(memPtr, _1)
                array := memPtr
                let dst := memPtr
                mstore(memPtr, length)
                dst := add(memPtr, 0x20)
                let srcEnd := add(offset, shl(6, length))
                if gt(srcEnd, end)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let src := offset
                for { } lt(src, srcEnd) { src := add(src, 64) }
                {
                    if slt(sub(end, src), 64)
                    {
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let memPtr_1 := mload(64)
                    finalize_allocation_18969(memPtr_1)
                    let value := calldataload(src)
                    validator_revert_uint8(value)
                    mstore(memPtr_1, value)
                    let value_1 := /** @src -1:-1:-1 */ 0
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    value_1 := calldataload(add(src, 0x20))
                    mstore(add(memPtr_1, 0x20), value_1)
                    mstore(dst, memPtr_1)
                    dst := add(dst, 0x20)
                }
            }
            function abi_decode_array_struct_FeeConfig_dyn(offset, end) -> array
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                array := abi_decode_available_length_array_struct_FeeConfig_dyn(add(offset, 0x20), calldataload(offset), end)
            }
            function abi_decode_contract_IRelay() -> value
            {
                value := calldataload(68)
                validator_revert_address(value)
            }
            function external_fun_initialize()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 128)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0x0200)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := allocate_memory_18988()
                mstore(value, abi_decode_uint32(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(add(offset, 68))
                mstore(add(value, 64), value_1)
                mstore(add(value, 96), abi_decode_uint8(add(offset, 100)))
                mstore(add(value, 128), abi_decode_uint32(add(offset, 132)))
                mstore(add(value, 160), abi_decode_uint8(add(offset, 164)))
                mstore(add(value, 192), abi_decode_uint32(add(offset, 196)))
                mstore(add(value, 224), abi_decode_uint16(add(offset, 228)))
                mstore(add(value, 256), abi_decode_uint16(add(offset, 260)))
                mstore(add(value, 288), abi_decode_uint32(add(offset, 292)))
                mstore(add(value, 320), abi_decode_address(add(offset, 324)))
                let offset_1 := calldataload(add(offset, 356))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 352), abi_decode_array_struct_FeeConfig_dyn(add(add(offset, offset_1), 4), calldatasize()))
                mstore(add(value, 384), abi_decode_address(add(offset, 388)))
                let offset_2 := calldataload(add(offset, 420))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 416), abi_decode_array_address_dyn(add(add(offset, offset_2), 4), calldatasize()))
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_2 := calldataload(add(offset, 452))
                mstore(add(value, 448), value_2)
                let value_3 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_3 := calldataload(add(offset, 484))
                mstore(add(value, 480), value_3)
                let value1 := abi_decode_address_18989()
                let value2 := abi_decode_contract_IRelay()
                /// @src 0:18392:27162  "function initialize(..."
                modifier_initializer(value, value1, value2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_address_18991())
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function abi_encode_uint256_bool_uint256(headStart, value0, value1, value2) -> tail
            {
                tail := add(headStart, 96)
                mstore(headStart, value0)
                mstore(add(headStart, 32), iszero(iszero(value1)))
                mstore(add(headStart, 64), value2)
            }
            function external_fun_getRandomNumberHistorical()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let ret, ret_1, ret_2 := fun_getRandomNumberHistorical(value)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, ret, ret_1, ret_2), memPos))
            }
            function external_fun_signingPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:14414:14448  "address public signingPolicySetter" */ 3), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function external_fun_getVotingRoundId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let _1 := sload(/** @src 0:97635:97644  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value_1 := and(shr(8, _1), 0xffffffff)
                if /** @src 0:97621:97668  "_timestamp >= stateData.firstVotingRoundStartTs" */ lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value, /** @src 0:97621:97668  "_timestamp >= stateData.firstVotingRoundStartTs" */ value_1)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x7ccf96d5))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                let diff := sub(value, value_1)
                if gt(diff, value) { panic_error_0x11() }
                let value_2 := and(shr(40, _1), 0xff)
                if iszero(value_2) { panic_error_0x12() }
                let memPos := mload(64)
                return(memPos, sub(abi_encode_tuple_bytes32(memPos, div(diff, value_2)), memPos))
            }
            function abi_encode_string(value, pos) -> end
            {
                let length := mload(value)
                mstore(pos, length)
                mcopy(add(pos, 0x20), add(value, 0x20), length)
                mstore(add(add(pos, length), 0x20), /** @src -1:-1:-1 */ 0)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                end := add(add(pos, and(add(length, 31), not(31))), 0x20)
            }
            function external_fun_UPGRADE_INTERFACE_VERSION()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let size := 0
                let _1 := 0
                _1 := 0
                size := 64
                let memPtr := mload(64)
                finalize_allocation(memPtr, 64)
                mstore(memPtr, 5)
                mstore(add(memPtr, 32), "5.0.0")
                let memPos := mload(64)
                mstore(memPos, 32)
                return(memPos, sub(abi_encode_string(memPtr, add(memPos, 32)), memPos))
            }
            function external_fun_getExecuteTimelockedCallTimestamp()
            {
                if callvalue() { revert(0, 0) }
                let param, param_1 := abi_decode_bytes_calldata(calldatasize())
                /// @src 5:4407:4430  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:4407:4430  "keccak256(_encodedCall)" */ param, param_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                mstore(/** @src -1:-1:-1 */ 0, /** @src 5:4407:4430  "keccak256(_encodedCall)" */ keccak256(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:4407:4430  "keccak256(_encodedCall)" */ _mpos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:4407:4430  "keccak256(_encodedCall)" */ _mpos)))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(0x20, /** @src 5:4465:4486  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                /// @src 5:4513:4576  "require(_allowedAfterTimestamp != 0, TimelockInvalidSelector())"
                require_helper_error_TimelockInvalidSelector(/** @src 5:4521:4548  "_allowedAfterTimestamp != 0" */ iszero(iszero(_1)))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(0x40)
                mstore(memPos, _1)
                return(memPos, 0x20)
            }
            function external_fun_relay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:38182:38195  "sourceChainId" */ 0x0e)
                /// @src 0:38261:88845  "assembly {..."
                let usr$memPtr := mload(0x40)
                mstore(add(usr$memPtr, 160), sload(11))
                if lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38261:88845  "assembly {..." */ 15)
                {
                    usr$revertWithError_18997(usr$memPtr)
                }
                let usr$metadata := shr(168, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4))
                /// @src 0:38261:88845  "assembly {..."
                if lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38261:88845  "assembly {..." */ add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 48))
                {
                    usr$revertWithError_18998(usr$memPtr)
                }
                let _2 := usr$calculateSigningPolicyHash_18999(add(usr$memPtr, 288), add(43, mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22)), _1)
                mstore(add(usr$memPtr, 0x40), _2)
                mstore(usr$memPtr, and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215))
                mstore(add(usr$memPtr, 32), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                /// @src 0:38261:88845  "assembly {..."
                let _3 := sload(keccak256(usr$memPtr, 0x40))
                mstore(add(usr$memPtr, 96), _3)
                if iszero(eq(_2, _3))
                {
                    usr$revertWithError_19000(usr$memPtr)
                }
                let usr$signatureStart := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38261:88845  "assembly {..."
                let usr$threshold := and(usr$metadata, 65535)
                if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), 1)
                {
                    let usr$overrideBIPS := tload(49263867947327861046025139002774505900665624735272959673709246929275493786307)
                    if iszero(iszero(usr$overrideBIPS))
                    {
                        usr$threshold := div(mul(usr$calculateTotalWeight(usr$metadata), usr$overrideBIPS), 10000)
                    }
                }
                if iszero(iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47)))))
                {
                    let usr$memPtrGP0 := mload(0x40)
                    usr$signatureStart := add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 85)
                    if lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38261:88845  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithError_19002(usr$memPtrGP0)
                    }
                    calldatacopy(usr$memPtrGP0, add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47), 38)
                    let usr$votingRoundId := and(shr(216, mload(usr$memPtrGP0)), 4294967295)
                    mstore(add(usr$memPtrGP0, 96), shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))))
                    mstore(add(usr$memPtrGP0, 128), 1)
                    mstore(add(usr$memPtrGP0, 128), keccak256(add(usr$memPtrGP0, 96), 0x40))
                    mstore(add(usr$memPtrGP0, 96), usr$votingRoundId)
                    if iszero(iszero(sload(keccak256(add(usr$memPtrGP0, 96), 0x40))))
                    {
                        usr$revertWithError_19003(usr$memPtrGP0)
                    }
                    if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), 1)
                    {
                        if usr$votingRoundId
                        {
                            usr$revertWithError_19004(usr$memPtrGP0)
                        }
                        if cleanup_from_storage_uint8(shr(208, mload(usr$memPtrGP0)))
                        {
                            usr$revertWithError_19006(usr$memPtrGP0)
                        }
                    }
                    let usr$messageRewardEpochId := and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215)
                    let _4 := iszero(eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), 1))
                    if _4
                    {
                        usr$messageRewardEpochId := usr$rewardEpochIdFromVotingRoundId(mload(add(usr$memPtrGP0, 160)), usr$votingRoundId)
                    }
                    if lt(usr$messageRewardEpochId, and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215))
                    {
                        usr$revertWithError_19007(usr$memPtrGP0)
                    }
                    let _5 := mload(add(usr$memPtrGP0, 160))
                    if lt(add(usr$messageRewardEpochId, and(shr(192, _5), 4294967295)), and(shr(152, _5), 4294967295))
                    {
                        usr$revertWithError_19008(usr$memPtrGP0)
                    }
                    if and(_4, lt(usr$votingRoundId, and(shr(184, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 4294967295)))
                    {
                        usr$revertWithError_19009(usr$memPtrGP0)
                    }
                    if gt(usr$messageRewardEpochId, and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215))
                    {
                        let usr$lastInitializedRewardEpoch := extract_from_storage_value_offset_19_uint32(mload(add(usr$memPtrGP0, 160)))
                        if gt(usr$lastInitializedRewardEpoch, and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215))
                        {
                            mstore(add(usr$memPtrGP0, 96), add(and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215), 1))
                            mstore(add(usr$memPtrGP0, 128), 2)
                            if gt(add(usr$votingRoundId, 1), sload(keccak256(add(usr$memPtrGP0, 96), 0x40)))
                            {
                                usr$revertWithError_19011(usr$memPtrGP0)
                            }
                        }
                        if eq(usr$lastInitializedRewardEpoch, and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215))
                        {
                            usr$threshold := div(mul(usr$threshold, usr$structValue(mload(add(usr$memPtrGP0, 160)))), 10000)
                        }
                    }
                    let _6 := add(usr$memPtrGP0, 288)
                    mstore(_6, _1)
                    calldatacopy(add(usr$memPtrGP0, 320), add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47), 38)
                    mstore(add(usr$memPtrGP0, 32), keccak256(_6, 70))
                }
                if iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))))
                {
                    let _7 := mload(0x40)
                    if iszero(iszero(extract_from_storage_value_offset_bool(mload(add(_7, 160))))) { usr$revertWithError_19014(_7) }
                    if lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38261:88845  "assembly {..." */ add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 59))
                    {
                        usr$revertWithError_19015(mload(0x40))
                    }
                    calldatacopy(mload(0x40), add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 48), 11)
                    let _8 := mload(0x40)
                    let _9 := mload(_8)
                    let _10 := shr(240, _9)
                    if iszero(_10) { usr$revertWithError_19016(_8) }
                    if gt(_10, 300)
                    {
                        usr$revertWithError_19017(mload(0x40))
                    }
                    let _11 := mul(_10, 22)
                    usr$signatureStart := add(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), _11), 91)
                    if lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38261:88845  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithError_19018(mload(0x40))
                    }
                    let usr$newSigningPolicyRewardEpochId := and(shr(216, _9), 16777215)
                    let _12 := mload(0x40)
                    let usr$tmpLastInitializedRewardEpochId := extract_from_storage_value_offset_19_uint32(mload(add(_12, 160)))
                    if iszero(eq(usr$tmpLastInitializedRewardEpochId, and(shr(216, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 16777215))) { usr$revertWithError(_12) }
                    if iszero(eq(add(1, usr$tmpLastInitializedRewardEpochId), usr$newSigningPolicyRewardEpochId))
                    {
                        usr$revertWithError_19021(mload(0x40))
                    }
                    usr$checkThresholdConsistency(mload(0x40), shr(168, _9), add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 48))
                    let usr$newSigningPolicyHash := usr$calculateSigningPolicyHash(add(mload(0x40), 288), add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 48), add(43, _11), _1)
                    let _13 := add(mload(0x40), 160)
                    mstore(_13, usr$assignStruct(mload(_13), usr$newSigningPolicyRewardEpochId))
                    mstore(mload(0x40), usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), 2)
                    let _14 := mload(0x40)
                    sstore(keccak256(_14, 0x40), and(shr(184, _9), 4294967295))
                    mstore(_14, usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                    /// @src 0:38261:88845  "assembly {..."
                    let _15 := mload(0x40)
                    sstore(keccak256(_15, 0x40), usr$newSigningPolicyHash)
                    mstore(add(_15, 32), usr$newSigningPolicyHash)
                    mstore(add(mload(0x40), 96), "SigningPolicyRelayed(uint256)")
                    log2(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, /** @src 0:38261:88845  "assembly {..." */ keccak256(add(mload(0x40), 96), 29), usr$newSigningPolicyRewardEpochId)
                }
                let _16 := add(usr$signatureStart, 2)
                if lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38261:88845  "assembly {..." */ _16)
                {
                    usr$revertWithError_19023(usr$memPtr)
                }
                calldatacopy(add(usr$memPtr, 0x40), usr$signatureStart, 2)
                let _17 := shr(240, mload(add(usr$memPtr, 0x40)))
                mstore(add(usr$memPtr, 256), _16)
                if lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38261:88845  "assembly {..." */ add(add(usr$signatureStart, mul(_17, 67)), 2))
                {
                    usr$revertWithError_19024(usr$memPtr)
                }
                mstore(usr$memPtr, "0000\x19Ethereum Signed Message:\n32")
                mstore(usr$memPtr, keccak256(add(usr$memPtr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4), /** @src 0:38261:88845  "assembly {..." */ 60))
                let usr$i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38261:88845  "assembly {..."
                let usr$weight := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38261:88845  "assembly {..."
                let usr$nextUnusedIndex := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38261:88845  "assembly {..."
                let usr$memPtrFor := mload(0x40)
                for { } lt(usr$i, _17) { usr$i := add(usr$i, 1) }
                {
                    mstore(add(usr$memPtrFor, 32), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                    /// @src 0:38261:88845  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 63), add(add(usr$signatureStart, mul(usr$i, 67)), 2), 67)
                    let usr$index := shr(240, mload(add(usr$memPtrFor, 128)))
                    if gt(add(usr$index, 1), shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)))
                    /// @src 0:38261:88845  "assembly {..."
                    {
                        usr$revertWithError_19025(usr$memPtrFor)
                    }
                    if lt(usr$index, usr$nextUnusedIndex)
                    {
                        usr$revertWithError_19026(usr$memPtrFor)
                    }
                    usr$nextUnusedIndex := add(usr$index, 1)
                    let _18 := and(mload(add(usr$memPtrFor, 32)), 0xff)
                    if iszero(or(eq(_18, 27), eq(_18, 28)))
                    {
                        usr$revertWithError_19027(usr$memPtrFor)
                    }
                    if gt(mload(add(usr$memPtrFor, 96)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                    {
                        usr$revertWithError_19028(usr$memPtrFor)
                    }
                    if iszero(staticcall(not(0), 1, usr$memPtrFor, 128, add(usr$memPtrFor, 0x40), 32))
                    {
                        usr$revertWithError_19029(usr$memPtrFor)
                    }
                    if iszero(eq(returndatasize(), 32))
                    {
                        usr$revertWithError_19030(usr$memPtrFor)
                    }
                    if iszero(mload(add(usr$memPtrFor, 0x40)))
                    {
                        usr$revertWithError_19031(usr$memPtrFor)
                    }
                    mstore(add(usr$memPtrFor, 96), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                    /// @src 0:38261:88845  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 106), add(47, mul(usr$index, 22)), 22)
                    if iszero(eq(mload(add(usr$memPtrFor, 0x40)), shr(16, mload(add(usr$memPtrFor, 96)))))
                    {
                        usr$revertWithError_19032(usr$memPtrFor)
                    }
                    usr$weight := add(usr$weight, and(mload(add(usr$memPtrFor, 96)), 65535))
                    if gt(usr$weight, usr$threshold)
                    {
                        if iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))))
                        {
                            sstore(11, mload(add(usr$memPtrFor, 160)))
                            return(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0)
                        }
                        /// @src 0:38261:88845  "assembly {..."
                        if iszero(iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47)))))
                        {
                            let _19 := add(usr$memPtrFor, 192)
                            calldatacopy(_19, add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 53), 32)
                            if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), 1)
                            {
                                mstore(usr$memPtrFor, mload(_19))
                                mstore(add(usr$memPtrFor, 32), and(shl(16, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ shl(232, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 16777215)))
                                /// @src 0:38261:88845  "assembly {..."
                                return(usr$memPtrFor, 35)
                            }
                            if iszero(mload(_19))
                            {
                                usr$revertWithError_19033(usr$memPtrFor)
                            }
                            let usr$votingRoundId_1 := usr$extractVotingRoundIdFromMessage(add(43, mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22)))
                            mstore(usr$memPtrFor, shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))))
                            mstore(add(usr$memPtrFor, 32), 1)
                            mstore(add(usr$memPtrFor, 32), keccak256(usr$memPtrFor, 0x40))
                            mstore(usr$memPtrFor, usr$votingRoundId_1)
                            sstore(keccak256(usr$memPtrFor, 0x40), mload(_19))
                            let _20 := add(usr$memPtrFor, 160)
                            if iszero(eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), cleanup_from_storage_uint8(mload(_20))))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47), 6)
                                let _21 := shr(208, mload(usr$memPtrFor))
                                mstore(usr$memPtrFor, _21)
                                mstore(_20, and(_21, 0xff))
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_20, 0x40, keccak256(add(usr$memPtrFor, 96), 49), shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), usr$votingRoundId_1)
                                return(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0)
                            }
                            /// @src 0:38261:88845  "assembly {..."
                            if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), cleanup_from_storage_uint8(mload(_20)))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47), 6)
                                let usr$isSecure := iszero(iszero(cleanup_from_storage_uint8(shr(208, mload(usr$memPtrFor)))))
                                let _22 := add(usr$memPtrFor, 256)
                                usr$processRandomMerkleProof(usr$memPtrFor, add(mload(_22), mul(_17, 67)), _19, usr$votingRoundId_1, usr$isSecure)
                                if usr$isSecure
                                {
                                    usr$setIsSecureRandomBit(add(usr$memPtrFor, 96), usr$votingRoundId_1)
                                }
                                let _23 := mload(_20)
                                if gt(usr$votingRoundId_1, and(shr(112, _23), 4294967295))
                                {
                                    sstore(11, usr$assignStruct_19038(usr$assignStruct_19037(_23, usr$votingRoundId_1), usr$isSecure))
                                }
                                mstore(_20, usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_20, 0x40, keccak256(add(usr$memPtrFor, 96), 49), shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38261:88845  "assembly {..." */ 22), 47))), usr$votingRoundId_1)
                                calldatacopy(_19, add(mload(_22), mul(_17, 67)), 32)
                                mstore(add(usr$memPtrFor, 224), usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "RandomNumberRelayed(uint32,uint2")
                                mstore(add(usr$memPtrFor, 128), "56,bool)")
                                log2(_19, 0x40, keccak256(add(usr$memPtrFor, 96), 40), usr$votingRoundId_1)
                                return(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0)
                            }
                        }
                        /// @src 0:38261:88845  "assembly {..."
                        usr$revertWithError_19039(mload(0x40))
                    }
                }
                /// @src 0:88873:88890  "NotEnoughWeight()"
                mstore(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 0:88873:88890  "NotEnoughWeight()" */ shl(226, 0x179215cf))
                revert(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 4)
            }
            function external_fun_setFeeCollectionAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address(value)
                /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1893:1923  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:2037:2045  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:35592:35657  "require(signingPolicySetter == address(0), FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:35600:35633  "signingPolicySetter == address(0)" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:35600:35619  "signingPolicySetter" */ 0x03), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                    let _1 := and(/** @src 0:35675:35710  "_feeCollectionAddress != address(0)" */ value, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    /// @src 0:35667:35739  "require(_feeCollectionAddress != address(0), FeeCollectionAddressZero())"
                    require_helper_error_FeeCollectionAddressZero(/** @src 0:35675:35710  "_feeCollectionAddress != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1)))
                    sstore(/** @src 0:35749:35802  "feeCollectionAddress = payable(_feeCollectionAddress)" */ 0x05, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 0:35749:35802  "feeCollectionAddress = payable(_feeCollectionAddress)" */ 0x05), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(160, 0xffffffffffffffffffffffff)), _1))
                    /// @src 0:35817:35863  "FeeCollectionAddressSet(_feeCollectionAddress)"
                    log2(/** @src -1:-1:-1 */ 0, 0, /** @src 0:35817:35863  "FeeCollectionAddressSet(_feeCollectionAddress)" */ 0xfc78a1d0b2aa388b5b987c35079601ed0e4c5a4d38f758a0278449af9d7b9ba2, _1)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_setProtocolFees()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address(value)
                let offset := calldataload(36)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value1, value2 := abi_decode_array_struct_FeeExemption_calldata_dyn_calldata(add(4, offset), calldatasize())
                /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1893:1923  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:2037:2045  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1889:2057  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:34277:34342  "require(signingPolicySetter == address(0), FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:34285:34318  "signingPolicySetter == address(0)" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:34285:34304  "signingPolicySetter" */ 0x03), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                    /// @src 0:34352:34392  "_setProtocolFees(_feeToken, _feeConfigs)"
                    fun_setProtocolFees(value, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_array_struct_FeeConfig_dyn(/** @src 0:34352:34392  "_setProtocolFees(_feeToken, _feeConfigs)" */ value1, value2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize()))
                }
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_verifyCustomSignatureWithThreshold()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 96)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value0, value1 := abi_decode_bytes_calldata_ptr(add(4, offset), calldatasize())
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(36)
                let value_1 := calldataload(68)
                validator_revert_uint16(value_1)
                /// @src 0:33108:33168  "require(_thresholdBIPS < THRESHOLD_BIPS, ThresholdTooHigh())"
                require_helper_error_ThresholdTooHigh(/** @src 0:33116:33147  "_thresholdBIPS < THRESHOLD_BIPS" */ lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:33116:33147  "_thresholdBIPS < THRESHOLD_BIPS" */ value_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff), /** @src 0:7446:7451  "10000" */ 0x2710))
                /// @src 0:33468:33530  "assembly {..."
                tstore(/** @src 0:7997:8063  "0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3" */ 0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3, /** @src 0:33468:33530  "assembly {..." */ value_1)
                /// @src 0:33539:33607  "_rewardEpochId = _verifyCustomSignature(_relayMessage, _messageHash)"
                let var_rewardEpochId := /** @src 0:33556:33607  "_verifyCustomSignature(_relayMessage, _messageHash)" */ fun_verifyCustomSignature(value0, value1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value)
                /// @src 0:33673:33722  "assembly {..."
                tstore(/** @src 0:7997:8063  "0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3" */ 0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3, /** @src -1:-1:-1 */ 0)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                mstore(memPos, var_rewardEpochId)
                return(memPos, 32)
            }
            function external_fun_getRandomNumber()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:96037:96046  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := and(shr(112, _1), 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 0:96015:96036  "toRandomNumberPrivate" */ 0x0c)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _2 := sload(keccak256(0, 0x40))
                let cleaned := and(/** @src 0:96216:96249  "stateData.randomVotingRoundId + 1" */ checked_add_uint32_19043(value), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                /// @src 0:96129:96301  "_randomTimestamp =..."
                let var_randomTimestamp := /** @src 0:96160:96301  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(8, _1), 0xffffffff), /** @src 0:96208:96301  "uint256(stateData.randomVotingRoundId + 1) *..." */ checked_mul_uint256(cleaned, cleanup_from_storage_uint8(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(40, _1), 0xff))))
                let memPos := mload(0x40)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, _2, and(shr(144, _1), 0xff), var_randomTimestamp), memPos))
            }
            function external_fun_getTimelockDurationSeconds()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 5:4063:4092  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_transferOwnership()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address(value)
                /// @src 33:2324:2386  "modifier onlyOwner() {..."
                fun_checkOwner()
                /// @src 33:2378:2379  "_"
                fun_transferOwnership_inner(value)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_cancelTimelockedCall()
            {
                if callvalue() { revert(0, 0) }
                let param, param_1 := abi_decode_bytes_calldata(calldatasize())
                /// @src 33:2324:2386  "modifier onlyOwner() {..."
                fun_checkOwner()
                /// @src 5:3148:3171  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:3148:3171  "keccak256(_encodedCall)" */ param, param_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                /// @src 5:3148:3171  "keccak256(_encodedCall)"
                let expr := keccak256(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:3148:3171  "keccak256(_encodedCall)" */ _mpos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:3148:3171  "keccak256(_encodedCall)" */ _mpos))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:3189:3210  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 5:3181:3260  "require(state.timelockedCalls[encodedCallHash] != 0, TimelockInvalidSelector())"
                require_helper_error_TimelockInvalidSelector(/** @src 5:3189:3232  "state.timelockedCalls[encodedCallHash] != 0" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40)))))
                /// @src 5:3275:3314  "TimelockedCallCanceled(encodedCallHash)"
                let _1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                mstore(_1, expr)
                /// @src 5:3275:3314  "TimelockedCallCanceled(encodedCallHash)"
                log1(_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20, /** @src 5:3275:3314  "TimelockedCallCanceled(encodedCallHash)" */ 0x317f58a0a5e6a501ac25aa9519e1dbad2f1671fe061164a3f1529da5b14362e1)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:3189:3210  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let dataSlot := keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40)
                let result := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                result := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(dataSlot, /** @src -1:-1:-1 */ 0)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_oldRelay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:16456:16478  "IRelay public oldRelay" */ 13), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function extract_from_storage_value_offset_20_uint32(slot_value) -> value
            {
                value := and(shr(160, slot_value), 0xffffffff)
            }
            function abi_decode_bytes32_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                value0 := mload(headStart)
            }
            function revert_forward()
            {
                let pos := mload(64)
                returndatacopy(pos, 0, returndatasize())
                revert(pos, returndatasize())
            }
            function require_helper_error_NoAccessToSigningPolicyHashes(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x6ac41cb3))
                    revert(0, 4)
                }
            }
            /// @ast-id 2086 @src 0:97850:98249  "function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {..."
            function fun_toSigningPolicyHash(var__rewardEpochId) -> var
            {
                /// @src 0:97926:97933  "bytes32"
                var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:97957:97965  "oldRelay" */ 0x0d)
                /// @src 0:97949:97966  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:97949:98021  "address(oldRelay) != address(0) && _rewardEpochId < initialRewardEpochId"
                let expr_1 := /** @src 0:97949:97980  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:97949:97980  "address(oldRelay) != address(0)" */ expr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:97949:98021  "address(oldRelay) != address(0) && _rewardEpochId < initialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:97984:98021  "_rewardEpochId < initialRewardEpochId" */ lt(var__rewardEpochId, cleanup_from_storage_uint32(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_20_uint32(_1)))
                }
                /// @src 0:97945:98099  "if (address(oldRelay) != address(0) && _rewardEpochId < initialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:98044:98088  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:98044:98088  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    mstore(_2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x0c85bf07))
                    /// @src 0:98044:98088  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_tuple_bytes32(add(_2, 4), var__rewardEpochId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:98044:98088  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_2 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:98037:98088  "return oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    var := expr_2
                    leave
                }
                /// @src 0:98108:98183  "require(signingPolicySetter != address(0), NoAccessToSigningPolicyHashes())"
                require_helper_error_NoAccessToSigningPolicyHashes(/** @src 0:98116:98149  "signingPolicySetter != address(0)" */ iszero(iszero(cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:98116:98135  "signingPolicySetter" */ 0x03))))))
                /// @src 0:98193:98242  "return toSigningPolicyHashPrivate[_rewardEpochId]"
                var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:98200:98242  "toSigningPolicyHashPrivate[_rewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19046(var__rewardEpochId))
            }
            /// @src 5:1578:1584  "7 days"
            function require_helper_error_TimelockDurationTooLong(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xef478505))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_uint256_to_uint256(value)
            {
                sstore(/** @src 0:24535:24579  "sourceChainId = _initialConfig.sourceChainId" */ 0x0e, /** @src 5:1578:1584  "7 days" */ value)
            }
            function update_storage_value_offset_t_uint256_to_t_uint256(value)
            {
                sstore(/** @src 0:25062:25096  "getState().timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01, /** @src 5:1578:1584  "7 days" */ value)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function require_helper_error_TimelockInvalidSelector(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(226, 0x023679b7))
                    revert(0, 4)
                }
            }
            function update_byte_slice_dynamic32(value, shiftBytes, toInsert) -> result
            {
                let shiftBits := shl(3, shiftBytes)
                result := or(and(value, not(shl(shiftBits, /** @src 0:38261:88845  "assembly {..." */ not(0)))), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(shiftBits, toInsert))
            }
            function update_storage_value_uint256_to_uint256(slot, offset, value)
            {
                sstore(slot, update_byte_slice_dynamic32(sload(slot), offset, value))
            }
            function update_storage_value_offset_bool_to_bool_18957()
            {
                sstore(/** @src 5:1796:1838  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 5:1796:1838  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(255)), /** @src 5:2641:2645  "true" */ 0x01))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function update_storage_value_offset_bool_to_bool_18958()
            {
                sstore(/** @src 5:1796:1838  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 5:1796:1838  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(255)))
            }
            function update_storage_value_offset_bool_to_bool_19134(slot)
            {
                sstore(slot, or(and(sload(slot), not(255)), /** @src 0:20826:20827  "1" */ 0x01))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function update_storage_value_offset_0_bool_to_bool(slot, value)
            {
                let value_1 := and(sload(slot), not(255))
                sstore(slot, or(value_1, and(iszero(iszero(value)), 255)))
            }
            function abi_encode_bytes_calldata(start, length, pos) -> end
            {
                calldatacopy(pos, start, length)
                let _1 := add(pos, length)
                mstore(_1, 0)
                end := _1
            }
            function extract_returndata() -> data
            {
                switch returndatasize()
                case 0 { data := 96 }
                default {
                    let _1 := returndatasize()
                    let _2 := array_allocation_size_bytes(_1)
                    let memPtr := mload(64)
                    finalize_allocation(memPtr, _2)
                    mstore(memPtr, _1)
                    data := memPtr
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ returndatasize())
                }
            }
            function validator_revert_bool(value)
            {
                if iszero(eq(value, iszero(iszero(value)))) { revert(0, 0) }
            }
            function abi_decode_t_bool_fromMemory(offset) -> value
            {
                value := mload(offset)
                validator_revert_bool(value)
            }
            function abi_decode_bool_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let value := mload(headStart)
                validator_revert_bool(value)
                value0 := value
            }
            function abi_encode_uint256_uint256(headStart, value0, value1) -> tail
            {
                tail := add(headStart, 64)
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
            }
            /// @ast-id 1825 @src 0:94401:94946  "function isFinalized(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_isFinalized(var__protocolId, var_votingRoundId) -> var
            {
                /// @src 0:94506:94510  "bool"
                var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:94538:94546  "oldRelay" */ 0x0d)
                /// @src 0:94530:94547  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:94530:94626  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr_1 := /** @src 0:94530:94561  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:94530:94561  "address(oldRelay) != address(0)" */ expr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:94530:94626  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:94565:94626  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, cleanup_from_storage_uint32(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:94526:94709  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:94649:94698  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:94649:94698  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(226, 0x0c5eb4cf))
                    /// @src 0:94649:94698  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var__protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:94649:94698  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_2 := abi_decode_bool_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:94642:94698  "return oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    var := expr_2
                    leave
                }
                /// @src 0:94871:94939  "return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)"
                var := /** @src 0:94878:94939  "merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:94878:94925  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:94878:94909  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19054(var__protocolId), /** @src 0:94878:94925  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function require_helper_error_FeeExemptionsNotAllowed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x7eac2661))
                    revert(0, 4)
                }
            }
            function panic_error_0x32()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x32)
                revert(0, 0x24)
            }
            function calldata_array_index_access_struct_FeeExemption_calldata_dyn_calldata(base_ref, length, index) -> addr
            {
                if iszero(lt(index, length)) { panic_error_0x32() }
                addr := add(base_ref, shl(6, index))
            }
            function read_from_calldatat_address(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                validator_revert_address(value)
                returnValue := value
            }
            function require_helper_error_FeeExemptAddressZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x7075186f))
                    revert(0, 4)
                }
            }
            function read_from_calldatat_bool(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                validator_revert_bool(value)
                returnValue := value
            }
            function require_helper_error_NoAccessToMerkleRoots(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(226, 0x2d98205b))
                    revert(0, 4)
                }
            }
            /// @ast-id 1874 @src 0:94994:95464  "function merkleRoots(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_merkleRoots(var_protocolId, var_votingRoundId) -> var_merkleRoot
            {
                /// @src 0:95099:95118  "bytes32 _merkleRoot"
                var_merkleRoot := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:95146:95154  "oldRelay" */ 0x0d)
                /// @src 0:95138:95155  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:95138:95234  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr_1 := /** @src 0:95138:95169  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:95138:95169  "address(oldRelay) != address(0)" */ expr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:95138:95234  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:95173:95234  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, cleanup_from_storage_uint32(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:95134:95317  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:95257:95306  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:95257:95306  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(232, 3752811))
                    /// @src 0:95257:95306  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var_protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:95257:95306  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_2 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:95250:95306  "return oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    var_merkleRoot := expr_2
                    leave
                }
                /// @src 0:95326:95393  "require(signingPolicySetter != address(0), NoAccessToMerkleRoots())"
                require_helper_error_NoAccessToMerkleRoots(/** @src 0:95334:95367  "signingPolicySetter != address(0)" */ iszero(iszero(cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:95334:95353  "signingPolicySetter" */ 0x03))))))
                /// @src 0:95403:95457  "return merkleRootsPrivate[_protocolId][_votingRoundId]"
                var_merkleRoot := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:95410:95457  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:95410:95441  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19054(var_protocolId), /** @src 0:95410:95457  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function update_storage_value_offset_address_to_address(value)
            {
                sstore(/** @src 0:22810:22868  "feeCollectionAddress = _initialConfig.feeCollectionAddress" */ 0x05, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 0:22810:22868  "feeCollectionAddress = _initialConfig.feeCollectionAddress" */ 0x05), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(160, 0xffffffffffffffffffffffff)), and(value, sub(shl(160, 1), 1))))
            }
            function update_storage_value_offset_t_address_to_t_address(value)
            {
                sstore(/** @src 0:22423:22465  "signingPolicySetter = _signingPolicySetter" */ 0x03, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 0:22423:22465  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(160, 0xffffffffffffffffffffffff)), and(value, sub(shl(160, 1), 1))))
            }
            function update_storage_value_offset_address_to_address_19138(value)
            {
                sstore(/** @src 0:19952:20010  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x0d, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 0:19952:20010  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x0d), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(160, 0xffffffffffffffffffffffff)), and(value, sub(shl(160, 1), 1))))
            }
            function update_storage_value_offset_address_to_address_19259(value)
            {
                sstore(/** @src 0:99922:99942  "feeToken = _feeToken" */ 0x06, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 0:99922:99942  "feeToken = _feeToken" */ 0x06), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(160, 0xffffffffffffffffffffffff)), and(value, sub(shl(160, 1), 1))))
            }
            function write_to_memory_uint8(memPtr, value)
            {
                mstore(memPtr, and(value, 0xff))
            }
            function memory_array_index_access_struct_FeeConfig_dyn(baseRef, index) -> addr
            {
                if iszero(lt(index, mload(baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, shl(5, index)), 32)
            }
            function require_helper_error_InvalidProtocolId(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x55e7c3d9))
                    revert(0, 4)
                }
            }
            function read_from_storage_split_offset_bool(slot) -> value
            {
                value := and(sload(slot), 0xff)
            }
            function require_helper_error_MsgValueNotAllowed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x6eaeea27))
                    revert(0, 4)
                }
            }
            function require_helper_error_TooLowFee(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x54f87649))
                    revert(0, 4)
                }
            }
            function require_helper_error_NotFinalized(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x0df706ad))
                    revert(0, 4)
                }
            }
            function require_helper_error_MerkleProofInvalid(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xc8ac23c3))
                    revert(0, 4)
                }
            }
            function require_helper_error_FeeTransferFailed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x4033e4e3))
                    revert(0, 4)
                }
            }
            function panic_error_0x11()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x11)
                revert(0, 0x24)
            }
            function checked_sub_uint256_19148(y) -> diff
            {
                diff := sub(/** @src 0:97214:97217  "255" */ 0xff, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ y)
                if gt(diff, /** @src 0:97214:97217  "255" */ 0xff)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_19254(x) -> diff
            {
                diff := add(x, /** @src 0:38261:88845  "assembly {..." */ not(0))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if gt(diff, x) { panic_error_0x11() }
            }
            function checked_sub_uint256(x, y) -> diff
            {
                diff := sub(x, y)
                if gt(diff, x) { panic_error_0x11() }
            }
            function require_helper_error_RefundFailed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(226, 0x3c312751))
                    revert(0, 4)
                }
            }
            function abi_encode_uint256_uint256_bytes32_array_bytes32_dyn_calldata(headStart, value0, value1, value2, value3, value4) -> tail
            {
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
                mstore(add(headStart, 64), value2)
                mstore(add(headStart, 96), 128)
                mstore(add(headStart, 128), value4)
                if gt(value4, sub(shl(251, 1), 1)) { revert(0, 0) }
                let length := shl(5, value4)
                calldatacopy(add(headStart, 160), value3, length)
                tail := add(add(headStart, length), 160)
            }
            function require_helper_error_OldRelayVerificationFailed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x917dd4e5))
                    revert(0, 4)
                }
            }
            /// @ast-id 1701 @src 0:88945:93453  "function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)..."
            function fun_verify(var_protocolId, var_votingRoundId, var__leaf, var_proof_offset, var_proof_length) -> var
            {
                /// @src 0:89090:89094  "bool"
                var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:89605:89613  "oldRelay" */ 0x0d)
                /// @src 0:89597:89693  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:89597:89628  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:89597:89614  "address(oldRelay)" */ cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1)), sub(shl(160, 1), 1))))
                /// @src 0:89597:89693  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:89632:89693  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, cleanup_from_storage_uint32(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:89593:93425  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                switch expr
                case 0 {
                    /// @src 0:91034:91079  "require(_protocolId > 1, InvalidProtocolId())"
                    require_helper_error_InvalidProtocolId(/** @src 0:91042:91057  "_protocolId > 1" */ gt(var_protocolId, /** @src 0:91056:91057  "1" */ 0x01))
                    /// @src 0:91298:91326  "feeExemptAddress[msg.sender]"
                    let _2 := read_from_storage_split_offset_bool(mapping_index_access_mapping_address_bool_of_address(/** @src 0:91315:91325  "msg.sender" */ caller()))
                    /// @src 0:91298:91357  "feeExemptAddress[msg.sender] ? 0 : protocolFee[_protocolId]"
                    let expr_1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:91298:91357  "feeExemptAddress[msg.sender] ? 0 : protocolFee[_protocolId]"
                    switch _2
                    case 0 {
                        expr_1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:91333:91357  "protocolFee[_protocolId]" */ mapping_index_access_mapping_uint256__uint256__of_uint256(var_protocolId))
                    }
                    default /// @src 0:91298:91357  "feeExemptAddress[msg.sender] ? 0 : protocolFee[_protocolId]"
                    {
                        expr_1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    }
                    let _3 := and(cleanup_address_payable(sload(/** @src 0:91387:91395  "feeToken" */ 0x06)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    /// @src 0:91413:91432  "token == address(0)"
                    let expr_2 := iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _3)
                    /// @src 0:91409:91782  "if (token == address(0)) {..."
                    switch expr_2
                    case 0 {
                        /// @src 0:91722:91767  "require(msg.value == 0, MsgValueNotAllowed())"
                        require_helper_error_MsgValueNotAllowed(/** @src 0:91730:91744  "msg.value == 0" */ iszero(/** @src 0:91730:91739  "msg.value" */ callvalue()))
                    }
                    default /// @src 0:91409:91782  "if (token == address(0)) {..."
                    {
                        /// @src 0:91452:91490  "require(msg.value >= fee, TooLowFee())"
                        require_helper_error_TooLowFee(/** @src 0:91460:91476  "msg.value >= fee" */ iszero(lt(/** @src 0:91460:91469  "msg.value" */ callvalue(), /** @src 0:91460:91476  "msg.value >= fee" */ expr_1)))
                    }
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _4 := sload(/** @src 0:91883:91930  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:91883:91914  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19054(var_protocolId), /** @src 0:91883:91930  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
                    /// @src 0:91944:91987  "require(root != bytes32(0), NotFinalized())"
                    require_helper_error_NotFinalized(/** @src 0:91952:91970  "root != bytes32(0)" */ iszero(iszero(_4)))
                    /// @src 0:92001:92066  "require(_proof.verifyCalldata(root, _leaf), MerkleProofInvalid())"
                    require_helper_error_MerkleProofInvalid(/** @src 0:92009:92043  "_proof.verifyCalldata(root, _leaf)" */ fun_verifyCalldata(var_proof_offset, var_proof_length, _4, var__leaf))
                    /// @src 0:92514:93415  "if (token == address(0)) {..."
                    switch expr_2
                    case 0 {
                        /// @src 0:93300:93415  "if (fee > 0) {..."
                        if /** @src 0:93304:93311  "fee > 0" */ iszero(iszero(expr_1))
                        /// @src 0:93300:93415  "if (fee > 0) {..."
                        {
                            /// @src 0:93331:93400  "IERC20(token).safeTransferFrom(msg.sender, feeCollectionAddress, fee)"
                            fun_safeTransferFrom(_3, /** @src 0:91315:91325  "msg.sender" */ caller(), /** @src 0:93331:93400  "IERC20(token).safeTransferFrom(msg.sender, feeCollectionAddress, fee)" */ cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:93374:93394  "feeCollectionAddress" */ 0x05))), /** @src 0:93331:93400  "IERC20(token).safeTransferFrom(msg.sender, feeCollectionAddress, fee)" */ expr_1)
                        }
                    }
                    default /// @src 0:92514:93415  "if (token == address(0)) {..."
                    {
                        /// @src 0:92557:92920  "if (fee > 0) {..."
                        if /** @src 0:92561:92568  "fee > 0" */ iszero(iszero(expr_1))
                        /// @src 0:92557:92920  "if (fee > 0) {..."
                        {
                            /// @src 0:92740:92781  "feeCollectionAddress.call{value: fee}(\"\")"
                            let expr_1641_component := call(gas(), /** @src 0:92740:92765  "feeCollectionAddress.call" */ cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:92740:92760  "feeCollectionAddress" */ 0x05))), /** @src 0:92740:92781  "feeCollectionAddress.call{value: fee}(\"\")" */ expr_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, 0, 0)
                            /// @src 0:92740:92781  "feeCollectionAddress.call{value: fee}(\"\")"
                            pop(extract_returndata())
                            /// @src 0:92866:92901  "require(feeOk, FeeTransferFailed())"
                            require_helper_error_FeeTransferFailed(expr_1641_component)
                        }
                        /// @src 0:92954:92969  "msg.value - fee"
                        let expr_3 := checked_sub_uint256(/** @src 0:92954:92963  "msg.value" */ callvalue(), /** @src 0:92954:92969  "msg.value - fee" */ expr_1)
                        /// @src 0:92987:93280  "if (refund > 0) {..."
                        if /** @src 0:92991:93001  "refund > 0" */ iszero(iszero(expr_3))
                        /// @src 0:92987:93280  "if (refund > 0) {..."
                        {
                            /// @src 0:93109:93143  "msg.sender.call{value: refund}(\"\")"
                            let expr_1669_component := call(gas(), /** @src 0:91315:91325  "msg.sender" */ caller(), /** @src 0:93109:93143  "msg.sender.call{value: refund}(\"\")" */ expr_3, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, 0, 0)
                            /// @src 0:93109:93143  "msg.sender.call{value: refund}(\"\")"
                            pop(extract_returndata())
                            /// @src 0:93228:93261  "require(refundOk, RefundFailed())"
                            require_helper_error_RefundFailed(expr_1669_component)
                        }
                    }
                }
                default /// @src 0:89593:93425  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                {
                    /// @src 0:90566:90581  "oldRelay.verify"
                    let expr_address := cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:89605:89613  "oldRelay" */ 0x0d)))
                    /// @src 0:90566:90625  "oldRelay.verify(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _5 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:90566:90625  "oldRelay.verify(_protocolId, _votingRoundId, _leaf, _proof)"
                    mstore(_5, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x40428355))
                    /// @src 0:90566:90625  "oldRelay.verify(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _6 := call(gas(), expr_address, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 0:90566:90625  "oldRelay.verify(_protocolId, _votingRoundId, _leaf, _proof)" */ _5, sub(abi_encode_uint256_uint256_bytes32_array_bytes32_dyn_calldata(add(_5, 4), var_protocolId, var_votingRoundId, var__leaf, var_proof_offset, var_proof_length), _5), _5, 32)
                    if iszero(_6) { revert_forward() }
                    let expr_4 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:90566:90625  "oldRelay.verify(_protocolId, _votingRoundId, _leaf, _proof)"
                    if _6
                    {
                        let _7 := 32
                        if gt(32, returndatasize()) { _7 := returndatasize() }
                        finalize_allocation(_5, _7)
                        expr_4 := abi_decode_bool_fromMemory(_5, add(_5, _7))
                    }
                    /// @src 0:90639:90680  "require(ok, OldRelayVerificationFailed())"
                    require_helper_error_OldRelayVerificationFailed(expr_4)
                    /// @src 0:90694:90979  "if (msg.value > 0) {..."
                    if /** @src 0:90698:90711  "msg.value > 0" */ iszero(iszero(/** @src 0:90698:90707  "msg.value" */ callvalue()))
                    /// @src 0:90694:90979  "if (msg.value > 0) {..."
                    {
                        /// @src 0:90814:90851  "msg.sender.call{value: msg.value}(\"\")"
                        let expr_component := call(gas(), /** @src 0:90814:90824  "msg.sender" */ caller(), /** @src 0:90698:90707  "msg.value" */ callvalue(), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, 0, 0)
                        /// @src 0:90814:90851  "msg.sender.call{value: msg.value}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:90928:90964  "require(oldRefundOk, RefundFailed())"
                        require_helper_error_RefundFailed(expr_component)
                    }
                    /// @src 0:90992:91003  "return true"
                    var := /** @src 0:90999:91003  "true" */ 0x01
                    /// @src 0:90992:91003  "return true"
                    leave
                }
                /// @src 0:93435:93446  "return true"
                var := /** @src 0:93442:93446  "true" */ 0x01
            }
            /// @ast-id 492 @src 0:17259:17395  "modifier onlySigningPolicySetter() {..."
            function modifier_onlySigningPolicySetter(var_signingPolicy_mpos) -> _1
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(/** @src 0:17312:17345  "msg.sender == signingPolicySetter" */ eq(/** @src 0:17312:17322  "msg.sender" */ caller(), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:17326:17345  "signingPolicySetter" */ 0x03), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x5c4fa5b5))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 0:27727:27767  "stateData.lastInitializedRewardEpoch + 1"
                let expr := checked_add_uint32_19043(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_19_uint32(sload(/** @src 0:27727:27736  "stateData" */ 0x0b)))
                /// @src 0:27719:27822  "require(stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId, NotNextRewardEpoch())"
                require_helper_error_NotNextRewardEpoch(/** @src 0:27727:27799  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:27727:27799  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ expr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), /** @src 0:27727:27799  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ cleanup_uint24(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:27771:27799  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))))
                /// @src 0:28143:28164  "_signingPolicy.voters"
                let _2 := add(var_signingPolicy_mpos, 128)
                /// @src 0:28135:28198  "require(_signingPolicy.voters.length > 0, SigningPolicyEmpty())"
                require_helper_error_SigningPolicyEmpty(/** @src 0:28143:28175  "_signingPolicy.voters.length > 0" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28143:28164  "_signingPolicy.voters" */ mload(_2)))))
                /// @src 0:28208:28276  "require(_signingPolicy.voters.length <= MAX_VOTERS, TooManyVoters())"
                require_helper_error_TooManyVoters(/** @src 0:28216:28258  "_signingPolicy.voters.length <= MAX_VOTERS" */ iszero(gt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28216:28237  "_signingPolicy.voters" */ mload(_2)), /** @src 0:7544:7547  "300" */ 0x012c)))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let length := mload(/** @src 0:28294:28315  "_signingPolicy.voters" */ mload(_2))
                /// @src 0:28326:28348  "_signingPolicy.weights"
                let _3 := add(var_signingPolicy_mpos, 160)
                /// @src 0:28286:28385  "require(_signingPolicy.voters.length == _signingPolicy.weights.length, VotersWeightsSizeMismatch())"
                require_helper_error_VotersWeightsSizeMismatch(/** @src 0:28294:28355  "_signingPolicy.voters.length == _signingPolicy.weights.length" */ eq(length, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28326:28348  "_signingPolicy.weights" */ mload(_3))))
                /// @src 0:28395:28418  "uint256 totalWeight = 0"
                let var_totalWeight := /** @src -1:-1:-1 */ 0
                /// @src 0:28433:28446  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 0:28428:28553  "for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {..."
                for { }
                /** @src 0:27766:27767  "1" */ 0x01
                /// @src 0:28433:28446  "uint256 i = 0"
                {
                    /// @src 0:28483:28486  "i++"
                    var_i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:28483:28486  "i++" */ var_i, /** @src 0:27766:27767  "1" */ 0x01)
                }
                /// @src 0:28483:28486  "i++"
                {
                    /// @src 0:28452:28474  "_signingPolicy.weights"
                    let _mpos := mload(_3)
                    /// @src 0:28448:28481  "i < _signingPolicy.weights.length"
                    if iszero(lt(var_i, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28452:28481  "_signingPolicy.weights.length" */ _mpos)))
                    /// @src 0:28448:28481  "i < _signingPolicy.weights.length"
                    { break }
                    /// @src 0:28502:28542  "totalWeight += _signingPolicy.weights[i]"
                    var_totalWeight := checked_add_uint256(var_totalWeight, cleanup_from_storage_uint16(/** @src 0:28517:28542  "_signingPolicy.weights[i]" */ read_from_memoryt_uint16(memory_array_index_access_struct_FeeConfig_dyn(_mpos, var_i))))
                }
                /// @src 0:28562:28611  "require(totalWeight < 2**16, TotalWeightTooBig())"
                require_helper_error_TotalWeightTooBig(/** @src 0:28570:28589  "totalWeight < 2**16" */ lt(var_totalWeight, /** @src 0:28584:28589  "2**16" */ 0x010000))
                /// @src 0:28650:28674  "_signingPolicy.threshold"
                let _4 := add(var_signingPolicy_mpos, 64)
                /// @src 0:28642:28701  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_1 := checked_mul_uint256_19082(/** @src 0:28642:28675  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:28650:28674  "_signingPolicy.threshold" */ _4))))
                /// @src 0:28621:28778  "require(..."
                require_helper_error_ThresholdTooLow(/** @src 0:28642:28737  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS" */ iszero(lt(expr_1, /** @src 0:28705:28737  "totalWeight * MIN_THRESHOLD_BIPS" */ checked_mul_uint256_19083(var_totalWeight))))
                /// @src 0:28809:28868  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_2 := checked_mul_uint256_19082(/** @src 0:28809:28842  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:28817:28841  "_signingPolicy.threshold" */ _4))))
                /// @src 0:28788:28946  "require(..."
                require_helper_error_ThresholdTooHigh(/** @src 0:28809:28904  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS" */ iszero(gt(expr_2, /** @src 0:28872:28904  "totalWeight * MAX_THRESHOLD_BIPS" */ checked_mul_uint256_19085(var_totalWeight))))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let length_1 := mload(/** @src 0:28982:29003  "_signingPolicy.voters" */ mload(_2))
                /// @src 0:29043:29114  "SIGNING_POLICY_PREFIX_BYTES + numberOfVoters * ADDRESS_AND_WEIGHT_BYTES"
                let expr_3 := checked_add_uint256_19087(/** @src 0:29073:29114  "numberOfVoters * ADDRESS_AND_WEIGHT_BYTES" */ checked_mul_uint256_19086(length_1))
                /// @src 0:29329:29357  "new bytes(policyLength + 32)"
                let expr_mpos := allocate_and_zero_memory_array_bytes(/** @src 0:29339:29356  "policyLength + 32" */ checked_add_uint256_19088(expr_3))
                /// @src 0:29367:29456  "assembly (\"memory-safe\") {..."
                mstore(expr_mpos, expr_3)
                /// @src 0:29743:29771  "_signingPolicy.rewardEpochId"
                let _5 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:29743:29771  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:29785:29818  "_signingPolicy.startVotingRoundId"
                let _6 := add(var_signingPolicy_mpos, /** @src 0:29354:29356  "32" */ 0x20)
                /// @src 0:29785:29818  "_signingPolicy.startVotingRoundId"
                let _7 := /** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:29785:29818  "_signingPolicy.startVotingRoundId" */ _6))
                /// @src 0:29832:29856  "_signingPolicy.threshold"
                let _8 := /** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:29832:29856  "_signingPolicy.threshold" */ _4))
                /// @src 0:29870:29889  "_signingPolicy.seed"
                let _9 := add(var_signingPolicy_mpos, 96)
                /// @src 0:9417:9419  "22"
                let _10 := mload(/** @src 0:29870:29889  "_signingPolicy.seed" */ _9)
                /// @src 0:29677:29899  "abi.encodePacked(..."
                let expr_mpos_1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28650:28674  "_signingPolicy.threshold" */ 64)
                /// @src 0:29677:29899  "abi.encodePacked(..."
                let _11 := add(expr_mpos_1, /** @src 0:29354:29356  "32" */ 0x20)
                /// @src 0:29677:29899  "abi.encodePacked(..."
                let _12 := sub(abi_encode_packed_uint16_uint24_uint32_uint16_uint256(_11, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:29707:29729  "uint16(numberOfVoters)" */ length_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff), /** @src 0:29677:29899  "abi.encodePacked(..." */ _5, _7, _8, _10), expr_mpos_1)
                mstore(expr_mpos_1, add(_12, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(31)))
                /// @src 0:29677:29899  "abi.encodePacked(..."
                finalize_allocation(expr_mpos_1, _12)
                /// @src 0:29909:30042  "assembly (\"memory-safe\") {..."
                mcopy(add(expr_mpos, /** @src 0:29354:29356  "32" */ 0x20), /** @src 0:29909:30042  "assembly (\"memory-safe\") {..." */ _11, /** @src 0:9555:9557  "43" */ 0x2b)
                /// @src 0:30056:30069  "uint256 i = 0"
                let var_i_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:30051:30773  "for (uint256 i = 0; i < numberOfVoters; i++) {..."
                for { }
                /** @src 0:30071:30089  "i < numberOfVoters" */ lt(var_i_1, length_1)
                /// @src 0:30056:30069  "uint256 i = 0"
                {
                    /// @src 0:30091:30094  "i++"
                    var_i_1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:30091:30094  "i++" */ var_i_1, /** @src 0:27766:27767  "1" */ 0x01)
                }
                /// @src 0:30091:30094  "i++"
                {
                    /// @src 0:30126:30150  "_signingPolicy.voters[i]"
                    let _13 := read_from_memoryt_address(memory_array_index_access_struct_FeeConfig_dyn(/** @src 0:30126:30147  "_signingPolicy.voters" */ mload(_2), /** @src 0:30126:30150  "_signingPolicy.voters[i]" */ var_i_1))
                    /// @src 0:30164:30206  "uint256 weight = _signingPolicy.weights[i]"
                    let var_weight := cleanup_from_storage_uint16(/** @src 0:30181:30206  "_signingPolicy.weights[i]" */ read_from_memoryt_uint16(memory_array_index_access_struct_FeeConfig_dyn(/** @src 0:30181:30203  "_signingPolicy.weights" */ mload(_3), /** @src 0:30181:30206  "_signingPolicy.weights[i]" */ var_i_1)))
                    /// @src 0:30220:30763  "assembly (\"memory-safe\") {..."
                    let _14 := add(expr_mpos, mul(var_i_1, /** @src 0:9417:9419  "22" */ 0x16))
                    /// @src 0:30220:30763  "assembly (\"memory-safe\") {..."
                    mstore(add(_14, 75), shl(/** @src 0:29870:29889  "_signingPolicy.seed" */ 96, /** @src 0:30220:30763  "assembly (\"memory-safe\") {..." */ _13))
                    mstore(add(_14, 95), shl(240, var_weight))
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _15 := sload(/** @src 0:31360:31373  "sourceChainId" */ 0x0e)
                /// @src 0:31343:31394  "abi.encodePacked(sourceChainId, signingPolicyBytes)"
                let expr_mpos_2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28650:28674  "_signingPolicy.threshold" */ 64)
                /// @src 0:31343:31394  "abi.encodePacked(sourceChainId, signingPolicyBytes)"
                let _16 := add(expr_mpos_2, /** @src 0:29354:29356  "32" */ 0x20)
                /// @src 0:31343:31394  "abi.encodePacked(sourceChainId, signingPolicyBytes)"
                let _17 := sub(abi_encode_packed_uint256_bytes(_16, _15, expr_mpos), expr_mpos_2)
                mstore(expr_mpos_2, add(_17, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(31)))
                /// @src 0:31343:31394  "abi.encodePacked(sourceChainId, signingPolicyBytes)"
                finalize_allocation(expr_mpos_2, _17)
                /// @src 0:31333:31395  "keccak256(abi.encodePacked(sourceChainId, signingPolicyBytes))"
                let expr_4 := keccak256(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _16, mload(/** @src 0:31333:31395  "keccak256(abi.encodePacked(sourceChainId, signingPolicyBytes))" */ expr_mpos_2))
                /// @src 5:1578:1584  "7 days"
                sstore(/** @src 0:31405:31461  "toSigningPolicyHashPrivate[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256__bytes32__of_uint24(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:31432:31460  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))), /** @src 5:1578:1584  "7 days" */ expr_4)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _18 := cleanup_uint24(mload(/** @src 0:31524:31552  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:31485:31552  "stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId"
                update_storage_value_offset_t_uint32_to_t_uint32(cleanup_uint24(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _18))
                /// @src 5:1578:1584  "7 days"
                sstore(/** @src 0:31562:31614  "startingVotingRoundIds[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _18), /** @src 0:31562:31650  "startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy.startVotingRoundId" */ cleanup_from_storage_uint32(/** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:31617:31650  "_signingPolicy.startVotingRoundId" */ _6))))
                /// @src 0:31703:31731  "_signingPolicy.rewardEpochId"
                let _19 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:31703:31731  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:31745:31778  "_signingPolicy.startVotingRoundId"
                let _20 := /** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:31745:31778  "_signingPolicy.startVotingRoundId" */ _6))
                /// @src 0:31792:31816  "_signingPolicy.threshold"
                let _21 := /** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:31792:31816  "_signingPolicy.threshold" */ _4))
                /// @src 0:9417:9419  "22"
                let _22 := mload(/** @src 0:31830:31849  "_signingPolicy.seed" */ _9)
                /// @src 0:31863:31884  "_signingPolicy.voters"
                let _mpos_1 := mload(_2)
                /// @src 0:31898:31920  "_signingPolicy.weights"
                let _mpos_2 := mload(_3)
                /// @src 0:31665:31999  "SigningPolicyInitialized(..."
                let _23 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28650:28674  "_signingPolicy.threshold" */ 64)
                /// @src 0:31665:31999  "SigningPolicyInitialized(..."
                log2(_23, sub(abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(_23, _20, _21, _22, _mpos_1, _mpos_2, expr_mpos, /** @src 0:9417:9419  "22" */ and(/** @src 0:31973:31988  "block.timestamp" */ timestamp(), /** @src 0:9417:9419  "22" */ 0xffffffffffffffff)), /** @src 0:31665:31999  "SigningPolicyInitialized(..." */ _23), 0x91d0280e969157fc6c5b8f952f237b03d934b18534dafcac839075bbc33522f8, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:31665:31999  "SigningPolicyInitialized(..." */ _19, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffff))
                /// @src 0:17387:17388  "_"
                _1 := expr_4
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function checked_add_uint32_19043(x) -> sum
            {
                sum := add(and(x, 0xffffffff), 1)
                if gt(sum, 0xffffffff) { panic_error_0x11() }
            }
            function checked_add_uint32(x, y) -> sum
            {
                sum := add(and(x, 0xffffffff), and(y, 0xffffffff))
                if gt(sum, 0xffffffff) { panic_error_0x11() }
            }
            function require_helper_error_NotNextRewardEpoch(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x124f824d))
                    revert(0, 4)
                }
            }
            function require_helper_error_SigningPolicyEmpty(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x29e11b6d))
                    revert(0, 4)
                }
            }
            /// @src 0:7544:7547  "300"
            function require_helper_error_TooManyVoters(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x4647aac9))
                    revert(0, 4)
                }
            }
            function require_helper_error_VotersWeightsSizeMismatch(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x72f0e451))
                    revert(0, 4)
                }
            }
            function read_from_memoryt_uint16(ptr) -> returnValue
            {
                returnValue := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7544:7547  "300" */ mload(ptr), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff)
            }
            /// @src 0:7544:7547  "300"
            function checked_add_uint256_19087(y) -> sum
            {
                sum := add(/** @src 0:9555:9557  "43" */ 0x2b, /** @src 0:7544:7547  "300" */ y)
                if gt(/** @src 0:9555:9557  "43" */ 0x2b, /** @src 0:7544:7547  "300" */ sum) { panic_error_0x11() }
            }
            function checked_add_uint256_19088(x) -> sum
            {
                sum := add(x, /** @src 0:29354:29356  "32" */ 0x20)
                /// @src 0:7544:7547  "300"
                if gt(x, sum) { panic_error_0x11() }
            }
            function checked_add_uint256_19149(x) -> sum
            {
                sum := add(x, /** @src 0:96965:96983  "merkleRootsPrivate" */ 0x01)
                /// @src 0:7544:7547  "300"
                if gt(x, sum) { panic_error_0x11() }
            }
            function checked_add_uint256(x, y) -> sum
            {
                sum := add(x, y)
                if gt(x, sum) { panic_error_0x11() }
            }
            function require_helper_error_TotalWeightTooBig(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x8dd23571))
                    revert(0, 4)
                }
            }
            /// @src 0:7446:7451  "10000"
            function checked_mul_uint256_19082(x) -> product
            {
                product := mul(x, 0x2710)
                if iszero(or(iszero(x), eq(0x2710, div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19083(x) -> product
            {
                product := mul(x, /** @src 0:7599:7603  "5000" */ 0x1388)
                /// @src 0:7446:7451  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:7599:7603  "5000" */ 0x1388, /** @src 0:7446:7451  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19085(x) -> product
            {
                product := mul(x, /** @src 0:7655:7659  "6600" */ 0x19c8)
                /// @src 0:7446:7451  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:7655:7659  "6600" */ 0x19c8, /** @src 0:7446:7451  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19086(x) -> product
            {
                product := mul(x, /** @src 0:9417:9419  "22" */ 0x16)
                /// @src 0:7446:7451  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:9417:9419  "22" */ 0x16, /** @src 0:7446:7451  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256(x, y) -> product
            {
                product := mul(x, y)
                if iszero(or(iszero(x), eq(y, div(product, x)))) { panic_error_0x11() }
            }
            /// @src 0:7599:7603  "5000"
            function require_helper_error_ThresholdTooLow(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x1cc767c5))
                    revert(0, 4)
                }
            }
            /// @src 0:7655:7659  "6600"
            function require_helper_error_ThresholdTooHigh(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xe56d58cf))
                    revert(0, 4)
                }
            }
            /// @src 0:9417:9419  "22"
            function allocate_and_zero_memory_array_bytes(length) -> memPtr
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := array_allocation_size_bytes(length)
                let memPtr_1 := mload(64)
                finalize_allocation(memPtr_1, _1)
                mstore(memPtr_1, length)
                /// @src 0:9417:9419  "22"
                memPtr := memPtr_1
                calldatacopy(add(memPtr_1, 32), calldatasize(), add(array_allocation_size_bytes(length), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(31)))
            }
            /// @src 0:9417:9419  "22"
            function abi_encode_packed_uint16_uint24_uint32_uint16_uint256(pos, value0, value1, value2, value3, value4) -> end
            {
                mstore(pos, and(shl(240, value0), shl(240, 65535)))
                mstore(add(pos, 2), and(shl(232, value1), /** @src 0:38261:88845  "assembly {..." */ shl(232, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 16777215)))
                /// @src 0:9417:9419  "22"
                mstore(add(pos, 5), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shl(224, /** @src 0:9417:9419  "22" */ value2), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xffffffff)))
                /// @src 0:9417:9419  "22"
                mstore(add(pos, 9), and(shl(240, value3), shl(240, 65535)))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src 0:9417:9419  "22" */ add(pos, 11), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value4)
                /// @src 0:9417:9419  "22"
                end := add(pos, 43)
            }
            function read_from_memoryt_address(ptr) -> returnValue
            {
                returnValue := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:9417:9419  "22" */ mload(ptr), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
            }
            /// @src 0:9417:9419  "22"
            function abi_encode_packed_uint256_bytes(pos, value0, value1) -> end
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(pos, value0)
                /// @src 0:9417:9419  "22"
                let length := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:9417:9419  "22" */ value1)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mcopy(/** @src 0:9417:9419  "22" */ add(pos, 32), add(value1, 32), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ length)
                let _1 := add(add(/** @src 0:9417:9419  "22" */ pos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ length), /** @src 0:9417:9419  "22" */ 32)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(_1, /** @src -1:-1:-1 */ 0)
                /// @src 0:9417:9419  "22"
                end := _1
            }
            function mapping_index_access_mapping_uint256__bytes32__of_uint24(key) -> dataSlot
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:9417:9419  "22" */ key, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffff))
                /// @src 0:9417:9419  "22"
                mstore(0x20, /** @src -1:-1:-1 */ 0)
                /// @src 0:9417:9419  "22"
                dataSlot := keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:9417:9419  "22" */ 0x40)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24(key) -> dataSlot
            {
                mstore(0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:9417:9419  "22" */ key, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffff))
                /// @src 0:9417:9419  "22"
                mstore(0x20, /** @src 0:31562:31584  "startingVotingRoundIds" */ 0x02)
                /// @src 0:9417:9419  "22"
                dataSlot := keccak256(0, 0x40)
            }
            function update_storage_value_offset_t_uint32_to_t_uint32(value)
            {
                let _1 := sload(/** @src 0:27727:27736  "stateData" */ 0x0b)
                /// @src 0:9417:9419  "22"
                sstore(/** @src 0:27727:27736  "stateData" */ 0x0b, /** @src 0:9417:9419  "22" */ or(and(_1, not(shl(152, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:9417:9419  "22" */ and(shl(152, value), shl(152, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))))
            }
            /// @src 0:9417:9419  "22"
            function abi_encode_array_uint16_dyn(value, pos) -> end
            {
                let length := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:9417:9419  "22" */ value)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(pos, length)
                /// @src 0:9417:9419  "22"
                pos := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(pos, 0x20)
                /// @src 0:9417:9419  "22"
                let srcPtr := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9417:9419  "22" */ value, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20)
                /// @src 0:9417:9419  "22"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 0:9417:9419  "22"
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(pos, and(/** @src 0:9417:9419  "22" */ mload(srcPtr), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff))
                    /// @src 0:9417:9419  "22"
                    pos := add(pos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20)
                    /// @src 0:9417:9419  "22"
                    srcPtr := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9417:9419  "22" */ srcPtr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20)
                }
                /// @src 0:9417:9419  "22"
                end := pos
            }
            function abi_encode_uint64(value, pos)
            {
                mstore(pos, and(value, 0xffffffffffffffff))
            }
            function abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(headStart, value0, value1, value2, value3, value4, value5, value6) -> tail
            {
                let tail_1 := add(headStart, 224)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(headStart, and(value0, 0xffffffff))
                mstore(/** @src 0:9417:9419  "22" */ add(headStart, 32), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(value1, 0xffff))
                mstore(/** @src 0:9417:9419  "22" */ add(headStart, 64), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value2)
                /// @src 0:9417:9419  "22"
                mstore(add(headStart, 96), 224)
                let pos := tail_1
                let length := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:9417:9419  "22" */ value3)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(tail_1, length)
                /// @src 0:9417:9419  "22"
                pos := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9417:9419  "22" */ headStart, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 256)
                /// @src 0:9417:9419  "22"
                let srcPtr := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9417:9419  "22" */ value3, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(pos, and(/** @src 0:9417:9419  "22" */ mload(srcPtr), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
                    /// @src 0:9417:9419  "22"
                    pos := add(pos, 32)
                    srcPtr := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9417:9419  "22" */ srcPtr, 32)
                }
                mstore(add(headStart, 128), sub(pos, headStart))
                let tail_2 := abi_encode_array_uint16_dyn(value4, pos)
                mstore(add(headStart, 160), sub(tail_2, headStart))
                tail := abi_encode_string(value5, tail_2)
                abi_encode_uint64(value6, add(headStart, 192))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function mapping_index_access_mapping_uint256__uint256__of_uint32(key) -> dataSlot
            {
                mstore(0, and(key, 0xffffffff))
                mstore(0x20, /** @src 0:20520:20542  "startingVotingRoundIds" */ 0x02)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint32(key) -> dataSlot
            {
                mstore(/** @src 0:18905:18906  "0" */ 0x00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(key, 0xffffffff))
                mstore(0x20, /** @src 0:18905:18906  "0" */ 0x00)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(/** @src 0:18905:18906  "0" */ 0x00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40)
            }
            function extract_from_storage_value_offset_uint64(slot_value) -> value
            {
                value := /** @src 0:9417:9419  "22" */ and(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ slot_value, /** @src 0:9417:9419  "22" */ 0xffffffffffffffff)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function update_storage_value_offset_uint64_to_uint64()
            {
                sstore(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(0xffffffffffffffff)), /** @src 0:9417:9419  "22" */ 1))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function update_storage_value_offset_t_bool_to_t_bool()
            {
                sstore(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(0xff0000000000000000)), 0x010000000000000000))
            }
            function update_storage_value_offset_bool_to_bool()
            {
                sstore(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(0xff0000000000000000)))
            }
            /// @ast-id 3832 @src 14:4069:5171  "modifier initializer() {..."
            function modifier_initializer(var__initialConfig_mpos, var_signingPolicySetter, var__oldRelay_address, var_initialOwner)
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := and(shr(64, _1), 0xff)
                /// @src 14:4301:4317  "!$._initializing"
                let expr := cleanup_bool(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value))
                /// @src 14:4724:4740  "initialized == 0"
                let _2 := /** @src 0:9417:9419  "22" */ and(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_uint64(_1), /** @src 0:9417:9419  "22" */ 0xffffffffffffffff)
                /// @src 14:4724:4758  "initialized == 0 && isTopLevelCall"
                let expr_1 := /** @src 14:4724:4740  "initialized == 0" */ iszero(_2)
                /// @src 14:4724:4758  "initialized == 0 && isTopLevelCall"
                if expr_1 { expr_1 := expr }
                /// @src 14:4788:4838  "initialized == 1 && address(this).code.length == 0"
                let expr_2 := /** @src 14:4788:4804  "initialized == 1" */ eq(_2, /** @src 14:4803:4804  "1" */ 0x01)
                /// @src 14:4788:4838  "initialized == 1 && address(this).code.length == 0"
                if expr_2
                {
                    expr_2 := /** @src 14:4808:4838  "address(this).code.length == 0" */ iszero(/** @src 14:4808:4833  "address(this).code.length" */ extcodesize(/** @src 14:4816:4820  "this" */ address()))
                }
                /// @src 14:4853:4883  "!initialSetup && !construction"
                let expr_3 := /** @src 14:4853:4866  "!initialSetup" */ iszero(expr_1)
                /// @src 14:4853:4883  "!initialSetup && !construction"
                if expr_3
                {
                    expr_3 := /** @src 14:4870:4883  "!construction" */ iszero(expr_2)
                }
                /// @src 14:4849:4940  "if (!initialSetup && !construction) {..."
                if expr_3
                {
                    /// @src 14:4906:4929  "InvalidInitialization()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 14:4906:4929  "InvalidInitialization()" */ shl(224, 0xf92ee8a9))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 14:4906:4929  "InvalidInitialization()" */ 4)
                }
                /// @src 14:4949:4967  "$._initialized = 1"
                update_storage_value_offset_uint64_to_uint64()
                /// @src 14:4977:5044  "if (isTopLevelCall) {..."
                if expr
                {
                    /// @src 14:5011:5033  "$._initializing = true"
                    update_storage_value_offset_t_bool_to_t_bool()
                }
                /// @src 14:5053:5054  "_"
                fun_initialize_inner(var__initialConfig_mpos, var_signingPolicySetter, var__oldRelay_address, var_initialOwner)
                /// @src 14:5064:5165  "if (isTopLevelCall) {..."
                if expr
                {
                    /// @src 14:5098:5121  "$._initializing = false"
                    update_storage_value_offset_bool_to_bool()
                    /// @src 14:5140:5154  "Initialized(1)"
                    let _3 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 14:5140:5154  "Initialized(1)"
                    log1(_3, sub(abi_encode_bool(_3), _3), 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2)
                }
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function require_helper_error_ThresholdIncreaseTooSmall(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x7708e90b))
                    revert(0, 4)
                }
            }
            function require_helper_error_RewardEpochDurationZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x3e813e31))
                    revert(0, 4)
                }
            }
            function read_from_memoryt_uint8(ptr) -> returnValue
            {
                returnValue := and(mload(ptr), 0xff)
            }
            function require_helper_error_VotingEpochDurationZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x151163c1))
                    revert(0, 4)
                }
            }
            function require_helper_error_InitialSigningPolicyHashZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(227, 0x030a4b2f))
                    revert(0, 4)
                }
            }
            function checked_mul_uint32(x, y) -> product
            {
                let product_raw := mul(and(x, 0xffffffff), and(y, 0xffffffff))
                product := and(product_raw, 0xffffffff)
                if iszero(eq(product, product_raw)) { panic_error_0x11() }
            }
            function require_helper_error_InvalidInitialStartingVotingRoundId(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x5acba20f))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_uint32_to_uint32_19118(value)
            {
                let _1 := sload(/** @src 0:19952:20010  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x0d)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:19952:20010  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x0d, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(shl(160, 0xffffffff))), and(shl(160, value), shl(160, 0xffffffff))))
            }
            function update_storage_value_offset_uint32_to_uint32_19119(value)
            {
                let _1 := sload(/** @src 0:19952:20010  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x0d)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:19952:20010  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x0d, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(shl(192, 0xffffffff))), and(shl(192, value), shl(192, 0xffffffff))))
            }
            function update_storage_value_offset_uint32_to_uint32_19129(value)
            {
                let _1 := sload(/** @src 0:20436:20445  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(shl(192, 0xffffffff))), and(shl(192, value), shl(192, 0xffffffff))))
            }
            function require_helper_error_InvalidRandomNumberProtocolId(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x06e1dff5))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_t_uint8_to_t_uint8(value)
            {
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 0:20436:20445  "stateData" */ 0x0b), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(255)), and(value, 0xff)))
            }
            function update_storage_value_offset_uint32_to_uint32_19124(value)
            {
                let _1 := sload(/** @src 0:20436:20445  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(0xffffffff00)), and(shl(8, value), 0xffffffff00)))
            }
            function update_storage_value_offset_uint8_to_uint8(value)
            {
                let _1 := sload(/** @src 0:20436:20445  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(0xff0000000000)), and(shl(40, value), 0xff0000000000)))
            }
            function update_storage_value_offset_uint32_to_uint32(value)
            {
                let _1 := sload(/** @src 0:20436:20445  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(0xffffffff000000000000)), and(shl(48, value), 0xffffffff000000000000)))
            }
            function update_storage_value_offset_t_uint16_to_t_uint16(value)
            {
                let _1 := sload(/** @src 0:20436:20445  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(shl(80, /** @src 0:9417:9419  "22" */ 65535))), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shl(80, value), shl(80, /** @src 0:9417:9419  "22" */ 65535))))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function update_storage_value_offset_uint16_to_uint16(value)
            {
                let _1 := sload(/** @src 0:20436:20445  "stateData" */ 0x0b)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_1, not(shl(96, /** @src 0:9417:9419  "22" */ 65535))), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shl(96, value), shl(96, /** @src 0:9417:9419  "22" */ 65535))))
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function require_helper_error_FeeCollectionAddressZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xa63c869f))
                    revert(0, 4)
                }
            }
            function require_helper_error_FeeConfigNotAllowed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xf286d12d))
                    revert(0, 4)
                }
            }
            function require_helper_error_SourceChainIdMismatchOnHomeDeploy(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x07f124cb))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_bool_to_bool_19132()
            {
                sstore(/** @src 0:20436:20445  "stateData" */ 0x0b, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 0:20436:20445  "stateData" */ 0x0b), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(shl(184, 255))), shl(184, 1)))
            }
            function require_helper_error_SourceChainIdZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x8609583d))
                    revert(0, 4)
                }
            }
            function require_helper_error_OldRelayNotAllowedInRelayMode(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x40703575))
                    revert(0, 4)
                }
            }
            function abi_decode_address_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let value := mload(headStart)
                validator_revert_address(value)
                value0 := value
            }
            function require_helper_error_OldRelayIncompatible(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xdfd7b0b9))
                    revert(0, 4)
                }
            }
            function abi_decode_uint32_fromMemory(offset) -> value
            {
                value := mload(offset)
                validator_revert_uint32(value)
            }
            function abi_decode_uint8t_uint32t_uint8t_uint32t_uint16t_uint16t_uint32t_boolt_uint32t_boolt_uint32_fromMemory(headStart, dataEnd) -> value0, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10
            {
                if slt(sub(dataEnd, headStart), 352) { revert(0, 0) }
                let value := mload(headStart)
                validator_revert_uint8(value)
                value0 := value
                let value_1 := mload(add(headStart, 32))
                validator_revert_uint32(value_1)
                value1 := value_1
                let value_2 := mload(add(headStart, 64))
                validator_revert_uint8(value_2)
                value2 := value_2
                let value_3 := mload(add(headStart, 96))
                validator_revert_uint32(value_3)
                value3 := value_3
                let value_4 := mload(add(headStart, 128))
                validator_revert_uint16(value_4)
                value4 := value_4
                let value_5 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_5 := mload(add(headStart, 160))
                validator_revert_uint16(value_5)
                value5 := value_5
                let value_6 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_6 := mload(add(headStart, 192))
                validator_revert_uint32(value_6)
                value6 := value_6
                value7 := abi_decode_t_bool_fromMemory(add(headStart, 224))
                value8 := abi_decode_uint32_fromMemory(add(headStart, 256))
                value9 := abi_decode_t_bool_fromMemory(add(headStart, 288))
                value10 := abi_decode_uint32_fromMemory(add(headStart, 320))
            }
            function require_helper_error_OldRelayWrongStartTs(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x59e4528b))
                    revert(0, 4)
                }
            }
            function require_helper_error_OldRelayWrongRewardEpochDuration(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xf05344a9))
                    revert(0, 4)
                }
            }
            function require_helper_error_OldRelayWrongFirstRewardEpochStart(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x6e0e72e9))
                    revert(0, 4)
                }
            }
            function require_helper_error_OldRelayWrongVotingEpochDuration(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x23ac0927))
                    revert(0, 4)
                }
            }
            /// @src 0:18392:27162  "function initialize(..."
            function fun_initialize_inner(var_initialConfig_mpos, var__signingPolicySetter, var_oldRelay_address, var__initialOwner)
            {
                /// @src 33:1868:1995  "function __Ownable_init(address initialOwner) internal onlyInitializing {..."
                modifier_onlyInitializing(var__initialOwner)
                /// @src 0:18653:18689  "_initialConfig.thresholdIncreaseBIPS"
                let _1 := add(var_initialConfig_mpos, 256)
                /// @src 0:18645:18737  "require(_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS, ThresholdIncreaseTooSmall())"
                require_helper_error_ThresholdIncreaseTooSmall(/** @src 0:18653:18707  "_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS" */ iszero(lt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:18653:18689  "_initialConfig.thresholdIncreaseBIPS" */ _1)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff), /** @src 0:7446:7451  "10000" */ 0x2710)))
                /// @src 0:18854:18902  "_initialConfig.rewardEpochDurationInVotingEpochs"
                let _2 := add(var_initialConfig_mpos, 224)
                /// @src 0:18846:18934  "require(_initialConfig.rewardEpochDurationInVotingEpochs > 0, RewardEpochDurationZero())"
                require_helper_error_RewardEpochDurationZero(/** @src 0:18854:18906  "_initialConfig.rewardEpochDurationInVotingEpochs > 0" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:18854:18902  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff))))
                /// @src 0:18952:18993  "_initialConfig.votingEpochDurationSeconds"
                let _3 := add(var_initialConfig_mpos, 160)
                /// @src 0:18944:19025  "require(_initialConfig.votingEpochDurationSeconds > 0, VotingEpochDurationZero())"
                require_helper_error_VotingEpochDurationZero(/** @src 0:18952:18997  "_initialConfig.votingEpochDurationSeconds > 0" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(cleanup_from_storage_uint8(mload(/** @src 0:18952:18993  "_initialConfig.votingEpochDurationSeconds" */ _3)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff))))
                /// @src 0:19573:19612  "_initialConfig.initialSigningPolicyHash"
                let _4 := add(var_initialConfig_mpos, 64)
                /// @src 0:19565:19659  "require(_initialConfig.initialSigningPolicyHash != bytes32(0), InitialSigningPolicyHashZero())"
                require_helper_error_InitialSigningPolicyHashZero(/** @src 0:19573:19626  "_initialConfig.initialSigningPolicyHash != bytes32(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:19573:19612  "_initialConfig.initialSigningPolicyHash" */ _4))))
                /// @src 0:19677:19726  "_initialConfig.firstRewardEpochStartVotingRoundId"
                let _5 := add(var_initialConfig_mpos, 192)
                let _6 := /** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:19677:19726  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _5))
                /// @src 0:19741:19776  "_initialConfig.initialRewardEpochId"
                let _7 := /** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:19741:19776  "_initialConfig.initialRewardEpochId" */ var_initialConfig_mpos))
                /// @src 0:19677:19827  "_initialConfig.firstRewardEpochStartVotingRoundId +..."
                let expr := checked_add_uint32(_6, /** @src 0:19741:19827  "_initialConfig.initialRewardEpochId * _initialConfig.rewardEpochDurationInVotingEpochs" */ checked_mul_uint32(_7, cleanup_from_storage_uint16(/** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:19779:19827  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2)))))
                /// @src 0:19843:19902  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId"
                let _8 := add(var_initialConfig_mpos, 32)
                /// @src 0:19669:19942  "require(_initialConfig.firstRewardEpochStartVotingRoundId +..."
                require_helper_error_InvalidInitialStartingVotingRoundId(/** @src 0:19677:19902  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ iszero(gt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:19677:19902  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ expr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), /** @src 0:19677:19902  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ cleanup_from_storage_uint32(/** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:19843:19902  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _8))))))
                /// @src 0:19975:20010  "_initialConfig.initialRewardEpochId"
                let _9 := /** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:19975:20010  "_initialConfig.initialRewardEpochId" */ var_initialConfig_mpos))
                /// @src 0:19952:20010  "initialRewardEpochId = _initialConfig.initialRewardEpochId"
                update_storage_value_offset_uint32_to_uint32_19118(_9)
                /// @src 0:9417:9419  "22"
                let _10 := cleanup_from_storage_uint32(mload(/** @src 0:20079:20138  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _8))
                /// @src 0:20020:20138  "startingVotingRoundIdForInitialRewardEpochId =..."
                update_storage_value_offset_uint32_to_uint32_19119(/** @src 0:9417:9419  "22" */ _10)
                /// @src 0:20436:20510  "stateData.lastInitializedRewardEpoch = _initialConfig.initialRewardEpochId"
                update_storage_value_offset_t_uint32_to_t_uint32(_9)
                /// @src 5:1578:1584  "7 days"
                sstore(/** @src 0:20520:20579  "startingVotingRoundIds[_initialConfig.initialRewardEpochId]" */ mapping_index_access_mapping_uint256__uint256__of_uint32(/** @src 0:9417:9419  "22" */ _9), /** @src 0:20520:20653  "startingVotingRoundIds[_initialConfig.initialRewardEpochId] =..." */ cleanup_from_storage_uint32(/** @src 0:9417:9419  "22" */ _10))
                /// @src 5:1578:1584  "7 days"
                sstore(/** @src 0:20663:20726  "toSigningPolicyHashPrivate[_initialConfig.initialRewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint32(/** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:20690:20725  "_initialConfig.initialRewardEpochId" */ var_initialConfig_mpos))), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:20729:20768  "_initialConfig.initialSigningPolicyHash" */ _4))
                /// @src 0:20786:20823  "_initialConfig.randomNumberProtocolId"
                let _11 := add(var_initialConfig_mpos, 96)
                /// @src 0:20778:20861  "require(_initialConfig.randomNumberProtocolId > 1, InvalidRandomNumberProtocolId())"
                require_helper_error_InvalidRandomNumberProtocolId(/** @src 0:20786:20827  "_initialConfig.randomNumberProtocolId > 1" */ gt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(cleanup_from_storage_uint8(mload(/** @src 0:20786:20823  "_initialConfig.randomNumberProtocolId" */ _11)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff), /** @src 0:20826:20827  "1" */ 0x01))
                /// @src 0:20871:20943  "stateData.randomNumberProtocolId = _initialConfig.randomNumberProtocolId"
                update_storage_value_offset_t_uint8_to_t_uint8(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_from_storage_uint8(mload(/** @src 0:20906:20943  "_initialConfig.randomNumberProtocolId" */ _11)))
                /// @src 0:20989:21027  "_initialConfig.firstVotingRoundStartTs"
                let _12 := add(var_initialConfig_mpos, 128)
                /// @src 0:20953:21027  "stateData.firstVotingRoundStartTs = _initialConfig.firstVotingRoundStartTs"
                update_storage_value_offset_uint32_to_uint32_19124(/** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:20989:21027  "_initialConfig.firstVotingRoundStartTs" */ _12)))
                /// @src 0:21037:21117  "stateData.votingEpochDurationSeconds = _initialConfig.votingEpochDurationSeconds"
                update_storage_value_offset_uint8_to_uint8(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_from_storage_uint8(mload(/** @src 0:21076:21117  "_initialConfig.votingEpochDurationSeconds" */ _3)))
                /// @src 0:21127:21223  "stateData.firstRewardEpochStartVotingRoundId = _initialConfig.firstRewardEpochStartVotingRoundId"
                update_storage_value_offset_uint32_to_uint32(/** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:21174:21223  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _5)))
                /// @src 0:21233:21327  "stateData.rewardEpochDurationInVotingEpochs = _initialConfig.rewardEpochDurationInVotingEpochs"
                update_storage_value_offset_t_uint16_to_t_uint16(/** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:21279:21327  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2)))
                /// @src 0:21337:21407  "stateData.thresholdIncreaseBIPS = _initialConfig.thresholdIncreaseBIPS"
                update_storage_value_offset_uint16_to_uint16(/** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:21371:21407  "_initialConfig.thresholdIncreaseBIPS" */ _1)))
                /// @src 0:21417:21523  "stateData.messageFinalizationWindowInRewardEpochs = _initialConfig.messageFinalizationWindowInRewardEpochs"
                update_storage_value_offset_uint32_to_uint32_19129(/** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:21469:21523  "_initialConfig.messageFinalizationWindowInRewardEpochs" */ add(var_initialConfig_mpos, 288))))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _13 := and(/** @src 0:21537:21571  "_signingPolicySetter != address(0)" */ var__signingPolicySetter, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 0:21537:21571  "_signingPolicySetter != address(0)"
                let expr_1 := iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _13))
                /// @src 0:21533:23576  "if (_signingPolicySetter != address(0)) {..."
                switch expr_1
                case 0 {
                    /// @src 0:22718:22753  "_initialConfig.feeCollectionAddress"
                    let _14 := add(var_initialConfig_mpos, 320)
                    /// @src 0:22710:22796  "require(_initialConfig.feeCollectionAddress != address(0), FeeCollectionAddressZero())"
                    require_helper_error_FeeCollectionAddressZero(/** @src 0:22718:22767  "_initialConfig.feeCollectionAddress != address(0)" */ iszero(iszero(cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(mload(/** @src 0:22718:22753  "_initialConfig.feeCollectionAddress" */ _14))))))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _15 := cleanup_address_payable(mload(/** @src 0:22833:22868  "_initialConfig.feeCollectionAddress" */ _14))
                    /// @src 0:22810:22868  "feeCollectionAddress = _initialConfig.feeCollectionAddress"
                    update_storage_value_offset_address_to_address(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _15)
                    /// @src 0:22887:22947  "FeeCollectionAddressSet(_initialConfig.feeCollectionAddress)"
                    log2(/** @src 0:18905:18906  "0" */ 0x00, 0x00, /** @src 0:22887:22947  "FeeCollectionAddressSet(_initialConfig.feeCollectionAddress)" */ 0xfc78a1d0b2aa388b5b987c35079601ed0e4c5a4d38f758a0278449af9d7b9ba2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:22887:22947  "FeeCollectionAddressSet(_initialConfig.feeCollectionAddress)" */ _15, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
                    /// @src 0:23514:23537  "_initialConfig.feeToken"
                    let _16 := /** @src 0:9417:9419  "22" */ cleanup_address_payable(mload(/** @src 0:23514:23537  "_initialConfig.feeToken" */ add(var_initialConfig_mpos, 384)))
                    /// @src 0:23539:23564  "_initialConfig.feeConfigs"
                    fun_setProtocolFees(_16, mload(add(var_initialConfig_mpos, 352)))
                }
                default /// @src 0:21533:23576  "if (_signingPolicySetter != address(0)) {..."
                {
                    /// @src 0:21828:21897  "require(_initialConfig.feeConfigs.length == 0, FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:21836:21873  "_initialConfig.feeConfigs.length == 0" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:21836:21861  "_initialConfig.feeConfigs" */ mload(add(var_initialConfig_mpos, 352)))))
                    /// @src 0:21911:21992  "require(_initialConfig.feeExemptAddresses.length == 0, FeeExemptionsNotAllowed())"
                    require_helper_error_FeeExemptionsNotAllowed(/** @src 0:21919:21964  "_initialConfig.feeExemptAddresses.length == 0" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:21919:21952  "_initialConfig.feeExemptAddresses" */ mload(add(var_initialConfig_mpos, 416)))))
                    /// @src 0:22006:22087  "require(_initialConfig.feeCollectionAddress == address(0), FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:22014:22063  "_initialConfig.feeCollectionAddress == address(0)" */ iszero(cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(mload(/** @src 0:22014:22049  "_initialConfig.feeCollectionAddress" */ add(var_initialConfig_mpos, 320))))))
                    /// @src 0:22101:22170  "require(_initialConfig.feeToken == address(0), FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:22109:22146  "_initialConfig.feeToken == address(0)" */ iszero(cleanup_address_payable(/** @src 0:9417:9419  "22" */ cleanup_address_payable(mload(/** @src 0:22109:22132  "_initialConfig.feeToken" */ add(var_initialConfig_mpos, 384))))))
                    /// @src 0:9417:9419  "22"
                    let _17 := mload(/** @src 0:22297:22325  "_initialConfig.sourceChainId" */ add(var_initialConfig_mpos, 448))
                    /// @src 0:22272:22409  "require(..."
                    require_helper_error_SourceChainIdMismatchOnHomeDeploy(/** @src 0:22297:22342  "_initialConfig.sourceChainId == block.chainid" */ eq(_17, /** @src 0:22329:22342  "block.chainid" */ chainid()))
                    /// @src 0:22423:22465  "signingPolicySetter = _signingPolicySetter"
                    update_storage_value_offset_t_address_to_t_address(var__signingPolicySetter)
                    /// @src 0:22479:22516  "stateData.noSigningPolicyRelay = true"
                    update_storage_value_offset_bool_to_bool_19132()
                    /// @src 0:22535:22579  "SigningPolicySetterSet(_signingPolicySetter)"
                    log2(/** @src 0:18905:18906  "0" */ 0x00, 0x00, /** @src 0:22535:22579  "SigningPolicySetterSet(_signingPolicySetter)" */ 0x78cbfa03aa310db13b3d8fcb316ae48a77d62315fccfe098fc146374d6edb309, _13)
                }
                /// @src 0:23888:23901  "uint256 i = 0"
                let var_i := /** @src 0:18905:18906  "0" */ 0x00
                /// @src 0:23883:24220  "for (uint256 i = 0; i < _initialConfig.feeExemptAddresses.length; i++) {..."
                for { }
                /** @src 0:20826:20827  "1" */ 0x01
                /// @src 0:23888:23901  "uint256 i = 0"
                {
                    /// @src 0:23949:23952  "i++"
                    var_i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:23949:23952  "i++" */ var_i, /** @src 0:20826:20827  "1" */ 0x01)
                }
                /// @src 0:23949:23952  "i++"
                {
                    /// @src 0:23907:23940  "_initialConfig.feeExemptAddresses"
                    let _524_mpos := mload(add(var_initialConfig_mpos, 416))
                    /// @src 0:23903:23947  "i < _initialConfig.feeExemptAddresses.length"
                    if iszero(lt(var_i, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:23907:23947  "_initialConfig.feeExemptAddresses.length" */ _524_mpos)))
                    /// @src 0:23903:23947  "i < _initialConfig.feeExemptAddresses.length"
                    { break }
                    /// @src 0:23992:24028  "_initialConfig.feeExemptAddresses[i]"
                    let _18 := read_from_memoryt_address(memory_array_index_access_struct_FeeConfig_dyn(_524_mpos, var_i))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _19 := and(/** @src 0:24050:24077  "exemptAccount != address(0)" */ _18, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    /// @src 0:24042:24102  "require(exemptAccount != address(0), FeeExemptAddressZero())"
                    require_helper_error_FeeExemptAddressZero(/** @src 0:24050:24077  "exemptAccount != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _19)))
                    /// @src 0:24116:24154  "feeExemptAddress[exemptAccount] = true"
                    update_storage_value_offset_bool_to_bool_19134(/** @src 0:24116:24147  "feeExemptAddress[exemptAccount]" */ mapping_index_access_mapping_address_bool_of_address(_18))
                    /// @src 0:24173:24209  "FeeExemptionSet(exemptAccount, true)"
                    let _20 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:19573:19612  "_initialConfig.initialSigningPolicyHash" */ 64)
                    /// @src 0:24173:24209  "FeeExemptionSet(exemptAccount, true)"
                    log2(_20, sub(abi_encode_bool(_20), _20), 0x210f2a4a589e25d95b24cbdb060d26ae79bbe123a564d0f973503d48badd00ca, _19)
                }
                /// @src 0:24470:24498  "_initialConfig.sourceChainId"
                let _21 := add(var_initialConfig_mpos, 448)
                /// @src 0:24462:24525  "require(_initialConfig.sourceChainId != 0, SourceChainIdZero())"
                require_helper_error_SourceChainIdZero(/** @src 0:24470:24503  "_initialConfig.sourceChainId != 0" */ iszero(iszero(/** @src 0:9417:9419  "22" */ mload(/** @src 0:24470:24498  "_initialConfig.sourceChainId" */ _21))))
                /// @src 0:24535:24579  "sourceChainId = _initialConfig.sourceChainId"
                update_storage_value_offset_uint256_to_uint256(/** @src 0:9417:9419  "22" */ mload(/** @src 0:24551:24579  "_initialConfig.sourceChainId" */ _21))
                /// @src 0:24932:24970  "_initialConfig.timelockDurationSeconds"
                let _22 := add(var_initialConfig_mpos, 480)
                /// @src 0:24911:25052  "require(..."
                require_helper_error_TimelockDurationTooLong(/** @src 0:24932:25003  "_initialConfig.timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS" */ iszero(gt(/** @src 0:9417:9419  "22" */ mload(/** @src 0:24932:24970  "_initialConfig.timelockDurationSeconds" */ _22), /** @src 5:1578:1584  "7 days" */ 0x093a80)))
                /// @src 0:9417:9419  "22"
                let _23 := mload(/** @src 0:25099:25137  "_initialConfig.timelockDurationSeconds" */ _22)
                /// @src 0:25062:25137  "getState().timelockDurationSeconds = _initialConfig.timelockDurationSeconds"
                update_storage_value_offset_t_uint256_to_t_uint256(_23)
                /// @src 0:25152:25211  "TimelockDurationSet(_initialConfig.timelockDurationSeconds)"
                let _24 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:19573:19612  "_initialConfig.initialSigningPolicyHash" */ 64)
                /// @src 0:25152:25211  "TimelockDurationSet(_initialConfig.timelockDurationSeconds)"
                log1(_24, sub(abi_encode_tuple_bytes32(_24, _23), _24), 0xf15cdeff5f6a37216412a72678ec978762dc7264a85f30590ed54b14ab51bbdf)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _25 := and(/** @src 0:25225:25243  "address(_oldRelay)" */ var_oldRelay_address, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 0:25221:27156  "if (address(_oldRelay) != address(0)) {..."
                if /** @src 0:25225:25257  "address(_oldRelay) != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _25))
                /// @src 0:25221:27156  "if (address(_oldRelay) != address(0)) {..."
                {
                    /// @src 0:25886:25962  "require(_signingPolicySetter != address(0), OldRelayNotAllowedInRelayMode())"
                    require_helper_error_OldRelayNotAllowedInRelayMode(expr_1)
                    /// @src 0:26061:26092  "_oldRelay.signingPolicySetter()"
                    let _26 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:19573:19612  "_initialConfig.initialSigningPolicyHash" */ 64)
                    /// @src 0:26061:26092  "_oldRelay.signingPolicySetter()"
                    mstore(_26, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xa9dbe8ed))
                    /// @src 0:26061:26092  "_oldRelay.signingPolicySetter()"
                    let _27 := staticcall(gas(), _25, _26, 4, _26, /** @src 0:19843:19902  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32)
                    /// @src 0:26061:26092  "_oldRelay.signingPolicySetter()"
                    if iszero(_27) { revert_forward() }
                    let expr_2 := /** @src 0:18905:18906  "0" */ 0x00
                    /// @src 0:26061:26092  "_oldRelay.signingPolicySetter()"
                    if _27
                    {
                        let _28 := /** @src 0:19843:19902  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32
                        /// @src 0:26061:26092  "_oldRelay.signingPolicySetter()"
                        if gt(/** @src 0:19843:19902  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32, /** @src 0:26061:26092  "_oldRelay.signingPolicySetter()" */ returndatasize()) { _28 := returndatasize() }
                        finalize_allocation(_26, _28)
                        expr_2 := abi_decode_address_fromMemory(_26, add(_26, _28))
                    }
                    /// @src 0:26053:26131  "require(_oldRelay.signingPolicySetter() != address(0), OldRelayIncompatible())"
                    require_helper_error_OldRelayIncompatible(/** @src 0:26061:26106  "_oldRelay.signingPolicySetter() != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:26061:26106  "_oldRelay.signingPolicySetter() != address(0)" */ expr_2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))))
                    /// @src 0:26418:26439  "_oldRelay.stateData()"
                    let _29 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:19573:19612  "_initialConfig.initialSigningPolicyHash" */ 64)
                    /// @src 0:26418:26439  "_oldRelay.stateData()"
                    mstore(_29, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x0f47d9b5))
                    /// @src 0:26418:26439  "_oldRelay.stateData()"
                    let _30 := staticcall(gas(), _25, _29, /** @src 0:26061:26092  "_oldRelay.signingPolicySetter()" */ 4, /** @src 0:26418:26439  "_oldRelay.stateData()" */ _29, 352)
                    if iszero(_30) { revert_forward() }
                    let expr_893_component := /** @src 0:18905:18906  "0" */ 0x00
                    let expr_893_component_1 := 0x00
                    let expr_component := 0x00
                    let expr_component_1 := 0x00
                    /// @src 0:26418:26439  "_oldRelay.stateData()"
                    if _30
                    {
                        let _31 := 352
                        if gt(_31, returndatasize()) { _31 := returndatasize() }
                        finalize_allocation(_29, _31)
                        let expr_component_2, expr_component_3, expr_component_4, expr_component_5, expr_component_6, expr_component_7, expr_component_8, expr_component_9, expr_component_10, expr_component_11, expr_component_12 := abi_decode_uint8t_uint32t_uint8t_uint32t_uint16t_uint16t_uint32t_boolt_uint32t_boolt_uint32_fromMemory(_29, add(_29, _31))
                        expr_893_component := expr_component_3
                        expr_893_component_1 := expr_component_4
                        expr_component := expr_component_5
                        expr_component_1 := expr_component_6
                    }
                    /// @src 0:26461:26499  "_initialConfig.firstVotingRoundStartTs"
                    let _32 := /** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:26461:26499  "_initialConfig.firstVotingRoundStartTs" */ _12))
                    /// @src 0:26453:26551  "require(_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs, OldRelayWrongStartTs())"
                    require_helper_error_OldRelayWrongStartTs(/** @src 0:26461:26526  "_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs" */ eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:26461:26526  "_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs" */ _32, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), and(/** @src 0:26461:26526  "_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs" */ expr_893_component, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)))
                    /// @src 0:26590:26638  "_initialConfig.rewardEpochDurationInVotingEpochs"
                    let _33 := /** @src 0:7544:7547  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:26590:26638  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2))
                    /// @src 0:26565:26741  "require(..."
                    require_helper_error_OldRelayWrongRewardEpochDuration(/** @src 0:26590:26675  "_initialConfig.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:26590:26675  "_initialConfig.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ _33, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff), and(/** @src 0:26590:26675  "_initialConfig.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ expr_component_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff)))
                    /// @src 0:26780:26829  "_initialConfig.firstRewardEpochStartVotingRoundId"
                    let _34 := /** @src 0:9417:9419  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:26780:26829  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _5))
                    /// @src 0:26755:26935  "require(..."
                    require_helper_error_OldRelayWrongFirstRewardEpochStart(/** @src 0:26780:26867  "_initialConfig.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:26780:26867  "_initialConfig.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ _34, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), and(/** @src 0:26780:26867  "_initialConfig.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ expr_component, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)))
                    /// @src 0:26974:27015  "_initialConfig.votingEpochDurationSeconds"
                    let _35 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_from_storage_uint8(mload(/** @src 0:26974:27015  "_initialConfig.votingEpochDurationSeconds" */ _3))
                    /// @src 0:26949:27111  "require(..."
                    require_helper_error_OldRelayWrongVotingEpochDuration(/** @src 0:26974:27045  "_initialConfig.votingEpochDurationSeconds == votingEpochDurationSeconds" */ eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:26974:27045  "_initialConfig.votingEpochDurationSeconds == votingEpochDurationSeconds" */ _35, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff), and(/** @src 0:26974:27045  "_initialConfig.votingEpochDurationSeconds == votingEpochDurationSeconds" */ expr_893_component_1, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)))
                    /// @src 0:27125:27145  "oldRelay = _oldRelay"
                    update_storage_value_offset_address_to_address_19138(var_oldRelay_address)
                }
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function abi_decode_uint256t_boolt_uint256_fromMemory(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := mload(headStart)
                value0 := value
                let value_1 := mload(add(headStart, 32))
                validator_revert_bool(value_1)
                value1 := value_1
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_2 := mload(add(headStart, 64))
                value2 := value_2
            }
            function mapping_index_access_mapping_uint256__mapping_uint256__bytes32___of_uint8(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, /** @src 0:96965:96983  "merkleRootsPrivate" */ 0x01)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_mapping_uint256_bytes32__of_uint8(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, /** @src 0:99880:99891  "protocolFee" */ 0x04)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function require_helper_error_NoRandomNumber(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xd76adcd1))
                    revert(0, 4)
                }
            }
            function panic_error_0x12()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x12)
                revert(0, 0x24)
            }
            function checked_div_uint256(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := shr(8, x)
            }
            function mod_uint256(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := and(x, 255)
            }
            /// @ast-id 2015 @src 0:96373:97477  "function getRandomNumberHistorical(uint256 _votingRoundId)..."
            function fun_getRandomNumberHistorical(var__votingRoundId) -> var_randomNumber, var_isSecureRandom, var_randomTimestamp
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(/** @src 0:96614:96622  "oldRelay" */ 0x0d)
                /// @src 0:96606:96623  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:96606:96702  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr_1 := /** @src 0:96606:96637  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:96606:96637  "address(oldRelay) != address(0)" */ expr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:96606:96702  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:96641:96702  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var__votingRoundId, cleanup_from_storage_uint32(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:96602:96786  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:96725:96775  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _2 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:96725:96775  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    mstore(_2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(227, 0x150fe287))
                    /// @src 0:96725:96775  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_tuple_bytes32(add(_2, 4), var__votingRoundId), _2), _2, 96)
                    if iszero(_3) { revert_forward() }
                    let expr_1941_component := /** @src 0:96635:96636  "0" */ 0x00
                    let expr_component := 0x00
                    let expr_component_1 := 0x00
                    /// @src 0:96725:96775  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    if _3
                    {
                        let _4 := 96
                        if gt(96, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        let expr_component_2, expr_component_3, expr_component_4 := abi_decode_uint256t_boolt_uint256_fromMemory(_2, add(_2, _4))
                        expr_1941_component := expr_component_2
                        expr_component := expr_component_3
                        expr_component_1 := expr_component_4
                    }
                    /// @src 0:96718:96775  "return oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    var_randomNumber := expr_1941_component
                    var_isSecureRandom := expr_component
                    var_randomTimestamp := expr_component_1
                    leave
                }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _5 := sload(/** @src 0:96984:96993  "stateData" */ 0x0b)
                /// @src 0:96957:97066  "require(merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0), NoRandomNumber())"
                require_helper_error_NoRandomNumber(/** @src 0:96965:97047  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:96965:97033  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:96965:97017  "merkleRootsPrivate[stateData.randomNumberProtocolId]" */ mapping_index_access_mapping_uint256__mapping_uint256__bytes32___of_uint8(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_from_storage_uint8(_5)), /** @src 0:96965:97033  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ var__votingRoundId)))))
                /// @src 0:97076:97129  "_randomNumber = toRandomNumberPrivate[_votingRoundId]"
                var_randomNumber := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:97092:97129  "toRandomNumberPrivate[_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19144(var__votingRoundId))
                /// @src 0:97139:97303  "_isSecureRandom =..."
                var_isSecureRandom := /** @src 0:97169:97303  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))..." */ eq(/** @src 0:97169:97264  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))" */ and(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shr(/** @src 0:97214:97240  "255 - _votingRoundId % 256" */ checked_sub_uint256_19148(/** @src 0:97220:97240  "_votingRoundId % 256" */ mod_uint256(var__votingRoundId)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:97170:97209  "isSecureRandomMap[_votingRoundId / 256]" */ mapping_index_access_t_mapping_t_uint256__t_uint256__of_t_uint256(/** @src 0:97188:97208  "_votingRoundId / 256" */ checked_div_uint256(var__votingRoundId)))), /** @src 0:96965:96983  "merkleRootsPrivate" */ 0x01), 0x01)
                /// @src 0:97344:97377  "stateData.firstVotingRoundStartTs"
                let _6 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_uint32(_5)
                /// @src 0:97400:97418  "_votingRoundId + 1"
                let expr_2 := checked_add_uint256_19149(var__votingRoundId)
                /// @src 0:97313:97470  "_randomTimestamp =..."
                var_randomTimestamp := /** @src 0:97344:97470  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:97344:97470  "stateData.firstVotingRoundStartTs +..." */ _6, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), /** @src 0:97392:97470  "uint256(_votingRoundId + 1) *..." */ checked_mul_uint256(expr_2, cleanup_from_storage_uint8(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_uint8(_5))))
            }
            /// @src 0:38261:88845  "assembly {..."
            function usr$revertWithError_18997(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x1fe641cf))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_18998(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x5509ecdf))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19000(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x050ff0d7))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19002(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x21d34b23))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19003(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xd0ebeb4b))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19004(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xe3427225))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19006(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x4913ec0d))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19007(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x8134d963))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19008(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x4ed02d0d))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19009(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x0c01bf37))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19011(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x3d93f667))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19014(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xf0059553))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19015(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x3d8f01cb))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19016(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x29e11b6d))
                /// @src 0:38261:88845  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19017(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:7544:7547  "300" */ shl(224, 0x4647aac9))
                /// @src 0:38261:88845  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19018(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x60c18b0d))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError(usr_memPtr)
            {
                mstore(usr_memPtr, shl(229, 0x05f459a9))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19021(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x124f824d))
                /// @src 0:38261:88845  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19023(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xf8139caf))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19024(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xe246dc63))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19025(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x1390f2a1))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19026(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x297f31e1))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19027(usr_memPtr)
            {
                mstore(usr_memPtr, shl(227, 0x1064186b))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19028(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xf54d11f5))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19029(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xc859b3f5))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19030(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x315e8bad))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19031(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xe5c48ac5))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19032(usr_memPtr)
            {
                mstore(usr_memPtr, shl(227, 0x06ad4883))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19033(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x49337731))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19039(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x383241e3))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19150(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xd76adcd1))
                /// @src 0:38261:88845  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19151(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x5d2f8a05))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19152(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x987d1299))
                revert(usr_memPtr, 4)
            }
            function usr$assignStruct(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, /** @src 0:9417:9419  "22" */ not(shl(152, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:38261:88845  "assembly {..." */ shl(152, usr$newVal))
            }
            function usr$assignStruct_19037(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(112, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:38261:88845  "assembly {..." */ shl(112, usr$newVal))
            }
            function usr$assignStruct_19038(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(144, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255))), /** @src 0:38261:88845  "assembly {..." */ shl(144, usr$newVal))
            }
            function usr$structValue(usr_structObj) -> usr_val
            {
                usr_val := and(shr(96, usr_structObj), 65535)
            }
            function usr$rewardEpochIdFromVotingRoundId(usr_stateDataObj, usr$_votingRoundId) -> usr_rewardEpochId
            {
                let usr$firstRewardEpochStartVotingRoundId := and(shr(48, usr_stateDataObj), 4294967295)
                if lt(usr$_votingRoundId, usr$firstRewardEpochStartVotingRoundId)
                {
                    let _1 := mload(0x40)
                    mstore(_1, shl(226, 8083425))
                    revert(_1, 4)
                }
                usr_rewardEpochId := div(sub(usr$_votingRoundId, usr$firstRewardEpochStartVotingRoundId), and(shr(80, usr_stateDataObj), 65535))
            }
            function usr$calculateSigningPolicyHash_18999(usr_memPos, usr_policyLength, usr_sourceChainId) -> usr_policyHash
            {
                mstore(usr_memPos, usr_sourceChainId)
                calldatacopy(add(usr_memPos, 0x20), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4, /** @src 0:38261:88845  "assembly {..." */ usr_policyLength)
                usr_policyHash := keccak256(usr_memPos, add(0x20, usr_policyLength))
            }
            function usr$calculateSigningPolicyHash(usr$_memPos, usr_calldataPos, usr_policyLength, usr_sourceChainId) -> usr$_policyHash
            {
                mstore(usr$_memPos, usr_sourceChainId)
                calldatacopy(add(usr$_memPos, 0x20), usr_calldataPos, usr_policyLength)
                usr$_policyHash := keccak256(usr$_memPos, add(0x20, usr_policyLength))
            }
            function usr$extractVotingRoundIdFromMessage(usr_signingPolicyLength) -> usr_votingRoundId
            {
                usr_votingRoundId := and(shr(216, calldataload(add(4, usr_signingPolicyLength))), 4294967295)
            }
            function usr$calculateTotalWeight(usr_metadata) -> usr_totalWeight
            {
                let usr$numberOfVoters := and(shr(72, usr_metadata), 65535)
                let usr$i := 0
                for { } lt(usr$i, usr$numberOfVoters) { usr$i := add(usr$i, 1) }
                {
                    usr_totalWeight := add(usr_totalWeight, shr(240, calldataload(add(mul(usr$i, 22), 67))))
                }
            }
            function usr$checkThresholdConsistency(usr_memPtr, usr_metadata, usr_signingPolicyStart)
            {
                let usr_totalWeight := /** @src -1:-1:-1 */ 0
                /// @src 0:38261:88845  "assembly {..."
                let usr$numberOfVoters := and(shr(72, usr_metadata), 65535)
                let usr$i := /** @src -1:-1:-1 */ 0
                /// @src 0:38261:88845  "assembly {..."
                for { } lt(usr$i, usr$numberOfVoters) { usr$i := add(usr$i, 1) }
                {
                    usr_totalWeight := add(usr_totalWeight, shr(240, calldataload(add(add(usr_signingPolicyStart, mul(usr$i, 22)), 63))))
                }
                if gt(usr_totalWeight, 65535)
                {
                    mstore(usr_memPtr, /** @src 0:7544:7547  "300" */ shl(224, 0x8dd23571))
                    /// @src 0:38261:88845  "assembly {..."
                    revert(usr_memPtr, 4)
                }
                let _1 := mul(and(usr_metadata, 65535), 10000)
                if lt(_1, mul(usr_totalWeight, 5000))
                {
                    mstore(usr_memPtr, /** @src 0:7599:7603  "5000" */ shl(225, 0x1cc767c5))
                    /// @src 0:38261:88845  "assembly {..."
                    revert(usr_memPtr, 4)
                }
                if gt(_1, mul(usr_totalWeight, 6600))
                {
                    mstore(usr_memPtr, /** @src 0:7655:7659  "6600" */ shl(224, 0xe56d58cf))
                    /// @src 0:38261:88845  "assembly {..."
                    revert(usr_memPtr, 4)
                }
            }
            function usr$setIsSecureRandomBit(usr_memPtr, usr_votingRoundId)
            {
                mstore(usr_memPtr, shr(8, usr_votingRoundId))
                mstore(add(usr_memPtr, 32), 10)
                let _1 := keccak256(usr_memPtr, 64)
                sstore(_1, or(sload(_1), shl(sub(255, and(usr_votingRoundId, 255)), 1)))
            }
            function usr$processRandomMerkleProof(usr_memPtr, usr_proofStart, usr_memPtrMerkleRoot, usr_votingRoundId, usr_isSecureRandom)
            {
                let _1 := add(usr_proofStart, 32)
                if lt(calldatasize(), _1)
                {
                    usr$revertWithError_19150(usr_memPtr)
                }
                if iszero(iszero(and(sub(calldatasize(), usr_proofStart), 31)))
                {
                    usr$revertWithError_19151(usr_memPtr)
                }
                mstore(usr_memPtr, usr_votingRoundId)
                let _2 := add(usr_memPtr, 32)
                calldatacopy(_2, usr_proofStart, 32)
                let _3 := add(usr_memPtr, 64)
                mstore(_3, usr_isSecureRandom)
                mstore(usr_memPtr, keccak256(usr_memPtr, 96))
                let usr$pos := _1
                for { }
                lt(usr$pos, calldatasize())
                { usr$pos := add(usr$pos, 32) }
                {
                    calldatacopy(_2, usr$pos, 32)
                    if lt(mload(usr_memPtr), mload(_2))
                    {
                        mstore(usr_memPtr, keccak256(usr_memPtr, 64))
                        continue
                    }
                    mstore(_3, mload(usr_memPtr))
                    mstore(usr_memPtr, keccak256(_2, 64))
                }
                if iszero(eq(mload(usr_memPtr), mload(usr_memPtrMerkleRoot)))
                {
                    usr$revertWithError_19152(usr_memPtr)
                }
                calldatacopy(_3, usr_proofStart, 32)
                mstore(usr_memPtr, usr_votingRoundId)
                mstore(_2, 12)
                sstore(keccak256(usr_memPtr, 64), mload(_3))
            }
            /// @src 33:3426:3641  "function transferOwnership(address newOwner) public virtual onlyOwner {..."
            function fun_transferOwnership_inner(var_newOwner)
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := and(/** @src 33:3510:3532  "newOwner == address(0)" */ var_newOwner, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 33:3506:3597  "if (newOwner == address(0)) {..."
                if /** @src 33:3510:3532  "newOwner == address(0)" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1)
                /// @src 33:3506:3597  "if (newOwner == address(0)) {..."
                {
                    /// @src 33:3555:3586  "OwnableInvalidOwner(address(0))"
                    mstore(/** @src 33:3530:3531  "0" */ 0x00, /** @src 33:3555:3586  "OwnableInvalidOwner(address(0))" */ shl(224, 0x1e4fbdf7))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(/** @src 33:3555:3586  "OwnableInvalidOwner(address(0))" */ 4, /** @src 33:3530:3531  "0" */ 0x00)
                    /// @src 33:3555:3586  "OwnableInvalidOwner(address(0))"
                    revert(/** @src 33:3530:3531  "0" */ 0x00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                }
                let _2 := sload(/** @src 33:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 33:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_2, shl(160, 0xffffffffffffffffffffffff)), _1))
                /// @src 33:3996:4036  "OwnershipTransferred(oldOwner, newOwner)"
                log3(/** @src 33:3530:3531  "0" */ 0x00, 0x00, /** @src 33:3996:4036  "OwnershipTransferred(oldOwner, newOwner)" */ 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_2, sub(shl(160, 1), 1)), /** @src 33:3996:4036  "OwnershipTransferred(oldOwner, newOwner)" */ _1)
            }
            /// @ast-id 3275 @src 5:6458:6690  "function _timeToExecuteTimelockedCall()..."
            function fun_timeToExecuteTimelockedCall() -> var_
            {
                /// @src 5:6630:6683  "state.executing || state.timelockDurationSeconds == 0"
                let expr := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 5:1796:1838  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)
                /// @src 5:6630:6683  "state.executing || state.timelockDurationSeconds == 0"
                if iszero(expr)
                {
                    expr := /** @src 5:6649:6683  "state.timelockDurationSeconds == 0" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 5:6649:6678  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01))
                }
                /// @src 5:6623:6683  "return state.executing || state.timelockDurationSeconds == 0"
                var_ := expr
            }
            /// @ast-id 3255 @src 5:5785:6452  "function _recordTimelockedCall(..."
            function fun_recordTimelockedCall(var_encodedCall_length)
            {
                /// @src 5:5906:5938  "State storage state = getState()"
                fun_checkOwner()
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(/** @src 5:6136:6150  "msg.value == 0" */ iszero(/** @src 5:6136:6145  "msg.value" */ callvalue()))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src 5:2037:2045  "msg.data" */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xe8de4489))
                    revert(/** @src 5:2037:2045  "msg.data" */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 5:6214:6237  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:2037:2045  "msg.data" */ 0, /** @src 5:6214:6237  "keccak256(_encodedCall)" */ var_encodedCall_length, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                /// @src 5:6214:6237  "keccak256(_encodedCall)"
                let expr := keccak256(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:6214:6237  "keccak256(_encodedCall)" */ _mpos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:6214:6237  "keccak256(_encodedCall)" */ _mpos))
                /// @src 0:7544:7547  "300"
                let sum := add(/** @src 5:6267:6282  "block.timestamp" */ timestamp(), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 5:6285:6314  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01))
                /// @src 0:7544:7547  "300"
                if gt(/** @src 5:6267:6282  "block.timestamp" */ timestamp(), /** @src 0:7544:7547  "300" */ sum) { panic_error_0x11() }
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src 5:2037:2045  "msg.data" */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:6324:6345  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 5:1578:1584  "7 days"
                sstore(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ keccak256(/** @src 5:2037:2045  "msg.data" */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40), /** @src 5:1578:1584  "7 days" */ sum)
                /// @src 5:6389:6445  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)"
                let _1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                mstore(_1, 96)
                mstore(add(_1, 96), var_encodedCall_length)
                calldatacopy(add(_1, 128), /** @src 5:2037:2045  "msg.data" */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ var_encodedCall_length)
                mstore(add(add(_1, var_encodedCall_length), 128), /** @src 5:2037:2045  "msg.data" */ 0)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(_1, 0x20), expr)
                mstore(add(_1, 0x40), sum)
                /// @src 5:6389:6445  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)"
                log1(_1, add(sub(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(_1, and(add(var_encodedCall_length, 31), not(31))), /** @src 5:6389:6445  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)" */ _1), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 128), /** @src 5:6389:6445  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)" */ 0xcfe4e47fb61ab9e86fdf402e71633288356fe9946ea95fd84d6b233736e7caa2)
            }
            /// @ast-id 3202 @src 5:4863:5160  "function _beforeExecuteTimelockedCall()..."
            function fun_beforeExecuteTimelockedCall()
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(/** @src 5:1796:1838  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00)
                /// @src 5:4992:5154  "if (state.executing) {..."
                switch /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_1, 0xff)
                case /** @src 5:4992:5154  "if (state.executing) {..." */ 0 { fun_checkOwner() }
                default {
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if iszero(/** @src 5:5034:5061  "msg.sender == address(this)" */ eq(/** @src 5:5034:5044  "msg.sender" */ caller(), /** @src 5:5056:5060  "this" */ address()))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    {
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x4e487b71))
                        mstore(4, 0x01)
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x24)
                    }
                    sstore(/** @src 5:1796:1838  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_1, not(255)))
                }
            }
            /// @ast-id 3282 @src 5:6696:7173  "function _passReturnOrRevert(..."
            function fun_passReturnOrRevert(var__success)
            {
                /// @src 5:6869:7167  "assembly (\"memory-safe\") {..."
                let usr$size := returndatasize()
                let usr$ptr := mload(0x40)
                mstore(0x40, add(usr$ptr, usr$size))
                returndatacopy(usr$ptr, 0, usr$size)
                if var__success { return(usr$ptr, usr$size) }
                revert(usr$ptr, usr$size)
            }
            /// @ast-id 7481 @src 28:4638:4810  "function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {..."
            function fun_verifyCalldata(var_proof_7464_offset, var_proof_7464_length, var_root, var_leaf) -> var
            {
                /// @src 28:5325:5352  "bytes32 computedHash = leaf"
                let var_computedHash := var_leaf
                /// @src 28:5367:5380  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 28:5362:5496  "for (uint256 i = 0; i < proof.length; i++) {..."
                for { }
                /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1
                /// @src 28:5367:5380  "uint256 i = 0"
                {
                    /// @src 28:5400:5403  "i++"
                    var_i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 28:5400:5403  "i++" */ var_i, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1)
                }
                /// @src 28:5400:5403  "i++"
                {
                    /// @src 28:5382:5398  "i < proof.length"
                    let _1 := iszero(lt(var_i, /** @src 28:5386:5398  "proof.length" */ var_proof_7464_length))
                    /// @src 28:5382:5398  "i < proof.length"
                    if _1 { break }
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    _1 := /** @src -1:-1:-1 */ 0
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let value := calldataload(add(var_proof_7464_offset, shl(5, var_i)))
                    /// @src 27:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    let expr := /** @src -1:-1:-1 */ 0
                    /// @src 27:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    switch /** @src 27:605:610  "a < b" */ lt(var_computedHash, value)
                    case /** @src 27:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)" */ 0 {
                        /// @src 27:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 27:889:1024  "assembly (\"memory-safe\") {..." */ value)
                        mstore(0x20, var_computedHash)
                        /// @src 27:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 27:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 27:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    default /// @src 27:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    {
                        /// @src 27:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 27:889:1024  "assembly (\"memory-safe\") {..." */ var_computedHash)
                        mstore(0x20, value)
                        /// @src 27:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 27:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 27:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    /// @src 28:5419:5485  "computedHash = Hashes.commutativeKeccak256(computedHash, proof[i])"
                    var_computedHash := expr
                }
                /// @src 28:4755:4803  "return processProofCalldata(proof, leaf) == root"
                var := /** @src 28:4762:4803  "processProofCalldata(proof, leaf) == root" */ eq(var_computedHash, var_root)
            }
            /// @ast-id 4344 @src 18:1733:1965  "function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {..."
            function fun_safeTransferFrom(var_token_address, var_from, var_to, var_value)
            {
                /// @src 18:1838:1885  "_safeTransferFrom(token, from, to, value, true)"
                let var_success := /** @src -1:-1:-1 */ 0
                /// @src 18:11053:12201  "assembly (\"memory-safe\") {..."
                let usr$fmp := mload(0x40)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 18:11014:11042  "IERC20.transferFrom.selector" */ shl(224, 0x23b872dd))
                /// @src 18:11053:12201  "assembly (\"memory-safe\") {..."
                mstore(0x04, and(var_from, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
                /// @src 18:11053:12201  "assembly (\"memory-safe\") {..."
                mstore(0x24, and(var_to, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
                /// @src 18:11053:12201  "assembly (\"memory-safe\") {..."
                mstore(0x44, var_value)
                var_success := call(gas(), var_token_address, /** @src -1:-1:-1 */ 0, 0, /** @src 18:11053:12201  "assembly (\"memory-safe\") {..." */ 0x64, /** @src -1:-1:-1 */ 0, /** @src 18:11053:12201  "assembly (\"memory-safe\") {..." */ 0x20)
                if iszero(and(var_success, eq(mload(/** @src -1:-1:-1 */ 0), /** @src 18:1880:1884  "true" */ 0x01)))
                /// @src 18:11053:12201  "assembly (\"memory-safe\") {..."
                {
                    if and(iszero(var_success), /** @src 18:1880:1884  "true" */ 0x01)
                    /// @src 18:11053:12201  "assembly (\"memory-safe\") {..."
                    {
                        returndatacopy(usr$fmp, /** @src -1:-1:-1 */ 0, /** @src 18:11053:12201  "assembly (\"memory-safe\") {..." */ returndatasize())
                        revert(usr$fmp, returndatasize())
                    }
                    var_success := and(var_success, and(iszero(returndatasize()), iszero(iszero(extcodesize(var_token_address)))))
                }
                mstore(0x40, usr$fmp)
                mstore(96, /** @src -1:-1:-1 */ 0)
                /// @src 18:1833:1959  "if (!_safeTransferFrom(token, from, to, value, true)) {..."
                if /** @src 18:1837:1885  "!_safeTransferFrom(token, from, to, value, true)" */ cleanup_bool(iszero(/** @src 18:1838:1885  "_safeTransferFrom(token, from, to, value, true)" */ var_success))
                /// @src 18:1833:1959  "if (!_safeTransferFrom(token, from, to, value, true)) {..."
                {
                    /// @src 18:1908:1948  "SafeERC20FailedOperation(address(token))"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 18:1908:1948  "SafeERC20FailedOperation(address(token))" */ shl(224, 0x5274afe7))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 18:1908:1948  "SafeERC20FailedOperation(address(token))" */ abi_encode_address(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 18:1933:1947  "address(token)" */ var_token_address, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                }
            }
            /// @ast-id 2272 @src 0:100530:101767  "function _verifyCustomSignature(..."
            function fun_verifyCustomSignature(var_relayMessage_offset, var_relayMessage_length, var_messageHash) -> var_rewardEpochId
            {
                /// @src 0:100837:100870  "address(this).call(_relayMessage)"
                let _1 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                calldatacopy(_1, var_relayMessage_offset, var_relayMessage_length)
                let _2 := add(_1, var_relayMessage_length)
                mstore(_2, /** @src -1:-1:-1 */ 0)
                /// @src 0:100837:100870  "address(this).call(_relayMessage)"
                let expr_2234_component := call(gas(), /** @src 0:100845:100849  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 0:100837:100870  "address(this).call(_relayMessage)" */ _1, sub(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _2, /** @src 0:100837:100870  "address(this).call(_relayMessage)" */ _1), /** @src -1:-1:-1 */ 0, 0)
                /// @src 0:100837:100870  "address(this).call(_relayMessage)"
                let expr_component_mpos := extract_returndata()
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(expr_2234_component)
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x439cc0cd))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                if iszero(/** @src 0:101285:101308  "returnData.length == 35" */ eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:101285:101302  "returnData.length" */ expr_component_mpos), /** @src 0:101306:101308  "35" */ 0x23))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x801c629f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 0:101465:101650  "assembly {..."
                let var_returnHash := mload(add(expr_component_mpos, 0x20))
                let var_returnRewardEpochId := shr(232, mload(add(expr_component_mpos, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 64)))
                if iszero(/** @src 0:101667:101702  "bytes32(returnHash) == _messageHash" */ eq(var_returnHash, var_messageHash))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xb39d5b51))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 0:101734:101760  "return returnRewardEpochId"
                var_rewardEpochId := var_returnRewardEpochId
            }
            /// @ast-id 3887 @src 14:6891:6967  "modifier onlyInitializing() {..."
            function modifier_onlyInitializing(var_initialOwner)
            {
                fun_checkInitializing()
                fun_checkInitializing()
                /// @src 14:6959:6960  "_"
                fun_transferOwnership_inner(var_initialOwner)
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function require_helper_error_ProtocolFeeZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x3dcffc5b))
                    revert(0, 4)
                }
            }
            function require_helper_error_DuplicateProtocolId(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xdb295d05))
                    revert(0, 4)
                }
            }
            /// @ast-id 2215 @src 0:99538:100524  "function _setProtocolFees(..."
            function fun_setProtocolFees(var_feeToken, var_feeConfigs_mpos)
            {
                /// @src 0:99668:99913  "while (feeProtocolIdsPrivate.length() > 0) {..."
                for { }
                /** @src 0:99804:99805  "1" */ 0x01
                /// @src 0:99668:99913  "while (feeProtocolIdsPrivate.length() > 0) {..."
                { }
                {
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let length := sload(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07)
                    /// @src 0:99675:99709  "feeProtocolIdsPrivate.length() > 0"
                    if iszero(length) { break }
                    /// @src 32:23238:23261  "_pos(set._inner, index)"
                    let _1 := fun_pos(/** @src 0:99771:99805  "feeProtocolIdsPrivate.length() - 1" */ checked_sub_uint256_19254(/** @src 32:5434:5452  "set._values.length" */ length))
                    /// @src 32:21254:21289  "_remove(set._inner, bytes32(value))"
                    pop(fun_remove(/** @src 32:21274:21288  "bytes32(value)" */ _1))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let slot := /** @src 0:99880:99902  "protocolFee[clearedId]" */ mapping_index_access_mapping_uint256__uint256__of_uint256(_1)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let result := /** @src 5:2445:2446  "0" */ 0x00
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    result := /** @src 5:2445:2446  "0" */ 0x00
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    sstore(slot, /** @src 5:2445:2446  "0" */ 0x00)
                }
                /// @src 0:99922:99942  "feeToken = _feeToken"
                update_storage_value_offset_address_to_address_19259(var_feeToken)
                /// @src 0:99957:99970  "uint256 i = 0"
                let var_i := /** @src 0:99708:99709  "0" */ 0x00
                /// @src 0:99952:100464  "for (uint256 i = 0; i < _feeConfigs.length; i++) {..."
                for { }
                /** @src 0:99804:99805  "1" */ 0x01
                /// @src 0:99957:99970  "uint256 i = 0"
                {
                    /// @src 0:99996:99999  "i++"
                    var_i := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:99996:99999  "i++" */ var_i, /** @src 0:99804:99805  "1" */ 0x01)
                }
                /// @src 0:99996:99999  "i++"
                {
                    /// @src 0:99972:99994  "i < _feeConfigs.length"
                    if iszero(lt(var_i, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:99976:99994  "_feeConfigs.length" */ var_feeConfigs_mpos)))
                    /// @src 0:99972:99994  "i < _feeConfigs.length"
                    { break }
                    /// @src 0:100034:100059  "_feeConfigs[i].protocolId"
                    let _2 := read_from_memoryt_uint8(/** @src 0:100034:100048  "_feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(var_feeConfigs_mpos, var_i)))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _3 := and(/** @src 0:100081:100095  "protocolId > 1" */ _2, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)
                    /// @src 0:100073:100117  "require(protocolId > 1, InvalidProtocolId())"
                    require_helper_error_InvalidProtocolId(/** @src 0:100081:100095  "protocolId > 1" */ gt(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _3, /** @src 0:99804:99805  "1" */ 0x01))
                    /// @src 0:100131:100181  "require(_feeConfigs[i].fee > 0, ProtocolFeeZero())"
                    require_helper_error_ProtocolFeeZero(/** @src 0:100139:100161  "_feeConfigs[i].fee > 0" */ iszero(iszero(/** @src 0:9417:9419  "22" */ mload(/** @src 0:100139:100157  "_feeConfigs[i].fee" */ add(/** @src 0:100139:100153  "_feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(var_feeConfigs_mpos, var_i)), /** @src 0:100139:100157  "_feeConfigs[i].fee" */ 32)))))
                    /// @src 5:1578:1584  "7 days"
                    sstore(/** @src 0:100195:100218  "protocolFee[protocolId]" */ mapping_index_access_mapping_uint256_mapping_uint256_bytes32__of_uint8(_2), /** @src 0:9417:9419  "22" */ mload(/** @src 0:100221:100239  "_feeConfigs[i].fee" */ add(/** @src 0:100221:100235  "_feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(var_feeConfigs_mpos, var_i)), /** @src 0:100139:100157  "_feeConfigs[i].fee" */ 32)))
                    /// @src 0:100384:100453  "require(feeProtocolIdsPrivate.add(protocolId), DuplicateProtocolId())"
                    require_helper_error_DuplicateProtocolId(/** @src 32:20954:20986  "_add(set._inner, bytes32(value))" */ fun_add(/** @src 32:20971:20985  "bytes32(value)" */ _3))
                }
                /// @src 0:100478:100517  "ProtocolFeesSet(_feeToken, _feeConfigs)"
                let _4 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                /// @src 0:100478:100517  "ProtocolFeesSet(_feeToken, _feeConfigs)"
                log2(_4, sub(abi_encode_array_struct_FeeConfig_dyn(_4, var_feeConfigs_mpos), _4), 0x48bea0d997ec5c0b88b7100b4de90ecccfd5ddf9007d9b3d588b21d45e6c7ab9, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:100478:100517  "ProtocolFeesSet(_feeToken, _feeConfigs)" */ var_feeToken, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
            }
            /// @ast-id 13748 @src 33:2679:2841  "function _checkOwner() internal view virtual {..."
            function fun_checkOwner()
            {
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let cleaned := and(sload(/** @src 33:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 33:2734:2835  "if (owner() != _msgSender()) {..."
                if /** @src 33:2738:2761  "owner() != _msgSender()" */ iszero(eq(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleaned, /** @src 34:987:997  "msg.sender" */ caller()))
                /// @src 33:2734:2835  "if (owner() != _msgSender()) {..."
                {
                    /// @src 33:2784:2824  "OwnableUnauthorizedAccount(_msgSender())"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 33:2784:2824  "OwnableUnauthorizedAccount(_msgSender())" */ shl(224, 0x118cdaa7))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(/** @src 33:2784:2824  "OwnableUnauthorizedAccount(_msgSender())" */ 4, /** @src 34:987:997  "msg.sender" */ caller())
                    /// @src 33:2784:2824  "OwnableUnauthorizedAccount(_msgSender())"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                }
            }
            function storage_array_index_access_bytes32_dyn(array, index) -> slot, offset
            {
                if iszero(lt(index, sload(array))) { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ array)
                slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), index)
                offset := /** @src -1:-1:-1 */ 0
            }
            /// @ast-id 12049 @src 32:5801:5920  "function _pos(Set storage set, uint256 index) private view returns (bytes32) {..."
            function fun_pos(var_index) -> var
            {
                /// @src 32:5895:5913  "set._values[index]"
                let slot := /** @src -1:-1:-1 */ 0
                /// @src 32:5895:5913  "set._values[index]"
                let offset := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(lt(var_index, sload(/** @src 0:94067:94088  "feeProtocolIdsPrivate" */ 0x07)))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:94067:94088  "feeProtocolIdsPrivate" */ 0x07)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), var_index)
                offset := /** @src -1:-1:-1 */ 0
                /// @src 32:5888:5913  "return set._values[index]"
                var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 32:5895:5913  "set._values[index]" */ slot)
            }
            /// @ast-id 3900 @src 14:7082:7223  "function _checkInitializing() internal view virtual {..."
            function fun_checkInitializing()
            {
                /// @src 14:7144:7217  "if (!_isInitializing()) {..."
                if /** @src 14:7148:7166  "!_isInitializing()" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(64, sload(/** @src 14:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff))
                /// @src 14:7144:7217  "if (!_isInitializing()) {..."
                {
                    /// @src 14:7189:7206  "NotInitializing()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 14:7189:7206  "NotInitializing()" */ shl(227, 0x1afcd79f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 14:7189:7206  "NotInitializing()" */ 4)
                }
            }
            /// @ast-id 3529 @src 12:2264:2608  "function upgradeToAndCall(address newImplementation, bytes memory data) internal {..."
            function fun_upgradeToAndCall(var_newImplementation, var_data_mpos)
            {
                /// @src 12:1744:1863  "if (newImplementation.code.length == 0) {..."
                if /** @src 12:1748:1782  "newImplementation.code.length == 0" */ iszero(/** @src 12:1748:1777  "newImplementation.code.length" */ extcodesize(var_newImplementation))
                /// @src 12:1744:1863  "if (newImplementation.code.length == 0) {..."
                {
                    /// @src 12:1805:1852  "ERC1967InvalidImplementation(newImplementation)"
                    mstore(/** @src 12:1781:1782  "0" */ 0x00, /** @src 15:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)" */ shl(224, 0x4c9c8ce3))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(/** @src 12:1805:1852  "ERC1967InvalidImplementation(newImplementation)" */ 4, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(var_newImplementation, sub(shl(160, 1), 1)))
                    /// @src 12:1805:1852  "ERC1967InvalidImplementation(newImplementation)"
                    revert(/** @src 12:1781:1782  "0" */ 0x00, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                }
                let _1 := and(var_newImplementation, sub(shl(160, 1), 1))
                sstore(/** @src 12:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 12:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc), /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(160, 0xffffffffffffffffffffffff)), _1))
                /// @src 12:2407:2443  "IERC1967.Upgraded(newImplementation)"
                log2(/** @src 12:1781:1782  "0" */ 0x00, 0x00, /** @src 12:2407:2443  "IERC1967.Upgraded(newImplementation)" */ 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b, _1)
                /// @src 12:2454:2602  "if (data.length > 0) {..."
                switch /** @src 12:2458:2473  "data.length > 0" */ iszero(iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 12:2458:2469  "data.length" */ var_data_mpos)))
                case /** @src 12:2454:2602  "if (data.length > 0) {..." */ 0 {
                    /// @src 12:6181:6251  "if (msg.value > 0) {..."
                    if /** @src 12:6185:6198  "msg.value > 0" */ iszero(iszero(/** @src 12:6185:6194  "msg.value" */ callvalue()))
                    /// @src 12:6181:6251  "if (msg.value > 0) {..."
                    {
                        /// @src 12:6221:6240  "ERC1967NonPayable()"
                        mstore(/** @src 12:1781:1782  "0" */ 0x00, /** @src 12:6221:6240  "ERC1967NonPayable()" */ shl(224, 0xb398979f))
                        revert(/** @src 12:1781:1782  "0" */ 0x00, /** @src 12:6221:6240  "ERC1967NonPayable()" */ 4)
                    }
                }
                default /// @src 12:2454:2602  "if (data.length > 0) {..."
                {
                    /// @src 12:2489:2542  "Address.functionDelegateCall(newImplementation, data)"
                    pop(fun_functionDelegateCall(var_newImplementation, var_data_mpos))
                }
            }
            /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function array_pop_array_bytes32_dyn_storage_ptr(array)
            {
                let oldLen := sload(array)
                if iszero(oldLen)
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x31)
                    revert(0, 0x24)
                }
                let newLen := add(oldLen, /** @src 0:38261:88845  "assembly {..." */ not(0))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let slot, offset := storage_array_index_access_bytes32_dyn(array, newLen)
                let _1 := sload(slot)
                let result := /** @src -1:-1:-1 */ 0
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                result := and(_1, not(shl(shl(3, offset), /** @src 0:38261:88845  "assembly {..." */ not(0))))
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(slot, result)
                sstore(array, newLen)
            }
            /// @ast-id 11956 @src 32:3112:4480  "function _remove(Set storage set, bytes32 value) private returns (bool) {..."
            function fun_remove(var_value) -> var
            {
                /// @src 32:3178:3182  "bool"
                var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                mstore(0, var_value)
                mstore(0x20, /** @src 32:3307:3321  "set._positions" */ 8)
                /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(keccak256(0, 0x40))
                /// @src 32:3339:4474  "if (position != 0) {..."
                switch /** @src 32:3343:3356  "position != 0" */ iszero(iszero(_1))
                case /** @src 32:3339:4474  "if (position != 0) {..." */ 0 {
                    /// @src 32:4451:4463  "return false"
                    var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 32:4451:4463  "return false"
                    leave
                }
                default /// @src 32:3339:4474  "if (position != 0) {..."
                {
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let diff := add(_1, /** @src 0:38261:88845  "assembly {..." */ not(0))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if gt(diff, _1) { panic_error_0x11() }
                    let _2 := sload(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let diff_1 := add(_2, /** @src 0:38261:88845  "assembly {..." */ not(0))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if gt(diff_1, _2) { panic_error_0x11() }
                    /// @src 32:3814:4192  "if (valueIndex != lastIndex) {..."
                    if /** @src 32:3818:3841  "valueIndex != lastIndex" */ iszero(eq(diff, diff_1))
                    /// @src 32:3814:4192  "if (valueIndex != lastIndex) {..."
                    {
                        /// @src 32:3881:3903  "set._values[lastIndex]"
                        let _3, _4 := storage_array_index_access_bytes32_dyn(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07, /** @src 32:3881:3903  "set._values[lastIndex]" */ diff_1)
                        let _5 := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_dynamict_uint256(sload(/** @src 32:3881:3903  "set._values[lastIndex]" */ _3), _4)
                        /// @src 32:4002:4025  "set._values[valueIndex]"
                        let _6, _7 := storage_array_index_access_bytes32_dyn(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07, /** @src 32:4002:4025  "set._values[valueIndex]" */ diff)
                        /// @src 32:4002:4037  "set._values[valueIndex] = lastValue"
                        update_storage_value_uint256_to_uint256(_6, _7, _5)
                        /// @src 5:1578:1584  "7 days"
                        sstore(/** @src 32:4141:4166  "set._positions[lastValue]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 32:3307:3321  "set._positions" */ 8, /** @src 32:4141:4166  "set._positions[lastValue]" */ _5), /** @src 5:1578:1584  "7 days" */ _1)
                    }
                    /// @src 32:4270:4285  "set._values.pop"
                    array_pop_array_bytes32_dyn_storage_ptr(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let slot := /** @src 32:4373:4394  "set._positions[value]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 32:3307:3321  "set._positions" */ 8, /** @src 32:4373:4394  "set._positions[value]" */ var_value)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let result := /** @src 5:2445:2446  "0" */ 0x00
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    result := /** @src 5:2445:2446  "0" */ 0x00
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    sstore(slot, /** @src 5:2445:2446  "0" */ 0x00)
                    /// @src 32:4409:4420  "return true"
                    var := /** @src 32:3307:3321  "set._positions" */ 1
                    /// @src 32:4409:4420  "return true"
                    leave
                }
            }
            /// @ast-id 11872 @src 32:2538:2944  "function _add(Set storage set, bytes32 value) private returns (bool) {..."
            function fun_add(var_value) -> var
            {
                /// @src 32:2601:2605  "bool"
                var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                mstore(0, var_value)
                mstore(0x20, /** @src 32:5238:5252  "set._positions" */ 8)
                /// @src 32:2617:2938  "if (!_contains(set, value)) {..."
                switch /** @src 32:5238:5264  "set._positions[value] != 0" */ iszero(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(keccak256(0, 0x40)))
                case /** @src 32:2617:2938  "if (!_contains(set, value)) {..." */ 0 {
                    /// @src 32:2915:2927  "return false"
                    var := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 32:2915:2927  "return false"
                    leave
                }
                default /// @src 32:2617:2938  "if (!_contains(set, value)) {..."
                {
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let oldLen := sload(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if iszero(lt(oldLen, 18446744073709551616)) { panic_error_0x41() }
                    sstore(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(oldLen, /** @src 32:5238:5252  "set._positions" */ 1))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let slot := /** @src -1:-1:-1 */ 0
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let offset := /** @src -1:-1:-1 */ 0
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if iszero(lt(oldLen, sload(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07)))
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    { panic_error_0x32() }
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), oldLen)
                    offset := /** @src -1:-1:-1 */ 0
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    sstore(slot, update_byte_slice_dynamic32(sload(slot), /** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ var_value))
                    /// @src 32:2841:2859  "set._values.length"
                    let expr := /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:99675:99696  "feeProtocolIdsPrivate" */ 0x07)
                    /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ var_value)
                    mstore(0x20, /** @src 32:5238:5252  "set._positions" */ 8)
                    /// @src 5:1578:1584  "7 days"
                    sstore(/** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40), /** @src 5:1578:1584  "7 days" */ expr)
                    /// @src 32:2873:2884  "return true"
                    var := /** @src 32:5238:5252  "set._positions" */ 1
                    /// @src 32:2873:2884  "return true"
                    leave
                }
            }
            /// @ast-id 5038 @src 19:4691:5240  "function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {..."
            function fun_functionDelegateCall(var_target, var_data_4979_mpos) -> var_mpos
            {
                /// @src 19:4874:4946  "success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)"
                let expr := /** @src 23:3526:3655  "assembly (\"memory-safe\") {..." */ delegatecall(gas(), var_target, add(var_data_4979_mpos, 0x20), mload(var_data_4979_mpos), /** @src -1:-1:-1 */ 0, 0)
                /// @src 23:3526:3655  "assembly (\"memory-safe\") {..."
                let var_success := /** @src 19:4874:4946  "success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)" */ expr
                if expr
                {
                    /// @src 19:4886:4919  "LowLevelCall.returnDataSize() > 0"
                    let _1 := iszero(/** @src 23:4578:4651  "assembly (\"memory-safe\") {..." */ returndatasize())
                    /// @src 19:4886:4945  "LowLevelCall.returnDataSize() > 0 || target.code.length > 0"
                    let expr_1 := /** @src 19:4886:4919  "LowLevelCall.returnDataSize() > 0" */ iszero(_1)
                    /// @src 19:4886:4945  "LowLevelCall.returnDataSize() > 0 || target.code.length > 0"
                    if _1
                    {
                        expr_1 := /** @src 19:4923:4945  "target.code.length > 0" */ iszero(iszero(/** @src 19:4923:4941  "target.code.length" */ extcodesize(var_target)))
                    }
                    /// @src 19:4874:4946  "success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)"
                    expr := expr_1
                }
                /// @src 19:4870:5234  "if (success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)) {..."
                switch expr
                case 0 {
                    /// @src 19:5011:5234  "if (success) {..."
                    switch var_success
                    case 0 {
                        /// @src 19:5086:5234  "if (LowLevelCall.returnDataSize() > 0) {..."
                        switch /** @src 19:5090:5123  "LowLevelCall.returnDataSize() > 0" */ iszero(iszero(/** @src 23:4578:4651  "assembly (\"memory-safe\") {..." */ returndatasize()))
                        case /** @src 19:5086:5234  "if (LowLevelCall.returnDataSize() > 0) {..." */ 0 {
                            /// @src 19:5204:5223  "Errors.FailedCall()"
                            mstore(/** @src -1:-1:-1 */ 0, /** @src 19:5204:5223  "Errors.FailedCall()" */ shl(224, 0xd6bda275))
                            revert(/** @src -1:-1:-1 */ 0, /** @src 19:5204:5223  "Errors.FailedCall()" */ 4)
                        }
                        default /// @src 19:5086:5234  "if (LowLevelCall.returnDataSize() > 0) {..."
                        {
                            /// @src 19:5139:5151  "LowLevelCall"
                            revert_forward()
                        }
                    }
                    default /// @src 19:5011:5234  "if (success) {..."
                    {
                        /// @src 19:5045:5069  "AddressEmptyCode(target)"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 19:5045:5069  "AddressEmptyCode(target)" */ shl(224, 0x9996b315))
                        /// @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                        mstore(/** @src 19:5045:5069  "AddressEmptyCode(target)" */ 4, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(var_target, sub(shl(160, 1), 1)))
                        /// @src 19:5045:5069  "AddressEmptyCode(target)"
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:1230:101769  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                    }
                }
                default /// @src 19:4870:5234  "if (success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)) {..."
                {
                    /// @src 19:4962:4994  "return LowLevelCall.returnData()"
                    var_mpos := /** @src 19:4969:4994  "LowLevelCall.returnData()" */ fun_returnData()
                    /// @src 19:4962:4994  "return LowLevelCall.returnData()"
                    leave
                }
            }
            /// @ast-id 6948 @src 23:4740:5074  "function returnData() internal pure returns (bytes memory result) {..."
            function fun_returnData() -> var_result_mpos
            {
                /// @src 23:4816:5068  "assembly (\"memory-safe\") {..."
                var_result_mpos := mload(0x40)
                mstore(var_result_mpos, returndatasize())
                returndatacopy(add(var_result_mpos, 0x20), 0x00, returndatasize())
                mstore(0x40, add(add(var_result_mpos, returndatasize()), 0x20))
            }
        }
        data ".metadata" hex"a264697066735822122017b4dfeb655b68ff5b47cbe17a7b158de43dae52c5a63d50fbccbe5e67e41f1064736f6c63430008230033"
    }
}
