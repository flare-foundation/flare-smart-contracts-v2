/// @use-src 0:"contracts/governance/GSSGovernance.sol", 2:"contracts/protocol/implementation/Relay.sol", 3:"contracts/protocol/interface/IIRelay.sol", 4:"contracts/userInterfaces/IRelay.sol", 5:"contracts/userInterfaces/IRelayGovernance.sol", 6:"contracts/userInterfaces/LTS/RandomNumberV2Interface.sol"
object "Relay_3237" {
    code {
        {
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            mstore(64, memoryguard(0x0140))
            if callvalue() { revert(0, 0) }
            let programSize := datasize("Relay_3237")
            let argSize := sub(codesize(), programSize)
            finalize_allocation(memoryguard(0x0140), argSize)
            codecopy(memoryguard(0x0140), programSize, argSize)
            if slt(sub(add(memoryguard(0x0140), argSize), memoryguard(0x0140)), 96)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let offset := mload(memoryguard(0x0140))
            if gt(offset, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            if slt(sub(add(memoryguard(0x0140), argSize), add(memoryguard(0x0140), offset)), 0x0240)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let memPtr := mload(64)
            let newFreePtr := add(memPtr, 0x0240)
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
            }
            mstore(64, newFreePtr)
            mstore(memPtr, abi_decode_uint32_fromMemory(add(memoryguard(0x0140), offset)))
            let _1 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0140), offset), 32))
            mstore(add(memPtr, 32), _1)
            let value := mload(add(add(memoryguard(0x0140), offset), 64))
            mstore(add(memPtr, 64), value)
            let _2 := abi_decode_uint8_fromMemory(add(add(memoryguard(0x0140), offset), 96))
            mstore(add(memPtr, 96), _2)
            let _3 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0140), offset), 128))
            mstore(add(memPtr, 128), _3)
            let _4 := abi_decode_uint8_fromMemory(add(add(memoryguard(0x0140), offset), 160))
            mstore(add(memPtr, 160), _4)
            let _5 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0140), offset), 192))
            mstore(add(memPtr, 192), _5)
            let _6 := abi_decode_uint16_fromMemory(add(add(memoryguard(0x0140), offset), 224))
            mstore(add(memPtr, 224), _6)
            let _7 := abi_decode_uint16_fromMemory(add(add(memoryguard(0x0140), offset), 256))
            mstore(add(memPtr, 256), _7)
            let _8 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0140), offset), 288))
            mstore(add(memPtr, 288), _8)
            let value_1 := mload(add(add(memoryguard(0x0140), offset), 320))
            if iszero(eq(value_1, and(value_1, sub(shl(160, 1), 1))))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            mstore(add(memPtr, 320), value_1)
            let offset_1 := mload(add(add(memoryguard(0x0140), offset), 352))
            if gt(offset_1, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            if iszero(slt(add(add(add(memoryguard(0x0140), offset), offset_1), 31), add(memoryguard(0x0140), argSize)))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let length := mload(add(add(memoryguard(0x0140), offset), offset_1))
            let _9 := array_allocation_size_array_struct_FeeConfig_dyn(length)
            let memPtr_1 := mload(64)
            finalize_allocation(memPtr_1, _9)
            let dst := memPtr_1
            mstore(memPtr_1, length)
            dst := add(memPtr_1, 32)
            let srcEnd := add(add(add(add(memoryguard(0x0140), offset), offset_1), shl(6, length)), 32)
            if gt(srcEnd, add(memoryguard(0x0140), argSize))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let src := add(add(add(memoryguard(0x0140), offset), offset_1), 32)
            for { } lt(src, srcEnd) { src := add(src, 64) }
            {
                if slt(sub(add(memoryguard(0x0140), argSize), src), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPtr_2 := mload(64)
                let newFreePtr_1 := add(memPtr_2, 64)
                if or(gt(newFreePtr_1, sub(shl(64, 1), 1)), lt(newFreePtr_1, memPtr_2))
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
                }
                mstore(64, newFreePtr_1)
                mstore(memPtr_2, abi_decode_uint8_fromMemory(src))
                mstore(add(memPtr_2, 32), mload(add(src, 32)))
                mstore(dst, memPtr_2)
                dst := add(dst, 32)
            }
            mstore(add(memPtr, 352), memPtr_1)
            let value_2 := mload(add(add(memoryguard(0x0140), offset), 384))
            mstore(add(memPtr, 384), value_2)
            let _10 := abi_decode_address_fromMemory(add(add(memoryguard(0x0140), offset), 416))
            mstore(add(memPtr, 416), _10)
            let value_3 := mload(add(add(memoryguard(0x0140), offset), 448))
            mstore(add(memPtr, 448), value_3)
            let offset_2 := mload(add(add(memoryguard(0x0140), offset), 480))
            if gt(offset_2, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            if iszero(slt(add(add(add(memoryguard(0x0140), offset), offset_2), 31), add(memoryguard(0x0140), argSize)))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let length_1 := mload(add(add(memoryguard(0x0140), offset), offset_2))
            let _11 := array_allocation_size_array_struct_FeeConfig_dyn(length_1)
            let memPtr_3 := mload(64)
            finalize_allocation(memPtr_3, _11)
            let dst_1 := memPtr_3
            mstore(memPtr_3, length_1)
            dst_1 := add(memPtr_3, 32)
            if gt(add(add(add(add(memoryguard(0x0140), offset), offset_2), shl(5, length_1)), 32), add(memoryguard(0x0140), argSize))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let src_1 := add(add(add(memoryguard(0x0140), offset), offset_2), 32)
            for { }
            lt(src_1, add(add(add(add(memoryguard(0x0140), offset), offset_2), shl(5, length_1)), 32))
            { src_1 := add(src_1, 32) }
            {
                mstore(dst_1, abi_decode_address_fromMemory(src_1))
                dst_1 := add(dst_1, 32)
            }
            mstore(add(memPtr, 480), memPtr_3)
            let value_4 := mload(add(add(memoryguard(0x0140), offset), 512))
            mstore(add(memPtr, 512), value_4)
            let value_5 := mload(add(add(memoryguard(0x0140), offset), 544))
            mstore(add(memPtr, 544), value_5)
            let value1 := abi_decode_address_fromMemory(add(memoryguard(0x0140), 32))
            let value_6 := mload(add(memoryguard(0x0140), 64))
            if iszero(eq(value_6, and(value_6, sub(shl(160, 1), 1))))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:2895:2900  "10000"
            if /** @src 2:11989:12043  "_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS" */ lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(mload(add(memPtr, 256)), 0xffff), /** @src 2:2895:2900  "10000" */ 0x2710)
            {
                let memPtr_4 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_4, shl(229, 4594637))
                mstore(add(memPtr_4, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_4, 36), 28)
                mstore(add(memPtr_4, 68), "threshold increase too small")
                revert(memPtr_4, 100)
            }
            if /** @src 2:12196:12248  "_initialConfig.rewardEpochDurationInVotingEpochs > 0" */ iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(mload(add(memPtr, 224)), 0xffff))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_5 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_5, shl(229, 4594637))
                mstore(add(memPtr_5, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_5, 36), 26)
                mstore(add(memPtr_5, 68), "reward epoch duration zero")
                revert(memPtr_5, 100)
            }
            if /** @src 2:12297:12342  "_initialConfig.votingEpochDurationSeconds > 0" */ iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 160)), 0xff))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_6 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_6, shl(229, 4594637))
                mstore(add(memPtr_6, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_6, 36), 26)
                mstore(add(memPtr_6, 68), "voting epoch duration zero")
                revert(memPtr_6, 100)
            }
            if /** @src 2:12833:12886  "_initialConfig.initialSigningPolicyHash != bytes32(0)" */ iszero(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 64)))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_7 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_7, shl(229, 4594637))
                mstore(add(memPtr_7, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_7, 36), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_7, 68), "initial signing policy hash zero")
                revert(memPtr_7, 100)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let cleaned := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 192)), 0xffffffff)
            let cleaned_1 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:13018:13053  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
            /// @src 2:2895:2900  "10000"
            let product_raw := mul(cleaned_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(mload(add(memPtr, 224)), 0xffff))
            /// @src 2:2895:2900  "10000"
            let product := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ product_raw, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
            /// @src 2:2895:2900  "10000"
            if iszero(eq(product, product_raw))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2895:2900  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
            }
            let sum := add(cleaned, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ product)
            /// @src 2:2895:2900  "10000"
            if gt(sum, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
            /// @src 2:2895:2900  "10000"
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2895:2900  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
            }
            if /** @src 2:12954:13179  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:12954:13179  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ sum, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 32)), 0xffffffff))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_8 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_8, shl(229, 4594637))
                mstore(add(memPtr_8, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_8, 36), 40)
                mstore(add(memPtr_8, 68), "invalid initial starting voting ")
                mstore(add(memPtr_8, 100), "round id")
                revert(memPtr_8, 132)
            }
            /// @src 2:13255:13313  "initialRewardEpochId = _initialConfig.initialRewardEpochId"
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 256, and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:13278:13313  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            /// @src 2:13323:13441  "startingVotingRoundIdForInitialRewardEpochId =..."
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 288, and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 32)), 0xffffffff))
            let _12 := and(/** @src 2:2895:2900  "10000" */ value1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:13451:13493  "signingPolicySetter = _signingPolicySetter" */ 0x03, /** @src 2:2895:2900  "10000" */ or(and(sload(/** @src 2:13451:13493  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 2:2895:2900  "10000" */ not(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))), /** @src 2:2895:2900  "10000" */ _12))
            let _13 := mload(/** @src 2:13984:14019  "_initialConfig.initialRewardEpochId" */ memPtr)
            /// @src 2:2895:2900  "10000"
            let _14 := sload(/** @src 2:13945:13954  "stateData" */ 0x0d)
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:13945:13954  "stateData" */ 0x0d, /** @src 2:2895:2900  "10000" */ or(and(_14, not(shl(152, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:2895:2900  "10000" */ and(shl(152, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _13), /** @src 2:2895:2900  "10000" */ shl(152, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))))
            let cleaned_2 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 32)), 0xffffffff)
            /// @src 2:2895:2900  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(_13, 0xffffffff))
            /// @src 2:2895:2900  "10000"
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:14029:14051  "startingVotingRoundIds" */ 0x02)
            /// @src 2:2895:2900  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:2895:2900  "10000" */ cleaned_2)
            let _15 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 64))
            /// @src 2:2895:2900  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:14199:14234  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            /// @src 2:2895:2900  "10000"
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src -1:-1:-1 */ 0)
            /// @src 2:2895:2900  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:2895:2900  "10000" */ _15)
            if iszero(/** @src 2:14295:14336  "_initialConfig.randomNumberProtocolId > 1" */ gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 96)), 0xff), 1))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_9 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_9, shl(229, 4594637))
                mstore(add(memPtr_9, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_9, 36), 37)
                mstore(add(memPtr_9, 68), "random number protocol id must b")
                mstore(add(memPtr_9, 100), "e > 1")
                revert(memPtr_9, 132)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let cleaned_3 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 96)), 0xff)
            /// @src 2:2895:2900  "10000"
            let _16 := sload(/** @src 2:13945:13954  "stateData" */ 0x0d)
            /// @src 2:2895:2900  "10000"
            let toInsert := and(shl(8, mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 128))), /** @src 2:2895:2900  "10000" */ 0xffffffff00)
            let toInsert_1 := and(shl(40, mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 160))), /** @src 2:2895:2900  "10000" */ 0xff0000000000)
            let toInsert_2 := and(shl(48, mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 192))), /** @src 2:2895:2900  "10000" */ 0xffffffff000000000000)
            let toInsert_3 := and(shl(80, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(add(memPtr, 224))), /** @src 2:2895:2900  "10000" */ 0xffff00000000000000000000)
            let toInsert_4 := and(shl(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 96, mload(add(memPtr, 256))), /** @src 2:2895:2900  "10000" */ 0xffff000000000000000000000000)
            let toInsert_5 := and(shl(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 192, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 288))), /** @src 2:2895:2900  "10000" */ shl(192, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            /// @src 2:2895:2900  "10000"
            let _17 := or(toInsert_3, and(or(toInsert_2, and(or(toInsert_1, and(or(toInsert, and(or(and(_16, not(0xffffffffffff)), cleaned_3), not(0xffffffff000000000000))), not(0xffff00000000000000000000))), not(0xffff000000000000000000000000))), not(shl(192, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:13945:13954  "stateData" */ 0x0d, /** @src 2:2895:2900  "10000" */ or(or(toInsert_4, _17), toInsert_5))
            /// @src 2:15054:15088  "_signingPolicySetter != address(0)"
            let _18 := iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _12)
            /// @src 2:15054:15088  "_signingPolicySetter != address(0)"
            let expr := iszero(_18)
            /// @src 2:15050:15233  "if (_signingPolicySetter != address(0)) {..."
            if expr
            {
                /// @src 2:2895:2900  "10000"
                if iszero(/** @src 2:15112:15149  "_initialConfig.feeConfigs.length == 0" */ iszero(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:15112:15137  "_initialConfig.feeConfigs" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 352)))))
                /// @src 2:2895:2900  "10000"
                {
                    let memPtr_10 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2895:2900  "10000"
                    mstore(memPtr_10, shl(229, 4594637))
                    mstore(add(memPtr_10, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(add(memPtr_10, 36), 17)
                    mstore(add(memPtr_10, 68), "fee cannot be set")
                    revert(memPtr_10, 100)
                }
                sstore(/** @src 2:13945:13954  "stateData" */ 0x0d, /** @src 2:2895:2900  "10000" */ or(or(toInsert_5, or(toInsert_4, and(_17, not(shl(184, 255))))), shl(184, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)))
            }
            let cleaned_4 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 320)), sub(shl(160, 1), 1))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 5, /** @src 2:2895:2900  "10000" */ or(and(sload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 5), /** @src 2:2895:2900  "10000" */ not(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))), /** @src 2:2895:2900  "10000" */ cleaned_4))
            /// @src 2:15427:15514  "_signingPolicySetter != address(0) || _initialConfig.feeCollectionAddress != address(0)"
            let expr_1 := expr
            if _18
            {
                expr_1 := /** @src 2:15465:15514  "_initialConfig.feeCollectionAddress != address(0)" */ iszero(iszero(cleaned_4))
            }
            /// @src 2:2895:2900  "10000"
            if iszero(expr_1)
            {
                let memPtr_11 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_11, shl(229, 4594637))
                mstore(add(memPtr_11, 4), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_11, 36), 27)
                mstore(add(memPtr_11, 68), "fee collection address zero")
                revert(memPtr_11, 100)
            }
            /// @src 2:15582:15595  "uint256 i = 0"
            let var_i := /** @src -1:-1:-1 */ 0
            /// @src 2:15577:15865  "for (uint256 i = 0; i < _initialConfig.feeConfigs.length; i++) {..."
            for { }
            /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1
            /// @src 2:15582:15595  "uint256 i = 0"
            {
                /// @src 2:15635:15638  "i++"
                var_i := /** @src 2:2895:2900  "10000" */ add(/** @src 2:15635:15638  "i++" */ var_i, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
            }
            /// @src 2:15635:15638  "i++"
            {
                /// @src 2:15601:15626  "_initialConfig.feeConfigs"
                let _mpos := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 352))
                /// @src 2:15597:15633  "i < _initialConfig.feeConfigs.length"
                if iszero(lt(var_i, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:15601:15633  "_initialConfig.feeConfigs.length" */ _mpos)))
                /// @src 2:15597:15633  "i < _initialConfig.feeConfigs.length"
                { break }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let cleaned_5 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:15673:15701  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(_mpos, var_i))), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)
                /// @src 2:2895:2900  "10000"
                if iszero(/** @src 2:15734:15748  "protocolId > 1" */ gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleaned_5, 1))
                /// @src 2:2895:2900  "10000"
                {
                    let memPtr_12 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2895:2900  "10000"
                    mstore(memPtr_12, shl(229, 4594637))
                    mstore(add(memPtr_12, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(add(memPtr_12, 36), 19)
                    mstore(add(memPtr_12, 68), "invalid protocol id")
                    revert(memPtr_12, 100)
                }
                let _19 := mload(/** @src 2:15817:15854  "_initialConfig.feeConfigs[i].feeInWei" */ add(/** @src 2:15817:15845  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(/** @src 2:15817:15842  "_initialConfig.feeConfigs" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 352)), /** @src 2:15817:15845  "_initialConfig.feeConfigs[i]" */ var_i)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                /// @src 2:2895:2900  "10000"
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ cleaned_5)
                mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04)
                /// @src 2:2895:2900  "10000"
                sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:2895:2900  "10000" */ _19)
            }
            let _20 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 384))
            /// @src 2:15998:16078  "_initialConfig.sourceChainId == 0 ? block.chainid : _initialConfig.sourceChainId"
            let expr_2 := /** @src -1:-1:-1 */ 0
            /// @src 2:15998:16078  "_initialConfig.sourceChainId == 0 ? block.chainid : _initialConfig.sourceChainId"
            switch /** @src 2:15998:16031  "_initialConfig.sourceChainId == 0" */ iszero(_20)
            case /** @src 2:15998:16078  "_initialConfig.sourceChainId == 0 ? block.chainid : _initialConfig.sourceChainId" */ 0 { expr_2 := _20 }
            default {
                expr_2 := /** @src 2:16034:16047  "block.chainid" */ chainid()
            }
            /// @src 2:15982:16078  "sourceChainId = _initialConfig.sourceChainId == 0 ? block.chainid : _initialConfig.sourceChainId"
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 128, /** @src 2:15982:16078  "sourceChainId = _initialConfig.sourceChainId == 0 ? block.chainid : _initialConfig.sourceChainId" */ expr_2)
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let cleaned_6 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 416)), sub(shl(160, 1), 1))
            /// @src 2:16088:16134  "governanceSafe = _initialConfig.governanceSafe"
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 160, /** @src 2:2895:2900  "10000" */ cleaned_6)
            let _21 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 448))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:16144:16200  "governanceThreshold = _initialConfig.governanceThreshold" */ 0x09, /** @src 2:2895:2900  "10000" */ _21)
            let _22 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 512))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:16210:16284  "activeOwnerConfigSafeNonce = _initialConfig.governanceOwnerConfigSafeNonce" */ 0x07, /** @src 2:2895:2900  "10000" */ _22)
            let _23 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 544))
            /// @src 2:2895:2900  "10000"
            sstore(8, _23)
            /// @src 2:16364:16422  "governanceReplayFloor = _initialConfig.governanceSafeNonce"
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 192, /** @src 2:2895:2900  "10000" */ _23)
            /// @src 2:16578:16606  "governanceSafe != address(0)"
            let _24 := iszero(cleaned_6)
            /// @src 2:16578:16646  "governanceSafe != address(0) ||..."
            let expr_3 := /** @src 2:16578:16606  "governanceSafe != address(0)" */ iszero(_24)
            /// @src 2:16578:16646  "governanceSafe != address(0) ||..."
            if _24
            {
                expr_3 := /** @src 2:16622:16646  "governanceThreshold != 0" */ iszero(iszero(_21))
            }
            /// @src 2:16578:16705  "governanceSafe != address(0) ||..."
            let expr_4 := expr_3
            if iszero(expr_3)
            {
                expr_4 := /** @src 2:16662:16705  "_initialConfig.governanceOwners.length != 0" */ iszero(iszero(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:16662:16693  "_initialConfig.governanceOwners" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480)))))
            }
            /// @src 2:16578:16752  "governanceSafe != address(0) ||..."
            let expr_5 := expr_4
            if iszero(expr_4)
            {
                expr_5 := /** @src 2:16721:16752  "activeOwnerConfigSafeNonce != 0" */ iszero(iszero(_22))
            }
            /// @src 2:16578:16796  "governanceSafe != address(0) ||..."
            let expr_6 := expr_5
            if iszero(expr_5)
            {
                expr_6 := /** @src 2:16768:16796  "lastGovernanceSafeNonce != 0" */ iszero(iszero(_23))
            }
            /// @src 2:16806:18181  "if (hasGovernanceConfiguration) {..."
            if expr_6
            {
                /// @src 2:16956:17055  "if (governanceSafe == address(0)) {..."
                if /** @src 2:16960:16988  "governanceSafe == address(0)" */ _24
                /// @src 2:16956:17055  "if (governanceSafe == address(0)) {..."
                {
                    /// @src 2:17015:17040  "InvalidGovernanceSource()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17015:17040  "InvalidGovernanceSource()" */ shl(224, 0x50b23415))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:17072:17141  "_signingPolicySetter != address(0) || _oldRelay != IRelay(address(0))"
                let expr_7 := expr
                if _18
                {
                    expr_7 := /** @src 2:17110:17141  "_oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value_6, sub(shl(160, 1), 1))))
                }
                /// @src 2:17068:17212  "if (_signingPolicySetter != address(0) || _oldRelay != IRelay(address(0))) {..."
                if expr_7
                {
                    /// @src 2:17168:17197  "InvalidGovernanceDeployment()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17168:17197  "InvalidGovernanceDeployment()" */ shl(224, 0x352869e1))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:17225:17370  "if (_initialConfig.governanceOwners.length > MAX_GOVERNANCE_OWNERS) {..."
                if /** @src 2:17229:17291  "_initialConfig.governanceOwners.length > MAX_GOVERNANCE_OWNERS" */ gt(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:17229:17260  "_initialConfig.governanceOwners" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480))), 256)
                /// @src 2:17225:17370  "if (_initialConfig.governanceOwners.length > MAX_GOVERNANCE_OWNERS) {..."
                {
                    /// @src 2:17318:17355  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17318:17355  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:17383:17516  "if (activeOwnerConfigSafeNonce > governanceReplayFloor) {..."
                if /** @src 2:17387:17437  "activeOwnerConfigSafeNonce > governanceReplayFloor" */ gt(_22, _23)
                /// @src 2:17383:17516  "if (activeOwnerConfigSafeNonce > governanceReplayFloor) {..."
                {
                    /// @src 2:17464:17501  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17318:17355  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    /// @src 2:17464:17501  "InvalidGovernanceOwnerConfiguration()"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:17555:17586  "_initialConfig.governanceOwners"
                let _mpos_1 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480))
                /// @src 2:36617:36630  "owners.length"
                let expr_8 := /** @src 2:2895:2900  "10000" */ mload(/** @src 2:36617:36630  "owners.length" */ _mpos_1)
                /// @src 2:36617:36653  "owners.length == 0 || threshold == 0"
                let expr_9 := /** @src 2:36617:36635  "owners.length == 0" */ iszero(expr_8)
                /// @src 2:36617:36653  "owners.length == 0 || threshold == 0"
                if iszero(expr_9)
                {
                    expr_9 := /** @src 2:36639:36653  "threshold == 0" */ iszero(_21)
                }
                /// @src 2:36617:36682  "owners.length == 0 || threshold == 0 || threshold > owners.length"
                let expr_10 := expr_9
                if iszero(expr_9)
                {
                    expr_10 := /** @src 2:36657:36682  "threshold > owners.length" */ gt(_21, expr_8)
                }
                /// @src 2:36613:36753  "if (owners.length == 0 || threshold == 0 || threshold > owners.length) {..."
                if expr_10
                {
                    /// @src 2:36705:36742  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17318:17355  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    /// @src 2:36705:36742  "InvalidGovernanceOwnerConfiguration()"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:36767:36776  "uint256 i"
                let var_i_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:36767:36776  "uint256 i"
                var_i_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:36762:36973  "for (uint256 i; i < owners.length; ++i) {..."
                for { }
                /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1
                /// @src 2:36767:36776  "uint256 i"
                {
                    /// @src 2:36797:36800  "++i"
                    var_i_1 := /** @src 2:2895:2900  "10000" */ add(/** @src 2:36797:36800  "++i" */ var_i_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:36797:36800  "++i"
                {
                    /// @src 2:36778:36795  "i < owners.length"
                    if iszero(lt(var_i_1, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:36782:36795  "owners.length" */ _mpos_1)))
                    /// @src 2:36778:36795  "i < owners.length"
                    { break }
                    /// @src 2:36820:36884  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    let expr_11 := /** @src 2:36820:36843  "owners[i] == address(0)" */ iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:36820:36829  "owners[i]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_1, var_i_1)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 2:36820:36884  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    if iszero(expr_11)
                    {
                        /// @src 2:36848:36883  "i > 0 && owners[i - 1] >= owners[i]"
                        let expr_12 := /** @src 2:36848:36853  "i > 0" */ iszero(iszero(var_i_1))
                        /// @src 2:36848:36883  "i > 0 && owners[i - 1] >= owners[i]"
                        if expr_12
                        {
                            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                            let diff := add(var_i_1, not(0))
                            if gt(diff, var_i_1)
                            {
                                /// @src 2:2895:2900  "10000"
                                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                                /// @src 2:2895:2900  "10000"
                                mstore(/** @src 2:15786:15802  "protocolFeeInWei" */ 0x04, /** @src 2:2895:2900  "10000" */ 0x11)
                                revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
                            }
                            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                            let cleaned_7 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:36857:36870  "owners[i - 1]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_1, /** @src 2:36864:36869  "i - 1" */ diff)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                            /// @src 2:36848:36883  "i > 0 && owners[i - 1] >= owners[i]"
                            expr_12 := /** @src 2:36857:36883  "owners[i - 1] >= owners[i]" */ iszero(lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleaned_7, and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:36874:36883  "owners[i]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_1, var_i_1)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                        }
                        /// @src 2:36820:36884  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                        expr_11 := expr_12
                    }
                    /// @src 2:36816:36963  "if (owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])) {..."
                    if expr_11
                    {
                        /// @src 2:36911:36948  "InvalidGovernanceOwnerConfiguration()"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17318:17355  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                        /// @src 2:36911:36948  "InvalidGovernanceOwnerConfiguration()"
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04)
                    }
                }
                /// @src 2:17627:17636  "uint256 i"
                let var_i_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:17627:17636  "uint256 i"
                var_i_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:17622:17777  "for (uint256 i; i < _initialConfig.governanceOwners.length; ++i) {..."
                for { }
                /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1
                /// @src 2:17627:17636  "uint256 i"
                {
                    /// @src 2:17682:17685  "++i"
                    var_i_2 := /** @src 2:2895:2900  "10000" */ add(/** @src 2:17682:17685  "++i" */ var_i_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:17682:17685  "++i"
                {
                    /// @src 2:17642:17673  "_initialConfig.governanceOwners"
                    let _mpos_2 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480))
                    /// @src 2:17638:17680  "i < _initialConfig.governanceOwners.length"
                    if iszero(lt(var_i_2, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:17642:17680  "_initialConfig.governanceOwners.length" */ _mpos_2)))
                    /// @src 2:17638:17680  "i < _initialConfig.governanceOwners.length"
                    { break }
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    let cleaned_8 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:17727:17761  "_initialConfig.governanceOwners[i]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_2, var_i_2)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                    /// @src 2:10095:10098  "256"
                    let oldLen := sload(/** @src 2:17705:17721  "governanceOwners" */ 0x0a)
                    /// @src 2:10095:10098  "256"
                    if iszero(lt(oldLen, 18446744073709551616))
                    {
                        /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                        mstore(/** @src 2:15786:15802  "protocolFeeInWei" */ 0x04, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x41)
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
                    }
                    /// @src 2:10095:10098  "256"
                    let _25 := add(oldLen, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                    /// @src 2:10095:10098  "256"
                    sstore(/** @src 2:17705:17721  "governanceOwners" */ 0x0a, /** @src 2:10095:10098  "256" */ _25)
                    if iszero(lt(oldLen, _25))
                    {
                        /// @src 2:2895:2900  "10000"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                        /// @src 2:2895:2900  "10000"
                        mstore(/** @src 2:15786:15802  "protocolFeeInWei" */ 0x04, /** @src 2:2895:2900  "10000" */ 0x32)
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
                    }
                    /// @src 2:10095:10098  "256"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17705:17721  "governanceOwners" */ 0x0a)
                    /// @src 2:10095:10098  "256"
                    let slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32), /** @src 2:10095:10098  "256" */ oldLen)
                    sstore(slot, or(and(sload(slot), /** @src 2:2895:2900  "10000" */ not(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))), /** @src 2:10095:10098  "256" */ cleaned_8))
                }
                /// @src 2:2895:2900  "10000"
                let _26 := sload(/** @src 2:16210:16284  "activeOwnerConfigSafeNonce = _initialConfig.governanceOwnerConfigSafeNonce" */ 0x07)
                /// @src 2:2895:2900  "10000"
                let _27 := sload(/** @src 2:16144:16200  "governanceThreshold = _initialConfig.governanceThreshold" */ 0x09)
                /// @src 2:10095:10098  "256"
                let pos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:10095:10098  "256"
                let memPtr_13 := pos
                let length_2 := sload(/** @src 2:17705:17721  "governanceOwners" */ 0x0a)
                /// @src 2:2895:2900  "10000"
                mstore(pos, length_2)
                /// @src 2:10095:10098  "256"
                pos := /** @src 2:2895:2900  "10000" */ add(pos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                let updated_pos := /** @src 2:10095:10098  "256" */ pos
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17705:17721  "governanceOwners" */ 0x0a)
                /// @src 2:10095:10098  "256"
                let srcPtr := keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:10095:10098  "256"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 2:10095:10098  "256"
                for { }
                lt(i, length_2)
                {
                    i := add(i, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:10095:10098  "256"
                {
                    mstore(pos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ sload(srcPtr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 2:10095:10098  "256"
                    pos := add(pos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:10095:10098  "256"
                    srcPtr := add(srcPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:10095:10098  "256"
                finalize_allocation(memPtr_13, sub(pos, memPtr_13))
                /// @src 2:2895:2900  "10000"
                let _28 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 128)
                let cleaned_9 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 160), sub(shl(160, 1), 1))
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                let expr_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                let _29 := add(expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 0:224:379  "keccak256(..."
                let tail := add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 224)
                /// @src 2:10095:10098  "256"
                mstore(_29, /** @src 0:224:379  "keccak256(..." */ 0xe0928e00f77af6dd5036aaeb1b692b0989112348ea8aba90009b7e6d3260f0fe)
                /// @src 2:10095:10098  "256"
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:10095:10098  "256" */ _28)
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 96), cleaned_9)
                /// @src 2:10095:10098  "256"
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 128), /** @src 2:10095:10098  "256" */ _26)
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 160), /** @src 2:10095:10098  "256" */ _27)
                /// @src 0:224:379  "keccak256(..."
                mstore(add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 192), 192)
                /// @src 0:224:379  "keccak256(..."
                let pos_1 := tail
                let length_3 := /** @src 2:2895:2900  "10000" */ mload(/** @src 0:224:379  "keccak256(..." */ memPtr_13)
                /// @src 2:2895:2900  "10000"
                mstore(tail, length_3)
                /// @src 0:224:379  "keccak256(..."
                pos_1 := /** @src 2:2895:2900  "10000" */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 256)
                /// @src 0:224:379  "keccak256(..."
                let srcPtr_1 := updated_pos
                let i_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:224:379  "keccak256(..."
                for { }
                lt(i_1, length_3)
                {
                    i_1 := add(i_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 0:224:379  "keccak256(..."
                {
                    /// @src 2:10095:10098  "256"
                    mstore(pos_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 0:224:379  "keccak256(..." */ mload(srcPtr_1), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 0:224:379  "keccak256(..."
                    pos_1 := /** @src 2:10095:10098  "256" */ add(pos_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 0:224:379  "keccak256(..."
                    srcPtr_1 := add(srcPtr_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                }
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                let _30 := sub(pos_1, expr_mpos)
                mstore(expr_mpos, add(_30, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                finalize_allocation(expr_mpos, _30)
                /// @src 0:599:701  "return keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners))"
                let var := /** @src 0:606:701  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners))" */ keccak256(/** @src 0:224:379  "keccak256(..." */ _29, /** @src 2:2895:2900  "10000" */ mload(/** @src 0:606:701  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners))" */ expr_mpos))
                /// @src 2:2895:2900  "10000"
                sstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 6, /** @src 2:2895:2900  "10000" */ var)
                let _31 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 192)
                /// @src 2:17942:18170  "GovernanceInitialized(..."
                let _32 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:10095:10098  "256"
                let tail_1 := add(_32, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 128)
                /// @src 2:10095:10098  "256"
                mstore(_32, _26)
                mstore(add(_32, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32), /** @src 2:10095:10098  "256" */ _31)
                mstore(add(_32, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:10095:10098  "256" */ _27)
                mstore(add(_32, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 96), 128)
                /// @src 2:10095:10098  "256"
                let pos_2 := tail_1
                /// @src 2:2895:2900  "10000"
                mstore(tail_1, length_2)
                /// @src 2:10095:10098  "256"
                pos_2 := /** @src 2:2895:2900  "10000" */ add(/** @src 2:10095:10098  "256" */ _32, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 160)
                /// @src 2:10095:10098  "256"
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:17705:17721  "governanceOwners" */ 0x0a)
                /// @src 2:10095:10098  "256"
                let srcPtr_2 := keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:10095:10098  "256"
                let i_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:10095:10098  "256"
                for { }
                lt(i_2, length_2)
                {
                    i_2 := add(i_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:10095:10098  "256"
                {
                    mstore(pos_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ sload(srcPtr_2), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 2:10095:10098  "256"
                    pos_2 := add(pos_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:10095:10098  "256"
                    srcPtr_2 := add(srcPtr_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:17942:18170  "GovernanceInitialized(..."
                log2(_32, sub(pos_2, _32), 0x098e5a4172791950a04e8ca2f87d889f9b5819f37518f3d01b9e17e7861626d2, var)
            }
            /// @src 2:18396:18545  "if (_signingPolicySetter != address(0)) {..."
            if expr
            {
                /// @src 2:2895:2900  "10000"
                let _33 := mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 128)
                /// @src 2:10095:10098  "256"
                if iszero(/** @src 2:18458:18488  "sourceChainId == block.chainid" */ eq(_33, /** @src 2:18475:18488  "block.chainid" */ chainid()))
                /// @src 2:10095:10098  "256"
                {
                    let memPtr_14 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:10095:10098  "256"
                    mstore(memPtr_14, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:10095:10098  "256"
                    mstore(add(memPtr_14, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:10095:10098  "256" */ add(memPtr_14, 36), 41)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:10095:10098  "256" */ memPtr_14, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:10095:10098  "256" */ "source chain id must match on ho")
                    mstore(add(memPtr_14, 100), "me deploy")
                    revert(memPtr_14, 132)
                }
            }
            /// @src 2:18554:18574  "oldRelay = _oldRelay"
            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 224, /** @src 2:18554:18574  "oldRelay = _oldRelay" */ value_6)
            /// @src 2:18665:19978  "if(oldRelay != IIRelay(address(0))) {..."
            if /** @src 2:18668:18699  "oldRelay != IIRelay(address(0))" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value_6, sub(shl(160, 1), 1))))
            /// @src 2:18665:19978  "if(oldRelay != IIRelay(address(0))) {..."
            {
                /// @src 2:18741:18774  "signingPolicySetter != address(0)"
                let _34 := iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ sload(/** @src 2:13451:13493  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                /// @src 2:18741:18822  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                let expr_13 := /** @src 2:18741:18774  "signingPolicySetter != address(0)" */ iszero(_34)
                /// @src 2:18741:18822  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                if expr_13
                {
                    /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                    let _35 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                    mstore(_35, /** @src 2:10095:10098  "256" */ shl(224, 0xa9dbe8ed))
                    /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                    let _36 := staticcall(gas(), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value_6, sub(shl(160, 1), 1)), /** @src 2:18778:18808  "oldRelay.signingPolicySetter()" */ _35, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04, /** @src 2:18778:18808  "oldRelay.signingPolicySetter()" */ _35, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                    if iszero(_36)
                    {
                        /// @src 2:10095:10098  "256"
                        let pos_3 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                        /// @src 2:10095:10098  "256"
                        returndatacopy(pos_3, /** @src -1:-1:-1 */ 0, /** @src 2:10095:10098  "256" */ returndatasize())
                        revert(pos_3, returndatasize())
                    }
                    /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                    let expr_14 := /** @src -1:-1:-1 */ 0
                    /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                    if _36
                    {
                        let _37 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32
                        /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                        if gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:18778:18808  "oldRelay.signingPolicySetter()" */ returndatasize()) { _37 := returndatasize() }
                        finalize_allocation(_35, _37)
                        /// @src 2:10095:10098  "256"
                        if slt(sub(/** @src 2:18778:18808  "oldRelay.signingPolicySetter()" */ add(_35, _37), /** @src 2:10095:10098  "256" */ _35), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                        /// @src 2:10095:10098  "256"
                        {
                            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                            revert(/** @src -1:-1:-1 */ 0, 0)
                        }
                        /// @src 2:18778:18808  "oldRelay.signingPolicySetter()"
                        expr_14 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_address_fromMemory(/** @src 2:10095:10098  "256" */ _35)
                    }
                    /// @src 2:18741:18822  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                    expr_13 := /** @src 2:18778:18822  "oldRelay.signingPolicySetter() != address(0)" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:18778:18822  "oldRelay.signingPolicySetter() != address(0)" */ expr_14, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                }
                /// @src 2:18740:18926  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                let expr_15 := expr_13
                if iszero(expr_13)
                {
                    /// @src 2:18844:18925  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                    let expr_16 := _34
                    if _34
                    {
                        /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                        let cleaned_10 := and(/** @src 2:10095:10098  "256" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 224), sub(shl(160, 1), 1))
                        /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                        let _38 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                        /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                        mstore(_38, /** @src 2:10095:10098  "256" */ shl(224, 0xa9dbe8ed))
                        /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                        let _39 := staticcall(gas(), cleaned_10, _38, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04, /** @src 2:18881:18911  "oldRelay.signingPolicySetter()" */ _38, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                        /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                        if iszero(_39)
                        {
                            /// @src 2:10095:10098  "256"
                            let pos_4 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                            /// @src 2:10095:10098  "256"
                            returndatacopy(pos_4, /** @src -1:-1:-1 */ 0, /** @src 2:10095:10098  "256" */ returndatasize())
                            revert(pos_4, returndatasize())
                        }
                        /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                        let expr_17 := /** @src -1:-1:-1 */ 0
                        /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                        if _39
                        {
                            let _40 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32
                            /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                            if gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:18881:18911  "oldRelay.signingPolicySetter()" */ returndatasize()) { _40 := returndatasize() }
                            finalize_allocation(_38, _40)
                            /// @src 2:10095:10098  "256"
                            if slt(sub(/** @src 2:18881:18911  "oldRelay.signingPolicySetter()" */ add(_38, _40), /** @src 2:10095:10098  "256" */ _38), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                            /// @src 2:10095:10098  "256"
                            {
                                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                                revert(/** @src -1:-1:-1 */ 0, 0)
                            }
                            /// @src 2:18881:18911  "oldRelay.signingPolicySetter()"
                            expr_17 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_address_fromMemory(/** @src 2:10095:10098  "256" */ _38)
                        }
                        /// @src 2:18844:18925  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                        expr_16 := /** @src 2:18881:18925  "oldRelay.signingPolicySetter() == address(0)" */ iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:18881:18925  "oldRelay.signingPolicySetter() == address(0)" */ expr_17, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    }
                    /// @src 2:18740:18926  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                    expr_15 := expr_16
                }
                /// @src 2:10095:10098  "256"
                if iszero(expr_15)
                {
                    let memPtr_15 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:10095:10098  "256"
                    mstore(memPtr_15, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:10095:10098  "256"
                    mstore(add(memPtr_15, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:10095:10098  "256" */ add(memPtr_15, 36), 22)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:10095:10098  "256" */ memPtr_15, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:10095:10098  "256" */ "old relay incompatible")
                    revert(memPtr_15, 100)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let cleaned_11 := and(/** @src 2:10095:10098  "256" */ mload(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 224), sub(shl(160, 1), 1))
                /// @src 2:19269:19289  "oldRelay.stateData()"
                let _41 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:19269:19289  "oldRelay.stateData()"
                mstore(_41, /** @src 2:10095:10098  "256" */ shl(225, 0x0f47d9b5))
                /// @src 2:19269:19289  "oldRelay.stateData()"
                let _42 := staticcall(gas(), cleaned_11, _41, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04, /** @src 2:19269:19289  "oldRelay.stateData()" */ _41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 352)
                /// @src 2:19269:19289  "oldRelay.stateData()"
                if iszero(_42)
                {
                    /// @src 2:10095:10098  "256"
                    let pos_5 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:10095:10098  "256"
                    returndatacopy(pos_5, /** @src -1:-1:-1 */ 0, /** @src 2:10095:10098  "256" */ returndatasize())
                    revert(pos_5, returndatasize())
                }
                let expr_component := /** @src -1:-1:-1 */ 0
                let expr_component_1 := 0
                let expr_component_2 := 0
                let expr_component_3 := 0
                /// @src 2:19269:19289  "oldRelay.stateData()"
                if _42
                {
                    let _43 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 352
                    /// @src 2:19269:19289  "oldRelay.stateData()"
                    if gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _43, /** @src 2:19269:19289  "oldRelay.stateData()" */ returndatasize()) { _43 := returndatasize() }
                    finalize_allocation(_41, _43)
                    /// @src 2:10095:10098  "256"
                    if slt(sub(/** @src 2:19269:19289  "oldRelay.stateData()" */ add(_41, _43), /** @src 2:10095:10098  "256" */ _41), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 352)
                    /// @src 2:10095:10098  "256"
                    {
                        /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    pop(abi_decode_uint8_fromMemory(/** @src 2:10095:10098  "256" */ _41))
                    let value1_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint32_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                    /// @src 2:10095:10098  "256"
                    let value2 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint8_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64))
                    /// @src 2:10095:10098  "256"
                    let value3 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint32_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 96))
                    /// @src 2:10095:10098  "256"
                    let value4 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint16_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 128))
                    pop(abi_decode_uint16_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 160)))
                    pop(abi_decode_uint32_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 192)))
                    /// @src 2:10095:10098  "256"
                    pop(abi_decode_bool_fromMemory(add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 224)))
                    pop(abi_decode_uint32_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 256)))
                    /// @src 2:10095:10098  "256"
                    pop(abi_decode_bool_fromMemory(add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 288)))
                    pop(abi_decode_uint32_fromMemory(/** @src 2:10095:10098  "256" */ add(_41, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 320)))
                    /// @src 2:19269:19289  "oldRelay.stateData()"
                    expr_component := value1_1
                    expr_component_1 := value2
                    expr_component_2 := value3
                    expr_component_3 := value4
                }
                /// @src 2:10095:10098  "256"
                let _44 := sload(/** @src 2:13945:13954  "stateData" */ 0x0d)
                /// @src 2:10095:10098  "256"
                if iszero(/** @src 2:19328:19388  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ eq(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ shr(/** @src 2:2895:2900  "10000" */ 8, /** @src 2:10095:10098  "256" */ _44), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), and(/** @src 2:19328:19388  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ expr_component, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
                /// @src 2:10095:10098  "256"
                {
                    let memPtr_16 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:10095:10098  "256"
                    mstore(memPtr_16, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:10095:10098  "256"
                    mstore(add(memPtr_16, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:10095:10098  "256" */ add(memPtr_16, 36), 14)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:10095:10098  "256" */ memPtr_16, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:10095:10098  "256" */ "wrong start ts")
                    revert(memPtr_16, 100)
                }
                if iszero(/** @src 2:19475:19555  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ eq(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ shr(/** @src 2:2895:2900  "10000" */ 80, /** @src 2:10095:10098  "256" */ _44), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff), and(/** @src 2:19475:19555  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ expr_component_3, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff)))
                /// @src 2:10095:10098  "256"
                {
                    let memPtr_17 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:10095:10098  "256"
                    mstore(memPtr_17, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:10095:10098  "256"
                    mstore(add(memPtr_17, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:10095:10098  "256" */ add(memPtr_17, 36), 27)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:10095:10098  "256" */ memPtr_17, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:10095:10098  "256" */ "wrong reward epoch duration")
                    revert(memPtr_17, 100)
                }
                if iszero(/** @src 2:19655:19737  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ eq(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ shr(/** @src 2:2895:2900  "10000" */ 48, /** @src 2:10095:10098  "256" */ _44), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), and(/** @src 2:19655:19737  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ expr_component_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
                /// @src 2:10095:10098  "256"
                {
                    let memPtr_18 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:10095:10098  "256"
                    mstore(memPtr_18, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:10095:10098  "256"
                    mstore(add(memPtr_18, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:10095:10098  "256" */ add(memPtr_18, 36), 30)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:10095:10098  "256" */ memPtr_18, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:10095:10098  "256" */ "wrong first reward epoch start")
                    revert(memPtr_18, 100)
                }
                if iszero(/** @src 2:19840:19906  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ eq(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ shr(/** @src 2:2895:2900  "10000" */ 40, /** @src 2:10095:10098  "256" */ _44), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff), and(/** @src 2:19840:19906  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ expr_component_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)))
                /// @src 2:10095:10098  "256"
                {
                    let memPtr_19 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:10095:10098  "256"
                    mstore(memPtr_19, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:10095:10098  "256"
                    mstore(add(memPtr_19, /** @src 2:15786:15802  "protocolFeeInWei" */ 0x04), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:10095:10098  "256" */ add(memPtr_19, 36), 27)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:10095:10098  "256" */ memPtr_19, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:10095:10098  "256" */ "wrong voting epoch duration")
                    revert(memPtr_19, 100)
                }
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            let _45 := mload(64)
            let _46 := datasize("Relay_3237_deployed")
            codecopy(_45, dataoffset("Relay_3237_deployed"), _46)
            setimmutable(_45, "471", mload(128))
            setimmutable(_45, "474", mload(160))
            setimmutable(_45, "477", mload(192))
            setimmutable(_45, "537", mload(224))
            setimmutable(_45, "540", mload(256))
            setimmutable(_45, "543", mload(288))
            return(_45, _46)
        }
        function finalize_allocation(memPtr, size)
        {
            let newFreePtr := add(memPtr, and(add(size, 31), not(31)))
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
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
        function array_allocation_size_array_struct_FeeConfig_dyn(length) -> size
        {
            if gt(length, sub(shl(64, 1), 1))
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(0, 0x24)
            }
            size := add(shl(5, length), 0x20)
        }
        function abi_decode_address_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, and(value, sub(shl(160, 1), 1)))) { revert(0, 0) }
        }
        /// @src 2:2895:2900  "10000"
        function memory_array_index_access_struct_FeeConfig_dyn(baseRef, index) -> addr
        {
            if iszero(lt(index, mload(baseRef)))
            {
                mstore(0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2895:2900  "10000"
                mstore(4, 0x32)
                revert(0, 0x24)
            }
            addr := add(add(baseRef, shl(5, index)), 32)
        }
        /// @src 2:10095:10098  "256"
        function abi_decode_bool_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, /** @src 2:2895:2900  "10000" */ iszero(iszero(/** @src 2:10095:10098  "256" */ value)))) { revert(0, 0) }
        }
    }
    /// @use-src 0:"contracts/governance/GSSGovernance.sol", 1:"contracts/governance/GnosisSafeTx.sol", 2:"contracts/protocol/implementation/Relay.sol", 7:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/ECDSA.sol", 8:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/Hashes.sol", 9:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/MerkleProof.sol"
    object "Relay_3237_deployed" {
        code {
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(64, 128)
                if iszero(lt(calldatasize(), 4))
                {
                    switch shr(224, calldataload(0))
                    case 0x0c85bf07 {
                        external_fun_toSigningPolicyHash()
                    }
                    case 0x1544298e { external_fun_sourceChainId() }
                    case 0x1e8fb36a { external_fun_stateData() }
                    case 0x317ad33c { external_fun_isFinalized() }
                    case 0x342ea4de {
                        external_fun_activeOwnerConfigHash()
                    }
                    case 0x35afd54f {
                        external_fun_governanceReplayFloor()
                    }
                    case 0x377c50d4 {
                        external_fun_feeCollectionAddress()
                    }
                    case 0x39436b00 { external_fun_merkleRoots() }
                    case 0x411461ef {
                        external_fun_governanceOwnersLength()
                    }
                    case 0x47e1818b {
                        external_fun_startingVotingRoundIdForInitialRewardEpochId()
                    }
                    case 0x620f5455 {
                        external_fun_lastGovernanceSafeNonce()
                    }
                    case 0x66e37eae {
                        external_fun_governanceThreshold()
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
                    case 0x886a5647 {
                        external_fun_governanceOwner()
                    }
                    case 0x8a7495ac {
                        external_fun_governanceSafeNonceConsumed()
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
                    case 0xa9cf5521 {
                        external_fun_processGSSMessage()
                    }
                    case 0xa9dbe8ed {
                        external_fun_signingPolicySetter()
                    }
                    case 0xab97db37 {
                        external_fun_getVotingRoundId()
                    }
                    case 0xb59589d1 { external_fun_relay() }
                    case 0xbe03338e { external_fun_governanceSafe() }
                    case 0xc956d658 {
                        external_fun_activeOwnerConfigSafeNonce()
                    }
                    case 0xdbdff2c1 {
                        external_fun_getRandomNumber()
                    }
                    case 0xffc1f8ef { external_fun_oldRelay() }
                }
                revert(0, 0)
            }
            function abi_decode_uint256() -> value
            { value := calldataload(4) }
            function abi_decode_uint256_19151() -> value
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                let ret := fun_toSigningPolicyHash(value)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function abi_encode_uint256(value0) -> tail
            {
                tail := 36
                mstore(/** @src 2:28778:28821  "GovernanceNonceAlreadyConsumed(actionNonce)" */ 4, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value0)
            }
            function external_fun_sourceChainId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, /** @src 2:9545:9592  "uint256 public immutable override sourceChainId" */ loadimmutable("471"))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                return(memPos, 32)
            }
            function cleanup_from_storage_uint8(value) -> cleaned
            { cleaned := and(value, 0xff) }
            function cleanup_from_storage_uint32(value) -> cleaned
            {
                cleaned := and(value, 0xffffffff)
            }
            function extract_from_storage_value_offset_1t_uint32(slot_value) -> value
            {
                value := and(shr(8, slot_value), 0xffffffff)
            }
            function extract_from_storage_value_offsett_uint8(slot_value) -> value
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
                let _1 := sload(/** @src 2:10848:10874  "StateData public stateData" */ 13)
                let ret := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_bool(_1)
                /// @src 2:10848:10874  "StateData public stateData"
                let ret_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offset_24t_uint32(_1)
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(36)
                let ret := fun_isFinalized(value, value_1)
                let memPos := mload(64)
                mstore(memPos, iszero(iszero(ret)))
                return(memPos, 32)
            }
            function external_fun_activeOwnerConfigHash()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:9713:9758  "bytes32 public override activeOwnerConfigHash" */ 6)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_governanceReplayFloor()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, /** @src 2:9652:9707  "uint256 public immutable override governanceReplayFloor" */ loadimmutable("477"))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                return(memPos, 32)
            }
            function extract_from_storage_value_dynamict_address_payable(slot_value, offset) -> value
            {
                value := and(shr(shl(3, offset), slot_value), sub(shl(160, 1), 1))
            }
            function cleanup_address_payable(value) -> cleaned
            {
                cleaned := and(value, sub(shl(160, 1), 1))
            }
            function external_fun_feeCollectionAddress()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 2:9290:9333  "address payable public feeCollectionAddress" */ 5), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(36)
                let ret := fun_merkleRoots(value, value_1)
                let memPos := mload(64)
                mstore(memPos, ret)
                return(memPos, 32)
            }
            function external_fun_governanceOwnersLength()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let length := sload(/** @src 2:29886:29902  "governanceOwners" */ 0x0a)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, length)
                return(memPos, 32)
            }
            function external_fun_startingVotingRoundIdForInitialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:11304:11372  "uint32 public immutable startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("543"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function external_fun_lastGovernanceSafeNonce()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:9820:9867  "uint256 public override lastGovernanceSafeNonce" */ 8)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_governanceThreshold()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:9873:9916  "uint256 public override governanceThreshold" */ 9)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_initialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:11201:11245  "uint32 public immutable initialRewardEpochId" */ loadimmutable("540"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19217(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, 0)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19218(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:91945:91963  "merkleRootsPrivate" */ 0x01)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19220(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:90015:90031  "protocolFeeInWei" */ 0x04)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19293(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:94262:94283  "toRandomNumberPrivate" */ 0x0e)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19295(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:94340:94357  "isSecureRandomMap" */ 0x0c)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_19405(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:28715:28742  "governanceSafeNonceConsumed" */ 0x0b)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value)
                mstore(32, /** @src 2:8980:9051  "mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds" */ 2)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x40))
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value0 := abi_decode_uint256()
                let value1 := abi_decode_uint256_19151()
                let value2 := abi_decode_bytes32()
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let length := calldataload(add(4, offset))
                if gt(length, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if gt(add(add(offset, shl(5, length)), 36), calldatasize())
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
            function finalize_allocation_19423(memPtr)
            {
                let newFreePtr := add(memPtr, 96)
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
                finalize_allocation(memPtr, 0xc0)
            }
            function allocate_memory_19417() -> memPtr
            {
                memPtr := mload(64)
                finalize_allocation(memPtr, 320)
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
            function validator_revert_address(value)
            {
                if iszero(eq(value, and(value, sub(shl(160, 1), 1)))) { revert(0, 0) }
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0xc0)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := allocate_memory()
                mstore(value, abi_decode_uint24(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                mstore(add(value, 64), abi_decode_uint16(add(offset, 68)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(add(offset, 100))
                mstore(add(value, 96), value_1)
                let offset_1 := calldataload(add(offset, 132))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(value, 128), abi_decode_array_address_dyn(add(add(offset, offset_1), 4), calldatasize()))
                let offset_2 := calldataload(add(offset, 164))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(value, 160), abi_decode_array_uint16_dyn(add(add(offset, offset_2), 4), calldatasize()))
                /// @src 2:20286:20293  "bytes32"
                let var := modifier_onlySigningPolicySetter(value)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bytes32(memPos, var), memPos))
            }
            function external_fun_governanceOwner()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                if iszero(lt(value, sload(/** @src 2:30020:30036  "governanceOwners" */ 0x0a)))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:30020:30036  "governanceOwners" */ 0x0a)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value_1 := and(sload(add(89717814153306320011181716697424560163256864414616650038987186496166826726056, value)), sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value_1)
                return(memPos, 32)
            }
            function external_fun_governanceSafeNonceConsumed()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value)
                mstore(32, /** @src 2:9962:10040  "mapping(uint256 safeNonce => bool) public override governanceSafeNonceConsumed" */ 11)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value_1 := and(sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x40)), 0xff)
                let memPos := mload(0x40)
                mstore(memPos, iszero(iszero(value_1)))
                return(memPos, 32)
            }
            function external_fun_lastInitializedRewardEpochData()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(152, sload(/** @src 2:95724:95733  "stateData" */ 0x0d)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 2:95843:95865  "startingVotingRoundIds" */ 0x02)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value)
                mstore(32, 4)
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x40))
                let memPos := mload(0x40)
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
            function external_fun_verifyCustomSignature()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value0, value1 := abi_decode_bytes_calldata(add(4, offset), calldatasize())
                let value2 := abi_decode_uint256_19151()
                /// @src 2:96215:96248  "address(this).call(_relayMessage)"
                let _1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                calldatacopy(_1, value0, value1)
                let _2 := add(_1, value1)
                mstore(_2, /** @src -1:-1:-1 */ 0)
                /// @src 2:96215:96248  "address(this).call(_relayMessage)"
                let expr_component := call(gas(), /** @src 2:96223:96227  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 2:96215:96248  "address(this).call(_relayMessage)" */ _1, sub(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _2, /** @src 2:96215:96248  "address(this).call(_relayMessage)" */ _1), /** @src -1:-1:-1 */ 0, 0)
                /// @src 2:96215:96248  "address(this).call(_relayMessage)"
                let expr_component_mpos := extract_returndata()
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(expr_component)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 19)
                    mstore(add(memPtr, 68), "Verification failed")
                    revert(memPtr, 100)
                }
                /// @src 2:96842:96901  "require(returnData.length == 35, \"Wrong verification data\")"
                require_helper_stringliteral_3323(/** @src 2:96850:96873  "returnData.length == 35" */ eq(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:96850:96867  "returnData.length" */ expr_component_mpos), /** @src 2:96871:96873  "35" */ 0x23))
                /// @src 2:97032:97217  "assembly {..."
                let var_returnHash := mload(add(expr_component_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                /// @src 2:97032:97217  "assembly {..."
                let var_returnRewardEpochId := shr(232, mload(add(expr_component_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)))
                /// @src 2:97226:97293  "require(bytes32(returnHash) == _messageHash, \"Invalid config hash\")"
                require_helper_stringliteral_a3dc(/** @src 2:97234:97269  "bytes32(returnHash) == _messageHash" */ eq(var_returnHash, value2))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bytes32(memPos, var_returnRewardEpochId), memPos))
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                let ret, ret_1, ret_2 := fun_getRandomNumberHistorical(value)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, ret, ret_1, ret_2), memPos))
            }
            function external_fun_processGSSMessage()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := add(4, offset)
                if slt(add(sub(calldatasize(), offset), not(3)), 320)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset_1 := calldataload(36)
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value1, value2 := abi_decode_bytes_calldata(add(4, offset_1), calldatasize())
                /// @src 2:27714:27728  "governanceSafe"
                let _2 := loadimmutable("474")
                /// @src 2:27714:27767  "governanceSafe == address(0) || txData.operation != 0"
                let expr := /** @src 2:27714:27742  "governanceSafe == address(0)" */ iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:27714:27742  "governanceSafe == address(0)" */ _2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                /// @src 2:27714:27767  "governanceSafe == address(0) || txData.operation != 0"
                if iszero(expr)
                {
                    expr := /** @src 2:27746:27767  "txData.operation != 0" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:27746:27762  "txData.operation" */ read_from_calldatat_uint8(add(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, /** @src 2:27746:27762  "txData.operation" */ 100)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)))
                }
                /// @src 2:27714:27788  "governanceSafe == address(0) || txData.operation != 0 || txData.value != 0"
                let expr_1 := expr
                if iszero(expr)
                {
                    /// @src 2:27771:27783  "txData.value"
                    let value := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    value := calldataload(/** @src 2:27771:27783  "txData.value" */ add(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, 36))
                    /// @src 2:27714:27788  "governanceSafe == address(0) || txData.operation != 0 || txData.value != 0"
                    expr_1 := /** @src 2:27771:27788  "txData.value != 0" */ iszero(iszero(value))
                }
                /// @src 2:27710:27852  "if (governanceSafe == address(0) || txData.operation != 0 || txData.value != 0) {..."
                if expr_1
                {
                    /// @src 2:27811:27841  "InvalidGovernanceTransaction()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4)
                }
                /// @src 2:30224:30246  "signatures.length / 65"
                let expr_2 := checked_div_uint256_19167(value2)
                /// @src 2:30273:30338  "signatures.length == 0 ||..."
                let expr_3 := /** @src 2:30273:30295  "signatures.length == 0" */ iszero(value2)
                /// @src 2:30273:30338  "signatures.length == 0 ||..."
                if iszero(expr_3)
                {
                    expr_3 := /** @src 2:30311:30338  "signatures.length % 65 != 0" */ iszero(iszero(/** @src 2:30311:30333  "signatures.length % 65" */ mod_uint256_19168(value2)))
                }
                /// @src 2:30273:30381  "signatures.length == 0 ||..."
                let expr_4 := expr_3
                if iszero(expr_3)
                {
                    expr_4 := /** @src 2:30354:30381  "count < governanceThreshold" */ lt(expr_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:30362:30381  "governanceThreshold" */ 0x09))
                }
                /// @src 2:30273:30428  "signatures.length == 0 ||..."
                let expr_5 := expr_4
                if iszero(expr_4)
                {
                    expr_5 := /** @src 2:30397:30428  "count > governanceOwners.length" */ gt(expr_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:30405:30421  "governanceOwners" */ 0x0a))
                }
                /// @src 2:30256:30500  "if (..."
                if expr_5
                {
                    /// @src 2:30460:30489  "InvalidGovernanceSignatures()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:30460:30489  "InvalidGovernanceSignatures()" */ shl(225, 0x7ddace71))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4)
                }
                /// @src 2:30546:30571  "_copyGovernanceTx(txData)"
                let expr_mpos := fun_copyGovernanceTx(_1)
                /// @src 2:30526:30603  "GnosisSafeTx.digest(_copyGovernanceTx(txData), sourceChainId, governanceSafe)"
                let expr_6 := fun_digest(expr_mpos, /** @src 2:30573:30586  "sourceChainId" */ loadimmutable("471"), /** @src 2:30588:30602  "governanceSafe" */ _2)
                /// @src 2:30640:30660  "new address[](count)"
                let expr_mpos_1 := allocate_and_zero_memory_array_array_address_dyn(expr_2)
                /// @src 2:30675:30684  "uint256 i"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:30675:30684  "uint256 i"
                var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:30670:31033  "for (uint256 i; i < count; ++i) {..."
                for { }
                /** @src 2:30686:30695  "i < count" */ lt(var_i, expr_2)
                /// @src 2:30675:30684  "uint256 i"
                {
                    /// @src 2:30697:30700  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:30697:30700  "++i" */ var_i, /** @src 2:30826:30827  "1" */ 0x01)
                }
                /// @src 2:30697:30700  "++i"
                {
                    /// @src 2:30814:30820  "i * 65"
                    let expr_7 := checked_mul_uint256_19169(var_i)
                    /// @src 2:30803:30834  "signatures[i * 65:(i + 1) * 65]"
                    let expr_offset, expr_length := calldata_array_index_range_access_bytes_calldata(value1, value2, expr_7, /** @src 2:30821:30833  "(i + 1) * 65" */ checked_mul_uint256_19169(/** @src 2:30822:30827  "i + 1" */ checked_add_uint256_19170(var_i)))
                    /// @src 2:30785:30835  "digest.tryRecover(signatures[i * 65:(i + 1) * 65])"
                    let expr_component, expr_component_1, expr_component_2 := fun_tryRecover_3740(expr_6, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:30785:30835  "digest.tryRecover(signatures[i * 65:(i + 1) * 65])" */ expr_offset, expr_length, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize()))
                    validator_assert_enum_RecoverError(expr_component_1)
                    /// @src 2:30853:30895  "recoverError != ECDSA.RecoverError.NoError"
                    let _3 := iszero(expr_component_1)
                    /// @src 2:30853:30919  "recoverError != ECDSA.RecoverError.NoError || signer == address(0)"
                    let expr_8 := /** @src 2:30853:30895  "recoverError != ECDSA.RecoverError.NoError" */ iszero(_3)
                    /// @src 2:30853:30919  "recoverError != ECDSA.RecoverError.NoError || signer == address(0)"
                    if _3
                    {
                        expr_8 := /** @src 2:30899:30919  "signer == address(0)" */ iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:30899:30919  "signer == address(0)" */ expr_component, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    }
                    /// @src 2:30849:30990  "if (recoverError != ECDSA.RecoverError.NoError || signer == address(0)) {..."
                    if expr_8
                    {
                        /// @src 2:30946:30975  "InvalidGovernanceSignatures()"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:30460:30489  "InvalidGovernanceSignatures()" */ shl(225, 0x7ddace71))
                        /// @src 2:30946:30975  "InvalidGovernanceSignatures()"
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4)
                    }
                    /// @src 2:31003:31022  "signers[i] = signer"
                    write_to_memory_address(memory_array_index_access_uint16_dyn(expr_mpos_1, var_i), expr_component)
                }
                /// @src 2:31069:31076  "signers"
                fun_validateGovernanceSigners(expr_mpos_1)
                /// @src 2:27951:27962  "txData.data"
                let expr_offset_1, expr_length_1 := access_calldata_tail_bytes_calldata(_1, add(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, /** @src 2:27951:27962  "txData.data" */ 68))
                /// @src 2:27964:27976  "txData.nonce"
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(/** @src 2:27964:27976  "txData.nonce" */ add(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, /** @src 2:27964:27976  "txData.nonce" */ 292))
                fun_processVerifiedGovernanceAction(expr_offset_1, expr_length_1, value_1)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function external_fun_signingPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 2:9126:9160  "address public signingPolicySetter" */ 3), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value0 := abi_decode_uint256()
                let _1 := sload(/** @src 2:94805:94814  "stateData" */ 0x0d)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := and(shr(8, _1), 0xffffffff)
                if /** @src 2:94791:94838  "_timestamp >= stateData.firstVotingRoundStartTs" */ lt(value0, value)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 16)
                    mstore(add(memPtr, 68), "before the start")
                    revert(memPtr, 100)
                }
                /// @src 2:94877:94923  "_timestamp - stateData.firstVotingRoundStartTs"
                let expr := checked_sub_uint256(value0, cleanup_from_storage_uint32(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value))
                /// @src 2:94869:94963  "return (_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds"
                let var := /** @src 2:94876:94963  "(_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds" */ checked_div_uint256(expr, cleanup_from_storage_uint8(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_uint8(_1)))
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bytes32(memPos, var), memPos))
            }
            function abi_encode_bytes(value, pos) -> end
            {
                let length := mload(value)
                mstore(pos, length)
                mcopy(add(pos, 0x20), add(value, 0x20), length)
                mstore(add(add(pos, length), 0x20), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                end := add(add(pos, and(add(length, 31), not(31))), 0x20)
            }
            function external_fun_relay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 2:37658:87889  "assembly {..."
                let usr$memPtr := mload(0x40)
                mstore(add(usr$memPtr, 160), sload(13))
                if lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:37658:87889  "assembly {..." */ 15)
                {
                    usr$revertWithMessage_19174(usr$memPtr)
                }
                calldatacopy(usr$memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4, /** @src 2:37658:87889  "assembly {..." */ 11)
                let _1 := mload(usr$memPtr)
                if lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:37658:87889  "assembly {..." */ add(mul(shr(240, _1), 22), 48))
                {
                    usr$revertWithMessage_19175(usr$memPtr)
                }
                let _2 := usr$calculateSigningPolicyHash_19176(usr$memPtr, add(43, mul(shr(240, _1), 22)), /** @src 2:37579:37592  "sourceChainId" */ loadimmutable("471"))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr$memPtr, 0x40), _2)
                mstore(usr$memPtr, and(shr(216, _1), 16777215))
                mstore(add(usr$memPtr, 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                /// @src 2:37658:87889  "assembly {..."
                let _3 := sload(keccak256(usr$memPtr, 0x40))
                mstore(add(usr$memPtr, 96), _3)
                if iszero(eq(_2, _3))
                {
                    usr$revertWithMessage_19177(usr$memPtr)
                }
                calldatacopy(usr$memPtr, add(mul(shr(240, _1), 22), 47), 1)
                let usr$protocolId := shr(248, mload(usr$memPtr))
                let usr$signatureStart := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:37658:87889  "assembly {..."
                let usr$threshold := and(shr(168, _1), 65535)
                if iszero(iszero(usr$protocolId))
                {
                    let usr$memPtrGP0 := mload(0x40)
                    usr$signatureStart := add(mul(shr(240, _1), 22), 85)
                    if lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:37658:87889  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_19178(usr$memPtrGP0)
                    }
                    calldatacopy(usr$memPtrGP0, add(mul(shr(240, _1), 22), 47), 38)
                    let usr$votingRoundId := and(shr(216, mload(usr$memPtrGP0)), 4294967295)
                    mstore(add(usr$memPtrGP0, 96), usr$protocolId)
                    mstore(add(usr$memPtrGP0, 128), 1)
                    mstore(add(usr$memPtrGP0, 128), keccak256(add(usr$memPtrGP0, 96), 0x40))
                    mstore(add(usr$memPtrGP0, 96), usr$votingRoundId)
                    if iszero(iszero(sload(keccak256(add(usr$memPtrGP0, 96), 0x40))))
                    {
                        usr$revertWithMessage_19179(usr$memPtrGP0)
                    }
                    let _4 := eq(usr$protocolId, 1)
                    if _4
                    {
                        if usr$votingRoundId
                        {
                            usr$revertWithMessage_19180(usr$memPtrGP0)
                        }
                        if cleanup_from_storage_uint8(shr(208, mload(usr$memPtrGP0)))
                        {
                            usr$revertWithMessage_19182(usr$memPtrGP0)
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
                        usr$revertWithMessage_19183(usr$memPtrGP0)
                    }
                    let _6 := mload(add(usr$memPtrGP0, 160))
                    if lt(add(usr$messageRewardEpochId, and(shr(192, _6), 4294967295)), and(shr(152, _6), 4294967295))
                    {
                        usr$revertWithMessage(usr$memPtrGP0)
                    }
                    if and(_5, lt(usr$votingRoundId, and(shr(184, _1), 4294967295)))
                    {
                        usr$revertWithMessage_19185(usr$memPtrGP0)
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
                                usr$revertWithMessage_19187(usr$memPtrGP0)
                            }
                        }
                        if eq(usr$lastInitializedRewardEpoch, and(shr(216, _1), 16777215))
                        {
                            usr$threshold := div(mul(usr$threshold, usr$structValue(mload(add(usr$memPtrGP0, 160)))), 10000)
                        }
                    }
                    let _7 := keccak256(usr$memPtrGP0, 38)
                    let _8 := add(usr$memPtrGP0, 32)
                    mstore(_8, _7)
                    mstore(usr$memPtrGP0, /** @src 2:37579:37592  "sourceChainId" */ loadimmutable("471"))
                    /// @src 2:37658:87889  "assembly {..."
                    mstore(_8, keccak256(usr$memPtrGP0, 0x40))
                }
                if iszero(usr$protocolId)
                {
                    let _9 := mload(0x40)
                    if iszero(iszero(extract_from_storage_value_offsett_bool(mload(add(_9, 160)))))
                    {
                        usr$revertWithMessage_19190(_9)
                    }
                    if lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:37658:87889  "assembly {..." */ add(mul(shr(240, _1), 22), 59))
                    {
                        usr$revertWithMessage_19191(mload(0x40))
                    }
                    calldatacopy(mload(0x40), add(mul(shr(240, _1), 22), 48), 11)
                    let _10 := mload(0x40)
                    let _11 := mload(_10)
                    let _12 := shr(240, _11)
                    if iszero(_12)
                    {
                        usr$revertWithMessage_19192(_10)
                    }
                    if gt(_12, 300)
                    {
                        usr$revertWithMessage_19193(mload(0x40))
                    }
                    let _13 := mul(_12, 22)
                    usr$signatureStart := add(add(mul(shr(240, _1), 22), _13), 91)
                    if lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:37658:87889  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_19194(mload(0x40))
                    }
                    let usr$newSigningPolicyRewardEpochId := and(shr(216, _11), 16777215)
                    let _14 := mload(0x40)
                    let usr$tmpLastInitializedRewardEpochId := extract_from_storage_value_offsett_uint32(mload(add(_14, 160)))
                    if iszero(eq(usr$tmpLastInitializedRewardEpochId, and(shr(216, _1), 16777215)))
                    {
                        usr$revertWithMessage_19196(_14)
                    }
                    if iszero(eq(add(1, usr$tmpLastInitializedRewardEpochId), usr$newSigningPolicyRewardEpochId))
                    {
                        usr$revertWithMessage_19197(mload(0x40))
                    }
                    usr$checkThresholdConsistency(mload(0x40), shr(168, _11), add(mul(shr(240, _1), 22), 48))
                    let usr$newSigningPolicyHash := usr$calculateSigningPolicyHash(mload(0x40), add(mul(shr(240, _1), 22), 48), add(43, _13), /** @src 2:37579:37592  "sourceChainId" */ loadimmutable("471"))
                    /// @src 2:37658:87889  "assembly {..."
                    let _15 := add(mload(0x40), 160)
                    mstore(_15, usr$assignStruct(mload(_15), usr$newSigningPolicyRewardEpochId))
                    mstore(mload(0x40), usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), 2)
                    let _16 := mload(0x40)
                    sstore(keccak256(_16, 0x40), and(shr(184, _11), 4294967295))
                    mstore(_16, usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                    /// @src 2:37658:87889  "assembly {..."
                    let _17 := mload(0x40)
                    sstore(keccak256(_17, 0x40), usr$newSigningPolicyHash)
                    mstore(add(_17, 32), usr$newSigningPolicyHash)
                    mstore(add(mload(0x40), 96), "SigningPolicyRelayed(uint256)")
                    log2(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, /** @src 2:37658:87889  "assembly {..." */ keccak256(add(mload(0x40), 96), 29), usr$newSigningPolicyRewardEpochId)
                }
                let _18 := add(usr$signatureStart, 2)
                if lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:37658:87889  "assembly {..." */ _18)
                {
                    usr$revertWithMessage_19199(usr$memPtr)
                }
                calldatacopy(add(usr$memPtr, 0x40), usr$signatureStart, 2)
                let _19 := shr(240, mload(add(usr$memPtr, 0x40)))
                mstore(add(usr$memPtr, 256), _18)
                if lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:37658:87889  "assembly {..." */ add(add(usr$signatureStart, mul(_19, 67)), 2))
                {
                    usr$revertWithMessage_19200(usr$memPtr)
                }
                mstore(usr$memPtr, "0000\x19Ethereum Signed Message:\n32")
                mstore(usr$memPtr, keccak256(add(usr$memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4), /** @src 2:37658:87889  "assembly {..." */ 60))
                let usr$i := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:37658:87889  "assembly {..."
                let usr$weight := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:37658:87889  "assembly {..."
                let usr$nextUnusedIndex := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:37658:87889  "assembly {..."
                let usr$memPtrFor := mload(0x40)
                for { } lt(usr$i, _19) { usr$i := add(usr$i, 1) }
                {
                    mstore(add(usr$memPtrFor, 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                    /// @src 2:37658:87889  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 63), add(add(usr$signatureStart, mul(usr$i, 67)), 2), 67)
                    let usr$index := shr(240, mload(add(usr$memPtrFor, 128)))
                    if gt(add(usr$index, 1), shr(240, _1))
                    {
                        usr$revertWithMessage_19201(usr$memPtrFor)
                    }
                    if lt(usr$index, usr$nextUnusedIndex)
                    {
                        usr$revertWithMessage_19202(usr$memPtrFor)
                    }
                    usr$nextUnusedIndex := add(usr$index, 1)
                    let _20 := and(mload(add(usr$memPtrFor, 32)), 0xff)
                    if iszero(or(eq(_20, 27), eq(_20, 28)))
                    {
                        usr$revertWithMessage_19203(usr$memPtrFor)
                    }
                    if gt(mload(add(usr$memPtrFor, 96)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                    {
                        usr$revertWithMessage_19204(usr$memPtrFor)
                    }
                    if iszero(staticcall(not(0), 1, usr$memPtrFor, 128, add(usr$memPtrFor, 0x40), 32))
                    {
                        usr$revertWithMessage_19205(usr$memPtrFor)
                    }
                    if iszero(eq(returndatasize(), 32))
                    {
                        usr$revertWithMessage_19206(usr$memPtrFor)
                    }
                    if iszero(mload(add(usr$memPtrFor, 0x40)))
                    {
                        usr$revertWithMessage_19207(usr$memPtrFor)
                    }
                    mstore(add(usr$memPtrFor, 96), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                    /// @src 2:37658:87889  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 106), add(47, mul(usr$index, 22)), 22)
                    if iszero(eq(mload(add(usr$memPtrFor, 0x40)), shr(16, mload(add(usr$memPtrFor, 96)))))
                    {
                        usr$revertWithMessage_19208(usr$memPtrFor)
                    }
                    usr$weight := add(usr$weight, and(mload(add(usr$memPtrFor, 96)), 65535))
                    if gt(usr$weight, usr$threshold)
                    {
                        if iszero(usr$protocolId)
                        {
                            sstore(13, mload(add(usr$memPtrFor, 160)))
                            return(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0)
                        }
                        /// @src 2:37658:87889  "assembly {..."
                        if iszero(iszero(usr$protocolId))
                        {
                            let _21 := add(usr$memPtrFor, 192)
                            calldatacopy(_21, add(mul(shr(240, _1), 22), 53), 32)
                            if eq(usr$protocolId, 1)
                            {
                                mstore(usr$memPtrFor, mload(_21))
                                mstore(add(usr$memPtrFor, 32), and(shl(16, _1), shl(232, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 16777215)))
                                /// @src 2:37658:87889  "assembly {..."
                                return(usr$memPtrFor, 35)
                            }
                            if iszero(mload(_21))
                            {
                                usr$revertWithMessage_19209(usr$memPtrFor)
                            }
                            let usr$votingRoundId_1 := usr$extractVotingRoundIdFromMessage(usr$memPtrFor, add(43, mul(shr(240, _1), 22)))
                            mstore(usr$memPtrFor, usr$protocolId)
                            mstore(add(usr$memPtrFor, 32), 1)
                            mstore(add(usr$memPtrFor, 32), keccak256(usr$memPtrFor, 0x40))
                            mstore(usr$memPtrFor, usr$votingRoundId_1)
                            sstore(keccak256(usr$memPtrFor, 0x40), mload(_21))
                            let _22 := add(usr$memPtrFor, 160)
                            if iszero(eq(usr$protocolId, cleanup_from_storage_uint8(mload(_22))))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, _1), 22), 47), 6)
                                let _23 := shr(208, mload(usr$memPtrFor))
                                mstore(usr$memPtrFor, _23)
                                mstore(_22, and(_23, 0xff))
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_22, 0x40, keccak256(add(usr$memPtrFor, 96), 49), usr$protocolId, usr$votingRoundId_1)
                                return(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0)
                            }
                            /// @src 2:37658:87889  "assembly {..."
                            if eq(usr$protocolId, cleanup_from_storage_uint8(mload(_22)))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, _1), 22), 47), 6)
                                let usr$isSecure := iszero(iszero(cleanup_from_storage_uint8(shr(208, mload(usr$memPtrFor)))))
                                let _24 := add(usr$memPtrFor, 256)
                                usr$processRandomMerkleProof(usr$memPtrFor, add(mload(_24), mul(_19, 67)), _21, usr$votingRoundId_1, usr$isSecure)
                                if usr$isSecure
                                {
                                    usr$setIsSecureRandomBit(add(usr$memPtrFor, 96), usr$votingRoundId_1)
                                }
                                let _25 := mload(_22)
                                if gt(usr$votingRoundId_1, and(shr(112, _25), 4294967295))
                                {
                                    sstore(13, usr$assignStruct_19214(usr$assignStruct_19213(_25, usr$votingRoundId_1), usr$isSecure))
                                }
                                mstore(_22, usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_22, 0x40, keccak256(add(usr$memPtrFor, 96), 49), usr$protocolId, usr$votingRoundId_1)
                                calldatacopy(_21, add(mload(_24), mul(_19, 67)), 32)
                                mstore(add(usr$memPtrFor, 224), usr$isSecure)
                                mstore(add(usr$memPtrFor, 96), "RandomNumberRelayed(uint32,uint2")
                                mstore(add(usr$memPtrFor, 128), "56,bool)")
                                log2(_21, 0x40, keccak256(add(usr$memPtrFor, 96), 40), usr$votingRoundId_1)
                                return(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0)
                            }
                        }
                        /// @src 2:37658:87889  "assembly {..."
                        usr$revertWithMessage_19215(mload(0x40))
                    }
                }
                /// @src 2:87910:87937  "revert(\"Not enough weight\")"
                let _26 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:37658:87889  "assembly {..." */ 0x40)
                /// @src 2:87910:87937  "revert(\"Not enough weight\")"
                mstore(_26, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:87910:87937  "revert(\"Not enough weight\")"
                revert(_26, sub(abi_encode_stringliteral_0d64(add(_26, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4)), /** @src 2:87910:87937  "revert(\"Not enough weight\")" */ _26))
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function external_fun_governanceSafe()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:9598:9646  "address public immutable override governanceSafe" */ loadimmutable("474"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                return(memPos, 32)
            }
            function external_fun_activeOwnerConfigSafeNonce()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:9764:9814  "uint256 public override activeOwnerConfigSafeNonce" */ 7)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_getRandomNumber()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:93123:93132  "stateData" */ 0x0d)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := and(shr(112, _1), 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 2:93101:93122  "toRandomNumberPrivate" */ 0x0e)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _2 := sload(keccak256(0, 0x40))
                let cleaned := and(/** @src 2:93302:93335  "stateData.randomVotingRoundId + 1" */ checked_add_uint32(value), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
                /// @src 2:93215:93387  "_randomTimestamp =..."
                let var__randomTimestamp := /** @src 2:93246:93387  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shr(8, _1), 0xffffffff), /** @src 2:93294:93387  "uint256(stateData.randomVotingRoundId + 1) *..." */ checked_mul_uint256(cleaned, cleanup_from_storage_uint8(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shr(40, _1), 0xff))))
                let memPos := mload(0x40)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, _2, and(shr(144, _1), 0xff), var__randomTimestamp), memPos))
            }
            function external_fun_oldRelay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:11126:11158  "IRelay public immutable oldRelay" */ loadimmutable("537"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
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
            /// @ast-id 3159 @src 2:95018:95421  "function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {..."
            function fun_toSigningPolicyHash(var_rewardEpochId) -> var
            {
                /// @src 2:95094:95101  "bytes32"
                var := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:95117:95125  "oldRelay" */ loadimmutable("537"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:95117:95188  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                let expr := /** @src 2:95117:95147  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:95117:95188  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:95151:95188  "_rewardEpochId < initialRewardEpochId" */ lt(var_rewardEpochId, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:95168:95188  "initialRewardEpochId" */ loadimmutable("540"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:95113:95266  "if (oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:95211:95255  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _2 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:95211:95255  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    mstore(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x0c85bf07))
                    /// @src 2:95211:95255  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_bytes32(add(_2, 4), var_rewardEpochId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:95211:95255  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 2:95204:95255  "return oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    var := expr_1
                    leave
                }
                /// @src 2:95275:95355  "require(signingPolicySetter != address(0), \"no access to signing policy hashes\")"
                require_helper_stringliteral_63a2(/** @src 2:95283:95316  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(cleanup_address_payable(sload(/** @src 2:95283:95302  "signingPolicySetter" */ 0x03)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))))
                /// @src 2:95365:95414  "return toSigningPolicyHashPrivate[_rewardEpochId]"
                var := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:95372:95414  "toSigningPolicyHashPrivate[_rewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19217(var_rewardEpochId))
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
            function abi_encode_uint256_uint256_19404(value0, value1) -> tail
            {
                tail := 68
                mstore(/** @src 2:28623:28691  "GovernanceNonceBeforeReplayFloor(actionNonce, governanceReplayFloor)" */ 4, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value0)
                mstore(36, value1)
            }
            function abi_encode_uint256_uint256(headStart, value0, value1) -> tail
            {
                tail := add(headStart, 64)
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
            }
            /// @ast-id 2905 @src 2:91413:92013  "function isFinalized(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_isFinalized(var_protocolId, var_votingRoundId) -> var
            {
                /// @src 2:91518:91522  "bool"
                var := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:91542:91550  "oldRelay" */ loadimmutable("537"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:91542:91637  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:91542:91572  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:91542:91637  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:91576:91637  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:91593:91637  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("543"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:91538:91720  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:91660:91709  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _2 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:91660:91709  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(226, 0x0c5eb4cf))
                    /// @src 2:91660:91709  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var_protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:91660:91709  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bool_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 2:91653:91709  "return oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    var := expr_1
                    leave
                }
                /// @src 2:91938:92006  "return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)"
                var := /** @src 2:91945:92006  "merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:91945:91992  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:91945:91976  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19218(var_protocolId), /** @src 2:91945:91992  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))))
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
            /// @ast-id 2952 @src 2:92061:92534  "function merkleRoots(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_merkleRoots(var__protocolId, var_votingRoundId) -> var_merkleRoot
            {
                /// @src 2:92166:92185  "bytes32 _merkleRoot"
                var_merkleRoot := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:92205:92213  "oldRelay" */ loadimmutable("537"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:92205:92300  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:92205:92235  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:92205:92300  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:92239:92300  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:92256:92300  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("543"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:92201:92383  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:92323:92372  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _2 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:92323:92372  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(232, 3752811))
                    /// @src 2:92323:92372  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var__protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:92323:92372  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 2:92316:92372  "return oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    var_merkleRoot := expr_1
                    leave
                }
                /// @src 2:92392:92463  "require(signingPolicySetter != address(0), \"no access to merkle roots\")"
                require_helper_stringliteral_1c79(/** @src 2:92400:92433  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(cleanup_address_payable(sload(/** @src 2:92400:92419  "signingPolicySetter" */ 0x03)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))))
                /// @src 2:92473:92527  "return merkleRootsPrivate[_protocolId][_votingRoundId]"
                var_merkleRoot := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:92480:92527  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:92480:92511  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19218(var__protocolId), /** @src 2:92480:92527  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
                size := add(and(add(length, 31), not(31)), 0x20)
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
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ returndatasize())
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
            function panic_error_0x11()
            {
                mstore(0, shl(224, 0x4e487b71))
                mstore(4, 0x11)
                revert(0, 0x24)
            }
            function checked_sub_uint256_19232(y) -> diff
            {
                diff := sub(/** @src 2:24749:24751  "20" */ 0x14, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:24749:24751  "20" */ 0x14)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_19234(y) -> diff
            {
                diff := sub(/** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_19237(y) -> diff
            {
                diff := sub(/** @src 2:23978:23979  "2" */ 0x02, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:23978:23979  "2" */ 0x02)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_19297(y) -> diff
            {
                diff := sub(/** @src 2:94384:94387  "255" */ 0xff, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:94384:94387  "255" */ 0xff)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_19426(x) -> diff
            {
                diff := add(x, /** @src 2:37658:87889  "assembly {..." */ not(0))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if gt(diff, x) { panic_error_0x11() }
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
            /// @ast-id 2863 @src 2:87992:91365  "function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)..."
            function fun_verify(var_protocolId, var_votingRoundId, var__leaf, var__proof_offset, var__proof_length) -> var
            {
                /// @src 2:88137:88141  "bool"
                var := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:88885:88893  "oldRelay" */ loadimmutable("537"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:88885:88980  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:88885:88915  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:88885:88980  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:88919:88980  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:88936:88980  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("543"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:88881:91337  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                switch expr
                case 0 {
                    /// @src 2:89940:89987  "require(_protocolId > 1, \"invalid protocol id\")"
                    require_helper_stringliteral_44e5(/** @src 2:89948:89963  "_protocolId > 1" */ gt(var_protocolId, /** @src 2:89962:89963  "1" */ 0x01))
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    let _2 := sload(/** @src 2:90015:90044  "protocolFeeInWei[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19220(var_protocolId))
                    /// @src 2:90058:90098  "require(msg.value >= fee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 2:90066:90082  "msg.value >= fee" */ iszero(lt(/** @src 2:90066:90075  "msg.value" */ callvalue(), /** @src 2:90066:90082  "msg.value >= fee" */ _2)))
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    let _3 := sload(/** @src 2:90208:90255  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:90208:90239  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19218(var_protocolId), /** @src 2:90208:90255  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
                    /// @src 2:90269:90313  "require(root != bytes32(0), \"not finalized\")"
                    require_helper_stringliteral(/** @src 2:90277:90295  "root != bytes32(0)" */ iszero(iszero(_3)))
                    /// @src 2:90327:90440  "require(..."
                    require_helper_stringliteral_c04c(/** @src 2:90352:90386  "_proof.verifyCalldata(root, _leaf)" */ fun_verifyCalldata(var__proof_offset, var__proof_length, _3, var__leaf))
                    /// @src 2:90657:90994  "if (fee > 0) {..."
                    if /** @src 2:90661:90668  "fee > 0" */ iszero(iszero(_2))
                    /// @src 2:90657:90994  "if (fee > 0) {..."
                    {
                        /// @src 2:90828:90869  "feeCollectionAddress.call{value: fee}(\"\")"
                        let expr_component := call(gas(), /** @src 2:90828:90853  "feeCollectionAddress.call" */ cleanup_address_payable(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_address_payable(sload(/** @src 2:90828:90848  "feeCollectionAddress" */ 0x05))), /** @src 2:90828:90869  "feeCollectionAddress.call{value: fee}(\"\")" */ _2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, 0, 0)
                        /// @src 2:90828:90869  "feeCollectionAddress.call{value: fee}(\"\")"
                        pop(extract_returndata())
                        /// @src 2:90946:90979  "require(feeOk, \"Transfer failed\")"
                        require_helper_stringliteral_25ad(expr_component)
                    }
                    /// @src 2:91024:91039  "msg.value - fee"
                    let expr_1 := checked_sub_uint256(/** @src 2:90066:90075  "msg.value" */ callvalue(), /** @src 2:91024:91039  "msg.value - fee" */ _2)
                    /// @src 2:91053:91327  "if (refund > 0) {..."
                    if /** @src 2:91057:91067  "refund > 0" */ iszero(iszero(expr_1))
                    /// @src 2:91053:91327  "if (refund > 0) {..."
                    {
                        /// @src 2:91167:91201  "msg.sender.call{value: refund}(\"\")"
                        let expr_2849_component := call(gas(), /** @src 2:91167:91177  "msg.sender" */ caller(), /** @src 2:91167:91201  "msg.sender.call{value: refund}(\"\")" */ expr_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, 0, 0)
                        /// @src 2:91167:91201  "msg.sender.call{value: refund}(\"\")"
                        pop(extract_returndata())
                        /// @src 2:91278:91312  "require(refundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_2849_component)
                    }
                }
                default /// @src 2:88881:91337  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                {
                    /// @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _4 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)"
                    mstore(_4, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x91e7d42f))
                    /// @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _5 := staticcall(gas(), _1, _4, sub(abi_encode_bytes32(add(_4, 4), var_protocolId), _4), _4, 32)
                    if iszero(_5) { revert_forward() }
                    let expr_2 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)"
                    if _5
                    {
                        let _6 := 32
                        if gt(32, returndatasize()) { _6 := returndatasize() }
                        finalize_allocation(_4, _6)
                        expr_2 := abi_decode_uint256_fromMemory(_4, add(_4, _6))
                    }
                    /// @src 2:89334:89377  "require(msg.value >= oldFee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 2:89342:89361  "msg.value >= oldFee" */ iszero(lt(/** @src 2:89342:89351  "msg.value" */ callvalue(), /** @src 2:89342:89361  "msg.value >= oldFee" */ expr_2)))
                    /// @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _7 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    mstore(_7, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(225, 0x40428355))
                    /// @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _8 := call(gas(), _1, expr_2, _7, sub(abi_encode_uint256_uint256_bytes32_array_bytes32_dyn_calldata(add(_7, /** @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)" */ 4), /** @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ var_protocolId, var_votingRoundId, var__leaf, var__proof_offset, var__proof_length), _7), _7, /** @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)" */ 32)
                    /// @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if iszero(_8) { revert_forward() }
                    let expr_3 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if _8
                    {
                        let _9 := /** @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)" */ 32
                        /// @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                        if gt(/** @src 2:89282:89320  "oldRelay.protocolFeeInWei(_protocolId)" */ 32, /** @src 2:89401:89475  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ returndatasize()) { _9 := returndatasize() }
                        finalize_allocation(_7, _9)
                        expr_3 := abi_decode_bool_fromMemory(_7, add(_7, _9))
                    }
                    /// @src 2:89489:89533  "require(ok, \"old relay verification failed\")"
                    require_helper_stringliteral_fd5d(expr_3)
                    /// @src 2:89567:89585  "msg.value - oldFee"
                    let expr_4 := checked_sub_uint256(/** @src 2:89342:89351  "msg.value" */ callvalue(), /** @src 2:89567:89585  "msg.value - oldFee" */ expr_2)
                    /// @src 2:89599:89885  "if (oldRefund > 0) {..."
                    if /** @src 2:89603:89616  "oldRefund > 0" */ iszero(iszero(expr_4))
                    /// @src 2:89599:89885  "if (oldRefund > 0) {..."
                    {
                        /// @src 2:89719:89756  "msg.sender.call{value: oldRefund}(\"\")"
                        let expr_2752_component := call(gas(), /** @src 2:89719:89729  "msg.sender" */ caller(), /** @src 2:89719:89756  "msg.sender.call{value: oldRefund}(\"\")" */ expr_4, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, 0, 0)
                        /// @src 2:89719:89756  "msg.sender.call{value: oldRefund}(\"\")"
                        pop(extract_returndata())
                        /// @src 2:89833:89870  "require(oldRefundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_2752_component)
                    }
                    /// @src 2:89898:89909  "return true"
                    var := /** @src 2:89905:89909  "true" */ 0x01
                    /// @src 2:89898:89909  "return true"
                    leave
                }
                /// @src 2:91347:91358  "return true"
                var := /** @src 2:91354:91358  "true" */ 0x01
            }
            /// @ast-id 556 @src 2:11451:11583  "modifier onlySigningPolicySetter() {..."
            function modifier_onlySigningPolicySetter(var_signingPolicy_mpos) -> _1
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(/** @src 2:11504:11537  "msg.sender == signingPolicySetter" */ eq(/** @src 2:11504:11514  "msg.sender" */ caller(), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(sload(/** @src 2:11518:11537  "signingPolicySetter" */ 0x03), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 23)
                    mstore(add(memPtr, 68), "only sign policy setter")
                    revert(memPtr, 100)
                }
                /// @src 2:20630:20670  "stateData.lastInitializedRewardEpoch + 1"
                let expr := checked_add_uint32(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_uint32(sload(/** @src 2:20630:20639  "stateData" */ 0x0d)))
                /// @src 2:20609:20749  "require(..."
                require_helper_stringliteral_d084(/** @src 2:20630:20702  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ eq(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:20630:20702  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ expr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), /** @src 2:20630:20702  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ cleanup_uint24(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:20674:20702  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))))
                /// @src 2:21603:21667  "require(_signingPolicy.voters.length > 0, \"must be non-trivial\")"
                require_helper_stringliteral_aacd(/** @src 2:21611:21643  "_signingPolicy.voters.length > 0" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ mload(add(var_signingPolicy_mpos, 128))))))
                /// @src 2:21677:21747  "require(_signingPolicy.voters.length <= MAX_VOTERS, \"too many voters\")"
                require_helper_stringliteral_d1bc(/** @src 2:21685:21727  "_signingPolicy.voters.length <= MAX_VOTERS" */ iszero(gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:21685:21706  "_signingPolicy.voters" */ mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))), /** @src 2:2993:2996  "300" */ 0x012c)))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let length := mload(/** @src 2:21765:21786  "_signingPolicy.voters" */ mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))
                /// @src 2:21757:21844  "require(_signingPolicy.voters.length == _signingPolicy.weights.length, \"size mismatch\")"
                require_helper_stringliteral_6b32(/** @src 2:21765:21826  "_signingPolicy.voters.length == _signingPolicy.weights.length" */ eq(length, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:21797:21819  "_signingPolicy.weights" */ mload(add(var_signingPolicy_mpos, 160)))))
                /// @src 2:21854:21877  "uint256 totalWeight = 0"
                let var_totalWeight := /** @src -1:-1:-1 */ 0
                /// @src 2:21892:21905  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:21887:22012  "for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {..."
                for { }
                /** @src 2:20669:20670  "1" */ 0x01
                /// @src 2:21892:21905  "uint256 i = 0"
                {
                    /// @src 2:21942:21945  "i++"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:21942:21945  "i++" */ var_i, /** @src 2:20669:20670  "1" */ 0x01)
                }
                /// @src 2:21942:21945  "i++"
                {
                    /// @src 2:21911:21933  "_signingPolicy.weights"
                    let _mpos := mload(/** @src 2:21797:21819  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                    /// @src 2:21907:21940  "i < _signingPolicy.weights.length"
                    if iszero(lt(var_i, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:21911:21940  "_signingPolicy.weights.length" */ _mpos)))
                    /// @src 2:21907:21940  "i < _signingPolicy.weights.length"
                    { break }
                    /// @src 2:21961:22001  "totalWeight += _signingPolicy.weights[i]"
                    var_totalWeight := checked_add_uint256(var_totalWeight, cleanup_from_storage_uint16(/** @src 2:21976:22001  "_signingPolicy.weights[i]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos, var_i))))
                }
                /// @src 2:22021:22073  "require(totalWeight < 2**16, \"total weight too big\")"
                require_helper_stringliteral_f10c(/** @src 2:22029:22048  "totalWeight < 2**16" */ lt(var_totalWeight, /** @src 2:22043:22048  "2**16" */ 0x010000))
                /// @src 2:22104:22163  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_1 := checked_mul_uint256_19223(/** @src 2:22104:22137  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:22112:22136  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 2:22083:22244  "require(..."
                require_helper_stringliteral_d8d1(/** @src 2:22104:22199  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS" */ iszero(lt(expr_1, /** @src 2:22167:22199  "totalWeight * MIN_THRESHOLD_BIPS" */ checked_mul_uint256_19224(var_totalWeight))))
                /// @src 2:22275:22334  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_2 := checked_mul_uint256_19223(/** @src 2:22275:22308  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:22112:22136  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 2:22254:22413  "require(..."
                require_helper_stringliteral_185c(/** @src 2:22275:22370  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS" */ iszero(gt(expr_2, /** @src 2:22338:22370  "totalWeight * MAX_THRESHOLD_BIPS" */ checked_mul_uint256_19226(var_totalWeight))))
                /// @src 2:22458:22608  "new bytes(..."
                let expr_mpos := allocate_and_zero_memory_array_bytes(/** @src 2:22481:22598  "SIGNING_POLICY_PREFIX_BYTES +..." */ checked_add_uint256_19228(/** @src 2:22527:22598  "_signingPolicy.voters.length *..." */ checked_mul_uint256_19227(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:22527:22548  "_signingPolicy.voters" */ mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))))
                /// @src 2:22619:22636  "Counters memory m"
                let zero_struct_Counters_mpos := /** @src 2:4462:4464  "22" */ allocate_and_zero_memory_struct_struct_Counters()
                /// @src 2:22952:22973  "_signingPolicy.voters"
                let _mpos_1 := mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 2:22938:22982  "bytes2(uint16(_signingPolicy.voters.length))"
                let expr_3 := convert_uint16_to_bytes2(/** @src 2:22945:22981  "uint16(_signingPolicy.voters.length)" */ cleanup_from_storage_uint16(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:22952:22980  "_signingPolicy.voters.length" */ _mpos_1)))
                /// @src 2:22996:23032  "bytes3(_signingPolicy.rewardEpochId)"
                let expr_4 := convert_uint24_to_bytes3(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:23003:23031  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))
                /// @src 2:23046:23087  "bytes4(_signingPolicy.startVotingRoundId)"
                let expr_5 := convert_uint32_to_bytes4(/** @src 2:4462:4464  "22" */ cleanup_from_storage_uint32(mload(/** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32))))
                /// @src 2:23101:23133  "bytes2(_signingPolicy.threshold)"
                let expr_6 := convert_uint16_to_bytes2(/** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:22112:22136  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64))))
                /// @src 2:4462:4464  "22"
                let _2 := mload(/** @src 2:23163:23182  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 2:23198:23231  "bytes20(_signingPolicy.voters[0])"
                let expr_7 := convert_address_to_bytes20(/** @src 2:23206:23230  "_signingPolicy.voters[0]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn_19229(_mpos_1)))
                /// @src 2:22912:23300  "bytes.concat(..."
                let expr_mpos_1 := bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(expr_3, expr_4, expr_5, expr_6, _2, expr_7, /** @src 2:23245:23290  "bytes1(uint8(_signingPolicy.weights[0] >> 8))" */ convert_uint8_to_bytes1(/** @src 2:23252:23289  "uint8(_signingPolicy.weights[0] >> 8)" */ cleanup_from_storage_uint8(/** @src 2:23258:23288  "_signingPolicy.weights[0] >> 8" */ shift_right_uint16_uint8(/** @src 2:23258:23283  "_signingPolicy.weights[0]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn_19229(/** @src 2:23258:23280  "_signingPolicy.weights" */ mload(/** @src 2:21797:21819  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))))))))
                /// @src 2:23311:23457  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                for { }
                /** @src 2:20669:20670  "1" */ 0x01
                /// @src 2:23311:23457  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                {
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:23343:23361  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 2:23343:23363  "m.signingPolicyPos++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23343:23361  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                }
                /// @src 2:23343:23363  "m.signingPolicyPos++"
                {
                    /// @src 2:4462:4464  "22"
                    let _3 := mload(/** @src 2:23343:23361  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 2:23318:23341  "m.signingPolicyPos < 64"
                    if iszero(lt(_3, /** @src 2:22112:22136  "_signingPolicy.threshold" */ 64))
                    /// @src 2:23318:23341  "m.signingPolicyPos < 64"
                    { break }
                    /// @src 2:23420:23446  "toHash[m.signingPolicyPos]"
                    let _4 := read_from_memoryt_bytes1(memory_array_index_access_bytes(expr_mpos_1, /** @src 2:4462:4464  "22" */ _3))
                    let _5 := mload(/** @src 2:23343:23361  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 2:23379:23446  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]"
                    mstore8(memory_array_index_access_bytes(expr_mpos, _5), byte(/** @src -1:-1:-1 */ 0, /** @src 2:23379:23446  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]" */ _4))
                }
                /// @src 2:23467:23506  "bytes32 currentHash = keccak256(toHash)"
                let var_currentHash := /** @src 2:23489:23506  "keccak256(toHash)" */ keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:23489:23506  "keccak256(toHash)" */ expr_mpos_1, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:23489:23506  "keccak256(toHash)" */ expr_mpos_1))
                /// @src 2:4462:4464  "22"
                mstore(zero_struct_Counters_mpos, /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:23544:23555  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:20669:20670  "1" */ 0x01)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:23569:23581  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:22112:22136  "_signingPolicy.threshold" */ 64), /** @src 2:20669:20670  "1" */ 0x01)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:23595:23605  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:23163:23182  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                /// @src 2:23620:25826  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                for { }
                /** @src 2:20669:20670  "1" */ 0x01
                /// @src 2:23620:25826  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                { }
                {
                    /// @src 2:4462:4464  "22"
                    let _6 := mload(/** @src 2:23627:23640  "m.weightIndex" */ zero_struct_Counters_mpos)
                    /// @src 2:23627:23671  "m.weightIndex < _signingPolicy.voters.length"
                    if iszero(lt(_6, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:23643:23664  "_signingPolicy.voters" */ mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))))
                    /// @src 2:23627:23671  "m.weightIndex < _signingPolicy.voters.length"
                    { break }
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128), /** @src -1:-1:-1 */ 0)
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:23712:23722  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src -1:-1:-1 */ 0)
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160), /** @src -1:-1:-1 */ 0)
                    /// @src 2:23789:25499  "while (..."
                    for { }
                    /** @src 2:20669:20670  "1" */ 0x01
                    /// @src 2:23789:25499  "while (..."
                    { }
                    {
                        /// @src 2:23813:23873  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        let expr_8 := /** @src 2:23813:23825  "m.count < 32" */ lt(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128)), /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32)
                        /// @src 2:23813:23873  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if expr_8
                        {
                            /// @src 2:4462:4464  "22"
                            let _7 := mload(/** @src 2:23829:23842  "m.weightIndex" */ zero_struct_Counters_mpos)
                            /// @src 2:23813:23873  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                            expr_8 := /** @src 2:23829:23873  "m.weightIndex < _signingPolicy.voters.length" */ lt(_7, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:23845:23866  "_signingPolicy.voters" */ mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))
                        }
                        /// @src 2:23813:23873  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if iszero(expr_8) { break }
                        /// @src 2:4462:4464  "22"
                        let _8 := mload(/** @src 2:23910:23923  "m.weightIndex" */ zero_struct_Counters_mpos)
                        /// @src 2:23906:25443  "if (m.weightIndex < m.voterIndex) {..."
                        switch /** @src 2:23910:23938  "m.weightIndex < m.voterIndex" */ lt(_8, /** @src 2:4462:4464  "22" */ mload(/** @src 2:23569:23581  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:22112:22136  "_signingPolicy.threshold" */ 64)))
                        case /** @src 2:23906:25443  "if (m.weightIndex < m.voterIndex) {..." */ 0 {
                            /// @src 2:4462:4464  "22"
                            mstore(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160), /** @src 2:24749:24764  "20 - m.voterPos" */ checked_sub_uint256_19232(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23595:23605  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:23163:23182  "_signingPolicy.seed" */ 96))))
                            /// @src 2:4462:4464  "22"
                            let _9 := mload(/** @src 2:23595:23605  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:23163:23182  "_signingPolicy.seed" */ 96))
                            /// @src 2:24786:24791  "m.pos"
                            let _10 := add(zero_struct_Counters_mpos, 224)
                            /// @src 2:4462:4464  "22"
                            mstore(_10, _9)
                            /// @src 2:24895:24916  "_signingPolicy.voters"
                            let _mpos_2 := mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                            /// @src 2:24879:24972  "uint256(uint160(_signingPolicy.voters[m.voterIndex])) <<..."
                            let _11 := shift_left_uint256_uint8_19233(/** @src 2:24879:24932  "uint256(uint160(_signingPolicy.voters[m.voterIndex]))" */ cleanup_address_payable(/** @src 2:24887:24931  "uint160(_signingPolicy.voters[m.voterIndex])" */ cleanup_address_payable(/** @src 2:24895:24930  "_signingPolicy.voters[m.voterIndex]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(_mpos_2, /** @src 2:4462:4464  "22" */ mload(/** @src 2:23569:23581  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:22112:22136  "_signingPolicy.threshold" */ 64)))))))
                            /// @src 2:4462:4464  "22"
                            let _12 := mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128))
                            /// @src 2:25016:25289  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 2:25020:25048  "m.count + m.bytesToTake > 32" */ gt(/** @src 2:25020:25043  "m.count + m.bytesToTake" */ checked_add_uint256(_12, /** @src 2:4462:4464  "22" */ mload(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160))), /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 2:25016:25289  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:23595:23605  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:23163:23182  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:23569:23581  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:22112:22136  "_signingPolicy.threshold" */ 64), /** @src 2:25252:25266  "m.voterIndex++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23569:23581  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:22112:22136  "_signingPolicy.threshold" */ 64))))
                            }
                            default /// @src 2:25016:25289  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 2:25092:25104  "32 - m.count"
                                let _13 := checked_sub_uint256_19234(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128)))
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160), /** @src 2:4462:4464  "22" */ _13)
                                mstore(/** @src 2:23595:23605  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:23163:23182  "_signingPolicy.seed" */ 96), /** @src 2:25130:25157  "m.voterPos += m.bytesToTake" */ checked_add_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23595:23605  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:23163:23182  "_signingPolicy.seed" */ 96)), /** @src 2:4462:4464  "22" */ _13))
                            }
                            mstore(/** @src 2:23712:23722  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 2:25310:25424  "m.nextSlot |= bytes32(..." */ or(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23712:23722  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shr(/** @src 2:25389:25400  "8 * m.count" */ checked_mul_uint256_19235(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128))), /** @src 2:4462:4464  "22" */ shl(/** @src 2:25373:25382  "8 * m.pos" */ checked_mul_uint256_19235(/** @src 2:4462:4464  "22" */ mload(/** @src 2:25377:25382  "m.pos" */ _10)), /** @src 2:4462:4464  "22" */ _11))))
                        }
                        default /// @src 2:23906:25443  "if (m.weightIndex < m.voterIndex) {..."
                        {
                            /// @src 2:4462:4464  "22"
                            mstore(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160), /** @src 2:23978:23993  "2 - m.weightPos" */ checked_sub_uint256_19237(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23544:23555  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32))))
                            /// @src 2:4462:4464  "22"
                            let _14 := mload(/** @src 2:23544:23555  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 2:24015:24020  "m.pos"
                            let _15 := add(zero_struct_Counters_mpos, 224)
                            /// @src 2:4462:4464  "22"
                            mstore(_15, _14)
                            /// @src 2:24154:24176  "_signingPolicy.weights"
                            let _mpos_3 := mload(/** @src 2:21797:21819  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                            /// @src 2:24110:24230  "uint256(..."
                            let _16 := shift_left_uint256_uint8(/** @src 2:24110:24218  "uint256(..." */ cleanup_from_storage_uint16(/** @src 2:24154:24191  "_signingPolicy.weights[m.weightIndex]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos_3, /** @src 2:4462:4464  "22" */ mload(/** @src 2:24177:24190  "m.weightIndex" */ zero_struct_Counters_mpos)))))
                            /// @src 2:4462:4464  "22"
                            let _17 := mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128))
                            /// @src 2:24274:24550  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 2:24278:24306  "m.count + m.bytesToTake > 32" */ gt(/** @src 2:24278:24301  "m.count + m.bytesToTake" */ checked_add_uint256(_17, /** @src 2:4462:4464  "22" */ mload(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160))), /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 2:24274:24550  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:23544:23555  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32), /** @src -1:-1:-1 */ 0)
                                /// @src 2:4462:4464  "22"
                                mstore(zero_struct_Counters_mpos, /** @src 2:24512:24527  "m.weightIndex++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:24512:24527  "m.weightIndex++" */ zero_struct_Counters_mpos)))
                            }
                            default /// @src 2:24274:24550  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 2:24350:24362  "32 - m.count"
                                let _18 := checked_sub_uint256_19234(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128)))
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160), /** @src 2:4462:4464  "22" */ _18)
                                mstore(/** @src 2:23544:23555  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:24388:24416  "m.weightPos += m.bytesToTake" */ checked_add_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23544:23555  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32)), /** @src 2:4462:4464  "22" */ _18))
                            }
                            mstore(/** @src 2:23712:23722  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 2:24571:24686  "m.nextSlot |= bytes32(..." */ or(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23712:23722  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shr(/** @src 2:24651:24662  "8 * m.count" */ checked_mul_uint256_19235(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128))), /** @src 2:4462:4464  "22" */ shl(/** @src 2:24635:24644  "8 * m.pos" */ checked_mul_uint256_19235(/** @src 2:4462:4464  "22" */ mload(/** @src 2:24639:24644  "m.pos" */ _15)), /** @src 2:4462:4464  "22" */ _16))))
                        }
                        mstore(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128), /** @src 2:25460:25484  "m.count += m.bytesToTake" */ checked_add_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128)), /** @src 2:4462:4464  "22" */ mload(/** @src 2:23758:23771  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:21797:21819  "_signingPolicy.weights" */ 160))))
                    }
                    /// @src 2:25512:25816  "if (m.count > 0) {..."
                    if /** @src 2:25516:25527  "m.count > 0" */ iszero(iszero(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128))))
                    /// @src 2:25512:25816  "if (m.count > 0) {..."
                    {
                        /// @src 2:25571:25608  "bytes.concat(currentHash, m.nextSlot)"
                        let expr_mpos_2 := bytes_concat_bytes32_bytes32(var_currentHash, /** @src 2:4462:4464  "22" */ mload(/** @src 2:23712:23722  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)))
                        /// @src 2:25547:25609  "currentHash = keccak256(bytes.concat(currentHash, m.nextSlot))"
                        var_currentHash := /** @src 2:25561:25609  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:25561:25609  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:25561:25609  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2))
                        /// @src 2:25632:25645  "uint256 i = 0"
                        let var_i_1 := /** @src -1:-1:-1 */ 0
                        /// @src 2:25627:25802  "for (uint256 i = 0; i < m.count; i++) {..."
                        for { }
                        /** @src 2:20669:20670  "1" */ 0x01
                        /// @src 2:25632:25645  "uint256 i = 0"
                        {
                            /// @src 2:25660:25663  "i++"
                            var_i_1 := /** @src 2:2993:2996  "300" */ add(/** @src 2:25660:25663  "i++" */ var_i_1, /** @src 2:20669:20670  "1" */ 0x01)
                        }
                        /// @src 2:25660:25663  "i++"
                        {
                            /// @src 2:25647:25658  "i < m.count"
                            if iszero(lt(var_i_1, /** @src 2:4462:4464  "22" */ mload(/** @src 2:23687:23694  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:21611:21632  "_signingPolicy.voters" */ 128))))
                            /// @src 2:25647:25658  "i < m.count"
                            { break }
                            /// @src 2:4462:4464  "22"
                            let _19 := mload(/** @src 2:23712:23722  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192))
                            /// @src 2:25728:25741  "m.nextSlot[i]"
                            if iszero(lt(var_i_1, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 2:25728:25741  "m.nextSlot[i]"
                            { panic_error_0x32() }
                            /// @src 2:25687:25741  "signingPolicyBytes[m.signingPolicyPos] = m.nextSlot[i]"
                            mstore8(memory_array_index_access_bytes(expr_mpos, /** @src 2:4462:4464  "22" */ mload(/** @src 2:23343:23361  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))), /** @src 2:25728:25741  "m.nextSlot[i]" */ byte(var_i_1, _19))
                            /// @src 2:4462:4464  "22"
                            mstore(/** @src 2:23343:23361  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 2:25763:25783  "m.signingPolicyPos++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23343:23361  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                        }
                    }
                }
                /// @src 2:26280:26324  "abi.encodePacked(sourceChainId, currentHash)"
                let expr_mpos_3 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:22112:22136  "_signingPolicy.threshold" */ 64)
                /// @src 2:26280:26324  "abi.encodePacked(sourceChainId, currentHash)"
                let _20 := add(expr_mpos_3, /** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 2:26280:26324  "abi.encodePacked(sourceChainId, currentHash)"
                let _21 := sub(abi_encode_packed_uint256_bytes32(_20, /** @src 2:26297:26310  "sourceChainId" */ loadimmutable("471"), /** @src 2:26280:26324  "abi.encodePacked(sourceChainId, currentHash)" */ var_currentHash), expr_mpos_3)
                mstore(expr_mpos_3, add(_21, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:26280:26324  "abi.encodePacked(sourceChainId, currentHash)"
                finalize_allocation(expr_mpos_3, _21)
                /// @src 2:26270:26325  "keccak256(abi.encodePacked(sourceChainId, currentHash))"
                let expr_9 := keccak256(/** @src 2:4462:4464  "22" */ _20, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:26270:26325  "keccak256(abi.encodePacked(sourceChainId, currentHash))" */ expr_mpos_3))
                /// @src 2:4462:4464  "22"
                sstore(/** @src 2:26335:26391  "toSigningPolicyHashPrivate[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:26362:26390  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))), /** @src 2:4462:4464  "22" */ expr_9)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _22 := cleanup_uint24(mload(/** @src 2:26454:26482  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 2:26415:26482  "stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId"
                update_storage_value_offsett_uint32_to_uint32(cleanup_uint24(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _22))
                /// @src 2:4462:4464  "22"
                sstore(/** @src 2:26492:26544  "startingVotingRoundIds[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24_19244(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _22), /** @src 2:26492:26580  "startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy.startVotingRoundId" */ cleanup_from_storage_uint32(/** @src 2:4462:4464  "22" */ cleanup_from_storage_uint32(mload(/** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))))
                /// @src 2:26633:26661  "_signingPolicy.rewardEpochId"
                let _23 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:26633:26661  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 2:26675:26708  "_signingPolicy.startVotingRoundId"
                let _24 := /** @src 2:4462:4464  "22" */ cleanup_from_storage_uint32(mload(/** @src 2:23053:23086  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))
                /// @src 2:26722:26746  "_signingPolicy.threshold"
                let _25 := /** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:22112:22136  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))
                /// @src 2:4462:4464  "22"
                let _26 := mload(/** @src 2:23163:23182  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 2:26793:26814  "_signingPolicy.voters"
                let _mpos_4 := mload(/** @src 2:21611:21632  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 2:26828:26850  "_signingPolicy.weights"
                let _mpos_5 := mload(/** @src 2:21797:21819  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                /// @src 2:26595:26929  "SigningPolicyInitialized(..."
                let _27 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:22112:22136  "_signingPolicy.threshold" */ 64)
                /// @src 2:26595:26929  "SigningPolicyInitialized(..."
                log2(_27, sub(abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(_27, _24, _25, _26, _mpos_4, _mpos_5, expr_mpos, /** @src 2:4462:4464  "22" */ and(/** @src 2:26903:26918  "block.timestamp" */ timestamp(), /** @src 2:4462:4464  "22" */ 0xffffffffffffffff)), /** @src 2:26595:26929  "SigningPolicyInitialized(..." */ _27), 0x91d0280e969157fc6c5b8f952f237b03d934b18534dafcac839075bbc33522f8, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:26595:26929  "SigningPolicyInitialized(..." */ _23, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffff))
                /// @src 2:11575:11576  "_"
                _1 := expr_9
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
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
            /// @src 2:2993:2996  "300"
            function require_helper_stringliteral_d1bc(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2993:2996  "300"
                    mstore(memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:2993:2996  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:2993:2996  "300" */ add(memPtr, 36), 15)
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:2993:2996  "300" */ memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:2993:2996  "300" */ "too many voters")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_6b32(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2993:2996  "300"
                    mstore(memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:2993:2996  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:2993:2996  "300" */ add(memPtr, 36), 13)
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:2993:2996  "300" */ memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:2993:2996  "300" */ "size mismatch")
                    revert(memPtr, 100)
                }
            }
            function panic_error_0x32()
            {
                mstore(0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2993:2996  "300"
                mstore(4, 0x32)
                revert(0, 0x24)
            }
            function memory_array_index_access_uint16_dyn_19229(baseRef) -> addr
            {
                if iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:2993:2996  "300" */ baseRef)) { panic_error_0x32() }
                addr := add(baseRef, 32)
            }
            function memory_array_index_access_uint16_dyn(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:2993:2996  "300" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, shl(5, index)), 32)
            }
            function read_from_memoryt_uint16(ptr) -> returnValue
            {
                returnValue := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2993:2996  "300" */ mload(ptr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff)
            }
            /// @src 2:2993:2996  "300"
            function checked_add_uint256_19170(x) -> sum
            {
                sum := add(x, /** @src 2:30826:30827  "1" */ 0x01)
                /// @src 2:2993:2996  "300"
                if gt(x, sum) { panic_error_0x11() }
            }
            function checked_add_uint256_19228(y) -> sum
            {
                sum := add(/** @src 2:4600:4602  "43" */ 0x2b, /** @src 2:2993:2996  "300" */ y)
                if gt(/** @src 2:4600:4602  "43" */ 0x2b, /** @src 2:2993:2996  "300" */ sum) { panic_error_0x11() }
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
                    let memPtr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2993:2996  "300"
                    mstore(memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:2993:2996  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:2993:2996  "300" */ add(memPtr, 36), 20)
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:2993:2996  "300" */ memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:2993:2996  "300" */ "total weight too big")
                    revert(memPtr, 100)
                }
            }
            /// @src 2:2895:2900  "10000"
            function checked_mul_uint256_19169(x) -> product
            {
                product := mul(x, /** @src 2:30244:30246  "65" */ 0x41)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:30244:30246  "65" */ 0x41, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19223(x) -> product
            {
                product := mul(x, 0x2710)
                if iszero(or(iszero(x), eq(0x2710, div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19224(x) -> product
            {
                product := mul(x, /** @src 2:3048:3052  "5000" */ 0x1388)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:3048:3052  "5000" */ 0x1388, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19226(x) -> product
            {
                product := mul(x, /** @src 2:3104:3108  "6600" */ 0x19c8)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:3104:3108  "6600" */ 0x19c8, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19227(x) -> product
            {
                product := mul(x, /** @src 2:4462:4464  "22" */ 0x16)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:4462:4464  "22" */ 0x16, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_19235(y) -> product
            {
                product := shl(3, y)
                if iszero(eq(y, and(y, sub(shl(253, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 1), 1))))
                /// @src 2:2895:2900  "10000"
                { panic_error_0x11() }
            }
            function checked_mul_uint256(x, y) -> product
            {
                product := mul(x, y)
                if iszero(or(iszero(x), eq(y, div(product, x)))) { panic_error_0x11() }
            }
            /// @src 2:3048:3052  "5000"
            function require_helper_stringliteral_d8d1(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:3048:3052  "5000"
                    mstore(memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:3048:3052  "5000"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:3048:3052  "5000" */ add(memPtr, 36), 19)
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:3048:3052  "5000" */ memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:3048:3052  "5000" */ "too small threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 2:3104:3108  "6600"
            function require_helper_stringliteral_185c(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:3104:3108  "6600"
                    mstore(memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:3104:3108  "6600"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:3104:3108  "6600" */ add(memPtr, 36), 17)
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:3104:3108  "6600" */ memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:3104:3108  "6600" */ "too big threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 2:4462:4464  "22"
            function allocate_and_zero_memory_array_bytes(length) -> memPtr
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := array_allocation_size_bytes(length)
                let memPtr_1 := mload(64)
                finalize_allocation(memPtr_1, _1)
                mstore(memPtr_1, length)
                /// @src 2:4462:4464  "22"
                memPtr := memPtr_1
                calldatacopy(add(memPtr_1, 32), calldatasize(), add(array_allocation_size_bytes(length), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
            }
            /// @src 2:4462:4464  "22"
            function allocate_and_zero_memory_struct_struct_Counters() -> memPtr
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPtr_1 := mload(64)
                let newFreePtr := add(memPtr_1, /** @src 2:4462:4464  "22" */ 288)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1)) { panic_error_0x41() }
                mstore(64, newFreePtr)
                /// @src 2:4462:4464  "22"
                memPtr := memPtr_1
                mstore(memPtr_1, /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 32), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 96), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 128), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 160), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 192), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 224), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 256), /** @src -1:-1:-1 */ 0)
            }
            /// @src 2:4462:4464  "22"
            function convert_uint16_to_bytes2(value) -> converted
            {
                converted := and(shl(240, value), shl(240, 65535))
            }
            function convert_uint24_to_bytes3(value) -> converted
            {
                converted := and(shl(232, value), /** @src 2:37658:87889  "assembly {..." */ shl(232, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 16777215))
            }
            /// @src 2:4462:4464  "22"
            function convert_uint32_to_bytes4(value) -> converted
            {
                converted := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shl(224, /** @src 2:4462:4464  "22" */ value), shl(224, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            }
            /// @src 2:4462:4464  "22"
            function read_from_memoryt_address(ptr) -> returnValue
            {
                returnValue := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:4462:4464  "22" */ mload(ptr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
            }
            /// @src 2:4462:4464  "22"
            function convert_address_to_bytes20(value) -> converted
            {
                converted := and(shl(96, value), not(0xffffffffffffffffffffffff))
            }
            function shift_right_uint16_uint8(value) -> result
            {
                result := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shr(8, /** @src 2:4462:4464  "22" */ value), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)
            }
            /// @src 2:4462:4464  "22"
            function convert_uint8_to_bytes1(value) -> converted
            {
                converted := and(shl(248, value), shl(248, 255))
            }
            function bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(param, param_1, param_2, param_3, param_4, param_5, param_6) -> outPtr
            {
                outPtr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 0x20), and(param, shl(240, 65535)))
                mstore(add(outPtr, 34), and(param_1, /** @src 2:37658:87889  "assembly {..." */ shl(232, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 16777215)))
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 37), and(param_2, shl(224, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 41), and(param_3, shl(240, 65535)))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 2:4462:4464  "22" */ add(outPtr, 43), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ param_4)
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 75), and(param_5, not(0xffffffffffffffffffffffff)))
                mstore(add(outPtr, 95), and(param_6, shl(248, 255)))
                mstore(outPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)
                /// @src 2:4462:4464  "22"
                finalize_allocation(outPtr, 96)
            }
            function increment_uint256(value) -> ret
            {
                if eq(value, /** @src 2:37658:87889  "assembly {..." */ not(0))
                /// @src 2:4462:4464  "22"
                { panic_error_0x11() }
                ret := add(value, 1)
            }
            function memory_array_index_access_bytes(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:4462:4464  "22" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, index), 32)
            }
            function read_from_memoryt_bytes1(ptr) -> returnValue
            {
                returnValue := and(mload(ptr), shl(248, 255))
            }
            function shift_left_uint256_uint8_19233(value) -> result
            {
                result := shl(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 96, /** @src 2:4462:4464  "22" */ value)
            }
            function shift_left_uint256_uint8(value) -> result
            {
                result := shl(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 240, /** @src 2:4462:4464  "22" */ value)
            }
            function bytes_concat_bytes32_bytes32(param, param_1) -> outPtr
            {
                outPtr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                mstore(/** @src 2:4462:4464  "22" */ add(outPtr, 0x20), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ param)
                mstore(/** @src 2:4462:4464  "22" */ add(outPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), param_1)
                /// @src 2:4462:4464  "22"
                mstore(outPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)
                /// @src 2:4462:4464  "22"
                finalize_allocation(outPtr, 96)
            }
            function abi_encode_packed_uint256_bytes32(pos, value0, value1) -> end
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(pos, value0)
                mstore(/** @src 2:4462:4464  "22" */ add(pos, 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                /// @src 2:4462:4464  "22"
                end := add(pos, 64)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24(key) -> dataSlot
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:4462:4464  "22" */ key, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffff))
                /// @src 2:4462:4464  "22"
                mstore(0x20, /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                dataSlot := keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:4462:4464  "22" */ 0x40)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24_19244(key) -> dataSlot
            {
                mstore(0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:4462:4464  "22" */ key, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffff))
                /// @src 2:4462:4464  "22"
                mstore(0x20, /** @src 2:26492:26514  "startingVotingRoundIds" */ 0x02)
                /// @src 2:4462:4464  "22"
                dataSlot := keccak256(0, 0x40)
            }
            function update_storage_value_offsett_bytes32_to_bytes32_19411(value)
            {
                sstore(/** @src 2:29389:29412  "lastGovernanceSafeNonce" */ 0x08, /** @src 2:4462:4464  "22" */ value)
            }
            function update_storage_value_offsett_bytes32_to_bytes32_19432(value)
            {
                sstore(/** @src 2:33354:33385  "governanceThreshold = threshold" */ 0x09, /** @src 2:4462:4464  "22" */ value)
            }
            function update_storage_value_offsett_bytes32_to_bytes32_19433(value)
            {
                sstore(/** @src 2:33395:33429  "activeOwnerConfigSafeNonce = nonce" */ 0x07, /** @src 2:4462:4464  "22" */ value)
            }
            function update_storage_value_offsett_bytes32_to_bytes32(value)
            {
                sstore(/** @src 2:32810:32831  "activeOwnerConfigHash" */ 0x06, /** @src 2:4462:4464  "22" */ value)
            }
            function update_storage_value_offsett_uint32_to_uint32(value)
            {
                let _1 := sload(/** @src 2:20630:20639  "stateData" */ 0x0d)
                /// @src 2:4462:4464  "22"
                sstore(/** @src 2:20630:20639  "stateData" */ 0x0d, /** @src 2:4462:4464  "22" */ or(and(_1, not(shl(152, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:4462:4464  "22" */ and(shl(152, value), shl(152, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))))
            }
            /// @src 2:4462:4464  "22"
            function abi_encode_array_address_dyn(value, pos) -> end
            {
                let length := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:4462:4464  "22" */ value)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(pos, length)
                /// @src 2:4462:4464  "22"
                pos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(pos, 0x20)
                /// @src 2:4462:4464  "22"
                let srcPtr := add(value, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
                /// @src 2:4462:4464  "22"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 2:4462:4464  "22"
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(pos, and(/** @src 2:4462:4464  "22" */ mload(srcPtr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 2:4462:4464  "22"
                    pos := add(pos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
                    /// @src 2:4462:4464  "22"
                    srcPtr := add(srcPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
                }
                /// @src 2:4462:4464  "22"
                end := pos
            }
            function abi_encode_uint64(value, pos)
            {
                mstore(pos, and(value, 0xffffffffffffffff))
            }
            function abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(headStart, value0, value1, value2, value3, value4, value5, value6) -> tail
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, and(value0, 0xffffffff))
                mstore(/** @src 2:4462:4464  "22" */ add(headStart, 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value1, 0xffff))
                mstore(/** @src 2:4462:4464  "22" */ add(headStart, 64), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value2)
                /// @src 2:4462:4464  "22"
                mstore(add(headStart, 96), 224)
                let tail_1 := abi_encode_array_address_dyn(value3, add(headStart, 224))
                mstore(add(headStart, 128), sub(tail_1, headStart))
                let pos := tail_1
                let length := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:4462:4464  "22" */ value4)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(tail_1, length)
                /// @src 2:4462:4464  "22"
                pos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(tail_1, /** @src 2:4462:4464  "22" */ 32)
                let srcPtr := add(value4, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(pos, and(/** @src 2:4462:4464  "22" */ mload(srcPtr), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff))
                    /// @src 2:4462:4464  "22"
                    pos := add(pos, 32)
                    srcPtr := add(srcPtr, 32)
                }
                mstore(add(headStart, 160), sub(pos, headStart))
                tail := abi_encode_bytes(value5, pos)
                abi_encode_uint64(value6, add(headStart, 192))
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function storage_array_index_access_address_dyn(index) -> slot, offset
            {
                if iszero(lt(index, sload(/** @src 2:36077:36093  "governanceOwners" */ 0x0a)))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:36077:36093  "governanceOwners" */ 0x0a)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20), index)
                offset := /** @src -1:-1:-1 */ 0
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function abi_decode_uint256t_boolt_uint256_fromMemory(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := mload(headStart)
                value0 := value
                value1 := abi_decode_t_bool_fromMemory(add(headStart, 32))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := mload(add(headStart, 64))
                value2 := value_1
            }
            function mapping_index_access_mapping_uint256_mapping_uint256_bytes32_of_uint8(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, /** @src 2:94112:94130  "merkleRootsPrivate" */ 0x01)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
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
            function checked_div_uint256_19167(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := div(x, /** @src 2:30244:30246  "65" */ 0x41)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function checked_div_uint256_19294(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := shr(8, x)
            }
            function checked_div_uint256_19435(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := shr(1, x)
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
            function mod_uint256_19168(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := mod(x, /** @src 2:30244:30246  "65" */ 0x41)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function mod_uint256(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := and(x, 255)
            }
            /// @ast-id 3091 @src 2:93459:94647  "function getRandomNumberHistorical(uint256 _votingRoundId)..."
            function fun_getRandomNumberHistorical(var__votingRoundId) -> var_randomNumber, var_isSecureRandom, var_randomTimestamp
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := and(/** @src 2:93692:93700  "oldRelay" */ loadimmutable("537"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:93692:93787  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:93692:93722  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:93692:93787  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:93726:93787  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var__votingRoundId, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:93743:93787  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("543"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:93688:93871  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:93810:93860  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _2 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:93810:93860  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    mstore(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(227, 0x150fe287))
                    /// @src 2:93810:93860  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_bytes32(add(_2, 4), var__votingRoundId), _2), _2, 96)
                    if iszero(_3) { revert_forward() }
                    let expr_3018_component := /** @src 2:93719:93720  "0" */ 0x00
                    let expr_3018_component_1 := 0x00
                    let expr_component := 0x00
                    /// @src 2:93810:93860  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    if _3
                    {
                        let _4 := 96
                        if gt(96, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        let expr_component_1, expr_component_2, expr_component_3 := abi_decode_uint256t_boolt_uint256_fromMemory(_2, add(_2, _4))
                        expr_3018_component := expr_component_1
                        expr_3018_component_1 := expr_component_2
                        expr_component := expr_component_3
                    }
                    /// @src 2:93803:93860  "return oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    var_randomNumber := expr_3018_component
                    var_isSecureRandom := expr_3018_component_1
                    var_randomTimestamp := expr_component
                    leave
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _5 := sload(/** @src 2:94131:94140  "stateData" */ 0x0d)
                /// @src 2:94091:94236  "require(..."
                require_helper_stringliteral_2275(/** @src 2:94112:94194  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:94112:94180  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:94112:94164  "merkleRootsPrivate[stateData.randomNumberProtocolId]" */ mapping_index_access_mapping_uint256_mapping_uint256_bytes32_of_uint8(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_from_storage_uint8(_5)), /** @src 2:94112:94180  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ var__votingRoundId)))))
                /// @src 2:94246:94299  "_randomNumber = toRandomNumberPrivate[_votingRoundId]"
                var_randomNumber := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:94262:94299  "toRandomNumberPrivate[_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19293(var__votingRoundId))
                /// @src 2:94309:94473  "_isSecureRandom =..."
                var_isSecureRandom := /** @src 2:94339:94473  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))..." */ eq(/** @src 2:94339:94434  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))" */ and(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shr(/** @src 2:94384:94410  "255 - _votingRoundId % 256" */ checked_sub_uint256_19297(/** @src 2:94390:94410  "_votingRoundId % 256" */ mod_uint256(var__votingRoundId)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:94340:94379  "isSecureRandomMap[_votingRoundId / 256]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19295(/** @src 2:94358:94378  "_votingRoundId / 256" */ checked_div_uint256_19294(var__votingRoundId)))), /** @src 2:94112:94130  "merkleRootsPrivate" */ 0x01), 0x01)
                /// @src 2:94514:94547  "stateData.firstVotingRoundStartTs"
                let _6 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offset_1t_uint32(_5)
                /// @src 2:94570:94588  "_votingRoundId + 1"
                let expr_1 := checked_add_uint256_19170(var__votingRoundId)
                /// @src 2:94483:94640  "_randomTimestamp =..."
                var_randomTimestamp := /** @src 2:94514:94640  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:94514:94640  "stateData.firstVotingRoundStartTs +..." */ _6, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), /** @src 2:94562:94640  "uint256(_votingRoundId + 1) *..." */ checked_mul_uint256(expr_1, cleanup_from_storage_uint8(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_uint8(_5))))
            }
            function read_from_calldatat_uint8(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                if iszero(eq(value, and(value, 0xff))) { revert(0, 0) }
                returnValue := value
            }
            function access_calldata_tail_bytes_calldata(base_ref, ptr_to_tail) -> addr, length
            {
                let rel_offset_of_tail := calldataload(ptr_to_tail)
                if iszero(slt(rel_offset_of_tail, add(sub(calldatasize(), base_ref), not(30)))) { revert(0, 0) }
                let addr_1 := add(base_ref, rel_offset_of_tail)
                length := calldataload(addr_1)
                if gt(length, 0xffffffffffffffff) { revert(0, 0) }
                addr := add(addr_1, 0x20)
                if sgt(addr, sub(calldatasize(), length)) { revert(0, 0) }
            }
            function abi_encode_stringliteral_0d64(headStart) -> tail
            {
                mstore(headStart, 32)
                mstore(add(headStart, 32), 17)
                mstore(add(headStart, 64), "Not enough weight")
                tail := add(headStart, 96)
            }
            /// @src 2:37658:87889  "assembly {..."
            function usr$revertWithMessage_19174(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy metadata")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19175(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy length")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19177(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Signing policy hash mismatch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19178(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "Too short message")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19179(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Already relayed")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19180(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "Wrong message format")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19182(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Wrong message format2")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19183(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong sign policy reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Message too old")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19185(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "Delayed sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19187(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Must use new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19190(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Sign policy relay disabled")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19191(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 23)
                mstore(add(usr_memPtr, 0x44), "No new sign policy size")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19192(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "must be non-trivial")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19193(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "too many voters")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19194(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong size for new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19196(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Not with last intialized")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19197(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not next reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19199(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "No signature count")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19200(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not enough signatures")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19201(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of range")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19202(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of order")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19203(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad v")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19204(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad s")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19205(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "ecrecover error")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19206(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "ecrecover returned bad data")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19207(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 11)
                mstore(add(usr_memPtr, 0x44), "Zero signer")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19208(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Wrong signature")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19209(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "zero merkle root")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19215(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "This should never happen")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19306(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "total weight too big")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19307(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "too small threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19308(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "too big threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19309(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "No random number")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19310(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 22)
                mstore(add(usr_memPtr, 0x44), "Incorrect merkle proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_19311(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:37658:87889  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "Invalid random number proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$assignStruct(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, /** @src 2:4462:4464  "22" */ not(shl(152, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:37658:87889  "assembly {..." */ shl(152, usr$newVal))
            }
            function usr$assignStruct_19213(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(112, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:37658:87889  "assembly {..." */ shl(112, usr$newVal))
            }
            function usr$assignStruct_19214(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(144, /** @src 2:4462:4464  "22" */ 255))), /** @src 2:37658:87889  "assembly {..." */ shl(144, usr$newVal))
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
                    mstore(_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:37658:87889  "assembly {..."
                    mstore(add(_1, 0x04), 0x20)
                    mstore(add(_1, 0x24), 23)
                    mstore(add(_1, 0x44), "Invalid voting round id")
                    revert(_1, 0x64)
                }
                usr_rewardEpochId := div(sub(usr$_votingRoundId, usr$firstRewardEpochStartVotingRoundId), and(shr(80, usr_stateDataObj), 65535))
            }
            function usr$calculateSigningPolicyHash_19176(usr_memPos, usr_policyLength, usr_scid) -> usr_policyHash
            {
                calldatacopy(usr_memPos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4, /** @src 2:37658:87889  "assembly {..." */ 32)
                let usr$endPos := add(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 4, /** @src 2:37658:87889  "assembly {..." */ and(usr_policyLength, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:37658:87889  "assembly {..."
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
                mstore(usr_memPos, usr_scid)
                mstore(add(usr_memPos, 32), usr_policyHash)
                usr_policyHash := keccak256(usr_memPos, 64)
            }
            function usr$calculateSigningPolicyHash(usr_memPos, usr_calldataPos, usr_policyLength, usr_scid) -> usr_policyHash
            {
                calldatacopy(usr_memPos, usr_calldataPos, 32)
                let usr$endPos := add(usr_calldataPos, and(usr_policyLength, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:37658:87889  "assembly {..."
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
                mstore(usr_memPos, usr_scid)
                mstore(add(usr_memPos, 32), usr_policyHash)
                usr_policyHash := keccak256(usr_memPos, 64)
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
                    usr$revertWithMessage_19306(usr_memPtr)
                }
                let _1 := mul(and(usr_metadata, 65535), 10000)
                if lt(_1, mul(usr$totalWeight, 5000))
                {
                    usr$revertWithMessage_19307(usr_memPtr)
                }
                if gt(_1, mul(usr$totalWeight, 6600))
                {
                    usr$revertWithMessage_19308(usr_memPtr)
                }
            }
            function usr$setIsSecureRandomBit(usr_memPtr, usr_votingRoundId)
            {
                mstore(usr_memPtr, shr(8, usr_votingRoundId))
                mstore(add(usr_memPtr, 32), 12)
                let _1 := keccak256(usr_memPtr, 64)
                sstore(_1, or(sload(_1), shl(sub(255, and(usr_votingRoundId, 255)), 1)))
            }
            function usr$processRandomMerkleProof(usr_memPtr, usr_proofStart, usr_memPtrMerkleRoot, usr_votingRoundId, usr_isSecureRandom)
            {
                let _1 := add(usr_proofStart, 32)
                if lt(calldatasize(), _1)
                {
                    usr$revertWithMessage_19309(usr_memPtr)
                }
                if iszero(iszero(and(sub(calldatasize(), usr_proofStart), 31)))
                {
                    usr$revertWithMessage_19310(usr_memPtr)
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
                    usr$revertWithMessage_19311(usr_memPtr)
                }
                calldatacopy(_3, usr_proofStart, 32)
                mstore(usr_memPtr, usr_votingRoundId)
                mstore(_2, 14)
                sstore(keccak256(usr_memPtr, 64), mload(_3))
            }
            /// @ast-id 4227 @src 9:4637:4809  "function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {..."
            function fun_verifyCalldata(var_proof_offset, var_proof_length, var_root, var_leaf) -> var
            {
                /// @src 9:5324:5351  "bytes32 computedHash = leaf"
                let var_computedHash := var_leaf
                /// @src 9:5366:5379  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 9:5361:5495  "for (uint256 i = 0; i < proof.length; i++) {..."
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 9:5366:5379  "uint256 i = 0"
                {
                    /// @src 9:5399:5402  "i++"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 9:5399:5402  "i++" */ var_i, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 9:5399:5402  "i++"
                {
                    /// @src 9:5381:5397  "i < proof.length"
                    let _1 := iszero(lt(var_i, /** @src 9:5385:5397  "proof.length" */ var_proof_length))
                    /// @src 9:5381:5397  "i < proof.length"
                    if _1 { break }
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    _1 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    let value := calldataload(add(var_proof_offset, shl(5, var_i)))
                    /// @src 8:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    let expr := /** @src -1:-1:-1 */ 0
                    /// @src 8:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    switch /** @src 8:605:610  "a < b" */ lt(var_computedHash, value)
                    case /** @src 8:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)" */ 0 {
                        /// @src 8:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 8:889:1024  "assembly (\"memory-safe\") {..." */ value)
                        mstore(0x20, var_computedHash)
                        /// @src 8:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 8:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 8:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    default /// @src 8:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                    {
                        /// @src 8:889:1024  "assembly (\"memory-safe\") {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 8:889:1024  "assembly (\"memory-safe\") {..." */ var_computedHash)
                        mstore(0x20, value)
                        /// @src 8:605:664  "a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a)"
                        expr := /** @src 8:889:1024  "assembly (\"memory-safe\") {..." */ keccak256(/** @src -1:-1:-1 */ 0, /** @src 8:889:1024  "assembly (\"memory-safe\") {..." */ 0x40)
                    }
                    /// @src 9:5418:5484  "computedHash = Hashes.commutativeKeccak256(computedHash, proof[i])"
                    var_computedHash := expr
                }
                /// @src 9:4754:4802  "return processProofCalldata(proof, leaf) == root"
                var := /** @src 9:4761:4802  "processProofCalldata(proof, leaf) == root" */ eq(var_computedHash, var_root)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function require_helper_stringliteral_3323(condition)
            {
                if iszero(condition)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 23)
                    mstore(add(memPtr, 68), "Wrong verification data")
                    revert(memPtr, 100)
                }
            }
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
            function allocate_and_zero_memory_array_array_address_dyn(length) -> memPtr
            {
                let _1 := array_allocation_size_array_address_dyn(length)
                let memPtr_1 := mload(64)
                finalize_allocation(memPtr_1, _1)
                mstore(memPtr_1, length)
                memPtr := memPtr_1
                /// @src 2:4462:4464  "22"
                calldatacopy(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr_1, 32), /** @src 2:4462:4464  "22" */ calldatasize(), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ add(array_allocation_size_array_address_dyn(length), not(31)))
            }
            function calldata_array_index_range_access_bytes_calldata_19424(offset, length, endIndex) -> offsetOut, lengthOut
            {
                if gt(/** @src 2:33767:33768  "4" */ 0x04, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ endIndex) { revert(0, 0) }
                if gt(endIndex, length) { revert(0, 0) }
                offsetOut := add(offset, /** @src 2:33767:33768  "4" */ 0x04)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                lengthOut := add(endIndex, not(3))
            }
            function calldata_array_index_range_access_bytes_calldata(offset, length, startIndex, endIndex) -> offsetOut, lengthOut
            {
                if gt(startIndex, endIndex) { revert(0, 0) }
                if gt(endIndex, length) { revert(0, 0) }
                offsetOut := add(offset, startIndex)
                lengthOut := sub(endIndex, startIndex)
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
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                calldatacopy(add(memPtr, 0x20), src, length)
                mstore(add(add(memPtr, length), 0x20), /** @src -1:-1:-1 */ 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function validator_assert_enum_RecoverError(value)
            {
                if iszero(lt(value, 4))
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x21)
                    revert(0, 0x24)
                }
            }
            function write_to_memory_address(memPtr, value)
            {
                mstore(memPtr, and(value, sub(shl(160, 1), 1)))
            }
            function read_from_storage_split_offset_bool(slot) -> value
            {
                value := and(sload(slot), 0xff)
            }
            /// @src 2:10363:10447  "bytes4(keccak256(\"changeProtocolFees(uint256,bytes32,(uint256,uint256,uint256)[])\"))"
            function abi_encode_bytes4(value0) -> tail
            {
                tail := 36
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:29738:29771  "UnknownGovernanceAction(selector)" */ 4, /** @src 2:4462:4464  "22" */ and(value0, shl(224, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
            }
            /// @src 2:10363:10447  "bytes4(keccak256(\"changeProtocolFees(uint256,bytes32,(uint256,uint256,uint256)[])\"))"
            function update_storage_value_offsett_bool_to_bool(slot)
            {
                sstore(slot, or(and(sload(slot), not(/** @src 2:4462:4464  "22" */ 255)), /** @src 2:29627:29631  "true" */ 0x01))
            }
            /// @ast-id 1860 @src 2:28195:29788  "function _processVerifiedGovernanceAction(bytes calldata action, uint256 safeTxNonce) internal {..."
            function fun_processVerifiedGovernanceAction(var_action_offset, var_action_length, var_safeTxNonce)
            {
                /// @src 2:28318:28345  "_governanceSelector(action)"
                let expr := fun_governanceSelector(var_action_offset, var_action_length)
                /// @src 2:28377:28407  "_governanceActionNonce(action)"
                let expr_1 := fun_governanceActionNonce(var_action_offset, var_action_length)
                /// @src 2:28421:28487  "safeTxNonce == type(uint256).max || actionNonce != safeTxNonce + 1"
                let expr_2 := /** @src 2:28421:28453  "safeTxNonce == type(uint256).max" */ eq(var_safeTxNonce, /** @src 2:37658:87889  "assembly {..." */ not(0))
                /// @src 2:28421:28487  "safeTxNonce == type(uint256).max || actionNonce != safeTxNonce + 1"
                if iszero(expr_2)
                {
                    expr_2 := /** @src 2:28457:28487  "actionNonce != safeTxNonce + 1" */ iszero(eq(expr_1, /** @src 2:28472:28487  "safeTxNonce + 1" */ checked_add_uint256_19170(var_safeTxNonce)))
                }
                /// @src 2:28417:28551  "if (safeTxNonce == type(uint256).max || actionNonce != safeTxNonce + 1) {..."
                if expr_2
                {
                    /// @src 2:28510:28540  "InvalidGovernanceTransaction()"
                    mstore(0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:28510:28540  "InvalidGovernanceTransaction()"
                    revert(0, 4)
                }
                /// @src 2:28579:28600  "governanceReplayFloor"
                let _1 := loadimmutable("477")
                /// @src 2:28560:28702  "if (actionNonce <= governanceReplayFloor) {..."
                if /** @src 2:28564:28600  "actionNonce <= governanceReplayFloor" */ iszero(gt(expr_1, _1))
                /// @src 2:28560:28702  "if (actionNonce <= governanceReplayFloor) {..."
                {
                    /// @src 2:28623:28691  "GovernanceNonceBeforeReplayFloor(actionNonce, governanceReplayFloor)"
                    mstore(0, shl(224, 0x2db8fdf3))
                    revert(0, abi_encode_uint256_uint256_19404(expr_1, _1))
                }
                /// @src 2:28711:28832  "if (governanceSafeNonceConsumed[actionNonce]) {..."
                if /** @src 2:28715:28755  "governanceSafeNonceConsumed[actionNonce]" */ read_from_storage_split_offset_bool(mapping_index_access_mapping_uint256_uint256_of_uint256_19405(expr_1))
                /// @src 2:28711:28832  "if (governanceSafeNonceConsumed[actionNonce]) {..."
                {
                    /// @src 2:28778:28821  "GovernanceNonceAlreadyConsumed(actionNonce)"
                    mstore(0, shl(225, 0x516aabb5))
                    revert(0, abi_encode_uint256(expr_1))
                }
                /// @src 2:28845:28879  "selector == CHANGE_OWNERS_SELECTOR"
                let _2 := /** @src 2:4462:4464  "22" */ and(/** @src 2:28845:28879  "selector == CHANGE_OWNERS_SELECTOR" */ expr, /** @src 2:4462:4464  "22" */ shl(224, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                /// @src 2:28841:29782  "if (selector == CHANGE_OWNERS_SELECTOR) {..."
                switch /** @src 2:28845:28879  "selector == CHANGE_OWNERS_SELECTOR" */ eq(_2, /** @src 2:4462:4464  "22" */ shl(226, 0x23d0fe25))
                case /** @src 2:28841:29782  "if (selector == CHANGE_OWNERS_SELECTOR) {..." */ 0 {
                    /// @src 2:29309:29782  "if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {..."
                    switch /** @src 2:29313:29354  "selector == CHANGE_PROTOCOL_FEES_SELECTOR" */ eq(_2, /** @src 2:4462:4464  "22" */ shl(225, 0x0ac2ae7b))
                    case /** @src 2:29309:29782  "if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {..." */ 0 {
                        /// @src 2:29738:29771  "UnknownGovernanceAction(selector)"
                        mstore(0, shl(228, 0x0cd3f8fb))
                        revert(0, abi_encode_bytes4(expr))
                    }
                    default /// @src 2:29309:29782  "if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {..."
                    {
                        /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                        let _3 := sload(/** @src 2:29389:29412  "lastGovernanceSafeNonce" */ 0x08)
                        /// @src 2:29370:29519  "if (actionNonce <= lastGovernanceSafeNonce) {..."
                        if /** @src 2:29374:29412  "actionNonce <= lastGovernanceSafeNonce" */ iszero(gt(expr_1, _3))
                        /// @src 2:29370:29519  "if (actionNonce <= lastGovernanceSafeNonce) {..."
                        {
                            /// @src 2:29439:29504  "GovernanceNonceNotMonotonic(actionNonce, lastGovernanceSafeNonce)"
                            mstore(/** @src -1:-1:-1 */ 0, /** @src 2:29439:29504  "GovernanceNonceNotMonotonic(actionNonce, lastGovernanceSafeNonce)" */ shl(224, 0xeaafa115))
                            revert(/** @src -1:-1:-1 */ 0, /** @src 2:29439:29504  "GovernanceNonceNotMonotonic(actionNonce, lastGovernanceSafeNonce)" */ abi_encode_uint256_uint256_19404(expr_1, _3))
                        }
                        /// @src 2:29532:29701  "if (_applyGovernanceFees(action)) {..."
                        if /** @src 2:29536:29564  "_applyGovernanceFees(action)" */ fun_applyGovernanceFees(var_action_offset, var_action_length)
                        /// @src 2:29532:29701  "if (_applyGovernanceFees(action)) {..."
                        {
                            /// @src 2:29584:29631  "governanceSafeNonceConsumed[actionNonce] = true"
                            update_storage_value_offsett_bool_to_bool(/** @src 2:29584:29624  "governanceSafeNonceConsumed[actionNonce]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19405(expr_1))
                            /// @src 2:29649:29686  "lastGovernanceSafeNonce = actionNonce"
                            update_storage_value_offsett_bytes32_to_bytes32_19411(expr_1)
                        }
                    }
                }
                default /// @src 2:28841:29782  "if (selector == CHANGE_OWNERS_SELECTOR) {..."
                {
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    let _4 := sload(/** @src 2:28914:28940  "activeOwnerConfigSafeNonce" */ 0x07)
                    /// @src 2:28895:29062  "if (actionNonce <= activeOwnerConfigSafeNonce) {..."
                    if /** @src 2:28899:28940  "actionNonce <= activeOwnerConfigSafeNonce" */ iszero(gt(expr_1, _4))
                    /// @src 2:28895:29062  "if (actionNonce <= activeOwnerConfigSafeNonce) {..."
                    {
                        /// @src 2:28967:29047  "GovernanceOwnerConfigNonceNotIncreasing(actionNonce, activeOwnerConfigSafeNonce)"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:28967:29047  "GovernanceOwnerConfigNonceNotIncreasing(actionNonce, activeOwnerConfigSafeNonce)" */ shl(224, 0xfda3669f))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:28967:29047  "GovernanceOwnerConfigNonceNotIncreasing(actionNonce, activeOwnerConfigSafeNonce)" */ abi_encode_uint256_uint256_19404(expr_1, _4))
                    }
                    /// @src 2:29098:29104  "action"
                    fun_applyGovernanceOwners(var_action_offset, var_action_length)
                    /// @src 2:29119:29166  "governanceSafeNonceConsumed[actionNonce] = true"
                    update_storage_value_offsett_bool_to_bool(/** @src 2:29119:29159  "governanceSafeNonceConsumed[actionNonce]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19405(expr_1))
                    /// @src 2:29180:29293  "if (actionNonce > lastGovernanceSafeNonce) {..."
                    if /** @src 2:29184:29221  "actionNonce > lastGovernanceSafeNonce" */ gt(expr_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:29198:29221  "lastGovernanceSafeNonce" */ 0x08))
                    /// @src 2:29180:29293  "if (actionNonce > lastGovernanceSafeNonce) {..."
                    {
                        /// @src 2:29241:29278  "lastGovernanceSafeNonce = actionNonce"
                        update_storage_value_offsett_bytes32_to_bytes32_19411(expr_1)
                    }
                }
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function allocate_and_zero_memory_struct_struct_Transaction() -> memPtr
            {
                let memPtr_1 := mload(64)
                let newFreePtr := add(memPtr_1, 320)
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1)) { panic_error_0x41() }
                mstore(64, newFreePtr)
                memPtr := memPtr_1
                mstore(memPtr_1, /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 32), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 64), 96)
                mstore(add(memPtr_1, 96), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 128), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 160), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 192), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 224), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 256), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 288), /** @src -1:-1:-1 */ 0)
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function read_from_calldatat_address(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                validator_revert_address(value)
                returnValue := value
            }
            function write_to_memory_uint8(memPtr, value)
            {
                mstore(memPtr, and(value, 0xff))
            }
            /// @ast-id 2117 @src 2:31797:32298  "function _copyGovernanceTx(GnosisSafeTx.Transaction calldata source)..."
            function fun_copyGovernanceTx(var_source_offset) -> var_target_mpos
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                pop(allocate_and_zero_memory_struct_struct_Transaction())
                /// @src 2:32014:32023  "source.to"
                let expr := read_from_calldatat_address(var_source_offset)
                /// @src 2:32037:32049  "source.value"
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(/** @src 2:32037:32049  "source.value" */ add(var_source_offset, 32))
                /// @src 2:32063:32074  "source.data"
                let expr_2098_offset, expr_2098_length := access_calldata_tail_bytes_calldata(var_source_offset, add(var_source_offset, 64))
                /// @src 2:32088:32104  "source.operation"
                let expr_1 := read_from_calldatat_uint8(add(var_source_offset, 96))
                /// @src 2:32118:32134  "source.safeTxGas"
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(/** @src 2:32118:32134  "source.safeTxGas" */ add(var_source_offset, 128))
                /// @src 2:32148:32162  "source.baseGas"
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_2 := calldataload(/** @src 2:32148:32162  "source.baseGas" */ add(var_source_offset, 160))
                /// @src 2:32176:32191  "source.gasPrice"
                let value_3 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_3 := calldataload(/** @src 2:32176:32191  "source.gasPrice" */ add(var_source_offset, 192))
                /// @src 2:32205:32220  "source.gasToken"
                let expr_2 := read_from_calldatat_address(add(var_source_offset, 224))
                /// @src 2:32234:32255  "source.refundReceiver"
                let expr_3 := read_from_calldatat_address(add(var_source_offset, 256))
                /// @src 2:32269:32281  "source.nonce"
                let value_4 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_4 := calldataload(/** @src 2:32269:32281  "source.nonce" */ add(var_source_offset, 288))
                /// @src 2:31976:32291  "GnosisSafeTx.Transaction(..."
                let expr_2113_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ allocate_memory_19417()
                /// @src 2:31976:32291  "GnosisSafeTx.Transaction(..."
                write_to_memory_address(expr_2113_mpos, expr)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ add(expr_2113_mpos, /** @src 2:32037:32049  "source.value" */ 32), /** @src 2:4462:4464  "22" */ value)
                mstore(/** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ add(expr_2113_mpos, /** @src 2:32063:32074  "source.data" */ 64), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ expr_2098_offset, expr_2098_length, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize()))
                /// @src 2:31976:32291  "GnosisSafeTx.Transaction(..."
                write_to_memory_uint8(add(expr_2113_mpos, /** @src 2:32088:32104  "source.operation" */ 96), /** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ expr_1)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ add(expr_2113_mpos, /** @src 2:32118:32134  "source.safeTxGas" */ 128), /** @src 2:4462:4464  "22" */ value_1)
                mstore(/** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ add(expr_2113_mpos, /** @src 2:32148:32162  "source.baseGas" */ 160), /** @src 2:4462:4464  "22" */ value_2)
                mstore(/** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ add(expr_2113_mpos, /** @src 2:32176:32191  "source.gasPrice" */ 192), /** @src 2:4462:4464  "22" */ value_3)
                /// @src 2:31976:32291  "GnosisSafeTx.Transaction(..."
                write_to_memory_address(add(expr_2113_mpos, /** @src 2:32205:32220  "source.gasToken" */ 224), /** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ expr_2)
                write_to_memory_address(add(expr_2113_mpos, /** @src 2:32234:32255  "source.refundReceiver" */ 256), /** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ expr_3)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:31976:32291  "GnosisSafeTx.Transaction(..." */ add(expr_2113_mpos, /** @src 2:32269:32281  "source.nonce" */ 288), /** @src 2:4462:4464  "22" */ value_4)
                /// @src 2:31967:32291  "target = GnosisSafeTx.Transaction(..."
                var_target_mpos := expr_2113_mpos
            }
            /// @src 1:586:668  "keccak256(..."
            function abi_encode_bytes32_uint256_address(headStart, value1, value2) -> tail
            {
                tail := add(headStart, 96)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, /** @src 1:586:668  "keccak256(..." */ 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 1:586:668  "keccak256(..." */ add(headStart, 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                mstore(/** @src 1:586:668  "keccak256(..." */ add(headStart, 64), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value2, sub(shl(160, 1), 1)))
            }
            /// @src 1:719:963  "keccak256(..."
            function abi_encode_bytes32_address_uint256_bytes32_uint8_uint256_uint256_uint256_address_address_uint256(headStart, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10) -> tail
            {
                tail := add(headStart, 352)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, /** @src 1:719:963  "keccak256(..." */ 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value1, sub(shl(160, 1), 1)))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 64), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value2)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 96), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value3)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 128), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value4, 0xff))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 160), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value5)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 192), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value6)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 224), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value7)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 256), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value8, sub(shl(160, 1), 1)))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 288), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value9, sub(shl(160, 1), 1)))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 320), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value10)
            }
            /// @src 1:719:963  "keccak256(..."
            function abi_encode_packed_stringliteral_301a_bytes32_bytes32(pos, value0, value1) -> end
            {
                mstore(pos, shl(240, 6401))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 1:719:963  "keccak256(..." */ add(pos, 2), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value0)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(pos, 34), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                /// @src 1:719:963  "keccak256(..."
                end := add(pos, 66)
            }
            /// @ast-id 135 @src 1:970:1709  "function digest(..."
            function fun_digest(var_txData_mpos, var_chainId, var_safe) -> var
            {
                /// @src 1:1143:1241  "abi.encode(..."
                let expr_91_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 1:1143:1241  "abi.encode(..."
                let _1 := add(expr_91_mpos, 0x20)
                let _2 := sub(abi_encode_bytes32_uint256_address(_1, var_chainId, var_safe), expr_91_mpos)
                mstore(expr_91_mpos, add(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 1:1143:1241  "abi.encode(..."
                finalize_allocation(expr_91_mpos, _2)
                /// @src 1:1133:1242  "keccak256(abi.encode(..."
                let expr := keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1133:1242  "keccak256(abi.encode(..." */ expr_91_mpos))
                /// @src 1:1337:1346  "txData.to"
                let _3 := /** @src 2:4462:4464  "22" */ cleanup_address_payable(mload(/** @src 1:1337:1346  "txData.to" */ var_txData_mpos))
                /// @src 2:4462:4464  "22"
                let _4 := mload(/** @src 1:1360:1372  "txData.value" */ add(var_txData_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20))
                /// @src 1:1396:1407  "txData.data"
                let _712_mpos := mload(add(var_txData_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64))
                /// @src 1:1386:1408  "keccak256(txData.data)"
                let expr_1 := keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 1:1386:1408  "keccak256(txData.data)" */ _712_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1386:1408  "keccak256(txData.data)" */ _712_mpos))
                /// @src 1:1422:1438  "txData.operation"
                let _5 := /** @src 1:719:963  "keccak256(..." */ cleanup_from_storage_uint8(mload(/** @src 1:1422:1438  "txData.operation" */ add(var_txData_mpos, 96)))
                /// @src 2:4462:4464  "22"
                let _6 := mload(/** @src 1:1452:1468  "txData.safeTxGas" */ add(var_txData_mpos, 128))
                /// @src 2:4462:4464  "22"
                let _7 := mload(/** @src 1:1482:1496  "txData.baseGas" */ add(var_txData_mpos, 160))
                /// @src 2:4462:4464  "22"
                let _8 := mload(/** @src 1:1510:1525  "txData.gasPrice" */ add(var_txData_mpos, 192))
                /// @src 1:1539:1554  "txData.gasToken"
                let _9 := /** @src 2:4462:4464  "22" */ cleanup_address_payable(mload(/** @src 1:1539:1554  "txData.gasToken" */ add(var_txData_mpos, 224)))
                /// @src 1:1568:1589  "txData.refundReceiver"
                let _10 := /** @src 2:4462:4464  "22" */ cleanup_address_payable(mload(/** @src 1:1568:1589  "txData.refundReceiver" */ add(var_txData_mpos, 256)))
                /// @src 2:4462:4464  "22"
                let _11 := mload(/** @src 1:1603:1615  "txData.nonce" */ add(var_txData_mpos, 288))
                /// @src 1:1283:1625  "abi.encode(..."
                let expr_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 1:1283:1625  "abi.encode(..."
                let _12 := add(expr_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20)
                /// @src 1:1283:1625  "abi.encode(..."
                let _13 := sub(abi_encode_bytes32_address_uint256_bytes32_uint8_uint256_uint256_uint256_address_address_uint256(_12, _3, _4, expr_1, _5, _6, _7, _8, _9, _10, _11), expr_mpos)
                mstore(expr_mpos, add(_13, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 1:1283:1625  "abi.encode(..."
                finalize_allocation(expr_mpos, _13)
                /// @src 1:1273:1626  "keccak256(abi.encode(..."
                let expr_2 := keccak256(/** @src 2:4462:4464  "22" */ _12, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1273:1626  "keccak256(abi.encode(..." */ expr_mpos))
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                let expr_131_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                let _14 := add(expr_131_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20)
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                let _15 := sub(abi_encode_packed_stringliteral_301a_bytes32_bytes32(_14, expr, expr_2), expr_131_mpos)
                mstore(expr_131_mpos, add(_15, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                finalize_allocation(expr_131_mpos, _15)
                /// @src 1:1636:1702  "return keccak256(abi.encodePacked(\"\\x19\\x01\", domain, structHash))"
                var := /** @src 1:1643:1702  "keccak256(abi.encodePacked(\"\\x19\\x01\", domain, structHash))" */ keccak256(/** @src 2:4462:4464  "22" */ _14, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1643:1702  "keccak256(abi.encodePacked(\"\\x19\\x01\", domain, structHash))" */ expr_131_mpos))
            }
            /// @ast-id 3740 @src 7:2129:2907  "function tryRecover(..."
            function fun_tryRecover_3740(var_hash, var_signature_mpos) -> var_recovered, var_err, var_errArg
            {
                /// @src 7:2299:2315  "signature.length"
                let expr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 7:2299:2315  "signature.length" */ var_signature_mpos)
                /// @src 7:2295:2901  "if (signature.length == 65) {..."
                switch /** @src 7:2299:2321  "signature.length == 65" */ eq(expr, /** @src 7:2319:2321  "65" */ 0x41)
                case /** @src 7:2295:2901  "if (signature.length == 65) {..." */ 0 {
                    /// @src 7:2807:2890  "return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length))"
                    var_recovered := /** @src 7:2823:2824  "0" */ 0x00
                    /// @src 7:2807:2890  "return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length))"
                    var_err := /** @src 7:2827:2862  "RecoverError.InvalidSignatureLength" */ 2
                    /// @src 7:2807:2890  "return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length))"
                    var_errArg := expr
                    leave
                }
                default /// @src 7:2295:2901  "if (signature.length == 65) {..."
                {
                    /// @src 7:2535:2731  "assembly (\"memory-safe\") {..."
                    let var_r := mload(add(var_signature_mpos, 0x20))
                    /// @src 7:2751:2776  "tryRecover(hash, v, r, s)"
                    let expr_3721_component, expr_3721_component_1, expr_3721_component_2 := fun_tryRecover(var_hash, /** @src 7:2535:2731  "assembly (\"memory-safe\") {..." */ byte(/** @src -1:-1:-1 */ 0, /** @src 7:2535:2731  "assembly (\"memory-safe\") {..." */ mload(add(var_signature_mpos, 0x60))), /** @src 7:2751:2776  "tryRecover(hash, v, r, s)" */ var_r, /** @src 7:2535:2731  "assembly (\"memory-safe\") {..." */ mload(add(var_signature_mpos, 0x40)))
                    /// @src 7:2744:2776  "return tryRecover(hash, v, r, s)"
                    var_recovered := expr_3721_component
                    var_err := expr_3721_component_1
                    var_errArg := expr_3721_component_2
                    leave
                }
            }
            /// @ast-id 2081 @src 2:31090:31791  "function _validateGovernanceSigners(address[] memory signers) internal view {..."
            function fun_validateGovernanceSigners(var_signers_mpos)
            {
                /// @src 2:31193:31207  "signers.length"
                let expr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:31193:31207  "signers.length" */ var_signers_mpos)
                /// @src 2:31193:31264  "signers.length == 0 ||..."
                let expr_1 := /** @src 2:31193:31212  "signers.length == 0" */ iszero(expr)
                /// @src 2:31193:31264  "signers.length == 0 ||..."
                if iszero(expr_1)
                {
                    expr_1 := /** @src 2:31228:31264  "signers.length < governanceThreshold" */ lt(expr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:31245:31264  "governanceThreshold" */ 0x09))
                }
                /// @src 2:31193:31320  "signers.length == 0 ||..."
                let expr_2 := expr_1
                if iszero(expr_1)
                {
                    expr_2 := /** @src 2:31280:31320  "signers.length > governanceOwners.length" */ gt(expr, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:31297:31313  "governanceOwners" */ 0x0a))
                }
                /// @src 2:31176:31392  "if (..."
                if expr_2
                {
                    /// @src 2:31352:31381  "InvalidGovernanceSignatures()"
                    mstore(/** @src 2:31211:31212  "0" */ 0x00, /** @src 2:30460:30489  "InvalidGovernanceSignatures()" */ shl(225, 0x7ddace71))
                    /// @src 2:31352:31381  "InvalidGovernanceSignatures()"
                    revert(/** @src 2:31211:31212  "0" */ 0x00, /** @src 2:31352:31381  "InvalidGovernanceSignatures()" */ 4)
                }
                /// @src 2:31401:31417  "address previous"
                let var_previous := /** @src 2:31211:31212  "0" */ 0x00
                /// @src 2:31401:31417  "address previous"
                var_previous := /** @src 2:31211:31212  "0" */ 0x00
                /// @src 2:31432:31441  "uint256 i"
                let var_i := /** @src 2:31211:31212  "0" */ 0x00
                /// @src 2:31432:31441  "uint256 i"
                var_i := /** @src 2:31211:31212  "0" */ 0x00
                /// @src 2:31427:31785  "for (uint256 i; i < signers.length; ++i) {..."
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 2:31432:31441  "uint256 i"
                {
                    /// @src 2:31463:31466  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:31463:31466  "++i" */ var_i, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 2:31463:31466  "++i"
                {
                    /// @src 2:31443:31461  "i < signers.length"
                    if iszero(lt(var_i, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:31447:31461  "signers.length" */ var_signers_mpos)))
                    /// @src 2:31443:31461  "i < signers.length"
                    { break }
                    /// @src 2:31499:31509  "signers[i]"
                    let _1 := read_from_memoryt_address(memory_array_index_access_uint16_dyn(var_signers_mpos, var_i))
                    /// @src 2:31544:31564  "signer == address(0)"
                    let _2 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:31544:31564  "signer == address(0)" */ _1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                    /// @src 2:31544:31613  "signer == address(0) ||..."
                    let expr_3 := /** @src 2:31544:31564  "signer == address(0)" */ iszero(_2)
                    /// @src 2:31544:31613  "signer == address(0) ||..."
                    if iszero(expr_3)
                    {
                        /// @src 2:31585:31612  "i > 0 && signer <= previous"
                        let expr_4 := /** @src 2:31585:31590  "i > 0" */ iszero(iszero(var_i))
                        /// @src 2:31585:31612  "i > 0 && signer <= previous"
                        if expr_4
                        {
                            expr_4 := /** @src 2:31594:31612  "signer <= previous" */ iszero(gt(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:31594:31612  "signer <= previous" */ var_previous, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                        }
                        /// @src 2:31544:31613  "signer == address(0) ||..."
                        expr_3 := expr_4
                    }
                    /// @src 2:31544:31660  "signer == address(0) ||..."
                    let expr_5 := expr_3
                    if iszero(expr_3)
                    {
                        expr_5 := /** @src 2:31633:31660  "!_isGovernanceOwner(signer)" */ cleanup_bool(iszero(/** @src 2:31634:31660  "_isGovernanceOwner(signer)" */ fun_isGovernanceOwner(_1)))
                    }
                    /// @src 2:31523:31744  "if (..."
                    if expr_5
                    {
                        /// @src 2:31700:31729  "InvalidGovernanceSignatures()"
                        mstore(/** @src 2:31211:31212  "0" */ 0x00, /** @src 2:30460:30489  "InvalidGovernanceSignatures()" */ shl(225, 0x7ddace71))
                        /// @src 2:31700:31729  "InvalidGovernanceSignatures()"
                        revert(/** @src 2:31211:31212  "0" */ 0x00, /** @src 2:31700:31729  "InvalidGovernanceSignatures()" */ 4)
                    }
                    /// @src 2:31757:31774  "previous = signer"
                    var_previous := _1
                }
            }
            /// @ast-id 2474 @src 2:35513:35715  "function _governanceSelector(bytes calldata data) internal pure returns (bytes4 selector) {..."
            function fun_governanceSelector(var_data_offset, var_data_2451_length) -> var_selector
            {
                /// @src 2:35613:35671  "if (data.length < 4) revert InvalidGovernanceTransaction()"
                if /** @src 2:35617:35632  "data.length < 4" */ lt(var_data_2451_length, /** @src 2:35631:35632  "4" */ 0x04)
                /// @src 2:35613:35671  "if (data.length < 4) revert InvalidGovernanceTransaction()"
                {
                    /// @src 2:35641:35671  "InvalidGovernanceTransaction()"
                    mstore(0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:35641:35671  "InvalidGovernanceTransaction()"
                    revert(0, /** @src 2:35631:35632  "4" */ 0x04)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if gt(/** @src 2:35631:35632  "4" */ 0x04, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ var_data_2451_length)
                {
                    revert(/** @src 2:35699:35707  "data[:4]" */ 0, 0)
                }
                /// @src 2:35681:35708  "selector = bytes4(data[:4])"
                var_selector := /** @src 2:4462:4464  "22" */ and(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldataload(var_data_offset), /** @src 2:4462:4464  "22" */ shl(224, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            }
            /// @ast-id 2503 @src 2:35721:35951  "function _governanceActionNonce(bytes calldata data) internal pure returns (uint256 actionNonce) {..."
            function fun_governanceActionNonce(var_data_2476_offset, var_data_length) -> var_actionNonce
            {
                /// @src 2:35828:35887  "if (data.length < 36) revert InvalidGovernanceTransaction()"
                if /** @src 2:35832:35848  "data.length < 36" */ lt(var_data_length, /** @src 2:35846:35848  "36" */ 0x24)
                /// @src 2:35828:35887  "if (data.length < 36) revert InvalidGovernanceTransaction()"
                {
                    /// @src 2:35857:35887  "InvalidGovernanceTransaction()"
                    mstore(0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:35857:35887  "InvalidGovernanceTransaction()"
                    revert(0, 4)
                }
                /// @src 2:35922:35932  "data[4:36]"
                let offsetOut := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if gt(/** @src 2:35846:35848  "36" */ 0x24, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ var_data_length)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:35911:35944  "abi.decode(data[4:36], (uint256))"
                let value0 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                offsetOut := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(add(var_data_2476_offset, /** @src 2:35927:35928  "4" */ 0x04))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value0 := value
                /// @src 2:35897:35944  "actionNonce = abi.decode(data[4:36], (uint256))"
                var_actionNonce := value
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function abi_decode_uint256t_bytes32t_array_struct_GovernanceFeeUpdate_dyn(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(headStart)
                value0 := value
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(add(headStart, 32))
                value1 := value_1
                let offset := calldataload(add(headStart, 64))
                if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                let _1 := add(headStart, offset)
                if iszero(slt(add(_1, 0x1f), dataEnd))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let length := calldataload(_1)
                let _2 := array_allocation_size_array_address_dyn(length)
                let memPtr := mload(64)
                finalize_allocation(memPtr, _2)
                let dst := memPtr
                mstore(memPtr, length)
                dst := add(memPtr, 32)
                let srcEnd := add(add(_1, mul(length, 96)), 32)
                if gt(srcEnd, dataEnd)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let src := add(_1, 32)
                for { } lt(src, srcEnd) { src := add(src, 96) }
                {
                    if slt(sub(dataEnd, src), 96)
                    {
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    let memPtr_1 := mload(64)
                    finalize_allocation_19423(memPtr_1)
                    let value_2 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    value_2 := calldataload(src)
                    mstore(memPtr_1, value_2)
                    let value_3 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    value_3 := calldataload(add(src, 32))
                    mstore(add(memPtr_1, 32), value_3)
                    let value_4 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    value_4 := calldataload(add(src, 64))
                    mstore(add(memPtr_1, 64), value_4)
                    mstore(dst, memPtr_1)
                    dst := add(dst, 32)
                }
                value2 := memPtr
            }
            function abi_encode_uint256_bytes32_array_struct_GovernanceFeeUpdate_dyn(headStart, value0, value1, value2) -> tail
            {
                let tail_1 := add(headStart, 96)
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
                mstore(add(headStart, 64), 96)
                let pos := tail_1
                let length := mload(value2)
                mstore(tail_1, length)
                pos := add(headStart, 128)
                let srcPtr := /** @src 2:4462:4464  "22" */ add(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value2, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    let _1 := mload(srcPtr)
                    mstore(pos, mload(_1))
                    mstore(add(pos, 32), mload(add(_1, 32)))
                    mstore(add(pos, 64), mload(add(_1, 64)))
                    pos := add(pos, 96)
                    srcPtr := /** @src 2:4462:4464  "22" */ add(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ srcPtr, 32)
                }
                tail := pos
            }
            /// @ast-id 2449 @src 2:33565:35507  "function _applyGovernanceFees(bytes calldata action) internal returns (bool relevant) {..."
            function fun_applyGovernanceFees(var_action_2247_offset, var_action_2247_length) -> var_relevant
            {
                /// @src 2:33636:33649  "bool relevant"
                var_relevant := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:33760:33770  "action[4:]"
                let expr_2264_offset, expr_2264_length := calldata_array_index_range_access_bytes_calldata_19424(var_action_2247_offset, var_action_2247_length, var_action_2247_length)
                /// @src 2:33749:33814  "abi.decode(action[4:], (uint256, bytes32, GovernanceFeeUpdate[]))"
                let expr_2272_component, expr_component, expr_2272_component_3_mpos := abi_decode_uint256t_bytes32t_array_struct_GovernanceFeeUpdate_dyn(expr_2264_offset, add(expr_2264_offset, expr_2264_length))
                /// @src 2:33841:33858  "keccak256(action)"
                let _797_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:33841:33858  "keccak256(action)" */ var_action_2247_offset, var_action_2247_length, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize())
                /// @src 2:33841:33858  "keccak256(action)"
                let expr := keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:33841:33858  "keccak256(action)" */ _797_mpos, /** @src 2:4462:4464  "22" */ 0x20), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:33841:33858  "keccak256(action)" */ _797_mpos))
                /// @src 2:33884:33965  "abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates)"
                let expr_2284_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:33884:33965  "abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates)"
                let _1 := add(expr_2284_mpos, /** @src 2:4462:4464  "22" */ 0x20)
                /// @src 2:33884:33965  "abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates)"
                mstore(_1, /** @src 2:4462:4464  "22" */ shl(225, 0x0ac2ae7b))
                /// @src 2:33884:33965  "abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates)"
                let _2 := sub(abi_encode_uint256_bytes32_array_struct_GovernanceFeeUpdate_dyn(add(expr_2284_mpos, 36), expr_2272_component, expr_component, expr_2272_component_3_mpos), expr_2284_mpos)
                mstore(expr_2284_mpos, add(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:33884:33965  "abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates)"
                finalize_allocation(expr_2284_mpos, _2)
                /// @src 2:33824:34014  "if (..."
                if /** @src 2:33841:33966  "keccak256(action) !=..." */ iszero(eq(expr, /** @src 2:33874:33966  "keccak256(abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates))" */ keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:33874:33966  "keccak256(abi.encodeWithSelector(CHANGE_PROTOCOL_FEES_SELECTOR, nonce, configHash, updates))" */ expr_2284_mpos))))
                /// @src 2:33824:34014  "if (..."
                {
                    /// @src 2:33984:34014  "InvalidGovernanceTransaction()"
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:33984:34014  "InvalidGovernanceTransaction()"
                    revert(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:33767:33768  "4" */ 0x04)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _3 := sload(/** @src 2:34042:34063  "activeOwnerConfigHash" */ 0x06)
                /// @src 2:34024:34159  "if (configHash != activeOwnerConfigHash) {..."
                if /** @src 2:34028:34063  "configHash != activeOwnerConfigHash" */ iszero(eq(expr_component, _3))
                /// @src 2:34024:34159  "if (configHash != activeOwnerConfigHash) {..."
                {
                    /// @src 2:34086:34148  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)"
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:34086:34148  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)" */ shl(224, 0xb3d0e4e9))
                    revert(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:34086:34148  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)" */ abi_encode_uint256_uint256_19404(expr_component, _3))
                }
                /// @src 2:34172:34186  "updates.length"
                let expr_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:34172:34186  "updates.length" */ expr_2272_component_3_mpos)
                /// @src 2:34172:34238  "updates.length == 0 || updates.length > MAX_GOVERNANCE_FEE_UPDATES"
                let expr_2 := /** @src 2:34172:34191  "updates.length == 0" */ iszero(expr_1)
                /// @src 2:34172:34238  "updates.length == 0 || updates.length > MAX_GOVERNANCE_FEE_UPDATES"
                if iszero(expr_2)
                {
                    expr_2 := /** @src 2:34195:34238  "updates.length > MAX_GOVERNANCE_FEE_UPDATES" */ gt(expr_1, /** @src 2:10158:10161  "256" */ 0x0100)
                }
                /// @src 2:34168:34302  "if (updates.length == 0 || updates.length > MAX_GOVERNANCE_FEE_UPDATES) {..."
                if expr_2
                {
                    /// @src 2:34261:34291  "InvalidGovernanceTransaction()"
                    mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:34261:34291  "InvalidGovernanceTransaction()"
                    revert(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:33767:33768  "4" */ 0x04)
                }
                /// @src 2:34316:34325  "uint256 i"
                let var_i := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:34316:34325  "uint256 i"
                var_i := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:34311:35048  "for (uint256 i; i < updates.length; ++i) {..."
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 2:34316:34325  "uint256 i"
                {
                    /// @src 2:34347:34350  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:34347:34350  "++i" */ var_i, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 2:34347:34350  "++i"
                {
                    /// @src 2:34327:34345  "i < updates.length"
                    if iszero(lt(var_i, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:34331:34345  "updates.length" */ expr_2272_component_3_mpos)))
                    /// @src 2:34327:34345  "i < updates.length"
                    { break }
                    /// @src 2:34402:34412  "updates[i]"
                    let _823_mpos := mload(memory_array_index_access_uint16_dyn(expr_2272_component_3_mpos, var_i))
                    /// @src 2:34430:34481  "update.targetChainId == 0 || update.protocolId <= 1"
                    let expr_3 := /** @src 2:34430:34455  "update.targetChainId == 0" */ iszero(/** @src 2:4462:4464  "22" */ mload(/** @src 2:34430:34450  "update.targetChainId" */ _823_mpos))
                    /// @src 2:34430:34481  "update.targetChainId == 0 || update.protocolId <= 1"
                    if iszero(expr_3)
                    {
                        expr_3 := /** @src 2:34459:34481  "update.protocolId <= 1" */ iszero(gt(/** @src 2:4462:4464  "22" */ mload(/** @src 2:34459:34476  "update.protocolId" */ add(_823_mpos, /** @src 2:4462:4464  "22" */ 0x20)), /** @src 2:2993:2996  "300" */ 1))
                    }
                    /// @src 2:34426:34553  "if (update.targetChainId == 0 || update.protocolId <= 1) {..."
                    if expr_3
                    {
                        /// @src 2:34508:34538  "InvalidGovernanceTransaction()"
                        mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                        /// @src 2:34508:34538  "InvalidGovernanceTransaction()"
                        revert(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:33767:33768  "4" */ 0x04)
                    }
                    /// @src 2:34566:34966  "if (i > 0) {..."
                    if /** @src 2:34570:34575  "i > 0" */ iszero(iszero(var_i))
                    /// @src 2:34566:34966  "if (i > 0) {..."
                    {
                        /// @src 2:34633:34647  "updates[i - 1]"
                        let _mpos := mload(memory_array_index_access_uint16_dyn(expr_2272_component_3_mpos, /** @src 2:34641:34646  "i - 1" */ checked_sub_uint256_19426(var_i)))
                        /// @src 2:4462:4464  "22"
                        let _4 := mload(/** @src 2:34690:34710  "update.targetChainId" */ _823_mpos)
                        /// @src 2:4462:4464  "22"
                        let _5 := mload(/** @src 2:34713:34735  "previous.targetChainId" */ _mpos)
                        /// @src 2:34690:34855  "update.targetChainId < previous.targetChainId..."
                        let expr_4 := /** @src 2:34690:34735  "update.targetChainId < previous.targetChainId" */ lt(_4, _5)
                        /// @src 2:34690:34855  "update.targetChainId < previous.targetChainId..."
                        if iszero(expr_4)
                        {
                            /// @src 2:34764:34854  "update.targetChainId == previous.targetChainId && update.protocolId <= previous.protocolId"
                            let expr_5 := /** @src 2:34764:34810  "update.targetChainId == previous.targetChainId" */ eq(_4, _5)
                            /// @src 2:34764:34854  "update.targetChainId == previous.targetChainId && update.protocolId <= previous.protocolId"
                            if expr_5
                            {
                                /// @src 2:4462:4464  "22"
                                let _6 := mload(/** @src 2:34814:34831  "update.protocolId" */ add(_823_mpos, /** @src 2:4462:4464  "22" */ 0x20))
                                /// @src 2:34764:34854  "update.targetChainId == previous.targetChainId && update.protocolId <= previous.protocolId"
                                expr_5 := /** @src 2:34814:34854  "update.protocolId <= previous.protocolId" */ iszero(gt(_6, /** @src 2:4462:4464  "22" */ mload(/** @src 2:34835:34854  "previous.protocolId" */ add(_mpos, /** @src 2:4462:4464  "22" */ 0x20))))
                            }
                            /// @src 2:34690:34855  "update.targetChainId < previous.targetChainId..."
                            expr_4 := expr_5
                        }
                        /// @src 2:34665:34952  "if (..."
                        if expr_4
                        {
                            /// @src 2:34903:34933  "InvalidGovernanceTransaction()"
                            mstore(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                            /// @src 2:34903:34933  "InvalidGovernanceTransaction()"
                            revert(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:33767:33768  "4" */ 0x04)
                        }
                    }
                    /// @src 2:34979:35037  "if (update.targetChainId == block.chainid) relevant = true"
                    if /** @src 2:34983:35020  "update.targetChainId == block.chainid" */ eq(/** @src 2:4462:4464  "22" */ mload(/** @src 2:34983:35003  "update.targetChainId" */ _823_mpos), /** @src 2:35007:35020  "block.chainid" */ chainid())
                    /// @src 2:34979:35037  "if (update.targetChainId == block.chainid) relevant = true"
                    {
                        /// @src 2:35022:35037  "relevant = true"
                        var_relevant := /** @src 2:2993:2996  "300" */ 1
                    }
                }
                /// @src 2:35057:35084  "if (!relevant) return false"
                if /** @src 2:35061:35070  "!relevant" */ iszero(var_relevant)
                /// @src 2:35057:35084  "if (!relevant) return false"
                {
                    /// @src 2:35072:35084  "return false"
                    var_relevant := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:35072:35084  "return false"
                    leave
                }
                /// @src 2:35099:35108  "uint256 i"
                let var_i_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:35099:35108  "uint256 i"
                var_i_1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:35094:35501  "for (uint256 i; i < updates.length; ++i) {..."
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 2:35099:35108  "uint256 i"
                {
                    /// @src 2:35130:35133  "++i"
                    var_i_1 := /** @src 2:2993:2996  "300" */ add(/** @src 2:35130:35133  "++i" */ var_i_1, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 2:35130:35133  "++i"
                {
                    /// @src 2:35110:35128  "i < updates.length"
                    if iszero(lt(var_i_1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:35114:35128  "updates.length" */ expr_2272_component_3_mpos)))
                    /// @src 2:35110:35128  "i < updates.length"
                    { break }
                    /// @src 2:35149:35204  "if (updates[i].targetChainId != block.chainid) continue"
                    if /** @src 2:35153:35194  "updates[i].targetChainId != block.chainid" */ iszero(eq(/** @src 2:4462:4464  "22" */ mload(/** @src 2:35153:35163  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2272_component_3_mpos, var_i_1))), /** @src 2:35007:35020  "block.chainid" */ chainid()))
                    /// @src 2:35149:35204  "if (updates[i].targetChainId != block.chainid) continue"
                    {
                        /// @src 2:35196:35204  "continue"
                        continue
                    }
                    /// @src 2:4462:4464  "22"
                    sstore(/** @src 2:35218:35257  "protocolFeeInWei[updates[i].protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_19220(/** @src 2:4462:4464  "22" */ mload(/** @src 2:35235:35256  "updates[i].protocolId" */ add(/** @src 2:35235:35245  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2272_component_3_mpos, var_i_1)), /** @src 2:4462:4464  "22" */ 0x20))), mload(/** @src 2:35260:35279  "updates[i].feeInWei" */ add(/** @src 2:35260:35270  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2272_component_3_mpos, var_i_1)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)))
                    /// @src 2:4462:4464  "22"
                    let _7 := mload(/** @src 2:35367:35388  "updates[i].protocolId" */ add(/** @src 2:35367:35377  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2272_component_3_mpos, var_i_1)), /** @src 2:4462:4464  "22" */ 0x20))
                    let _8 := mload(/** @src 2:35406:35425  "updates[i].feeInWei" */ add(/** @src 2:35406:35416  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2272_component_3_mpos, var_i_1)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64))
                    /// @src 2:35298:35490  "GovernanceFeeUpdated(..."
                    let _9 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:35298:35490  "GovernanceFeeUpdated(..."
                    log4(_9, sub(abi_encode_uint256_uint256(_9, _8, expr_2272_component), _9), 0xaf29a23d2bc893d04257fcb829a71cbf3ba313601249fa9581733a5aff968174, /** @src 2:35007:35020  "block.chainid" */ chainid(), /** @src 2:35298:35490  "GovernanceFeeUpdated(..." */ _7, expr_component)
                }
            }
            /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
            function abi_decode_uint256t_bytes32t_uint256t_array_address_dyn(headStart, dataEnd) -> value0, value1, value2, value3
            {
                if slt(sub(dataEnd, headStart), 128) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(headStart)
                value0 := value
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(add(headStart, 32))
                value1 := value_1
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                value_2 := calldataload(add(headStart, 64))
                value2 := value_2
                let offset := calldataload(add(headStart, 96))
                if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                value3 := abi_decode_array_address_dyn(add(headStart, offset), dataEnd)
            }
            function abi_encode_uint256_bytes32_uint256_array_address_dyn(headStart, value0, value1, value2, value3) -> tail
            {
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
                mstore(add(headStart, 64), value2)
                mstore(add(headStart, 96), 128)
                tail := abi_encode_array_address_dyn(value3, add(headStart, 128))
            }
            /// @src 2:10095:10098  "256"
            function storage_set_to_zero_array_address_dyn()
            {
                let offset := /** @src 2:33215:33238  "delete governanceOwners" */ 0
                /// @src 2:10095:10098  "256"
                offset := /** @src 2:33215:33238  "delete governanceOwners" */ 0
                /// @src 2:10095:10098  "256"
                let oldLen := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:33215:33238  "delete governanceOwners" */ 0x0a)
                /// @src 2:10095:10098  "256"
                sstore(/** @src 2:33215:33238  "delete governanceOwners" */ 0x0a, /** @src -1:-1:-1 */ 0)
                /// @src 2:10095:10098  "256"
                if iszero(iszero(oldLen))
                {
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:33215:33238  "delete governanceOwners" */ 0x0a)
                    /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                    let data := keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
                    /// @src 2:10095:10098  "256"
                    let _1 := add(data, oldLen)
                    let start := data
                    for { } lt(start, _1) { start := add(start, 1) }
                    {
                        sstore(start, /** @src -1:-1:-1 */ 0)
                    }
                }
            }
            /// @src 2:10095:10098  "256"
            function array_push_from_address_to_array_address_dyn_storage_ptr(value0)
            {
                let oldLen := sload(/** @src 2:33215:33238  "delete governanceOwners" */ 0x0a)
                /// @src 2:10095:10098  "256"
                if iszero(lt(oldLen, 18446744073709551616)) { panic_error_0x41() }
                sstore(/** @src 2:33215:33238  "delete governanceOwners" */ 0x0a, /** @src 2:10095:10098  "256" */ add(oldLen, 1))
                let slot := /** @src -1:-1:-1 */ 0
                /// @src 2:10095:10098  "256"
                let offset := /** @src -1:-1:-1 */ 0
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(lt(oldLen, sload(/** @src 2:33215:33238  "delete governanceOwners" */ 0x0a)))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:33215:33238  "delete governanceOwners" */ 0x0a)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20), oldLen)
                offset := /** @src -1:-1:-1 */ 0
                /// @src 2:10095:10098  "256"
                sstore(slot, or(and(sload(slot), shl(160, /** @src 2:4462:4464  "22" */ 0xffffffffffffffffffffffff)), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:10095:10098  "256" */ value0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
            }
            /// @src 2:10095:10098  "256"
            function abi_encode_uint256_uint256_array_address_dyn(headStart, value0, value1, value2) -> tail
            {
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, value0)
                mstore(/** @src 2:10095:10098  "256" */ add(headStart, 32), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                /// @src 2:10095:10098  "256"
                mstore(add(headStart, 64), 96)
                tail := abi_encode_array_address_dyn(value2, add(headStart, 96))
            }
            /// @ast-id 2245 @src 2:32346:33559  "function _applyGovernanceOwners(bytes calldata action) internal {..."
            function fun_applyGovernanceOwners(var_action_2119_offset, var_action_2119_length)
            {
                /// @src 2:32526:32536  "action[4:]"
                let expr_2135_offset, expr_length := calldata_array_index_range_access_bytes_calldata_19424(var_action_2119_offset, var_action_2119_length, var_action_2119_length)
                /// @src 2:32515:32577  "abi.decode(action[4:], (uint256, bytes32, uint256, address[]))"
                let expr_component, expr_2146_component, expr_2146_component_1, expr_component_mpos := abi_decode_uint256t_bytes32t_uint256t_array_address_dyn(expr_2135_offset, add(expr_2135_offset, expr_length))
                /// @src 2:32604:32621  "keccak256(action)"
                let _905_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:32604:32621  "keccak256(action)" */ var_action_2119_offset, var_action_2119_length, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize())
                /// @src 2:32604:32621  "keccak256(action)"
                let expr := keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:32604:32621  "keccak256(action)" */ _905_mpos, /** @src 2:4462:4464  "22" */ 0x20), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:32604:32621  "keccak256(action)" */ _905_mpos))
                /// @src 2:32647:32732  "abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners)"
                let expr_2159_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:32647:32732  "abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners)"
                let _1 := add(expr_2159_mpos, /** @src 2:4462:4464  "22" */ 0x20)
                /// @src 2:32647:32732  "abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners)"
                mstore(_1, /** @src 2:4462:4464  "22" */ shl(226, 0x23d0fe25))
                /// @src 2:32647:32732  "abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners)"
                let _2 := sub(abi_encode_uint256_bytes32_uint256_array_address_dyn(add(expr_2159_mpos, 36), expr_component, expr_2146_component, expr_2146_component_1, expr_component_mpos), expr_2159_mpos)
                mstore(expr_2159_mpos, add(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:32647:32732  "abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners)"
                finalize_allocation(expr_2159_mpos, _2)
                /// @src 2:32587:32781  "if (..."
                if /** @src 2:32604:32733  "keccak256(action) !=..." */ iszero(eq(expr, /** @src 2:32637:32733  "keccak256(abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners))" */ keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:32637:32733  "keccak256(abi.encodeWithSelector(CHANGE_OWNERS_SELECTOR, nonce, currentHash, threshold, owners))" */ expr_2159_mpos))))
                /// @src 2:32587:32781  "if (..."
                {
                    /// @src 2:32751:32781  "InvalidGovernanceTransaction()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:27811:27841  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:32751:32781  "InvalidGovernanceTransaction()"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:32533:32534  "4" */ 0x04)
                }
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                let _3 := sload(/** @src 2:32810:32831  "activeOwnerConfigHash" */ 0x06)
                /// @src 2:32791:32928  "if (currentHash != activeOwnerConfigHash) {..."
                if /** @src 2:32795:32831  "currentHash != activeOwnerConfigHash" */ iszero(eq(expr_2146_component, _3))
                /// @src 2:32791:32928  "if (currentHash != activeOwnerConfigHash) {..."
                {
                    /// @src 2:32854:32917  "GovernanceOwnerHashMismatch(currentHash, activeOwnerConfigHash)"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:34086:34148  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)" */ shl(224, 0xb3d0e4e9))
                    /// @src 2:32854:32917  "GovernanceOwnerHashMismatch(currentHash, activeOwnerConfigHash)"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:32854:32917  "GovernanceOwnerHashMismatch(currentHash, activeOwnerConfigHash)" */ abi_encode_uint256_uint256_19404(expr_2146_component, _3))
                }
                /// @src 2:32937:33024  "if (owners.length > MAX_GOVERNANCE_OWNERS) revert InvalidGovernanceOwnerConfiguration()"
                if /** @src 2:32941:32978  "owners.length > MAX_GOVERNANCE_OWNERS" */ gt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:32941:32954  "owners.length" */ expr_component_mpos), /** @src 2:10158:10161  "256" */ 0x0100)
                /// @src 2:32937:33024  "if (owners.length > MAX_GOVERNANCE_OWNERS) revert InvalidGovernanceOwnerConfiguration()"
                {
                    /// @src 2:32987:33024  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:32987:33024  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:32533:32534  "4" */ 0x04)
                }
                /// @src 2:33068:33077  "threshold"
                fun_validateGovernanceOwners(expr_component_mpos, expr_2146_component_1)
                /// @src 2:33153:33205  "_governanceOwnerConfigHash(nonce, threshold, owners)"
                let expr_1 := fun_governanceOwnerConfigHash(expr_component, expr_2146_component_1, expr_component_mpos)
                /// @src 2:33215:33238  "delete governanceOwners"
                storage_set_to_zero_array_address_dyn()
                /// @src 2:33253:33262  "uint256 i"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:33253:33262  "uint256 i"
                var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:33248:33345  "for (uint256 i; i < owners.length; ++i) {..."
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 2:33253:33262  "uint256 i"
                {
                    /// @src 2:33283:33286  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:33283:33286  "++i" */ var_i, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 2:33283:33286  "++i"
                {
                    /// @src 2:33264:33281  "i < owners.length"
                    if iszero(lt(var_i, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:33268:33281  "owners.length" */ expr_component_mpos)))
                    /// @src 2:33264:33281  "i < owners.length"
                    { break }
                    /// @src 2:33302:33334  "governanceOwners.push(owners[i])"
                    array_push_from_address_to_array_address_dyn_storage_ptr(/** @src 2:33324:33333  "owners[i]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(expr_component_mpos, var_i)))
                }
                /// @src 2:33354:33385  "governanceThreshold = threshold"
                update_storage_value_offsett_bytes32_to_bytes32_19432(expr_2146_component_1)
                /// @src 2:33395:33429  "activeOwnerConfigSafeNonce = nonce"
                update_storage_value_offsett_bytes32_to_bytes32_19433(expr_component)
                /// @src 2:33439:33467  "activeOwnerConfigHash = next"
                update_storage_value_offsett_bytes32_to_bytes32(expr_1)
                /// @src 2:33482:33552  "GovernanceOwnerConfigUpdated(previous, next, nonce, threshold, owners)"
                let _4 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:33482:33552  "GovernanceOwnerConfigUpdated(previous, next, nonce, threshold, owners)"
                log3(_4, sub(abi_encode_uint256_uint256_array_address_dyn(_4, expr_component, expr_2146_component_1, expr_component_mpos), _4), 0x0d98428e81be81c8c2e5fb18bb96e02d0dad8ff7c3a7cf42a1d4dec9f2073dc0, _3, expr_1)
            }
            /// @ast-id 3928 @src 7:5203:6754  "function tryRecover(..."
            function fun_tryRecover(var_hash, var_v, var_r, var_s) -> var_recovered, var_err, var_errArg
            {
                /// @src 7:6266:6430  "if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {..."
                if /** @src 7:6270:6349  "uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0" */ gt(var_s, /** @src 7:6283:6349  "0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0" */ 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0)
                /// @src 7:6266:6430  "if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {..."
                {
                    /// @src 7:6365:6419  "return (address(0), RecoverError.InvalidSignatureS, s)"
                    var_recovered := /** @src 7:6381:6382  "0" */ 0x00
                    /// @src 7:6365:6419  "return (address(0), RecoverError.InvalidSignatureS, s)"
                    var_err := /** @src 7:6385:6415  "RecoverError.InvalidSignatureS" */ 3
                    /// @src 7:6365:6419  "return (address(0), RecoverError.InvalidSignatureS, s)"
                    var_errArg := var_s
                    leave
                }
                /// @src 7:6541:6565  "ecrecover(hash, v, r, s)"
                let _1 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                mstore(_1, var_hash)
                mstore(add(_1, 32), and(var_v, 0xff))
                mstore(add(_1, 64), var_r)
                mstore(add(_1, 96), var_s)
                /// @src 7:6541:6565  "ecrecover(hash, v, r, s)"
                mstore(/** @src -1:-1:-1 */ 0, 0)
                /// @src 7:6541:6565  "ecrecover(hash, v, r, s)"
                if iszero(staticcall(gas(), 1, _1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 128, /** @src -1:-1:-1 */ 0, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                /// @src 7:6541:6565  "ecrecover(hash, v, r, s)"
                { revert_forward() }
                let _2 := mload(/** @src -1:-1:-1 */ 0)
                /// @src 7:6575:6688  "if (signer == address(0)) {..."
                if /** @src 7:6579:6599  "signer == address(0)" */ iszero(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 7:6579:6599  "signer == address(0)" */ _2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                /// @src 7:6575:6688  "if (signer == address(0)) {..."
                {
                    /// @src 7:6615:6677  "return (address(0), RecoverError.InvalidSignature, bytes32(0))"
                    var_recovered := /** @src -1:-1:-1 */ 0
                    /// @src 7:6615:6677  "return (address(0), RecoverError.InvalidSignature, bytes32(0))"
                    var_err := /** @src 7:6541:6565  "ecrecover(hash, v, r, s)" */ 1
                    /// @src 7:6615:6677  "return (address(0), RecoverError.InvalidSignature, bytes32(0))"
                    var_errArg := /** @src -1:-1:-1 */ 0
                    /// @src 7:6615:6677  "return (address(0), RecoverError.InvalidSignature, bytes32(0))"
                    leave
                }
                /// @src 7:6698:6747  "return (signer, RecoverError.NoError, bytes32(0))"
                var_recovered := _2
                var_err := /** @src -1:-1:-1 */ 0
                /// @src 7:6698:6747  "return (signer, RecoverError.NoError, bytes32(0))"
                var_errArg := /** @src -1:-1:-1 */ 0
            }
            /// @ast-id 2570 @src 2:35957:36504  "function _isGovernanceOwner(address account) internal view returns (bool) {..."
            function fun_isGovernanceOwner(var_account) -> var_
            {
                /// @src 2:36041:36052  "uint256 low"
                let var_low := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:36041:36052  "uint256 low"
                var_low := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:36062:36100  "uint256 high = governanceOwners.length"
                let var_high := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:36077:36093  "governanceOwners" */ 0x0a)
                /// @src 2:36062:36100  "uint256 high = governanceOwners.length"
                let var_high_1 := var_high
                /// @src 2:36110:36384  "while (low < high) {..."
                for { }
                /** @src 2:36117:36127  "low < high" */ lt(var_low, var_high)
                /// @src 2:36110:36384  "while (low < high) {..."
                { }
                {
                    /// @src 2:2993:2996  "300"
                    let sum := add(var_low, var_high)
                    if gt(var_low, sum) { panic_error_0x11() }
                    /// @src 2:36160:36176  "(low + high) / 2"
                    let expr := checked_div_uint256_19435(/** @src 2:36161:36171  "low + high" */ sum)
                    /// @src 2:36210:36234  "governanceOwners[middle]"
                    let _1, _2 := storage_array_index_access_address_dyn(expr)
                    let _3 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_dynamict_address_payable(sload(/** @src 2:36210:36234  "governanceOwners[middle]" */ _1), _2)
                    /// @src 2:36248:36374  "if (candidate < account) {..."
                    switch /** @src 2:36252:36271  "candidate < account" */ lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:36252:36271  "candidate < account" */ _3, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)), and(/** @src 2:36252:36271  "candidate < account" */ var_account, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    case /** @src 2:36248:36374  "if (candidate < account) {..." */ 0 {
                        /// @src 2:36346:36359  "high = middle"
                        var_high := expr
                    }
                    default /// @src 2:36248:36374  "if (candidate < account) {..."
                    {
                        /// @src 2:36291:36307  "low = middle + 1"
                        var_low := /** @src 2:36297:36307  "middle + 1" */ checked_add_uint256_19170(expr)
                    }
                }
                /// @src 2:36397:36462  "low < governanceOwners.length && governanceOwners[low] == account"
                let expr_1 := /** @src 2:36397:36426  "low < governanceOwners.length" */ lt(var_low, var_high_1)
                /// @src 2:36397:36462  "low < governanceOwners.length && governanceOwners[low] == account"
                if expr_1
                {
                    /// @src 2:36430:36451  "governanceOwners[low]"
                    let _4, _5 := storage_array_index_access_address_dyn(var_low)
                    let _6 := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_dynamict_address_payable(sload(/** @src 2:36430:36451  "governanceOwners[low]" */ _4), _5)
                    /// @src 2:36397:36462  "low < governanceOwners.length && governanceOwners[low] == account"
                    expr_1 := /** @src 2:36430:36462  "governanceOwners[low] == account" */ eq(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:36430:36462  "governanceOwners[low] == account" */ _6, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)), and(/** @src 2:36430:36462  "governanceOwners[low] == account" */ var_account, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                }
                /// @src 2:36393:36475  "if (low < governanceOwners.length && governanceOwners[low] == account) return true"
                if expr_1
                {
                    /// @src 2:36464:36475  "return true"
                    var_ := /** @src 2:36471:36475  "true" */ 0x01
                    /// @src 2:36464:36475  "return true"
                    leave
                }
                /// @src 2:36485:36497  "return false"
                var_ := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
            }
            /// @ast-id 2637 @src 2:36510:36979  "function _validateGovernanceOwners(address[] memory owners, uint256 threshold) internal pure {..."
            function fun_validateGovernanceOwners(var_owners_mpos, var_threshold)
            {
                /// @src 2:36617:36630  "owners.length"
                let expr := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:36617:36630  "owners.length" */ var_owners_mpos)
                /// @src 2:36617:36653  "owners.length == 0 || threshold == 0"
                let expr_1 := /** @src 2:36617:36635  "owners.length == 0" */ iszero(expr)
                /// @src 2:36617:36653  "owners.length == 0 || threshold == 0"
                if iszero(expr_1)
                {
                    expr_1 := /** @src 2:36639:36653  "threshold == 0" */ iszero(var_threshold)
                }
                /// @src 2:36617:36682  "owners.length == 0 || threshold == 0 || threshold > owners.length"
                let expr_2 := expr_1
                if iszero(expr_1)
                {
                    expr_2 := /** @src 2:36657:36682  "threshold > owners.length" */ gt(var_threshold, expr)
                }
                /// @src 2:36613:36753  "if (owners.length == 0 || threshold == 0 || threshold > owners.length) {..."
                if expr_2
                {
                    /// @src 2:36705:36742  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src 2:36634:36635  "0" */ 0x00, /** @src 2:32987:33024  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    /// @src 2:36705:36742  "InvalidGovernanceOwnerConfiguration()"
                    revert(/** @src 2:36634:36635  "0" */ 0x00, /** @src 2:36705:36742  "InvalidGovernanceOwnerConfiguration()" */ 4)
                }
                /// @src 2:36767:36776  "uint256 i"
                let var_i := /** @src 2:36634:36635  "0" */ 0x00
                /// @src 2:36767:36776  "uint256 i"
                var_i := /** @src 2:36634:36635  "0" */ 0x00
                /// @src 2:36762:36973  "for (uint256 i; i < owners.length; ++i) {..."
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 2:36767:36776  "uint256 i"
                {
                    /// @src 2:36797:36800  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:36797:36800  "++i" */ var_i, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 2:36797:36800  "++i"
                {
                    /// @src 2:36778:36795  "i < owners.length"
                    if iszero(lt(var_i, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:36782:36795  "owners.length" */ var_owners_mpos)))
                    /// @src 2:36778:36795  "i < owners.length"
                    { break }
                    /// @src 2:36820:36884  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    let expr_3 := /** @src 2:36820:36843  "owners[i] == address(0)" */ iszero(cleanup_address_payable(/** @src 2:36820:36829  "owners[i]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(var_owners_mpos, var_i))))
                    /// @src 2:36820:36884  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    if iszero(expr_3)
                    {
                        /// @src 2:36848:36883  "i > 0 && owners[i - 1] >= owners[i]"
                        let expr_4 := /** @src 2:36848:36853  "i > 0" */ iszero(iszero(var_i))
                        /// @src 2:36848:36883  "i > 0 && owners[i - 1] >= owners[i]"
                        if expr_4
                        {
                            /// @src 2:36857:36870  "owners[i - 1]"
                            let _1 := read_from_memoryt_address(memory_array_index_access_uint16_dyn(var_owners_mpos, /** @src 2:36864:36869  "i - 1" */ checked_sub_uint256_19426(var_i)))
                            /// @src 2:36848:36883  "i > 0 && owners[i - 1] >= owners[i]"
                            expr_4 := /** @src 2:36857:36883  "owners[i - 1] >= owners[i]" */ iszero(lt(/** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:36857:36883  "owners[i - 1] >= owners[i]" */ _1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)), /** @src 2:36857:36883  "owners[i - 1] >= owners[i]" */ cleanup_address_payable(/** @src 2:36874:36883  "owners[i]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(var_owners_mpos, var_i)))))
                        }
                        /// @src 2:36820:36884  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                        expr_3 := expr_4
                    }
                    /// @src 2:36816:36963  "if (owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])) {..."
                    if expr_3
                    {
                        /// @src 2:36911:36948  "InvalidGovernanceOwnerConfiguration()"
                        mstore(/** @src 2:36634:36635  "0" */ 0x00, /** @src 2:32987:33024  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                        /// @src 2:36911:36948  "InvalidGovernanceOwnerConfiguration()"
                        revert(/** @src 2:36634:36635  "0" */ 0x00, /** @src 2:36911:36948  "InvalidGovernanceOwnerConfiguration()" */ 4)
                    }
                }
            }
            /// @ast-id 2659 @src 2:36985:37352  "function _governanceOwnerConfigHash(..."
            function fun_governanceOwnerConfigHash(var_ownerConfigSafeNonce, var_threshold, var_owners_2644_mpos) -> var
            {
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                let expr_mpos := /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                let _1 := add(expr_mpos, 0x20)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(_1, /** @src 0:224:379  "keccak256(..." */ 0xe0928e00f77af6dd5036aaeb1b692b0989112348ea8aba90009b7e6d3260f0fe)
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:37217:37230  "sourceChainId" */ loadimmutable("471"))
                /// @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 0:224:379  "keccak256(..." */ 96), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:37244:37258  "governanceSafe" */ loadimmutable("474"), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 0:224:379  "keccak256(..." */ 128), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ var_ownerConfigSafeNonce)
                mstore(/** @src 0:224:379  "keccak256(..." */ add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 0:224:379  "keccak256(..." */ 160), /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ var_threshold)
                /// @src 0:224:379  "keccak256(..."
                mstore(add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 0:224:379  "keccak256(..." */ 192), 192)
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                let _2 := sub(/** @src 0:224:379  "keccak256(..." */ abi_encode_array_address_dyn(var_owners_2644_mpos, add(/** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos, /** @src 0:224:379  "keccak256(..." */ 224)), /** @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)" */ expr_mpos)
                mstore(expr_mpos, add(_2, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 0:616:700  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners)"
                finalize_allocation(expr_mpos, _2)
                /// @src 2:37167:37345  "return GSSGovernance.ownerConfigHash(..."
                var := /** @src 0:606:701  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners))" */ keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:97338  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 0:606:701  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, safeNonce, threshold, owners))" */ expr_mpos))
            }
        }
        data ".metadata" hex"a26469706673582212208085ceab9ddb2d9f07701070a22cfef4af8fd94d38b8f2f1eb89023c77bc48eb64736f6c634300081b0033"
    }
}
