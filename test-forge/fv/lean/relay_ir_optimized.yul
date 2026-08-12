/// @use-src 0:"contracts/protocol/implementation/Relay.sol", 1:"contracts/protocol/interface/IIRelay.sol", 2:"contracts/userInterfaces/IOwnableWithTimelock.sol", 3:"contracts/userInterfaces/IRelay.sol", 4:"contracts/userInterfaces/LTS/RandomNumberV2Interface.sol", 5:"contracts/utils/implementation/OwnableWithTimelock.sol", 7:"dependencies/@openzeppelin-contracts-5.7.0/interfaces/draft-IERC1822.sol", 10:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/Initializable.sol", 11:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/UUPSUpgradeable.sol", 18:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/access/OwnableUpgradeable.sol", 19:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/utils/ContextUpgradeable.sol"
object "Relay_2495" {
    code {
        {
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            let _1 := memoryguard(0xa0)
            mstore(64, _1)
            if callvalue() { revert(0, 0) }
            /// @src 11:1076:1089  "address(this)"
            mstore(128, /** @src 11:1084:1088  "this" */ address())
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            let _2 := sload(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)
            /// @src 10:7894:7970  "if ($._initializing) {..."
            if /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(64, _2), 0xff)
            /// @src 10:7894:7970  "if ($._initializing) {..."
            {
                /// @src 10:7936:7959  "InvalidInitialization()"
                mstore(/** @src -1:-1:-1 */ 0, /** @src 10:7936:7959  "InvalidInitialization()" */ shl(224, 0xf92ee8a9))
                revert(/** @src -1:-1:-1 */ 0, /** @src 10:7936:7959  "InvalidInitialization()" */ 4)
            }
            /// @src 10:7979:8125  "if ($._initialized != type(uint64).max) {..."
            if /** @src 10:7983:8017  "$._initialized != type(uint64).max" */ iszero(eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_2, sub(shl(64, 1), 1)), sub(shl(64, 1), 1)))
            /// @src 10:7979:8125  "if ($._initialized != type(uint64).max) {..."
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(_2, not(sub(shl(64, 1), 1))), sub(shl(64, 1), 1)))
                mstore(_1, sub(shl(64, 1), 1))
                /// @src 10:8085:8114  "Initialized(type(uint64).max)"
                log1(_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32, /** @src 10:8085:8114  "Initialized(type(uint64).max)" */ 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            let _3 := mload(64)
            let _4 := datasize("Relay_2495_deployed")
            codecopy(_3, dataoffset("Relay_2495_deployed"), _4)
            setimmutable(_3, "4159", mload(/** @src 11:1076:1089  "address(this)" */ 128))
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            return(_3, _4)
        }
    }
    /// @use-src 0:"contracts/protocol/implementation/Relay.sol", 5:"contracts/utils/implementation/OwnableWithTimelock.sol", 8:"dependencies/@openzeppelin-contracts-5.7.0/proxy/ERC1967/ERC1967Utils.sol", 10:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/Initializable.sol", 11:"dependencies/@openzeppelin-contracts-5.7.0/proxy/utils/UUPSUpgradeable.sol", 12:"dependencies/@openzeppelin-contracts-5.7.0/utils/Address.sol", 14:"dependencies/@openzeppelin-contracts-5.7.0/utils/LowLevelCall.sol", 15:"dependencies/@openzeppelin-contracts-5.7.0/utils/StorageSlot.sol", 16:"dependencies/@openzeppelin-contracts-5.7.0/utils/cryptography/Hashes.sol", 17:"dependencies/@openzeppelin-contracts-5.7.0/utils/cryptography/MerkleProof.sol", 18:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/access/OwnableUpgradeable.sol", 19:"dependencies/@openzeppelin-contracts-upgradeable-5.7.0/utils/ContextUpgradeable.sol"
    object "Relay_2495_deployed" {
        code {
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
                    case 0x1684afe8 {
                        external_fun_setProtocolFees()
                    }
                    case 0x1d5226a3 { external_fun_initialize() }
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1349:1379  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:1493:1501  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 5:3075:3168  "require(_timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS, TimelockDurationTooLong())"
                    require_helper_error_TimelockDurationTooLong(/** @src 5:3083:3140  "_timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS" */ iszero(gt(value, /** @src 5:1188:1194  "7 days" */ 0x093a80)))
                    sstore(/** @src 5:3178:3207  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01, /** @src 5:1188:1194  "7 days" */ value)
                    /// @src 5:3249:3294  "TimelockDurationSet(_timelockDurationSeconds)"
                    let _1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    mstore(_1, value)
                    /// @src 5:3249:3294  "TimelockDurationSet(_timelockDurationSeconds)"
                    log1(_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32, /** @src 5:3249:3294  "TimelockDurationSet(_timelockDurationSeconds)" */ 0xf15cdeff5f6a37216412a72678ec978762dc7264a85f30590ed54b14ab51bbdf)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_sourceChainId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:15835:15872  "uint256 public override sourceChainId" */ 11)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function abi_decode_array_struct_FeeConfig_calldata_dyn_calldata(dataEnd) -> value0, value1
            {
                if slt(add(dataEnd, not(3)), 32) { revert(0, 0) }
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                let offset_1 := add(4, offset)
                let arrayPos := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let length := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(slt(add(offset_1, 0x1f), dataEnd))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                length := calldataload(offset_1)
                if gt(length, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                arrayPos := add(offset_1, 0x20)
                if gt(add(add(offset_1, shl(6, length)), 0x20), dataEnd) { revert(0, 0) }
                value0 := arrayPos
                value1 := length
            }
            function external_fun_setProtocolFees()
            {
                if callvalue() { revert(0, 0) }
                let param, param_1 := abi_decode_array_struct_FeeConfig_calldata_dyn_calldata(calldatasize())
                /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1349:1379  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:1493:1501  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:34206:34271  "require(signingPolicySetter == address(0), FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:34214:34247  "signingPolicySetter == address(0)" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:34214:34233  "signingPolicySetter" */ 0x03), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                    /// @src 0:34286:34299  "uint256 i = 0"
                    let var_i := /** @src -1:-1:-1 */ 0
                    /// @src 0:34281:34595  "for (uint256 i = 0; i < _feeConfigs.length; i++) {..."
                    for { }
                    /** @src 0:34301:34323  "i < _feeConfigs.length" */ lt(var_i, /** @src 0:34305:34323  "_feeConfigs.length" */ param_1)
                    /// @src 0:34286:34299  "uint256 i = 0"
                    {
                        /// @src 0:34325:34328  "i++"
                        var_i := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:34325:34328  "i++" */ var_i, /** @src 0:34423:34424  "1" */ 0x01)
                    }
                    /// @src 0:34325:34328  "i++"
                    {
                        /// @src 0:34363:34388  "_feeConfigs[i].protocolId"
                        let expr := read_from_calldatat_uint8(/** @src 0:34363:34377  "_feeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(param, param_1, var_i))
                        /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                        let _1 := and(/** @src 0:34410:34424  "protocolId > 1" */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)
                        /// @src 0:34402:34446  "require(protocolId > 1, InvalidProtocolId())"
                        require_helper_error_InvalidProtocolId(/** @src 0:34410:34424  "protocolId > 1" */ gt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1, /** @src 0:34423:34424  "1" */ 0x01))
                        /// @src 0:34491:34514  "_feeConfigs[i].feeInWei"
                        let _2 := add(/** @src 0:34491:34505  "_feeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(param, param_1, var_i), /** @src 0:34491:34514  "_feeConfigs[i].feeInWei" */ 32)
                        let value := /** @src -1:-1:-1 */ 0
                        /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                        value := calldataload(_2)
                        /// @src 5:1188:1194  "7 days"
                        sstore(/** @src 0:34460:34488  "protocolFeeInWei[protocolId]" */ mapping_index_access_mapping_uint256__uint256__of_uint8(expr), /** @src 5:1188:1194  "7 days" */ value)
                        /// @src 0:34560:34583  "_feeConfigs[i].feeInWei"
                        let _3 := add(/** @src 0:34560:34574  "_feeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(param, param_1, var_i), /** @src 0:34491:34514  "_feeConfigs[i].feeInWei" */ 32)
                        /// @src 0:34560:34583  "_feeConfigs[i].feeInWei"
                        let value_1 := /** @src -1:-1:-1 */ 0
                        /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                        value_1 := calldataload(_3)
                        /// @src 0:34533:34584  "ProtocolFeeSet(protocolId, _feeConfigs[i].feeInWei)"
                        let _4 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                        /// @src 0:34533:34584  "ProtocolFeeSet(protocolId, _feeConfigs[i].feeInWei)"
                        log2(_4, sub(abi_encode_tuple_bytes32(_4, value_1), _4), 0x9e48fd6a5a4b85a56901f1e36dfa8e5322e39f6785209de54a38f4392386ed8d, _1)
                    }
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(0, 0)
            }
            function panic_error_0x41()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(0, 0x24)
            }
            function finalize_allocation_19939(memPtr)
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
                finalize_allocation(memPtr, 0x01e0)
            }
            function allocate_memory_19968() -> memPtr
            {
                memPtr := mload(64)
                finalize_allocation(memPtr, 0xc0)
            }
            function cleanup_uint32(value) -> cleaned
            {
                cleaned := and(value, 0xffffffff)
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
            function abi_decode_bytes32() -> value
            { value := calldataload(68) }
            function cleanup_uint8(value) -> cleaned
            { cleaned := and(value, 0xff) }
            function validator_revert_uint8(value)
            {
                if iszero(eq(value, and(value, 0xff))) { revert(0, 0) }
            }
            function abi_decode_uint8(offset) -> value
            {
                value := calldataload(offset)
                validator_revert_uint8(value)
            }
            function cleanup_uint16(value) -> cleaned
            { cleaned := and(value, 0xffff) }
            function validator_revert_uint16(value)
            {
                if iszero(eq(value, and(value, 0xffff))) { revert(0, 0) }
            }
            function abi_decode_uint16(offset) -> value
            {
                value := calldataload(offset)
                validator_revert_uint16(value)
            }
            function cleanup_address_payable(value) -> cleaned
            {
                cleaned := and(value, sub(shl(160, 1), 1))
            }
            function validator_revert_address_payable(value)
            {
                if iszero(eq(value, and(value, sub(shl(160, 1), 1)))) { revert(0, 0) }
            }
            function abi_decode_address_payable(offset) -> value
            {
                value := calldataload(offset)
                validator_revert_address_payable(value)
            }
            function array_allocation_size_array_struct_FeeConfig_dyn(length) -> size
            {
                if gt(length, 0xffffffffffffffff) { panic_error_0x41() }
                size := add(shl(5, length), 0x20)
            }
            function abi_decode_array_struct_FeeConfig_dyn(offset, end) -> array
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                let length := calldataload(offset)
                let _1 := array_allocation_size_array_struct_FeeConfig_dyn(length)
                let memPtr := mload(64)
                finalize_allocation(memPtr, _1)
                let dst := memPtr
                mstore(memPtr, length)
                dst := add(memPtr, 0x20)
                let srcEnd := add(add(offset, shl(6, length)), 0x20)
                if gt(srcEnd, end)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let src := add(offset, 0x20)
                for { } lt(src, srcEnd) { src := add(src, 64) }
                {
                    if slt(sub(end, src), 64)
                    {
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let memPtr_1 := mload(64)
                    finalize_allocation_19939(memPtr_1)
                    let value := calldataload(src)
                    validator_revert_uint8(value)
                    mstore(memPtr_1, value)
                    let value_1 := /** @src -1:-1:-1 */ 0
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    value_1 := calldataload(add(src, 0x20))
                    mstore(add(memPtr_1, 0x20), value_1)
                    mstore(dst, memPtr_1)
                    dst := add(dst, 0x20)
                }
                array := memPtr
            }
            function abi_decode_address() -> value
            {
                value := calldataload(36)
                validator_revert_address_payable(value)
            }
            function abi_decode_t_address() -> value
            {
                value := calldataload(100)
                validator_revert_address_payable(value)
            }
            function abi_decode_array_address_dyn(offset, end) -> array
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                let length := calldataload(offset)
                let _1 := array_allocation_size_array_struct_FeeConfig_dyn(length)
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let src := add(offset, 0x20)
                for { } lt(src, srcEnd) { src := add(src, 0x20) }
                {
                    let value := calldataload(src)
                    validator_revert_address_payable(value)
                    mstore(dst, value)
                    dst := add(dst, 0x20)
                }
                array := memPtr
            }
            function abi_decode_contract_IRelay() -> value
            {
                value := calldataload(68)
                validator_revert_address_payable(value)
            }
            function external_fun_initialize()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 128)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0x01e0)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := allocate_memory()
                mstore(value, abi_decode_uint32(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(add(offset, 68))
                mstore(add(value, 64), value_1)
                mstore(add(value, 96), abi_decode_uint8(add(offset, 100)))
                mstore(add(value, 128), abi_decode_uint32(add(offset, 132)))
                mstore(add(value, 160), abi_decode_uint8(add(offset, 164)))
                mstore(add(value, 192), abi_decode_uint32(add(offset, 196)))
                mstore(add(value, 224), abi_decode_uint16(add(offset, 228)))
                mstore(add(value, 256), abi_decode_uint16(add(offset, 260)))
                mstore(add(value, 288), abi_decode_uint32(add(offset, 292)))
                mstore(add(value, 320), abi_decode_address_payable(add(offset, 324)))
                let offset_1 := calldataload(add(offset, 356))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 352), abi_decode_array_struct_FeeConfig_dyn(add(add(offset, offset_1), 4), calldatasize()))
                let offset_2 := calldataload(add(offset, 388))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 384), abi_decode_array_address_dyn(add(add(offset, offset_2), 4), calldatasize()))
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_2 := calldataload(add(offset, 420))
                mstore(add(value, 416), value_2)
                let value_3 := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_3 := calldataload(add(offset, 452))
                mstore(add(value, 448), value_3)
                let value1 := abi_decode_address()
                let value2 := abi_decode_contract_IRelay()
                /// @src 0:16965:25037  "function initialize(..."
                modifier_initializer(value, value1, value2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_t_address())
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function extract_from_storage_value_offset_uint32(slot_value) -> value
            {
                value := and(shr(8, slot_value), 0xffffffff)
            }
            function extract_from_storage_value_offset_uint8(slot_value) -> value
            {
                value := and(shr(40, slot_value), 0xff)
            }
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
                let _1 := sload(/** @src 0:14675:14701  "StateData public stateData" */ 7)
                let ret := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_bool(_1)
                /// @src 0:14675:14701  "StateData public stateData"
                let ret_1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)
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
                /// @src 5:1755:1778  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:1755:1778  "keccak256(_encodedCall)" */ param, param_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                /// @src 5:1755:1778  "keccak256(_encodedCall)"
                let expr := keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:1755:1778  "keccak256(_encodedCall)" */ _mpos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:1755:1778  "keccak256(_encodedCall)" */ _mpos))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:1820:1841  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                /// @src 5:1868:1930  "require(allowedAfterTimestamp != 0, TimelockInvalidSelector())"
                require_helper_error_TimelockInvalidSelector(/** @src 5:1876:1902  "allowedAfterTimestamp != 0" */ iszero(iszero(_1)))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(/** @src 5:1948:1988  "block.timestamp >= allowedAfterTimestamp" */ iszero(lt(/** @src 5:1948:1963  "block.timestamp" */ timestamp(), /** @src 5:1948:1988  "block.timestamp >= allowedAfterTimestamp" */ _1)))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(0, shl(225, 0x309272e1))
                    revert(0, 4)
                }
                sstore(/** @src 5:2031:2069  "state.timelockedCalls[encodedCallHash]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19947(expr), /** @src 5:1901:1902  "0" */ 0x00)
                /// @src 5:2079:2101  "state.executing = true"
                update_storage_value_offset_bool_to_bool_19949()
                /// @src 5:2187:2219  "address(this).call(_encodedCall)"
                let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                /// @src 5:2187:2219  "address(this).call(_encodedCall)"
                let expr_component := call(gas(), /** @src 5:2195:2199  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 5:2187:2219  "address(this).call(_encodedCall)" */ _2, sub(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_encode_bytes_calldata(/** @src 5:2187:2219  "address(this).call(_encodedCall)" */ param, param_1, _2), _2), /** @src -1:-1:-1 */ 0, 0)
                /// @src 5:2187:2219  "address(this).call(_encodedCall)"
                pop(extract_returndata())
                /// @src 5:2229:2252  "state.executing = false"
                update_storage_value_offset_bool_to_bool_19950()
                /// @src 5:2267:2306  "TimelockedCallExecuted(encodedCallHash)"
                let _3 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                /// @src 5:2267:2306  "TimelockedCallExecuted(encodedCallHash)"
                log1(_3, sub(abi_encode_tuple_bytes32(_3, expr), _3), 0x4730df91415d0dc5bbdb12bc2edbf9b11242938ab0e851d9fb37e3ca802cea21)
                /// @src 5:2336:2343  "success"
                fun_passReturnOrRevert(expr_component)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function abi_encode_tuple_bool(headStart) -> tail
            {
                tail := add(headStart, 32)
                mstore(headStart, /** @src 0:19468:19469  "1" */ 0x01)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function abi_encode_bool(headStart, value0) -> tail
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(36)
                let ret := fun_isFinalized(value, value_1)
                let memPos := mload(64)
                mstore(memPos, iszero(iszero(ret)))
                return(memPos, 32)
            }
            function external_fun_feeCollectionAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:14231:14274  "address payable public feeCollectionAddress" */ 5), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function external_fun_setFeeExemptions()
            {
                if callvalue() { revert(0, 0) }
                let param, param_1 := abi_decode_array_struct_FeeConfig_calldata_dyn_calldata(calldatasize())
                /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1349:1379  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:1493:1501  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:34994:35063  "require(signingPolicySetter == address(0), FeeExemptionsNotAllowed())"
                    require_helper_error_FeeExemptionsNotAllowed(/** @src 0:35002:35035  "signingPolicySetter == address(0)" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:35002:35021  "signingPolicySetter" */ 0x03), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                    /// @src 0:35078:35091  "uint256 i = 0"
                    let var_i := /** @src -1:-1:-1 */ 0
                    /// @src 0:35073:35384  "for (uint256 i = 0; i < _exemptions.length; i++) {..."
                    for { }
                    /** @src 0:35093:35115  "i < _exemptions.length" */ lt(var_i, /** @src 0:35097:35115  "_exemptions.length" */ param_1)
                    /// @src 0:35078:35091  "uint256 i = 0"
                    {
                        /// @src 0:35117:35120  "i++"
                        var_i := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:35117:35120  "i++" */ var_i, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1)
                    }
                    /// @src 0:35117:35120  "i++"
                    {
                        /// @src 0:35154:35176  "_exemptions[i].account"
                        let expr := read_from_calldatat_address(/** @src 0:35154:35168  "_exemptions[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(param, param_1, var_i))
                        /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                        let _1 := and(/** @src 0:35198:35219  "account != address(0)" */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                        /// @src 0:35190:35244  "require(account != address(0), FeeExemptAddressZero())"
                        require_helper_error_FeeExemptAddressZero(/** @src 0:35198:35219  "account != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1)))
                        /// @src 0:35258:35307  "feeExemptAddress[account] = _exemptions[i].exempt"
                        update_storage_value_offset_t_bool_to_t_bool(/** @src 0:35258:35283  "feeExemptAddress[account]" */ mapping_index_access_mapping_address_bool_of_address(expr), /** @src 0:35286:35307  "_exemptions[i].exempt" */ read_from_calldatat_bool(add(/** @src 0:35286:35300  "_exemptions[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(param, param_1, var_i), /** @src 0:35286:35307  "_exemptions[i].exempt" */ 32)))
                        /// @src 0:35351:35372  "_exemptions[i].exempt"
                        let expr_1 := read_from_calldatat_bool(add(/** @src 0:35351:35365  "_exemptions[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(param, param_1, var_i), /** @src 0:35286:35307  "_exemptions[i].exempt" */ 32))
                        /// @src 0:35326:35373  "FeeExemptionSet(account, _exemptions[i].exempt)"
                        let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                        /// @src 0:35326:35373  "FeeExemptionSet(account, _exemptions[i].exempt)"
                        log2(_2, sub(abi_encode_bool(_2, expr_1), _2), 0x210f2a4a589e25d95b24cbdb060d26ae79bbe123a564d0f973503d48badd00ca, _1)
                    }
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(0, 0)
            }
            function external_fun_merkleRoots()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(36)
                let ret := fun_merkleRoots(value, value_1)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function external_fun_setSigningPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address_payable(value)
                /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1349:1379  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:1493:1501  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _1 := sload(/** @src 0:36494:36513  "signingPolicySetter" */ 0x03)
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if /** @src 0:36494:36527  "signingPolicySetter != address(0)" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_1, sub(shl(160, 1), 1)))
                    {
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xd029c629))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                    }
                    let _2 := and(/** @src 0:36579:36613  "_signingPolicySetter != address(0)" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    if /** @src 0:36579:36613  "_signingPolicySetter != address(0)" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _2)
                    {
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x60ba70d1))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                    }
                    /// @src 0:7432:7437  "10000"
                    sstore(/** @src 0:36494:36513  "signingPolicySetter" */ 0x03, /** @src 0:7432:7437  "10000" */ or(and(_1, shl(160, 0xffffffffffffffffffffffff)), _2))
                    /// @src 0:36708:36752  "SigningPolicySetterSet(_signingPolicySetter)"
                    log2(/** @src -1:-1:-1 */ 0, 0, /** @src 0:36708:36752  "SigningPolicySetterSet(_signingPolicySetter)" */ 0x78cbfa03aa310db13b3d8fcb316ae48a77d62315fccfe098fc146374d6edb309, _2)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_startingVotingRoundIdForInitialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(192, sload(/** @src 0:15111:15169  "uint32 public startingVotingRoundIdForInitialRewardEpochId" */ 9)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                calldatacopy(add(memPtr, 0x20), src, length)
                mstore(add(add(memPtr, length), 0x20), /** @src -1:-1:-1 */ 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_upgradeToAndCall()
            {
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address_payable(value)
                let offset := calldataload(36)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let array := abi_decode_available_length_bytes(add(offset, 36), calldataload(add(4, offset)), calldatasize())
                /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1349:1379  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:1493:1501  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 11:4400:4423  "address(this) == __self"
                    let _1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 11:4417:4423  "__self" */ loadimmutable("4159"), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    /// @src 11:4400:4520  "address(this) == __self || // Must be called through delegatecall..."
                    let expr := /** @src 11:4400:4423  "address(this) == __self" */ eq(/** @src 11:4408:4412  "this" */ address(), /** @src 11:4400:4423  "address(this) == __self" */ _1)
                    /// @src 11:4400:4520  "address(this) == __self || // Must be called through delegatecall..."
                    if iszero(expr)
                    {
                        expr := /** @src 11:4478:4520  "ERC1967Utils.getImplementation() != __self" */ iszero(eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 8:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)), /** @src 11:4478:4520  "ERC1967Utils.getImplementation() != __self" */ _1))
                    }
                    /// @src 11:4383:4634  "if (..."
                    if expr
                    {
                        /// @src 11:4594:4623  "UUPSUnauthorizedCallContext()"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 11:4594:4623  "UUPSUnauthorizedCallContext()" */ shl(225, 0x703e46dd))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                    }
                    /// @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    mstore(_2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x52d1902d))
                    /// @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    let trySuccessCondition := staticcall(gas(), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 11:5881:5917  "IERC1822Proxiable(newImplementation)" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)), /** @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()" */ _2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4, /** @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()" */ _2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32)
                    /// @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    let expr_1 := /** @src -1:-1:-1 */ 0
                    /// @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                    if trySuccessCondition
                    {
                        let _3 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32
                        /// @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()"
                        if gt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 32, /** @src 11:5881:5933  "IERC1822Proxiable(newImplementation).proxiableUUID()" */ returndatasize()) { _3 := returndatasize() }
                        finalize_allocation(_2, _3)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _3))
                    }
                    /// @src 11:5877:6314  "try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {..."
                    switch iszero(trySuccessCondition)
                    case 0 {
                        /// @src 11:5971:6091  "if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {..."
                        if /** @src 11:5975:6015  "slot != ERC1967Utils.IMPLEMENTATION_SLOT" */ iszero(eq(expr_1, /** @src 8:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
                        /// @src 11:5971:6091  "if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {..."
                        {
                            /// @src 11:6042:6076  "UUPSUnsupportedProxiableUUID(slot)"
                            mstore(/** @src -1:-1:-1 */ 0, /** @src 11:6042:6076  "UUPSUnsupportedProxiableUUID(slot)" */ shl(226, 0x2a875269))
                            revert(/** @src -1:-1:-1 */ 0, /** @src 11:6042:6076  "UUPSUnsupportedProxiableUUID(slot)" */ abi_encode_bytes32(expr_1))
                        }
                        /// @src 11:6153:6157  "data"
                        fun_upgradeToAndCall(value, array)
                    }
                    default /// @src 11:5877:6314  "try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {..."
                    {
                        /// @src 11:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 11:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)" */ shl(224, 0x4c9c8ce3))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 11:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)" */ abi_encode_address(value))
                    }
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_proxiableUUID()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 11:4819:4964  "if (address(this) != __self) {..."
                if /** @src 11:4823:4846  "address(this) != __self" */ iszero(eq(/** @src 11:4831:4835  "this" */ address(), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 11:4840:4846  "__self" */ loadimmutable("4159"), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 11:4819:4964  "if (address(this) != __self) {..."
                {
                    /// @src 11:4924:4953  "UUPSUnauthorizedCallContext()"
                    mstore(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 11:4594:4623  "UUPSUnauthorizedCallContext()" */ shl(225, 0x703e46dd))
                    /// @src 11:4924:4953  "UUPSUnauthorizedCallContext()"
                    revert(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 4)
                }
                let memPos := mload(64)
                mstore(memPos, /** @src 8:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
                let cleaned := and(sload(/** @src 8:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, cleaned)
                return(memPos, 32)
            }
            function external_fun_initialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(160, sload(/** @src 0:15018:15052  "uint32 public initialRewardEpochId" */ 9)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function mapping_index_access_mapping_address_bool_of_address(key) -> dataSlot
            {
                mstore(0, and(key, sub(shl(160, 1), 1)))
                mstore(0x20, /** @src 0:35258:35274  "feeExemptAddress" */ 0x0a)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function external_fun_feeExemptAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address_payable(value)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(value, sub(shl(160, 1), 1)))
                mstore(32, /** @src 0:15311:15376  "mapping(address account => bool) public override feeExemptAddress" */ 10)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value_1 := and(sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40)), 0xff)
                let memPos := mload(0x40)
                mstore(memPos, iszero(iszero(value_1)))
                return(memPos, 32)
            }
            function external_fun_renounceOwnership()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 5:4288:4306  "RenounceDisabled()"
                mstore(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 5:4288:4306  "RenounceDisabled()" */ shl(224, 0x89051165))
                revert(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 4)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19947(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 5:1820:1841  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_20024(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, 0)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_20066(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:94311:94329  "merkleRootsPrivate" */ 0x01)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_t_mapping_t_uint256__t_uint256__of_t_uint256(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:92430:92446  "protocolFeeInWei" */ 0x04)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_t_mapping_t_uint256_t_uint256_of_t_uint256(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:96590:96611  "toRandomNumberPrivate" */ 0x08)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256__uint256__of_uint256(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:96668:96685  "isSecureRandomMap" */ 0x06)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value)
                mstore(32, /** @src 0:13921:13992  "mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds" */ 2)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                let memPos := mload(0x40)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_verify()
            {
                if slt(add(calldatasize(), not(3)), 128)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value0 := abi_decode_uint256()
                let value1 := abi_decode_t_uint256()
                let value2 := abi_decode_bytes32()
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let length := calldataload(add(4, offset))
                if gt(length, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if gt(add(add(offset, shl(5, length)), 36), calldatasize())
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let ret := fun_verify(value0, value1, value2, add(offset, 36), length)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bool(memPos, ret), memPos))
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
            function abi_decode_array_uint16_dyn(offset, end) -> array
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                let length := calldataload(offset)
                let _1 := array_allocation_size_array_struct_FeeConfig_dyn(length)
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0xc0)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := allocate_memory_19968()
                mstore(value, abi_decode_uint24(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                mstore(add(value, 64), abi_decode_uint16(add(offset, 68)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_1 := calldataload(add(offset, 100))
                mstore(add(value, 96), value_1)
                let offset_1 := calldataload(add(offset, 132))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 128), abi_decode_array_address_dyn(add(add(offset, offset_1), 4), calldatasize()))
                let offset_2 := calldataload(add(offset, 164))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(value, 160), abi_decode_array_uint16_dyn(add(add(offset, offset_2), 4), calldatasize()))
                /// @src 0:25339:25346  "bytes32"
                let var := modifier_onlySigningPolicySetter(value)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_tuple_bytes32(memPos, var), memPos))
            }
            function external_fun_lastInitializedRewardEpochData()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(152, sload(/** @src 0:98050:98059  "stateData" */ 0x07)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                /// @src 0:7432:7437  "10000"
                mstore(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 0:7432:7437  "10000" */ value)
                mstore(0x20, /** @src 0:98169:98191  "startingVotingRoundIds" */ 0x02)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let cleaned := and(sload(/** @src 0:7432:7437  "10000" */ keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 0:7432:7437  "10000" */ 0x40)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                let memPos := mload(/** @src 0:7432:7437  "10000" */ 0x40)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(memPos, value)
                mstore(add(memPos, /** @src 0:7432:7437  "10000" */ 0x20), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleaned)
                return(memPos, /** @src 0:7432:7437  "10000" */ 0x40)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_owner()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let cleaned := and(sload(/** @src 18:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value)
                mstore(32, 4)
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value0, value1 := abi_decode_bytes_calldata_ptr(add(4, offset), calldatasize())
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(36)
                let ret := /** @src 0:32194:32245  "_verifyCustomSignature(_relayMessage, _messageHash)" */ fun_verifyCustomSignature(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value0, value1, value)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let ret, ret_1, ret_2 := fun_getRandomNumberHistorical(value)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, ret, ret_1, ret_2), memPos))
            }
            function external_fun_signingPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:14067:14101  "address public signingPolicySetter" */ 3), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(4)
                let _1 := sload(/** @src 0:97133:97142  "stateData" */ 0x07)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value_1 := and(shr(8, _1), 0xffffffff)
                if /** @src 0:97119:97166  "_timestamp >= stateData.firstVotingRoundStartTs" */ lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value, /** @src 0:97119:97166  "_timestamp >= stateData.firstVotingRoundStartTs" */ value_1)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x7ccf96d5))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
                /// @src 5:3863:3886  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:3863:3886  "keccak256(_encodedCall)" */ param, param_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                mstore(/** @src -1:-1:-1 */ 0, /** @src 5:3863:3886  "keccak256(_encodedCall)" */ keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:3863:3886  "keccak256(_encodedCall)" */ _mpos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:3863:3886  "keccak256(_encodedCall)" */ _mpos)))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(0x20, /** @src 5:3921:3942  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40))
                /// @src 5:3969:4032  "require(_allowedAfterTimestamp != 0, TimelockInvalidSelector())"
                require_helper_error_TimelockInvalidSelector(/** @src 5:3977:4004  "_allowedAfterTimestamp != 0" */ iszero(iszero(_1)))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(0x40)
                mstore(memPos, _1)
                return(memPos, 0x20)
            }
            function external_fun_relay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:38392:38405  "sourceChainId" */ 0x0b)
                /// @src 0:38471:90030  "assembly {..."
                let usr$memPtr := mload(0x40)
                mstore(add(usr$memPtr, 160), sload(7))
                if lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38471:90030  "assembly {..." */ 15)
                {
                    usr$revertWithError_19977(usr$memPtr)
                }
                let usr$metadata := shr(168, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4))
                /// @src 0:38471:90030  "assembly {..."
                if lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38471:90030  "assembly {..." */ add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 48))
                {
                    usr$revertWithError_19978(usr$memPtr)
                }
                let _2 := usr$calculateSigningPolicyHash_19979(usr$memPtr, add(43, mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22)), _1)
                mstore(add(usr$memPtr, 0x40), _2)
                mstore(usr$memPtr, and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215))
                mstore(add(usr$memPtr, 32), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                /// @src 0:38471:90030  "assembly {..."
                let _3 := sload(keccak256(usr$memPtr, 0x40))
                mstore(add(usr$memPtr, 96), _3)
                if iszero(eq(_2, _3))
                {
                    usr$revertWithError_19980(usr$memPtr)
                }
                let usr$signatureStart := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38471:90030  "assembly {..."
                let usr$threshold := and(usr$metadata, 65535)
                if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), 1)
                {
                    let usr$overrideBIPS := tload(49263867947327861046025139002774505900665624735272959673709246929275493786307)
                    if iszero(iszero(usr$overrideBIPS))
                    {
                        usr$threshold := div(mul(usr$calculateTotalWeight(usr$metadata), usr$overrideBIPS), 10000)
                    }
                }
                if iszero(iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47)))))
                {
                    let usr$memPtrGP0 := mload(0x40)
                    usr$signatureStart := add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 85)
                    if lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38471:90030  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithError_19982(usr$memPtrGP0)
                    }
                    calldatacopy(usr$memPtrGP0, add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47), 38)
                    let usr$votingRoundId := and(shr(216, mload(usr$memPtrGP0)), 4294967295)
                    mstore(add(usr$memPtrGP0, 96), shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))))
                    mstore(add(usr$memPtrGP0, 128), 1)
                    mstore(add(usr$memPtrGP0, 128), keccak256(add(usr$memPtrGP0, 96), 0x40))
                    mstore(add(usr$memPtrGP0, 96), usr$votingRoundId)
                    if iszero(iszero(sload(keccak256(add(usr$memPtrGP0, 96), 0x40))))
                    {
                        usr$revertWithError_19983(usr$memPtrGP0)
                    }
                    if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), 1)
                    {
                        if usr$votingRoundId
                        {
                            usr$revertWithError_19984(usr$memPtrGP0)
                        }
                        if cleanup_uint8(shr(208, mload(usr$memPtrGP0)))
                        {
                            usr$revertWithError_19986(usr$memPtrGP0)
                        }
                    }
                    let usr$messageRewardEpochId := and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215)
                    let _4 := iszero(eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), 1))
                    if _4
                    {
                        usr$messageRewardEpochId := usr$rewardEpochIdFromVotingRoundId(mload(add(usr$memPtrGP0, 160)), usr$votingRoundId)
                    }
                    if lt(usr$messageRewardEpochId, and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215))
                    {
                        usr$revertWithError_19987(usr$memPtrGP0)
                    }
                    let _5 := mload(add(usr$memPtrGP0, 160))
                    if lt(add(usr$messageRewardEpochId, and(shr(192, _5), 4294967295)), and(shr(152, _5), 4294967295))
                    {
                        usr$revertWithError_19988(usr$memPtrGP0)
                    }
                    if and(_4, lt(usr$votingRoundId, and(shr(184, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 4294967295)))
                    {
                        usr$revertWithError_19989(usr$memPtrGP0)
                    }
                    if gt(usr$messageRewardEpochId, and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215))
                    {
                        let usr$lastInitializedRewardEpoch := extract_from_storage_value_offset_19_uint32(mload(add(usr$memPtrGP0, 160)))
                        if gt(usr$lastInitializedRewardEpoch, and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215))
                        {
                            mstore(add(usr$memPtrGP0, 96), add(and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215), 1))
                            mstore(add(usr$memPtrGP0, 128), 2)
                            if gt(add(usr$votingRoundId, 1), sload(keccak256(add(usr$memPtrGP0, 96), 0x40)))
                            {
                                usr$revertWithError_19991(usr$memPtrGP0)
                            }
                        }
                        if eq(usr$lastInitializedRewardEpoch, and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215))
                        {
                            usr$threshold := div(mul(usr$threshold, usr$structValue(mload(add(usr$memPtrGP0, 160)))), 10000)
                        }
                    }
                    let _6 := keccak256(usr$memPtrGP0, 38)
                    let _7 := add(usr$memPtrGP0, 32)
                    mstore(_7, _6)
                    mstore(usr$memPtrGP0, _1)
                    mstore(_7, keccak256(usr$memPtrGP0, 0x40))
                }
                if iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))))
                {
                    let _8 := mload(0x40)
                    if iszero(iszero(extract_from_storage_value_offset_bool(mload(add(_8, 160))))) { usr$revertWithError_19994(_8) }
                    if lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38471:90030  "assembly {..." */ add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 59))
                    {
                        usr$revertWithError_19995(mload(0x40))
                    }
                    calldatacopy(mload(0x40), add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 48), /** @src 0:38392:38405  "sourceChainId" */ 0x0b)
                    /// @src 0:38471:90030  "assembly {..."
                    let _9 := mload(0x40)
                    let _10 := mload(_9)
                    let _11 := shr(240, _10)
                    if iszero(_11) { usr$revertWithError_19996(_9) }
                    if gt(_11, 300)
                    {
                        usr$revertWithError_19997(mload(0x40))
                    }
                    let _12 := mul(_11, 22)
                    usr$signatureStart := add(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), _12), 91)
                    if lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38471:90030  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithError(mload(0x40))
                    }
                    let usr$newSigningPolicyRewardEpochId := and(shr(216, _10), 16777215)
                    let _13 := mload(0x40)
                    let usr$tmpLastInitializedRewardEpochId := extract_from_storage_value_offset_19_uint32(mload(add(_13, 160)))
                    if iszero(eq(usr$tmpLastInitializedRewardEpochId, and(shr(216, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 16777215)))
                    {
                        usr$revertWithError_20000(_13)
                    }
                    if iszero(eq(add(1, usr$tmpLastInitializedRewardEpochId), usr$newSigningPolicyRewardEpochId))
                    {
                        usr$revertWithError_20001(mload(0x40))
                    }
                    usr$checkThresholdConsistency(mload(0x40), shr(168, _10), add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 48))
                    let usr$newSigningPolicyHash := usr$calculateSigningPolicyHash(mload(0x40), add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 48), add(43, _12), _1)
                    let _14 := add(mload(0x40), 160)
                    mstore(_14, usr$assignStruct(mload(_14), usr$newSigningPolicyRewardEpochId))
                    mstore(mload(0x40), usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), 2)
                    let _15 := mload(0x40)
                    sstore(keccak256(_15, 0x40), and(shr(184, _10), 4294967295))
                    mstore(_15, usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                    /// @src 0:38471:90030  "assembly {..."
                    let _16 := mload(0x40)
                    sstore(keccak256(_16, 0x40), usr$newSigningPolicyHash)
                    mstore(add(_16, 32), usr$newSigningPolicyHash)
                    mstore(add(mload(0x40), 96), "SigningPolicyRelayed(uint256)")
                    log2(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, /** @src 0:38471:90030  "assembly {..." */ keccak256(add(mload(0x40), 96), 29), usr$newSigningPolicyRewardEpochId)
                }
                let _17 := add(usr$signatureStart, 2)
                if lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38471:90030  "assembly {..." */ _17)
                {
                    usr$revertWithError_20003(usr$memPtr)
                }
                calldatacopy(add(usr$memPtr, 0x40), usr$signatureStart, 2)
                let _18 := shr(240, mload(add(usr$memPtr, 0x40)))
                mstore(add(usr$memPtr, 256), _17)
                if lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize(), /** @src 0:38471:90030  "assembly {..." */ add(add(usr$signatureStart, mul(_18, 67)), 2))
                {
                    usr$revertWithError_20004(usr$memPtr)
                }
                mstore(usr$memPtr, "0000\x19Ethereum Signed Message:\n32")
                mstore(usr$memPtr, keccak256(add(usr$memPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4), /** @src 0:38471:90030  "assembly {..." */ 60))
                let usr$i := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38471:90030  "assembly {..."
                let usr$weight := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38471:90030  "assembly {..."
                let usr$nextUnusedIndex := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                /// @src 0:38471:90030  "assembly {..."
                let usr$memPtrFor := mload(0x40)
                for { } lt(usr$i, _18) { usr$i := add(usr$i, 1) }
                {
                    mstore(add(usr$memPtrFor, 32), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                    /// @src 0:38471:90030  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 63), add(add(usr$signatureStart, mul(usr$i, 67)), 2), 67)
                    let usr$index := shr(240, mload(add(usr$memPtrFor, 128)))
                    if gt(add(usr$index, 1), shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)))
                    /// @src 0:38471:90030  "assembly {..."
                    {
                        usr$revertWithError_20005(usr$memPtrFor)
                    }
                    if lt(usr$index, usr$nextUnusedIndex)
                    {
                        usr$revertWithError_20006(usr$memPtrFor)
                    }
                    usr$nextUnusedIndex := add(usr$index, 1)
                    let _19 := and(mload(add(usr$memPtrFor, 32)), 0xff)
                    if iszero(or(eq(_19, 27), eq(_19, 28)))
                    {
                        usr$revertWithError_20007(usr$memPtrFor)
                    }
                    if gt(mload(add(usr$memPtrFor, 96)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                    {
                        usr$revertWithError_20008(usr$memPtrFor)
                    }
                    if iszero(staticcall(not(0), 1, usr$memPtrFor, 128, add(usr$memPtrFor, 0x40), 32))
                    {
                        usr$revertWithError_20009(usr$memPtrFor)
                    }
                    if iszero(eq(returndatasize(), 32))
                    {
                        usr$revertWithError_20010(usr$memPtrFor)
                    }
                    if iszero(mload(add(usr$memPtrFor, 0x40)))
                    {
                        usr$revertWithError_20011(usr$memPtrFor)
                    }
                    mstore(add(usr$memPtrFor, 96), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0)
                    /// @src 0:38471:90030  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 106), add(47, mul(usr$index, 22)), 22)
                    if iszero(eq(mload(add(usr$memPtrFor, 0x40)), shr(16, mload(add(usr$memPtrFor, 96)))))
                    {
                        usr$revertWithError_20012(usr$memPtrFor)
                    }
                    usr$weight := add(usr$weight, and(mload(add(usr$memPtrFor, 96)), 65535))
                    if gt(usr$weight, usr$threshold)
                    {
                        if iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))))
                        {
                            sstore(7, mload(add(usr$memPtrFor, 160)))
                            return(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0)
                        }
                        /// @src 0:38471:90030  "assembly {..."
                        if iszero(iszero(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47)))))
                        {
                            let _20 := add(usr$memPtrFor, 192)
                            calldatacopy(_20, add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 53), 32)
                            if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), 1)
                            {
                                mstore(usr$memPtrFor, mload(_20))
                                mstore(add(usr$memPtrFor, 32), and(shl(16, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ shl(232, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 16777215)))
                                /// @src 0:38471:90030  "assembly {..."
                                return(usr$memPtrFor, 35)
                            }
                            if iszero(mload(_20))
                            {
                                usr$revertWithError_20013(usr$memPtrFor)
                            }
                            let usr$votingRoundId_1 := usr$extractVotingRoundIdFromMessage(add(43, mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22)))
                            mstore(usr$memPtrFor, shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))))
                            mstore(add(usr$memPtrFor, 32), 1)
                            mstore(add(usr$memPtrFor, 32), keccak256(usr$memPtrFor, 0x40))
                            mstore(usr$memPtrFor, usr$votingRoundId_1)
                            sstore(keccak256(usr$memPtrFor, 0x40), mload(_20))
                            let _21 := add(usr$memPtrFor, 160)
                            if iszero(eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), cleanup_uint8(mload(_21))))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47), 6)
                                let _22 := shr(208, mload(usr$memPtrFor))
                                mstore(usr$memPtrFor, _22)
                                mstore(_21, and(_22, 0xff))
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_21, 0x40, keccak256(add(usr$memPtrFor, 96), 49), shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), usr$votingRoundId_1)
                                return(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0)
                            }
                            /// @src 0:38471:90030  "assembly {..."
                            if eq(shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), cleanup_uint8(mload(_21)))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47), 6)
                                let usr$isSecure := iszero(iszero(cleanup_uint8(shr(208, mload(usr$memPtrFor)))))
                                let _23 := add(usr$memPtrFor, 256)
                                usr$processRandomMerkleProof(usr$memPtrFor, add(mload(_23), mul(_18, 67)), _20, usr$votingRoundId_1, usr$isSecure)
                                if usr$isSecure
                                {
                                    usr$setIsSecureRandomBit(add(usr$memPtrFor, 96), usr$votingRoundId_1)
                                }
                                let _24 := mload(_21)
                                if gt(usr$votingRoundId_1, and(shr(112, _24), 4294967295))
                                {
                                    sstore(7, usr$assignStruct_20018(usr$assignStruct_20017(_24, usr$votingRoundId_1), usr$isSecure))
                                }
                                mstore(_21, usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_21, 0x40, keccak256(add(usr$memPtrFor, 96), 49), shr(248, calldataload(add(mul(shr(240, calldataload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)), /** @src 0:38471:90030  "assembly {..." */ 22), 47))), usr$votingRoundId_1)
                                calldatacopy(_20, add(mload(_23), mul(_18, 67)), 32)
                                mstore(add(usr$memPtrFor, 224), usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "RandomNumberRelayed(uint32,uint2")
                                mstore(add(usr$memPtrFor, 128), "56,bool)")
                                log2(_20, 0x40, keccak256(add(usr$memPtrFor, 96), 40), usr$votingRoundId_1)
                                return(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0)
                            }
                        }
                        /// @src 0:38471:90030  "assembly {..."
                        usr$revertWithError_20019(mload(0x40))
                    }
                }
                /// @src 0:90058:90075  "NotEnoughWeight()"
                mstore(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 0:90058:90075  "NotEnoughWeight()" */ shl(226, 0x179215cf))
                revert(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 4)
            }
            function external_fun_setFeeCollectionAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address_payable(value)
                /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                switch /** @src 5:1349:1379  "_timeToExecuteTimelockedCall()" */ fun_timeToExecuteTimelockedCall()
                case /** @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..." */ 0 {
                    /// @src 5:1493:1501  "msg.data"
                    fun_recordTimelockedCall(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                }
                default /// @src 5:1345:1513  "if (_timeToExecuteTimelockedCall()) {..."
                {
                    fun_beforeExecuteTimelockedCall()
                    /// @src 0:35794:35859  "require(signingPolicySetter == address(0), FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:35802:35835  "signingPolicySetter == address(0)" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:35802:35821  "signingPolicySetter" */ 0x03), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                    let _1 := and(/** @src 0:35877:35912  "_feeCollectionAddress != address(0)" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    /// @src 0:35869:35941  "require(_feeCollectionAddress != address(0), FeeCollectionAddressZero())"
                    require_helper_error_FeeCollectionAddressZero(/** @src 0:35877:35912  "_feeCollectionAddress != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1)))
                    /// @src 0:7432:7437  "10000"
                    sstore(/** @src 0:35951:36004  "feeCollectionAddress = payable(_feeCollectionAddress)" */ 0x05, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 0:35951:36004  "feeCollectionAddress = payable(_feeCollectionAddress)" */ 0x05), /** @src 0:7432:7437  "10000" */ shl(160, 0xffffffffffffffffffffffff)), _1))
                    /// @src 0:36019:36065  "FeeCollectionAddressSet(_feeCollectionAddress)"
                    log2(/** @src -1:-1:-1 */ 0, 0, /** @src 0:36019:36065  "FeeCollectionAddressSet(_feeCollectionAddress)" */ 0xfc78a1d0b2aa388b5b987c35079601ed0e4c5a4d38f758a0278449af9d7b9ba2, _1)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_verifyCustomSignatureWithThreshold()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 96)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value0, value1 := abi_decode_bytes_calldata_ptr(add(4, offset), calldatasize())
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := calldataload(36)
                let value_1 := calldataload(68)
                validator_revert_uint16(value_1)
                /// @src 0:33064:33124  "require(_thresholdBIPS < THRESHOLD_BIPS, ThresholdTooHigh())"
                require_helper_error_ThresholdTooHigh(/** @src 0:33072:33103  "_thresholdBIPS < THRESHOLD_BIPS" */ lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:33072:33103  "_thresholdBIPS < THRESHOLD_BIPS" */ value_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff), /** @src 0:7432:7437  "10000" */ 0x2710))
                /// @src 0:33424:33486  "assembly {..."
                tstore(/** @src 0:7983:8049  "0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3" */ 0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3, /** @src 0:33424:33486  "assembly {..." */ value_1)
                /// @src 0:33495:33563  "_rewardEpochId = _verifyCustomSignature(_relayMessage, _messageHash)"
                let var_rewardEpochId := /** @src 0:33512:33563  "_verifyCustomSignature(_relayMessage, _messageHash)" */ fun_verifyCustomSignature(value0, value1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value)
                /// @src 0:33629:33678  "assembly {..."
                tstore(/** @src 0:7983:8049  "0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3" */ 0x6cea5c73f8043432390b6161c6418f07a6dc8cc07557416a3f28d2fd6007a2c3, /** @src -1:-1:-1 */ 0)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPos := mload(64)
                mstore(memPos, var_rewardEpochId)
                return(memPos, 32)
            }
            function external_fun_getRandomNumber()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:95486:95495  "stateData" */ 0x07)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := and(shr(112, _1), 0xffffffff)
                /// @src 0:7432:7437  "10000"
                mstore(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 0:7432:7437  "10000" */ value)
                mstore(0x20, /** @src 0:95464:95485  "toRandomNumberPrivate" */ 0x08)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _2 := sload(/** @src 0:7432:7437  "10000" */ keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, /** @src 0:7432:7437  "10000" */ 0x40))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let cleaned := and(/** @src 0:95665:95698  "stateData.randomVotingRoundId + 1" */ checked_add_uint32_20022(value), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                /// @src 0:95578:95750  "_randomTimestamp =..."
                let var_randomTimestamp := /** @src 0:95609:95750  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(/** @src 0:95464:95485  "toRandomNumberPrivate" */ 0x08, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1), 0xffffffff), /** @src 0:95657:95750  "uint256(stateData.randomVotingRoundId + 1) *..." */ checked_mul_uint256(cleaned, cleanup_uint8(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(40, _1), 0xff))))
                let memPos := mload(/** @src 0:7432:7437  "10000" */ 0x40)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, _2, and(shr(144, _1), 0xff), var_randomTimestamp), memPos))
            }
            function external_fun_getTimelockDurationSeconds()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 5:3519:3548  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := calldataload(4)
                validator_revert_address_payable(value)
                /// @src 18:2324:2386  "modifier onlyOwner() {..."
                fun_checkOwner()
                /// @src 18:2378:2379  "_"
                fun_transferOwnership_inner(value)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_cancelTimelockedCall()
            {
                if callvalue() { revert(0, 0) }
                let param, param_1 := abi_decode_bytes_calldata(calldatasize())
                /// @src 18:2324:2386  "modifier onlyOwner() {..."
                fun_checkOwner()
                /// @src 5:2604:2627  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:2604:2627  "keccak256(_encodedCall)" */ param, param_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                /// @src 5:2604:2627  "keccak256(_encodedCall)"
                let expr := keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:2604:2627  "keccak256(_encodedCall)" */ _mpos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:2604:2627  "keccak256(_encodedCall)" */ _mpos))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:2645:2666  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 5:2637:2716  "require(state.timelockedCalls[encodedCallHash] != 0, TimelockInvalidSelector())"
                require_helper_error_TimelockInvalidSelector(/** @src 5:2645:2688  "state.timelockedCalls[encodedCallHash] != 0" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40)))))
                /// @src 5:2731:2770  "TimelockedCallCanceled(encodedCallHash)"
                let _1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                mstore(_1, expr)
                /// @src 5:2731:2770  "TimelockedCallCanceled(encodedCallHash)"
                log1(_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20, /** @src 5:2731:2770  "TimelockedCallCanceled(encodedCallHash)" */ 0x317f58a0a5e6a501ac25aa9519e1dbad2f1671fe061164a3f1529da5b14362e1)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:2645:2666  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40), /** @src -1:-1:-1 */ 0)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function external_fun_oldRelay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:14953:14975  "IRelay public oldRelay" */ 9), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
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
            /// @ast-id 2414 @src 0:97348:97747  "function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {..."
            function fun_toSigningPolicyHash(var_rewardEpochId) -> var_
            {
                /// @src 0:97424:97431  "bytes32"
                var_ := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:97455:97463  "oldRelay" */ 0x09)
                /// @src 0:97447:97464  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:97447:97519  "address(oldRelay) != address(0) && _rewardEpochId < initialRewardEpochId"
                let expr_1 := /** @src 0:97447:97478  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:97447:97478  "address(oldRelay) != address(0)" */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:97447:97519  "address(oldRelay) != address(0) && _rewardEpochId < initialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:97482:97519  "_rewardEpochId < initialRewardEpochId" */ lt(var_rewardEpochId, cleanup_uint32(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_20_uint32(_1)))
                }
                /// @src 0:97443:97597  "if (address(oldRelay) != address(0) && _rewardEpochId < initialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:97542:97586  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:97542:97586  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    mstore(_2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x0c85bf07))
                    /// @src 0:97542:97586  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_tuple_bytes32(add(_2, 4), var_rewardEpochId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:97542:97586  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_2 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:97535:97586  "return oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    var_ := expr_2
                    leave
                }
                /// @src 0:97606:97681  "require(signingPolicySetter != address(0), NoAccessToSigningPolicyHashes())"
                require_helper_error_NoAccessToSigningPolicyHashes(/** @src 0:97614:97647  "signingPolicySetter != address(0)" */ iszero(iszero(cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:97614:97633  "signingPolicySetter" */ 0x03))))))
                /// @src 0:97691:97740  "return toSigningPolicyHashPrivate[_rewardEpochId]"
                var_ := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:97698:97740  "toSigningPolicyHashPrivate[_rewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_20024(var_rewardEpochId))
            }
            /// @src 5:1188:1194  "7 days"
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
                sstore(/** @src 0:22915:22959  "sourceChainId = _initialConfig.sourceChainId" */ 0x0b, /** @src 5:1188:1194  "7 days" */ value)
            }
            function update_storage_value_offset_t_uint256_to_t_uint256(value)
            {
                sstore(/** @src 0:23462:23496  "getState().timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01, /** @src 5:1188:1194  "7 days" */ value)
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function require_helper_error_FeeConfigNotAllowed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xf286d12d))
                    revert(0, 4)
                }
            }
            function panic_error_0x32()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x32)
                revert(0, 0x24)
            }
            function calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(base_ref, length, index) -> addr
            {
                if iszero(lt(index, length)) { panic_error_0x32() }
                addr := add(base_ref, shl(6, index))
            }
            function read_from_calldatat_uint8(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                validator_revert_uint8(value)
                returnValue := value
            }
            function require_helper_error_InvalidProtocolId(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x55e7c3d9))
                    revert(0, 4)
                }
            }
            function mapping_index_access_mapping_uint256__uint256__of_uint8(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, 4)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint8(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, /** @src 0:96463:96481  "merkleRootsPrivate" */ 0x01)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                dataSlot := keccak256(0, 0x40)
            }
            function extract_from_storage_value_offset_uint64(slot_value) -> value
            {
                value := and(slot_value, 0xffffffffffffffff)
            }
            function update_storage_value_offset_uint64_to_uint64()
            {
                sstore(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(0xffffffffffffffff)), 1))
            }
            function update_storage_value_offset_bool_to_bool_20033()
            {
                sstore(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ or(and(sload(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(0xff0000000000000000)), 0x010000000000000000))
            }
            function update_storage_value_offset_bool_to_bool_20034()
            {
                sstore(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(0xff0000000000000000)))
            }
            function abi_encode_rational_by(value, pos)
            {
                mstore(pos, and(value, 0xffffffffffffffff))
            }
            /// @ast-id 3983 @src 10:4069:5171  "modifier initializer() {..."
            function modifier_initializer(var_initialConfig_mpos, var__signingPolicySetter, var__oldRelay_address, var_initialOwner)
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := and(shr(64, _1), 0xff)
                /// @src 10:4301:4317  "!$._initializing"
                let expr := cleanup_bool(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value))
                /// @src 10:4724:4740  "initialized == 0"
                let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(extract_from_storage_value_offset_uint64(_1), 0xffffffffffffffff)
                /// @src 10:4724:4758  "initialized == 0 && isTopLevelCall"
                let expr_1 := /** @src 10:4724:4740  "initialized == 0" */ iszero(_2)
                /// @src 10:4724:4758  "initialized == 0 && isTopLevelCall"
                if expr_1 { expr_1 := expr }
                /// @src 10:4788:4838  "initialized == 1 && address(this).code.length == 0"
                let expr_2 := /** @src 10:4788:4804  "initialized == 1" */ eq(_2, /** @src 10:4803:4804  "1" */ 0x01)
                /// @src 10:4788:4838  "initialized == 1 && address(this).code.length == 0"
                if expr_2
                {
                    expr_2 := /** @src 10:4808:4838  "address(this).code.length == 0" */ iszero(/** @src 10:4808:4833  "address(this).code.length" */ extcodesize(/** @src 10:4816:4820  "this" */ address()))
                }
                /// @src 10:4853:4883  "!initialSetup && !construction"
                let expr_3 := /** @src 10:4853:4866  "!initialSetup" */ iszero(expr_1)
                /// @src 10:4853:4883  "!initialSetup && !construction"
                if expr_3
                {
                    expr_3 := /** @src 10:4870:4883  "!construction" */ iszero(expr_2)
                }
                /// @src 10:4849:4940  "if (!initialSetup && !construction) {..."
                if expr_3
                {
                    /// @src 10:4906:4929  "InvalidInitialization()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 10:4906:4929  "InvalidInitialization()" */ shl(224, 0xf92ee8a9))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 10:4906:4929  "InvalidInitialization()" */ 4)
                }
                /// @src 10:4949:4967  "$._initialized = 1"
                update_storage_value_offset_uint64_to_uint64()
                /// @src 10:4977:5044  "if (isTopLevelCall) {..."
                if expr
                {
                    /// @src 10:5011:5033  "$._initializing = true"
                    update_storage_value_offset_bool_to_bool_20033()
                }
                /// @src 10:5053:5054  "_"
                fun_initialize_inner(var_initialConfig_mpos, var__signingPolicySetter, var__oldRelay_address, var_initialOwner)
                /// @src 10:5064:5165  "if (isTopLevelCall) {..."
                if expr
                {
                    /// @src 10:5098:5121  "$._initializing = false"
                    update_storage_value_offset_bool_to_bool_20034()
                    /// @src 10:5140:5154  "Initialized(1)"
                    let _3 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 10:5140:5154  "Initialized(1)"
                    log1(_3, sub(abi_encode_tuple_bool(_3), _3), 0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2)
                }
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function read_from_memoryt_uint16(ptr) -> returnValue
            {
                returnValue := and(mload(ptr), 0xffff)
            }
            /// @src 0:7432:7437  "10000"
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
                returnValue := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ mload(ptr), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)
            }
            /// @src 0:7432:7437  "10000"
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
            function panic_error_0x11()
            {
                mstore(0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x4e487b71))
                /// @src 0:7432:7437  "10000"
                mstore(4, 0x11)
                revert(0, 0x24)
            }
            function checked_mul_uint32(x, y) -> product
            {
                let product_raw := mul(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ x, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), and(/** @src 0:7432:7437  "10000" */ y, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))
                /// @src 0:7432:7437  "10000"
                product := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ product_raw, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                /// @src 0:7432:7437  "10000"
                if iszero(eq(product, product_raw)) { panic_error_0x11() }
            }
            function checked_add_uint32_20022(x) -> sum
            {
                sum := add(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ x, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), 1)
                /// @src 0:7432:7437  "10000"
                if gt(sum, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                /// @src 0:7432:7437  "10000"
                { panic_error_0x11() }
            }
            function checked_add_uint32(x, y) -> sum
            {
                sum := add(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ x, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), and(/** @src 0:7432:7437  "10000" */ y, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))
                /// @src 0:7432:7437  "10000"
                if gt(sum, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)
                /// @src 0:7432:7437  "10000"
                { panic_error_0x11() }
            }
            function require_helper_error_InvalidInitialStartingVotingRoundId(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x5acba20f))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_uint32_to_uint32_20036(value)
            {
                let _1 := sload(/** @src 0:18440:18498  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x09)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:18440:18498  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x09, /** @src 0:7432:7437  "10000" */ or(and(_1, not(shl(160, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:7432:7437  "10000" */ and(shl(160, value), shl(160, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_uint32_to_uint32(value)
            {
                let _1 := sload(/** @src 0:18440:18498  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x09)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:18440:18498  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x09, /** @src 0:7432:7437  "10000" */ or(and(_1, not(shl(192, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:7432:7437  "10000" */ and(shl(192, value), shl(192, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_t_uint32_to_t_uint32(value)
            {
                let _1 := sload(/** @src 0:19078:19087  "stateData" */ 0x07)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(_1, not(shl(192, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:7432:7437  "10000" */ and(shl(192, value), shl(192, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_uint32_to_uint32_20038(value)
            {
                let _1 := sload(/** @src 0:19078:19087  "stateData" */ 0x07)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(_1, not(shl(152, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:7432:7437  "10000" */ and(shl(152, value), shl(152, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))))
            }
            /// @src 0:7432:7437  "10000"
            function mapping_index_access_mapping_uint256__uint256__of_uint32(key) -> dataSlot
            {
                mstore(0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ key, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))
                /// @src 0:7432:7437  "10000"
                mstore(0x20, /** @src 0:19162:19184  "startingVotingRoundIds" */ 0x02)
                /// @src 0:7432:7437  "10000"
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint32(key) -> dataSlot
            {
                mstore(/** @src 0:17481:17482  "0" */ 0x00, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ key, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))
                /// @src 0:7432:7437  "10000"
                mstore(0x20, /** @src 0:17481:17482  "0" */ 0x00)
                /// @src 0:7432:7437  "10000"
                dataSlot := keccak256(/** @src 0:17481:17482  "0" */ 0x00, /** @src 0:7432:7437  "10000" */ 0x40)
            }
            function require_helper_error_InvalidRandomNumberProtocolId(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x06e1dff5))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_uint8_to_uint8(value)
            {
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 0:19078:19087  "stateData" */ 0x07), /** @src 0:7432:7437  "10000" */ not(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255)), and(/** @src 0:7432:7437  "10000" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_uint32_to_uint32_20042(value)
            {
                let _1 := sload(/** @src 0:19078:19087  "stateData" */ 0x07)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(_1, not(0xffffffff00)), and(shl(8, value), 0xffffffff00)))
            }
            function update_storage_value_offset_t_uint8_to_t_uint8(value)
            {
                let _1 := sload(/** @src 0:19078:19087  "stateData" */ 0x07)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(_1, not(0xff0000000000)), and(shl(40, value), 0xff0000000000)))
            }
            function update_storage_value_offset_uint32_to_uint32_20044(value)
            {
                let _1 := sload(/** @src 0:19078:19087  "stateData" */ 0x07)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(_1, not(0xffffffff000000000000)), and(shl(48, value), 0xffffffff000000000000)))
            }
            function update_storage_value_offset_t_uint16_to_t_uint16(value)
            {
                let _1 := sload(/** @src 0:19078:19087  "stateData" */ 0x07)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(_1, not(shl(80, 65535))), and(shl(80, value), shl(80, 65535))))
            }
            function update_storage_value_offset_uint16_to_uint16(value)
            {
                let _1 := sload(/** @src 0:19078:19087  "stateData" */ 0x07)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(_1, not(shl(96, 65535))), and(shl(96, value), shl(96, 65535))))
            }
            function require_helper_error_FeeCollectionAddressZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xa63c869f))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_address_payable_to_address_payable(value)
            {
                sstore(/** @src 0:21380:21438  "feeCollectionAddress = _initialConfig.feeCollectionAddress" */ 0x05, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 0:21380:21438  "feeCollectionAddress = _initialConfig.feeCollectionAddress" */ 0x05), /** @src 0:7432:7437  "10000" */ shl(160, 0xffffffffffffffffffffffff)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_t_address_payable_to_t_address_payable(value)
            {
                sstore(/** @src 0:20993:21035  "signingPolicySetter = _signingPolicySetter" */ 0x03, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 0:20993:21035  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 0:7432:7437  "10000" */ shl(160, 0xffffffffffffffffffffffff)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_address_payable_to_address_payable_20057(value)
            {
                sstore(/** @src 0:18440:18498  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x09, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 0:18440:18498  "initialRewardEpochId = _initialConfig.initialRewardEpochId" */ 0x09), /** @src 0:7432:7437  "10000" */ shl(160, 0xffffffffffffffffffffffff)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
            }
            /// @src 0:7432:7437  "10000"
            function require_helper_error_FeeExemptionsNotAllowed(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x7eac2661))
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
            function update_storage_value_offset_bool_to_bool()
            {
                sstore(/** @src 0:19078:19087  "stateData" */ 0x07, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 0:19078:19087  "stateData" */ 0x07), /** @src 0:7432:7437  "10000" */ not(shl(184, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255))), /** @src 0:7432:7437  "10000" */ shl(184, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1)))
            }
            /// @src 0:7432:7437  "10000"
            function memory_array_index_access_struct_FeeConfig_dyn(baseRef) -> addr
            {
                if iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:7432:7437  "10000" */ baseRef)) { panic_error_0x32() }
                addr := add(baseRef, 32)
            }
            function memory_array_index_access_array_struct_FeeConfig_dyn(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:7432:7437  "10000" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, shl(5, index)), 32)
            }
            function read_from_memoryt_address(ptr) -> returnValue
            {
                returnValue := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ mload(ptr), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
            }
            /// @src 0:7432:7437  "10000"
            function require_helper_error_FeeExemptAddressZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x7075186f))
                    revert(0, 4)
                }
            }
            function update_storage_value_offset_bool_to_bool_19949()
            {
                sstore(/** @src 5:1252:1294  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 5:1252:1294  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00), /** @src 0:7432:7437  "10000" */ not(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255)), /** @src 5:2097:2101  "true" */ 0x01))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_bool_to_bool_19950()
            {
                sstore(/** @src 5:1252:1294  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00, /** @src 0:7432:7437  "10000" */ and(sload(/** @src 5:1252:1294  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00), /** @src 0:7432:7437  "10000" */ not(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255)))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_bool_to_bool_20053(slot)
            {
                sstore(slot, or(and(sload(slot), not(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255)), /** @src 0:19468:19469  "1" */ 0x01))
            }
            /// @src 0:7432:7437  "10000"
            function update_storage_value_offset_t_bool_to_t_bool(slot, value)
            {
                let value_1 := and(sload(slot), not(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255))
                /// @src 0:7432:7437  "10000"
                sstore(slot, or(value_1, and(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ iszero(iszero(/** @src 0:7432:7437  "10000" */ value)), 255)))
            }
            function require_helper_error_SourceChainIdZero(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0x8609583d))
                    revert(0, 4)
                }
            }
            function abi_decode_address_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32)
                {
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    revert(0, 0)
                }
                /// @src 0:7432:7437  "10000"
                let value := mload(headStart)
                validator_revert_address_payable(value)
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
            function validator_revert_bool(value)
            {
                if iszero(eq(value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ iszero(iszero(/** @src 0:7432:7437  "10000" */ value)))) { revert(0, 0) }
            }
            function abi_decode_t_bool_fromMemory(offset) -> value
            {
                value := mload(offset)
                validator_revert_bool(value)
            }
            function abi_decode_uint8t_uint32t_uint8t_uint32t_uint16t_uint16t_uint32t_boolt_uint32t_boolt_uint32_fromMemory(headStart, dataEnd) -> value0, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10
            {
                if slt(sub(dataEnd, headStart), 352)
                {
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    revert(0, 0)
                }
                /// @src 0:7432:7437  "10000"
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
                /// @src 0:7432:7437  "10000"
                value_5 := mload(add(headStart, 160))
                validator_revert_uint16(value_5)
                value5 := value_5
                let value_6 := /** @src -1:-1:-1 */ 0
                /// @src 0:7432:7437  "10000"
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
            /// @src 0:16965:25037  "function initialize(..."
            function fun_initialize_inner(var__initialConfig_mpos, var_signingPolicySetter, var_oldRelay_address, var__initialOwner)
            {
                /// @src 18:1868:1995  "function __Ownable_init(address initialOwner) internal onlyInitializing {..."
                modifier_onlyInitializing(var__initialOwner)
                /// @src 0:17226:17262  "_initialConfig.thresholdIncreaseBIPS"
                let _1 := add(var__initialConfig_mpos, 256)
                /// @src 0:17218:17310  "require(_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS, ThresholdIncreaseTooSmall())"
                require_helper_error_ThresholdIncreaseTooSmall(/** @src 0:17226:17280  "_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS" */ iszero(lt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(cleanup_uint16(mload(/** @src 0:17226:17262  "_initialConfig.thresholdIncreaseBIPS" */ _1)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff), /** @src 0:7432:7437  "10000" */ 0x2710)))
                /// @src 0:17430:17478  "_initialConfig.rewardEpochDurationInVotingEpochs"
                let _2 := add(var__initialConfig_mpos, 224)
                /// @src 0:17422:17510  "require(_initialConfig.rewardEpochDurationInVotingEpochs > 0, RewardEpochDurationZero())"
                require_helper_error_RewardEpochDurationZero(/** @src 0:17430:17482  "_initialConfig.rewardEpochDurationInVotingEpochs > 0" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(cleanup_uint16(mload(/** @src 0:17430:17478  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff))))
                /// @src 0:17528:17569  "_initialConfig.votingEpochDurationSeconds"
                let _3 := add(var__initialConfig_mpos, 160)
                /// @src 0:17520:17601  "require(_initialConfig.votingEpochDurationSeconds > 0, VotingEpochDurationZero())"
                require_helper_error_VotingEpochDurationZero(/** @src 0:17528:17573  "_initialConfig.votingEpochDurationSeconds > 0" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ cleanup_uint8(mload(/** @src 0:17528:17569  "_initialConfig.votingEpochDurationSeconds" */ _3)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff))))
                /// @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash"
                let _4 := add(var__initialConfig_mpos, 64)
                /// @src 0:18053:18147  "require(_initialConfig.initialSigningPolicyHash != bytes32(0), InitialSigningPolicyHashZero())"
                require_helper_error_InitialSigningPolicyHashZero(/** @src 0:18061:18114  "_initialConfig.initialSigningPolicyHash != bytes32(0)" */ iszero(iszero(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash" */ _4))))
                /// @src 0:18165:18214  "_initialConfig.firstRewardEpochStartVotingRoundId"
                let _5 := add(var__initialConfig_mpos, 192)
                let _6 := /** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:18165:18214  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _5))
                /// @src 0:18229:18264  "_initialConfig.initialRewardEpochId"
                let _7 := /** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:18229:18264  "_initialConfig.initialRewardEpochId" */ var__initialConfig_mpos))
                /// @src 0:18165:18315  "_initialConfig.firstRewardEpochStartVotingRoundId +..."
                let expr := checked_add_uint32(_6, /** @src 0:18229:18315  "_initialConfig.initialRewardEpochId * _initialConfig.rewardEpochDurationInVotingEpochs" */ checked_mul_uint32(_7, cleanup_uint16(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:18267:18315  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2)))))
                /// @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId"
                let _8 := add(var__initialConfig_mpos, 32)
                /// @src 0:18157:18430  "require(_initialConfig.firstRewardEpochStartVotingRoundId +..."
                require_helper_error_InvalidInitialStartingVotingRoundId(/** @src 0:18165:18390  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ iszero(gt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:18165:18390  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), /** @src 0:18165:18390  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ cleanup_uint32(/** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _8))))))
                /// @src 0:18463:18498  "_initialConfig.initialRewardEpochId"
                let _9 := /** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:18463:18498  "_initialConfig.initialRewardEpochId" */ var__initialConfig_mpos))
                /// @src 0:18440:18498  "initialRewardEpochId = _initialConfig.initialRewardEpochId"
                update_storage_value_offset_uint32_to_uint32_20036(_9)
                /// @src 0:7432:7437  "10000"
                let _10 := cleanup_uint32(mload(/** @src 0:18567:18626  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _8))
                /// @src 0:18508:18626  "startingVotingRoundIdForInitialRewardEpochId =..."
                update_storage_value_offset_uint32_to_uint32(/** @src 0:7432:7437  "10000" */ _10)
                /// @src 0:19078:19152  "stateData.lastInitializedRewardEpoch = _initialConfig.initialRewardEpochId"
                update_storage_value_offset_uint32_to_uint32_20038(_9)
                /// @src 5:1188:1194  "7 days"
                sstore(/** @src 0:19162:19221  "startingVotingRoundIds[_initialConfig.initialRewardEpochId]" */ mapping_index_access_mapping_uint256__uint256__of_uint32(/** @src 0:7432:7437  "10000" */ _9), /** @src 0:19162:19295  "startingVotingRoundIds[_initialConfig.initialRewardEpochId] =..." */ cleanup_uint32(/** @src 0:7432:7437  "10000" */ _10))
                /// @src 5:1188:1194  "7 days"
                sstore(/** @src 0:19305:19368  "toSigningPolicyHashPrivate[_initialConfig.initialRewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint32(/** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:19332:19367  "_initialConfig.initialRewardEpochId" */ var__initialConfig_mpos))), /** @src 0:7432:7437  "10000" */ mload(/** @src 0:19371:19410  "_initialConfig.initialSigningPolicyHash" */ _4))
                /// @src 0:19428:19465  "_initialConfig.randomNumberProtocolId"
                let _11 := add(var__initialConfig_mpos, 96)
                /// @src 0:19420:19503  "require(_initialConfig.randomNumberProtocolId > 1, InvalidRandomNumberProtocolId())"
                require_helper_error_InvalidRandomNumberProtocolId(/** @src 0:19428:19469  "_initialConfig.randomNumberProtocolId > 1" */ gt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:7432:7437  "10000" */ cleanup_uint8(mload(/** @src 0:19428:19465  "_initialConfig.randomNumberProtocolId" */ _11)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff), /** @src 0:19468:19469  "1" */ 0x01))
                /// @src 0:19513:19585  "stateData.randomNumberProtocolId = _initialConfig.randomNumberProtocolId"
                update_storage_value_offset_uint8_to_uint8(/** @src 0:7432:7437  "10000" */ cleanup_uint8(mload(/** @src 0:19548:19585  "_initialConfig.randomNumberProtocolId" */ _11)))
                /// @src 0:19631:19669  "_initialConfig.firstVotingRoundStartTs"
                let _12 := add(var__initialConfig_mpos, 128)
                /// @src 0:19595:19669  "stateData.firstVotingRoundStartTs = _initialConfig.firstVotingRoundStartTs"
                update_storage_value_offset_uint32_to_uint32_20042(/** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:19631:19669  "_initialConfig.firstVotingRoundStartTs" */ _12)))
                /// @src 0:19679:19759  "stateData.votingEpochDurationSeconds = _initialConfig.votingEpochDurationSeconds"
                update_storage_value_offset_t_uint8_to_t_uint8(/** @src 0:7432:7437  "10000" */ cleanup_uint8(mload(/** @src 0:19718:19759  "_initialConfig.votingEpochDurationSeconds" */ _3)))
                /// @src 0:19769:19865  "stateData.firstRewardEpochStartVotingRoundId = _initialConfig.firstRewardEpochStartVotingRoundId"
                update_storage_value_offset_uint32_to_uint32_20044(/** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:19816:19865  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _5)))
                /// @src 0:19875:19969  "stateData.rewardEpochDurationInVotingEpochs = _initialConfig.rewardEpochDurationInVotingEpochs"
                update_storage_value_offset_t_uint16_to_t_uint16(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:19921:19969  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2)))
                /// @src 0:19979:20049  "stateData.thresholdIncreaseBIPS = _initialConfig.thresholdIncreaseBIPS"
                update_storage_value_offset_uint16_to_uint16(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:20013:20049  "_initialConfig.thresholdIncreaseBIPS" */ _1)))
                /// @src 0:20059:20165  "stateData.messageFinalizationWindowInRewardEpochs = _initialConfig.messageFinalizationWindowInRewardEpochs"
                update_storage_value_offset_t_uint32_to_t_uint32(/** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:20111:20165  "_initialConfig.messageFinalizationWindowInRewardEpochs" */ add(var__initialConfig_mpos, 288))))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _13 := and(/** @src 0:20179:20213  "_signingPolicySetter != address(0)" */ var_signingPolicySetter, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 0:20179:20213  "_signingPolicySetter != address(0)"
                let _14 := iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _13)
                /// @src 0:20179:20213  "_signingPolicySetter != address(0)"
                let expr_1 := iszero(_14)
                /// @src 0:20175:21528  "if (_signingPolicySetter != address(0)) {..."
                switch expr_1
                case 0 {
                    /// @src 0:21288:21323  "_initialConfig.feeCollectionAddress"
                    let _15 := add(var__initialConfig_mpos, 320)
                    /// @src 0:21280:21366  "require(_initialConfig.feeCollectionAddress != address(0), FeeCollectionAddressZero())"
                    require_helper_error_FeeCollectionAddressZero(/** @src 0:21288:21337  "_initialConfig.feeCollectionAddress != address(0)" */ iszero(iszero(cleanup_address_payable(/** @src 0:7432:7437  "10000" */ cleanup_address_payable(mload(/** @src 0:21288:21323  "_initialConfig.feeCollectionAddress" */ _15))))))
                    /// @src 0:7432:7437  "10000"
                    let _16 := cleanup_address_payable(mload(/** @src 0:21403:21438  "_initialConfig.feeCollectionAddress" */ _15))
                    /// @src 0:21380:21438  "feeCollectionAddress = _initialConfig.feeCollectionAddress"
                    update_storage_value_offset_address_payable_to_address_payable(/** @src 0:7432:7437  "10000" */ _16)
                    /// @src 0:21457:21517  "FeeCollectionAddressSet(_initialConfig.feeCollectionAddress)"
                    log2(/** @src 0:17481:17482  "0" */ 0x00, 0x00, /** @src 0:21457:21517  "FeeCollectionAddressSet(_initialConfig.feeCollectionAddress)" */ 0xfc78a1d0b2aa388b5b987c35079601ed0e4c5a4d38f758a0278449af9d7b9ba2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:21457:21517  "FeeCollectionAddressSet(_initialConfig.feeCollectionAddress)" */ _16, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
                }
                default /// @src 0:20175:21528  "if (_signingPolicySetter != address(0)) {..."
                {
                    /// @src 0:20470:20539  "require(_initialConfig.feeConfigs.length == 0, FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:20478:20515  "_initialConfig.feeConfigs.length == 0" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:20478:20503  "_initialConfig.feeConfigs" */ mload(add(var__initialConfig_mpos, 352)))))
                    /// @src 0:20553:20634  "require(_initialConfig.feeExemptAddresses.length == 0, FeeExemptionsNotAllowed())"
                    require_helper_error_FeeExemptionsNotAllowed(/** @src 0:20561:20606  "_initialConfig.feeExemptAddresses.length == 0" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:20561:20594  "_initialConfig.feeExemptAddresses" */ mload(add(var__initialConfig_mpos, 384)))))
                    /// @src 0:20648:20729  "require(_initialConfig.feeCollectionAddress == address(0), FeeConfigNotAllowed())"
                    require_helper_error_FeeConfigNotAllowed(/** @src 0:20656:20705  "_initialConfig.feeCollectionAddress == address(0)" */ iszero(cleanup_address_payable(/** @src 0:7432:7437  "10000" */ cleanup_address_payable(mload(/** @src 0:20656:20691  "_initialConfig.feeCollectionAddress" */ add(var__initialConfig_mpos, 320))))))
                    /// @src 0:7432:7437  "10000"
                    let _17 := mload(/** @src 0:20867:20895  "_initialConfig.sourceChainId" */ add(var__initialConfig_mpos, 416))
                    /// @src 0:20842:20979  "require(..."
                    require_helper_error_SourceChainIdMismatchOnHomeDeploy(/** @src 0:20867:20912  "_initialConfig.sourceChainId == block.chainid" */ eq(_17, /** @src 0:20899:20912  "block.chainid" */ chainid()))
                    /// @src 0:20993:21035  "signingPolicySetter = _signingPolicySetter"
                    update_storage_value_offset_t_address_payable_to_t_address_payable(var_signingPolicySetter)
                    /// @src 0:21049:21086  "stateData.noSigningPolicyRelay = true"
                    update_storage_value_offset_bool_to_bool()
                    /// @src 0:21105:21149  "SigningPolicySetterSet(_signingPolicySetter)"
                    log2(/** @src 0:17481:17482  "0" */ 0x00, 0x00, /** @src 0:21105:21149  "SigningPolicySetterSet(_signingPolicySetter)" */ 0x78cbfa03aa310db13b3d8fcb316ae48a77d62315fccfe098fc146374d6edb309, _13)
                }
                /// @src 0:21542:21555  "uint256 i = 0"
                let var_i := /** @src 0:17481:17482  "0" */ 0x00
                /// @src 0:21537:21907  "for (uint256 i = 0; i < _initialConfig.feeConfigs.length; i++) {..."
                for { }
                /** @src 0:19468:19469  "1" */ 0x01
                /// @src 0:21542:21555  "uint256 i = 0"
                {
                    /// @src 0:21595:21598  "i++"
                    var_i := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:21595:21598  "i++" */ var_i, /** @src 0:19468:19469  "1" */ 0x01)
                }
                /// @src 0:21595:21598  "i++"
                {
                    /// @src 0:21561:21586  "_initialConfig.feeConfigs"
                    let _18 := add(var__initialConfig_mpos, 352)
                    let _205_mpos := mload(_18)
                    /// @src 0:21557:21593  "i < _initialConfig.feeConfigs.length"
                    if iszero(lt(var_i, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:21561:21593  "_initialConfig.feeConfigs.length" */ _205_mpos)))
                    /// @src 0:21557:21593  "i < _initialConfig.feeConfigs.length"
                    { break }
                    /// @src 0:21633:21672  "_initialConfig.feeConfigs[i].protocolId"
                    let _19 := read_from_memoryt_uint8(/** @src 0:21633:21661  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_array_struct_FeeConfig_dyn(_205_mpos, var_i)))
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _20 := and(/** @src 0:21694:21708  "protocolId > 1" */ _19, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)
                    /// @src 0:21686:21730  "require(protocolId > 1, InvalidProtocolId())"
                    require_helper_error_InvalidProtocolId(/** @src 0:21694:21708  "protocolId > 1" */ gt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _20, /** @src 0:19468:19469  "1" */ 0x01))
                    /// @src 5:1188:1194  "7 days"
                    sstore(/** @src 0:21744:21772  "protocolFeeInWei[protocolId]" */ mapping_index_access_mapping_uint256__uint256__of_uint8(_19), /** @src 0:7432:7437  "10000" */ mload(/** @src 0:21775:21812  "_initialConfig.feeConfigs[i].feeInWei" */ add(/** @src 0:21775:21803  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_array_struct_FeeConfig_dyn(/** @src 0:21775:21800  "_initialConfig.feeConfigs" */ mload(_18), /** @src 0:21775:21803  "_initialConfig.feeConfigs[i]" */ var_i)), /** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32)))
                    /// @src 0:7432:7437  "10000"
                    let _21 := mload(/** @src 0:21858:21895  "_initialConfig.feeConfigs[i].feeInWei" */ add(/** @src 0:21858:21886  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_array_struct_FeeConfig_dyn(/** @src 0:21858:21883  "_initialConfig.feeConfigs" */ mload(_18), /** @src 0:21858:21886  "_initialConfig.feeConfigs[i]" */ var_i)), /** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32))
                    /// @src 0:21831:21896  "ProtocolFeeSet(protocolId, _initialConfig.feeConfigs[i].feeInWei)"
                    let _22 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash" */ 64)
                    /// @src 0:21831:21896  "ProtocolFeeSet(protocolId, _initialConfig.feeConfigs[i].feeInWei)"
                    log2(_22, sub(abi_encode_tuple_bytes32(_22, _21), _22), 0x9e48fd6a5a4b85a56901f1e36dfa8e5322e39f6785209de54a38f4392386ed8d, _20)
                }
                /// @src 0:22219:22232  "uint256 i = 0"
                let var_i_1 := /** @src 0:17481:17482  "0" */ 0x00
                /// @src 0:22214:22551  "for (uint256 i = 0; i < _initialConfig.feeExemptAddresses.length; i++) {..."
                for { }
                /** @src 0:19468:19469  "1" */ 0x01
                /// @src 0:22219:22232  "uint256 i = 0"
                {
                    /// @src 0:22280:22283  "i++"
                    var_i_1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:22280:22283  "i++" */ var_i_1, /** @src 0:19468:19469  "1" */ 0x01)
                }
                /// @src 0:22280:22283  "i++"
                {
                    /// @src 0:22238:22271  "_initialConfig.feeExemptAddresses"
                    let _241_mpos := mload(add(var__initialConfig_mpos, 384))
                    /// @src 0:22234:22278  "i < _initialConfig.feeExemptAddresses.length"
                    if iszero(lt(var_i_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:22238:22278  "_initialConfig.feeExemptAddresses.length" */ _241_mpos)))
                    /// @src 0:22234:22278  "i < _initialConfig.feeExemptAddresses.length"
                    { break }
                    /// @src 0:22323:22359  "_initialConfig.feeExemptAddresses[i]"
                    let _23 := read_from_memoryt_address(memory_array_index_access_array_struct_FeeConfig_dyn(_241_mpos, var_i_1))
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _24 := and(/** @src 0:22381:22408  "exemptAccount != address(0)" */ _23, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                    /// @src 0:22373:22433  "require(exemptAccount != address(0), FeeExemptAddressZero())"
                    require_helper_error_FeeExemptAddressZero(/** @src 0:22381:22408  "exemptAccount != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _24)))
                    /// @src 0:22447:22485  "feeExemptAddress[exemptAccount] = true"
                    update_storage_value_offset_bool_to_bool_20053(/** @src 0:22447:22478  "feeExemptAddress[exemptAccount]" */ mapping_index_access_mapping_address_bool_of_address(_23))
                    /// @src 0:22504:22540  "FeeExemptionSet(exemptAccount, true)"
                    let _25 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash" */ 64)
                    /// @src 0:22504:22540  "FeeExemptionSet(exemptAccount, true)"
                    log2(_25, sub(abi_encode_tuple_bool(_25), _25), 0x210f2a4a589e25d95b24cbdb060d26ae79bbe123a564d0f973503d48badd00ca, _24)
                }
                /// @src 0:22850:22878  "_initialConfig.sourceChainId"
                let _26 := add(var__initialConfig_mpos, 416)
                /// @src 0:22842:22905  "require(_initialConfig.sourceChainId != 0, SourceChainIdZero())"
                require_helper_error_SourceChainIdZero(/** @src 0:22850:22883  "_initialConfig.sourceChainId != 0" */ iszero(iszero(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:22850:22878  "_initialConfig.sourceChainId" */ _26))))
                /// @src 0:22915:22959  "sourceChainId = _initialConfig.sourceChainId"
                update_storage_value_offset_uint256_to_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:22931:22959  "_initialConfig.sourceChainId" */ _26))
                /// @src 0:23332:23370  "_initialConfig.timelockDurationSeconds"
                let _27 := add(var__initialConfig_mpos, 448)
                /// @src 0:23311:23452  "require(..."
                require_helper_error_TimelockDurationTooLong(/** @src 0:23332:23403  "_initialConfig.timelockDurationSeconds <= MAX_TIMELOCK_DURATION_SECONDS" */ iszero(gt(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:23332:23370  "_initialConfig.timelockDurationSeconds" */ _27), /** @src 5:1188:1194  "7 days" */ 0x093a80)))
                /// @src 0:7432:7437  "10000"
                let _28 := mload(/** @src 0:23499:23537  "_initialConfig.timelockDurationSeconds" */ _27)
                /// @src 0:23462:23537  "getState().timelockDurationSeconds = _initialConfig.timelockDurationSeconds"
                update_storage_value_offset_t_uint256_to_t_uint256(_28)
                /// @src 0:23552:23611  "TimelockDurationSet(_initialConfig.timelockDurationSeconds)"
                let _29 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash" */ 64)
                /// @src 0:23552:23611  "TimelockDurationSet(_initialConfig.timelockDurationSeconds)"
                log1(_29, sub(abi_encode_tuple_bytes32(_29, _28), _29), 0xf15cdeff5f6a37216412a72678ec978762dc7264a85f30590ed54b14ab51bbdf)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _30 := and(/** @src 0:23706:23724  "address(_oldRelay)" */ var_oldRelay_address, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 0:23702:25031  "if (address(_oldRelay) != address(0)) {..."
                if /** @src 0:23706:23738  "address(_oldRelay) != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _30))
                /// @src 0:23702:25031  "if (address(_oldRelay) != address(0)) {..."
                {
                    /// @src 0:23763:23846  "_signingPolicySetter != address(0) && _oldRelay.signingPolicySetter() != address(0)"
                    let expr_2 := expr_1
                    if expr_1
                    {
                        /// @src 0:23801:23832  "_oldRelay.signingPolicySetter()"
                        let _31 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash" */ 64)
                        /// @src 0:23801:23832  "_oldRelay.signingPolicySetter()"
                        mstore(_31, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xa9dbe8ed))
                        /// @src 0:23801:23832  "_oldRelay.signingPolicySetter()"
                        let _32 := staticcall(gas(), _30, _31, /** @src 0:21744:21760  "protocolFeeInWei" */ 0x04, /** @src 0:23801:23832  "_oldRelay.signingPolicySetter()" */ _31, /** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32)
                        /// @src 0:23801:23832  "_oldRelay.signingPolicySetter()"
                        if iszero(_32) { revert_forward() }
                        let expr_3 := /** @src 0:17481:17482  "0" */ 0x00
                        /// @src 0:23801:23832  "_oldRelay.signingPolicySetter()"
                        if _32
                        {
                            let _33 := /** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32
                            /// @src 0:23801:23832  "_oldRelay.signingPolicySetter()"
                            if gt(/** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32, /** @src 0:23801:23832  "_oldRelay.signingPolicySetter()" */ returndatasize()) { _33 := returndatasize() }
                            finalize_allocation(_31, _33)
                            expr_3 := abi_decode_address_fromMemory(_31, add(_31, _33))
                        }
                        /// @src 0:23763:23846  "_signingPolicySetter != address(0) && _oldRelay.signingPolicySetter() != address(0)"
                        expr_2 := /** @src 0:23801:23846  "_oldRelay.signingPolicySetter() != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:23801:23846  "_oldRelay.signingPolicySetter() != address(0)" */ expr_3, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                    }
                    /// @src 0:23762:23952  "(_signingPolicySetter != address(0) && _oldRelay.signingPolicySetter() != address(0)) ||..."
                    let expr_4 := expr_2
                    if iszero(expr_2)
                    {
                        /// @src 0:23868:23951  "_signingPolicySetter == address(0) && _oldRelay.signingPolicySetter() == address(0)"
                        let expr_5 := _14
                        if _14
                        {
                            /// @src 0:23906:23937  "_oldRelay.signingPolicySetter()"
                            let _34 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash" */ 64)
                            /// @src 0:23906:23937  "_oldRelay.signingPolicySetter()"
                            mstore(_34, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xa9dbe8ed))
                            /// @src 0:23906:23937  "_oldRelay.signingPolicySetter()"
                            let _35 := staticcall(gas(), _30, _34, /** @src 0:21744:21760  "protocolFeeInWei" */ 0x04, /** @src 0:23906:23937  "_oldRelay.signingPolicySetter()" */ _34, /** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32)
                            /// @src 0:23906:23937  "_oldRelay.signingPolicySetter()"
                            if iszero(_35) { revert_forward() }
                            let expr_6 := /** @src 0:17481:17482  "0" */ 0x00
                            /// @src 0:23906:23937  "_oldRelay.signingPolicySetter()"
                            if _35
                            {
                                let _36 := /** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32
                                /// @src 0:23906:23937  "_oldRelay.signingPolicySetter()"
                                if gt(/** @src 0:18331:18390  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ 32, /** @src 0:23906:23937  "_oldRelay.signingPolicySetter()" */ returndatasize()) { _36 := returndatasize() }
                                finalize_allocation(_34, _36)
                                expr_6 := abi_decode_address_fromMemory(_34, add(_34, _36))
                            }
                            /// @src 0:23868:23951  "_signingPolicySetter == address(0) && _oldRelay.signingPolicySetter() == address(0)"
                            expr_5 := /** @src 0:23906:23951  "_oldRelay.signingPolicySetter() == address(0)" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:23906:23951  "_oldRelay.signingPolicySetter() == address(0)" */ expr_6, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
                        }
                        /// @src 0:23762:23952  "(_signingPolicySetter != address(0) && _oldRelay.signingPolicySetter() != address(0)) ||..."
                        expr_4 := expr_5
                    }
                    /// @src 0:23754:24006  "require((_signingPolicySetter != address(0) && _oldRelay.signingPolicySetter() != address(0)) ||..."
                    require_helper_error_OldRelayIncompatible(expr_4)
                    /// @src 0:24293:24314  "_oldRelay.stateData()"
                    let _37 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:18061:18100  "_initialConfig.initialSigningPolicyHash" */ 64)
                    /// @src 0:24293:24314  "_oldRelay.stateData()"
                    mstore(_37, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x0f47d9b5))
                    /// @src 0:24293:24314  "_oldRelay.stateData()"
                    let _38 := staticcall(gas(), _30, _37, /** @src 0:21744:21760  "protocolFeeInWei" */ 0x04, /** @src 0:24293:24314  "_oldRelay.stateData()" */ _37, /** @src 0:21561:21586  "_initialConfig.feeConfigs" */ 352)
                    /// @src 0:24293:24314  "_oldRelay.stateData()"
                    if iszero(_38) { revert_forward() }
                    let expr_929_component := /** @src 0:17481:17482  "0" */ 0x00
                    let expr_929_component_1 := 0x00
                    let expr_component := 0x00
                    let expr_component_1 := 0x00
                    /// @src 0:24293:24314  "_oldRelay.stateData()"
                    if _38
                    {
                        let _39 := /** @src 0:21561:21586  "_initialConfig.feeConfigs" */ 352
                        /// @src 0:24293:24314  "_oldRelay.stateData()"
                        if gt(/** @src 0:21561:21586  "_initialConfig.feeConfigs" */ _39, /** @src 0:24293:24314  "_oldRelay.stateData()" */ returndatasize()) { _39 := returndatasize() }
                        finalize_allocation(_37, _39)
                        let expr_component_2, expr_component_3, expr_component_4, expr_component_5, expr_component_6, expr_component_7, expr_component_8, expr_component_9, expr_component_10, expr_component_11, expr_component_12 := abi_decode_uint8t_uint32t_uint8t_uint32t_uint16t_uint16t_uint32t_boolt_uint32t_boolt_uint32_fromMemory(_37, add(_37, _39))
                        expr_929_component := expr_component_3
                        expr_929_component_1 := expr_component_4
                        expr_component := expr_component_5
                        expr_component_1 := expr_component_6
                    }
                    /// @src 0:24336:24374  "_initialConfig.firstVotingRoundStartTs"
                    let _40 := /** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:24336:24374  "_initialConfig.firstVotingRoundStartTs" */ _12))
                    /// @src 0:24328:24426  "require(_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs, OldRelayWrongStartTs())"
                    require_helper_error_OldRelayWrongStartTs(/** @src 0:24336:24401  "_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs" */ eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:24336:24401  "_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs" */ _40, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), and(/** @src 0:24336:24401  "_initialConfig.firstVotingRoundStartTs == firstVotingRoundStartTs" */ expr_929_component, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)))
                    /// @src 0:24465:24513  "_initialConfig.rewardEpochDurationInVotingEpochs"
                    let _41 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:24465:24513  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _2))
                    /// @src 0:24440:24616  "require(..."
                    require_helper_error_OldRelayWrongRewardEpochDuration(/** @src 0:24465:24550  "_initialConfig.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:24465:24550  "_initialConfig.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ _41, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff), and(/** @src 0:24465:24550  "_initialConfig.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ expr_component_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff)))
                    /// @src 0:24655:24704  "_initialConfig.firstRewardEpochStartVotingRoundId"
                    let _42 := /** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:24655:24704  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _5))
                    /// @src 0:24630:24810  "require(..."
                    require_helper_error_OldRelayWrongFirstRewardEpochStart(/** @src 0:24655:24742  "_initialConfig.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:24655:24742  "_initialConfig.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ _42, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), and(/** @src 0:24655:24742  "_initialConfig.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ expr_component, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)))
                    /// @src 0:24849:24890  "_initialConfig.votingEpochDurationSeconds"
                    let _43 := /** @src 0:7432:7437  "10000" */ cleanup_uint8(mload(/** @src 0:24849:24890  "_initialConfig.votingEpochDurationSeconds" */ _3))
                    /// @src 0:24824:24986  "require(..."
                    require_helper_error_OldRelayWrongVotingEpochDuration(/** @src 0:24849:24920  "_initialConfig.votingEpochDurationSeconds == votingEpochDurationSeconds" */ eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:24849:24920  "_initialConfig.votingEpochDurationSeconds == votingEpochDurationSeconds" */ _43, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff), and(/** @src 0:24849:24920  "_initialConfig.votingEpochDurationSeconds == votingEpochDurationSeconds" */ expr_929_component_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)))
                    /// @src 0:25000:25020  "oldRelay = _oldRelay"
                    update_storage_value_offset_address_payable_to_address_payable_20057(var_oldRelay_address)
                }
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function require_helper_error_TimelockInvalidSelector(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(226, 0x023679b7))
                    revert(0, 4)
                }
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
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ returndatasize())
                }
            }
            function abi_decode_bool_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                /// @src 0:7432:7437  "10000"
                let value := mload(headStart)
                validator_revert_bool(value)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value0 := value
            }
            function abi_encode_uint256_uint256(headStart, value0, value1) -> tail
            {
                tail := add(headStart, 64)
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
            }
            /// @ast-id 2153 @src 0:93778:94379  "function isFinalized(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_isFinalized(var_protocolId, var_votingRoundId) -> var
            {
                /// @src 0:93883:93887  "bool"
                var := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:93915:93923  "oldRelay" */ 0x09)
                /// @src 0:93907:93924  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:93907:94003  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr_1 := /** @src 0:93907:93938  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:93907:93938  "address(oldRelay) != address(0)" */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:93907:94003  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:93942:94003  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, cleanup_uint32(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:93903:94086  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:94026:94075  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:94026:94075  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(226, 0x0c5eb4cf))
                    /// @src 0:94026:94075  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var_protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:94026:94075  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_2 := abi_decode_bool_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:94019:94075  "return oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    var := expr_2
                    leave
                }
                /// @src 0:94304:94372  "return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)"
                var := /** @src 0:94311:94372  "merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:94311:94358  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:94311:94342  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_20066(var_protocolId), /** @src 0:94311:94358  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))))
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function read_from_calldatat_address(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                validator_revert_address_payable(value)
                returnValue := value
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
            /// @ast-id 2202 @src 0:94427:94897  "function merkleRoots(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_merkleRoots(var__protocolId, var_votingRoundId) -> var_merkleRoot
            {
                /// @src 0:94532:94551  "bytes32 _merkleRoot"
                var_merkleRoot := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:94579:94587  "oldRelay" */ 0x09)
                /// @src 0:94571:94588  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:94571:94667  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr_1 := /** @src 0:94571:94602  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:94571:94602  "address(oldRelay) != address(0)" */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:94571:94667  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:94606:94667  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, cleanup_uint32(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:94567:94750  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:94690:94739  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:94690:94739  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(232, 3752811))
                    /// @src 0:94690:94739  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var__protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:94690:94739  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_2 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:94683:94739  "return oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    var_merkleRoot := expr_2
                    leave
                }
                /// @src 0:94759:94826  "require(signingPolicySetter != address(0), NoAccessToMerkleRoots())"
                require_helper_error_NoAccessToMerkleRoots(/** @src 0:94767:94800  "signingPolicySetter != address(0)" */ iszero(iszero(cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:94767:94786  "signingPolicySetter" */ 0x03))))))
                /// @src 0:94836:94890  "return merkleRootsPrivate[_protocolId][_votingRoundId]"
                var_merkleRoot := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:94843:94890  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:94843:94874  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_20066(var__protocolId), /** @src 0:94843:94890  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function read_from_storage_split_offset_bool(slot) -> value
            {
                value := and(sload(slot), 0xff)
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
            function checked_sub_uint256_20096(y) -> diff
            {
                diff := sub(/** @src 0:29766:29768  "20" */ 0x14, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ y)
                if gt(diff, /** @src 0:29766:29768  "20" */ 0x14)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_20098(y) -> diff
            {
                diff := sub(/** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ y)
                if gt(diff, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_20101(y) -> diff
            {
                diff := sub(/** @src 0:28995:28996  "2" */ 0x02, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ y)
                if gt(diff, /** @src 0:28995:28996  "2" */ 0x02)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_20161(y) -> diff
            {
                diff := sub(/** @src 0:96712:96715  "255" */ 0xff, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ y)
                if gt(diff, /** @src 0:96712:96715  "255" */ 0xff)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                { panic_error_0x11() }
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
            function abi_decode_uint256_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := mload(headStart)
                value0 := value
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
            /// @ast-id 2110 @src 0:90130:93730  "function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)..."
            function fun_verify(var_protocolId, var_votingRoundId, var__leaf, var_proof_offset, var_proof_length) -> var
            {
                /// @src 0:90275:90279  "bool"
                var := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                let _1 := sload(/** @src 0:91031:91039  "oldRelay" */ 0x09)
                /// @src 0:91023:91119  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:91023:91054  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:91023:91040  "address(oldRelay)" */ cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1)), sub(shl(160, 1), 1))))
                /// @src 0:91023:91119  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:91058:91119  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, cleanup_uint32(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:91019:93702  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                switch expr
                case 0 {
                    /// @src 0:92073:92118  "require(_protocolId > 1, InvalidProtocolId())"
                    require_helper_error_InvalidProtocolId(/** @src 0:92081:92096  "_protocolId > 1" */ gt(var_protocolId, /** @src 0:92095:92096  "1" */ 0x01))
                    /// @src 0:92395:92423  "feeExemptAddress[msg.sender]"
                    let _2 := read_from_storage_split_offset_bool(mapping_index_access_mapping_address_bool_of_address(/** @src 0:92412:92422  "msg.sender" */ caller()))
                    /// @src 0:92395:92459  "feeExemptAddress[msg.sender] ? 0 : protocolFeeInWei[_protocolId]"
                    let expr_1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:92395:92459  "feeExemptAddress[msg.sender] ? 0 : protocolFeeInWei[_protocolId]"
                    switch _2
                    case 0 {
                        expr_1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:92430:92459  "protocolFeeInWei[_protocolId]" */ mapping_index_access_t_mapping_t_uint256__t_uint256__of_t_uint256(var_protocolId))
                    }
                    default /// @src 0:92395:92459  "feeExemptAddress[msg.sender] ? 0 : protocolFeeInWei[_protocolId]"
                    {
                        expr_1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    }
                    /// @src 0:92473:92511  "require(msg.value >= fee, TooLowFee())"
                    require_helper_error_TooLowFee(/** @src 0:92481:92497  "msg.value >= fee" */ iszero(lt(/** @src 0:92481:92490  "msg.value" */ callvalue(), /** @src 0:92481:92497  "msg.value >= fee" */ expr_1)))
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let _3 := sload(/** @src 0:92621:92668  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:92621:92652  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_20066(var_protocolId), /** @src 0:92621:92668  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
                    /// @src 0:92682:92725  "require(root != bytes32(0), NotFinalized())"
                    require_helper_error_NotFinalized(/** @src 0:92690:92708  "root != bytes32(0)" */ iszero(iszero(_3)))
                    /// @src 0:92739:92804  "require(_proof.verifyCalldata(root, _leaf), MerkleProofInvalid())"
                    require_helper_error_MerkleProofInvalid(/** @src 0:92747:92781  "_proof.verifyCalldata(root, _leaf)" */ fun_verifyCalldata(var_proof_offset, var_proof_length, _3, var__leaf))
                    /// @src 0:93021:93360  "if (fee > 0) {..."
                    if /** @src 0:93025:93032  "fee > 0" */ iszero(iszero(expr_1))
                    /// @src 0:93021:93360  "if (fee > 0) {..."
                    {
                        /// @src 0:93192:93233  "feeCollectionAddress.call{value: fee}(\"\")"
                        let expr_2067_component := call(gas(), /** @src 0:93192:93217  "feeCollectionAddress.call" */ cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:93192:93212  "feeCollectionAddress" */ 0x05))), /** @src 0:93192:93233  "feeCollectionAddress.call{value: fee}(\"\")" */ expr_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, 0, 0)
                        /// @src 0:93192:93233  "feeCollectionAddress.call{value: fee}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:93310:93345  "require(feeOk, FeeTransferFailed())"
                        require_helper_error_FeeTransferFailed(expr_2067_component)
                    }
                    /// @src 0:93390:93405  "msg.value - fee"
                    let expr_2 := checked_sub_uint256(/** @src 0:92481:92490  "msg.value" */ callvalue(), /** @src 0:93390:93405  "msg.value - fee" */ expr_1)
                    /// @src 0:93419:93692  "if (refund > 0) {..."
                    if /** @src 0:93423:93433  "refund > 0" */ iszero(iszero(expr_2))
                    /// @src 0:93419:93692  "if (refund > 0) {..."
                    {
                        /// @src 0:93533:93567  "msg.sender.call{value: refund}(\"\")"
                        let expr_component := call(gas(), /** @src 0:92412:92422  "msg.sender" */ caller(), /** @src 0:93533:93567  "msg.sender.call{value: refund}(\"\")" */ expr_2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, 0, 0)
                        /// @src 0:93533:93567  "msg.sender.call{value: refund}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:93644:93677  "require(refundOk, RefundFailed())"
                        require_helper_error_RefundFailed(expr_component)
                    }
                }
                default /// @src 0:91019:93702  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                {
                    /// @src 0:91421:91446  "oldRelay.protocolFeeInWei"
                    let expr_address := cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(sload(/** @src 0:91031:91039  "oldRelay" */ 0x09)))
                    /// @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _4 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)"
                    mstore(_4, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x91e7d42f))
                    /// @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _5 := staticcall(gas(), expr_address, _4, sub(abi_encode_tuple_bytes32(add(_4, 4), var_protocolId), _4), _4, 32)
                    if iszero(_5) { revert_forward() }
                    let expr_3 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)"
                    if _5
                    {
                        let _6 := 32
                        if gt(32, returndatasize()) { _6 := returndatasize() }
                        finalize_allocation(_4, _6)
                        expr_3 := abi_decode_uint256_fromMemory(_4, add(_4, _6))
                    }
                    /// @src 0:91473:91514  "require(msg.value >= oldFee, TooLowFee())"
                    require_helper_error_TooLowFee(/** @src 0:91481:91500  "msg.value >= oldFee" */ iszero(lt(/** @src 0:91481:91490  "msg.value" */ callvalue(), /** @src 0:91481:91500  "msg.value >= oldFee" */ expr_3)))
                    /// @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _7 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    mstore(_7, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x40428355))
                    /// @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _8 := call(gas(), expr_address, expr_3, _7, sub(abi_encode_uint256_uint256_bytes32_array_bytes32_dyn_calldata(add(_7, /** @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)" */ 4), /** @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ var_protocolId, var_votingRoundId, var__leaf, var_proof_offset, var_proof_length), _7), _7, /** @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)" */ 32)
                    /// @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if iszero(_8) { revert_forward() }
                    let expr_4 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0
                    /// @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if _8
                    {
                        let _9 := /** @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)" */ 32
                        /// @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                        if gt(/** @src 0:91421:91459  "oldRelay.protocolFeeInWei(_protocolId)" */ 32, /** @src 0:91538:91612  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ returndatasize()) { _9 := returndatasize() }
                        finalize_allocation(_7, _9)
                        expr_4 := abi_decode_bool_fromMemory(_7, add(_7, _9))
                    }
                    /// @src 0:91626:91667  "require(ok, OldRelayVerificationFailed())"
                    require_helper_error_OldRelayVerificationFailed(expr_4)
                    /// @src 0:91701:91719  "msg.value - oldFee"
                    let expr_5 := checked_sub_uint256(/** @src 0:91481:91490  "msg.value" */ callvalue(), /** @src 0:91701:91719  "msg.value - oldFee" */ expr_3)
                    /// @src 0:91733:92018  "if (oldRefund > 0) {..."
                    if /** @src 0:91737:91750  "oldRefund > 0" */ iszero(iszero(expr_5))
                    /// @src 0:91733:92018  "if (oldRefund > 0) {..."
                    {
                        /// @src 0:91853:91890  "msg.sender.call{value: oldRefund}(\"\")"
                        let expr_1986_component := call(gas(), /** @src 0:91853:91863  "msg.sender" */ caller(), /** @src 0:91853:91890  "msg.sender.call{value: oldRefund}(\"\")" */ expr_5, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0, 0, 0, 0)
                        /// @src 0:91853:91890  "msg.sender.call{value: oldRefund}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:91967:92003  "require(oldRefundOk, RefundFailed())"
                        require_helper_error_RefundFailed(expr_1986_component)
                    }
                    /// @src 0:92031:92042  "return true"
                    var := /** @src 0:92038:92042  "true" */ 0x01
                    /// @src 0:92031:92042  "return true"
                    leave
                }
                /// @src 0:93712:93723  "return true"
                var := /** @src 0:93719:93723  "true" */ 0x01
            }
            /// @ast-id 484 @src 0:15951:16087  "modifier onlySigningPolicySetter() {..."
            function modifier_onlySigningPolicySetter(var_signingPolicy_mpos) -> _1
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(/** @src 0:16004:16037  "msg.sender == signingPolicySetter" */ eq(/** @src 0:16004:16014  "msg.sender" */ caller(), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 0:16018:16037  "signingPolicySetter" */ 0x03), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x5c4fa5b5))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 0:25670:25710  "stateData.lastInitializedRewardEpoch + 1"
                let expr := checked_add_uint32_20022(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_19_uint32(sload(/** @src 0:25670:25679  "stateData" */ 0x07)))
                /// @src 0:25662:25765  "require(stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId, NotNextRewardEpoch())"
                require_helper_error_NotNextRewardEpoch(/** @src 0:25670:25742  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:25670:25742  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), /** @src 0:25670:25742  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ cleanup_uint24(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:25714:25742  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))))
                /// @src 0:26619:26682  "require(_signingPolicy.voters.length > 0, SigningPolicyEmpty())"
                require_helper_error_SigningPolicyEmpty(/** @src 0:26627:26659  "_signingPolicy.voters.length > 0" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ mload(add(var_signingPolicy_mpos, 128))))))
                /// @src 0:26692:26760  "require(_signingPolicy.voters.length <= MAX_VOTERS, TooManyVoters())"
                require_helper_error_TooManyVoters(/** @src 0:26700:26742  "_signingPolicy.voters.length <= MAX_VOTERS" */ iszero(gt(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:26700:26721  "_signingPolicy.voters" */ mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))), /** @src 0:7530:7533  "300" */ 0x012c)))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let length := mload(/** @src 0:26778:26799  "_signingPolicy.voters" */ mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))
                /// @src 0:26770:26869  "require(_signingPolicy.voters.length == _signingPolicy.weights.length, VotersWeightsSizeMismatch())"
                require_helper_error_VotersWeightsSizeMismatch(/** @src 0:26778:26839  "_signingPolicy.voters.length == _signingPolicy.weights.length" */ eq(length, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:26810:26832  "_signingPolicy.weights" */ mload(add(var_signingPolicy_mpos, 160)))))
                /// @src 0:26879:26902  "uint256 totalWeight = 0"
                let var_totalWeight := /** @src -1:-1:-1 */ 0
                /// @src 0:26917:26930  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 0:26912:27037  "for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {..."
                for { }
                /** @src 0:25709:25710  "1" */ 0x01
                /// @src 0:26917:26930  "uint256 i = 0"
                {
                    /// @src 0:26967:26970  "i++"
                    var_i := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:26967:26970  "i++" */ var_i, /** @src 0:25709:25710  "1" */ 0x01)
                }
                /// @src 0:26967:26970  "i++"
                {
                    /// @src 0:26936:26958  "_signingPolicy.weights"
                    let _mpos := mload(/** @src 0:26810:26832  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                    /// @src 0:26932:26965  "i < _signingPolicy.weights.length"
                    if iszero(lt(var_i, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:26936:26965  "_signingPolicy.weights.length" */ _mpos)))
                    /// @src 0:26932:26965  "i < _signingPolicy.weights.length"
                    { break }
                    /// @src 0:26986:27026  "totalWeight += _signingPolicy.weights[i]"
                    var_totalWeight := checked_add_uint256(var_totalWeight, cleanup_uint16(/** @src 0:27001:27026  "_signingPolicy.weights[i]" */ read_from_memoryt_uint16(memory_array_index_access_array_struct_FeeConfig_dyn(_mpos, var_i))))
                }
                /// @src 0:27046:27095  "require(totalWeight < 2**16, TotalWeightTooBig())"
                require_helper_error_TotalWeightTooBig(/** @src 0:27054:27073  "totalWeight < 2**16" */ lt(var_totalWeight, /** @src 0:27068:27073  "2**16" */ 0x010000))
                /// @src 0:27126:27185  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_1 := checked_mul_uint256_20087(/** @src 0:27126:27159  "uint256(_signingPolicy.threshold)" */ cleanup_uint16(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:27134:27158  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 0:27105:27262  "require(..."
                require_helper_error_ThresholdTooLow(/** @src 0:27126:27221  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS" */ iszero(lt(expr_1, /** @src 0:27189:27221  "totalWeight * MIN_THRESHOLD_BIPS" */ checked_mul_uint256_20088(var_totalWeight))))
                /// @src 0:27293:27352  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_2 := checked_mul_uint256_20087(/** @src 0:27293:27326  "uint256(_signingPolicy.threshold)" */ cleanup_uint16(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:27134:27158  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 0:27272:27430  "require(..."
                require_helper_error_ThresholdTooHigh(/** @src 0:27293:27388  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS" */ iszero(gt(expr_2, /** @src 0:27356:27388  "totalWeight * MAX_THRESHOLD_BIPS" */ checked_mul_uint256_20090(var_totalWeight))))
                /// @src 0:27475:27625  "new bytes(..."
                let expr_mpos := allocate_and_zero_memory_array_bytes(/** @src 0:27498:27615  "SIGNING_POLICY_PREFIX_BYTES +..." */ checked_add_uint256_20092(/** @src 0:27544:27615  "_signingPolicy.voters.length *..." */ checked_mul_uint256_20091(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:27544:27565  "_signingPolicy.voters" */ mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))))
                /// @src 0:27636:27653  "Counters memory m"
                let zero_struct_Counters_mpos := /** @src 0:9403:9405  "22" */ allocate_and_zero_memory_struct_struct_Counters()
                /// @src 0:27969:27990  "_signingPolicy.voters"
                let _mpos_1 := mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 0:27955:27999  "bytes2(uint16(_signingPolicy.voters.length))"
                let expr_3 := convert_uint16_to_bytes2(/** @src 0:27962:27998  "uint16(_signingPolicy.voters.length)" */ cleanup_uint16(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:27969:27997  "_signingPolicy.voters.length" */ _mpos_1)))
                /// @src 0:28013:28049  "bytes3(_signingPolicy.rewardEpochId)"
                let expr_4 := convert_uint24_to_bytes3(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:28020:28048  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))
                /// @src 0:28063:28104  "bytes4(_signingPolicy.startVotingRoundId)"
                let expr_5 := convert_uint32_to_bytes4(/** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32))))
                /// @src 0:28118:28150  "bytes2(_signingPolicy.threshold)"
                let expr_6 := convert_uint16_to_bytes2(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:27134:27158  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64))))
                /// @src 0:7432:7437  "10000"
                let _2 := mload(/** @src 0:28180:28199  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 0:28215:28248  "bytes20(_signingPolicy.voters[0])"
                let expr_7 := convert_address_to_bytes20(/** @src 0:28223:28247  "_signingPolicy.voters[0]" */ read_from_memoryt_address(memory_array_index_access_struct_FeeConfig_dyn(_mpos_1)))
                /// @src 0:27929:28317  "bytes.concat(..."
                let expr_mpos_1 := bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(expr_3, expr_4, expr_5, expr_6, _2, expr_7, /** @src 0:28262:28307  "bytes1(uint8(_signingPolicy.weights[0] >> 8))" */ convert_uint8_to_bytes1(/** @src 0:28269:28306  "uint8(_signingPolicy.weights[0] >> 8)" */ cleanup_uint8(/** @src 0:28275:28305  "_signingPolicy.weights[0] >> 8" */ shift_right_uint16_uint8(/** @src 0:28275:28300  "_signingPolicy.weights[0]" */ read_from_memoryt_uint16(memory_array_index_access_struct_FeeConfig_dyn(/** @src 0:28275:28297  "_signingPolicy.weights" */ mload(/** @src 0:26810:26832  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))))))))
                /// @src 0:28328:28474  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                for { }
                /** @src 0:25709:25710  "1" */ 0x01
                /// @src 0:28328:28474  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                {
                    /// @src 0:9403:9405  "22"
                    mstore(/** @src 0:28360:28378  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 0:28360:28380  "m.signingPolicyPos++" */ increment_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28360:28378  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                }
                /// @src 0:28360:28380  "m.signingPolicyPos++"
                {
                    /// @src 0:7432:7437  "10000"
                    let _3 := mload(/** @src 0:28360:28378  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 0:28335:28358  "m.signingPolicyPos < 64"
                    if iszero(lt(_3, /** @src 0:27134:27158  "_signingPolicy.threshold" */ 64))
                    /// @src 0:28335:28358  "m.signingPolicyPos < 64"
                    { break }
                    /// @src 0:28437:28463  "toHash[m.signingPolicyPos]"
                    let _4 := read_from_memoryt_bytes1(memory_array_index_access_bytes(expr_mpos_1, /** @src 0:7432:7437  "10000" */ _3))
                    let _5 := mload(/** @src 0:28360:28378  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 0:28396:28463  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]"
                    mstore8(memory_array_index_access_bytes(expr_mpos, _5), byte(/** @src -1:-1:-1 */ 0, /** @src 0:28396:28463  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]" */ _4))
                }
                /// @src 0:28484:28523  "bytes32 currentHash = keccak256(toHash)"
                let var_currentHash := /** @src 0:28506:28523  "keccak256(toHash)" */ keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:28506:28523  "keccak256(toHash)" */ expr_mpos_1, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28506:28523  "keccak256(toHash)" */ expr_mpos_1))
                /// @src 0:9403:9405  "22"
                mstore(zero_struct_Counters_mpos, /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(/** @src 0:28561:28572  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:25709:25710  "1" */ 0x01)
                /// @src 0:9403:9405  "22"
                mstore(/** @src 0:28586:28598  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:27134:27158  "_signingPolicy.threshold" */ 64), /** @src 0:25709:25710  "1" */ 0x01)
                /// @src 0:9403:9405  "22"
                mstore(/** @src 0:28612:28622  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:28180:28199  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                /// @src 0:28637:30843  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                for { }
                /** @src 0:25709:25710  "1" */ 0x01
                /// @src 0:28637:30843  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                { }
                {
                    /// @src 0:7432:7437  "10000"
                    let _6 := mload(/** @src 0:28644:28657  "m.weightIndex" */ zero_struct_Counters_mpos)
                    /// @src 0:28644:28688  "m.weightIndex < _signingPolicy.voters.length"
                    if iszero(lt(_6, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28660:28681  "_signingPolicy.voters" */ mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))))
                    /// @src 0:28644:28688  "m.weightIndex < _signingPolicy.voters.length"
                    { break }
                    /// @src 0:9403:9405  "22"
                    mstore(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128), /** @src -1:-1:-1 */ 0)
                    /// @src 0:9403:9405  "22"
                    mstore(/** @src 0:28729:28739  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src -1:-1:-1 */ 0)
                    /// @src 0:9403:9405  "22"
                    mstore(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160), /** @src -1:-1:-1 */ 0)
                    /// @src 0:28806:30516  "while (..."
                    for { }
                    /** @src 0:25709:25710  "1" */ 0x01
                    /// @src 0:28806:30516  "while (..."
                    { }
                    {
                        /// @src 0:28830:28890  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        let expr_8 := /** @src 0:28830:28842  "m.count < 32" */ lt(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128)), /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32)
                        /// @src 0:28830:28890  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if expr_8
                        {
                            /// @src 0:7432:7437  "10000"
                            let _7 := mload(/** @src 0:28846:28859  "m.weightIndex" */ zero_struct_Counters_mpos)
                            /// @src 0:28830:28890  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                            expr_8 := /** @src 0:28846:28890  "m.weightIndex < _signingPolicy.voters.length" */ lt(_7, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:28862:28883  "_signingPolicy.voters" */ mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))
                        }
                        /// @src 0:28830:28890  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if iszero(expr_8) { break }
                        /// @src 0:7432:7437  "10000"
                        let _8 := mload(/** @src 0:28927:28940  "m.weightIndex" */ zero_struct_Counters_mpos)
                        /// @src 0:28923:30460  "if (m.weightIndex < m.voterIndex) {..."
                        switch /** @src 0:28927:28955  "m.weightIndex < m.voterIndex" */ lt(_8, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28586:28598  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:27134:27158  "_signingPolicy.threshold" */ 64)))
                        case /** @src 0:28923:30460  "if (m.weightIndex < m.voterIndex) {..." */ 0 {
                            /// @src 0:9403:9405  "22"
                            mstore(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160), /** @src 0:29766:29781  "20 - m.voterPos" */ checked_sub_uint256_20096(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28612:28622  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:28180:28199  "_signingPolicy.seed" */ 96))))
                            /// @src 0:7432:7437  "10000"
                            let _9 := mload(/** @src 0:28612:28622  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:28180:28199  "_signingPolicy.seed" */ 96))
                            /// @src 0:29803:29808  "m.pos"
                            let _10 := add(zero_struct_Counters_mpos, 224)
                            /// @src 0:9403:9405  "22"
                            mstore(_10, _9)
                            /// @src 0:29912:29933  "_signingPolicy.voters"
                            let _mpos_2 := mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                            /// @src 0:29896:29989  "uint256(uint160(_signingPolicy.voters[m.voterIndex])) <<..."
                            let _11 := shift_left_t_uint256_t_uint8(/** @src 0:29896:29949  "uint256(uint160(_signingPolicy.voters[m.voterIndex]))" */ cleanup_address_payable(/** @src 0:29904:29948  "uint160(_signingPolicy.voters[m.voterIndex])" */ cleanup_address_payable(/** @src 0:29912:29947  "_signingPolicy.voters[m.voterIndex]" */ read_from_memoryt_address(memory_array_index_access_array_struct_FeeConfig_dyn(_mpos_2, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28586:28598  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:27134:27158  "_signingPolicy.threshold" */ 64)))))))
                            /// @src 0:7432:7437  "10000"
                            let _12 := mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128))
                            /// @src 0:30033:30306  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 0:30037:30065  "m.count + m.bytesToTake > 32" */ gt(/** @src 0:30037:30060  "m.count + m.bytesToTake" */ checked_add_uint256(_12, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160))), /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 0:30033:30306  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 0:9403:9405  "22"
                                mstore(/** @src 0:28612:28622  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:28180:28199  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                                /// @src 0:9403:9405  "22"
                                mstore(/** @src 0:28586:28598  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:27134:27158  "_signingPolicy.threshold" */ 64), /** @src 0:30269:30283  "m.voterIndex++" */ increment_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28586:28598  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:27134:27158  "_signingPolicy.threshold" */ 64))))
                            }
                            default /// @src 0:30033:30306  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 0:30109:30121  "32 - m.count"
                                let _13 := checked_sub_uint256_20098(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128)))
                                /// @src 0:9403:9405  "22"
                                mstore(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160), /** @src 0:9403:9405  "22" */ _13)
                                mstore(/** @src 0:28612:28622  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:28180:28199  "_signingPolicy.seed" */ 96), /** @src 0:30147:30174  "m.voterPos += m.bytesToTake" */ checked_add_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28612:28622  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:28180:28199  "_signingPolicy.seed" */ 96)), /** @src 0:7432:7437  "10000" */ _13))
                            }
                            /// @src 0:9403:9405  "22"
                            mstore(/** @src 0:28729:28739  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 0:30327:30441  "m.nextSlot |= bytes32(..." */ or(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28729:28739  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shr(/** @src 0:30406:30417  "8 * m.count" */ checked_mul_uint256_20099(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128))), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(/** @src 0:30390:30399  "8 * m.pos" */ checked_mul_uint256_20099(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:30394:30399  "m.pos" */ _10)), /** @src 0:9403:9405  "22" */ _11))))
                        }
                        default /// @src 0:28923:30460  "if (m.weightIndex < m.voterIndex) {..."
                        {
                            /// @src 0:9403:9405  "22"
                            mstore(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160), /** @src 0:28995:29010  "2 - m.weightPos" */ checked_sub_uint256_20101(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28561:28572  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32))))
                            /// @src 0:7432:7437  "10000"
                            let _14 := mload(/** @src 0:28561:28572  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 0:29032:29037  "m.pos"
                            let _15 := add(zero_struct_Counters_mpos, 224)
                            /// @src 0:9403:9405  "22"
                            mstore(_15, _14)
                            /// @src 0:29171:29193  "_signingPolicy.weights"
                            let _mpos_3 := mload(/** @src 0:26810:26832  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                            /// @src 0:29127:29247  "uint256(..."
                            let _16 := shift_left_uint256_uint8(/** @src 0:29127:29235  "uint256(..." */ cleanup_uint16(/** @src 0:29171:29208  "_signingPolicy.weights[m.weightIndex]" */ read_from_memoryt_uint16(memory_array_index_access_array_struct_FeeConfig_dyn(_mpos_3, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:29194:29207  "m.weightIndex" */ zero_struct_Counters_mpos)))))
                            /// @src 0:7432:7437  "10000"
                            let _17 := mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128))
                            /// @src 0:29291:29567  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 0:29295:29323  "m.count + m.bytesToTake > 32" */ gt(/** @src 0:29295:29318  "m.count + m.bytesToTake" */ checked_add_uint256(_17, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160))), /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 0:29291:29567  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 0:9403:9405  "22"
                                mstore(/** @src 0:28561:28572  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32), /** @src -1:-1:-1 */ 0)
                                /// @src 0:9403:9405  "22"
                                mstore(zero_struct_Counters_mpos, /** @src 0:29529:29544  "m.weightIndex++" */ increment_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:29529:29544  "m.weightIndex++" */ zero_struct_Counters_mpos)))
                            }
                            default /// @src 0:29291:29567  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 0:29367:29379  "32 - m.count"
                                let _18 := checked_sub_uint256_20098(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128)))
                                /// @src 0:9403:9405  "22"
                                mstore(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160), /** @src 0:9403:9405  "22" */ _18)
                                mstore(/** @src 0:28561:28572  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:29405:29433  "m.weightPos += m.bytesToTake" */ checked_add_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28561:28572  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32)), /** @src 0:7432:7437  "10000" */ _18))
                            }
                            /// @src 0:9403:9405  "22"
                            mstore(/** @src 0:28729:28739  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 0:29588:29703  "m.nextSlot |= bytes32(..." */ or(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28729:28739  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shr(/** @src 0:29668:29679  "8 * m.count" */ checked_mul_uint256_20099(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128))), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(/** @src 0:29652:29661  "8 * m.pos" */ checked_mul_uint256_20099(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:29656:29661  "m.pos" */ _15)), /** @src 0:9403:9405  "22" */ _16))))
                        }
                        mstore(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128), /** @src 0:30477:30501  "m.count += m.bytesToTake" */ checked_add_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128)), /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28775:28788  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:26810:26832  "_signingPolicy.weights" */ 160))))
                    }
                    /// @src 0:30529:30833  "if (m.count > 0) {..."
                    if /** @src 0:30533:30544  "m.count > 0" */ iszero(iszero(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128))))
                    /// @src 0:30529:30833  "if (m.count > 0) {..."
                    {
                        /// @src 0:30588:30625  "bytes.concat(currentHash, m.nextSlot)"
                        let expr_mpos_2 := bytes_concat_bytes32_bytes32(var_currentHash, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28729:28739  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)))
                        /// @src 0:30564:30626  "currentHash = keccak256(bytes.concat(currentHash, m.nextSlot))"
                        var_currentHash := /** @src 0:30578:30626  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:30578:30626  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:30578:30626  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2))
                        /// @src 0:30649:30662  "uint256 i = 0"
                        let var_i_1 := /** @src -1:-1:-1 */ 0
                        /// @src 0:30644:30819  "for (uint256 i = 0; i < m.count; i++) {..."
                        for { }
                        /** @src 0:25709:25710  "1" */ 0x01
                        /// @src 0:30649:30662  "uint256 i = 0"
                        {
                            /// @src 0:30677:30680  "i++"
                            var_i_1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:30677:30680  "i++" */ var_i_1, /** @src 0:25709:25710  "1" */ 0x01)
                        }
                        /// @src 0:30677:30680  "i++"
                        {
                            /// @src 0:30664:30675  "i < m.count"
                            if iszero(lt(var_i_1, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28704:28711  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:26627:26648  "_signingPolicy.voters" */ 128))))
                            /// @src 0:30664:30675  "i < m.count"
                            { break }
                            /// @src 0:7432:7437  "10000"
                            let _19 := mload(/** @src 0:28729:28739  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192))
                            /// @src 0:30745:30758  "m.nextSlot[i]"
                            if iszero(lt(var_i_1, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 0:30745:30758  "m.nextSlot[i]"
                            { panic_error_0x32() }
                            /// @src 0:30704:30758  "signingPolicyBytes[m.signingPolicyPos] = m.nextSlot[i]"
                            mstore8(memory_array_index_access_bytes(expr_mpos, /** @src 0:7432:7437  "10000" */ mload(/** @src 0:28360:28378  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))), /** @src 0:30745:30758  "m.nextSlot[i]" */ byte(var_i_1, _19))
                            /// @src 0:9403:9405  "22"
                            mstore(/** @src 0:28360:28378  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 0:30780:30800  "m.signingPolicyPos++" */ increment_uint256(/** @src 0:7432:7437  "10000" */ mload(/** @src 0:28360:28378  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                        }
                    }
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _20 := sload(/** @src 0:31314:31327  "sourceChainId" */ 0x0b)
                /// @src 0:31297:31341  "abi.encodePacked(sourceChainId, currentHash)"
                let expr_mpos_3 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:27134:27158  "_signingPolicy.threshold" */ 64)
                /// @src 0:31297:31341  "abi.encodePacked(sourceChainId, currentHash)"
                let _21 := add(expr_mpos_3, /** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 0:31297:31341  "abi.encodePacked(sourceChainId, currentHash)"
                let _22 := sub(abi_encode_packed_uint256_bytes32(_21, _20, var_currentHash), expr_mpos_3)
                mstore(expr_mpos_3, add(_22, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(31)))
                /// @src 0:31297:31341  "abi.encodePacked(sourceChainId, currentHash)"
                finalize_allocation(expr_mpos_3, _22)
                /// @src 0:31287:31342  "keccak256(abi.encodePacked(sourceChainId, currentHash))"
                let expr_9 := keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _21, mload(/** @src 0:31287:31342  "keccak256(abi.encodePacked(sourceChainId, currentHash))" */ expr_mpos_3))
                /// @src 5:1188:1194  "7 days"
                sstore(/** @src 0:31352:31408  "toSigningPolicyHashPrivate[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256__bytes32__of_uint24(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:31379:31407  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))), /** @src 5:1188:1194  "7 days" */ expr_9)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _23 := cleanup_uint24(mload(/** @src 0:31471:31499  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:31432:31499  "stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId"
                update_storage_value_offset_uint32_to_uint32_20038(cleanup_uint24(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _23))
                /// @src 5:1188:1194  "7 days"
                sstore(/** @src 0:31509:31561  "startingVotingRoundIds[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _23), /** @src 0:31509:31597  "startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy.startVotingRoundId" */ cleanup_uint32(/** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))))
                /// @src 0:31650:31678  "_signingPolicy.rewardEpochId"
                let _24 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint24(mload(/** @src 0:31650:31678  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:31692:31725  "_signingPolicy.startVotingRoundId"
                let _25 := /** @src 0:7432:7437  "10000" */ cleanup_uint32(mload(/** @src 0:28070:28103  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))
                /// @src 0:31739:31763  "_signingPolicy.threshold"
                let _26 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint16(mload(/** @src 0:27134:27158  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))
                /// @src 0:7432:7437  "10000"
                let _27 := mload(/** @src 0:28180:28199  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 0:31810:31831  "_signingPolicy.voters"
                let _mpos_4 := mload(/** @src 0:26627:26648  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 0:31845:31867  "_signingPolicy.weights"
                let _mpos_5 := mload(/** @src 0:26810:26832  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                /// @src 0:31612:31946  "SigningPolicyInitialized(..."
                let _28 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:27134:27158  "_signingPolicy.threshold" */ 64)
                /// @src 0:31612:31946  "SigningPolicyInitialized(..."
                log2(_28, sub(abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(_28, _25, _26, _27, _mpos_4, _mpos_5, expr_mpos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:31920:31935  "block.timestamp" */ timestamp(), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffffffffffff)), /** @src 0:31612:31946  "SigningPolicyInitialized(..." */ _28), 0x91d0280e969157fc6c5b8f952f237b03d934b18534dafcac839075bbc33522f8, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:31612:31946  "SigningPolicyInitialized(..." */ _24, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffff))
                /// @src 0:16079:16080  "_"
                _1 := expr_9
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
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
            /// @src 0:7530:7533  "300"
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
            function checked_add_uint256_20092(y) -> sum
            {
                sum := add(/** @src 0:9541:9543  "43" */ 0x2b, /** @src 0:7530:7533  "300" */ y)
                if gt(/** @src 0:9541:9543  "43" */ 0x2b, /** @src 0:7530:7533  "300" */ sum) { panic_error_0x11() }
            }
            function checked_add_uint256_20162(x) -> sum
            {
                sum := add(x, /** @src 0:96463:96481  "merkleRootsPrivate" */ 0x01)
                /// @src 0:7530:7533  "300"
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
            function checked_mul_uint256_20087(x) -> product
            {
                product := mul(x, /** @src 0:7432:7437  "10000" */ 0x2710)
                /// @src 0:7530:7533  "300"
                if iszero(or(iszero(x), eq(/** @src 0:7432:7437  "10000" */ 0x2710, /** @src 0:7530:7533  "300" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_20088(x) -> product
            {
                product := mul(x, /** @src 0:7585:7589  "5000" */ 0x1388)
                /// @src 0:7530:7533  "300"
                if iszero(or(iszero(x), eq(/** @src 0:7585:7589  "5000" */ 0x1388, /** @src 0:7530:7533  "300" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_20090(x) -> product
            {
                product := mul(x, /** @src 0:7641:7645  "6600" */ 0x19c8)
                /// @src 0:7530:7533  "300"
                if iszero(or(iszero(x), eq(/** @src 0:7641:7645  "6600" */ 0x19c8, /** @src 0:7530:7533  "300" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_20091(x) -> product
            {
                product := mul(x, /** @src 0:9403:9405  "22" */ 0x16)
                /// @src 0:7530:7533  "300"
                if iszero(or(iszero(x), eq(/** @src 0:9403:9405  "22" */ 0x16, /** @src 0:7530:7533  "300" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_20099(y) -> product
            {
                product := shl(3, y)
                if iszero(eq(y, and(y, sub(shl(253, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1), 1))))
                /// @src 0:7530:7533  "300"
                { panic_error_0x11() }
            }
            function checked_mul_uint256(x, y) -> product
            {
                product := mul(x, y)
                if iszero(or(iszero(x), eq(y, div(product, x)))) { panic_error_0x11() }
            }
            /// @src 0:7585:7589  "5000"
            function require_helper_error_ThresholdTooLow(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(225, 0x1cc767c5))
                    revert(0, 4)
                }
            }
            /// @src 0:7641:7645  "6600"
            function require_helper_error_ThresholdTooHigh(condition)
            {
                if iszero(condition)
                {
                    mstore(0, shl(224, 0xe56d58cf))
                    revert(0, 4)
                }
            }
            /// @src 0:9403:9405  "22"
            function allocate_and_zero_memory_array_bytes(length) -> memPtr
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := array_allocation_size_bytes(length)
                let memPtr_1 := mload(64)
                finalize_allocation(memPtr_1, _1)
                mstore(memPtr_1, length)
                /// @src 0:9403:9405  "22"
                memPtr := memPtr_1
                calldatacopy(add(memPtr_1, 32), calldatasize(), add(array_allocation_size_bytes(length), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(31)))
            }
            /// @src 0:9403:9405  "22"
            function allocate_and_zero_memory_struct_struct_Counters() -> memPtr
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let memPtr_1 := mload(64)
                let newFreePtr := add(memPtr_1, /** @src 0:9403:9405  "22" */ 288)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1)) { panic_error_0x41() }
                mstore(64, newFreePtr)
                /// @src 0:9403:9405  "22"
                memPtr := memPtr_1
                mstore(memPtr_1, /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, 32), /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 64), /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, 96), /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, 128), /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, 160), /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, 192), /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, 224), /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                mstore(add(memPtr_1, 256), /** @src -1:-1:-1 */ 0)
            }
            /// @src 0:9403:9405  "22"
            function convert_uint16_to_bytes2(value) -> converted
            {
                converted := and(shl(240, value), shl(240, /** @src 0:7432:7437  "10000" */ 65535))
            }
            /// @src 0:9403:9405  "22"
            function convert_uint24_to_bytes3(value) -> converted
            {
                converted := and(shl(232, value), /** @src 0:38471:90030  "assembly {..." */ shl(232, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 16777215))
            }
            /// @src 0:9403:9405  "22"
            function convert_uint32_to_bytes4(value) -> converted
            {
                converted := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shl(224, /** @src 0:9403:9405  "22" */ value), shl(224, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))
            }
            /// @src 0:9403:9405  "22"
            function convert_address_to_bytes20(value) -> converted
            {
                converted := /** @src 0:7432:7437  "10000" */ and(shl(96, /** @src 0:9403:9405  "22" */ value), not(/** @src 0:7432:7437  "10000" */ 0xffffffffffffffffffffffff))
            }
            /// @src 0:9403:9405  "22"
            function shift_right_uint16_uint8(value) -> result
            {
                result := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(8, /** @src 0:9403:9405  "22" */ value), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)
            }
            /// @src 0:9403:9405  "22"
            function convert_uint8_to_bytes1(value) -> converted
            {
                converted := and(shl(248, value), shl(248, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255))
            }
            /// @src 0:9403:9405  "22"
            function bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(param, param_1, param_2, param_3, param_4, param_5, param_6) -> outPtr
            {
                outPtr := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                /// @src 0:9403:9405  "22"
                mstore(add(outPtr, 0x20), and(param, shl(240, /** @src 0:7432:7437  "10000" */ 65535)))
                /// @src 0:9403:9405  "22"
                mstore(add(outPtr, 34), and(param_1, /** @src 0:38471:90030  "assembly {..." */ shl(232, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 16777215)))
                /// @src 0:9403:9405  "22"
                mstore(add(outPtr, 37), and(param_2, shl(224, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff)))
                /// @src 0:9403:9405  "22"
                mstore(add(outPtr, 41), and(param_3, shl(240, /** @src 0:7432:7437  "10000" */ 65535)))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src 0:9403:9405  "22" */ add(outPtr, 43), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ param_4)
                /// @src 0:9403:9405  "22"
                mstore(add(outPtr, 75), and(param_5, not(/** @src 0:7432:7437  "10000" */ 0xffffffffffffffffffffffff)))
                /// @src 0:9403:9405  "22"
                mstore(add(outPtr, 95), and(param_6, shl(248, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255)))
                /// @src 0:9403:9405  "22"
                mstore(outPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 64)
                /// @src 0:9403:9405  "22"
                finalize_allocation(outPtr, 96)
            }
            function increment_uint256(value) -> ret
            {
                if eq(value, /** @src 0:38471:90030  "assembly {..." */ not(0))
                /// @src 0:9403:9405  "22"
                { panic_error_0x11() }
                ret := add(value, 1)
            }
            function memory_array_index_access_bytes(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:9403:9405  "22" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, index), 32)
            }
            function read_from_memoryt_bytes1(ptr) -> returnValue
            {
                returnValue := and(mload(ptr), shl(248, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255))
            }
            /// @src 0:9403:9405  "22"
            function shift_left_t_uint256_t_uint8(value) -> result
            {
                result := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(96, /** @src 0:9403:9405  "22" */ value)
            }
            function shift_left_uint256_uint8(value) -> result
            {
                result := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(240, /** @src 0:9403:9405  "22" */ value)
            }
            function bytes_concat_bytes32_bytes32(param, param_1) -> outPtr
            {
                outPtr := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                mstore(/** @src 0:9403:9405  "22" */ add(outPtr, 0x20), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ param)
                mstore(/** @src 0:9403:9405  "22" */ add(outPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 64), param_1)
                /// @src 0:9403:9405  "22"
                mstore(outPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 64)
                /// @src 0:9403:9405  "22"
                finalize_allocation(outPtr, 96)
            }
            function abi_encode_packed_uint256_bytes32(pos, value0, value1) -> end
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(pos, value0)
                mstore(/** @src 0:9403:9405  "22" */ add(pos, 32), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value1)
                /// @src 0:9403:9405  "22"
                end := add(pos, 64)
            }
            function mapping_index_access_mapping_uint256__bytes32__of_uint24(key) -> dataSlot
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:9403:9405  "22" */ key, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffff))
                /// @src 0:9403:9405  "22"
                mstore(0x20, /** @src -1:-1:-1 */ 0)
                /// @src 0:9403:9405  "22"
                dataSlot := keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:9403:9405  "22" */ 0x40)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24(key) -> dataSlot
            {
                mstore(0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:9403:9405  "22" */ key, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffff))
                /// @src 0:9403:9405  "22"
                mstore(0x20, /** @src 0:31509:31531  "startingVotingRoundIds" */ 0x02)
                /// @src 0:9403:9405  "22"
                dataSlot := keccak256(0, 0x40)
            }
            function abi_encode_array_uint16_dyn(value, pos) -> end
            {
                let length := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:9403:9405  "22" */ value)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(pos, length)
                /// @src 0:9403:9405  "22"
                pos := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(pos, 0x20)
                /// @src 0:9403:9405  "22"
                let srcPtr := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9403:9405  "22" */ value, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20)
                /// @src 0:9403:9405  "22"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 0:9403:9405  "22"
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(pos, and(/** @src 0:9403:9405  "22" */ mload(srcPtr), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffff))
                    /// @src 0:9403:9405  "22"
                    pos := add(pos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20)
                    /// @src 0:9403:9405  "22"
                    srcPtr := add(srcPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20)
                }
                /// @src 0:9403:9405  "22"
                end := pos
            }
            function abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(headStart, value0, value1, value2, value3, value4, value5, value6) -> tail
            {
                let tail_1 := add(headStart, 224)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(headStart, and(value0, 0xffffffff))
                mstore(/** @src 0:9403:9405  "22" */ add(headStart, 32), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(value1, 0xffff))
                mstore(/** @src 0:9403:9405  "22" */ add(headStart, 64), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ value2)
                /// @src 0:9403:9405  "22"
                mstore(add(headStart, 96), 224)
                let pos := tail_1
                let length := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:9403:9405  "22" */ value3)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(tail_1, length)
                /// @src 0:9403:9405  "22"
                pos := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9403:9405  "22" */ headStart, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 256)
                /// @src 0:9403:9405  "22"
                let srcPtr := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 0:9403:9405  "22" */ value3, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(pos, and(/** @src 0:9403:9405  "22" */ mload(srcPtr), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1)))
                    /// @src 0:9403:9405  "22"
                    pos := add(pos, 32)
                    srcPtr := add(srcPtr, 32)
                }
                mstore(add(headStart, 128), sub(pos, headStart))
                let tail_2 := abi_encode_array_uint16_dyn(value4, pos)
                mstore(add(headStart, 160), sub(tail_2, headStart))
                tail := abi_encode_string(value5, tail_2)
                abi_encode_rational_by(value6, add(headStart, 192))
            }
            /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
            function abi_decode_uint256t_boolt_uint256_fromMemory(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value := mload(headStart)
                value0 := value
                /// @src 0:7432:7437  "10000"
                let value_1 := mload(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(headStart, 32))
                /// @src 0:7432:7437  "10000"
                validator_revert_bool(value_1)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value1 := value_1
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                value_2 := mload(add(headStart, 64))
                value2 := value_2
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
            /// @ast-id 2343 @src 0:95822:96975  "function getRandomNumberHistorical(uint256 _votingRoundId)..."
            function fun_getRandomNumberHistorical(var__votingRoundId) -> var_randomNumber, var_isSecureRandom, var_randomTimestamp
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(/** @src 0:96063:96071  "oldRelay" */ 0x09)
                /// @src 0:96055:96072  "address(oldRelay)"
                let expr := cleanup_address_payable(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_address_payable(_1))
                /// @src 0:96055:96151  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr_1 := /** @src 0:96055:96086  "address(oldRelay) != address(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:96055:96086  "address(oldRelay) != address(0)" */ expr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))))
                /// @src 0:96055:96151  "address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr_1
                {
                    expr_1 := /** @src 0:96090:96151  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var__votingRoundId, cleanup_uint32(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_t_uint32(_1)))
                }
                /// @src 0:96051:96235  "if (address(oldRelay) != address(0) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr_1
                {
                    /// @src 0:96174:96224  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _2 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                    /// @src 0:96174:96224  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    mstore(_2, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(227, 0x150fe287))
                    /// @src 0:96174:96224  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _3 := staticcall(gas(), expr, _2, sub(abi_encode_tuple_bytes32(add(_2, 4), var__votingRoundId), _2), _2, 96)
                    if iszero(_3) { revert_forward() }
                    let expr_2269_component := /** @src 0:96084:96085  "0" */ 0x00
                    let expr_component := 0x00
                    let expr_component_1 := 0x00
                    /// @src 0:96174:96224  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    if _3
                    {
                        let _4 := 96
                        if gt(96, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        let expr_component_2, expr_component_3, expr_component_4 := abi_decode_uint256t_boolt_uint256_fromMemory(_2, add(_2, _4))
                        expr_2269_component := expr_component_2
                        expr_component := expr_component_3
                        expr_component_1 := expr_component_4
                    }
                    /// @src 0:96167:96224  "return oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    var_randomNumber := expr_2269_component
                    var_isSecureRandom := expr_component
                    var_randomTimestamp := expr_component_1
                    leave
                }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _5 := sload(/** @src 0:96482:96491  "stateData" */ 0x07)
                /// @src 0:96455:96564  "require(merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0), NoRandomNumber())"
                require_helper_error_NoRandomNumber(/** @src 0:96463:96545  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:96463:96531  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:96463:96515  "merkleRootsPrivate[stateData.randomNumberProtocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint8(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleanup_uint8(_5)), /** @src 0:96463:96531  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ var__votingRoundId)))))
                /// @src 0:96574:96627  "_randomNumber = toRandomNumberPrivate[_votingRoundId]"
                var_randomNumber := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:96590:96627  "toRandomNumberPrivate[_votingRoundId]" */ mapping_index_access_t_mapping_t_uint256_t_uint256_of_t_uint256(var__votingRoundId))
                /// @src 0:96637:96801  "_isSecureRandom =..."
                var_isSecureRandom := /** @src 0:96667:96801  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))..." */ eq(/** @src 0:96667:96762  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))" */ and(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shr(/** @src 0:96712:96738  "255 - _votingRoundId % 256" */ checked_sub_uint256_20161(/** @src 0:96718:96738  "_votingRoundId % 256" */ mod_uint256(var__votingRoundId)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 0:96668:96707  "isSecureRandomMap[_votingRoundId / 256]" */ mapping_index_access_mapping_uint256__uint256__of_uint256(/** @src 0:96686:96706  "_votingRoundId / 256" */ checked_div_uint256(var__votingRoundId)))), /** @src 0:96463:96481  "merkleRootsPrivate" */ 0x01), 0x01)
                /// @src 0:96842:96875  "stateData.firstVotingRoundStartTs"
                let _6 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_uint32(_5)
                /// @src 0:96898:96916  "_votingRoundId + 1"
                let expr_2 := checked_add_uint256_20162(var__votingRoundId)
                /// @src 0:96811:96968  "_randomTimestamp =..."
                var_randomTimestamp := /** @src 0:96842:96968  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(/** @src 0:96842:96968  "stateData.firstVotingRoundStartTs +..." */ _6, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff), /** @src 0:96890:96968  "uint256(_votingRoundId + 1) *..." */ checked_mul_uint256(expr_2, cleanup_uint8(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ extract_from_storage_value_offset_uint8(_5))))
            }
            /// @src 0:38471:90030  "assembly {..."
            function usr$revertWithError_19977(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x1fe641cf))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19978(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x5509ecdf))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19980(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x050ff0d7))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19982(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x21d34b23))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19983(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xd0ebeb4b))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19984(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xe3427225))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19986(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x4913ec0d))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19987(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x8134d963))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19988(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x4ed02d0d))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19989(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x0c01bf37))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19991(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x3d93f667))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19994(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xf0059553))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19995(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x3d8f01cb))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19996(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(225, 0x29e11b6d))
                /// @src 0:38471:90030  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_19997(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:7530:7533  "300" */ shl(224, 0x4647aac9))
                /// @src 0:38471:90030  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x60c18b0d))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20000(usr_memPtr)
            {
                mstore(usr_memPtr, shl(229, 0x05f459a9))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20001(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x124f824d))
                /// @src 0:38471:90030  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20003(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xf8139caf))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20004(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xe246dc63))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20005(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x1390f2a1))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20006(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x297f31e1))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20007(usr_memPtr)
            {
                mstore(usr_memPtr, shl(227, 0x1064186b))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20008(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xf54d11f5))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20009(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xc859b3f5))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20010(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x315e8bad))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20011(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0xe5c48ac5))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20012(usr_memPtr)
            {
                mstore(usr_memPtr, shl(227, 0x06ad4883))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20013(usr_memPtr)
            {
                mstore(usr_memPtr, shl(225, 0x49337731))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20019(usr_memPtr)
            {
                mstore(usr_memPtr, shl(226, 0x383241e3))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20163(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xd76adcd1))
                /// @src 0:38471:90030  "assembly {..."
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20164(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x5d2f8a05))
                revert(usr_memPtr, 4)
            }
            function usr$revertWithError_20165(usr_memPtr)
            {
                mstore(usr_memPtr, shl(224, 0x987d1299))
                revert(usr_memPtr, 4)
            }
            function usr$assignStruct(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, /** @src 0:7432:7437  "10000" */ not(shl(152, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:38471:90030  "assembly {..." */ shl(152, usr$newVal))
            }
            function usr$assignStruct_20017(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(112, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xffffffff))), /** @src 0:38471:90030  "assembly {..." */ shl(112, usr$newVal))
            }
            function usr$assignStruct_20018(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(144, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255))), /** @src 0:38471:90030  "assembly {..." */ shl(144, usr$newVal))
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
            function usr$calculateSigningPolicyHash_19979(usr_memPos, usr_policyLength, usr_sourceChainId) -> usr_policyHash
            {
                calldatacopy(usr_memPos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4, /** @src 0:38471:90030  "assembly {..." */ 32)
                let usr$endPos := add(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4, /** @src 0:38471:90030  "assembly {..." */ and(usr_policyLength, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(31)))
                /// @src 0:38471:90030  "assembly {..."
                let usr$pos := 36
                for { } lt(usr$pos, usr$endPos) { usr$pos := add(usr$pos, 32) }
                {
                    calldatacopy(add(usr_memPos, 32), usr$pos, 32)
                    mstore(usr_memPos, keccak256(usr_memPos, 64))
                }
                let _1 := and(usr_policyLength, 31)
                let _2 := iszero(_1)
                if _2
                {
                    usr_policyHash := mload(usr_memPos)
                }
                if iszero(_2)
                {
                    let _3 := add(usr_memPos, 32)
                    mstore(_3, 0)
                    calldatacopy(_3, usr$endPos, _1)
                    let _4 := keccak256(usr_memPos, 64)
                    mstore(usr_memPos, _4)
                    usr_policyHash := _4
                }
                mstore(usr_memPos, usr_sourceChainId)
                mstore(add(usr_memPos, 32), usr_policyHash)
                usr_policyHash := keccak256(usr_memPos, 64)
            }
            function usr$calculateSigningPolicyHash(usr$_memPos, usr_calldataPos, usr_policyLength, usr_sourceChainId) -> usr$_policyHash
            {
                calldatacopy(usr$_memPos, usr_calldataPos, 32)
                let usr$endPos := add(usr_calldataPos, and(usr_policyLength, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ not(31)))
                /// @src 0:38471:90030  "assembly {..."
                let usr$pos := add(usr_calldataPos, 32)
                for { } lt(usr$pos, usr$endPos) { usr$pos := add(usr$pos, 32) }
                {
                    calldatacopy(add(usr$_memPos, 32), usr$pos, 32)
                    mstore(usr$_memPos, keccak256(usr$_memPos, 64))
                }
                let _1 := and(usr_policyLength, 31)
                let _2 := iszero(_1)
                if _2
                {
                    usr$_policyHash := mload(usr$_memPos)
                }
                if iszero(_2)
                {
                    let _3 := add(usr$_memPos, 32)
                    mstore(_3, 0)
                    calldatacopy(_3, usr$endPos, _1)
                    let _4 := keccak256(usr$_memPos, 64)
                    mstore(usr$_memPos, _4)
                    usr$_policyHash := _4
                }
                mstore(usr$_memPos, usr_sourceChainId)
                mstore(add(usr$_memPos, 32), usr$_policyHash)
                usr$_policyHash := keccak256(usr$_memPos, 64)
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
                /// @src 0:38471:90030  "assembly {..."
                let usr$numberOfVoters := and(shr(72, usr_metadata), 65535)
                let usr$i := /** @src -1:-1:-1 */ 0
                /// @src 0:38471:90030  "assembly {..."
                for { } lt(usr$i, usr$numberOfVoters) { usr$i := add(usr$i, 1) }
                {
                    usr_totalWeight := add(usr_totalWeight, shr(240, calldataload(add(add(usr_signingPolicyStart, mul(usr$i, 22)), 63))))
                }
                if gt(usr_totalWeight, 65535)
                {
                    mstore(usr_memPtr, /** @src 0:7530:7533  "300" */ shl(224, 0x8dd23571))
                    /// @src 0:38471:90030  "assembly {..."
                    revert(usr_memPtr, 4)
                }
                let _1 := mul(and(usr_metadata, 65535), 10000)
                if lt(_1, mul(usr_totalWeight, 5000))
                {
                    mstore(usr_memPtr, /** @src 0:7585:7589  "5000" */ shl(225, 0x1cc767c5))
                    /// @src 0:38471:90030  "assembly {..."
                    revert(usr_memPtr, 4)
                }
                if gt(_1, mul(usr_totalWeight, 6600))
                {
                    mstore(usr_memPtr, /** @src 0:7641:7645  "6600" */ shl(224, 0xe56d58cf))
                    /// @src 0:38471:90030  "assembly {..."
                    revert(usr_memPtr, 4)
                }
            }
            function usr$setIsSecureRandomBit(usr_memPtr, usr_votingRoundId)
            {
                mstore(usr_memPtr, shr(8, usr_votingRoundId))
                mstore(add(usr_memPtr, 32), 6)
                let _1 := keccak256(usr_memPtr, 64)
                sstore(_1, or(sload(_1), shl(sub(255, and(usr_votingRoundId, 255)), 1)))
            }
            function usr$processRandomMerkleProof(usr_memPtr, usr_proofStart, usr_memPtrMerkleRoot, usr_votingRoundId, usr_isSecureRandom)
            {
                let _1 := add(usr_proofStart, 32)
                if lt(calldatasize(), _1)
                {
                    usr$revertWithError_20163(usr_memPtr)
                }
                if iszero(iszero(and(sub(calldatasize(), usr_proofStart), 31)))
                {
                    usr$revertWithError_20164(usr_memPtr)
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
                    usr$revertWithError_20165(usr_memPtr)
                }
                calldatacopy(_3, usr_proofStart, 32)
                mstore(usr_memPtr, usr_votingRoundId)
                mstore(_2, 8)
                sstore(keccak256(usr_memPtr, 64), mload(_3))
            }
            /// @src 18:3426:3641  "function transferOwnership(address newOwner) public virtual onlyOwner {..."
            function fun_transferOwnership_inner(var_newOwner)
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := and(/** @src 18:3510:3532  "newOwner == address(0)" */ var_newOwner, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 18:3506:3597  "if (newOwner == address(0)) {..."
                if /** @src 18:3510:3532  "newOwner == address(0)" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _1)
                /// @src 18:3506:3597  "if (newOwner == address(0)) {..."
                {
                    /// @src 18:3555:3586  "OwnableInvalidOwner(address(0))"
                    mstore(/** @src 18:3530:3531  "0" */ 0x00, /** @src 18:3555:3586  "OwnableInvalidOwner(address(0))" */ shl(224, 0x1e4fbdf7))
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(/** @src 18:3555:3586  "OwnableInvalidOwner(address(0))" */ 4, /** @src 18:3530:3531  "0" */ 0x00)
                    /// @src 18:3555:3586  "OwnableInvalidOwner(address(0))"
                    revert(/** @src 18:3530:3531  "0" */ 0x00, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                }
                let _2 := sload(/** @src 18:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328)
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 18:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328, /** @src 0:7432:7437  "10000" */ or(and(_2, shl(160, 0xffffffffffffffffffffffff)), _1))
                /// @src 18:3996:4036  "OwnershipTransferred(oldOwner, newOwner)"
                log3(/** @src 18:3530:3531  "0" */ 0x00, 0x00, /** @src 18:3996:4036  "OwnershipTransferred(oldOwner, newOwner)" */ 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_2, sub(shl(160, 1), 1)), /** @src 18:3996:4036  "OwnershipTransferred(oldOwner, newOwner)" */ _1)
            }
            /// @ast-id 3520 @src 5:5295:5527  "function _timeToExecuteTimelockedCall()..."
            function fun_timeToExecuteTimelockedCall() -> var
            {
                /// @src 5:5467:5520  "state.executing || state.timelockDurationSeconds == 0"
                let expr := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(sload(/** @src 5:1252:1294  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff)
                /// @src 5:5467:5520  "state.executing || state.timelockDurationSeconds == 0"
                if iszero(expr)
                {
                    expr := /** @src 5:5486:5520  "state.timelockDurationSeconds == 0" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 5:5486:5515  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01))
                }
                /// @src 5:5460:5520  "return state.executing || state.timelockDurationSeconds == 0"
                var := expr
            }
            /// @ast-id 3500 @src 5:4622:5289  "function _recordTimelockedCall(..."
            function fun_recordTimelockedCall(var_encodedCall_length)
            {
                /// @src 5:4743:4775  "State storage state = getState()"
                fun_checkOwner()
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(/** @src 5:4973:4987  "msg.value == 0" */ iszero(/** @src 5:4973:4982  "msg.value" */ callvalue()))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src 5:1493:1501  "msg.data" */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xe8de4489))
                    revert(/** @src 5:1493:1501  "msg.data" */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 5:5051:5074  "keccak256(_encodedCall)"
                let _mpos := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ abi_decode_available_length_bytes(/** @src 5:1493:1501  "msg.data" */ 0, /** @src 5:5051:5074  "keccak256(_encodedCall)" */ var_encodedCall_length, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ calldatasize())
                /// @src 5:5051:5074  "keccak256(_encodedCall)"
                let expr := keccak256(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 5:5051:5074  "keccak256(_encodedCall)" */ _mpos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x20), mload(/** @src 5:5051:5074  "keccak256(_encodedCall)" */ _mpos))
                /// @src 0:7530:7533  "300"
                let sum := add(/** @src 5:5104:5119  "block.timestamp" */ timestamp(), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sload(/** @src 5:5122:5151  "state.timelockDurationSeconds" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d01))
                /// @src 0:7530:7533  "300"
                if gt(/** @src 5:5104:5119  "block.timestamp" */ timestamp(), /** @src 0:7530:7533  "300" */ sum) { panic_error_0x11() }
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(/** @src 5:1493:1501  "msg.data" */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ expr)
                mstore(0x20, /** @src 5:5161:5182  "state.timelockedCalls" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d02)
                /// @src 5:1188:1194  "7 days"
                sstore(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ keccak256(/** @src 5:1493:1501  "msg.data" */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x40), /** @src 5:1188:1194  "7 days" */ sum)
                /// @src 5:5226:5282  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)"
                let _1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(0x40)
                mstore(_1, 96)
                mstore(add(_1, 96), var_encodedCall_length)
                calldatacopy(add(_1, 128), /** @src 5:1493:1501  "msg.data" */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ var_encodedCall_length)
                mstore(add(add(_1, var_encodedCall_length), 128), /** @src 5:1493:1501  "msg.data" */ 0)
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                mstore(add(_1, 0x20), expr)
                mstore(add(_1, 0x40), sum)
                /// @src 5:5226:5282  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)"
                log1(_1, add(sub(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(_1, and(add(var_encodedCall_length, 31), not(31))), /** @src 5:5226:5282  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)" */ _1), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 128), /** @src 5:5226:5282  "CallTimelocked(_encodedCall, encodedCallHash, allowedAt)" */ 0xcfe4e47fb61ab9e86fdf402e71633288356fe9946ea95fd84d6b233736e7caa2)
            }
            /// @ast-id 3448 @src 5:4319:4616  "function _beforeExecuteTimelockedCall()..."
            function fun_beforeExecuteTimelockedCall()
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let _1 := sload(/** @src 5:1252:1294  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00)
                /// @src 5:4448:4610  "if (state.executing) {..."
                switch /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(_1, 0xff)
                case /** @src 5:4448:4610  "if (state.executing) {..." */ 0 { fun_checkOwner() }
                default {
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    if iszero(/** @src 5:4490:4517  "msg.sender == address(this)" */ eq(/** @src 5:4490:4500  "msg.sender" */ caller(), /** @src 5:4512:4516  "this" */ address()))
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    {
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x4e487b71))
                        mstore(4, 0x01)
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0x24)
                    }
                    /// @src 0:7432:7437  "10000"
                    sstore(/** @src 5:1252:1294  "erc7201(\"utils.OwnableWithTimelock.State\")" */ 0xb75c9e90321f4f8434274256cdcb612abd9d79ca93442665e21532b87bfb2d00, /** @src 0:7432:7437  "10000" */ and(_1, not(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 255)))
                }
            }
            /// @ast-id 4038 @src 10:6891:6967  "modifier onlyInitializing() {..."
            function modifier_onlyInitializing(var_initialOwner)
            {
                fun_checkInitializing()
                fun_checkInitializing()
                /// @src 10:6959:6960  "_"
                fun_transferOwnership_inner(var_initialOwner)
            }
            /// @ast-id 3527 @src 5:5533:6010  "function _passReturnOrRevert(..."
            function fun_passReturnOrRevert(var_success)
            {
                /// @src 5:5706:6004  "assembly (\"memory-safe\") {..."
                let usr$size := returndatasize()
                let usr$ptr := mload(0x40)
                mstore(0x40, add(usr$ptr, usr$size))
                returndatacopy(usr$ptr, 0, usr$size)
                if var_success { return(usr$ptr, usr$size) }
                revert(usr$ptr, usr$size)
            }
            /// @ast-id 5217 @src 17:4638:4810  "function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {..."
            function fun_verifyCalldata(var_proof_5200_offset, var_proof_5200_length, var_root, var_leaf) -> var
            {
                /// @src 17:5325:5352  "bytes32 computedHash = leaf"
                let var_computedHash := var_leaf
                /// @src 17:5367:5380  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 17:5362:5496  "for (uint256 i = 0; i < proof.length; i++) {..."
                for { }
                /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1
                /// @src 17:5367:5380  "uint256 i = 0"
                {
                    /// @src 17:5400:5403  "i++"
                    var_i := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ add(/** @src 17:5400:5403  "i++" */ var_i, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 1)
                }
                /// @src 17:5400:5403  "i++"
                {
                    /// @src 17:5382:5398  "i < proof.length"
                    let _1 := iszero(lt(var_i, /** @src 17:5386:5398  "proof.length" */ var_proof_5200_length))
                    /// @src 17:5382:5398  "i < proof.length"
                    if _1 { break }
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    _1 := /** @src -1:-1:-1 */ 0
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    let value := calldataload(add(var_proof_5200_offset, shl(5, var_i)))
                    /// @src 16:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    let expr := /** @src -1:-1:-1 */ 0
                    /// @src 16:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    switch /** @src 16:605:610  "a < b" */ lt(var_computedHash, value)
                    case /** @src 16:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)" */ 0 {
                        /// @src 16:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 16:889:1024  "assembly (\"memory-safe\") {..." */ value)
                        mstore(0x20, var_computedHash)
                        /// @src 16:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 16:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 16:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    default /// @src 16:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    {
                        /// @src 16:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 16:889:1024  "assembly (\"memory-safe\") {..." */ var_computedHash)
                        mstore(0x20, value)
                        /// @src 16:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 16:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 16:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    /// @src 17:5419:5485  "computedHash = Hashes.commutativeKeccak256(computedHash, proof[i])"
                    var_computedHash := expr
                }
                /// @src 17:4755:4803  "return processProofCalldata(proof, leaf) == root"
                var := /** @src 17:4762:4803  "processProofCalldata(proof, leaf) == root" */ eq(var_computedHash, var_root)
            }
            /// @ast-id 2494 @src 0:98234:99657  "function _verifyCustomSignature(..."
            function fun_verifyCustomSignature(var_relayMessage_offset, var_relayMessage_length, var_messageHash) -> var__rewardEpochId
            {
                /// @src 0:98541:98574  "address(this).call(_relayMessage)"
                let _1 := /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(64)
                calldatacopy(_1, var_relayMessage_offset, var_relayMessage_length)
                let _2 := add(_1, var_relayMessage_length)
                mstore(_2, /** @src -1:-1:-1 */ 0)
                /// @src 0:98541:98574  "address(this).call(_relayMessage)"
                let expr_2456_component := call(gas(), /** @src 0:98549:98553  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 0:98541:98574  "address(this).call(_relayMessage)" */ _1, sub(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ _2, /** @src 0:98541:98574  "address(this).call(_relayMessage)" */ _1), /** @src -1:-1:-1 */ 0, 0)
                /// @src 0:98541:98574  "address(this).call(_relayMessage)"
                let expr_component_mpos := extract_returndata()
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                if iszero(expr_2456_component)
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x439cc0cd))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                if iszero(/** @src 0:99175:99198  "returnData.length == 35" */ eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 0:99175:99192  "returnData.length" */ expr_component_mpos), /** @src 0:99196:99198  "35" */ 0x23))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0x801c629f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 0:99355:99540  "assembly {..."
                let var_returnHash := mload(add(expr_component_mpos, 0x20))
                let var_returnRewardEpochId := shr(232, mload(add(expr_component_mpos, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 64)))
                if iszero(/** @src 0:99557:99592  "bytes32(returnHash) == _messageHash" */ eq(var_returnHash, var_messageHash))
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ shl(224, 0xb39d5b51))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 4)
                }
                /// @src 0:99624:99650  "return returnRewardEpochId"
                var__rewardEpochId := var_returnRewardEpochId
            }
            /// @ast-id 6240 @src 18:2679:2841  "function _checkOwner() internal view virtual {..."
            function fun_checkOwner()
            {
                /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                let cleaned := and(sload(/** @src 18:1301:1366  "assembly {..." */ 65173360639460082030725920392146925864023520599682862633725751242436743107328), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 18:2734:2835  "if (owner() != _msgSender()) {..."
                if /** @src 18:2738:2761  "owner() != _msgSender()" */ iszero(eq(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ cleaned, /** @src 19:987:997  "msg.sender" */ caller()))
                /// @src 18:2734:2835  "if (owner() != _msgSender()) {..."
                {
                    /// @src 18:2784:2824  "OwnableUnauthorizedAccount(_msgSender())"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 18:2784:2824  "OwnableUnauthorizedAccount(_msgSender())" */ shl(224, 0x118cdaa7))
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(/** @src 18:2784:2824  "OwnableUnauthorizedAccount(_msgSender())" */ 4, /** @src 19:987:997  "msg.sender" */ caller())
                    /// @src 18:2784:2824  "OwnableUnauthorizedAccount(_msgSender())"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                }
            }
            /// @ast-id 4051 @src 10:7082:7223  "function _checkInitializing() internal view virtual {..."
            function fun_checkInitializing()
            {
                /// @src 10:7144:7217  "if (!_isInitializing()) {..."
                if /** @src 10:7148:7166  "!_isInitializing()" */ iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(shr(64, sload(/** @src 10:3147:3213  "0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00" */ 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00)), /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 0xff))
                /// @src 10:7144:7217  "if (!_isInitializing()) {..."
                {
                    /// @src 10:7189:7206  "NotInitializing()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 10:7189:7206  "NotInitializing()" */ shl(227, 0x1afcd79f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 10:7189:7206  "NotInitializing()" */ 4)
                }
            }
            /// @ast-id 3680 @src 8:2264:2608  "function upgradeToAndCall(address newImplementation, bytes memory data) internal {..."
            function fun_upgradeToAndCall(var_newImplementation, var_data_3649_mpos)
            {
                /// @src 8:1744:1863  "if (newImplementation.code.length == 0) {..."
                if /** @src 8:1748:1782  "newImplementation.code.length == 0" */ iszero(/** @src 8:1748:1777  "newImplementation.code.length" */ extcodesize(var_newImplementation))
                /// @src 8:1744:1863  "if (newImplementation.code.length == 0) {..."
                {
                    /// @src 8:1805:1852  "ERC1967InvalidImplementation(newImplementation)"
                    mstore(/** @src 8:1781:1782  "0" */ 0x00, /** @src 11:6243:6303  "ERC1967Utils.ERC1967InvalidImplementation(newImplementation)" */ shl(224, 0x4c9c8ce3))
                    /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                    mstore(/** @src 8:1805:1852  "ERC1967InvalidImplementation(newImplementation)" */ 4, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(var_newImplementation, sub(shl(160, 1), 1)))
                    /// @src 8:1805:1852  "ERC1967InvalidImplementation(newImplementation)"
                    revert(/** @src 8:1781:1782  "0" */ 0x00, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                }
                let _1 := and(/** @src 0:7432:7437  "10000" */ var_newImplementation, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ sub(shl(160, 1), 1))
                /// @src 0:7432:7437  "10000"
                sstore(/** @src 8:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, /** @src 0:7432:7437  "10000" */ or(and(sload(/** @src 8:811:877  "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc" */ 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc), /** @src 0:7432:7437  "10000" */ shl(160, 0xffffffffffffffffffffffff)), _1))
                /// @src 8:2407:2443  "IERC1967.Upgraded(newImplementation)"
                log2(/** @src 8:1781:1782  "0" */ 0x00, 0x00, /** @src 8:2407:2443  "IERC1967.Upgraded(newImplementation)" */ 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b, _1)
                /// @src 8:2454:2602  "if (data.length > 0) {..."
                switch /** @src 8:2458:2473  "data.length > 0" */ iszero(iszero(/** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ mload(/** @src 8:2458:2469  "data.length" */ var_data_3649_mpos)))
                case /** @src 8:2454:2602  "if (data.length > 0) {..." */ 0 {
                    /// @src 8:6181:6251  "if (msg.value > 0) {..."
                    if /** @src 8:6185:6198  "msg.value > 0" */ iszero(iszero(/** @src 8:6185:6194  "msg.value" */ callvalue()))
                    /// @src 8:6181:6251  "if (msg.value > 0) {..."
                    {
                        /// @src 8:6221:6240  "ERC1967NonPayable()"
                        mstore(/** @src 8:1781:1782  "0" */ 0x00, /** @src 8:6221:6240  "ERC1967NonPayable()" */ shl(224, 0xb398979f))
                        revert(/** @src 8:1781:1782  "0" */ 0x00, /** @src 8:6221:6240  "ERC1967NonPayable()" */ 4)
                    }
                }
                default /// @src 8:2454:2602  "if (data.length > 0) {..."
                {
                    /// @src 8:2489:2542  "Address.functionDelegateCall(newImplementation, data)"
                    pop(fun_functionDelegateCall(var_newImplementation, var_data_3649_mpos))
                }
            }
            /// @ast-id 4609 @src 12:4691:5240  "function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {..."
            function fun_functionDelegateCall(var_target, var_data_mpos) -> var_mpos
            {
                /// @src 12:4874:4946  "success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)"
                let expr := /** @src 14:3526:3655  "assembly (\"memory-safe\") {..." */ delegatecall(gas(), var_target, add(var_data_mpos, 0x20), mload(var_data_mpos), /** @src -1:-1:-1 */ 0, 0)
                /// @src 14:3526:3655  "assembly (\"memory-safe\") {..."
                let var_success := /** @src 12:4874:4946  "success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)" */ expr
                if expr
                {
                    /// @src 12:4886:4919  "LowLevelCall.returnDataSize() > 0"
                    let _1 := iszero(/** @src 14:4578:4651  "assembly (\"memory-safe\") {..." */ returndatasize())
                    /// @src 12:4886:4945  "LowLevelCall.returnDataSize() > 0 || target.code.length > 0"
                    let expr_1 := /** @src 12:4886:4919  "LowLevelCall.returnDataSize() > 0" */ iszero(_1)
                    /// @src 12:4886:4945  "LowLevelCall.returnDataSize() > 0 || target.code.length > 0"
                    if _1
                    {
                        expr_1 := /** @src 12:4923:4945  "target.code.length > 0" */ iszero(iszero(/** @src 12:4923:4941  "target.code.length" */ extcodesize(var_target)))
                    }
                    /// @src 12:4874:4946  "success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)"
                    expr := expr_1
                }
                /// @src 12:4870:5234  "if (success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)) {..."
                switch expr
                case 0 {
                    /// @src 12:5011:5234  "if (success) {..."
                    switch var_success
                    case 0 {
                        /// @src 12:5086:5234  "if (LowLevelCall.returnDataSize() > 0) {..."
                        switch /** @src 12:5090:5123  "LowLevelCall.returnDataSize() > 0" */ iszero(iszero(/** @src 14:4578:4651  "assembly (\"memory-safe\") {..." */ returndatasize()))
                        case /** @src 12:5086:5234  "if (LowLevelCall.returnDataSize() > 0) {..." */ 0 {
                            /// @src 12:5204:5223  "Errors.FailedCall()"
                            mstore(/** @src -1:-1:-1 */ 0, /** @src 12:5204:5223  "Errors.FailedCall()" */ shl(224, 0xd6bda275))
                            revert(/** @src -1:-1:-1 */ 0, /** @src 12:5204:5223  "Errors.FailedCall()" */ 4)
                        }
                        default /// @src 12:5086:5234  "if (LowLevelCall.returnDataSize() > 0) {..."
                        {
                            /// @src 12:5139:5151  "LowLevelCall"
                            revert_forward()
                        }
                    }
                    default /// @src 12:5011:5234  "if (success) {..."
                    {
                        /// @src 12:5045:5069  "AddressEmptyCode(target)"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 12:5045:5069  "AddressEmptyCode(target)" */ shl(224, 0x9996b315))
                        /// @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..."
                        mstore(/** @src 12:5045:5069  "AddressEmptyCode(target)" */ 4, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ and(var_target, sub(shl(160, 1), 1)))
                        /// @src 12:5045:5069  "AddressEmptyCode(target)"
                        revert(/** @src -1:-1:-1 */ 0, /** @src 0:983:99659  "contract Relay is IIRelay, OwnableWithTimelock, UUPSUpgradeable {..." */ 36)
                    }
                }
                default /// @src 12:4870:5234  "if (success && (LowLevelCall.returnDataSize() > 0 || target.code.length > 0)) {..."
                {
                    /// @src 12:4962:4994  "return LowLevelCall.returnData()"
                    var_mpos := /** @src 12:4969:4994  "LowLevelCall.returnData()" */ fun_returnData()
                    /// @src 12:4962:4994  "return LowLevelCall.returnData()"
                    leave
                }
            }
            /// @ast-id 4866 @src 14:4740:5074  "function returnData() internal pure returns (bytes memory result) {..."
            function fun_returnData() -> var_result_mpos
            {
                /// @src 14:4816:5068  "assembly (\"memory-safe\") {..."
                var_result_mpos := mload(0x40)
                mstore(var_result_mpos, returndatasize())
                returndatacopy(add(var_result_mpos, 0x20), 0x00, returndatasize())
                mstore(0x40, add(add(var_result_mpos, returndatasize()), 0x20))
            }
        }
        data ".metadata" hex"a26469706673582212202a786c6168a498114c515191bcb568fab4c17b49576660186deaa337a504f2d164736f6c63430008230033"
    }
}
