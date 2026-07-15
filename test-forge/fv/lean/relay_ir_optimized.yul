/// @use-src 0:"contracts/protocol/implementation/Relay.sol", 1:"contracts/protocol/interface/IIRelay.sol", 2:"contracts/userInterfaces/IRelay.sol", 3:"contracts/userInterfaces/LTS/RandomNumberV2Interface.sol"
object "Relay_2011" {
    code {
        {
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let _1 := memoryguard(0xe0)
            mstore(64, _1)
            if callvalue() { revert(0, 0) }
            let programSize := datasize("Relay_2011")
            let argSize := sub(codesize(), programSize)
            finalize_allocation(_1, argSize)
            codecopy(_1, programSize, argSize)
            let _2 := add(_1, argSize)
            if slt(sub(_2, _1), 96)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let offset := mload(_1)
            if gt(offset, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let _3 := add(_1, offset)
            if slt(sub(_2, _3), 0x0180)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let memPtr := mload(64)
            let newFreePtr := add(memPtr, 0x0180)
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x24)
            }
            mstore(64, newFreePtr)
            mstore(memPtr, abi_decode_uint32_fromMemory(_3))
            let _4 := abi_decode_uint32_fromMemory(add(_3, 32))
            let _5 := add(memPtr, 32)
            mstore(_5, _4)
            let value := mload(add(_3, 64))
            let _6 := add(memPtr, 64)
            mstore(_6, value)
            let _7 := abi_decode_uint8_fromMemory(add(_3, 96))
            let _8 := add(memPtr, 96)
            mstore(_8, _7)
            let _9 := abi_decode_uint32_fromMemory(add(_3, 128))
            let _10 := add(memPtr, 128)
            mstore(_10, _9)
            let _11 := abi_decode_uint8_fromMemory(add(_3, 160))
            let _12 := add(memPtr, 160)
            mstore(_12, _11)
            let _13 := abi_decode_uint32_fromMemory(add(_3, 192))
            let _14 := add(memPtr, 192)
            mstore(_14, _13)
            let _15 := abi_decode_uint16_fromMemory(add(_3, 224))
            let _16 := add(memPtr, 224)
            mstore(_16, _15)
            let _17 := abi_decode_uint16_fromMemory(add(_3, 256))
            let _18 := add(memPtr, 256)
            mstore(_18, _17)
            let _19 := abi_decode_uint32_fromMemory(add(_3, 288))
            let _20 := add(memPtr, 288)
            mstore(_20, _19)
            let value_1 := mload(add(_3, 320))
            if iszero(eq(value_1, and(value_1, sub(shl(160, 1), 1))))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let _21 := add(memPtr, 320)
            mstore(_21, value_1)
            let offset_1 := mload(add(_3, 352))
            if gt(offset_1, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let _22 := add(_3, offset_1)
            if iszero(slt(add(_22, 31), _2))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let length := mload(_22)
            if gt(length, sub(shl(64, 1), 1))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x24)
            }
            let memPtr_1 := mload(64)
            finalize_allocation(memPtr_1, add(shl(5, length), 32))
            let dst := memPtr_1
            mstore(memPtr_1, length)
            dst := add(memPtr_1, 32)
            let srcEnd := add(add(_22, shl(6, length)), 32)
            if gt(srcEnd, _2)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let src := add(_22, 32)
            for { } lt(src, srcEnd) { src := add(src, 64) }
            {
                if slt(sub(_2, src), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let memPtr_2 := mload(64)
                let newFreePtr_1 := add(memPtr_2, 64)
                if or(gt(newFreePtr_1, sub(shl(64, 1), 1)), lt(newFreePtr_1, memPtr_2))
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x24)
                }
                mstore(64, newFreePtr_1)
                mstore(memPtr_2, abi_decode_uint8_fromMemory(src))
                mstore(add(memPtr_2, 32), mload(add(src, 32)))
                mstore(dst, memPtr_2)
                dst := add(dst, 32)
            }
            let _23 := add(memPtr, 352)
            mstore(_23, memPtr_1)
            let value1 := abi_decode_address_fromMemory(add(_1, 32))
            let value_2 := mload(add(_1, 64))
            let _24 := and(value_2, sub(shl(160, 1), 1))
            if iszero(eq(value_2, _24))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:2387:2392  "10000"
            if /** @src 0:10504:10558  "_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS" */ lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(mload(/** @src 0:10504:10540  "_initialConfig.thresholdIncreaseBIPS" */ _18), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffff), /** @src 0:2387:2392  "10000" */ 0x2710)
            {
                let memPtr_3 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_3, shl(229, 4594637))
                mstore(add(memPtr_3, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_3, 36), 28)
                mstore(add(memPtr_3, 68), "threshold increase too small")
                revert(memPtr_3, 100)
            }
            if /** @src 0:10711:10763  "_initialConfig.rewardEpochDurationInVotingEpochs > 0" */ iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(mload(/** @src 0:10711:10759  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _16), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffff))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_4 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_4, shl(229, 4594637))
                mstore(add(memPtr_4, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_4, 36), 26)
                mstore(add(memPtr_4, 68), "reward epoch duration zero")
                revert(memPtr_4, 100)
            }
            if /** @src 0:10812:10857  "_initialConfig.votingEpochDurationSeconds > 0" */ iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:10812:10853  "_initialConfig.votingEpochDurationSeconds" */ _12), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_5 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_5, shl(229, 4594637))
                mstore(add(memPtr_5, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_5, 36), 26)
                mstore(add(memPtr_5, 68), "voting epoch duration zero")
                revert(memPtr_5, 100)
            }
            if /** @src 0:11019:11072  "_initialConfig.initialSigningPolicyHash != bytes32(0)" */ iszero(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11019:11058  "_initialConfig.initialSigningPolicyHash" */ _6))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_6 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_6, shl(229, 4594637))
                mstore(add(memPtr_6, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_6, 36), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_6, 68), "initial signing policy hash zero")
                revert(memPtr_6, 100)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let cleaned := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11140:11189  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _14), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
            let cleaned_1 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11204:11239  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            let product_raw := mul(cleaned_1, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(mload(/** @src 0:11242:11290  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _16), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffff))
            /// @src 0:2387:2392  "10000"
            let product := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ product_raw, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            if iszero(eq(product, product_raw))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                /// @src 0:2387:2392  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ 0x24)
            }
            let sum := add(cleaned, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ product)
            /// @src 0:2387:2392  "10000"
            if gt(sum, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                /// @src 0:2387:2392  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ 0x24)
            }
            if /** @src 0:11140:11365  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:11140:11365  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ sum, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff), and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11306:11365  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _5), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_7 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_7, shl(229, 4594637))
                mstore(add(memPtr_7, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_7, 36), 40)
                mstore(add(memPtr_7, 68), "invalid initial starting voting ")
                mstore(add(memPtr_7, 100), "round id")
                revert(memPtr_7, 132)
            }
            /// @src 0:11441:11499  "initialRewardEpochId = _initialConfig.initialRewardEpochId"
            mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 160, and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11464:11499  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:11509:11627  "startingVotingRoundIdForInitialRewardEpochId =..."
            mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 192, and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11568:11627  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _5), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
            let _25 := and(/** @src 0:2387:2392  "10000" */ value1, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:11637:11679  "signingPolicySetter = _signingPolicySetter" */ 0x03, /** @src 0:2387:2392  "10000" */ or(and(sload(/** @src 0:11637:11679  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 0:2387:2392  "10000" */ not(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))), /** @src 0:2387:2392  "10000" */ _25))
            let _26 := mload(/** @src 0:12170:12205  "_initialConfig.initialRewardEpochId" */ memPtr)
            /// @src 0:2387:2392  "10000"
            let _27 := sload(/** @src 0:12131:12140  "stateData" */ 0x07)
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:12131:12140  "stateData" */ 0x07, /** @src 0:2387:2392  "10000" */ or(and(_27, not(shl(152, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:2387:2392  "10000" */ and(shl(152, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ _26), /** @src 0:2387:2392  "10000" */ shl(152, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))))
            let cleaned_2 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12289:12348  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _5), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(_26, 0xffffffff))
            /// @src 0:2387:2392  "10000"
            mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32, /** @src 0:12215:12237  "startingVotingRoundIds" */ 0x02)
            /// @src 0:2387:2392  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64), /** @src 0:2387:2392  "10000" */ cleaned_2)
            let _28 := mload(/** @src 0:12424:12463  "_initialConfig.initialSigningPolicyHash" */ _6)
            /// @src 0:2387:2392  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12385:12420  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:2387:2392  "10000"
            mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32, /** @src -1:-1:-1 */ 0)
            /// @src 0:2387:2392  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64), /** @src 0:2387:2392  "10000" */ _28)
            if iszero(/** @src 0:12481:12522  "_initialConfig.randomNumberProtocolId > 1" */ gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12481:12518  "_initialConfig.randomNumberProtocolId" */ _8), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff), 1))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_8 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_8, shl(229, 4594637))
                mstore(add(memPtr_8, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_8, 36), 37)
                mstore(add(memPtr_8, 68), "random number protocol id must b")
                mstore(add(memPtr_8, 100), "e > 1")
                revert(memPtr_8, 132)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let cleaned_3 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12609:12646  "_initialConfig.randomNumberProtocolId" */ _8), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff)
            /// @src 0:2387:2392  "10000"
            let _29 := sload(/** @src 0:12131:12140  "stateData" */ 0x07)
            /// @src 0:2387:2392  "10000"
            let toInsert := and(shl(8, mload(/** @src 0:12692:12730  "_initialConfig.firstVotingRoundStartTs" */ _10)), /** @src 0:2387:2392  "10000" */ 0xffffffff00)
            let toInsert_1 := and(shl(40, mload(/** @src 0:12779:12820  "_initialConfig.votingEpochDurationSeconds" */ _12)), /** @src 0:2387:2392  "10000" */ 0xff0000000000)
            let toInsert_2 := and(shl(48, mload(/** @src 0:12877:12926  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _14)), /** @src 0:2387:2392  "10000" */ 0xffffffff000000000000)
            let toInsert_3 := and(shl(80, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:12982:13030  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _16)), /** @src 0:2387:2392  "10000" */ 0xffff00000000000000000000)
            let toInsert_4 := and(shl(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 96, mload(/** @src 0:13074:13110  "_initialConfig.thresholdIncreaseBIPS" */ _18)), /** @src 0:2387:2392  "10000" */ 0xffff000000000000000000000000)
            let toInsert_5 := and(shl(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 192, /** @src 0:2387:2392  "10000" */ mload(/** @src 0:13172:13226  "_initialConfig.messageFinalizationWindowInRewardEpochs" */ _20)), /** @src 0:2387:2392  "10000" */ shl(192, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:2387:2392  "10000"
            let _30 := or(toInsert_3, and(or(toInsert_2, and(or(toInsert_1, and(or(toInsert, and(or(and(_29, not(0xffffffffffff)), cleaned_3), not(0xffffffff000000000000))), not(0xffff00000000000000000000))), not(0xffff000000000000000000000000))), not(shl(192, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))))
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:12131:12140  "stateData" */ 0x07, /** @src 0:2387:2392  "10000" */ or(or(toInsert_4, _30), toInsert_5))
            /// @src 0:13240:13274  "_signingPolicySetter != address(0)"
            let _31 := iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _25)
            /// @src 0:13240:13274  "_signingPolicySetter != address(0)"
            let expr := iszero(_31)
            /// @src 0:13236:13419  "if (_signingPolicySetter != address(0)) {..."
            if expr
            {
                /// @src 0:2387:2392  "10000"
                if iszero(/** @src 0:13298:13335  "_initialConfig.feeConfigs.length == 0" */ iszero(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:13298:13323  "_initialConfig.feeConfigs" */ mload(_23))))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_9 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_9, shl(229, 4594637))
                    mstore(add(memPtr_9, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_9, 36), 17)
                    mstore(add(memPtr_9, 68), "fee cannot be set")
                    revert(memPtr_9, 100)
                }
                sstore(/** @src 0:12131:12140  "stateData" */ 0x07, /** @src 0:2387:2392  "10000" */ or(or(toInsert_5, or(toInsert_4, and(_30, not(shl(184, 255))))), shl(184, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 1)))
            }
            let cleaned_4 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:13451:13486  "_initialConfig.feeCollectionAddress" */ _21), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 5, /** @src 0:2387:2392  "10000" */ or(and(sload(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 5), /** @src 0:2387:2392  "10000" */ not(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))), /** @src 0:2387:2392  "10000" */ cleaned_4))
            /// @src 0:13722:13809  "_signingPolicySetter != address(0) || _initialConfig.feeCollectionAddress != address(0)"
            let expr_1 := expr
            if _31
            {
                expr_1 := /** @src 0:13760:13809  "_initialConfig.feeCollectionAddress != address(0)" */ iszero(iszero(cleaned_4))
            }
            /// @src 0:2387:2392  "10000"
            if iszero(expr_1)
            {
                let memPtr_10 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_10, shl(229, 4594637))
                mstore(add(memPtr_10, 4), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_10, 36), 27)
                mstore(add(memPtr_10, 68), "fee collection address zero")
                revert(memPtr_10, 100)
            }
            /// @src 0:13877:13890  "uint256 i = 0"
            let var_i := /** @src -1:-1:-1 */ 0
            /// @src 0:13872:14160  "for (uint256 i = 0; i < _initialConfig.feeConfigs.length; i++) {..."
            for { }
            /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 1
            /// @src 0:13877:13890  "uint256 i = 0"
            {
                /// @src 0:13930:13933  "i++"
                var_i := /** @src 0:2387:2392  "10000" */ add(/** @src 0:13930:13933  "i++" */ var_i, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 1)
            }
            /// @src 0:13930:13933  "i++"
            {
                /// @src 0:13896:13921  "_initialConfig.feeConfigs"
                let _mpos := mload(_23)
                /// @src 0:13892:13928  "i < _initialConfig.feeConfigs.length"
                if iszero(lt(var_i, /** @src 0:2387:2392  "10000" */ mload(/** @src 0:13896:13928  "_initialConfig.feeConfigs.length" */ _mpos)))
                /// @src 0:13892:13928  "i < _initialConfig.feeConfigs.length"
                { break }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let cleaned_5 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:13968:13996  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(_mpos, var_i))), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff)
                /// @src 0:2387:2392  "10000"
                if iszero(/** @src 0:14029:14043  "protocolId > 1" */ gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ cleaned_5, 1))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_11 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_11, shl(229, 4594637))
                    mstore(add(memPtr_11, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_11, 36), 19)
                    mstore(add(memPtr_11, 68), "invalid protocol id")
                    revert(memPtr_11, 100)
                }
                let _32 := mload(/** @src 0:14112:14149  "_initialConfig.feeConfigs[i].feeInWei" */ add(/** @src 0:14112:14140  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(/** @src 0:14112:14137  "_initialConfig.feeConfigs" */ mload(_23), /** @src 0:14112:14140  "_initialConfig.feeConfigs[i]" */ var_i)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32))
                /// @src 0:2387:2392  "10000"
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ cleaned_5)
                mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04)
                /// @src 0:2387:2392  "10000"
                sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64), /** @src 0:2387:2392  "10000" */ _32)
            }
            /// @src 0:14169:14189  "oldRelay = _oldRelay"
            mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 128, /** @src 0:14169:14189  "oldRelay = _oldRelay" */ value_2)
            /// @src 0:14280:15593  "if(oldRelay != IIRelay(address(0))) {..."
            if /** @src 0:14283:14314  "oldRelay != IIRelay(address(0))" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _24))
            /// @src 0:14280:15593  "if(oldRelay != IIRelay(address(0))) {..."
            {
                /// @src 0:14356:14389  "signingPolicySetter != address(0)"
                let _33 := iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ sload(/** @src 0:11637:11679  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
                /// @src 0:14356:14437  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                let expr_2 := /** @src 0:14356:14389  "signingPolicySetter != address(0)" */ iszero(_33)
                /// @src 0:14356:14437  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                if expr_2
                {
                    /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                    let _34 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                    mstore(_34, /** @src 0:2387:2392  "10000" */ shl(224, 0xa9dbe8ed))
                    /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                    let _35 := staticcall(gas(), _24, _34, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04, /** @src 0:14393:14423  "oldRelay.signingPolicySetter()" */ _34, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                    if iszero(_35)
                    {
                        /// @src 0:2387:2392  "10000"
                        let pos := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                        /// @src 0:2387:2392  "10000"
                        returndatacopy(pos, /** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ returndatasize())
                        revert(pos, returndatasize())
                    }
                    /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                    let expr_3 := /** @src -1:-1:-1 */ 0
                    /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                    if _35
                    {
                        let _36 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32
                        /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                        if gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32, /** @src 0:14393:14423  "oldRelay.signingPolicySetter()" */ returndatasize()) { _36 := returndatasize() }
                        finalize_allocation(_34, _36)
                        /// @src 0:2387:2392  "10000"
                        if slt(sub(/** @src 0:14393:14423  "oldRelay.signingPolicySetter()" */ add(_34, _36), /** @src 0:2387:2392  "10000" */ _34), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                        /// @src 0:2387:2392  "10000"
                        {
                            /// @src 0:397:82971  "contract Relay is IIRelay {..."
                            revert(/** @src -1:-1:-1 */ 0, 0)
                        }
                        /// @src 0:14393:14423  "oldRelay.signingPolicySetter()"
                        expr_3 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ abi_decode_address_fromMemory(/** @src 0:2387:2392  "10000" */ _34)
                    }
                    /// @src 0:14356:14437  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                    expr_2 := /** @src 0:14393:14437  "oldRelay.signingPolicySetter() != address(0)" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:14393:14437  "oldRelay.signingPolicySetter() != address(0)" */ expr_3, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))))
                }
                /// @src 0:14355:14541  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                let expr_4 := expr_2
                if iszero(expr_2)
                {
                    /// @src 0:14459:14540  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                    let expr_5 := _33
                    if _33
                    {
                        /// @src 0:397:82971  "contract Relay is IIRelay {..."
                        let cleaned_6 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 128), sub(shl(160, 1), 1))
                        /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                        let _37 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                        /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                        mstore(_37, /** @src 0:2387:2392  "10000" */ shl(224, 0xa9dbe8ed))
                        /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                        let _38 := staticcall(gas(), cleaned_6, _37, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04, /** @src 0:14496:14526  "oldRelay.signingPolicySetter()" */ _37, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                        /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                        if iszero(_38)
                        {
                            /// @src 0:2387:2392  "10000"
                            let pos_1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                            /// @src 0:2387:2392  "10000"
                            returndatacopy(pos_1, /** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ returndatasize())
                            revert(pos_1, returndatasize())
                        }
                        /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                        let expr_6 := /** @src -1:-1:-1 */ 0
                        /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                        if _38
                        {
                            let _39 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32
                            /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                            if gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32, /** @src 0:14496:14526  "oldRelay.signingPolicySetter()" */ returndatasize()) { _39 := returndatasize() }
                            finalize_allocation(_37, _39)
                            /// @src 0:2387:2392  "10000"
                            if slt(sub(/** @src 0:14496:14526  "oldRelay.signingPolicySetter()" */ add(_37, _39), /** @src 0:2387:2392  "10000" */ _37), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                            /// @src 0:2387:2392  "10000"
                            {
                                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                                revert(/** @src -1:-1:-1 */ 0, 0)
                            }
                            /// @src 0:14496:14526  "oldRelay.signingPolicySetter()"
                            expr_6 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ abi_decode_address_fromMemory(/** @src 0:2387:2392  "10000" */ _37)
                        }
                        /// @src 0:14459:14540  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                        expr_5 := /** @src 0:14496:14540  "oldRelay.signingPolicySetter() == address(0)" */ iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:14496:14540  "oldRelay.signingPolicySetter() == address(0)" */ expr_6, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
                    }
                    /// @src 0:14355:14541  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                    expr_4 := expr_5
                }
                /// @src 0:2387:2392  "10000"
                if iszero(expr_4)
                {
                    let memPtr_12 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_12, shl(229, 4594637))
                    mstore(add(memPtr_12, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_12, 36), 22)
                    mstore(add(memPtr_12, 68), "old relay incompatible")
                    revert(memPtr_12, 100)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let cleaned_7 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 128), sub(shl(160, 1), 1))
                /// @src 0:14884:14904  "oldRelay.stateData()"
                let _40 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:14884:14904  "oldRelay.stateData()"
                mstore(_40, /** @src 0:2387:2392  "10000" */ shl(225, 0x0f47d9b5))
                /// @src 0:14884:14904  "oldRelay.stateData()"
                let _41 := staticcall(gas(), cleaned_7, _40, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04, /** @src 0:14884:14904  "oldRelay.stateData()" */ _40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 352)
                /// @src 0:14884:14904  "oldRelay.stateData()"
                if iszero(_41)
                {
                    /// @src 0:2387:2392  "10000"
                    let pos_2 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    returndatacopy(pos_2, /** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ returndatasize())
                    revert(pos_2, returndatasize())
                }
                let expr_component := /** @src -1:-1:-1 */ 0
                let expr_component_1 := 0
                let expr_component_2 := 0
                let expr_component_3 := 0
                /// @src 0:14884:14904  "oldRelay.stateData()"
                if _41
                {
                    let _42 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 352
                    /// @src 0:14884:14904  "oldRelay.stateData()"
                    if gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _42, /** @src 0:14884:14904  "oldRelay.stateData()" */ returndatasize()) { _42 := returndatasize() }
                    finalize_allocation(_40, _42)
                    /// @src 0:2387:2392  "10000"
                    if slt(sub(/** @src 0:14884:14904  "oldRelay.stateData()" */ add(_40, _42), /** @src 0:2387:2392  "10000" */ _40), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 352)
                    /// @src 0:2387:2392  "10000"
                    {
                        /// @src 0:397:82971  "contract Relay is IIRelay {..."
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    pop(abi_decode_uint8_fromMemory(/** @src 0:2387:2392  "10000" */ _40))
                    let value1_1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32))
                    /// @src 0:2387:2392  "10000"
                    let value2 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ abi_decode_uint8_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64))
                    /// @src 0:2387:2392  "10000"
                    let value3 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 96))
                    /// @src 0:2387:2392  "10000"
                    let value4 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ abi_decode_uint16_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 128))
                    pop(abi_decode_uint16_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 160)))
                    pop(abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 192)))
                    /// @src 0:2387:2392  "10000"
                    pop(abi_decode_bool_fromMemory(add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 224)))
                    pop(abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 256)))
                    /// @src 0:2387:2392  "10000"
                    pop(abi_decode_bool_fromMemory(add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 288)))
                    pop(abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 320)))
                    /// @src 0:14884:14904  "oldRelay.stateData()"
                    expr_component := value1_1
                    expr_component_1 := value2
                    expr_component_2 := value3
                    expr_component_3 := value4
                }
                /// @src 0:2387:2392  "10000"
                let _43 := sload(/** @src 0:12131:12140  "stateData" */ 0x07)
                /// @src 0:2387:2392  "10000"
                if iszero(/** @src 0:14943:15003  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ eq(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(8, _43), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff), and(/** @src 0:14943:15003  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ expr_component, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_13 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_13, shl(229, 4594637))
                    mstore(add(memPtr_13, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_13, 36), 14)
                    mstore(add(memPtr_13, 68), "wrong start ts")
                    revert(memPtr_13, 100)
                }
                if iszero(/** @src 0:15090:15170  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ eq(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(80, _43), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffff), and(/** @src 0:15090:15170  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ expr_component_3, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_14 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_14, shl(229, 4594637))
                    mstore(add(memPtr_14, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_14, 36), 27)
                    mstore(add(memPtr_14, 68), "wrong reward epoch duration")
                    revert(memPtr_14, 100)
                }
                if iszero(/** @src 0:15270:15352  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ eq(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(48, _43), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff), and(/** @src 0:15270:15352  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ expr_component_2, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_15 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_15, shl(229, 4594637))
                    mstore(add(memPtr_15, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_15, 36), 30)
                    mstore(add(memPtr_15, 68), "wrong first reward epoch start")
                    revert(memPtr_15, 100)
                }
                if iszero(/** @src 0:15455:15521  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ eq(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(40, _43), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff), and(/** @src 0:15455:15521  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ expr_component_1, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_16 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_16, shl(229, 4594637))
                    mstore(add(memPtr_16, /** @src 0:14081:14097  "protocolFeeInWei" */ 0x04), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_16, 36), 27)
                    mstore(add(memPtr_16, 68), "wrong voting epoch duration")
                    revert(memPtr_16, 100)
                }
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            let _44 := mload(64)
            let _45 := datasize("Relay_2011_deployed")
            codecopy(_44, dataoffset("Relay_2011_deployed"), _45)
            setimmutable(_44, "332", mload(128))
            setimmutable(_44, "335", mload(160))
            setimmutable(_44, "338", mload(192))
            return(_44, _45)
        }
        function finalize_allocation(memPtr, size)
        {
            let newFreePtr := add(memPtr, and(add(size, 31), not(31)))
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x24)
            }
            mstore(64, newFreePtr)
        }
        function abi_decode_uint32_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, and(value, 0xffffffff))) { revert(0, 0) }
        }
        function abi_decode_uint8_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, and(value, 0xff))) { revert(0, 0) }
        }
        function abi_decode_uint16_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, and(value, 0xffff))) { revert(0, 0) }
        }
        function abi_decode_address_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, and(value, sub(shl(160, 1), 1)))) { revert(0, 0) }
        }
        /// @src 0:2387:2392  "10000"
        function memory_array_index_access_struct_FeeConfig_dyn(baseRef, index) -> addr
        {
            if iszero(lt(index, mload(baseRef)))
            {
                mstore(0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                /// @src 0:2387:2392  "10000"
                mstore(4, 0x32)
                revert(0, 0x24)
            }
            addr := add(add(baseRef, shl(5, index)), 32)
        }
        function abi_decode_bool_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, iszero(iszero(value)))) { revert(0, 0) }
        }
    }
    /// @use-src 0:"contracts/protocol/implementation/Relay.sol", 4:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/Hashes.sol", 5:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/MerkleProof.sol"
    object "Relay_2011_deployed" {
        code {
            {
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                mstore(64, 128)
                if iszero(lt(calldatasize(), 4))
                {
                    switch shr(224, calldataload(0))
                    case 0x0c85bf07 {
                        external_fun_toSigningPolicyHash()
                    }
                    case 0x1e8fb36a { external_fun_stateData() }
                    case 0x317ad33c { external_fun_isFinalized() }
                    case 0x377c50d4 {
                        external_fun_feeCollectionAddress()
                    }
                    case 0x39436b00 { external_fun_merkleRoots() }
                    case 0x47e1818b {
                        external_fun_startingVotingRoundIdForInitialRewardEpochId()
                    }
                    case 0x609f87f0 {
                        external_fun_governanceFeeNonce()
                    }
                    case 0x6217b101 {
                        external_fun_governanceFeeSetup()
                    }
                    case 0x686a5e5d {
                        external_fun_initialRewardEpochId()
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
                    case 0xb59589d1 { external_fun_relay() }
                    case 0xdbdff2c1 {
                        external_fun_getRandomNumber()
                    }
                    case 0xffc1f8ef { external_fun_oldRelay() }
                }
                revert(0, 0)
            }
            function abi_decode_uint256_15035() -> value
            { value := calldataload(4) }
            function abi_decode_uint256() -> value
            { value := calldataload(36) }
            function abi_encode_bytes32(headStart, value0) -> tail
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(4)
                let ret := fun_toSigningPolicyHash(value)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function extract_from_storage_value_offsett_uint8(slot_value) -> value
            {
                value := and(slot_value, 0xff)
            }
            function cleanup_from_storage_uint32(value) -> cleaned
            {
                cleaned := and(value, 0xffffffff)
            }
            function extract_from_storage_value_offset_1t_uint32(slot_value) -> value
            {
                value := and(shr(8, slot_value), 0xffffffff)
            }
            function extract_from_storage_value_offset_5t_uint8(slot_value) -> value
            {
                value := and(shr(40, slot_value), 0xff)
            }
            function cleanup_from_storage_uint16(value) -> cleaned
            { cleaned := and(value, 0xffff) }
            function extract_from_storage_value_offsett_uint32(slot_value) -> value
            {
                value := and(shr(152, slot_value), 0xffffffff)
            }
            function extract_from_storage_value_offsett_bool(slot_value) -> value
            {
                value := and(shr(184, slot_value), 0xff)
            }
            function extract_from_storage_value_offset_24t_uint32(slot_value) -> value
            {
                value := and(shr(192, slot_value), 0xffffffff)
            }
            function abi_encode_uint32(value, pos)
            {
                mstore(pos, and(value, 0xffffffff))
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
                let _1 := sload(/** @src 0:9226:9252  "StateData public stateData" */ 7)
                let ret := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_bool(_1)
                /// @src 0:9226:9252  "StateData public stateData"
                let ret_1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_24t_uint32(_1)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint8_uint32_uint8_uint32_uint16_uint16_uint32_bool_uint32_bool_uint32(memPos, and(_1, 0xff), and(shr(8, _1), 0xffffffff), and(shr(40, _1), 0xff), and(shr(48, _1), 0xffffffff), and(shr(80, _1), 0xffff), and(shr(96, _1), 0xffff), and(shr(112, _1), 0xffffffff), and(shr(144, _1), 0xff), and(shr(152, _1), 0xffffffff), ret, ret_1), memPos))
            }
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
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
            function abi_encode_address_payable(value, pos)
            {
                mstore(pos, and(value, sub(shl(160, 1), 1)))
            }
            function external_fun_feeCollectionAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:8782:8825  "address payable public feeCollectionAddress" */ 5), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value)
                return(memPos, 32)
            }
            function external_fun_merkleRoots()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value_1 := calldataload(36)
                let ret := fun_merkleRoots(value, value_1)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function external_fun_startingVotingRoundIdForInitialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 0:9819:9887  "uint32 public immutable startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function external_fun_governanceFeeNonce()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:9356:9389  "uint256 public governanceFeeNonce" */ 8)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function abi_decode_bytes_calldata(offset, end) -> arrayPos, length
            {
                if iszero(slt(add(offset, 0x1f), end)) { revert(0, 0) }
                length := calldataload(offset)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                arrayPos := add(offset, 0x20)
                if gt(add(add(offset, length), 0x20), end) { revert(0, 0) }
            }
            function external_fun_governanceFeeSetup()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value0, value1 := abi_decode_bytes_calldata(add(4, offset), calldatasize())
                let offset_1 := calldataload(36)
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let _1 := add(4, offset_1)
                if slt(add(sub(calldatasize(), offset_1), not(3)), 128)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:22515:22578  "require(signingPolicySetter == address(0), \"fee cannot be set\")"
                require_helper_stringliteral_59e4(/** @src 0:22523:22556  "signingPolicySetter == address(0)" */ iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(cleanup_address_payable(sload(/** @src 0:22523:22542  "signingPolicySetter" */ 0x03)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))))
                /// @src 0:22596:22611  "_config.chainId"
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(/** @src 0:22596:22611  "_config.chainId" */ add(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ offset_1, 36))
                /// @src 0:22588:22647  "require(_config.chainId == block.chainid, \"wrong chain id\")"
                require_helper_stringliteral_0424(/** @src 0:22596:22628  "_config.chainId == block.chainid" */ eq(value, /** @src 0:22615:22628  "block.chainid" */ chainid()))
                /// @src 0:22665:22688  "_config.descriptionHash"
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value_1 := calldataload(_1)
                /// @src 0:22657:22747  "require(_config.descriptionHash == keccak256(\"RelayGovernance\"), \"wrong description hash\")"
                require_helper_stringliteral_88b2(/** @src 0:22665:22720  "_config.descriptionHash == keccak256(\"RelayGovernance\")" */ eq(value_1, /** @src 0:22692:22720  "keccak256(\"RelayGovernance\")" */ 0xba90a7502e1d792c42ae7da5cf5982d831ebf2254fd5919818faf046187d95d2))
                /// @src 0:23022:23056  "abi.encode(_config, address(this))"
                let expr_mpos := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:23022:23056  "abi.encode(_config, address(this))"
                let _2 := add(expr_mpos, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:23022:23056  "abi.encode(_config, address(this))"
                let _3 := sub(abi_encode_struct_RelayGovernanceConfig_calldata_address(_2, _1, /** @src 0:23050:23054  "this" */ address()), /** @src 0:23022:23056  "abi.encode(_config, address(this))" */ expr_mpos)
                mstore(expr_mpos, add(_3, not(31)))
                finalize_allocation(expr_mpos, _3)
                /// @src 0:22974:23058  "_verifyCustomSignature(_relayMessage, keccak256(abi.encode(_config, address(this))))"
                let expr := fun_verifyCustomSignature(value0, value1, /** @src 0:23012:23057  "keccak256(abi.encode(_config, address(this)))" */ keccak256(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _2, mload(/** @src 0:23012:23057  "keccak256(abi.encode(_config, address(this)))" */ expr_mpos)))
                /// @src 0:23356:23392  "stateData.lastInitializedRewardEpoch"
                let _4 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_uint32(sload(/** @src 0:23356:23365  "stateData" */ 0x07))
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let _5 := and(/** @src 0:23356:23415  "stateData.lastInitializedRewardEpoch == returnRewardEpochId" */ _4, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
                /// @src 0:23356:23556  "stateData.lastInitializedRewardEpoch == returnRewardEpochId ||..."
                let expr_1 := /** @src 0:23356:23415  "stateData.lastInitializedRewardEpoch == returnRewardEpochId" */ eq(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _5, /** @src 0:23356:23415  "stateData.lastInitializedRewardEpoch == returnRewardEpochId" */ expr)
                /// @src 0:23356:23556  "stateData.lastInitializedRewardEpoch == returnRewardEpochId ||..."
                if iszero(expr_1)
                {
                    /// @src 0:23432:23555  "stateData.lastInitializedRewardEpoch > 0 &&..."
                    let expr_2 := /** @src 0:23432:23472  "stateData.lastInitializedRewardEpoch > 0" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _5))
                    /// @src 0:23432:23555  "stateData.lastInitializedRewardEpoch > 0 &&..."
                    if expr_2
                    {
                        expr_2 := /** @src 0:23492:23555  "stateData.lastInitializedRewardEpoch - 1 == returnRewardEpochId" */ eq(cleanup_from_storage_uint32(/** @src 0:23492:23532  "stateData.lastInitializedRewardEpoch - 1" */ checked_sub_uint32(_4)), /** @src 0:23492:23555  "stateData.lastInitializedRewardEpoch - 1 == returnRewardEpochId" */ expr)
                    }
                    /// @src 0:23356:23556  "stateData.lastInitializedRewardEpoch == returnRewardEpochId ||..."
                    expr_1 := expr_2
                }
                /// @src 0:23335:23604  "require(..."
                require_helper_stringliteral_524a(expr_1)
                /// @src 0:23722:23735  "_config.nonce"
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value_2 := calldataload(/** @src 0:23722:23735  "_config.nonce" */ add(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ offset_1, /** @src 0:23722:23735  "_config.nonce" */ 68))
                /// @src 0:23714:23774  "require(_config.nonce > governanceFeeNonce, \"nonce too low\")"
                require_helper_stringliteral_6b1b(/** @src 0:23722:23756  "_config.nonce > governanceFeeNonce" */ gt(value_2, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sload(/** @src 0:23738:23756  "governanceFeeNonce" */ 0x08)))
                /// @src 0:23784:23818  "governanceFeeNonce = _config.nonce"
                update_storage_value_offsett_uint256_to_uint256(/** @src 0:23805:23818  "_config.nonce" */ value_2)
                /// @src 0:23914:23927  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 0:23933:23954  "_config.newFeeConfigs"
                let _6 := add(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ offset_1, /** @src 0:23933:23954  "_config.newFeeConfigs" */ 100)
                /// @src 0:23909:24294  "for (uint256 i = 0; i < _config.newFeeConfigs.length; i++) {..."
                for { }
                /** @src 0:24071:24072  "1" */ 0x01
                /// @src 0:23914:23927  "uint256 i = 0"
                {
                    /// @src 0:23963:23966  "i++"
                    var_i := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:23963:23966  "i++" */ var_i, /** @src 0:24071:24072  "1" */ 0x01)
                }
                /// @src 0:23963:23966  "i++"
                {
                    /// @src 0:23933:23954  "_config.newFeeConfigs"
                    let expr_offset, expr_length := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:23929:23961  "i < _config.newFeeConfigs.length"
                    if iszero(lt(var_i, /** @src 0:23933:23961  "_config.newFeeConfigs.length" */ expr_length))
                    /// @src 0:23929:23961  "i < _config.newFeeConfigs.length"
                    { break }
                    /// @src 0:24001:24022  "_config.newFeeConfigs"
                    let expr_offset_1, expr_length_1 := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:24001:24036  "_config.newFeeConfigs[i].protocolId"
                    let expr_3 := read_from_calldatat_uint8(/** @src 0:24001:24025  "_config.newFeeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(expr_offset_1, expr_length_1, var_i))
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    let _7 := and(/** @src 0:24058:24072  "protocolId > 1" */ expr_3, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff)
                    /// @src 0:24050:24096  "require(protocolId > 1, \"invalid protocol id\")"
                    require_helper_stringliteral_44e5(/** @src 0:24058:24072  "protocolId > 1" */ gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _7, /** @src 0:24071:24072  "1" */ 0x01))
                    /// @src 0:24141:24162  "_config.newFeeConfigs"
                    let expr_offset_2, expr_length_2 := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:24141:24174  "_config.newFeeConfigs[i].feeInWei"
                    let _8 := add(/** @src 0:24141:24165  "_config.newFeeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(expr_offset_2, expr_length_2, var_i), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:24141:24174  "_config.newFeeConfigs[i].feeInWei"
                    let value_3 := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    value_3 := calldataload(_8)
                    sstore(/** @src 0:24110:24138  "protocolFeeInWei[protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint8(expr_3), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ value_3)
                    /// @src 0:24234:24255  "_config.newFeeConfigs"
                    let expr_offset_3, expr_length_3 := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:24234:24267  "_config.newFeeConfigs[i].feeInWei"
                    let _9 := add(/** @src 0:24234:24258  "_config.newFeeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(expr_offset_3, expr_length_3, var_i), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:24234:24267  "_config.newFeeConfigs[i].feeInWei"
                    let value_4 := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    value_4 := calldataload(_9)
                    /// @src 0:24193:24283  "RelayGovernanceFeeConfigured(protocolId, _config.newFeeConfigs[i].feeInWei, _config.nonce)"
                    let _10 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:24193:24283  "RelayGovernanceFeeConfigured(protocolId, _config.newFeeConfigs[i].feeInWei, _config.nonce)"
                    log2(_10, sub(abi_encode_uint256_uint256(_10, value_4, value_2), _10), 0x56e557c678d8c60ad61135f4d764031042d94e83074d43cad2dd56a0194759c8, _7)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function external_fun_initialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 0:9716:9760  "uint32 public immutable initialRewardEpochId" */ loadimmutable("335"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15098(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, 0)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15099(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:77578:77596  "merkleRootsPrivate" */ 0x01)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15104(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:75648:75664  "protocolFeeInWei" */ 0x04)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15177(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:79895:79916  "toRandomNumberPrivate" */ 0x09)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15179(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:79973:79990  "isSecureRandomMap" */ 0x06)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ value)
                mstore(32, /** @src 0:8472:8543  "mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds" */ 2)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x40))
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value0 := abi_decode_uint256_15035()
                let value1 := abi_decode_uint256()
                let value2 := abi_decode_bytes32()
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let length := calldataload(add(4, offset))
                if gt(length, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if gt(add(add(offset, shl(5, length)), 36), calldatasize())
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let ret := fun_verify(value0, value1, value2, add(offset, 36), length)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bool(memPos, ret), memPos))
            }
            function panic_error_0x41()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(0, 0x24)
            }
            function finalize_allocation(memPtr, size)
            {
                let newFreePtr := add(memPtr, and(add(size, 31), /** @src 0:23022:23056  "abi.encode(_config, address(this))" */ not(31)))
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr)) { panic_error_0x41() }
                mstore(64, newFreePtr)
            }
            function allocate_memory() -> memPtr
            {
                memPtr := mload(64)
                finalize_allocation(memPtr, 0xc0)
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
            function abi_decode_uint32(offset) -> value
            {
                value := calldataload(offset)
                if iszero(eq(value, and(value, 0xffffffff))) { revert(0, 0) }
            }
            function abi_decode_uint16(offset) -> value
            {
                value := calldataload(offset)
                if iszero(eq(value, and(value, 0xffff))) { revert(0, 0) }
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let src := add(offset, 0x20)
                for { } lt(src, srcEnd) { src := add(src, 0x20) }
                {
                    let value := calldataload(src)
                    if iszero(eq(value, and(value, sub(shl(160, 1), 1))))
                    {
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let src := add(offset, 0x20)
                for { } lt(src, srcEnd) { src := add(src, 0x20) }
                {
                    mstore(dst, abi_decode_uint16(src))
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0xc0)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := allocate_memory()
                mstore(value, abi_decode_uint24(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                mstore(add(value, 64), abi_decode_uint16(add(offset, 68)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value_1 := calldataload(add(offset, 100))
                mstore(add(value, 96), value_1)
                let offset_1 := calldataload(add(offset, 132))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                mstore(add(value, 128), abi_decode_array_address_dyn(add(add(offset, offset_1), 4), calldatasize()))
                let offset_2 := calldataload(add(offset, 164))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                mstore(add(value, 160), abi_decode_array_uint16_dyn(add(add(offset, offset_2), 4), calldatasize()))
                /// @src 0:15901:15908  "bytes32"
                let var := modifier_onlySigningPolicySetter(value)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bytes32(memPos, var), memPos))
            }
            function external_fun_lastInitializedRewardEpochData()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(152, sload(/** @src 0:81357:81366  "stateData" */ 0x07)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 0:81476:81498  "startingVotingRoundIds" */ 0x02)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let cleaned := and(sload(keccak256(0, 0x40)), 0xffffffff)
                let memPos := mload(0x40)
                mstore(memPos, value)
                mstore(add(memPos, 0x20), cleaned)
                return(memPos, 0x40)
            }
            function external_fun_protocolFeeInWei()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ value)
                mstore(32, 4)
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x40))
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value0, value1 := abi_decode_bytes_calldata(add(4, offset), calldatasize())
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(36)
                let ret := /** @src 0:22292:22343  "_verifyCustomSignature(_relayMessage, _messageHash)" */ fun_verifyCustomSignature(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ value0, value1, value)
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := calldataload(4)
                let ret, ret_1, ret_2 := fun_getRandomNumberHistorical(value)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, ret, ret_1, ret_2), memPos))
            }
            function external_fun_signingPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:8618:8652  "address public signingPolicySetter" */ 3), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
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
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value0 := abi_decode_uint256_15035()
                let _1 := sload(/** @src 0:80438:80447  "stateData" */ 0x07)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := and(shr(8, _1), 0xffffffff)
                if /** @src 0:80424:80471  "_timestamp >= stateData.firstVotingRoundStartTs" */ lt(value0, value)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 16)
                    mstore(add(memPtr, 68), "before the start")
                    revert(memPtr, 100)
                }
                /// @src 0:80510:80556  "_timestamp - stateData.firstVotingRoundStartTs"
                let expr := checked_sub_uint256(value0, cleanup_from_storage_uint32(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ value))
                /// @src 0:80502:80596  "return (_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds"
                let var := /** @src 0:80509:80596  "(_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds" */ checked_div_uint256(expr, extract_from_storage_value_offsett_uint8(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_5t_uint8(_1)))
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bytes32(memPos, var), memPos))
            }
            function abi_encode_bytes(value, pos) -> end
            {
                let length := mload(value)
                mstore(pos, length)
                mcopy(add(pos, 0x20), add(value, 0x20), length)
                mstore(add(add(pos, length), 0x20), /** @src -1:-1:-1 */ 0)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                end := add(add(pos, and(add(length, 31), /** @src 0:23022:23056  "abi.encode(_config, address(this))" */ not(31))), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x20)
            }
            function external_fun_relay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 0:24462:73522  "assembly {..."
                let usr$memPtr := mload(0x40)
                mstore(add(usr$memPtr, 160), sload(7))
                if lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:24462:73522  "assembly {..." */ 15)
                {
                    usr$revertWithMessage_15055(usr$memPtr)
                }
                calldatacopy(usr$memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 4, /** @src 0:24462:73522  "assembly {..." */ 11)
                let _1 := mload(usr$memPtr)
                if lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:24462:73522  "assembly {..." */ add(mul(shr(240, _1), 22), 48))
                {
                    usr$revertWithMessage_15056(usr$memPtr)
                }
                let _2 := usr$calculateSigningPolicyHash_15057(usr$memPtr, add(43, mul(shr(240, _1), 22)))
                mstore(add(usr$memPtr, 0x40), _2)
                mstore(usr$memPtr, and(shr(216, _1), 16777215))
                mstore(add(usr$memPtr, 32), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0)
                /// @src 0:24462:73522  "assembly {..."
                let _3 := sload(keccak256(usr$memPtr, 0x40))
                mstore(add(usr$memPtr, 96), _3)
                if iszero(eq(_2, _3))
                {
                    usr$revertWithMessage_15058(usr$memPtr)
                }
                calldatacopy(usr$memPtr, add(mul(shr(240, _1), 22), 47), 1)
                let usr$protocolId := shr(248, mload(usr$memPtr))
                let usr$signatureStart := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                /// @src 0:24462:73522  "assembly {..."
                let usr$threshold := and(shr(168, _1), 65535)
                if iszero(iszero(usr$protocolId))
                {
                    let usr$memPtrGP0 := mload(0x40)
                    usr$signatureStart := add(mul(shr(240, _1), 22), 85)
                    if lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:24462:73522  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_15059(usr$memPtrGP0)
                    }
                    calldatacopy(usr$memPtrGP0, add(mul(shr(240, _1), 22), 47), 38)
                    let usr$votingRoundId := and(shr(216, mload(usr$memPtrGP0)), 4294967295)
                    mstore(add(usr$memPtrGP0, 96), usr$protocolId)
                    mstore(add(usr$memPtrGP0, 128), 1)
                    mstore(add(usr$memPtrGP0, 128), keccak256(add(usr$memPtrGP0, 96), 0x40))
                    mstore(add(usr$memPtrGP0, 96), usr$votingRoundId)
                    if iszero(iszero(sload(keccak256(add(usr$memPtrGP0, 96), 0x40))))
                    {
                        usr$revertWithMessage_15060(usr$memPtrGP0)
                    }
                    let _4 := eq(usr$protocolId, 1)
                    if _4
                    {
                        if usr$votingRoundId
                        {
                            usr$revertWithMessage_15061(usr$memPtrGP0)
                        }
                        if extract_from_storage_value_offsett_uint8(shr(208, mload(usr$memPtrGP0)))
                        {
                            usr$revertWithMessage_15063(usr$memPtrGP0)
                        }
                    }
                    let usr$messageRewardEpochId := and(shr(216, _1), 16777215)
                    let _5 := iszero(_4)
                    if _5
                    {
                        usr$messageRewardEpochId := usr$rewardEpochIdFromVotingRoundId(mload(add(usr$memPtrGP0, 160)), usr$votingRoundId)
                    }
                    if lt(usr$messageRewardEpochId, and(shr(216, _1), 16777215))
                    {
                        usr$revertWithMessage_15064(usr$memPtrGP0)
                    }
                    let _6 := mload(add(usr$memPtrGP0, 160))
                    if lt(add(usr$messageRewardEpochId, and(shr(192, _6), 4294967295)), and(shr(152, _6), 4294967295))
                    {
                        usr$revertWithMessage_15065(usr$memPtrGP0)
                    }
                    if and(_5, lt(usr$votingRoundId, and(shr(184, _1), 4294967295)))
                    {
                        usr$revertWithMessage_15066(usr$memPtrGP0)
                    }
                    if gt(usr$messageRewardEpochId, and(shr(216, _1), 16777215))
                    {
                        let usr$lastInitializedRewardEpoch := extract_from_storage_value_offsett_uint32(mload(add(usr$memPtrGP0, 160)))
                        if gt(usr$lastInitializedRewardEpoch, and(shr(216, _1), 16777215))
                        {
                            mstore(add(usr$memPtrGP0, 96), add(and(shr(216, _1), 16777215), 1))
                            mstore(add(usr$memPtrGP0, 128), 2)
                            if gt(add(usr$votingRoundId, 1), sload(keccak256(add(usr$memPtrGP0, 96), 0x40)))
                            {
                                usr$revertWithMessage_15068(usr$memPtrGP0)
                            }
                        }
                        if eq(usr$lastInitializedRewardEpoch, and(shr(216, _1), 16777215))
                        {
                            usr$threshold := div(mul(usr$threshold, usr$structValue(mload(add(usr$memPtrGP0, 160)))), 10000)
                        }
                    }
                    mstore(add(usr$memPtrGP0, 32), keccak256(usr$memPtrGP0, 38))
                }
                if iszero(usr$protocolId)
                {
                    let _7 := mload(0x40)
                    if iszero(iszero(extract_from_storage_value_offsett_bool(mload(add(_7, 160)))))
                    {
                        usr$revertWithMessage_15071(_7)
                    }
                    if lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:24462:73522  "assembly {..." */ add(mul(shr(240, _1), 22), 59))
                    {
                        usr$revertWithMessage_15072(mload(0x40))
                    }
                    calldatacopy(mload(0x40), add(mul(shr(240, _1), 22), 48), 11)
                    let _8 := mload(0x40)
                    let _9 := mload(_8)
                    let _10 := shr(240, _9)
                    if iszero(_10)
                    {
                        usr$revertWithMessage_15073(_8)
                    }
                    if gt(_10, 300)
                    {
                        usr$revertWithMessage_15074(mload(0x40))
                    }
                    let _11 := mul(_10, 22)
                    usr$signatureStart := add(add(mul(shr(240, _1), 22), _11), 91)
                    if lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:24462:73522  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_15075(mload(0x40))
                    }
                    let usr$newSigningPolicyRewardEpochId := and(shr(216, _9), 16777215)
                    let _12 := mload(0x40)
                    let usr$tmpLastInitializedRewardEpochId := extract_from_storage_value_offsett_uint32(mload(add(_12, 160)))
                    if iszero(eq(usr$tmpLastInitializedRewardEpochId, and(shr(216, _1), 16777215)))
                    {
                        usr$revertWithMessage_15077(_12)
                    }
                    if iszero(eq(add(1, usr$tmpLastInitializedRewardEpochId), usr$newSigningPolicyRewardEpochId))
                    {
                        usr$revertWithMessage_15078(mload(0x40))
                    }
                    usr$checkThresholdConsistency(mload(0x40), shr(168, _9), add(mul(shr(240, _1), 22), 48))
                    let usr$newSigningPolicyHash := usr$calculateSigningPolicyHash(mload(0x40), add(mul(shr(240, _1), 22), 48), add(43, _11))
                    let _13 := add(mload(0x40), 160)
                    mstore(_13, usr$assignStruct(mload(_13), usr$newSigningPolicyRewardEpochId))
                    mstore(mload(0x40), usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), 2)
                    let _14 := mload(0x40)
                    sstore(keccak256(_14, 0x40), and(shr(184, _9), 4294967295))
                    mstore(_14, usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0)
                    /// @src 0:24462:73522  "assembly {..."
                    let _15 := mload(0x40)
                    sstore(keccak256(_15, 0x40), usr$newSigningPolicyHash)
                    mstore(add(_15, 32), usr$newSigningPolicyHash)
                    mstore(add(mload(0x40), 96), "SigningPolicyRelayed(uint256)")
                    log2(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0, 0, /** @src 0:24462:73522  "assembly {..." */ keccak256(add(mload(0x40), 96), 29), usr$newSigningPolicyRewardEpochId)
                }
                let _16 := add(usr$signatureStart, 2)
                if lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:24462:73522  "assembly {..." */ _16)
                {
                    usr$revertWithMessage_15080(usr$memPtr)
                }
                calldatacopy(add(usr$memPtr, 0x40), usr$signatureStart, 2)
                let _17 := shr(240, mload(add(usr$memPtr, 0x40)))
                mstore(add(usr$memPtr, 256), _16)
                if lt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:24462:73522  "assembly {..." */ add(add(usr$signatureStart, mul(_17, 67)), 2))
                {
                    usr$revertWithMessage_15081(usr$memPtr)
                }
                mstore(usr$memPtr, "0000\x19Ethereum Signed Message:\n32")
                mstore(usr$memPtr, keccak256(add(usr$memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 4), /** @src 0:24462:73522  "assembly {..." */ 60))
                let usr$i := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                /// @src 0:24462:73522  "assembly {..."
                let usr$weight := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                /// @src 0:24462:73522  "assembly {..."
                let usr$nextUnusedIndex := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                /// @src 0:24462:73522  "assembly {..."
                let usr$memPtrFor := mload(0x40)
                for { } lt(usr$i, _17) { usr$i := add(usr$i, 1) }
                {
                    mstore(add(usr$memPtrFor, 32), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0)
                    /// @src 0:24462:73522  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 63), add(add(usr$signatureStart, mul(usr$i, 67)), 2), 67)
                    let usr$index := shr(240, mload(add(usr$memPtrFor, 128)))
                    if gt(add(usr$index, 1), shr(240, _1))
                    {
                        usr$revertWithMessage_15082(usr$memPtrFor)
                    }
                    if lt(usr$index, usr$nextUnusedIndex)
                    {
                        usr$revertWithMessage_15083(usr$memPtrFor)
                    }
                    usr$nextUnusedIndex := add(usr$index, 1)
                    let _18 := and(mload(add(usr$memPtrFor, 32)), 0xff)
                    if iszero(or(eq(_18, 27), eq(_18, 28)))
                    {
                        usr$revertWithMessage_15084(usr$memPtrFor)
                    }
                    if gt(mload(add(usr$memPtrFor, 96)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                    {
                        usr$revertWithMessage_15085(usr$memPtrFor)
                    }
                    if iszero(staticcall(not(0), 1, usr$memPtrFor, 128, add(usr$memPtrFor, 0x40), 32))
                    {
                        usr$revertWithMessage_15086(usr$memPtrFor)
                    }
                    if iszero(eq(returndatasize(), 32))
                    {
                        usr$revertWithMessage_15087(usr$memPtrFor)
                    }
                    if iszero(mload(add(usr$memPtrFor, 0x40)))
                    {
                        usr$revertWithMessage_15088(usr$memPtrFor)
                    }
                    mstore(add(usr$memPtrFor, 96), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0)
                    /// @src 0:24462:73522  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 106), add(47, mul(usr$index, 22)), 22)
                    if iszero(eq(mload(add(usr$memPtrFor, 0x40)), shr(16, mload(add(usr$memPtrFor, 96)))))
                    {
                        usr$revertWithMessage_15089(usr$memPtrFor)
                    }
                    usr$weight := add(usr$weight, and(mload(add(usr$memPtrFor, 96)), 65535))
                    if gt(usr$weight, usr$threshold)
                    {
                        if iszero(usr$protocolId)
                        {
                            sstore(7, mload(add(usr$memPtrFor, 160)))
                            return(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0, 0)
                        }
                        /// @src 0:24462:73522  "assembly {..."
                        if iszero(iszero(usr$protocolId))
                        {
                            let _19 := add(usr$memPtrFor, 192)
                            calldatacopy(_19, add(mul(shr(240, _1), 22), 53), 32)
                            if eq(usr$protocolId, 1)
                            {
                                mstore(usr$memPtrFor, mload(_19))
                                mstore(add(usr$memPtrFor, 32), and(shl(16, _1), shl(232, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 16777215)))
                                /// @src 0:24462:73522  "assembly {..."
                                return(usr$memPtrFor, 35)
                            }
                            if iszero(mload(_19))
                            {
                                usr$revertWithMessage_15090(usr$memPtrFor)
                            }
                            let usr$votingRoundId_1 := usr$extractVotingRoundIdFromMessage(usr$memPtrFor, add(43, mul(shr(240, _1), 22)))
                            mstore(usr$memPtrFor, usr$protocolId)
                            mstore(add(usr$memPtrFor, 32), 1)
                            mstore(add(usr$memPtrFor, 32), keccak256(usr$memPtrFor, 0x40))
                            mstore(usr$memPtrFor, usr$votingRoundId_1)
                            sstore(keccak256(usr$memPtrFor, 0x40), mload(_19))
                            let _20 := add(usr$memPtrFor, 160)
                            if iszero(eq(usr$protocolId, extract_from_storage_value_offsett_uint8(mload(_20))))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, _1), 22), 47), 6)
                                let _21 := shr(208, mload(usr$memPtrFor))
                                mstore(usr$memPtrFor, _21)
                                mstore(_20, and(_21, 0xff))
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_20, 0x40, keccak256(add(usr$memPtrFor, 96), 49), usr$protocolId, usr$votingRoundId_1)
                                return(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0, 0)
                            }
                            /// @src 0:24462:73522  "assembly {..."
                            if eq(usr$protocolId, extract_from_storage_value_offsett_uint8(mload(_20)))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, _1), 22), 47), 6)
                                let usr$isSecure := iszero(iszero(extract_from_storage_value_offsett_uint8(shr(208, mload(usr$memPtrFor)))))
                                let _22 := add(usr$memPtrFor, 256)
                                usr$processRandomMerkleProof(usr$memPtrFor, add(mload(_22), mul(_17, 67)), _19, usr$votingRoundId_1, usr$isSecure)
                                if usr$isSecure
                                {
                                    usr$setIsSecureRandomBit(add(usr$memPtrFor, 96), usr$votingRoundId_1)
                                }
                                let _23 := mload(_20)
                                if gt(usr$votingRoundId_1, and(shr(112, _23), 4294967295))
                                {
                                    sstore(7, usr$assignStruct_15095(usr$assignStruct_15094(_23, usr$votingRoundId_1), usr$isSecure))
                                }
                                mstore(_20, usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_20, 0x40, keccak256(add(usr$memPtrFor, 96), 49), usr$protocolId, usr$votingRoundId_1)
                                calldatacopy(_19, add(mload(_22), mul(_17, 67)), 32)
                                mstore(add(usr$memPtrFor, 224), usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "RandomNumberRelayed(uint32,uint2")
                                mstore(add(usr$memPtrFor, 128), "56,bool)")
                                log2(_19, 0x40, keccak256(add(usr$memPtrFor, 96), 40), usr$votingRoundId_1)
                                return(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0, 0)
                            }
                        }
                        /// @src 0:24462:73522  "assembly {..."
                        usr$revertWithMessage_15096(mload(0x40))
                    }
                }
                /// @src 0:73543:73570  "revert(\"Not enough weight\")"
                let _24 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:24462:73522  "assembly {..." */ 0x40)
                /// @src 0:73543:73570  "revert(\"Not enough weight\")"
                mstore(_24, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:73543:73570  "revert(\"Not enough weight\")"
                revert(_24, sub(abi_encode_stringliteral_0d64(add(_24, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 4)), /** @src 0:73543:73570  "revert(\"Not enough weight\")" */ _24))
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function external_fun_getRandomNumber()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:78756:78765  "stateData" */ 0x07)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let value := and(shr(112, _1), 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 0:78734:78755  "toRandomNumberPrivate" */ 0x09)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let _2 := sload(keccak256(0, 0x40))
                let cleaned := and(/** @src 0:78935:78968  "stateData.randomVotingRoundId + 1" */ checked_add_uint32(value), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)
                /// @src 0:78848:79020  "_randomTimestamp =..."
                let var_randomTimestamp := /** @src 0:78879:79020  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(shr(8, _1), 0xffffffff), /** @src 0:78927:79020  "uint256(stateData.randomVotingRoundId + 1) *..." */ checked_mul_uint256(cleaned, extract_from_storage_value_offsett_uint8(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(shr(40, _1), 0xff))))
                let memPos := mload(0x40)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, _2, and(shr(144, _1), 0xff), var_randomTimestamp), memPos))
            }
            function external_fun_oldRelay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 0:9641:9673  "IRelay public immutable oldRelay" */ loadimmutable("332"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
                return(memPos, 32)
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
            function require_helper_stringliteral_63a2(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 34)
                    mstore(add(memPtr, 68), "no access to signing policy hash")
                    mstore(add(memPtr, 100), "es")
                    revert(memPtr, 132)
                }
            }
            /// @ast-id 1933 @src 0:80651:81054  "function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {..."
            function fun_toSigningPolicyHash(var_rewardEpochId) -> var
            {
                /// @src 0:80727:80734  "bytes32"
                var := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:80750:80758  "oldRelay" */ loadimmutable("332"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:80750:80821  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                let expr := /** @src 0:80750:80780  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:80750:80821  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:80784:80821  "_rewardEpochId < initialRewardEpochId" */ lt(var_rewardEpochId, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:80801:80821  "initialRewardEpochId" */ loadimmutable("335"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:80746:80899  "if (oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:80844:80888  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _2 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:80844:80888  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    mstore(_2, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x0c85bf07))
                    /// @src 0:80844:80888  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_bytes32(add(_2, 4), var_rewardEpochId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:80844:80888  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:80837:80888  "return oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    var := expr_1
                    leave
                }
                /// @src 0:80908:80988  "require(signingPolicySetter != address(0), \"no access to signing policy hashes\")"
                require_helper_stringliteral_63a2(/** @src 0:80916:80949  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(cleanup_address_payable(sload(/** @src 0:80916:80935  "signingPolicySetter" */ 0x03)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))))
                /// @src 0:80998:81047  "return toSigningPolicyHashPrivate[_rewardEpochId]"
                var := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sload(/** @src 0:81005:81047  "toSigningPolicyHashPrivate[_rewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15098(var_rewardEpochId))
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function abi_decode_t_bool_fromMemory(offset) -> value
            {
                value := mload(offset)
                if iszero(eq(value, iszero(iszero(value)))) { revert(0, 0) }
            }
            function abi_decode_bool_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                value0 := abi_decode_t_bool_fromMemory(headStart)
            }
            function abi_encode_uint256_uint256(headStart, value0, value1) -> tail
            {
                tail := add(headStart, 64)
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
            }
            /// @ast-id 1679 @src 0:77046:77646  "function isFinalized(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_isFinalized(var__protocolId, var_votingRoundId) -> var
            {
                /// @src 0:77151:77155  "bool"
                var := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:77175:77183  "oldRelay" */ loadimmutable("332"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:77175:77270  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:77175:77205  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:77175:77270  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:77209:77270  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:77226:77270  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:77171:77353  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:77293:77342  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:77293:77342  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(226, 0x0c5eb4cf))
                    /// @src 0:77293:77342  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var__protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:77293:77342  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bool_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:77286:77342  "return oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    var := expr_1
                    leave
                }
                /// @src 0:77571:77639  "return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)"
                var := /** @src 0:77578:77639  "merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ sload(/** @src 0:77578:77625  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:77578:77609  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15099(var__protocolId), /** @src 0:77578:77625  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))))
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function require_helper_stringliteral_1c79(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 25)
                    mstore(add(memPtr, 68), "no access to merkle roots")
                    revert(memPtr, 100)
                }
            }
            /// @ast-id 1726 @src 0:77694:78167  "function merkleRoots(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_merkleRoots(var_protocolId, var__votingRoundId) -> var_merkleRoot
            {
                /// @src 0:77799:77818  "bytes32 _merkleRoot"
                var_merkleRoot := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:77838:77846  "oldRelay" */ loadimmutable("332"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:77838:77933  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:77838:77868  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:77838:77933  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:77872:77933  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var__votingRoundId, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:77889:77933  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:77834:78016  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:77956:78005  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:77956:78005  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(232, 3752811))
                    /// @src 0:77956:78005  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var_protocolId, var__votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:77956:78005  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:77949:78005  "return oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    var_merkleRoot := expr_1
                    leave
                }
                /// @src 0:78025:78096  "require(signingPolicySetter != address(0), \"no access to merkle roots\")"
                require_helper_stringliteral_1c79(/** @src 0:78033:78066  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(cleanup_address_payable(sload(/** @src 0:78033:78052  "signingPolicySetter" */ 0x03)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))))
                /// @src 0:78106:78160  "return merkleRootsPrivate[_protocolId][_votingRoundId]"
                var_merkleRoot := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sload(/** @src 0:78113:78160  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:78113:78144  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15099(var_protocolId), /** @src 0:78113:78160  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var__votingRoundId))
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function require_helper_stringliteral_59e4(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 17)
                    mstore(add(memPtr, 68), "fee cannot be set")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_0424(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 14)
                    mstore(add(memPtr, 68), "wrong chain id")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_88b2(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 22)
                    mstore(add(memPtr, 68), "wrong description hash")
                    revert(memPtr, 100)
                }
            }
            function validator_revert_uint8(value)
            {
                if iszero(eq(value, and(value, 0xff))) { revert(0, 0) }
            }
            function abi_encode_array_struct_FeeConfig_calldata_dyn_calldata(value, length, pos) -> end
            {
                mstore(pos, length)
                pos := add(pos, 0x20)
                let srcPtr := value
                let i := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                for { } lt(i, length) { i := add(i, 1) }
                {
                    let value_1 := calldataload(srcPtr)
                    validator_revert_uint8(value_1)
                    mstore(pos, and(value_1, 0xff))
                    let value_2 := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    value_2 := calldataload(add(srcPtr, 0x20))
                    mstore(add(pos, 0x20), value_2)
                    pos := add(pos, 0x40)
                    srcPtr := add(srcPtr, 0x40)
                }
                end := pos
            }
            function abi_encode_struct_RelayGovernanceConfig_calldata_address(headStart, value0, value1) -> tail
            {
                mstore(headStart, 64)
                let value := 0
                value := calldataload(value0)
                mstore(add(headStart, 64), value)
                let value_1 := 0
                value_1 := calldataload(add(value0, 0x20))
                mstore(add(headStart, 96), value_1)
                let value_2 := 0
                value_2 := calldataload(add(value0, 64))
                mstore(add(headStart, 0x80), value_2)
                let rel_offset_of_tail := calldataload(add(value0, 96))
                if iszero(slt(rel_offset_of_tail, add(sub(calldatasize(), value0), not(30)))) { revert(0, 0) }
                let value_3 := add(rel_offset_of_tail, value0)
                let length := calldataload(value_3)
                let value_4 := add(value_3, 0x20)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                if sgt(value_4, sub(calldatasize(), shl(6, length))) { revert(0, 0) }
                mstore(add(headStart, 160), 0x80)
                tail := abi_encode_array_struct_FeeConfig_calldata_dyn_calldata(value_4, length, add(headStart, 192))
                abi_encode_address_payable(value1, add(headStart, 0x20))
            }
            function panic_error_0x11()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x11)
                revert(0, 0x24)
            }
            function checked_sub_uint32(x) -> diff
            {
                diff := add(and(x, 0xffffffff), /** @src 0:24462:73522  "assembly {..." */ not(0))
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if gt(diff, 0xffffffff) { panic_error_0x11() }
            }
            function require_helper_stringliteral_524a(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 22)
                    mstore(add(memPtr, 68), "too old signing policy")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_6b1b(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 13)
                    mstore(add(memPtr, 68), "nonce too low")
                    revert(memPtr, 100)
                }
            }
            function update_storage_value_offsett_uint256_to_uint256(value)
            {
                sstore(/** @src 0:23738:23756  "governanceFeeNonce" */ 0x08, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ value)
            }
            function access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(base_ref, ptr_to_tail) -> addr, length
            {
                let rel_offset_of_tail := calldataload(ptr_to_tail)
                if iszero(slt(rel_offset_of_tail, add(sub(calldatasize(), base_ref), not(30)))) { revert(0, 0) }
                let addr_1 := add(base_ref, rel_offset_of_tail)
                length := calldataload(addr_1)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                addr := add(addr_1, 0x20)
                if sgt(addr, sub(calldatasize(), shl(6, length))) { revert(0, 0) }
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
            function require_helper_stringliteral_44e5(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 19)
                    mstore(add(memPtr, 68), "invalid protocol id")
                    revert(memPtr, 100)
                }
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint8(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, 4)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint8_15176(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, /** @src 0:79745:79763  "merkleRootsPrivate" */ 0x01)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                dataSlot := keccak256(0, 0x40)
            }
            function require_helper_stringliteral_4ed5(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 11)
                    mstore(add(memPtr, 68), "too low fee")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 13)
                    mstore(add(memPtr, 68), "not finalized")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_c04c(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 20)
                    mstore(add(memPtr, 68), "merkle proof invalid")
                    revert(memPtr, 100)
                }
            }
            function array_allocation_size_bytes(length) -> size
            {
                if gt(length, 0xffffffffffffffff) { panic_error_0x41() }
                size := add(and(add(length, 31), /** @src 0:23022:23056  "abi.encode(_config, address(this))" */ not(31)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x20)
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
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ returndatasize())
                }
            }
            function require_helper_stringliteral_25ad(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 15)
                    mstore(add(memPtr, 68), "Transfer failed")
                    revert(memPtr, 100)
                }
            }
            function checked_sub_uint256_15116(y) -> diff
            {
                diff := sub(/** @src 0:20364:20366  "20" */ 0x14, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:20364:20366  "20" */ 0x14)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_15118(y) -> diff
            {
                diff := sub(/** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_15121(y) -> diff
            {
                diff := sub(/** @src 0:19593:19594  "2" */ 0x02, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:19593:19594  "2" */ 0x02)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_15181(y) -> diff
            {
                diff := sub(/** @src 0:80017:80020  "255" */ 0xff, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:80017:80020  "255" */ 0xff)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256(x, y) -> diff
            {
                diff := sub(x, y)
                if gt(diff, x) { panic_error_0x11() }
            }
            function require_helper_stringliteral_940e(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 13)
                    mstore(add(memPtr, 68), "Refund failed")
                    revert(memPtr, 100)
                }
            }
            function abi_decode_uint256_fromMemory(headStart, dataEnd) -> value0
            {
                if slt(sub(dataEnd, headStart), 32) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
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
            function require_helper_stringliteral_fd5d(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 29)
                    mstore(add(memPtr, 68), "old relay verification failed")
                    revert(memPtr, 100)
                }
            }
            /// @ast-id 1637 @src 0:73625:76998  "function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)..."
            function fun_verify(var_protocolId, var_votingRoundId, var_leaf, var__proof_offset, var_proof_length) -> var
            {
                /// @src 0:73770:73774  "bool"
                var := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:74518:74526  "oldRelay" */ loadimmutable("332"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:74518:74613  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:74518:74548  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:74518:74613  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:74552:74613  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:74569:74613  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:74514:76970  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                switch expr
                case 0 {
                    /// @src 0:75573:75620  "require(_protocolId > 1, \"invalid protocol id\")"
                    require_helper_stringliteral_44e5(/** @src 0:75581:75596  "_protocolId > 1" */ gt(var_protocolId, /** @src 0:75595:75596  "1" */ 0x01))
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    let _2 := sload(/** @src 0:75648:75677  "protocolFeeInWei[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15104(var_protocolId))
                    /// @src 0:75691:75731  "require(msg.value >= fee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 0:75699:75715  "msg.value >= fee" */ iszero(lt(/** @src 0:75699:75708  "msg.value" */ callvalue(), /** @src 0:75699:75715  "msg.value >= fee" */ _2)))
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    let _3 := sload(/** @src 0:75841:75888  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:75841:75872  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15099(var_protocolId), /** @src 0:75841:75888  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
                    /// @src 0:75902:75946  "require(root != bytes32(0), \"not finalized\")"
                    require_helper_stringliteral(/** @src 0:75910:75928  "root != bytes32(0)" */ iszero(iszero(_3)))
                    /// @src 0:75960:76073  "require(..."
                    require_helper_stringliteral_c04c(/** @src 0:75985:76019  "_proof.verifyCalldata(root, _leaf)" */ fun_verifyCalldata(var__proof_offset, var_proof_length, _3, var_leaf))
                    /// @src 0:76290:76627  "if (fee > 0) {..."
                    if /** @src 0:76294:76301  "fee > 0" */ iszero(iszero(_2))
                    /// @src 0:76290:76627  "if (fee > 0) {..."
                    {
                        /// @src 0:76461:76502  "feeCollectionAddress.call{value: fee}(\"\")"
                        let expr_1596_component := call(gas(), /** @src 0:76461:76486  "feeCollectionAddress.call" */ cleanup_address_payable(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ cleanup_address_payable(sload(/** @src 0:76461:76481  "feeCollectionAddress" */ 0x05))), /** @src 0:76461:76502  "feeCollectionAddress.call{value: fee}(\"\")" */ _2, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0, 0, 0, 0)
                        /// @src 0:76461:76502  "feeCollectionAddress.call{value: fee}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:76579:76612  "require(feeOk, \"Transfer failed\")"
                        require_helper_stringliteral_25ad(expr_1596_component)
                    }
                    /// @src 0:76657:76672  "msg.value - fee"
                    let expr_1 := checked_sub_uint256(/** @src 0:75699:75708  "msg.value" */ callvalue(), /** @src 0:76657:76672  "msg.value - fee" */ _2)
                    /// @src 0:76686:76960  "if (refund > 0) {..."
                    if /** @src 0:76690:76700  "refund > 0" */ iszero(iszero(expr_1))
                    /// @src 0:76686:76960  "if (refund > 0) {..."
                    {
                        /// @src 0:76800:76834  "msg.sender.call{value: refund}(\"\")"
                        let expr_1623_component := call(gas(), /** @src 0:76800:76810  "msg.sender" */ caller(), /** @src 0:76800:76834  "msg.sender.call{value: refund}(\"\")" */ expr_1, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0, 0, 0, 0)
                        /// @src 0:76800:76834  "msg.sender.call{value: refund}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:76911:76945  "require(refundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_1623_component)
                    }
                }
                default /// @src 0:74514:76970  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                {
                    /// @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _4 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)"
                    mstore(_4, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(224, 0x91e7d42f))
                    /// @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _5 := staticcall(gas(), _1, _4, sub(abi_encode_bytes32(add(_4, 4), var_protocolId), _4), _4, 32)
                    if iszero(_5) { revert_forward() }
                    let expr_2 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)"
                    if _5
                    {
                        let _6 := 32
                        if gt(32, returndatasize()) { _6 := returndatasize() }
                        finalize_allocation(_4, _6)
                        expr_2 := abi_decode_uint256_fromMemory(_4, add(_4, _6))
                    }
                    /// @src 0:74967:75010  "require(msg.value >= oldFee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 0:74975:74994  "msg.value >= oldFee" */ iszero(lt(/** @src 0:74975:74984  "msg.value" */ callvalue(), /** @src 0:74975:74994  "msg.value >= oldFee" */ expr_2)))
                    /// @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _7 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    mstore(_7, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(225, 0x40428355))
                    /// @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _8 := call(gas(), _1, expr_2, _7, sub(abi_encode_uint256_uint256_bytes32_array_bytes32_dyn_calldata(add(_7, /** @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)" */ 4), /** @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ var_protocolId, var_votingRoundId, var_leaf, var__proof_offset, var_proof_length), _7), _7, /** @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)" */ 32)
                    /// @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if iszero(_8) { revert_forward() }
                    let expr_3 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if _8
                    {
                        let _9 := /** @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)" */ 32
                        /// @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                        if gt(/** @src 0:74915:74953  "oldRelay.protocolFeeInWei(_protocolId)" */ 32, /** @src 0:75034:75108  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ returndatasize()) { _9 := returndatasize() }
                        finalize_allocation(_7, _9)
                        expr_3 := abi_decode_bool_fromMemory(_7, add(_7, _9))
                    }
                    /// @src 0:75122:75166  "require(ok, \"old relay verification failed\")"
                    require_helper_stringliteral_fd5d(expr_3)
                    /// @src 0:75200:75218  "msg.value - oldFee"
                    let expr_4 := checked_sub_uint256(/** @src 0:74975:74984  "msg.value" */ callvalue(), /** @src 0:75200:75218  "msg.value - oldFee" */ expr_2)
                    /// @src 0:75232:75518  "if (oldRefund > 0) {..."
                    if /** @src 0:75236:75249  "oldRefund > 0" */ iszero(iszero(expr_4))
                    /// @src 0:75232:75518  "if (oldRefund > 0) {..."
                    {
                        /// @src 0:75352:75389  "msg.sender.call{value: oldRefund}(\"\")"
                        let expr_1526_component := call(gas(), /** @src 0:75352:75362  "msg.sender" */ caller(), /** @src 0:75352:75389  "msg.sender.call{value: oldRefund}(\"\")" */ expr_4, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0, 0, 0, 0)
                        /// @src 0:75352:75389  "msg.sender.call{value: oldRefund}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:75466:75503  "require(oldRefundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_1526_component)
                    }
                    /// @src 0:75531:75542  "return true"
                    var := /** @src 0:75538:75542  "true" */ 0x01
                    /// @src 0:75531:75542  "return true"
                    leave
                }
                /// @src 0:76980:76991  "return true"
                var := /** @src 0:76987:76991  "true" */ 0x01
            }
            /// @ast-id 351 @src 0:9966:10098  "modifier onlySigningPolicySetter() {..."
            function modifier_onlySigningPolicySetter(var_signingPolicy_mpos) -> _1
            {
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if iszero(/** @src 0:10019:10052  "msg.sender == signingPolicySetter" */ eq(/** @src 0:10019:10029  "msg.sender" */ caller(), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(sload(/** @src 0:10033:10052  "signingPolicySetter" */ 0x03), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))))
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 23)
                    mstore(add(memPtr, 68), "only sign policy setter")
                    revert(memPtr, 100)
                }
                /// @src 0:16245:16285  "stateData.lastInitializedRewardEpoch + 1"
                let expr := checked_add_uint32(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_uint32(sload(/** @src 0:16245:16254  "stateData" */ 0x07)))
                /// @src 0:16224:16364  "require(..."
                require_helper_stringliteral_d084(/** @src 0:16245:16317  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ eq(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:16245:16317  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ expr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff), /** @src 0:16245:16317  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ cleanup_uint24(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:16289:16317  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))))
                /// @src 0:17218:17282  "require(_signingPolicy.voters.length > 0, \"must be non-trivial\")"
                require_helper_stringliteral_aacd(/** @src 0:17226:17258  "_signingPolicy.voters.length > 0" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ mload(add(var_signingPolicy_mpos, 128))))))
                /// @src 0:17292:17362  "require(_signingPolicy.voters.length <= MAX_VOTERS, \"too many voters\")"
                require_helper_stringliteral_d1bc(/** @src 0:17300:17342  "_signingPolicy.voters.length <= MAX_VOTERS" */ iszero(gt(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:17300:17321  "_signingPolicy.voters" */ mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))), /** @src 0:2485:2488  "300" */ 0x012c)))
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let length := mload(/** @src 0:17380:17401  "_signingPolicy.voters" */ mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))
                /// @src 0:17372:17459  "require(_signingPolicy.voters.length == _signingPolicy.weights.length, \"size mismatch\")"
                require_helper_stringliteral_6b32(/** @src 0:17380:17441  "_signingPolicy.voters.length == _signingPolicy.weights.length" */ eq(length, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:17412:17434  "_signingPolicy.weights" */ mload(add(var_signingPolicy_mpos, 160)))))
                /// @src 0:17469:17492  "uint256 totalWeight = 0"
                let var_totalWeight := /** @src -1:-1:-1 */ 0
                /// @src 0:17507:17520  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 0:17502:17627  "for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {..."
                for { }
                /** @src 0:16284:16285  "1" */ 0x01
                /// @src 0:17507:17520  "uint256 i = 0"
                {
                    /// @src 0:17557:17560  "i++"
                    var_i := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:17557:17560  "i++" */ var_i, /** @src 0:16284:16285  "1" */ 0x01)
                }
                /// @src 0:17557:17560  "i++"
                {
                    /// @src 0:17526:17548  "_signingPolicy.weights"
                    let _mpos := mload(/** @src 0:17412:17434  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                    /// @src 0:17522:17555  "i < _signingPolicy.weights.length"
                    if iszero(lt(var_i, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:17526:17555  "_signingPolicy.weights.length" */ _mpos)))
                    /// @src 0:17522:17555  "i < _signingPolicy.weights.length"
                    { break }
                    /// @src 0:17576:17616  "totalWeight += _signingPolicy.weights[i]"
                    var_totalWeight := checked_add_uint256(var_totalWeight, cleanup_from_storage_uint16(/** @src 0:17591:17616  "_signingPolicy.weights[i]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos, var_i))))
                }
                /// @src 0:17636:17688  "require(totalWeight < 2**16, \"total weight too big\")"
                require_helper_stringliteral_f10c(/** @src 0:17644:17663  "totalWeight < 2**16" */ lt(var_totalWeight, /** @src 0:17658:17663  "2**16" */ 0x010000))
                /// @src 0:17719:17778  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_1 := checked_mul_uint256_15107(/** @src 0:17719:17752  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:17727:17751  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 0:17698:17859  "require(..."
                require_helper_stringliteral_d8d1(/** @src 0:17719:17814  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS" */ iszero(lt(expr_1, /** @src 0:17782:17814  "totalWeight * MIN_THRESHOLD_BIPS" */ checked_mul_uint256_15108(var_totalWeight))))
                /// @src 0:17890:17949  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_2 := checked_mul_uint256_15107(/** @src 0:17890:17923  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:17727:17751  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 0:17869:18028  "require(..."
                require_helper_stringliteral_185c(/** @src 0:17890:17985  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS" */ iszero(gt(expr_2, /** @src 0:17953:17985  "totalWeight * MAX_THRESHOLD_BIPS" */ checked_mul_uint256_15110(var_totalWeight))))
                /// @src 0:18073:18223  "new bytes(..."
                let expr_mpos := allocate_and_zero_memory_array_bytes(/** @src 0:18096:18213  "SIGNING_POLICY_PREFIX_BYTES +..." */ checked_add_uint256_15112(/** @src 0:18142:18213  "_signingPolicy.voters.length *..." */ checked_mul_uint256_15111(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:18142:18163  "_signingPolicy.voters" */ mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))))
                /// @src 0:18234:18251  "Counters memory m"
                let zero_struct_Counters_mpos := /** @src 0:3954:3956  "22" */ allocate_and_zero_memory_struct_struct_Counters()
                /// @src 0:18567:18588  "_signingPolicy.voters"
                let _mpos_1 := mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 0:18553:18597  "bytes2(uint16(_signingPolicy.voters.length))"
                let expr_3 := convert_uint16_to_bytes2(/** @src 0:18560:18596  "uint16(_signingPolicy.voters.length)" */ cleanup_from_storage_uint16(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:18567:18595  "_signingPolicy.voters.length" */ _mpos_1)))
                /// @src 0:18611:18647  "bytes3(_signingPolicy.rewardEpochId)"
                let expr_4 := convert_uint24_to_bytes3(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:18618:18646  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))
                /// @src 0:18661:18702  "bytes4(_signingPolicy.startVotingRoundId)"
                let expr_5 := convert_uint32_to_bytes4(/** @src 0:3954:3956  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32))))
                /// @src 0:18716:18748  "bytes2(_signingPolicy.threshold)"
                let expr_6 := convert_uint16_to_bytes2(/** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:17727:17751  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64))))
                /// @src 0:3954:3956  "22"
                let _2 := mload(/** @src 0:18778:18797  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 0:18813:18846  "bytes20(_signingPolicy.voters[0])"
                let expr_7 := convert_address_to_bytes20(/** @src 0:18821:18845  "_signingPolicy.voters[0]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn_15113(_mpos_1)))
                /// @src 0:18527:18915  "bytes.concat(..."
                let expr_mpos_1 := bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(expr_3, expr_4, expr_5, expr_6, _2, expr_7, /** @src 0:18860:18905  "bytes1(uint8(_signingPolicy.weights[0] >> 8))" */ convert_uint8_to_bytes1(/** @src 0:18867:18904  "uint8(_signingPolicy.weights[0] >> 8)" */ extract_from_storage_value_offsett_uint8(/** @src 0:18873:18903  "_signingPolicy.weights[0] >> 8" */ shift_right_uint16_uint8(/** @src 0:18873:18898  "_signingPolicy.weights[0]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn_15113(/** @src 0:18873:18895  "_signingPolicy.weights" */ mload(/** @src 0:17412:17434  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))))))))
                /// @src 0:18926:19072  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                for { }
                /** @src 0:16284:16285  "1" */ 0x01
                /// @src 0:18926:19072  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                {
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:18958:18976  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 0:18958:18978  "m.signingPolicyPos++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:18958:18976  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                }
                /// @src 0:18958:18978  "m.signingPolicyPos++"
                {
                    /// @src 0:3954:3956  "22"
                    let _3 := mload(/** @src 0:18958:18976  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 0:18933:18956  "m.signingPolicyPos < 64"
                    if iszero(lt(_3, /** @src 0:17727:17751  "_signingPolicy.threshold" */ 64))
                    /// @src 0:18933:18956  "m.signingPolicyPos < 64"
                    { break }
                    /// @src 0:19035:19061  "toHash[m.signingPolicyPos]"
                    let _4 := read_from_memoryt_bytes1(memory_array_index_access_bytes(expr_mpos_1, /** @src 0:3954:3956  "22" */ _3))
                    let _5 := mload(/** @src 0:18958:18976  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 0:18994:19061  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]"
                    mstore8(memory_array_index_access_bytes(expr_mpos, _5), byte(/** @src -1:-1:-1 */ 0, /** @src 0:18994:19061  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]" */ _4))
                }
                /// @src 0:19082:19121  "bytes32 currentHash = keccak256(toHash)"
                let var_currentHash := /** @src 0:19104:19121  "keccak256(toHash)" */ keccak256(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:19104:19121  "keccak256(toHash)" */ expr_mpos_1, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:19104:19121  "keccak256(toHash)" */ expr_mpos_1))
                /// @src 0:3954:3956  "22"
                mstore(zero_struct_Counters_mpos, /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(/** @src 0:19159:19170  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:16284:16285  "1" */ 0x01)
                /// @src 0:3954:3956  "22"
                mstore(/** @src 0:19184:19196  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:17727:17751  "_signingPolicy.threshold" */ 64), /** @src 0:16284:16285  "1" */ 0x01)
                /// @src 0:3954:3956  "22"
                mstore(/** @src 0:19210:19220  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:18778:18797  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                /// @src 0:19235:21441  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                for { }
                /** @src 0:16284:16285  "1" */ 0x01
                /// @src 0:19235:21441  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                { }
                {
                    /// @src 0:3954:3956  "22"
                    let _6 := mload(/** @src 0:19242:19255  "m.weightIndex" */ zero_struct_Counters_mpos)
                    /// @src 0:19242:19286  "m.weightIndex < _signingPolicy.voters.length"
                    if iszero(lt(_6, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:19258:19279  "_signingPolicy.voters" */ mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))))
                    /// @src 0:19242:19286  "m.weightIndex < _signingPolicy.voters.length"
                    { break }
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128), /** @src -1:-1:-1 */ 0)
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:19327:19337  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src -1:-1:-1 */ 0)
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160), /** @src -1:-1:-1 */ 0)
                    /// @src 0:19404:21114  "while (..."
                    for { }
                    /** @src 0:16284:16285  "1" */ 0x01
                    /// @src 0:19404:21114  "while (..."
                    { }
                    {
                        /// @src 0:19428:19488  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        let expr_8 := /** @src 0:19428:19440  "m.count < 32" */ lt(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128)), /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32)
                        /// @src 0:19428:19488  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if expr_8
                        {
                            /// @src 0:3954:3956  "22"
                            let _7 := mload(/** @src 0:19444:19457  "m.weightIndex" */ zero_struct_Counters_mpos)
                            /// @src 0:19428:19488  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                            expr_8 := /** @src 0:19444:19488  "m.weightIndex < _signingPolicy.voters.length" */ lt(_7, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:19460:19481  "_signingPolicy.voters" */ mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))
                        }
                        /// @src 0:19428:19488  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if iszero(expr_8) { break }
                        /// @src 0:3954:3956  "22"
                        let _8 := mload(/** @src 0:19525:19538  "m.weightIndex" */ zero_struct_Counters_mpos)
                        /// @src 0:19521:21058  "if (m.weightIndex < m.voterIndex) {..."
                        switch /** @src 0:19525:19553  "m.weightIndex < m.voterIndex" */ lt(_8, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19184:19196  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:17727:17751  "_signingPolicy.threshold" */ 64)))
                        case /** @src 0:19521:21058  "if (m.weightIndex < m.voterIndex) {..." */ 0 {
                            /// @src 0:3954:3956  "22"
                            mstore(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160), /** @src 0:20364:20379  "20 - m.voterPos" */ checked_sub_uint256_15116(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19210:19220  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:18778:18797  "_signingPolicy.seed" */ 96))))
                            /// @src 0:3954:3956  "22"
                            let _9 := mload(/** @src 0:19210:19220  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:18778:18797  "_signingPolicy.seed" */ 96))
                            /// @src 0:20401:20406  "m.pos"
                            let _10 := add(zero_struct_Counters_mpos, 224)
                            /// @src 0:3954:3956  "22"
                            mstore(_10, _9)
                            /// @src 0:20510:20531  "_signingPolicy.voters"
                            let _mpos_2 := mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                            /// @src 0:20494:20587  "uint256(uint160(_signingPolicy.voters[m.voterIndex])) <<..."
                            let _11 := shift_left_uint256_uint8(/** @src 0:20494:20547  "uint256(uint160(_signingPolicy.voters[m.voterIndex]))" */ cleanup_address_payable(/** @src 0:20502:20546  "uint160(_signingPolicy.voters[m.voterIndex])" */ cleanup_address_payable(/** @src 0:20510:20545  "_signingPolicy.voters[m.voterIndex]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(_mpos_2, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19184:19196  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:17727:17751  "_signingPolicy.threshold" */ 64)))))))
                            /// @src 0:3954:3956  "22"
                            let _12 := mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128))
                            /// @src 0:20631:20904  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 0:20635:20663  "m.count + m.bytesToTake > 32" */ gt(/** @src 0:20635:20658  "m.count + m.bytesToTake" */ checked_add_uint256(_12, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160))), /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 0:20631:20904  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19210:19220  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:18778:18797  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19184:19196  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:17727:17751  "_signingPolicy.threshold" */ 64), /** @src 0:20867:20881  "m.voterIndex++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19184:19196  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:17727:17751  "_signingPolicy.threshold" */ 64))))
                            }
                            default /// @src 0:20631:20904  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 0:20707:20719  "32 - m.count"
                                let _13 := checked_sub_uint256_15118(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128)))
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160), /** @src 0:3954:3956  "22" */ _13)
                                mstore(/** @src 0:19210:19220  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:18778:18797  "_signingPolicy.seed" */ 96), /** @src 0:20745:20772  "m.voterPos += m.bytesToTake" */ checked_add_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19210:19220  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:18778:18797  "_signingPolicy.seed" */ 96)), /** @src 0:3954:3956  "22" */ _13))
                            }
                            mstore(/** @src 0:19327:19337  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 0:20925:21039  "m.nextSlot |= bytes32(..." */ or(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19327:19337  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shr(/** @src 0:21004:21015  "8 * m.count" */ checked_mul_uint256_15119(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128))), /** @src 0:3954:3956  "22" */ shl(/** @src 0:20988:20997  "8 * m.pos" */ checked_mul_uint256_15119(/** @src 0:3954:3956  "22" */ mload(/** @src 0:20992:20997  "m.pos" */ _10)), /** @src 0:3954:3956  "22" */ _11))))
                        }
                        default /// @src 0:19521:21058  "if (m.weightIndex < m.voterIndex) {..."
                        {
                            /// @src 0:3954:3956  "22"
                            mstore(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160), /** @src 0:19593:19608  "2 - m.weightPos" */ checked_sub_uint256_15121(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19159:19170  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32))))
                            /// @src 0:3954:3956  "22"
                            let _14 := mload(/** @src 0:19159:19170  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 0:19630:19635  "m.pos"
                            let _15 := add(zero_struct_Counters_mpos, 224)
                            /// @src 0:3954:3956  "22"
                            mstore(_15, _14)
                            /// @src 0:19769:19791  "_signingPolicy.weights"
                            let _mpos_3 := mload(/** @src 0:17412:17434  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                            /// @src 0:19725:19845  "uint256(..."
                            let _16 := shift_left_uint256_uint8_15122(/** @src 0:19725:19833  "uint256(..." */ cleanup_from_storage_uint16(/** @src 0:19769:19806  "_signingPolicy.weights[m.weightIndex]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos_3, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19792:19805  "m.weightIndex" */ zero_struct_Counters_mpos)))))
                            /// @src 0:3954:3956  "22"
                            let _17 := mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128))
                            /// @src 0:19889:20165  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 0:19893:19921  "m.count + m.bytesToTake > 32" */ gt(/** @src 0:19893:19916  "m.count + m.bytesToTake" */ checked_add_uint256(_17, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160))), /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 0:19889:20165  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19159:19170  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32), /** @src -1:-1:-1 */ 0)
                                /// @src 0:3954:3956  "22"
                                mstore(zero_struct_Counters_mpos, /** @src 0:20127:20142  "m.weightIndex++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:20127:20142  "m.weightIndex++" */ zero_struct_Counters_mpos)))
                            }
                            default /// @src 0:19889:20165  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 0:19965:19977  "32 - m.count"
                                let _18 := checked_sub_uint256_15118(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128)))
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160), /** @src 0:3954:3956  "22" */ _18)
                                mstore(/** @src 0:19159:19170  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:20003:20031  "m.weightPos += m.bytesToTake" */ checked_add_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19159:19170  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32)), /** @src 0:3954:3956  "22" */ _18))
                            }
                            mstore(/** @src 0:19327:19337  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 0:20186:20301  "m.nextSlot |= bytes32(..." */ or(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19327:19337  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shr(/** @src 0:20266:20277  "8 * m.count" */ checked_mul_uint256_15119(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128))), /** @src 0:3954:3956  "22" */ shl(/** @src 0:20250:20259  "8 * m.pos" */ checked_mul_uint256_15119(/** @src 0:3954:3956  "22" */ mload(/** @src 0:20254:20259  "m.pos" */ _15)), /** @src 0:3954:3956  "22" */ _16))))
                        }
                        mstore(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128), /** @src 0:21075:21099  "m.count += m.bytesToTake" */ checked_add_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128)), /** @src 0:3954:3956  "22" */ mload(/** @src 0:19373:19386  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17412:17434  "_signingPolicy.weights" */ 160))))
                    }
                    /// @src 0:21127:21431  "if (m.count > 0) {..."
                    if /** @src 0:21131:21142  "m.count > 0" */ iszero(iszero(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128))))
                    /// @src 0:21127:21431  "if (m.count > 0) {..."
                    {
                        /// @src 0:21186:21223  "bytes.concat(currentHash, m.nextSlot)"
                        let expr_mpos_2 := bytes_concat_bytes32_bytes32(var_currentHash, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19327:19337  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)))
                        /// @src 0:21162:21224  "currentHash = keccak256(bytes.concat(currentHash, m.nextSlot))"
                        var_currentHash := /** @src 0:21176:21224  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ keccak256(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:21176:21224  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:21176:21224  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2))
                        /// @src 0:21247:21260  "uint256 i = 0"
                        let var_i_1 := /** @src -1:-1:-1 */ 0
                        /// @src 0:21242:21417  "for (uint256 i = 0; i < m.count; i++) {..."
                        for { }
                        /** @src 0:16284:16285  "1" */ 0x01
                        /// @src 0:21247:21260  "uint256 i = 0"
                        {
                            /// @src 0:21275:21278  "i++"
                            var_i_1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:21275:21278  "i++" */ var_i_1, /** @src 0:16284:16285  "1" */ 0x01)
                        }
                        /// @src 0:21275:21278  "i++"
                        {
                            /// @src 0:21262:21273  "i < m.count"
                            if iszero(lt(var_i_1, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19302:19309  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17226:17247  "_signingPolicy.voters" */ 128))))
                            /// @src 0:21262:21273  "i < m.count"
                            { break }
                            /// @src 0:3954:3956  "22"
                            let _19 := mload(/** @src 0:19327:19337  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192))
                            /// @src 0:21343:21356  "m.nextSlot[i]"
                            if iszero(lt(var_i_1, /** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 0:21343:21356  "m.nextSlot[i]"
                            { panic_error_0x32() }
                            /// @src 0:21302:21356  "signingPolicyBytes[m.signingPolicyPos] = m.nextSlot[i]"
                            mstore8(memory_array_index_access_bytes(expr_mpos, /** @src 0:3954:3956  "22" */ mload(/** @src 0:18958:18976  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))), /** @src 0:21343:21356  "m.nextSlot[i]" */ byte(var_i_1, _19))
                            /// @src 0:3954:3956  "22"
                            mstore(/** @src 0:18958:18976  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 0:21378:21398  "m.signingPolicyPos++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:18958:18976  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                        }
                    }
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                sstore(/** @src 0:21450:21506  "toSigningPolicyHashPrivate[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:21477:21505  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ var_currentHash)
                let _20 := cleanup_uint24(mload(/** @src 0:21569:21597  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:21530:21597  "stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId"
                update_storage_value_offsett_uint32_to_uint32(cleanup_uint24(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _20))
                sstore(/** @src 0:21607:21659  "startingVotingRoundIds[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24_15128(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _20), /** @src 0:21607:21695  "startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy.startVotingRoundId" */ cleanup_from_storage_uint32(/** @src 0:3954:3956  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))))
                /// @src 0:21748:21776  "_signingPolicy.rewardEpochId"
                let _21 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:21748:21776  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:21790:21823  "_signingPolicy.startVotingRoundId"
                let _22 := /** @src 0:3954:3956  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:18668:18701  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))
                /// @src 0:21837:21861  "_signingPolicy.threshold"
                let _23 := /** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:17727:17751  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))
                /// @src 0:3954:3956  "22"
                let _24 := mload(/** @src 0:18778:18797  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 0:21908:21929  "_signingPolicy.voters"
                let _mpos_4 := mload(/** @src 0:17226:17247  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 0:21943:21965  "_signingPolicy.weights"
                let _mpos_5 := mload(/** @src 0:17412:17434  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                /// @src 0:21710:22044  "SigningPolicyInitialized(..."
                let _25 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:17727:17751  "_signingPolicy.threshold" */ 64)
                /// @src 0:21710:22044  "SigningPolicyInitialized(..."
                log2(_25, sub(abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(_25, _22, _23, _24, _mpos_4, _mpos_5, expr_mpos, /** @src 0:3954:3956  "22" */ and(/** @src 0:22018:22033  "block.timestamp" */ timestamp(), /** @src 0:3954:3956  "22" */ 0xffffffffffffffff)), /** @src 0:21710:22044  "SigningPolicyInitialized(..." */ _25), 0x91d0280e969157fc6c5b8f952f237b03d934b18534dafcac839075bbc33522f8, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:21710:22044  "SigningPolicyInitialized(..." */ _21, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffff))
                /// @src 0:10090:10091  "_"
                _1 := var_currentHash
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function checked_add_uint32(x) -> sum
            {
                sum := add(and(x, 0xffffffff), 1)
                if gt(sum, 0xffffffff) { panic_error_0x11() }
            }
            function require_helper_stringliteral_d084(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 21)
                    mstore(add(memPtr, 68), "not next reward epoch")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_aacd(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 19)
                    mstore(add(memPtr, 68), "must be non-trivial")
                    revert(memPtr, 100)
                }
            }
            /// @src 0:2485:2488  "300"
            function require_helper_stringliteral_d1bc(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2485:2488  "300"
                    mstore(memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2485:2488  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2485:2488  "300" */ add(memPtr, 36), 15)
                    mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:2485:2488  "300" */ memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 68), /** @src 0:2485:2488  "300" */ "too many voters")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_6b32(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2485:2488  "300"
                    mstore(memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2485:2488  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2485:2488  "300" */ add(memPtr, 36), 13)
                    mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:2485:2488  "300" */ memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 68), /** @src 0:2485:2488  "300" */ "size mismatch")
                    revert(memPtr, 100)
                }
            }
            function memory_array_index_access_uint16_dyn_15113(baseRef) -> addr
            {
                if iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:2485:2488  "300" */ baseRef)) { panic_error_0x32() }
                addr := add(baseRef, 32)
            }
            function memory_array_index_access_uint16_dyn(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:2485:2488  "300" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, shl(5, index)), 32)
            }
            function read_from_memoryt_uint16(ptr) -> returnValue
            {
                returnValue := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:2485:2488  "300" */ mload(ptr), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffff)
            }
            /// @src 0:2485:2488  "300"
            function checked_add_uint256_15112(y) -> sum
            {
                sum := add(/** @src 0:4092:4094  "43" */ 0x2b, /** @src 0:2485:2488  "300" */ y)
                if gt(/** @src 0:4092:4094  "43" */ 0x2b, /** @src 0:2485:2488  "300" */ sum) { panic_error_0x11() }
            }
            function checked_add_uint256_15182(x) -> sum
            {
                sum := add(x, /** @src 0:79745:79763  "merkleRootsPrivate" */ 0x01)
                /// @src 0:2485:2488  "300"
                if gt(x, sum) { panic_error_0x11() }
            }
            function checked_add_uint256(x, y) -> sum
            {
                sum := add(x, y)
                if gt(x, sum) { panic_error_0x11() }
            }
            function require_helper_stringliteral_f10c(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2485:2488  "300"
                    mstore(memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2485:2488  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2485:2488  "300" */ add(memPtr, 36), 20)
                    mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:2485:2488  "300" */ memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 68), /** @src 0:2485:2488  "300" */ "total weight too big")
                    revert(memPtr, 100)
                }
            }
            /// @src 0:2387:2392  "10000"
            function checked_mul_uint256_15107(x) -> product
            {
                product := mul(x, 0x2710)
                if iszero(or(iszero(x), eq(0x2710, div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15108(x) -> product
            {
                product := mul(x, /** @src 0:2540:2544  "5000" */ 0x1388)
                /// @src 0:2387:2392  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:2540:2544  "5000" */ 0x1388, /** @src 0:2387:2392  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15110(x) -> product
            {
                product := mul(x, /** @src 0:2596:2600  "6600" */ 0x19c8)
                /// @src 0:2387:2392  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:2596:2600  "6600" */ 0x19c8, /** @src 0:2387:2392  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15111(x) -> product
            {
                product := mul(x, /** @src 0:3954:3956  "22" */ 0x16)
                /// @src 0:2387:2392  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:3954:3956  "22" */ 0x16, /** @src 0:2387:2392  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15119(y) -> product
            {
                product := shl(3, y)
                if iszero(eq(y, and(y, sub(shl(253, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 1), 1))))
                /// @src 0:2387:2392  "10000"
                { panic_error_0x11() }
            }
            function checked_mul_uint256(x, y) -> product
            {
                product := mul(x, y)
                if iszero(or(iszero(x), eq(y, div(product, x)))) { panic_error_0x11() }
            }
            /// @src 0:2540:2544  "5000"
            function require_helper_stringliteral_d8d1(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2540:2544  "5000"
                    mstore(memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2540:2544  "5000"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2540:2544  "5000" */ add(memPtr, 36), 19)
                    mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:2540:2544  "5000" */ memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 68), /** @src 0:2540:2544  "5000" */ "too small threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 0:2596:2600  "6600"
            function require_helper_stringliteral_185c(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2596:2600  "6600"
                    mstore(memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2596:2600  "6600"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2596:2600  "6600" */ add(memPtr, 36), 17)
                    mstore(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:2596:2600  "6600" */ memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 68), /** @src 0:2596:2600  "6600" */ "too big threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 0:3954:3956  "22"
            function allocate_and_zero_memory_array_bytes(length) -> memPtr
            {
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let _1 := array_allocation_size_bytes(length)
                let memPtr_1 := mload(64)
                finalize_allocation(memPtr_1, _1)
                mstore(memPtr_1, length)
                /// @src 0:3954:3956  "22"
                memPtr := memPtr_1
                calldatacopy(add(memPtr_1, 32), calldatasize(), add(array_allocation_size_bytes(length), /** @src 0:23022:23056  "abi.encode(_config, address(this))" */ not(31)))
            }
            /// @src 0:3954:3956  "22"
            function allocate_and_zero_memory_struct_struct_Counters() -> memPtr
            {
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let memPtr_1 := mload(64)
                let newFreePtr := add(memPtr_1, /** @src 0:3954:3956  "22" */ 288)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1)) { panic_error_0x41() }
                mstore(64, newFreePtr)
                /// @src 0:3954:3956  "22"
                memPtr := memPtr_1
                mstore(memPtr_1, /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 32), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 96), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 128), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 160), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 192), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 224), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 256), /** @src -1:-1:-1 */ 0)
            }
            /// @src 0:3954:3956  "22"
            function convert_uint16_to_bytes2(value) -> converted
            {
                converted := and(shl(240, value), shl(240, 65535))
            }
            function convert_uint24_to_bytes3(value) -> converted
            {
                converted := and(shl(232, value), /** @src 0:24462:73522  "assembly {..." */ shl(232, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 16777215))
            }
            /// @src 0:3954:3956  "22"
            function convert_uint32_to_bytes4(value) -> converted
            {
                converted := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(shl(224, /** @src 0:3954:3956  "22" */ value), shl(224, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
            }
            /// @src 0:3954:3956  "22"
            function read_from_memoryt_address(ptr) -> returnValue
            {
                returnValue := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:3954:3956  "22" */ mload(ptr), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
            }
            /// @src 0:3954:3956  "22"
            function convert_address_to_bytes20(value) -> converted
            {
                converted := and(shl(96, value), not(0xffffffffffffffffffffffff))
            }
            function shift_right_uint16_uint8(value) -> result
            {
                result := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(shr(8, /** @src 0:3954:3956  "22" */ value), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xff)
            }
            /// @src 0:3954:3956  "22"
            function convert_uint8_to_bytes1(value) -> converted
            {
                converted := and(shl(248, value), shl(248, 255))
            }
            function bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(param, param_1, param_2, param_3, param_4, param_5, param_6) -> outPtr
            {
                outPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 0x20), and(param, shl(240, 65535)))
                mstore(add(outPtr, 34), and(param_1, /** @src 0:24462:73522  "assembly {..." */ shl(232, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 16777215)))
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 37), and(param_2, shl(224, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff)))
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 41), and(param_3, shl(240, 65535)))
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                mstore(/** @src 0:3954:3956  "22" */ add(outPtr, 43), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ param_4)
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 75), and(param_5, not(0xffffffffffffffffffffffff)))
                mstore(add(outPtr, 95), and(param_6, shl(248, 255)))
                mstore(outPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64)
                /// @src 0:3954:3956  "22"
                finalize_allocation(outPtr, 96)
            }
            function increment_uint256(value) -> ret
            {
                if eq(value, /** @src 0:24462:73522  "assembly {..." */ not(0))
                /// @src 0:3954:3956  "22"
                { panic_error_0x11() }
                ret := add(value, 1)
            }
            function memory_array_index_access_bytes(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:3954:3956  "22" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, index), 32)
            }
            function read_from_memoryt_bytes1(ptr) -> returnValue
            {
                returnValue := and(mload(ptr), shl(248, 255))
            }
            function shift_left_uint256_uint8(value) -> result
            {
                result := shl(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 96, /** @src 0:3954:3956  "22" */ value)
            }
            function shift_left_uint256_uint8_15122(value) -> result
            {
                result := shl(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 240, /** @src 0:3954:3956  "22" */ value)
            }
            function bytes_concat_bytes32_bytes32(param, param_1) -> outPtr
            {
                outPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                mstore(/** @src 0:3954:3956  "22" */ add(outPtr, 0x20), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ param)
                mstore(/** @src 0:3954:3956  "22" */ add(outPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64), param_1)
                /// @src 0:3954:3956  "22"
                mstore(outPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64)
                /// @src 0:3954:3956  "22"
                finalize_allocation(outPtr, 96)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24(key) -> dataSlot
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:3954:3956  "22" */ key, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffff))
                /// @src 0:3954:3956  "22"
                mstore(0x20, /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                dataSlot := keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:3954:3956  "22" */ 0x40)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24_15128(key) -> dataSlot
            {
                mstore(0, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:3954:3956  "22" */ key, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffff))
                /// @src 0:3954:3956  "22"
                mstore(0x20, /** @src 0:21607:21629  "startingVotingRoundIds" */ 0x02)
                /// @src 0:3954:3956  "22"
                dataSlot := keccak256(0, 0x40)
            }
            function update_storage_value_offsett_uint32_to_uint32(value)
            {
                let _1 := sload(/** @src 0:16245:16254  "stateData" */ 0x07)
                /// @src 0:3954:3956  "22"
                sstore(/** @src 0:16245:16254  "stateData" */ 0x07, /** @src 0:3954:3956  "22" */ or(and(_1, not(shl(152, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:3954:3956  "22" */ and(shl(152, value), shl(152, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))))
            }
            /// @src 0:3954:3956  "22"
            function abi_encode_array_uint16_dyn(value, pos) -> end
            {
                let length := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:3954:3956  "22" */ value)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                mstore(pos, length)
                /// @src 0:3954:3956  "22"
                pos := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(pos, 0x20)
                /// @src 0:3954:3956  "22"
                let srcPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:3954:3956  "22" */ value, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x20)
                /// @src 0:3954:3956  "22"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 0:3954:3956  "22"
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    mstore(pos, and(/** @src 0:3954:3956  "22" */ mload(srcPtr), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffff))
                    /// @src 0:3954:3956  "22"
                    pos := add(pos, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x20)
                    /// @src 0:3954:3956  "22"
                    srcPtr := add(srcPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0x20)
                }
                /// @src 0:3954:3956  "22"
                end := pos
            }
            function abi_encode_uint64(value, pos)
            {
                mstore(pos, and(value, 0xffffffffffffffff))
            }
            function abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(headStart, value0, value1, value2, value3, value4, value5, value6) -> tail
            {
                let tail_1 := add(headStart, 224)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                mstore(headStart, and(value0, 0xffffffff))
                mstore(/** @src 0:3954:3956  "22" */ add(headStart, 32), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(value1, 0xffff))
                mstore(/** @src 0:3954:3956  "22" */ add(headStart, 64), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ value2)
                /// @src 0:3954:3956  "22"
                mstore(add(headStart, 96), 224)
                let pos := tail_1
                let length := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:3954:3956  "22" */ value3)
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                mstore(tail_1, length)
                /// @src 0:3954:3956  "22"
                pos := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:3954:3956  "22" */ headStart, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 256)
                /// @src 0:3954:3956  "22"
                let srcPtr := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 0:3954:3956  "22" */ value3, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    mstore(pos, and(/** @src 0:3954:3956  "22" */ mload(srcPtr), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
                    /// @src 0:3954:3956  "22"
                    pos := add(pos, 32)
                    srcPtr := add(srcPtr, 32)
                }
                mstore(add(headStart, 128), sub(pos, headStart))
                let tail_2 := abi_encode_array_uint16_dyn(value4, pos)
                mstore(add(headStart, 160), sub(tail_2, headStart))
                tail := abi_encode_bytes(value5, tail_2)
                abi_encode_uint64(value6, add(headStart, 192))
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function abi_decode_uint256t_boolt_uint256_fromMemory(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value := mload(headStart)
                value0 := value
                value1 := abi_decode_t_bool_fromMemory(add(headStart, 32))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                value_1 := mload(add(headStart, 64))
                value2 := value_1
            }
            function require_helper_stringliteral_2275(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 16)
                    mstore(add(memPtr, 68), "no random number")
                    revert(memPtr, 100)
                }
            }
            function checked_div_uint256_15178(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := shr(8, x)
            }
            function checked_div_uint256(x, y) -> r
            {
                if iszero(y)
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x12)
                    revert(0, 0x24)
                }
                r := div(x, y)
            }
            function mod_uint256(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := and(x, 255)
            }
            /// @ast-id 1865 @src 0:79092:80280  "function getRandomNumberHistorical(uint256 _votingRoundId)..."
            function fun_getRandomNumberHistorical(var_votingRoundId) -> var_randomNumber, var_isSecureRandom, var_randomTimestamp
            {
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let _1 := and(/** @src 0:79325:79333  "oldRelay" */ loadimmutable("332"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:79325:79420  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:79325:79355  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:79325:79420  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:79359:79420  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:79376:79420  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:79321:79504  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:79443:79493  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _2 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:79443:79493  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    mstore(_2, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(227, 0x150fe287))
                    /// @src 0:79443:79493  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_bytes32(add(_2, 4), var_votingRoundId), _2), _2, 96)
                    if iszero(_3) { revert_forward() }
                    let expr_component := /** @src 0:79352:79353  "0" */ 0x00
                    let expr_component_1 := 0x00
                    let expr_component_2 := 0x00
                    /// @src 0:79443:79493  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    if _3
                    {
                        let _4 := 96
                        if gt(96, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        let expr_component_3, expr_component_4, expr_component_5 := abi_decode_uint256t_boolt_uint256_fromMemory(_2, add(_2, _4))
                        expr_component := expr_component_3
                        expr_component_1 := expr_component_4
                        expr_component_2 := expr_component_5
                    }
                    /// @src 0:79436:79493  "return oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    var_randomNumber := expr_component
                    var_isSecureRandom := expr_component_1
                    var_randomTimestamp := expr_component_2
                    leave
                }
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                let _5 := sload(/** @src 0:79764:79773  "stateData" */ 0x07)
                /// @src 0:79724:79869  "require(..."
                require_helper_stringliteral_2275(/** @src 0:79745:79827  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ sload(/** @src 0:79745:79813  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:79745:79797  "merkleRootsPrivate[stateData.randomNumberProtocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint8_15176(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_uint8(_5)), /** @src 0:79745:79813  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ var_votingRoundId)))))
                /// @src 0:79879:79932  "_randomNumber = toRandomNumberPrivate[_votingRoundId]"
                var_randomNumber := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sload(/** @src 0:79895:79932  "toRandomNumberPrivate[_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15177(var_votingRoundId))
                /// @src 0:79942:80106  "_isSecureRandom =..."
                var_isSecureRandom := /** @src 0:79972:80106  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))..." */ eq(/** @src 0:79972:80067  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))" */ and(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ shr(/** @src 0:80017:80043  "255 - _votingRoundId % 256" */ checked_sub_uint256_15181(/** @src 0:80023:80043  "_votingRoundId % 256" */ mod_uint256(var_votingRoundId)), /** @src 0:397:82971  "contract Relay is IIRelay {..." */ sload(/** @src 0:79973:80012  "isSecureRandomMap[_votingRoundId / 256]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15179(/** @src 0:79991:80011  "_votingRoundId / 256" */ checked_div_uint256_15178(var_votingRoundId)))), /** @src 0:79745:79763  "merkleRootsPrivate" */ 0x01), 0x01)
                /// @src 0:80147:80180  "stateData.firstVotingRoundStartTs"
                let _6 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_1t_uint32(_5)
                /// @src 0:80203:80221  "_votingRoundId + 1"
                let expr_1 := checked_add_uint256_15182(var_votingRoundId)
                /// @src 0:80116:80273  "_randomTimestamp =..."
                var_randomTimestamp := /** @src 0:80147:80273  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ and(/** @src 0:80147:80273  "stateData.firstVotingRoundStartTs +..." */ _6, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff), /** @src 0:80195:80273  "uint256(_votingRoundId + 1) *..." */ checked_mul_uint256(expr_1, extract_from_storage_value_offsett_uint8(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_5t_uint8(_5))))
            }
            function abi_encode_stringliteral_0d64(headStart) -> tail
            {
                mstore(headStart, 32)
                mstore(add(headStart, 32), 17)
                mstore(add(headStart, 64), "Not enough weight")
                tail := add(headStart, 96)
            }
            /// @src 0:24462:73522  "assembly {..."
            function usr$revertWithMessage_15055(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy metadata")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15056(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy length")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15058(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Signing policy hash mismatch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15059(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "Too short message")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15060(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Already relayed")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15061(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "Wrong message format")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15063(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Wrong message format2")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15064(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong sign policy reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15065(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Message too old")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15066(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "Delayed sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15068(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Must use new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15071(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Sign policy relay disabled")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15072(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 23)
                mstore(add(usr_memPtr, 0x44), "No new sign policy size")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15073(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "must be non-trivial")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15074(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "too many voters")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15075(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong size for new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15077(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Not with last intialized")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15078(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not next reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15080(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "No signature count")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15081(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not enough signatures")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15082(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of range")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15083(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of order")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15084(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad v")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15085(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad s")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15086(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "ecrecover error")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15087(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "ecrecover returned bad data")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15088(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 11)
                mstore(add(usr_memPtr, 0x44), "Zero signer")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15089(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Wrong signature")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15090(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "zero merkle root")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15096(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "This should never happen")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15184(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "total weight too big")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15185(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "too small threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15186(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "too big threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15187(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "No random number")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 22)
                mstore(add(usr_memPtr, 0x44), "Incorrect merkle proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15189(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:24462:73522  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "Invalid random number proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$assignStruct(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, /** @src 0:3954:3956  "22" */ not(shl(152, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:24462:73522  "assembly {..." */ shl(152, usr$newVal))
            }
            function usr$assignStruct_15094(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(112, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:24462:73522  "assembly {..." */ shl(112, usr$newVal))
            }
            function usr$assignStruct_15095(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(144, /** @src 0:3954:3956  "22" */ 255))), /** @src 0:24462:73522  "assembly {..." */ shl(144, usr$newVal))
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
                    mstore(_1, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:24462:73522  "assembly {..."
                    mstore(add(_1, 0x04), 0x20)
                    mstore(add(_1, 0x24), 23)
                    mstore(add(_1, 0x44), "Invalid voting round id")
                    revert(_1, 0x64)
                }
                usr_rewardEpochId := div(sub(usr$_votingRoundId, usr$firstRewardEpochStartVotingRoundId), and(shr(80, usr_stateDataObj), 65535))
            }
            function usr$calculateSigningPolicyHash_15057(usr_memPos, usr_policyLength) -> usr_policyHash
            {
                calldatacopy(usr_memPos, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 4, /** @src 0:24462:73522  "assembly {..." */ 32)
                let usr$endPos := add(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ 4, /** @src 0:24462:73522  "assembly {..." */ and(usr_policyLength, /** @src 0:23022:23056  "abi.encode(_config, address(this))" */ not(31)))
                /// @src 0:24462:73522  "assembly {..."
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
            }
            function usr$calculateSigningPolicyHash(usr_memPos, usr_calldataPos, usr_policyLength) -> usr_policyHash
            {
                calldatacopy(usr_memPos, usr_calldataPos, 32)
                let usr$endPos := add(usr_calldataPos, and(usr_policyLength, /** @src 0:23022:23056  "abi.encode(_config, address(this))" */ not(31)))
                /// @src 0:24462:73522  "assembly {..."
                let usr$pos := add(usr_calldataPos, 32)
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
            }
            function usr$extractVotingRoundIdFromMessage(usr_memPtr, usr_signingPolicyLength) -> usr_votingRoundId
            {
                calldatacopy(usr_memPtr, add(4, usr_signingPolicyLength), 6)
                usr_votingRoundId := and(shr(216, mload(usr_memPtr)), 4294967295)
            }
            function usr$checkThresholdConsistency(usr_memPtr, usr_metadata, usr_signingPolicyStart)
            {
                let usr$totalWeight := 0
                let usr$i := 0
                let usr$numberOfVoters := and(shr(72, usr_metadata), 65535)
                for { } lt(usr$i, usr$numberOfVoters) { usr$i := add(usr$i, 1) }
                {
                    mstore(usr_memPtr, 0)
                    calldatacopy(add(usr_memPtr, 30), add(add(usr_signingPolicyStart, mul(usr$i, 22)), 63), 2)
                    usr$totalWeight := add(usr$totalWeight, mload(usr_memPtr))
                }
                if gt(usr$totalWeight, 65535)
                {
                    usr$revertWithMessage_15184(usr_memPtr)
                }
                let _1 := mul(and(usr_metadata, 65535), 10000)
                if lt(_1, mul(usr$totalWeight, 5000))
                {
                    usr$revertWithMessage_15185(usr_memPtr)
                }
                if gt(_1, mul(usr$totalWeight, 6600))
                {
                    usr$revertWithMessage_15186(usr_memPtr)
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
                    usr$revertWithMessage_15187(usr_memPtr)
                }
                if iszero(iszero(and(sub(calldatasize(), usr_proofStart), 31)))
                {
                    usr$revertWithMessage(usr_memPtr)
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
                    usr$revertWithMessage_15189(usr_memPtr)
                }
                calldatacopy(_3, usr_proofStart, 32)
                mstore(usr_memPtr, usr_votingRoundId)
                mstore(_2, 9)
                sstore(keccak256(usr_memPtr, 64), mload(_3))
            }
            /// @src 0:397:82971  "contract Relay is IIRelay {..."
            function require_helper_stringliteral_a3dc(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 19)
                    mstore(add(memPtr, 68), "Invalid config hash")
                    revert(memPtr, 100)
                }
            }
            /// @ast-id 2010 @src 0:81541:82969  "function _verifyCustomSignature(..."
            function fun_verifyCustomSignature(var_relayMessage_offset, var_relayMessage_length, var_messageHash) -> var_rewardEpochId
            {
                /// @src 0:81848:81881  "address(this).call(_relayMessage)"
                let _1 := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(64)
                calldatacopy(_1, var_relayMessage_offset, var_relayMessage_length)
                let _2 := add(_1, var_relayMessage_length)
                mstore(_2, /** @src -1:-1:-1 */ 0)
                /// @src 0:81848:81881  "address(this).call(_relayMessage)"
                let expr_1975_component := call(gas(), /** @src 0:81856:81860  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 0:81848:81881  "address(this).call(_relayMessage)" */ _1, sub(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ _2, /** @src 0:81848:81881  "address(this).call(_relayMessage)" */ _1), /** @src -1:-1:-1 */ 0, 0)
                /// @src 0:81848:81881  "address(this).call(_relayMessage)"
                let expr_component_mpos := extract_returndata()
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                if iszero(expr_1975_component)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 19)
                    mstore(add(memPtr, 68), "Verification failed")
                    revert(memPtr, 100)
                }
                if iszero(/** @src 0:82483:82506  "returnData.length == 35" */ eq(/** @src 0:397:82971  "contract Relay is IIRelay {..." */ mload(/** @src 0:82483:82500  "returnData.length" */ expr_component_mpos), /** @src 0:82504:82506  "35" */ 0x23))
                /// @src 0:397:82971  "contract Relay is IIRelay {..."
                {
                    let memPtr_1 := mload(64)
                    mstore(memPtr_1, shl(229, 4594637))
                    mstore(add(memPtr_1, 4), 32)
                    mstore(add(memPtr_1, 36), 23)
                    mstore(add(memPtr_1, 68), "Wrong verification data")
                    revert(memPtr_1, 100)
                }
                /// @src 0:82665:82850  "assembly {..."
                let var_returnHash := mload(add(expr_component_mpos, 0x20))
                let var_returnRewardEpochId := shr(232, mload(add(expr_component_mpos, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 64)))
                /// @src 0:82859:82926  "require(bytes32(returnHash) == _messageHash, \"Invalid config hash\")"
                require_helper_stringliteral_a3dc(/** @src 0:82867:82902  "bytes32(returnHash) == _messageHash" */ eq(var_returnHash, var_messageHash))
                /// @src 0:82936:82962  "return returnRewardEpochId"
                var_rewardEpochId := var_returnRewardEpochId
            }
            /// @ast-id 2527 @src 5:4637:4809  "function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {..."
            function fun_verifyCalldata(var_proof_offset, var_proof_2510_length, var_root, var_leaf) -> var
            {
                /// @src 5:5324:5351  "bytes32 computedHash = leaf"
                let var_computedHash := var_leaf
                /// @src 5:5366:5379  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 5:5361:5495  "for (uint256 i = 0; i < proof.length; i++) {..."
                for { }
                /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 1
                /// @src 5:5366:5379  "uint256 i = 0"
                {
                    /// @src 5:5399:5402  "i++"
                    var_i := /** @src 0:397:82971  "contract Relay is IIRelay {..." */ add(/** @src 5:5399:5402  "i++" */ var_i, /** @src 0:397:82971  "contract Relay is IIRelay {..." */ 1)
                }
                /// @src 5:5399:5402  "i++"
                {
                    /// @src 5:5381:5397  "i < proof.length"
                    let _1 := iszero(lt(var_i, /** @src 5:5385:5397  "proof.length" */ var_proof_2510_length))
                    /// @src 5:5381:5397  "i < proof.length"
                    if _1 { break }
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    _1 := /** @src -1:-1:-1 */ 0
                    /// @src 5:5475:5483  "proof[i]"
                    let value := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:82971  "contract Relay is IIRelay {..."
                    value := calldataload(add(var_proof_offset, shl(5, var_i)))
                    /// @src 4:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    let expr := /** @src -1:-1:-1 */ 0
                    /// @src 4:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    switch /** @src 4:605:610  "a < b" */ lt(var_computedHash, value)
                    case /** @src 4:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)" */ 0 {
                        /// @src 4:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 4:889:1024  "assembly (\"memory-safe\") {..." */ value)
                        mstore(0x20, var_computedHash)
                        /// @src 4:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 4:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 4:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    default /// @src 4:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    {
                        /// @src 4:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 4:889:1024  "assembly (\"memory-safe\") {..." */ var_computedHash)
                        mstore(0x20, value)
                        /// @src 4:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 4:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 4:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    /// @src 5:5418:5484  "computedHash = Hashes.commutativeKeccak256(computedHash, proof[i])"
                    var_computedHash := expr
                }
                /// @src 5:4754:4802  "return processProofCalldata(proof, leaf) == root"
                var := /** @src 5:4761:4802  "processProofCalldata(proof, leaf) == root" */ eq(var_computedHash, var_root)
            }
        }
        data ".metadata" hex"a264697066735822122038f06f786e6e260ecdfe827424af4203af87ffade17082341502a6919b2e2eed64736f6c634300081b0033"
    }
}
