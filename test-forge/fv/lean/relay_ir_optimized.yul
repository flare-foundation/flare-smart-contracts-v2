/// @use-src 0:"contracts/governance/GSSGovernance.sol", 2:"contracts/protocol/implementation/Relay.sol", 3:"contracts/protocol/interface/IIRelay.sol", 4:"contracts/userInterfaces/IRelay.sol", 5:"contracts/userInterfaces/IRelayGovernance.sol", 6:"contracts/userInterfaces/LTS/RandomNumberV2Interface.sol"
object "Relay_3019" {
    code {
        {
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            mstore(64, memoryguard(0x0120))
            if callvalue() { revert(0, 0) }
            let programSize := datasize("Relay_3019")
            let argSize := sub(codesize(), programSize)
            finalize_allocation(memoryguard(0x0120), argSize)
            codecopy(memoryguard(0x0120), programSize, argSize)
            if slt(sub(add(memoryguard(0x0120), argSize), memoryguard(0x0120)), 96)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let offset := mload(memoryguard(0x0120))
            if gt(offset, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            if slt(sub(add(memoryguard(0x0120), argSize), add(memoryguard(0x0120), offset)), 0x0220)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let memPtr := mload(64)
            let newFreePtr := add(memPtr, 0x0220)
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
            }
            mstore(64, newFreePtr)
            mstore(memPtr, abi_decode_uint32_fromMemory(add(memoryguard(0x0120), offset)))
            let _1 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0120), offset), 32))
            mstore(add(memPtr, 32), _1)
            let value := mload(add(add(memoryguard(0x0120), offset), 64))
            mstore(add(memPtr, 64), value)
            let _2 := abi_decode_uint8_fromMemory(add(add(memoryguard(0x0120), offset), 96))
            mstore(add(memPtr, 96), _2)
            let _3 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0120), offset), 128))
            mstore(add(memPtr, 128), _3)
            let _4 := abi_decode_uint8_fromMemory(add(add(memoryguard(0x0120), offset), 160))
            mstore(add(memPtr, 160), _4)
            let _5 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0120), offset), 192))
            mstore(add(memPtr, 192), _5)
            let _6 := abi_decode_uint16_fromMemory(add(add(memoryguard(0x0120), offset), 224))
            mstore(add(memPtr, 224), _6)
            let _7 := abi_decode_uint16_fromMemory(add(add(memoryguard(0x0120), offset), 256))
            mstore(add(memPtr, 256), _7)
            let _8 := abi_decode_uint32_fromMemory(add(add(memoryguard(0x0120), offset), 288))
            mstore(add(memPtr, 288), _8)
            let value_1 := mload(add(add(memoryguard(0x0120), offset), 320))
            if iszero(eq(value_1, and(value_1, sub(shl(160, 1), 1))))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            mstore(add(memPtr, 320), value_1)
            let offset_1 := mload(add(add(memoryguard(0x0120), offset), 352))
            if gt(offset_1, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            if iszero(slt(add(add(add(memoryguard(0x0120), offset), offset_1), 31), add(memoryguard(0x0120), argSize)))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let length := mload(add(add(memoryguard(0x0120), offset), offset_1))
            let _9 := array_allocation_size_array_struct_FeeConfig_dyn(length)
            let memPtr_1 := mload(64)
            finalize_allocation(memPtr_1, _9)
            let dst := memPtr_1
            mstore(memPtr_1, length)
            dst := add(memPtr_1, 32)
            if gt(add(add(add(add(memoryguard(0x0120), offset), offset_1), shl(6, length)), 32), add(memoryguard(0x0120), argSize))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let src := add(add(add(memoryguard(0x0120), offset), offset_1), 32)
            for { }
            lt(src, add(add(add(add(memoryguard(0x0120), offset), offset_1), shl(6, length)), 32))
            { src := add(src, 64) }
            {
                if slt(sub(add(memoryguard(0x0120), argSize), src), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPtr_2 := mload(64)
                let newFreePtr_1 := add(memPtr_2, 64)
                if or(gt(newFreePtr_1, sub(shl(64, 1), 1)), lt(newFreePtr_1, memPtr_2))
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
                }
                mstore(64, newFreePtr_1)
                mstore(memPtr_2, abi_decode_uint8_fromMemory(src))
                mstore(add(memPtr_2, 32), mload(add(src, 32)))
                mstore(dst, memPtr_2)
                dst := add(dst, 32)
            }
            mstore(add(memPtr, 352), memPtr_1)
            let value_2 := mload(add(add(memoryguard(0x0120), offset), 384))
            mstore(add(memPtr, 384), value_2)
            let _10 := abi_decode_address_fromMemory(add(add(memoryguard(0x0120), offset), 416))
            mstore(add(memPtr, 416), _10)
            let value_3 := mload(add(add(memoryguard(0x0120), offset), 448))
            mstore(add(memPtr, 448), value_3)
            let offset_2 := mload(add(add(memoryguard(0x0120), offset), 480))
            if gt(offset_2, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            if iszero(slt(add(add(add(memoryguard(0x0120), offset), offset_2), 31), add(memoryguard(0x0120), argSize)))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let length_1 := mload(add(add(memoryguard(0x0120), offset), offset_2))
            let _11 := array_allocation_size_array_struct_FeeConfig_dyn(length_1)
            let memPtr_3 := mload(64)
            finalize_allocation(memPtr_3, _11)
            let dst_1 := memPtr_3
            mstore(memPtr_3, length_1)
            dst_1 := add(memPtr_3, 32)
            if gt(add(add(add(add(memoryguard(0x0120), offset), offset_2), shl(5, length_1)), 32), add(memoryguard(0x0120), argSize))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let src_1 := add(add(add(memoryguard(0x0120), offset), offset_2), 32)
            for { }
            lt(src_1, add(add(add(add(memoryguard(0x0120), offset), offset_2), shl(5, length_1)), 32))
            { src_1 := add(src_1, 32) }
            {
                mstore(dst_1, abi_decode_address_fromMemory(src_1))
                dst_1 := add(dst_1, 32)
            }
            mstore(add(memPtr, 480), memPtr_3)
            let value_4 := mload(add(add(memoryguard(0x0120), offset), 512))
            mstore(add(memPtr, 512), value_4)
            let value1 := abi_decode_address_fromMemory(add(memoryguard(0x0120), 32))
            let value_5 := mload(add(memoryguard(0x0120), 64))
            if iszero(eq(value_5, and(value_5, sub(shl(160, 1), 1))))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:2895:2900  "10000"
            if /** @src 2:11593:11647  "_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS" */ lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(mload(add(memPtr, 256)), 0xffff), /** @src 2:2895:2900  "10000" */ 0x2710)
            {
                let memPtr_4 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_4, shl(229, 4594637))
                mstore(add(memPtr_4, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_4, 36), 28)
                mstore(add(memPtr_4, 68), "threshold increase too small")
                revert(memPtr_4, 100)
            }
            if /** @src 2:11800:11852  "_initialConfig.rewardEpochDurationInVotingEpochs > 0" */ iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(mload(add(memPtr, 224)), 0xffff))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_5 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_5, shl(229, 4594637))
                mstore(add(memPtr_5, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_5, 36), 26)
                mstore(add(memPtr_5, 68), "reward epoch duration zero")
                revert(memPtr_5, 100)
            }
            if /** @src 2:11901:11946  "_initialConfig.votingEpochDurationSeconds > 0" */ iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 160)), 0xff))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_6 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_6, shl(229, 4594637))
                mstore(add(memPtr_6, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_6, 36), 26)
                mstore(add(memPtr_6, 68), "voting epoch duration zero")
                revert(memPtr_6, 100)
            }
            if /** @src 2:12444:12497  "_initialConfig.initialSigningPolicyHash != bytes32(0)" */ iszero(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 64)))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_7 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_7, shl(229, 4594637))
                mstore(add(memPtr_7, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_7, 36), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_7, 68), "initial signing policy hash zero")
                revert(memPtr_7, 100)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let cleaned := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 192)), 0xffffffff)
            let cleaned_1 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:12629:12664  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
            /// @src 2:2895:2900  "10000"
            let product_raw := mul(cleaned_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(mload(add(memPtr, 224)), 0xffff))
            /// @src 2:2895:2900  "10000"
            let product := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ product_raw, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
            /// @src 2:2895:2900  "10000"
            if iszero(eq(product, product_raw))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2895:2900  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
            }
            let sum := add(cleaned, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ product)
            /// @src 2:2895:2900  "10000"
            if gt(sum, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
            /// @src 2:2895:2900  "10000"
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2895:2900  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
            }
            if /** @src 2:12565:12790  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:12565:12790  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ sum, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 32)), 0xffffffff))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_8 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_8, shl(229, 4594637))
                mstore(add(memPtr_8, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_8, 36), 40)
                mstore(add(memPtr_8, 68), "invalid initial starting voting ")
                mstore(add(memPtr_8, 100), "round id")
                revert(memPtr_8, 132)
            }
            /// @src 2:12866:12924  "initialRewardEpochId = _initialConfig.initialRewardEpochId"
            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 224, and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:12889:12924  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            /// @src 2:12934:13052  "startingVotingRoundIdForInitialRewardEpochId =..."
            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 256, and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 32)), 0xffffffff))
            let _12 := and(/** @src 2:2895:2900  "10000" */ value1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:13062:13104  "signingPolicySetter = _signingPolicySetter" */ 0x03, /** @src 2:2895:2900  "10000" */ or(and(sload(/** @src 2:13062:13104  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 2:2895:2900  "10000" */ not(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))), /** @src 2:2895:2900  "10000" */ _12))
            let _13 := mload(/** @src 2:13595:13630  "_initialConfig.initialRewardEpochId" */ memPtr)
            /// @src 2:2895:2900  "10000"
            let _14 := sload(/** @src 2:13556:13565  "stateData" */ 0x0b)
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:13556:13565  "stateData" */ 0x0b, /** @src 2:2895:2900  "10000" */ or(and(_14, not(shl(152, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:2895:2900  "10000" */ and(shl(152, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _13), /** @src 2:2895:2900  "10000" */ shl(152, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))))
            let cleaned_2 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 32)), 0xffffffff)
            /// @src 2:2895:2900  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(_13, 0xffffffff))
            /// @src 2:2895:2900  "10000"
            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:13640:13662  "startingVotingRoundIds" */ 0x02)
            /// @src 2:2895:2900  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:2895:2900  "10000" */ cleaned_2)
            let _15 := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 64))
            /// @src 2:2895:2900  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:13810:13845  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            /// @src 2:2895:2900  "10000"
            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src -1:-1:-1 */ 0)
            /// @src 2:2895:2900  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:2895:2900  "10000" */ _15)
            if iszero(/** @src 2:13906:13947  "_initialConfig.randomNumberProtocolId > 1" */ gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 96)), 0xff), 1))
            /// @src 2:2895:2900  "10000"
            {
                let memPtr_9 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_9, shl(229, 4594637))
                mstore(add(memPtr_9, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_9, 36), 37)
                mstore(add(memPtr_9, 68), "random number protocol id must b")
                mstore(add(memPtr_9, 100), "e > 1")
                revert(memPtr_9, 132)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let cleaned_3 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 96)), 0xff)
            /// @src 2:2895:2900  "10000"
            let _16 := sload(/** @src 2:13556:13565  "stateData" */ 0x0b)
            /// @src 2:2895:2900  "10000"
            let toInsert := and(shl(8, mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 128))), /** @src 2:2895:2900  "10000" */ 0xffffffff00)
            let toInsert_1 := and(shl(40, mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 160))), /** @src 2:2895:2900  "10000" */ 0xff0000000000)
            let toInsert_2 := and(shl(48, mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 192))), /** @src 2:2895:2900  "10000" */ 0xffffffff000000000000)
            let toInsert_3 := and(shl(80, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(add(memPtr, 224))), /** @src 2:2895:2900  "10000" */ 0xffff00000000000000000000)
            let toInsert_4 := and(shl(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 96, mload(add(memPtr, 256))), /** @src 2:2895:2900  "10000" */ 0xffff000000000000000000000000)
            let toInsert_5 := and(shl(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 192, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 288))), /** @src 2:2895:2900  "10000" */ shl(192, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            /// @src 2:2895:2900  "10000"
            let _17 := or(toInsert_3, and(or(toInsert_2, and(or(toInsert_1, and(or(toInsert, and(or(and(_16, not(0xffffffffffff)), cleaned_3), not(0xffffffff000000000000))), not(0xffff00000000000000000000))), not(0xffff000000000000000000000000))), not(shl(192, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:13556:13565  "stateData" */ 0x0b, /** @src 2:2895:2900  "10000" */ or(or(toInsert_4, _17), toInsert_5))
            /// @src 2:14665:14699  "_signingPolicySetter != address(0)"
            let _18 := iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _12)
            /// @src 2:14665:14699  "_signingPolicySetter != address(0)"
            let expr := iszero(_18)
            /// @src 2:14661:14844  "if (_signingPolicySetter != address(0)) {..."
            if expr
            {
                /// @src 2:2895:2900  "10000"
                if iszero(/** @src 2:14723:14760  "_initialConfig.feeConfigs.length == 0" */ iszero(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:14723:14748  "_initialConfig.feeConfigs" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 352)))))
                /// @src 2:2895:2900  "10000"
                {
                    let memPtr_10 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2895:2900  "10000"
                    mstore(memPtr_10, shl(229, 4594637))
                    mstore(add(memPtr_10, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(add(memPtr_10, 36), 17)
                    mstore(add(memPtr_10, 68), "fee cannot be set")
                    revert(memPtr_10, 100)
                }
                sstore(/** @src 2:13556:13565  "stateData" */ 0x0b, /** @src 2:2895:2900  "10000" */ or(or(toInsert_5, or(toInsert_4, and(_17, not(shl(184, 255))))), shl(184, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)))
            }
            let cleaned_4 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 320)), sub(shl(160, 1), 1))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 5, /** @src 2:2895:2900  "10000" */ or(and(sload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 5), /** @src 2:2895:2900  "10000" */ not(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))), /** @src 2:2895:2900  "10000" */ cleaned_4))
            /// @src 2:15038:15125  "_signingPolicySetter != address(0) || _initialConfig.feeCollectionAddress != address(0)"
            let expr_1 := expr
            if _18
            {
                expr_1 := /** @src 2:15076:15125  "_initialConfig.feeCollectionAddress != address(0)" */ iszero(iszero(cleaned_4))
            }
            /// @src 2:2895:2900  "10000"
            if iszero(expr_1)
            {
                let memPtr_11 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:2895:2900  "10000"
                mstore(memPtr_11, shl(229, 4594637))
                mstore(add(memPtr_11, 4), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                mstore(add(memPtr_11, 36), 27)
                mstore(add(memPtr_11, 68), "fee collection address zero")
                revert(memPtr_11, 100)
            }
            /// @src 2:15193:15206  "uint256 i = 0"
            let var_i := /** @src -1:-1:-1 */ 0
            /// @src 2:15188:15476  "for (uint256 i = 0; i < _initialConfig.feeConfigs.length; i++) {..."
            for { }
            /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1
            /// @src 2:15193:15206  "uint256 i = 0"
            {
                /// @src 2:15246:15249  "i++"
                var_i := /** @src 2:2895:2900  "10000" */ add(/** @src 2:15246:15249  "i++" */ var_i, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
            }
            /// @src 2:15246:15249  "i++"
            {
                /// @src 2:15212:15237  "_initialConfig.feeConfigs"
                let _mpos := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 352))
                /// @src 2:15208:15244  "i < _initialConfig.feeConfigs.length"
                if iszero(lt(var_i, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:15212:15244  "_initialConfig.feeConfigs.length" */ _mpos)))
                /// @src 2:15208:15244  "i < _initialConfig.feeConfigs.length"
                { break }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let cleaned_5 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:15284:15312  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(_mpos, var_i))), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)
                /// @src 2:2895:2900  "10000"
                if iszero(/** @src 2:15345:15359  "protocolId > 1" */ gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleaned_5, 1))
                /// @src 2:2895:2900  "10000"
                {
                    let memPtr_12 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2895:2900  "10000"
                    mstore(memPtr_12, shl(229, 4594637))
                    mstore(add(memPtr_12, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(add(memPtr_12, 36), 19)
                    mstore(add(memPtr_12, 68), "invalid protocol id")
                    revert(memPtr_12, 100)
                }
                let _19 := mload(/** @src 2:15428:15465  "_initialConfig.feeConfigs[i].feeInWei" */ add(/** @src 2:15428:15456  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(/** @src 2:15428:15453  "_initialConfig.feeConfigs" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 352)), /** @src 2:15428:15456  "_initialConfig.feeConfigs[i]" */ var_i)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                /// @src 2:2895:2900  "10000"
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ cleaned_5)
                mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04)
                /// @src 2:2895:2900  "10000"
                sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:2895:2900  "10000" */ _19)
            }
            let _20 := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 384))
            /// @src 2:15485:15549  "governanceSourceChainId = _initialConfig.governanceSourceChainId"
            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 128, /** @src 2:2895:2900  "10000" */ _20)
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let cleaned_6 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 416)), sub(shl(160, 1), 1))
            /// @src 2:15559:15605  "governanceSafe = _initialConfig.governanceSafe"
            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 160, /** @src 2:2895:2900  "10000" */ cleaned_6)
            let _21 := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 448))
            /// @src 2:2895:2900  "10000"
            sstore(8, _21)
            let _22 := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 512))
            /// @src 2:2895:2900  "10000"
            sstore(/** @src 2:15681:15741  "lastGovernanceSafeNonce = _initialConfig.governanceSafeNonce" */ 0x07, /** @src 2:2895:2900  "10000" */ _22)
            /// @src 2:15797:15825  "governanceSourceChainId != 0"
            let _23 := iszero(_20)
            /// @src 2:15797:15869  "governanceSourceChainId != 0 ||..."
            let expr_2 := /** @src 2:15797:15825  "governanceSourceChainId != 0" */ iszero(_23)
            let expr_3 := /** @src 2:15797:15869  "governanceSourceChainId != 0 ||..." */ expr_2
            if _23
            {
                expr_2 := /** @src 2:15841:15869  "governanceSafe != address(0)" */ iszero(iszero(cleaned_6))
            }
            /// @src 2:15797:15909  "governanceSourceChainId != 0 ||..."
            let expr_4 := expr_2
            if iszero(expr_2)
            {
                expr_4 := /** @src 2:15885:15909  "governanceThreshold != 0" */ iszero(iszero(_21))
            }
            /// @src 2:15797:15968  "governanceSourceChainId != 0 ||..."
            let expr_5 := expr_4
            if iszero(expr_4)
            {
                expr_5 := /** @src 2:15925:15968  "_initialConfig.governanceOwners.length != 0" */ iszero(iszero(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:15925:15956  "_initialConfig.governanceOwners" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480)))))
            }
            /// @src 2:15797:16012  "governanceSourceChainId != 0 ||..."
            let expr_6 := expr_5
            if iszero(expr_5)
            {
                expr_6 := /** @src 2:15984:16012  "lastGovernanceSafeNonce != 0" */ iszero(iszero(_22))
            }
            /// @src 2:16022:16992  "if (hasGovernanceConfiguration) {..."
            if expr_6
            {
                /// @src 2:16176:16236  "governanceSourceChainId == 0 || governanceSafe == address(0)"
                let expr_7 := _23
                if expr_3
                {
                    expr_7 := /** @src 2:16208:16236  "governanceSafe == address(0)" */ iszero(cleaned_6)
                }
                /// @src 2:16172:16303  "if (governanceSourceChainId == 0 || governanceSafe == address(0)) {..."
                if expr_7
                {
                    /// @src 2:16263:16288  "InvalidGovernanceSource()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:16263:16288  "InvalidGovernanceSource()" */ shl(224, 0x50b23415))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:16320:16389  "_signingPolicySetter != address(0) || _oldRelay != IRelay(address(0))"
                let expr_8 := expr
                if _18
                {
                    expr_8 := /** @src 2:16358:16389  "_oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value_5, sub(shl(160, 1), 1))))
                }
                /// @src 2:16316:16460  "if (_signingPolicySetter != address(0) || _oldRelay != IRelay(address(0))) {..."
                if expr_8
                {
                    /// @src 2:16416:16445  "InvalidGovernanceDeployment()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:16416:16445  "InvalidGovernanceDeployment()" */ shl(224, 0x352869e1))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:16473:16618  "if (_initialConfig.governanceOwners.length > MAX_GOVERNANCE_OWNERS) {..."
                if /** @src 2:16477:16539  "_initialConfig.governanceOwners.length > MAX_GOVERNANCE_OWNERS" */ gt(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:16477:16508  "_initialConfig.governanceOwners" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480))), 256)
                /// @src 2:16473:16618  "if (_initialConfig.governanceOwners.length > MAX_GOVERNANCE_OWNERS) {..."
                {
                    /// @src 2:16566:16603  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:16566:16603  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:16657:16688  "_initialConfig.governanceOwners"
                let _mpos_1 := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480))
                /// @src 2:32885:32898  "owners.length"
                let expr_9 := /** @src 2:2895:2900  "10000" */ mload(/** @src 2:32885:32898  "owners.length" */ _mpos_1)
                /// @src 2:32885:32921  "owners.length == 0 || threshold == 0"
                let expr_10 := /** @src 2:32885:32903  "owners.length == 0" */ iszero(expr_9)
                /// @src 2:32885:32921  "owners.length == 0 || threshold == 0"
                if iszero(expr_10)
                {
                    expr_10 := /** @src 2:32907:32921  "threshold == 0" */ iszero(_21)
                }
                /// @src 2:32885:32950  "owners.length == 0 || threshold == 0 || threshold > owners.length"
                let expr_11 := expr_10
                if iszero(expr_10)
                {
                    expr_11 := /** @src 2:32925:32950  "threshold > owners.length" */ gt(_21, expr_9)
                }
                /// @src 2:32881:33021  "if (owners.length == 0 || threshold == 0 || threshold > owners.length) {..."
                if expr_11
                {
                    /// @src 2:32973:33010  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:16566:16603  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    /// @src 2:32973:33010  "InvalidGovernanceOwnerConfiguration()"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04)
                }
                /// @src 2:33035:33044  "uint256 i"
                let var_i_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:33035:33044  "uint256 i"
                var_i_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:33030:33241  "for (uint256 i; i < owners.length; ++i) {..."
                for { }
                /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1
                /// @src 2:33035:33044  "uint256 i"
                {
                    /// @src 2:33065:33068  "++i"
                    var_i_1 := /** @src 2:2895:2900  "10000" */ add(/** @src 2:33065:33068  "++i" */ var_i_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:33065:33068  "++i"
                {
                    /// @src 2:33046:33063  "i < owners.length"
                    if iszero(lt(var_i_1, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:33050:33063  "owners.length" */ _mpos_1)))
                    /// @src 2:33046:33063  "i < owners.length"
                    { break }
                    /// @src 2:33088:33152  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    let expr_12 := /** @src 2:33088:33111  "owners[i] == address(0)" */ iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:33088:33097  "owners[i]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_1, var_i_1)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 2:33088:33152  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    if iszero(expr_12)
                    {
                        /// @src 2:33116:33151  "i > 0 && owners[i - 1] >= owners[i]"
                        let expr_13 := /** @src 2:33116:33121  "i > 0" */ iszero(iszero(var_i_1))
                        /// @src 2:33116:33151  "i > 0 && owners[i - 1] >= owners[i]"
                        if expr_13
                        {
                            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                            let diff := add(var_i_1, not(0))
                            if gt(diff, var_i_1)
                            {
                                /// @src 2:2895:2900  "10000"
                                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                                /// @src 2:2895:2900  "10000"
                                mstore(/** @src 2:15397:15413  "protocolFeeInWei" */ 0x04, /** @src 2:2895:2900  "10000" */ 0x11)
                                revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
                            }
                            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                            let cleaned_7 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:33125:33138  "owners[i - 1]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_1, /** @src 2:33132:33137  "i - 1" */ diff)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                            /// @src 2:33116:33151  "i > 0 && owners[i - 1] >= owners[i]"
                            expr_13 := /** @src 2:33125:33151  "owners[i - 1] >= owners[i]" */ iszero(lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleaned_7, and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:33142:33151  "owners[i]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_1, var_i_1)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                        }
                        /// @src 2:33088:33152  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                        expr_12 := expr_13
                    }
                    /// @src 2:33084:33231  "if (owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])) {..."
                    if expr_12
                    {
                        /// @src 2:33179:33216  "InvalidGovernanceOwnerConfiguration()"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:16566:16603  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                        /// @src 2:33179:33216  "InvalidGovernanceOwnerConfiguration()"
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04)
                    }
                }
                /// @src 2:16729:16738  "uint256 i"
                let var_i_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:16729:16738  "uint256 i"
                var_i_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:16724:16879  "for (uint256 i; i < _initialConfig.governanceOwners.length; ++i) {..."
                for { }
                /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1
                /// @src 2:16729:16738  "uint256 i"
                {
                    /// @src 2:16784:16787  "++i"
                    var_i_2 := /** @src 2:2895:2900  "10000" */ add(/** @src 2:16784:16787  "++i" */ var_i_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:16784:16787  "++i"
                {
                    /// @src 2:16744:16775  "_initialConfig.governanceOwners"
                    let _mpos_2 := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(memPtr, 480))
                    /// @src 2:16740:16782  "i < _initialConfig.governanceOwners.length"
                    if iszero(lt(var_i_2, /** @src 2:2895:2900  "10000" */ mload(/** @src 2:16744:16782  "_initialConfig.governanceOwners.length" */ _mpos_2)))
                    /// @src 2:16740:16782  "i < _initialConfig.governanceOwners.length"
                    { break }
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    let cleaned_8 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:16829:16863  "_initialConfig.governanceOwners[i]" */ memory_array_index_access_struct_FeeConfig_dyn(_mpos_2, var_i_2)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                    /// @src 2:9699:9702  "256"
                    let oldLen := sload(/** @src 2:16807:16823  "governanceOwners" */ 0x09)
                    /// @src 2:9699:9702  "256"
                    if iszero(lt(oldLen, 18446744073709551616))
                    {
                        /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                        mstore(/** @src 2:15397:15413  "protocolFeeInWei" */ 0x04, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x41)
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
                    }
                    /// @src 2:9699:9702  "256"
                    let _24 := add(oldLen, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                    /// @src 2:9699:9702  "256"
                    sstore(/** @src 2:16807:16823  "governanceOwners" */ 0x09, /** @src 2:9699:9702  "256" */ _24)
                    if iszero(lt(oldLen, _24))
                    {
                        /// @src 2:2895:2900  "10000"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                        /// @src 2:2895:2900  "10000"
                        mstore(/** @src 2:15397:15413  "protocolFeeInWei" */ 0x04, /** @src 2:2895:2900  "10000" */ 0x32)
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:2895:2900  "10000" */ 0x24)
                    }
                    /// @src 2:9699:9702  "256"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:16807:16823  "governanceOwners" */ 0x09)
                    /// @src 2:9699:9702  "256"
                    let slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32), /** @src 2:9699:9702  "256" */ oldLen)
                    sstore(slot, or(and(sload(slot), /** @src 2:2895:2900  "10000" */ not(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))), /** @src 2:9699:9702  "256" */ cleaned_8))
                }
                /// @src 2:2895:2900  "10000"
                let _25 := sload(8)
                /// @src 2:9699:9702  "256"
                let pos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:9699:9702  "256"
                let memPtr_13 := pos
                let length_2 := sload(/** @src 2:16807:16823  "governanceOwners" */ 0x09)
                /// @src 2:2895:2900  "10000"
                mstore(pos, length_2)
                /// @src 2:9699:9702  "256"
                pos := /** @src 2:2895:2900  "10000" */ add(pos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:2895:2900  "10000"
                let updated_pos := /** @src 2:9699:9702  "256" */ pos
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:16807:16823  "governanceOwners" */ 0x09)
                /// @src 2:9699:9702  "256"
                let srcPtr := keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 2:9699:9702  "256"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 2:9699:9702  "256"
                for { }
                lt(i, length_2)
                {
                    i := add(i, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:9699:9702  "256"
                {
                    mstore(pos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:9699:9702  "256" */ sload(srcPtr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 2:9699:9702  "256"
                    pos := add(pos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:9699:9702  "256"
                    srcPtr := add(srcPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 2:9699:9702  "256"
                finalize_allocation(memPtr_13, sub(pos, memPtr_13))
                /// @src 2:2895:2900  "10000"
                let _26 := mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 128)
                let cleaned_9 := and(/** @src 2:2895:2900  "10000" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 160), sub(shl(160, 1), 1))
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                let expr_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                let _27 := add(expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                /// @src 0:224:350  "keccak256(..."
                let tail := add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 192)
                /// @src 0:224:350  "keccak256(..."
                mstore(_27, 0xb4237fcada7bd9adba2337f1358a57af9f53602d06e3622b52390b2178c62c41)
                mstore(add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 0:224:350  "keccak256(..." */ _26)
                /// @src 2:9699:9702  "256"
                mstore(/** @src 0:224:350  "keccak256(..." */ add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 96), cleaned_9)
                /// @src 0:224:350  "keccak256(..."
                mstore(add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 128), /** @src 0:224:350  "keccak256(..." */ _25)
                mstore(add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 160), 160)
                /// @src 0:224:350  "keccak256(..."
                let pos_1 := tail
                let length_3 := /** @src 2:2895:2900  "10000" */ mload(/** @src 0:224:350  "keccak256(..." */ memPtr_13)
                /// @src 2:2895:2900  "10000"
                mstore(tail, length_3)
                /// @src 0:224:350  "keccak256(..."
                pos_1 := /** @src 2:2895:2900  "10000" */ add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 224)
                /// @src 0:224:350  "keccak256(..."
                let srcPtr_1 := updated_pos
                let i_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:224:350  "keccak256(..."
                for { }
                lt(i_1, length_3)
                {
                    i_1 := add(i_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1)
                }
                /// @src 0:224:350  "keccak256(..."
                {
                    /// @src 2:9699:9702  "256"
                    mstore(pos_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 0:224:350  "keccak256(..." */ mload(srcPtr_1), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 0:224:350  "keccak256(..."
                    pos_1 := /** @src 2:9699:9702  "256" */ add(pos_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 0:224:350  "keccak256(..."
                    srcPtr_1 := add(srcPtr_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                }
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                let _28 := sub(pos_1, expr_mpos)
                mstore(expr_mpos, add(_28, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                finalize_allocation(expr_mpos, _28)
                /// @src 2:2895:2900  "10000"
                sstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 6, /** @src 0:550:634  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners))" */ keccak256(/** @src 0:224:350  "keccak256(..." */ _27, /** @src 2:2895:2900  "10000" */ mload(/** @src 0:550:634  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners))" */ expr_mpos)))
            }
            /// @src 2:17001:17021  "oldRelay = _oldRelay"
            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 192, /** @src 2:17001:17021  "oldRelay = _oldRelay" */ value_5)
            /// @src 2:17112:18425  "if(oldRelay != IIRelay(address(0))) {..."
            if /** @src 2:17115:17146  "oldRelay != IIRelay(address(0))" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value_5, sub(shl(160, 1), 1))))
            /// @src 2:17112:18425  "if(oldRelay != IIRelay(address(0))) {..."
            {
                /// @src 2:17188:17221  "signingPolicySetter != address(0)"
                let _29 := iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:9699:9702  "256" */ sload(/** @src 2:13062:13104  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                /// @src 2:17188:17269  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                let expr_14 := /** @src 2:17188:17221  "signingPolicySetter != address(0)" */ iszero(_29)
                /// @src 2:17188:17269  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                if expr_14
                {
                    /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                    let _30 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                    mstore(_30, /** @src 2:9699:9702  "256" */ shl(224, 0xa9dbe8ed))
                    /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                    let _31 := staticcall(gas(), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value_5, sub(shl(160, 1), 1)), /** @src 2:17225:17255  "oldRelay.signingPolicySetter()" */ _30, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04, /** @src 2:17225:17255  "oldRelay.signingPolicySetter()" */ _30, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                    if iszero(_31)
                    {
                        /// @src 2:9699:9702  "256"
                        let pos_2 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                        /// @src 2:9699:9702  "256"
                        returndatacopy(pos_2, /** @src -1:-1:-1 */ 0, /** @src 2:9699:9702  "256" */ returndatasize())
                        revert(pos_2, returndatasize())
                    }
                    /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                    let expr_15 := /** @src -1:-1:-1 */ 0
                    /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                    if _31
                    {
                        let _32 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32
                        /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                        if gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:17225:17255  "oldRelay.signingPolicySetter()" */ returndatasize()) { _32 := returndatasize() }
                        finalize_allocation(_30, _32)
                        /// @src 2:9699:9702  "256"
                        if slt(sub(/** @src 2:17225:17255  "oldRelay.signingPolicySetter()" */ add(_30, _32), /** @src 2:9699:9702  "256" */ _30), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                        /// @src 2:9699:9702  "256"
                        {
                            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                            revert(/** @src -1:-1:-1 */ 0, 0)
                        }
                        /// @src 2:17225:17255  "oldRelay.signingPolicySetter()"
                        expr_15 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_address_fromMemory(/** @src 2:9699:9702  "256" */ _30)
                    }
                    /// @src 2:17188:17269  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                    expr_14 := /** @src 2:17225:17269  "oldRelay.signingPolicySetter() != address(0)" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:17225:17269  "oldRelay.signingPolicySetter() != address(0)" */ expr_15, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                }
                /// @src 2:17187:17373  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                let expr_16 := expr_14
                if iszero(expr_14)
                {
                    /// @src 2:17291:17372  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                    let expr_17 := _29
                    if _29
                    {
                        /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                        let cleaned_10 := and(/** @src 2:9699:9702  "256" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 192), sub(shl(160, 1), 1))
                        /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                        let _33 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                        /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                        mstore(_33, /** @src 2:9699:9702  "256" */ shl(224, 0xa9dbe8ed))
                        /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                        let _34 := staticcall(gas(), cleaned_10, _33, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04, /** @src 2:17328:17358  "oldRelay.signingPolicySetter()" */ _33, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                        /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                        if iszero(_34)
                        {
                            /// @src 2:9699:9702  "256"
                            let pos_3 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                            /// @src 2:9699:9702  "256"
                            returndatacopy(pos_3, /** @src -1:-1:-1 */ 0, /** @src 2:9699:9702  "256" */ returndatasize())
                            revert(pos_3, returndatasize())
                        }
                        /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                        let expr_18 := /** @src -1:-1:-1 */ 0
                        /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                        if _34
                        {
                            let _35 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32
                            /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                            if gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32, /** @src 2:17328:17358  "oldRelay.signingPolicySetter()" */ returndatasize()) { _35 := returndatasize() }
                            finalize_allocation(_33, _35)
                            /// @src 2:9699:9702  "256"
                            if slt(sub(/** @src 2:17328:17358  "oldRelay.signingPolicySetter()" */ add(_33, _35), /** @src 2:9699:9702  "256" */ _33), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                            /// @src 2:9699:9702  "256"
                            {
                                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                                revert(/** @src -1:-1:-1 */ 0, 0)
                            }
                            /// @src 2:17328:17358  "oldRelay.signingPolicySetter()"
                            expr_18 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_address_fromMemory(/** @src 2:9699:9702  "256" */ _33)
                        }
                        /// @src 2:17291:17372  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                        expr_17 := /** @src 2:17328:17372  "oldRelay.signingPolicySetter() == address(0)" */ iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:17328:17372  "oldRelay.signingPolicySetter() == address(0)" */ expr_18, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    }
                    /// @src 2:17187:17373  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                    expr_16 := expr_17
                }
                /// @src 2:9699:9702  "256"
                if iszero(expr_16)
                {
                    let memPtr_14 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:9699:9702  "256"
                    mstore(memPtr_14, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:9699:9702  "256"
                    mstore(add(memPtr_14, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:9699:9702  "256" */ add(memPtr_14, 36), 22)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:9699:9702  "256" */ memPtr_14, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:9699:9702  "256" */ "old relay incompatible")
                    revert(memPtr_14, 100)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let cleaned_11 := and(/** @src 2:9699:9702  "256" */ mload(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 192), sub(shl(160, 1), 1))
                /// @src 2:17716:17736  "oldRelay.stateData()"
                let _36 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:17716:17736  "oldRelay.stateData()"
                mstore(_36, /** @src 2:9699:9702  "256" */ shl(225, 0x0f47d9b5))
                /// @src 2:17716:17736  "oldRelay.stateData()"
                let _37 := staticcall(gas(), cleaned_11, _36, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04, /** @src 2:17716:17736  "oldRelay.stateData()" */ _36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 352)
                /// @src 2:17716:17736  "oldRelay.stateData()"
                if iszero(_37)
                {
                    /// @src 2:9699:9702  "256"
                    let pos_4 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:9699:9702  "256"
                    returndatacopy(pos_4, /** @src -1:-1:-1 */ 0, /** @src 2:9699:9702  "256" */ returndatasize())
                    revert(pos_4, returndatasize())
                }
                let expr_component := /** @src -1:-1:-1 */ 0
                let expr_component_1 := 0
                let expr_component_2 := 0
                let expr_component_3 := 0
                /// @src 2:17716:17736  "oldRelay.stateData()"
                if _37
                {
                    let _38 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 352
                    /// @src 2:17716:17736  "oldRelay.stateData()"
                    if gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _38, /** @src 2:17716:17736  "oldRelay.stateData()" */ returndatasize()) { _38 := returndatasize() }
                    finalize_allocation(_36, _38)
                    /// @src 2:9699:9702  "256"
                    if slt(sub(/** @src 2:17716:17736  "oldRelay.stateData()" */ add(_36, _38), /** @src 2:9699:9702  "256" */ _36), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 352)
                    /// @src 2:9699:9702  "256"
                    {
                        /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    pop(abi_decode_uint8_fromMemory(/** @src 2:9699:9702  "256" */ _36))
                    let value1_1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint32_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                    /// @src 2:9699:9702  "256"
                    let value2 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint8_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64))
                    /// @src 2:9699:9702  "256"
                    let value3 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint32_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 96))
                    /// @src 2:9699:9702  "256"
                    let value4 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_uint16_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 128))
                    pop(abi_decode_uint16_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 160)))
                    pop(abi_decode_uint32_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 192)))
                    /// @src 2:9699:9702  "256"
                    pop(abi_decode_bool_fromMemory(add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 224)))
                    pop(abi_decode_uint32_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 256)))
                    /// @src 2:9699:9702  "256"
                    pop(abi_decode_bool_fromMemory(add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 288)))
                    pop(abi_decode_uint32_fromMemory(/** @src 2:9699:9702  "256" */ add(_36, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 320)))
                    /// @src 2:17716:17736  "oldRelay.stateData()"
                    expr_component := value1_1
                    expr_component_1 := value2
                    expr_component_2 := value3
                    expr_component_3 := value4
                }
                /// @src 2:9699:9702  "256"
                let _39 := sload(/** @src 2:13556:13565  "stateData" */ 0x0b)
                /// @src 2:9699:9702  "256"
                if iszero(/** @src 2:17775:17835  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ eq(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:9699:9702  "256" */ shr(/** @src 2:2895:2900  "10000" */ 8, /** @src 2:9699:9702  "256" */ _39), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), and(/** @src 2:17775:17835  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ expr_component, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
                /// @src 2:9699:9702  "256"
                {
                    let memPtr_15 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:9699:9702  "256"
                    mstore(memPtr_15, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:9699:9702  "256"
                    mstore(add(memPtr_15, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:9699:9702  "256" */ add(memPtr_15, 36), 14)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:9699:9702  "256" */ memPtr_15, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:9699:9702  "256" */ "wrong start ts")
                    revert(memPtr_15, 100)
                }
                if iszero(/** @src 2:17922:18002  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ eq(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:9699:9702  "256" */ shr(/** @src 2:2895:2900  "10000" */ 80, /** @src 2:9699:9702  "256" */ _39), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff), and(/** @src 2:17922:18002  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ expr_component_3, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff)))
                /// @src 2:9699:9702  "256"
                {
                    let memPtr_16 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:9699:9702  "256"
                    mstore(memPtr_16, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:9699:9702  "256"
                    mstore(add(memPtr_16, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:9699:9702  "256" */ add(memPtr_16, 36), 27)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:9699:9702  "256" */ memPtr_16, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:9699:9702  "256" */ "wrong reward epoch duration")
                    revert(memPtr_16, 100)
                }
                if iszero(/** @src 2:18102:18184  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ eq(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:9699:9702  "256" */ shr(/** @src 2:2895:2900  "10000" */ 48, /** @src 2:9699:9702  "256" */ _39), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), and(/** @src 2:18102:18184  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ expr_component_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
                /// @src 2:9699:9702  "256"
                {
                    let memPtr_17 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:9699:9702  "256"
                    mstore(memPtr_17, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:9699:9702  "256"
                    mstore(add(memPtr_17, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:9699:9702  "256" */ add(memPtr_17, 36), 30)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:9699:9702  "256" */ memPtr_17, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:9699:9702  "256" */ "wrong first reward epoch start")
                    revert(memPtr_17, 100)
                }
                if iszero(/** @src 2:18287:18353  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ eq(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:9699:9702  "256" */ shr(/** @src 2:2895:2900  "10000" */ 40, /** @src 2:9699:9702  "256" */ _39), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff), and(/** @src 2:18287:18353  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ expr_component_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)))
                /// @src 2:9699:9702  "256"
                {
                    let memPtr_18 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:9699:9702  "256"
                    mstore(memPtr_18, /** @src 2:2895:2900  "10000" */ shl(229, 4594637))
                    /// @src 2:9699:9702  "256"
                    mstore(add(memPtr_18, /** @src 2:15397:15413  "protocolFeeInWei" */ 0x04), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32)
                    /// @src 2:2895:2900  "10000"
                    mstore(/** @src 2:9699:9702  "256" */ add(memPtr_18, 36), 27)
                    mstore(/** @src 2:2895:2900  "10000" */ add(/** @src 2:9699:9702  "256" */ memPtr_18, /** @src 2:2895:2900  "10000" */ 68), /** @src 2:9699:9702  "256" */ "wrong voting epoch duration")
                    revert(memPtr_18, 100)
                }
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            let _40 := mload(64)
            let _41 := datasize("Relay_3019_deployed")
            codecopy(_40, dataoffset("Relay_3019_deployed"), _41)
            setimmutable(_40, "468", mload(128))
            setimmutable(_40, "471", mload(160))
            setimmutable(_40, "523", mload(192))
            setimmutable(_40, "526", mload(224))
            setimmutable(_40, "529", mload(256))
            return(_40, _41)
        }
        function finalize_allocation(memPtr, size)
        {
            let newFreePtr := add(memPtr, and(add(size, 31), not(31)))
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x24)
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
                mstore(0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2895:2900  "10000"
                mstore(4, 0x32)
                revert(0, 0x24)
            }
            addr := add(add(baseRef, shl(5, index)), 32)
        }
        /// @src 2:9699:9702  "256"
        function abi_decode_bool_fromMemory(offset) -> value
        {
            value := mload(offset)
            if iszero(eq(value, /** @src 2:2895:2900  "10000" */ iszero(iszero(/** @src 2:9699:9702  "256" */ value)))) { revert(0, 0) }
        }
    }
    /// @use-src 0:"contracts/governance/GSSGovernance.sol", 1:"contracts/governance/GnosisSafeTx.sol", 2:"contracts/protocol/implementation/Relay.sol", 7:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/ECDSA.sol", 8:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/Hashes.sol", 9:"dependencies/@openzeppelin-contracts-5.4.0/utils/cryptography/MerkleProof.sol"
    object "Relay_3019_deployed" {
        code {
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(64, 128)
                if iszero(lt(calldatasize(), 4))
                {
                    switch shr(224, calldataload(0))
                    case 0x016a8917 {
                        external_fun_governanceSourceChainId()
                    }
                    case 0x0c85bf07 {
                        external_fun_toSigningPolicyHash()
                    }
                    case 0x1e8fb36a { external_fun_stateData() }
                    case 0x317ad33c { external_fun_isFinalized() }
                    case 0x342ea4de {
                        external_fun_activeOwnerConfigHash()
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
                    case 0xdbdff2c1 {
                        external_fun_getRandomNumber()
                    }
                    case 0xffc1f8ef { external_fun_oldRelay() }
                }
                revert(0, 0)
            }
            function abi_encode_uint256(headStart, value0) -> tail
            {
                tail := add(headStart, 32)
                mstore(headStart, value0)
            }
            function external_fun_governanceSourceChainId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, /** @src 2:9340:9397  "uint256 public immutable override governanceSourceChainId" */ loadimmutable("468"))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                return(memPos, 32)
            }
            function abi_decode_uint256() -> value
            { value := calldataload(4) }
            function abi_decode_uint256_18378() -> value
            { value := calldataload(36) }
            function external_fun_toSigningPolicyHash()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                let ret := fun_toSigningPolicyHash(value)
                let memPos := mload(64)
                mstore(memPos, ret)
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
                let _1 := sload(/** @src 2:10452:10478  "StateData public stateData" */ 11)
                let ret := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_bool(_1)
                /// @src 2:10452:10478  "StateData public stateData"
                let ret_1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offset_24t_uint32(_1)
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                let _1 := sload(/** @src 2:9457:9502  "bytes32 public override activeOwnerConfigHash" */ 6)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, _1)
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
                let value := and(sload(/** @src 2:9290:9333  "address payable public feeCollectionAddress" */ 5), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                let length := sload(/** @src 2:27229:27245  "governanceOwners" */ 0x09)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, length)
                return(memPos, 32)
            }
            function external_fun_startingVotingRoundIdForInitialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:10908:10976  "uint32 public immutable startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("529"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function external_fun_lastGovernanceSafeNonce()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:9508:9555  "uint256 public override lastGovernanceSafeNonce" */ 7)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_governanceThreshold()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:9561:9604  "uint256 public override governanceThreshold" */ 8)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                mstore(memPos, _1)
                return(memPos, 32)
            }
            function external_fun_initialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:10805:10849  "uint32 public immutable initialRewardEpochId" */ loadimmutable("526"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_18441(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, 0)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_18442(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:87748:87766  "merkleRootsPrivate" */ 0x01)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_18444(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:85818:85834  "protocolFeeInWei" */ 0x04)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_18517(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:90065:90086  "toRandomNumberPrivate" */ 0x0c)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_18519(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 2:90143:90160  "isSecureRandomMap" */ 0x0a)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value)
                mstore(32, /** @src 2:8980:9051  "mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds" */ 2)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x40))
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value0 := abi_decode_uint256()
                let value1 := abi_decode_uint256_18378()
                let value2 := abi_decode_bytes32()
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let length := calldataload(add(4, offset))
                if gt(length, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if gt(add(add(offset, shl(5, length)), 36), calldatasize())
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            function finalize_allocation_18628(memPtr)
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
            function allocate_memory_18387() -> memPtr
            {
                memPtr := mload(64)
                finalize_allocation(memPtr, 0xc0)
            }
            function allocate_memory() -> memPtr
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0xc0)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := allocate_memory_18387()
                mstore(value, abi_decode_uint24(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                mstore(add(value, 64), abi_decode_uint16(add(offset, 68)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(add(offset, 100))
                mstore(add(value, 96), value_1)
                let offset_1 := calldataload(add(offset, 132))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(value, 128), abi_decode_array_address_dyn(add(add(offset, offset_1), 4), calldatasize()))
                let offset_2 := calldataload(add(offset, 164))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(value, 160), abi_decode_array_uint16_dyn(add(add(offset, offset_2), 4), calldatasize()))
                /// @src 2:18733:18740  "bytes32"
                let var := modifier_onlySigningPolicySetter(value)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256(memPos, var), memPos))
            }
            function external_fun_governanceOwner()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 32)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                if iszero(lt(value, sload(/** @src 2:27363:27379  "governanceOwners" */ 0x09)))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:27363:27379  "governanceOwners" */ 0x09)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value_1 := and(sload(add(49791959467252497455735130940088646708311117250336157395101362029847983277999, value)), sub(shl(160, 1), 1))
                let memPos := mload(64)
                mstore(memPos, value_1)
                return(memPos, 32)
            }
            function external_fun_lastInitializedRewardEpochData()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(152, sload(/** @src 2:91527:91536  "stateData" */ 0x0b)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 2:91646:91668  "startingVotingRoundIds" */ 0x02)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value)
                mstore(32, 4)
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x40))
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value0, value1 := abi_decode_bytes_calldata(add(4, offset), calldatasize())
                let value2 := abi_decode_uint256_18378()
                /// @src 2:92018:92051  "address(this).call(_relayMessage)"
                let _1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                calldatacopy(_1, value0, value1)
                let _2 := add(_1, value1)
                mstore(_2, /** @src -1:-1:-1 */ 0)
                /// @src 2:92018:92051  "address(this).call(_relayMessage)"
                let expr_component := call(gas(), /** @src 2:92026:92030  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 2:92018:92051  "address(this).call(_relayMessage)" */ _1, sub(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _2, /** @src 2:92018:92051  "address(this).call(_relayMessage)" */ _1), /** @src -1:-1:-1 */ 0, 0)
                /// @src 2:92018:92051  "address(this).call(_relayMessage)"
                let expr_component_mpos := extract_returndata()
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(expr_component)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 19)
                    mstore(add(memPtr, 68), "Verification failed")
                    revert(memPtr, 100)
                }
                /// @src 2:92645:92704  "require(returnData.length == 35, \"Wrong verification data\")"
                require_helper_stringliteral_3323(/** @src 2:92653:92676  "returnData.length == 35" */ eq(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:92653:92670  "returnData.length" */ expr_component_mpos), /** @src 2:92674:92676  "35" */ 0x23))
                /// @src 2:92835:93020  "assembly {..."
                let var_returnHash := mload(add(expr_component_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                /// @src 2:92835:93020  "assembly {..."
                let var_returnRewardEpochId := shr(232, mload(add(expr_component_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)))
                /// @src 2:93029:93096  "require(bytes32(returnHash) == _messageHash, \"Invalid config hash\")"
                require_helper_stringliteral_a3dc(/** @src 2:93037:93072  "bytes32(returnHash) == _messageHash" */ eq(var_returnHash, value2))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256(memPos, var_returnRewardEpochId), memPos))
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := add(4, offset)
                if slt(add(sub(calldatasize(), offset), not(3)), 320)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let offset_1 := calldataload(36)
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value1, value2 := abi_decode_bytes_calldata(add(4, offset_1), calldatasize())
                /// @src 2:26093:26146  "governanceSafe == address(0) || txData.operation != 0"
                let expr := /** @src 2:26093:26121  "governanceSafe == address(0)" */ iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:26093:26107  "governanceSafe" */ loadimmutable("471"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                /// @src 2:26093:26146  "governanceSafe == address(0) || txData.operation != 0"
                if iszero(expr)
                {
                    expr := /** @src 2:26125:26146  "txData.operation != 0" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:26125:26141  "txData.operation" */ read_from_calldatat_uint8(add(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, /** @src 2:26125:26141  "txData.operation" */ 100)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)))
                }
                /// @src 2:26093:26167  "governanceSafe == address(0) || txData.operation != 0 || txData.value != 0"
                let expr_1 := expr
                if iszero(expr)
                {
                    /// @src 2:26150:26162  "txData.value"
                    let value := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    value := calldataload(/** @src 2:26150:26162  "txData.value" */ add(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, 36))
                    /// @src 2:26093:26167  "governanceSafe == address(0) || txData.operation != 0 || txData.value != 0"
                    expr_1 := /** @src 2:26150:26167  "txData.value != 0" */ iszero(iszero(value))
                }
                /// @src 2:26089:26231  "if (governanceSafe == address(0) || txData.operation != 0 || txData.value != 0) {..."
                if expr_1
                {
                    /// @src 2:26190:26220  "InvalidGovernanceTransaction()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4)
                }
                /// @src 2:26276:26286  "signatures"
                fun_verifyGovernanceSignatures(_1, value1, value2)
                /// @src 2:26335:26346  "txData.data"
                let _2 := add(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, /** @src 2:26335:26346  "txData.data" */ 68)
                let expr_offset, expr_length := access_calldata_tail_bytes_calldata(_1, _2)
                /// @src 2:26315:26347  "_governanceSelector(txData.data)"
                let expr_2 := fun_governanceSelector(expr_offset, expr_length)
                /// @src 2:26402:26413  "txData.data"
                let expr_offset_1, expr_length_1 := access_calldata_tail_bytes_calldata(_1, _2)
                /// @src 2:26379:26414  "_governanceActionNonce(txData.data)"
                let expr_3 := fun_governanceActionNonce(expr_offset_1, expr_length_1)
                /// @src 2:26428:26440  "txData.nonce"
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(/** @src 2:26428:26440  "txData.nonce" */ add(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ offset, /** @src 2:26428:26440  "txData.nonce" */ 292))
                /// @src 2:26428:26496  "txData.nonce == type(uint256).max || actionNonce != txData.nonce + 1"
                let expr_4 := /** @src 2:26428:26461  "txData.nonce == type(uint256).max" */ eq(value_1, /** @src 2:26444:26461  "type(uint256).max" */ not(0))
                /// @src 2:26428:26496  "txData.nonce == type(uint256).max || actionNonce != txData.nonce + 1"
                if iszero(expr_4)
                {
                    expr_4 := /** @src 2:26465:26496  "actionNonce != txData.nonce + 1" */ iszero(eq(expr_3, /** @src 2:26480:26496  "txData.nonce + 1" */ checked_add_uint256_18393(value_1)))
                }
                /// @src 2:26424:26560  "if (txData.nonce == type(uint256).max || actionNonce != txData.nonce + 1) {..."
                if expr_4
                {
                    /// @src 2:26519:26549  "InvalidGovernanceTransaction()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:26519:26549  "InvalidGovernanceTransaction()"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4)
                }
                let _3 := sload(/** @src 2:26588:26611  "lastGovernanceSafeNonce" */ 0x07)
                /// @src 2:26569:26710  "if (actionNonce <= lastGovernanceSafeNonce) {..."
                if /** @src 2:26573:26611  "actionNonce <= lastGovernanceSafeNonce" */ iszero(gt(expr_3, _3))
                /// @src 2:26569:26710  "if (actionNonce <= lastGovernanceSafeNonce) {..."
                {
                    /// @src 2:26634:26699  "GovernanceNonceNotMonotonic(actionNonce, lastGovernanceSafeNonce)"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:26634:26699  "GovernanceNonceNotMonotonic(actionNonce, lastGovernanceSafeNonce)" */ shl(224, 0xeaafa115))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:26634:26699  "GovernanceNonceNotMonotonic(actionNonce, lastGovernanceSafeNonce)" */ abi_encode_uint256_uint256_18394(expr_3, _3))
                }
                /// @src 2:26719:26732  "bool relevant"
                let var_relevant := /** @src -1:-1:-1 */ 0
                /// @src 2:26719:26732  "bool relevant"
                var_relevant := /** @src -1:-1:-1 */ 0
                /// @src 2:26746:26780  "selector == CHANGE_OWNERS_SELECTOR"
                let _4 := /** @src 2:4462:4464  "22" */ and(/** @src 2:26746:26780  "selector == CHANGE_OWNERS_SELECTOR" */ expr_2, /** @src 2:4462:4464  "22" */ shl(224, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                /// @src 2:26742:27064  "if (selector == CHANGE_OWNERS_SELECTOR) {..."
                switch /** @src 2:26746:26780  "selector == CHANGE_OWNERS_SELECTOR" */ eq(_4, /** @src 2:4462:4464  "22" */ shl(226, 0x23d0fe25))
                case /** @src 2:26742:27064  "if (selector == CHANGE_OWNERS_SELECTOR) {..." */ 0 {
                    /// @src 2:26877:27064  "if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {..."
                    switch /** @src 2:26881:26922  "selector == CHANGE_PROTOCOL_FEES_SELECTOR" */ eq(_4, /** @src 2:4462:4464  "22" */ shl(225, 0x0ac2ae7b))
                    case /** @src 2:26877:27064  "if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {..." */ 0 {
                        /// @src 2:27020:27053  "UnknownGovernanceAction(selector)"
                        mstore(/** @src -1:-1:-1 */ 0, /** @src 2:27020:27053  "UnknownGovernanceAction(selector)" */ shl(228, 0x0cd3f8fb))
                        revert(/** @src -1:-1:-1 */ 0, /** @src 2:27020:27053  "UnknownGovernanceAction(selector)" */ abi_encode_bytes4(expr_2))
                    }
                    default /// @src 2:26877:27064  "if (selector == CHANGE_PROTOCOL_FEES_SELECTOR) {..."
                    {
                        /// @src 2:26970:26981  "txData.data"
                        let expr_offset_2, expr_length_2 := access_calldata_tail_bytes_calldata(_1, _2)
                        /// @src 2:26938:26982  "relevant = _applyGovernanceFees(txData.data)"
                        var_relevant := /** @src 2:26949:26982  "_applyGovernanceFees(txData.data)" */ fun_applyGovernanceFees(expr_offset_2, expr_length_2)
                    }
                }
                default /// @src 2:26742:27064  "if (selector == CHANGE_OWNERS_SELECTOR) {..."
                {
                    /// @src 2:26819:26830  "txData.data"
                    let expr_offset_3, expr_length_3 := access_calldata_tail_bytes_calldata(_1, _2)
                    fun_applyGovernanceOwners(expr_offset_3, expr_length_3)
                    /// @src 2:26845:26860  "relevant = true"
                    var_relevant := /** @src 2:26856:26860  "true" */ 0x01
                }
                /// @src 2:27073:27124  "if (relevant) lastGovernanceSafeNonce = actionNonce"
                if var_relevant
                {
                    /// @src 2:27087:27124  "lastGovernanceSafeNonce = actionNonce"
                    update_storage_value_offsett_bytes32_to_bytes32_18396(expr_3)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function external_fun_signingPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 2:9126:9160  "address public signingPolicySetter" */ 3), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value0 := abi_decode_uint256()
                let _1 := sload(/** @src 2:90608:90617  "stateData" */ 0x0b)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := and(shr(8, _1), 0xffffffff)
                if /** @src 2:90594:90641  "_timestamp >= stateData.firstVotingRoundStartTs" */ lt(value0, value)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 16)
                    mstore(add(memPtr, 68), "before the start")
                    revert(memPtr, 100)
                }
                /// @src 2:90680:90726  "_timestamp - stateData.firstVotingRoundStartTs"
                let expr := checked_sub_uint256(value0, cleanup_from_storage_uint32(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value))
                /// @src 2:90672:90766  "return (_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds"
                let var := /** @src 2:90679:90766  "(_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds" */ checked_div_uint256(expr, cleanup_from_storage_uint8(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_uint8(_1)))
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256(memPos, var), memPos))
            }
            function abi_encode_bytes(value, pos) -> end
            {
                let length := mload(value)
                mstore(pos, length)
                mcopy(add(pos, 0x20), add(value, 0x20), length)
                mstore(add(add(pos, length), 0x20), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                end := add(add(pos, and(add(length, 31), not(31))), 0x20)
            }
            function external_fun_relay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 2:33640:83692  "assembly {..."
                let usr$memPtr := mload(0x40)
                mstore(add(usr$memPtr, 160), sload(11))
                if lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:33640:83692  "assembly {..." */ 15)
                {
                    usr$revertWithMessage(usr$memPtr)
                }
                calldatacopy(usr$memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4, /** @src 2:33640:83692  "assembly {..." */ 11)
                let _1 := mload(usr$memPtr)
                if lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:33640:83692  "assembly {..." */ add(mul(shr(240, _1), 22), 48))
                {
                    usr$revertWithMessage_18399(usr$memPtr)
                }
                let _2 := usr$calculateSigningPolicyHash_18400(usr$memPtr, add(43, mul(shr(240, _1), 22)))
                mstore(add(usr$memPtr, 0x40), _2)
                mstore(usr$memPtr, and(shr(216, _1), 16777215))
                mstore(add(usr$memPtr, 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                /// @src 2:33640:83692  "assembly {..."
                let _3 := sload(keccak256(usr$memPtr, 0x40))
                mstore(add(usr$memPtr, 96), _3)
                if iszero(eq(_2, _3))
                {
                    usr$revertWithMessage_18401(usr$memPtr)
                }
                calldatacopy(usr$memPtr, add(mul(shr(240, _1), 22), 47), 1)
                let usr$protocolId := shr(248, mload(usr$memPtr))
                let usr$signatureStart := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:33640:83692  "assembly {..."
                let usr$threshold := and(shr(168, _1), 65535)
                if iszero(iszero(usr$protocolId))
                {
                    let usr$memPtrGP0 := mload(0x40)
                    usr$signatureStart := add(mul(shr(240, _1), 22), 85)
                    if lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:33640:83692  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_18402(usr$memPtrGP0)
                    }
                    calldatacopy(usr$memPtrGP0, add(mul(shr(240, _1), 22), 47), 38)
                    let usr$votingRoundId := and(shr(216, mload(usr$memPtrGP0)), 4294967295)
                    mstore(add(usr$memPtrGP0, 96), usr$protocolId)
                    mstore(add(usr$memPtrGP0, 128), 1)
                    mstore(add(usr$memPtrGP0, 128), keccak256(add(usr$memPtrGP0, 96), 0x40))
                    mstore(add(usr$memPtrGP0, 96), usr$votingRoundId)
                    if iszero(iszero(sload(keccak256(add(usr$memPtrGP0, 96), 0x40))))
                    {
                        usr$revertWithMessage_18403(usr$memPtrGP0)
                    }
                    let _4 := eq(usr$protocolId, 1)
                    if _4
                    {
                        if usr$votingRoundId
                        {
                            usr$revertWithMessage_18404(usr$memPtrGP0)
                        }
                        if cleanup_from_storage_uint8(shr(208, mload(usr$memPtrGP0)))
                        {
                            usr$revertWithMessage_18406(usr$memPtrGP0)
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
                        usr$revertWithMessage_18407(usr$memPtrGP0)
                    }
                    let _6 := mload(add(usr$memPtrGP0, 160))
                    if lt(add(usr$messageRewardEpochId, and(shr(192, _6), 4294967295)), and(shr(152, _6), 4294967295))
                    {
                        usr$revertWithMessage_18408(usr$memPtrGP0)
                    }
                    if and(_5, lt(usr$votingRoundId, and(shr(184, _1), 4294967295)))
                    {
                        usr$revertWithMessage_18409(usr$memPtrGP0)
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
                                usr$revertWithMessage_18411(usr$memPtrGP0)
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
                    mstore(usr$memPtrGP0, chainid())
                    mstore(_8, keccak256(usr$memPtrGP0, 0x40))
                }
                if iszero(usr$protocolId)
                {
                    let _9 := mload(0x40)
                    if iszero(iszero(extract_from_storage_value_offsett_bool(mload(add(_9, 160)))))
                    {
                        usr$revertWithMessage_18414(_9)
                    }
                    if lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:33640:83692  "assembly {..." */ add(mul(shr(240, _1), 22), 59))
                    {
                        usr$revertWithMessage_18415(mload(0x40))
                    }
                    calldatacopy(mload(0x40), add(mul(shr(240, _1), 22), 48), 11)
                    let _10 := mload(0x40)
                    let _11 := mload(_10)
                    let _12 := shr(240, _11)
                    if iszero(_12)
                    {
                        usr$revertWithMessage_18416(_10)
                    }
                    if gt(_12, 300)
                    {
                        usr$revertWithMessage_18417(mload(0x40))
                    }
                    let _13 := mul(_12, 22)
                    usr$signatureStart := add(add(mul(shr(240, _1), 22), _13), 91)
                    if lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:33640:83692  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_18418(mload(0x40))
                    }
                    let usr$newSigningPolicyRewardEpochId := and(shr(216, _11), 16777215)
                    let _14 := mload(0x40)
                    let usr$tmpLastInitializedRewardEpochId := extract_from_storage_value_offsett_uint32(mload(add(_14, 160)))
                    if iszero(eq(usr$tmpLastInitializedRewardEpochId, and(shr(216, _1), 16777215)))
                    {
                        usr$revertWithMessage_18420(_14)
                    }
                    if iszero(eq(add(1, usr$tmpLastInitializedRewardEpochId), usr$newSigningPolicyRewardEpochId))
                    {
                        usr$revertWithMessage_18421(mload(0x40))
                    }
                    usr$checkThresholdConsistency(mload(0x40), shr(168, _11), add(mul(shr(240, _1), 22), 48))
                    let usr$newSigningPolicyHash := usr$calculateSigningPolicyHash(mload(0x40), add(mul(shr(240, _1), 22), 48), add(43, _13))
                    let _15 := add(mload(0x40), 160)
                    mstore(_15, usr$assignStruct_18422(mload(_15), usr$newSigningPolicyRewardEpochId))
                    mstore(mload(0x40), usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), 2)
                    let _16 := mload(0x40)
                    sstore(keccak256(_16, 0x40), and(shr(184, _11), 4294967295))
                    mstore(_16, usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                    /// @src 2:33640:83692  "assembly {..."
                    let _17 := mload(0x40)
                    sstore(keccak256(_17, 0x40), usr$newSigningPolicyHash)
                    mstore(add(_17, 32), usr$newSigningPolicyHash)
                    mstore(add(mload(0x40), 96), "SigningPolicyRelayed(uint256)")
                    log2(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, /** @src 2:33640:83692  "assembly {..." */ keccak256(add(mload(0x40), 96), 29), usr$newSigningPolicyRewardEpochId)
                }
                let _18 := add(usr$signatureStart, 2)
                if lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:33640:83692  "assembly {..." */ _18)
                {
                    usr$revertWithMessage_18423(usr$memPtr)
                }
                calldatacopy(add(usr$memPtr, 0x40), usr$signatureStart, 2)
                let _19 := shr(240, mload(add(usr$memPtr, 0x40)))
                mstore(add(usr$memPtr, 256), _18)
                if lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize(), /** @src 2:33640:83692  "assembly {..." */ add(add(usr$signatureStart, mul(_19, 67)), 2))
                {
                    usr$revertWithMessage_18424(usr$memPtr)
                }
                mstore(usr$memPtr, "0000\x19Ethereum Signed Message:\n32")
                mstore(usr$memPtr, keccak256(add(usr$memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4), /** @src 2:33640:83692  "assembly {..." */ 60))
                let usr$i := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:33640:83692  "assembly {..."
                let usr$weight := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:33640:83692  "assembly {..."
                let usr$nextUnusedIndex := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:33640:83692  "assembly {..."
                let usr$memPtrFor := mload(0x40)
                for { } lt(usr$i, _19) { usr$i := add(usr$i, 1) }
                {
                    mstore(add(usr$memPtrFor, 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                    /// @src 2:33640:83692  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 63), add(add(usr$signatureStart, mul(usr$i, 67)), 2), 67)
                    let usr$index := shr(240, mload(add(usr$memPtrFor, 128)))
                    if gt(add(usr$index, 1), shr(240, _1))
                    {
                        usr$revertWithMessage_18425(usr$memPtrFor)
                    }
                    if lt(usr$index, usr$nextUnusedIndex)
                    {
                        usr$revertWithMessage_18426(usr$memPtrFor)
                    }
                    usr$nextUnusedIndex := add(usr$index, 1)
                    let _20 := and(mload(add(usr$memPtrFor, 32)), 0xff)
                    if iszero(or(eq(_20, 27), eq(_20, 28)))
                    {
                        usr$revertWithMessage_18427(usr$memPtrFor)
                    }
                    if gt(mload(add(usr$memPtrFor, 96)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                    {
                        usr$revertWithMessage_18428(usr$memPtrFor)
                    }
                    if iszero(staticcall(/** @src 2:26444:26461  "type(uint256).max" */ not(0), /** @src 2:33640:83692  "assembly {..." */ 1, usr$memPtrFor, 128, add(usr$memPtrFor, 0x40), 32))
                    {
                        usr$revertWithMessage_18429(usr$memPtrFor)
                    }
                    if iszero(eq(returndatasize(), 32))
                    {
                        usr$revertWithMessage_18430(usr$memPtrFor)
                    }
                    if iszero(mload(add(usr$memPtrFor, 0x40)))
                    {
                        usr$revertWithMessage_18431(usr$memPtrFor)
                    }
                    mstore(add(usr$memPtrFor, 96), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0)
                    /// @src 2:33640:83692  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 106), add(47, mul(usr$index, 22)), 22)
                    if iszero(eq(mload(add(usr$memPtrFor, 0x40)), shr(16, mload(add(usr$memPtrFor, 96)))))
                    {
                        usr$revertWithMessage_18432(usr$memPtrFor)
                    }
                    usr$weight := add(usr$weight, and(mload(add(usr$memPtrFor, 96)), 65535))
                    if gt(usr$weight, usr$threshold)
                    {
                        if iszero(usr$protocolId)
                        {
                            sstore(11, mload(add(usr$memPtrFor, 160)))
                            return(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0)
                        }
                        /// @src 2:33640:83692  "assembly {..."
                        if iszero(iszero(usr$protocolId))
                        {
                            let _21 := add(usr$memPtrFor, 192)
                            calldatacopy(_21, add(mul(shr(240, _1), 22), 53), 32)
                            if eq(usr$protocolId, 1)
                            {
                                mstore(usr$memPtrFor, mload(_21))
                                mstore(add(usr$memPtrFor, 32), and(shl(16, _1), shl(232, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 16777215)))
                                /// @src 2:33640:83692  "assembly {..."
                                return(usr$memPtrFor, 35)
                            }
                            if iszero(mload(_21))
                            {
                                usr$revertWithMessage_18433(usr$memPtrFor)
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
                                return(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0)
                            }
                            /// @src 2:33640:83692  "assembly {..."
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
                                    sstore(11, usr$assignStruct(usr$assignStruct_18437(_25, usr$votingRoundId_1), usr$isSecure))
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
                                return(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0)
                            }
                        }
                        /// @src 2:33640:83692  "assembly {..."
                        usr$revertWithMessage_18439(mload(0x40))
                    }
                }
                /// @src 2:83713:83740  "revert(\"Not enough weight\")"
                let _26 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:33640:83692  "assembly {..." */ 0x40)
                /// @src 2:83713:83740  "revert(\"Not enough weight\")"
                mstore(_26, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:83713:83740  "revert(\"Not enough weight\")"
                revert(_26, sub(abi_encode_stringliteral_0d64(add(_26, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4)), /** @src 2:83713:83740  "revert(\"Not enough weight\")" */ _26))
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function external_fun_governanceSafe()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:9403:9451  "address public immutable override governanceSafe" */ loadimmutable("471"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                return(memPos, 32)
            }
            function external_fun_getRandomNumber()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 2:88926:88935  "stateData" */ 0x0b)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := and(shr(112, _1), 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 2:88904:88925  "toRandomNumberPrivate" */ 0x0c)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _2 := sload(keccak256(0, 0x40))
                let cleaned := and(/** @src 2:89105:89138  "stateData.randomVotingRoundId + 1" */ checked_add_uint32(value), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)
                /// @src 2:89018:89190  "_randomTimestamp =..."
                let var__randomTimestamp := /** @src 2:89049:89190  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shr(8, _1), 0xffffffff), /** @src 2:89097:89190  "uint256(stateData.randomVotingRoundId + 1) *..." */ checked_mul_uint256(cleaned, cleanup_from_storage_uint8(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shr(40, _1), 0xff))))
                let memPos := mload(0x40)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, _2, and(shr(144, _1), 0xff), var__randomTimestamp), memPos))
            }
            function external_fun_oldRelay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 2:10730:10762  "IRelay public immutable oldRelay" */ loadimmutable("523"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
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
            /// @ast-id 2941 @src 2:90821:91224  "function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {..."
            function fun_toSigningPolicyHash(var_rewardEpochId) -> var_
            {
                /// @src 2:90897:90904  "bytes32"
                var_ := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:90920:90928  "oldRelay" */ loadimmutable("523"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:90920:90991  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                let expr := /** @src 2:90920:90950  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:90920:90991  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:90954:90991  "_rewardEpochId < initialRewardEpochId" */ lt(var_rewardEpochId, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:90971:90991  "initialRewardEpochId" */ loadimmutable("526"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:90916:91069  "if (oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:91014:91058  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _2 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:91014:91058  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    mstore(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x0c85bf07))
                    /// @src 2:91014:91058  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256(add(_2, 4), var_rewardEpochId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:91014:91058  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 2:91007:91058  "return oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    var_ := expr_1
                    leave
                }
                /// @src 2:91078:91158  "require(signingPolicySetter != address(0), \"no access to signing policy hashes\")"
                require_helper_stringliteral_63a2(/** @src 2:91086:91119  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(cleanup_address_payable(sload(/** @src 2:91086:91105  "signingPolicySetter" */ 0x03)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))))
                /// @src 2:91168:91217  "return toSigningPolicyHashPrivate[_rewardEpochId]"
                var_ := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:91175:91217  "toSigningPolicyHashPrivate[_rewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18441(var_rewardEpochId))
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            function abi_encode_uint256_uint256_18394(value0, value1) -> tail
            {
                tail := 68
                mstore(4, value0)
                mstore(36, value1)
            }
            function abi_encode_uint256_uint256(headStart, value0, value1) -> tail
            {
                tail := add(headStart, 64)
                mstore(headStart, value0)
                mstore(add(headStart, 32), value1)
            }
            /// @ast-id 2687 @src 2:87216:87816  "function isFinalized(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_isFinalized(var__protocolId, var__votingRoundId) -> var
            {
                /// @src 2:87321:87325  "bool"
                var := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:87345:87353  "oldRelay" */ loadimmutable("523"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:87345:87440  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:87345:87375  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:87345:87440  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:87379:87440  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var__votingRoundId, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:87396:87440  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("529"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:87341:87523  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:87463:87512  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _2 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:87463:87512  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(226, 0x0c5eb4cf))
                    /// @src 2:87463:87512  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var__protocolId, var__votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:87463:87512  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bool_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 2:87456:87512  "return oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    var := expr_1
                    leave
                }
                /// @src 2:87741:87809  "return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)"
                var := /** @src 2:87748:87809  "merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:87748:87795  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:87748:87779  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18442(var__protocolId), /** @src 2:87748:87795  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var__votingRoundId))))
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            /// @ast-id 2734 @src 2:87864:88337  "function merkleRoots(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_merkleRoots(var_protocolId, var_votingRoundId) -> var_merkleRoot
            {
                /// @src 2:87969:87988  "bytes32 _merkleRoot"
                var_merkleRoot := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:88008:88016  "oldRelay" */ loadimmutable("523"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:88008:88103  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:88008:88038  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:88008:88103  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:88042:88103  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:88059:88103  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("529"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:88004:88186  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:88126:88175  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _2 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:88126:88175  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(232, 3752811))
                    /// @src 2:88126:88175  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var_protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:88126:88175  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 2:88119:88175  "return oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    var_merkleRoot := expr_1
                    leave
                }
                /// @src 2:88195:88266  "require(signingPolicySetter != address(0), \"no access to merkle roots\")"
                require_helper_stringliteral_1c79(/** @src 2:88203:88236  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(cleanup_address_payable(sload(/** @src 2:88203:88222  "signingPolicySetter" */ 0x03)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))))
                /// @src 2:88276:88330  "return merkleRootsPrivate[_protocolId][_votingRoundId]"
                var_merkleRoot := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:88283:88330  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:88283:88314  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18442(var_protocolId), /** @src 2:88283:88330  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ returndatasize())
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
            function checked_sub_uint256_18456(y) -> diff
            {
                diff := sub(/** @src 2:23196:23198  "20" */ 0x14, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:23196:23198  "20" */ 0x14)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_18458(y) -> diff
            {
                diff := sub(/** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_18461(y) -> diff
            {
                diff := sub(/** @src 2:22425:22426  "2" */ 0x02, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:22425:22426  "2" */ 0x02)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_18521(y) -> diff
            {
                diff := sub(/** @src 2:90187:90190  "255" */ 0xff, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ y)
                if gt(diff, /** @src 2:90187:90190  "255" */ 0xff)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_18646(x) -> diff
            {
                diff := add(x, /** @src 2:26444:26461  "type(uint256).max" */ not(0))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            /// @ast-id 2645 @src 2:83795:87168  "function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)..."
            function fun_verify(var_protocolId, var_votingRoundId, var_leaf, var__proof_offset, var_proof_length) -> var
            {
                /// @src 2:83940:83944  "bool"
                var := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                let _1 := and(/** @src 2:84688:84696  "oldRelay" */ loadimmutable("523"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:84688:84783  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:84688:84718  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:84688:84783  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:84722:84783  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:84739:84783  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("529"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:84684:87140  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                switch expr
                case 0 {
                    /// @src 2:85743:85790  "require(_protocolId > 1, \"invalid protocol id\")"
                    require_helper_stringliteral_44e5(/** @src 2:85751:85766  "_protocolId > 1" */ gt(var_protocolId, /** @src 2:85765:85766  "1" */ 0x01))
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    let _2 := sload(/** @src 2:85818:85847  "protocolFeeInWei[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18444(var_protocolId))
                    /// @src 2:85861:85901  "require(msg.value >= fee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 2:85869:85885  "msg.value >= fee" */ iszero(lt(/** @src 2:85869:85878  "msg.value" */ callvalue(), /** @src 2:85869:85885  "msg.value >= fee" */ _2)))
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    let _3 := sload(/** @src 2:86011:86058  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:86011:86042  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18442(var_protocolId), /** @src 2:86011:86058  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
                    /// @src 2:86072:86116  "require(root != bytes32(0), \"not finalized\")"
                    require_helper_stringliteral(/** @src 2:86080:86098  "root != bytes32(0)" */ iszero(iszero(_3)))
                    /// @src 2:86130:86243  "require(..."
                    require_helper_stringliteral_c04c(/** @src 2:86155:86189  "_proof.verifyCalldata(root, _leaf)" */ fun_verifyCalldata(var__proof_offset, var_proof_length, _3, var_leaf))
                    /// @src 2:86460:86797  "if (fee > 0) {..."
                    if /** @src 2:86464:86471  "fee > 0" */ iszero(iszero(_2))
                    /// @src 2:86460:86797  "if (fee > 0) {..."
                    {
                        /// @src 2:86631:86672  "feeCollectionAddress.call{value: fee}(\"\")"
                        let expr_2604_component := call(gas(), /** @src 2:86631:86656  "feeCollectionAddress.call" */ cleanup_address_payable(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_address_payable(sload(/** @src 2:86631:86651  "feeCollectionAddress" */ 0x05))), /** @src 2:86631:86672  "feeCollectionAddress.call{value: fee}(\"\")" */ _2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, 0, 0)
                        /// @src 2:86631:86672  "feeCollectionAddress.call{value: fee}(\"\")"
                        pop(extract_returndata())
                        /// @src 2:86749:86782  "require(feeOk, \"Transfer failed\")"
                        require_helper_stringliteral_25ad(expr_2604_component)
                    }
                    /// @src 2:86827:86842  "msg.value - fee"
                    let expr_1 := checked_sub_uint256(/** @src 2:85869:85878  "msg.value" */ callvalue(), /** @src 2:86827:86842  "msg.value - fee" */ _2)
                    /// @src 2:86856:87130  "if (refund > 0) {..."
                    if /** @src 2:86860:86870  "refund > 0" */ iszero(iszero(expr_1))
                    /// @src 2:86856:87130  "if (refund > 0) {..."
                    {
                        /// @src 2:86970:87004  "msg.sender.call{value: refund}(\"\")"
                        let expr_2631_component := call(gas(), /** @src 2:86970:86980  "msg.sender" */ caller(), /** @src 2:86970:87004  "msg.sender.call{value: refund}(\"\")" */ expr_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, 0, 0)
                        /// @src 2:86970:87004  "msg.sender.call{value: refund}(\"\")"
                        pop(extract_returndata())
                        /// @src 2:87081:87115  "require(refundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_2631_component)
                    }
                }
                default /// @src 2:84684:87140  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                {
                    /// @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _4 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)"
                    mstore(_4, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x91e7d42f))
                    /// @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _5 := staticcall(gas(), _1, _4, sub(abi_encode_uint256(add(_4, 4), var_protocolId), _4), _4, 32)
                    if iszero(_5) { revert_forward() }
                    let expr_2 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)"
                    if _5
                    {
                        let _6 := 32
                        if gt(32, returndatasize()) { _6 := returndatasize() }
                        finalize_allocation(_4, _6)
                        expr_2 := abi_decode_uint256_fromMemory(_4, add(_4, _6))
                    }
                    /// @src 2:85137:85180  "require(msg.value >= oldFee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 2:85145:85164  "msg.value >= oldFee" */ iszero(lt(/** @src 2:85145:85154  "msg.value" */ callvalue(), /** @src 2:85145:85164  "msg.value >= oldFee" */ expr_2)))
                    /// @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _7 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    mstore(_7, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(225, 0x40428355))
                    /// @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _8 := call(gas(), _1, expr_2, _7, sub(abi_encode_uint256_uint256_bytes32_array_bytes32_dyn_calldata(add(_7, /** @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)" */ 4), /** @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ var_protocolId, var_votingRoundId, var_leaf, var__proof_offset, var_proof_length), _7), _7, /** @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)" */ 32)
                    /// @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if iszero(_8) { revert_forward() }
                    let expr_3 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if _8
                    {
                        let _9 := /** @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)" */ 32
                        /// @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                        if gt(/** @src 2:85085:85123  "oldRelay.protocolFeeInWei(_protocolId)" */ 32, /** @src 2:85204:85278  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ returndatasize()) { _9 := returndatasize() }
                        finalize_allocation(_7, _9)
                        expr_3 := abi_decode_bool_fromMemory(_7, add(_7, _9))
                    }
                    /// @src 2:85292:85336  "require(ok, \"old relay verification failed\")"
                    require_helper_stringliteral_fd5d(expr_3)
                    /// @src 2:85370:85388  "msg.value - oldFee"
                    let expr_4 := checked_sub_uint256(/** @src 2:85145:85154  "msg.value" */ callvalue(), /** @src 2:85370:85388  "msg.value - oldFee" */ expr_2)
                    /// @src 2:85402:85688  "if (oldRefund > 0) {..."
                    if /** @src 2:85406:85419  "oldRefund > 0" */ iszero(iszero(expr_4))
                    /// @src 2:85402:85688  "if (oldRefund > 0) {..."
                    {
                        /// @src 2:85522:85559  "msg.sender.call{value: oldRefund}(\"\")"
                        let expr_2534_component := call(gas(), /** @src 2:85522:85532  "msg.sender" */ caller(), /** @src 2:85522:85559  "msg.sender.call{value: oldRefund}(\"\")" */ expr_4, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, 0, 0, 0)
                        /// @src 2:85522:85559  "msg.sender.call{value: oldRefund}(\"\")"
                        pop(extract_returndata())
                        /// @src 2:85636:85673  "require(oldRefundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_2534_component)
                    }
                    /// @src 2:85701:85712  "return true"
                    var := /** @src 2:85708:85712  "true" */ 0x01
                    /// @src 2:85701:85712  "return true"
                    leave
                }
                /// @src 2:87150:87161  "return true"
                var := /** @src 2:87157:87161  "true" */ 0x01
            }
            /// @ast-id 542 @src 2:11055:11187  "modifier onlySigningPolicySetter() {..."
            function modifier_onlySigningPolicySetter(var_signingPolicy_mpos) -> _1
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(/** @src 2:11108:11141  "msg.sender == signingPolicySetter" */ eq(/** @src 2:11108:11118  "msg.sender" */ caller(), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(sload(/** @src 2:11122:11141  "signingPolicySetter" */ 0x03), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 23)
                    mstore(add(memPtr, 68), "only sign policy setter")
                    revert(memPtr, 100)
                }
                /// @src 2:19077:19117  "stateData.lastInitializedRewardEpoch + 1"
                let expr := checked_add_uint32(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_uint32(sload(/** @src 2:19077:19086  "stateData" */ 0x0b)))
                /// @src 2:19056:19196  "require(..."
                require_helper_stringliteral_d084(/** @src 2:19077:19149  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ eq(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:19077:19149  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ expr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), /** @src 2:19077:19149  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ cleanup_uint24(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:19121:19149  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))))
                /// @src 2:20050:20114  "require(_signingPolicy.voters.length > 0, \"must be non-trivial\")"
                require_helper_stringliteral_aacd(/** @src 2:20058:20090  "_signingPolicy.voters.length > 0" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ mload(add(var_signingPolicy_mpos, 128))))))
                /// @src 2:20124:20194  "require(_signingPolicy.voters.length <= MAX_VOTERS, \"too many voters\")"
                require_helper_stringliteral_d1bc(/** @src 2:20132:20174  "_signingPolicy.voters.length <= MAX_VOTERS" */ iszero(gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:20132:20153  "_signingPolicy.voters" */ mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))), /** @src 2:2993:2996  "300" */ 0x012c)))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let length := mload(/** @src 2:20212:20233  "_signingPolicy.voters" */ mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))
                /// @src 2:20204:20291  "require(_signingPolicy.voters.length == _signingPolicy.weights.length, \"size mismatch\")"
                require_helper_stringliteral_6b32(/** @src 2:20212:20273  "_signingPolicy.voters.length == _signingPolicy.weights.length" */ eq(length, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:20244:20266  "_signingPolicy.weights" */ mload(add(var_signingPolicy_mpos, 160)))))
                /// @src 2:20301:20324  "uint256 totalWeight = 0"
                let var_totalWeight := /** @src -1:-1:-1 */ 0
                /// @src 2:20339:20352  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:20334:20459  "for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {..."
                for { }
                /** @src 2:19116:19117  "1" */ 0x01
                /// @src 2:20339:20352  "uint256 i = 0"
                {
                    /// @src 2:20389:20392  "i++"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:20389:20392  "i++" */ var_i, /** @src 2:19116:19117  "1" */ 0x01)
                }
                /// @src 2:20389:20392  "i++"
                {
                    /// @src 2:20358:20380  "_signingPolicy.weights"
                    let _mpos := mload(/** @src 2:20244:20266  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                    /// @src 2:20354:20387  "i < _signingPolicy.weights.length"
                    if iszero(lt(var_i, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:20358:20387  "_signingPolicy.weights.length" */ _mpos)))
                    /// @src 2:20354:20387  "i < _signingPolicy.weights.length"
                    { break }
                    /// @src 2:20408:20448  "totalWeight += _signingPolicy.weights[i]"
                    var_totalWeight := checked_add_uint256(var_totalWeight, cleanup_from_storage_uint16(/** @src 2:20423:20448  "_signingPolicy.weights[i]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos, var_i))))
                }
                /// @src 2:20468:20520  "require(totalWeight < 2**16, \"total weight too big\")"
                require_helper_stringliteral_f10c(/** @src 2:20476:20495  "totalWeight < 2**16" */ lt(var_totalWeight, /** @src 2:20490:20495  "2**16" */ 0x010000))
                /// @src 2:20551:20610  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_1 := checked_mul_uint256_18447(/** @src 2:20551:20584  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:20559:20583  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 2:20530:20691  "require(..."
                require_helper_stringliteral_d8d1(/** @src 2:20551:20646  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS" */ iszero(lt(expr_1, /** @src 2:20614:20646  "totalWeight * MIN_THRESHOLD_BIPS" */ checked_mul_uint256_18448(var_totalWeight))))
                /// @src 2:20722:20781  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_2 := checked_mul_uint256_18447(/** @src 2:20722:20755  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:20559:20583  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 2:20701:20860  "require(..."
                require_helper_stringliteral_185c(/** @src 2:20722:20817  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS" */ iszero(gt(expr_2, /** @src 2:20785:20817  "totalWeight * MAX_THRESHOLD_BIPS" */ checked_mul_uint256_18450(var_totalWeight))))
                /// @src 2:20905:21055  "new bytes(..."
                let expr_mpos := allocate_and_zero_memory_array_bytes(/** @src 2:20928:21045  "SIGNING_POLICY_PREFIX_BYTES +..." */ checked_add_uint256_18452(/** @src 2:20974:21045  "_signingPolicy.voters.length *..." */ checked_mul_uint256_18451(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:20974:20995  "_signingPolicy.voters" */ mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))))
                /// @src 2:21066:21083  "Counters memory m"
                let zero_struct_Counters_mpos := /** @src 2:4462:4464  "22" */ allocate_and_zero_memory_struct_struct_Counters()
                /// @src 2:21399:21420  "_signingPolicy.voters"
                let _mpos_1 := mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 2:21385:21429  "bytes2(uint16(_signingPolicy.voters.length))"
                let expr_3 := convert_uint16_to_bytes2(/** @src 2:21392:21428  "uint16(_signingPolicy.voters.length)" */ cleanup_from_storage_uint16(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:21399:21427  "_signingPolicy.voters.length" */ _mpos_1)))
                /// @src 2:21443:21479  "bytes3(_signingPolicy.rewardEpochId)"
                let expr_4 := convert_uint24_to_bytes3(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:21450:21478  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))
                /// @src 2:21493:21534  "bytes4(_signingPolicy.startVotingRoundId)"
                let expr_5 := convert_uint32_to_bytes4(/** @src 2:4462:4464  "22" */ cleanup_from_storage_uint32(mload(/** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32))))
                /// @src 2:21548:21580  "bytes2(_signingPolicy.threshold)"
                let expr_6 := convert_uint16_to_bytes2(/** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:20559:20583  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64))))
                /// @src 2:4462:4464  "22"
                let _2 := mload(/** @src 2:21610:21629  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 2:21645:21678  "bytes20(_signingPolicy.voters[0])"
                let expr_7 := convert_address_to_bytes20(/** @src 2:21653:21677  "_signingPolicy.voters[0]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn_18453(_mpos_1)))
                /// @src 2:21359:21747  "bytes.concat(..."
                let expr_mpos_1 := bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(expr_3, expr_4, expr_5, expr_6, _2, expr_7, /** @src 2:21692:21737  "bytes1(uint8(_signingPolicy.weights[0] >> 8))" */ convert_uint8_to_bytes1(/** @src 2:21699:21736  "uint8(_signingPolicy.weights[0] >> 8)" */ cleanup_from_storage_uint8(/** @src 2:21705:21735  "_signingPolicy.weights[0] >> 8" */ shift_right_uint16_uint8(/** @src 2:21705:21730  "_signingPolicy.weights[0]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn_18453(/** @src 2:21705:21727  "_signingPolicy.weights" */ mload(/** @src 2:20244:20266  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))))))))
                /// @src 2:21758:21904  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                for { }
                /** @src 2:19116:19117  "1" */ 0x01
                /// @src 2:21758:21904  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                {
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:21790:21808  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 2:21790:21810  "m.signingPolicyPos++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:21790:21808  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                }
                /// @src 2:21790:21810  "m.signingPolicyPos++"
                {
                    /// @src 2:4462:4464  "22"
                    let _3 := mload(/** @src 2:21790:21808  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 2:21765:21788  "m.signingPolicyPos < 64"
                    if iszero(lt(_3, /** @src 2:20559:20583  "_signingPolicy.threshold" */ 64))
                    /// @src 2:21765:21788  "m.signingPolicyPos < 64"
                    { break }
                    /// @src 2:21867:21893  "toHash[m.signingPolicyPos]"
                    let _4 := read_from_memoryt_bytes1(memory_array_index_access_bytes(expr_mpos_1, /** @src 2:4462:4464  "22" */ _3))
                    let _5 := mload(/** @src 2:21790:21808  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 2:21826:21893  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]"
                    mstore8(memory_array_index_access_bytes(expr_mpos, _5), byte(/** @src -1:-1:-1 */ 0, /** @src 2:21826:21893  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]" */ _4))
                }
                /// @src 2:21914:21953  "bytes32 currentHash = keccak256(toHash)"
                let var_currentHash := /** @src 2:21936:21953  "keccak256(toHash)" */ keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:21936:21953  "keccak256(toHash)" */ expr_mpos_1, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:21936:21953  "keccak256(toHash)" */ expr_mpos_1))
                /// @src 2:4462:4464  "22"
                mstore(zero_struct_Counters_mpos, /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:21991:22002  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:19116:19117  "1" */ 0x01)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:22016:22028  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:20559:20583  "_signingPolicy.threshold" */ 64), /** @src 2:19116:19117  "1" */ 0x01)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:22042:22052  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:21610:21629  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                /// @src 2:22067:24273  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                for { }
                /** @src 2:19116:19117  "1" */ 0x01
                /// @src 2:22067:24273  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                { }
                {
                    /// @src 2:4462:4464  "22"
                    let _6 := mload(/** @src 2:22074:22087  "m.weightIndex" */ zero_struct_Counters_mpos)
                    /// @src 2:22074:22118  "m.weightIndex < _signingPolicy.voters.length"
                    if iszero(lt(_6, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:22090:22111  "_signingPolicy.voters" */ mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))))
                    /// @src 2:22074:22118  "m.weightIndex < _signingPolicy.voters.length"
                    { break }
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128), /** @src -1:-1:-1 */ 0)
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:22159:22169  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src -1:-1:-1 */ 0)
                    /// @src 2:4462:4464  "22"
                    mstore(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160), /** @src -1:-1:-1 */ 0)
                    /// @src 2:22236:23946  "while (..."
                    for { }
                    /** @src 2:19116:19117  "1" */ 0x01
                    /// @src 2:22236:23946  "while (..."
                    { }
                    {
                        /// @src 2:22260:22320  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        let expr_8 := /** @src 2:22260:22272  "m.count < 32" */ lt(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128)), /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32)
                        /// @src 2:22260:22320  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if expr_8
                        {
                            /// @src 2:4462:4464  "22"
                            let _7 := mload(/** @src 2:22276:22289  "m.weightIndex" */ zero_struct_Counters_mpos)
                            /// @src 2:22260:22320  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                            expr_8 := /** @src 2:22276:22320  "m.weightIndex < _signingPolicy.voters.length" */ lt(_7, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:22292:22313  "_signingPolicy.voters" */ mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))
                        }
                        /// @src 2:22260:22320  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if iszero(expr_8) { break }
                        /// @src 2:4462:4464  "22"
                        let _8 := mload(/** @src 2:22357:22370  "m.weightIndex" */ zero_struct_Counters_mpos)
                        /// @src 2:22353:23890  "if (m.weightIndex < m.voterIndex) {..."
                        switch /** @src 2:22357:22385  "m.weightIndex < m.voterIndex" */ lt(_8, /** @src 2:4462:4464  "22" */ mload(/** @src 2:22016:22028  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:20559:20583  "_signingPolicy.threshold" */ 64)))
                        case /** @src 2:22353:23890  "if (m.weightIndex < m.voterIndex) {..." */ 0 {
                            /// @src 2:4462:4464  "22"
                            mstore(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160), /** @src 2:23196:23211  "20 - m.voterPos" */ checked_sub_uint256_18456(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22042:22052  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:21610:21629  "_signingPolicy.seed" */ 96))))
                            /// @src 2:4462:4464  "22"
                            let _9 := mload(/** @src 2:22042:22052  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:21610:21629  "_signingPolicy.seed" */ 96))
                            /// @src 2:23233:23238  "m.pos"
                            let _10 := add(zero_struct_Counters_mpos, 224)
                            /// @src 2:4462:4464  "22"
                            mstore(_10, _9)
                            /// @src 2:23342:23363  "_signingPolicy.voters"
                            let _mpos_2 := mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                            /// @src 2:23326:23419  "uint256(uint160(_signingPolicy.voters[m.voterIndex])) <<..."
                            let _11 := shift_left_uint256_uint8_18457(/** @src 2:23326:23379  "uint256(uint160(_signingPolicy.voters[m.voterIndex]))" */ cleanup_address_payable(/** @src 2:23334:23378  "uint160(_signingPolicy.voters[m.voterIndex])" */ cleanup_address_payable(/** @src 2:23342:23377  "_signingPolicy.voters[m.voterIndex]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(_mpos_2, /** @src 2:4462:4464  "22" */ mload(/** @src 2:22016:22028  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:20559:20583  "_signingPolicy.threshold" */ 64)))))))
                            /// @src 2:4462:4464  "22"
                            let _12 := mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128))
                            /// @src 2:23463:23736  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 2:23467:23495  "m.count + m.bytesToTake > 32" */ gt(/** @src 2:23467:23490  "m.count + m.bytesToTake" */ checked_add_uint256(_12, /** @src 2:4462:4464  "22" */ mload(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160))), /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 2:23463:23736  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:22042:22052  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:21610:21629  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:22016:22028  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:20559:20583  "_signingPolicy.threshold" */ 64), /** @src 2:23699:23713  "m.voterIndex++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22016:22028  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 2:20559:20583  "_signingPolicy.threshold" */ 64))))
                            }
                            default /// @src 2:23463:23736  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 2:23539:23551  "32 - m.count"
                                let _13 := checked_sub_uint256_18458(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128)))
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160), /** @src 2:4462:4464  "22" */ _13)
                                mstore(/** @src 2:22042:22052  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:21610:21629  "_signingPolicy.seed" */ 96), /** @src 2:23577:23604  "m.voterPos += m.bytesToTake" */ checked_add_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22042:22052  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 2:21610:21629  "_signingPolicy.seed" */ 96)), /** @src 2:4462:4464  "22" */ _13))
                            }
                            mstore(/** @src 2:22159:22169  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 2:23757:23871  "m.nextSlot |= bytes32(..." */ or(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22159:22169  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shr(/** @src 2:23836:23847  "8 * m.count" */ checked_mul_uint256_18459(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128))), /** @src 2:4462:4464  "22" */ shl(/** @src 2:23820:23829  "8 * m.pos" */ checked_mul_uint256_18459(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23824:23829  "m.pos" */ _10)), /** @src 2:4462:4464  "22" */ _11))))
                        }
                        default /// @src 2:22353:23890  "if (m.weightIndex < m.voterIndex) {..."
                        {
                            /// @src 2:4462:4464  "22"
                            mstore(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160), /** @src 2:22425:22440  "2 - m.weightPos" */ checked_sub_uint256_18461(/** @src 2:4462:4464  "22" */ mload(/** @src 2:21991:22002  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32))))
                            /// @src 2:4462:4464  "22"
                            let _14 := mload(/** @src 2:21991:22002  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 2:22462:22467  "m.pos"
                            let _15 := add(zero_struct_Counters_mpos, 224)
                            /// @src 2:4462:4464  "22"
                            mstore(_15, _14)
                            /// @src 2:22601:22623  "_signingPolicy.weights"
                            let _mpos_3 := mload(/** @src 2:20244:20266  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                            /// @src 2:22557:22677  "uint256(..."
                            let _16 := shift_left_uint256_uint8(/** @src 2:22557:22665  "uint256(..." */ cleanup_from_storage_uint16(/** @src 2:22601:22638  "_signingPolicy.weights[m.weightIndex]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos_3, /** @src 2:4462:4464  "22" */ mload(/** @src 2:22624:22637  "m.weightIndex" */ zero_struct_Counters_mpos)))))
                            /// @src 2:4462:4464  "22"
                            let _17 := mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128))
                            /// @src 2:22721:22997  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 2:22725:22753  "m.count + m.bytesToTake > 32" */ gt(/** @src 2:22725:22748  "m.count + m.bytesToTake" */ checked_add_uint256(_17, /** @src 2:4462:4464  "22" */ mload(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160))), /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 2:22721:22997  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:21991:22002  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32), /** @src -1:-1:-1 */ 0)
                                /// @src 2:4462:4464  "22"
                                mstore(zero_struct_Counters_mpos, /** @src 2:22959:22974  "m.weightIndex++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22959:22974  "m.weightIndex++" */ zero_struct_Counters_mpos)))
                            }
                            default /// @src 2:22721:22997  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 2:22797:22809  "32 - m.count"
                                let _18 := checked_sub_uint256_18458(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128)))
                                /// @src 2:4462:4464  "22"
                                mstore(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160), /** @src 2:4462:4464  "22" */ _18)
                                mstore(/** @src 2:21991:22002  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:22835:22863  "m.weightPos += m.bytesToTake" */ checked_add_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:21991:22002  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32)), /** @src 2:4462:4464  "22" */ _18))
                            }
                            mstore(/** @src 2:22159:22169  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 2:23018:23133  "m.nextSlot |= bytes32(..." */ or(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22159:22169  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shr(/** @src 2:23098:23109  "8 * m.count" */ checked_mul_uint256_18459(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128))), /** @src 2:4462:4464  "22" */ shl(/** @src 2:23082:23091  "8 * m.pos" */ checked_mul_uint256_18459(/** @src 2:4462:4464  "22" */ mload(/** @src 2:23086:23091  "m.pos" */ _15)), /** @src 2:4462:4464  "22" */ _16))))
                        }
                        mstore(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128), /** @src 2:23907:23931  "m.count += m.bytesToTake" */ checked_add_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128)), /** @src 2:4462:4464  "22" */ mload(/** @src 2:22205:22218  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 2:20244:20266  "_signingPolicy.weights" */ 160))))
                    }
                    /// @src 2:23959:24263  "if (m.count > 0) {..."
                    if /** @src 2:23963:23974  "m.count > 0" */ iszero(iszero(/** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128))))
                    /// @src 2:23959:24263  "if (m.count > 0) {..."
                    {
                        /// @src 2:24018:24055  "bytes.concat(currentHash, m.nextSlot)"
                        let expr_mpos_2 := bytes_concat_bytes32_bytes32(var_currentHash, /** @src 2:4462:4464  "22" */ mload(/** @src 2:22159:22169  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)))
                        /// @src 2:23994:24056  "currentHash = keccak256(bytes.concat(currentHash, m.nextSlot))"
                        var_currentHash := /** @src 2:24008:24056  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:24008:24056  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:24008:24056  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2))
                        /// @src 2:24079:24092  "uint256 i = 0"
                        let var_i_1 := /** @src -1:-1:-1 */ 0
                        /// @src 2:24074:24249  "for (uint256 i = 0; i < m.count; i++) {..."
                        for { }
                        /** @src 2:19116:19117  "1" */ 0x01
                        /// @src 2:24079:24092  "uint256 i = 0"
                        {
                            /// @src 2:24107:24110  "i++"
                            var_i_1 := /** @src 2:2993:2996  "300" */ add(/** @src 2:24107:24110  "i++" */ var_i_1, /** @src 2:19116:19117  "1" */ 0x01)
                        }
                        /// @src 2:24107:24110  "i++"
                        {
                            /// @src 2:24094:24105  "i < m.count"
                            if iszero(lt(var_i_1, /** @src 2:4462:4464  "22" */ mload(/** @src 2:22134:22141  "m.count" */ add(zero_struct_Counters_mpos, /** @src 2:20058:20079  "_signingPolicy.voters" */ 128))))
                            /// @src 2:24094:24105  "i < m.count"
                            { break }
                            /// @src 2:4462:4464  "22"
                            let _19 := mload(/** @src 2:22159:22169  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192))
                            /// @src 2:24175:24188  "m.nextSlot[i]"
                            if iszero(lt(var_i_1, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 2:24175:24188  "m.nextSlot[i]"
                            { panic_error_0x32() }
                            /// @src 2:24134:24188  "signingPolicyBytes[m.signingPolicyPos] = m.nextSlot[i]"
                            mstore8(memory_array_index_access_bytes(expr_mpos, /** @src 2:4462:4464  "22" */ mload(/** @src 2:21790:21808  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))), /** @src 2:24175:24188  "m.nextSlot[i]" */ byte(var_i_1, _19))
                            /// @src 2:4462:4464  "22"
                            mstore(/** @src 2:21790:21808  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 2:24210:24230  "m.signingPolicyPos++" */ increment_uint256(/** @src 2:4462:4464  "22" */ mload(/** @src 2:21790:21808  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                        }
                    }
                }
                /// @src 2:24659:24703  "abi.encodePacked(block.chainid, currentHash)"
                let expr_mpos_3 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:20559:20583  "_signingPolicy.threshold" */ 64)
                /// @src 2:24659:24703  "abi.encodePacked(block.chainid, currentHash)"
                let _20 := add(expr_mpos_3, /** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 2:24659:24703  "abi.encodePacked(block.chainid, currentHash)"
                let _21 := sub(abi_encode_packed_uint256_bytes32(_20, /** @src 2:24676:24689  "block.chainid" */ chainid(), /** @src 2:24659:24703  "abi.encodePacked(block.chainid, currentHash)" */ var_currentHash), expr_mpos_3)
                mstore(expr_mpos_3, add(_21, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:24659:24703  "abi.encodePacked(block.chainid, currentHash)"
                finalize_allocation(expr_mpos_3, _21)
                /// @src 2:24649:24704  "keccak256(abi.encodePacked(block.chainid, currentHash))"
                let expr_9 := keccak256(/** @src 2:4462:4464  "22" */ _20, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:24649:24704  "keccak256(abi.encodePacked(block.chainid, currentHash))" */ expr_mpos_3))
                /// @src 2:4462:4464  "22"
                sstore(/** @src 2:24714:24770  "toSigningPolicyHashPrivate[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24_18466(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:24741:24769  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))), /** @src 2:4462:4464  "22" */ expr_9)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _22 := cleanup_uint24(mload(/** @src 2:24833:24861  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 2:24794:24861  "stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId"
                update_storage_value_offsett_uint32_to_uint32(cleanup_uint24(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _22))
                /// @src 2:4462:4464  "22"
                sstore(/** @src 2:24871:24923  "startingVotingRoundIds[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _22), /** @src 2:24871:24959  "startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy.startVotingRoundId" */ cleanup_from_storage_uint32(/** @src 2:4462:4464  "22" */ cleanup_from_storage_uint32(mload(/** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))))
                /// @src 2:25012:25040  "_signingPolicy.rewardEpochId"
                let _23 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_uint24(mload(/** @src 2:25012:25040  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 2:25054:25087  "_signingPolicy.startVotingRoundId"
                let _24 := /** @src 2:4462:4464  "22" */ cleanup_from_storage_uint32(mload(/** @src 2:21500:21533  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))
                /// @src 2:25101:25125  "_signingPolicy.threshold"
                let _25 := /** @src 2:2993:2996  "300" */ cleanup_from_storage_uint16(mload(/** @src 2:20559:20583  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))
                /// @src 2:4462:4464  "22"
                let _26 := mload(/** @src 2:21610:21629  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 2:25172:25193  "_signingPolicy.voters"
                let _mpos_4 := mload(/** @src 2:20058:20079  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 2:25207:25229  "_signingPolicy.weights"
                let _mpos_5 := mload(/** @src 2:20244:20266  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                /// @src 2:24974:25308  "SigningPolicyInitialized(..."
                let _27 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:20559:20583  "_signingPolicy.threshold" */ 64)
                /// @src 2:24974:25308  "SigningPolicyInitialized(..."
                log2(_27, sub(abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(_27, _24, _25, _26, _mpos_4, _mpos_5, expr_mpos, /** @src 2:4462:4464  "22" */ and(/** @src 2:25282:25297  "block.timestamp" */ timestamp(), /** @src 2:4462:4464  "22" */ 0xffffffffffffffff)), /** @src 2:24974:25308  "SigningPolicyInitialized(..." */ _27), 0x91d0280e969157fc6c5b8f952f237b03d934b18534dafcac839075bbc33522f8, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:24974:25308  "SigningPolicyInitialized(..." */ _23, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffff))
                /// @src 2:11179:11180  "_"
                _1 := expr_9
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                    let memPtr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2993:2996  "300"
                    mstore(memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:2993:2996  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:2993:2996  "300" */ add(memPtr, 36), 15)
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:2993:2996  "300" */ memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:2993:2996  "300" */ "too many voters")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_6b32(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2993:2996  "300"
                    mstore(memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:2993:2996  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:2993:2996  "300" */ add(memPtr, 36), 13)
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:2993:2996  "300" */ memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:2993:2996  "300" */ "size mismatch")
                    revert(memPtr, 100)
                }
            }
            function panic_error_0x32()
            {
                mstore(0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(224, 0x4e487b71))
                /// @src 2:2993:2996  "300"
                mstore(4, 0x32)
                revert(0, 0x24)
            }
            function memory_array_index_access_uint16_dyn_18453(baseRef) -> addr
            {
                if iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:2993:2996  "300" */ baseRef)) { panic_error_0x32() }
                addr := add(baseRef, 32)
            }
            function memory_array_index_access_uint16_dyn(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:2993:2996  "300" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, shl(5, index)), 32)
            }
            function read_from_memoryt_uint16(ptr) -> returnValue
            {
                returnValue := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:2993:2996  "300" */ mload(ptr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff)
            }
            /// @src 2:2993:2996  "300"
            function checked_add_uint256_18393(x) -> sum
            {
                sum := add(x, /** @src 2:26495:26496  "1" */ 0x01)
                /// @src 2:2993:2996  "300"
                if gt(x, sum) { panic_error_0x11() }
            }
            function checked_add_uint256_18452(y) -> sum
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
                    let memPtr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:2993:2996  "300"
                    mstore(memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:2993:2996  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:2993:2996  "300" */ add(memPtr, 36), 20)
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:2993:2996  "300" */ memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:2993:2996  "300" */ "total weight too big")
                    revert(memPtr, 100)
                }
            }
            /// @src 2:2895:2900  "10000"
            function checked_mul_uint256_18447(x) -> product
            {
                product := mul(x, 0x2710)
                if iszero(or(iszero(x), eq(0x2710, div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_18448(x) -> product
            {
                product := mul(x, /** @src 2:3048:3052  "5000" */ 0x1388)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:3048:3052  "5000" */ 0x1388, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_18450(x) -> product
            {
                product := mul(x, /** @src 2:3104:3108  "6600" */ 0x19c8)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:3104:3108  "6600" */ 0x19c8, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_18451(x) -> product
            {
                product := mul(x, /** @src 2:4462:4464  "22" */ 0x16)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:4462:4464  "22" */ 0x16, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_18459(y) -> product
            {
                product := shl(3, y)
                if iszero(eq(y, and(y, sub(shl(253, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 1), 1))))
                /// @src 2:2895:2900  "10000"
                { panic_error_0x11() }
            }
            function checked_mul_uint256_18621(x) -> product
            {
                product := mul(x, /** @src 2:27587:27589  "65" */ 0x41)
                /// @src 2:2895:2900  "10000"
                if iszero(or(iszero(x), eq(/** @src 2:27587:27589  "65" */ 0x41, /** @src 2:2895:2900  "10000" */ div(product, x)))) { panic_error_0x11() }
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
                    let memPtr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:3048:3052  "5000"
                    mstore(memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:3048:3052  "5000"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:3048:3052  "5000" */ add(memPtr, 36), 19)
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:3048:3052  "5000" */ memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:3048:3052  "5000" */ "too small threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 2:3104:3108  "6600"
            function require_helper_stringliteral_185c(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:3104:3108  "6600"
                    mstore(memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:3104:3108  "6600"
                    mstore(add(memPtr, 4), 32)
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src 2:3104:3108  "6600" */ add(memPtr, 36), 17)
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(/** @src 2:3104:3108  "6600" */ memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 68), /** @src 2:3104:3108  "6600" */ "too big threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 2:4462:4464  "22"
            function allocate_and_zero_memory_array_bytes(length) -> memPtr
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := array_allocation_size_bytes(length)
                let memPtr_1 := mload(64)
                finalize_allocation(memPtr_1, _1)
                mstore(memPtr_1, length)
                /// @src 2:4462:4464  "22"
                memPtr := memPtr_1
                calldatacopy(add(memPtr_1, 32), calldatasize(), add(array_allocation_size_bytes(length), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
            }
            /// @src 2:4462:4464  "22"
            function allocate_and_zero_memory_struct_struct_Counters() -> memPtr
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let memPtr_1 := mload(64)
                let newFreePtr := add(memPtr_1, /** @src 2:4462:4464  "22" */ 288)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1)) { panic_error_0x41() }
                mstore(64, newFreePtr)
                /// @src 2:4462:4464  "22"
                memPtr := memPtr_1
                mstore(memPtr_1, /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, 32), /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                mstore(add(memPtr_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src -1:-1:-1 */ 0)
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
                converted := and(shl(232, value), /** @src 2:33640:83692  "assembly {..." */ shl(232, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 16777215))
            }
            /// @src 2:4462:4464  "22"
            function convert_uint32_to_bytes4(value) -> converted
            {
                converted := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shl(224, /** @src 2:4462:4464  "22" */ value), shl(224, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            }
            /// @src 2:4462:4464  "22"
            function read_from_memoryt_address(ptr) -> returnValue
            {
                returnValue := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:4462:4464  "22" */ mload(ptr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
            }
            /// @src 2:4462:4464  "22"
            function convert_address_to_bytes20(value) -> converted
            {
                converted := and(shl(96, value), not(0xffffffffffffffffffffffff))
            }
            function shift_right_uint16_uint8(value) -> result
            {
                result := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(shr(8, /** @src 2:4462:4464  "22" */ value), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xff)
            }
            /// @src 2:4462:4464  "22"
            function convert_uint8_to_bytes1(value) -> converted
            {
                converted := and(shl(248, value), shl(248, 255))
            }
            function bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(param, param_1, param_2, param_3, param_4, param_5, param_6) -> outPtr
            {
                outPtr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 0x20), and(param, shl(240, 65535)))
                mstore(add(outPtr, 34), and(param_1, /** @src 2:33640:83692  "assembly {..." */ shl(232, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 16777215)))
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 37), and(param_2, shl(224, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 41), and(param_3, shl(240, 65535)))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 2:4462:4464  "22" */ add(outPtr, 43), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ param_4)
                /// @src 2:4462:4464  "22"
                mstore(add(outPtr, 75), and(param_5, not(0xffffffffffffffffffffffff)))
                mstore(add(outPtr, 95), and(param_6, shl(248, 255)))
                mstore(outPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)
                /// @src 2:4462:4464  "22"
                finalize_allocation(outPtr, 96)
            }
            function increment_uint256(value) -> ret
            {
                if eq(value, /** @src 2:26444:26461  "type(uint256).max" */ not(0))
                /// @src 2:4462:4464  "22"
                { panic_error_0x11() }
                ret := add(value, 1)
            }
            function memory_array_index_access_bytes(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:4462:4464  "22" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, index), 32)
            }
            function read_from_memoryt_bytes1(ptr) -> returnValue
            {
                returnValue := and(mload(ptr), shl(248, 255))
            }
            function shift_left_uint256_uint8_18457(value) -> result
            {
                result := shl(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 96, /** @src 2:4462:4464  "22" */ value)
            }
            function shift_left_uint256_uint8(value) -> result
            {
                result := shl(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 240, /** @src 2:4462:4464  "22" */ value)
            }
            function bytes_concat_bytes32_bytes32(param, param_1) -> outPtr
            {
                outPtr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                mstore(/** @src 2:4462:4464  "22" */ add(outPtr, 0x20), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ param)
                mstore(/** @src 2:4462:4464  "22" */ add(outPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), param_1)
                /// @src 2:4462:4464  "22"
                mstore(outPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)
                /// @src 2:4462:4464  "22"
                finalize_allocation(outPtr, 96)
            }
            function abi_encode_packed_uint256_bytes32(pos, value0, value1) -> end
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(pos, value0)
                mstore(/** @src 2:4462:4464  "22" */ add(pos, 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                /// @src 2:4462:4464  "22"
                end := add(pos, 64)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24_18466(key) -> dataSlot
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:4462:4464  "22" */ key, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffff))
                /// @src 2:4462:4464  "22"
                mstore(0x20, /** @src -1:-1:-1 */ 0)
                /// @src 2:4462:4464  "22"
                dataSlot := keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:4462:4464  "22" */ 0x40)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24(key) -> dataSlot
            {
                mstore(0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:4462:4464  "22" */ key, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffff))
                /// @src 2:4462:4464  "22"
                mstore(0x20, /** @src 2:24871:24893  "startingVotingRoundIds" */ 0x02)
                /// @src 2:4462:4464  "22"
                dataSlot := keccak256(0, 0x40)
            }
            function update_storage_value_offsett_bytes32_to_bytes32_18396(value)
            {
                sstore(/** @src 2:26588:26611  "lastGovernanceSafeNonce" */ 0x07, /** @src 2:4462:4464  "22" */ value)
            }
            function update_storage_value_offsett_bytes32_to_bytes32_18636(value)
            {
                sstore(/** @src 2:30005:30036  "governanceThreshold = threshold" */ 0x08, /** @src 2:4462:4464  "22" */ value)
            }
            function update_storage_value_offsett_bytes32_to_bytes32(value)
            {
                sstore(/** @src 2:29492:29513  "activeOwnerConfigHash" */ 0x06, /** @src 2:4462:4464  "22" */ value)
            }
            function update_storage_value_offsett_uint32_to_uint32(value)
            {
                let _1 := sload(/** @src 2:19077:19086  "stateData" */ 0x0b)
                /// @src 2:4462:4464  "22"
                sstore(/** @src 2:19077:19086  "stateData" */ 0x0b, /** @src 2:4462:4464  "22" */ or(and(_1, not(shl(152, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:4462:4464  "22" */ and(shl(152, value), shl(152, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))))
            }
            /// @src 2:4462:4464  "22"
            function abi_encode_array_address_dyn(value, pos) -> end
            {
                let length := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:4462:4464  "22" */ value)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(pos, length)
                /// @src 2:4462:4464  "22"
                pos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(pos, 0x20)
                /// @src 2:4462:4464  "22"
                let srcPtr := add(value, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
                /// @src 2:4462:4464  "22"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 2:4462:4464  "22"
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(pos, and(/** @src 2:4462:4464  "22" */ mload(srcPtr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    /// @src 2:4462:4464  "22"
                    pos := add(pos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
                    /// @src 2:4462:4464  "22"
                    srcPtr := add(srcPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, and(value0, 0xffffffff))
                mstore(/** @src 2:4462:4464  "22" */ add(headStart, 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value1, 0xffff))
                mstore(/** @src 2:4462:4464  "22" */ add(headStart, 64), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value2)
                /// @src 2:4462:4464  "22"
                mstore(add(headStart, 96), 224)
                let tail_1 := abi_encode_array_address_dyn(value3, add(headStart, 224))
                mstore(add(headStart, 128), sub(tail_1, headStart))
                let pos := tail_1
                let length := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:4462:4464  "22" */ value4)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(tail_1, length)
                /// @src 2:4462:4464  "22"
                pos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ add(tail_1, /** @src 2:4462:4464  "22" */ 32)
                let srcPtr := add(value4, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(pos, and(/** @src 2:4462:4464  "22" */ mload(srcPtr), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffff))
                    /// @src 2:4462:4464  "22"
                    pos := add(pos, 32)
                    srcPtr := add(srcPtr, 32)
                }
                mstore(add(headStart, 160), sub(pos, headStart))
                tail := abi_encode_bytes(value5, pos)
                abi_encode_uint64(value6, add(headStart, 192))
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function storage_array_index_access_address_dyn(index) -> slot, offset
            {
                if iszero(lt(index, sload(/** @src 2:32345:32361  "governanceOwners" */ 0x09)))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:32345:32361  "governanceOwners" */ 0x09)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20), index)
                offset := /** @src -1:-1:-1 */ 0
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function abi_decode_uint256t_boolt_uint256_fromMemory(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := mload(headStart)
                value0 := value
                value1 := abi_decode_t_bool_fromMemory(add(headStart, 32))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := mload(add(headStart, 64))
                value2 := value_1
            }
            function mapping_index_access_mapping_uint256_mapping_uint256_bytes32_of_uint8(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, /** @src 2:89915:89933  "merkleRootsPrivate" */ 0x01)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            function checked_div_uint256_18518(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := shr(8, x)
            }
            function checked_div_uint256_18619(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := div(x, /** @src 2:27587:27589  "65" */ 0x41)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function checked_div_uint256_18642(x) -> r
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
            function mod_uint256(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := and(x, 255)
            }
            function mod_uint256_18620(x) -> r
            {
                let _1 := 0
                _1 := 0
                r := mod(x, /** @src 2:27587:27589  "65" */ 0x41)
            }
            /// @ast-id 2873 @src 2:89262:90450  "function getRandomNumberHistorical(uint256 _votingRoundId)..."
            function fun_getRandomNumberHistorical(var_votingRoundId) -> var_randomNumber, var_isSecureRandom, var_randomTimestamp
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _1 := and(/** @src 2:89495:89503  "oldRelay" */ loadimmutable("523"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))
                /// @src 2:89495:89590  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 2:89495:89525  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ _1))
                /// @src 2:89495:89590  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 2:89529:89590  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:89546:89590  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("529"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
                }
                /// @src 2:89491:89674  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 2:89613:89663  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _2 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:89613:89663  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    mstore(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(227, 0x150fe287))
                    /// @src 2:89613:89663  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256(add(_2, 4), var_votingRoundId), _2), _2, 96)
                    if iszero(_3) { revert_forward() }
                    let expr_2800_component := /** @src 2:89522:89523  "0" */ 0x00
                    let expr_2800_component_1 := 0x00
                    let expr_component := 0x00
                    /// @src 2:89613:89663  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    if _3
                    {
                        let _4 := 96
                        if gt(96, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        let expr_component_1, expr_component_2, expr_component_3 := abi_decode_uint256t_boolt_uint256_fromMemory(_2, add(_2, _4))
                        expr_2800_component := expr_component_1
                        expr_2800_component_1 := expr_component_2
                        expr_component := expr_component_3
                    }
                    /// @src 2:89606:89663  "return oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    var_randomNumber := expr_2800_component
                    var_isSecureRandom := expr_2800_component_1
                    var_randomTimestamp := expr_component
                    leave
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _5 := sload(/** @src 2:89934:89943  "stateData" */ 0x0b)
                /// @src 2:89894:90039  "require(..."
                require_helper_stringliteral_2275(/** @src 2:89915:89997  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:89915:89983  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 2:89915:89967  "merkleRootsPrivate[stateData.randomNumberProtocolId]" */ mapping_index_access_mapping_uint256_mapping_uint256_bytes32_of_uint8(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ cleanup_from_storage_uint8(_5)), /** @src 2:89915:89983  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ var_votingRoundId)))))
                /// @src 2:90049:90102  "_randomNumber = toRandomNumberPrivate[_votingRoundId]"
                var_randomNumber := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:90065:90102  "toRandomNumberPrivate[_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18517(var_votingRoundId))
                /// @src 2:90112:90276  "_isSecureRandom =..."
                var_isSecureRandom := /** @src 2:90142:90276  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))..." */ eq(/** @src 2:90142:90237  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))" */ and(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shr(/** @src 2:90187:90213  "255 - _votingRoundId % 256" */ checked_sub_uint256_18521(/** @src 2:90193:90213  "_votingRoundId % 256" */ mod_uint256(var_votingRoundId)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:90143:90182  "isSecureRandomMap[_votingRoundId / 256]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18519(/** @src 2:90161:90181  "_votingRoundId / 256" */ checked_div_uint256_18518(var_votingRoundId)))), /** @src 2:89915:89933  "merkleRootsPrivate" */ 0x01), 0x01)
                /// @src 2:90317:90350  "stateData.firstVotingRoundStartTs"
                let _6 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offset_1t_uint32(_5)
                /// @src 2:90373:90391  "_votingRoundId + 1"
                let expr_1 := checked_add_uint256_18393(var_votingRoundId)
                /// @src 2:90286:90443  "_randomTimestamp =..."
                var_randomTimestamp := /** @src 2:90317:90443  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:90317:90443  "stateData.firstVotingRoundStartTs +..." */ _6, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff), /** @src 2:90365:90443  "uint256(_votingRoundId + 1) *..." */ checked_mul_uint256(expr_1, cleanup_from_storage_uint8(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_offsett_uint8(_5))))
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
            /// @src 2:9967:10051  "bytes4(keccak256(\"changeProtocolFees(uint256,bytes32,(uint256,uint256,uint256)[])\"))"
            function abi_encode_bytes4(value0) -> tail
            {
                tail := 36
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4, /** @src 2:4462:4464  "22" */ and(value0, shl(224, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff)))
            }
            function abi_encode_stringliteral_0d64(headStart) -> tail
            {
                mstore(headStart, 32)
                mstore(add(headStart, 32), 17)
                mstore(add(headStart, 64), "Not enough weight")
                tail := add(headStart, 96)
            }
            /// @src 2:33640:83692  "assembly {..."
            function usr$revertWithMessage(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy metadata")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18399(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy length")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18401(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Signing policy hash mismatch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18402(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "Too short message")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18403(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Already relayed")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18404(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "Wrong message format")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18406(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Wrong message format2")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18407(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong sign policy reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18408(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Message too old")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18409(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "Delayed sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18411(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Must use new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18414(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Sign policy relay disabled")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18415(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 23)
                mstore(add(usr_memPtr, 0x44), "No new sign policy size")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18416(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "must be non-trivial")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18417(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "too many voters")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18418(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong size for new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18420(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Not with last intialized")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18421(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not next reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18423(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "No signature count")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18424(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not enough signatures")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18425(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of range")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18426(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of order")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18427(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad v")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18428(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad s")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18429(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "ecrecover error")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18430(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "ecrecover returned bad data")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18431(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 11)
                mstore(add(usr_memPtr, 0x44), "Zero signer")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18432(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Wrong signature")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18433(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "zero merkle root")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18439(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "This should never happen")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18528(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "total weight too big")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18529(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "too small threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18530(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "too big threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18531(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "No random number")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18532(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 22)
                mstore(add(usr_memPtr, 0x44), "Incorrect merkle proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_18533(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                /// @src 2:33640:83692  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "Invalid random number proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$assignStruct_18422(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, /** @src 2:4462:4464  "22" */ not(shl(152, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:33640:83692  "assembly {..." */ shl(152, usr$newVal))
            }
            function usr$assignStruct_18437(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(112, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))), /** @src 2:33640:83692  "assembly {..." */ shl(112, usr$newVal))
            }
            function usr$assignStruct(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(144, /** @src 2:4462:4464  "22" */ 255))), /** @src 2:33640:83692  "assembly {..." */ shl(144, usr$newVal))
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
                    mstore(_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ shl(229, 4594637))
                    /// @src 2:33640:83692  "assembly {..."
                    mstore(add(_1, 0x04), 0x20)
                    mstore(add(_1, 0x24), 23)
                    mstore(add(_1, 0x44), "Invalid voting round id")
                    revert(_1, 0x64)
                }
                usr_rewardEpochId := div(sub(usr$_votingRoundId, usr$firstRewardEpochStartVotingRoundId), and(shr(80, usr_stateDataObj), 65535))
            }
            function usr$calculateSigningPolicyHash_18400(usr_memPos, usr_policyLength) -> usr_policyHash
            {
                calldatacopy(usr_memPos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4, /** @src 2:33640:83692  "assembly {..." */ 32)
                let usr$endPos := add(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 4, /** @src 2:33640:83692  "assembly {..." */ and(usr_policyLength, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:33640:83692  "assembly {..."
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
                mstore(usr_memPos, chainid())
                mstore(add(usr_memPos, 32), usr_policyHash)
                usr_policyHash := keccak256(usr_memPos, 64)
            }
            function usr$calculateSigningPolicyHash(usr_memPos, usr_calldataPos, usr_policyLength) -> usr_policyHash
            {
                calldatacopy(usr_memPos, usr_calldataPos, 32)
                let usr$endPos := add(usr_calldataPos, and(usr_policyLength, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:33640:83692  "assembly {..."
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
                mstore(usr_memPos, chainid())
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
                    usr$revertWithMessage_18528(usr_memPtr)
                }
                let _1 := mul(and(usr_metadata, 65535), 10000)
                if lt(_1, mul(usr$totalWeight, 5000))
                {
                    usr$revertWithMessage_18529(usr_memPtr)
                }
                if gt(_1, mul(usr$totalWeight, 6600))
                {
                    usr$revertWithMessage_18530(usr_memPtr)
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
                    usr$revertWithMessage_18531(usr_memPtr)
                }
                if iszero(iszero(and(sub(calldatasize(), usr_proofStart), 31)))
                {
                    usr$revertWithMessage_18532(usr_memPtr)
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
                    usr$revertWithMessage_18533(usr_memPtr)
                }
                calldatacopy(_3, usr_proofStart, 32)
                mstore(usr_memPtr, usr_votingRoundId)
                mstore(_2, 12)
                sstore(keccak256(usr_memPtr, 64), mload(_3))
            }
            /// @ast-id 3961 @src 9:4637:4809  "function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {..."
            function fun_verifyCalldata(var_proof_offset, var_proof_3944_length, var_root, var_leaf) -> var
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
                    let _1 := iszero(lt(var_i, /** @src 9:5385:5397  "proof.length" */ var_proof_3944_length))
                    /// @src 9:5381:5397  "i < proof.length"
                    if _1 { break }
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    _1 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            function calldata_array_index_range_access_bytes_calldata_18629(offset, length, endIndex) -> offsetOut, lengthOut
            {
                if gt(/** @src 2:30374:30375  "4" */ 0x04, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ endIndex) { revert(0, 0) }
                if gt(endIndex, length) { revert(0, 0) }
                offsetOut := add(offset, /** @src 2:30374:30375  "4" */ 0x04)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                calldatacopy(add(memPtr, 0x20), src, length)
                mstore(add(add(memPtr, length), 0x20), /** @src -1:-1:-1 */ 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function validator_assert_enum_RecoverError(value)
            {
                if iszero(lt(value, 4))
                {
                    mstore(0, shl(224, 0x4e487b71))
                    mstore(4, 0x21)
                    revert(0, 0x24)
                }
            }
            /// @ast-id 1895 @src 2:27399:28501  "function _verifyGovernanceSignatures(..."
            function fun_verifyGovernanceSignatures(var_txData_offset, var_signatures_offset, var_signatures_length)
            {
                /// @src 2:27567:27589  "signatures.length / 65"
                let expr := checked_div_uint256_18619(var_signatures_length)
                /// @src 2:27616:27681  "signatures.length == 0 ||..."
                let expr_1 := /** @src 2:27616:27638  "signatures.length == 0" */ iszero(var_signatures_length)
                /// @src 2:27616:27681  "signatures.length == 0 ||..."
                if iszero(expr_1)
                {
                    expr_1 := /** @src 2:27654:27681  "signatures.length % 65 != 0" */ iszero(iszero(/** @src 2:27654:27676  "signatures.length % 65" */ mod_uint256_18620(var_signatures_length)))
                }
                /// @src 2:27616:27724  "signatures.length == 0 ||..."
                let expr_2 := expr_1
                if iszero(expr_1)
                {
                    expr_2 := /** @src 2:27697:27724  "count < governanceThreshold" */ lt(expr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:27705:27724  "governanceThreshold" */ 0x08))
                }
                /// @src 2:27616:27771  "signatures.length == 0 ||..."
                let expr_3 := expr_2
                if iszero(expr_2)
                {
                    expr_3 := /** @src 2:27740:27771  "count > governanceOwners.length" */ gt(expr, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:27748:27764  "governanceOwners" */ 0x09))
                }
                /// @src 2:27599:27843  "if (..."
                if expr_3
                {
                    /// @src 2:27803:27832  "InvalidGovernanceSignatures()"
                    mstore(/** @src 2:27637:27638  "0" */ 0x00, /** @src 2:27803:27832  "InvalidGovernanceSignatures()" */ shl(225, 0x7ddace71))
                    revert(/** @src 2:27637:27638  "0" */ 0x00, /** @src 2:27803:27832  "InvalidGovernanceSignatures()" */ 4)
                }
                /// @src 2:27889:27914  "_copyGovernanceTx(txData)"
                let expr_1820_mpos := fun_copyGovernanceTx(var_txData_offset)
                /// @src 2:27869:27956  "GnosisSafeTx.digest(_copyGovernanceTx(txData), governanceSourceChainId, governanceSafe)"
                let expr_4 := fun_digest(expr_1820_mpos, /** @src 2:27916:27939  "governanceSourceChainId" */ loadimmutable("468"), /** @src 2:27941:27955  "governanceSafe" */ loadimmutable("471"))
                /// @src 2:27966:27982  "address previous"
                let var_previous := /** @src 2:27637:27638  "0" */ 0x00
                /// @src 2:27966:27982  "address previous"
                var_previous := /** @src 2:27637:27638  "0" */ 0x00
                /// @src 2:27997:28006  "uint256 i"
                let var_i := /** @src 2:27637:27638  "0" */ 0x00
                /// @src 2:27997:28006  "uint256 i"
                var_i := /** @src 2:27637:27638  "0" */ 0x00
                /// @src 2:27992:28495  "for (uint256 i; i < count; ++i) {..."
                for { }
                /** @src 2:28008:28017  "i < count" */ lt(var_i, expr)
                /// @src 2:27997:28006  "uint256 i"
                {
                    /// @src 2:28019:28022  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:28019:28022  "++i" */ var_i, /** @src 2:28148:28149  "1" */ 0x01)
                }
                /// @src 2:28019:28022  "++i"
                {
                    /// @src 2:28136:28142  "i * 65"
                    let expr_5 := checked_mul_uint256_18621(var_i)
                    /// @src 2:28125:28156  "signatures[i * 65:(i + 1) * 65]"
                    let expr_1854_offset, expr_1854_length := calldata_array_index_range_access_bytes_calldata(var_signatures_offset, var_signatures_length, expr_5, /** @src 2:28143:28155  "(i + 1) * 65" */ checked_mul_uint256_18621(/** @src 2:28144:28149  "i + 1" */ checked_add_uint256_18393(var_i)))
                    /// @src 2:28107:28157  "digest.tryRecover(signatures[i * 65:(i + 1) * 65])"
                    let expr_component, expr_1855_component, expr_1855_component_1 := fun_tryRecover(expr_4, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:28107:28157  "digest.tryRecover(signatures[i * 65:(i + 1) * 65])" */ expr_1854_offset, expr_1854_length, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize()))
                    validator_assert_enum_RecoverError(expr_1855_component)
                    /// @src 2:28192:28234  "recoverError != ECDSA.RecoverError.NoError"
                    let _1 := iszero(expr_1855_component)
                    /// @src 2:28192:28274  "recoverError != ECDSA.RecoverError.NoError ||..."
                    let expr_6 := /** @src 2:28192:28234  "recoverError != ECDSA.RecoverError.NoError" */ iszero(_1)
                    /// @src 2:28192:28274  "recoverError != ECDSA.RecoverError.NoError ||..."
                    if _1
                    {
                        expr_6 := /** @src 2:28254:28274  "signer == address(0)" */ iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:28254:28274  "signer == address(0)" */ expr_component, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    }
                    /// @src 2:28192:28323  "recoverError != ECDSA.RecoverError.NoError ||..."
                    let expr_7 := expr_6
                    if iszero(expr_6)
                    {
                        /// @src 2:28295:28322  "i > 0 && signer <= previous"
                        let expr_8 := /** @src 2:28295:28300  "i > 0" */ iszero(iszero(var_i))
                        /// @src 2:28295:28322  "i > 0 && signer <= previous"
                        if expr_8
                        {
                            expr_8 := /** @src 2:28304:28322  "signer <= previous" */ iszero(gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:28304:28322  "signer <= previous" */ expr_component, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)), and(/** @src 2:28304:28322  "signer <= previous" */ var_previous, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
                        }
                        /// @src 2:28192:28323  "recoverError != ECDSA.RecoverError.NoError ||..."
                        expr_7 := expr_8
                    }
                    /// @src 2:28192:28370  "recoverError != ECDSA.RecoverError.NoError ||..."
                    let expr_9 := expr_7
                    if iszero(expr_7)
                    {
                        expr_9 := /** @src 2:28343:28370  "!_isGovernanceOwner(signer)" */ cleanup_bool(iszero(/** @src 2:28344:28370  "_isGovernanceOwner(signer)" */ fun_isGovernanceOwner(expr_component)))
                    }
                    /// @src 2:28171:28454  "if (..."
                    if expr_9
                    {
                        /// @src 2:28410:28439  "InvalidGovernanceSignatures()"
                        mstore(/** @src 2:27637:27638  "0" */ 0x00, /** @src 2:27803:27832  "InvalidGovernanceSignatures()" */ shl(225, 0x7ddace71))
                        /// @src 2:28410:28439  "InvalidGovernanceSignatures()"
                        revert(/** @src 2:27637:27638  "0" */ 0x00, /** @src 2:28410:28439  "InvalidGovernanceSignatures()" */ 4)
                    }
                    /// @src 2:28467:28484  "previous = signer"
                    var_previous := expr_component
                }
            }
            /// @ast-id 2263 @src 2:31781:31983  "function _governanceSelector(bytes calldata data) internal pure returns (bytes4 selector) {..."
            function fun_governanceSelector(var_data_2240_offset, var_data_length) -> var_selector
            {
                /// @src 2:31881:31939  "if (data.length < 4) revert InvalidGovernanceTransaction()"
                if /** @src 2:31885:31900  "data.length < 4" */ lt(var_data_length, /** @src 2:31899:31900  "4" */ 0x04)
                /// @src 2:31881:31939  "if (data.length < 4) revert InvalidGovernanceTransaction()"
                {
                    /// @src 2:31909:31939  "InvalidGovernanceTransaction()"
                    mstore(0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:31909:31939  "InvalidGovernanceTransaction()"
                    revert(0, /** @src 2:31899:31900  "4" */ 0x04)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if gt(/** @src 2:31899:31900  "4" */ 0x04, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ var_data_length)
                {
                    revert(/** @src 2:31967:31975  "data[:4]" */ 0, 0)
                }
                /// @src 2:31949:31976  "selector = bytes4(data[:4])"
                var_selector := /** @src 2:4462:4464  "22" */ and(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldataload(var_data_2240_offset), /** @src 2:4462:4464  "22" */ shl(224, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0xffffffff))
            }
            /// @ast-id 2292 @src 2:31989:32219  "function _governanceActionNonce(bytes calldata data) internal pure returns (uint256 actionNonce) {..."
            function fun_governanceActionNonce(var_data_offset, var_data_2265_length) -> var_actionNonce
            {
                /// @src 2:32096:32155  "if (data.length < 36) revert InvalidGovernanceTransaction()"
                if /** @src 2:32100:32116  "data.length < 36" */ lt(var_data_2265_length, /** @src 2:32114:32116  "36" */ 0x24)
                /// @src 2:32096:32155  "if (data.length < 36) revert InvalidGovernanceTransaction()"
                {
                    /// @src 2:32125:32155  "InvalidGovernanceTransaction()"
                    mstore(0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:32125:32155  "InvalidGovernanceTransaction()"
                    revert(0, 4)
                }
                /// @src 2:32190:32200  "data[4:36]"
                let offsetOut := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if gt(/** @src 2:32114:32116  "36" */ 0x24, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ var_data_2265_length)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:32179:32212  "abi.decode(data[4:36], (uint256))"
                let value0 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                offsetOut := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(add(var_data_offset, /** @src 2:32195:32196  "4" */ 0x04))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value0 := value
                /// @src 2:32165:32212  "actionNonce = abi.decode(data[4:36], (uint256))"
                var_actionNonce := value
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function abi_decode_uint256t_bytes32t_array_struct_GovernanceFeeUpdate_dyn(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(headStart)
                value0 := value
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(add(headStart, 32))
                value1 := value_1
                let offset := calldataload(add(headStart, 64))
                if gt(offset, 0xffffffffffffffff) { revert(0, 0) }
                let _1 := add(headStart, offset)
                if iszero(slt(add(_1, 0x1f), dataEnd))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let src := add(_1, 32)
                for { } lt(src, srcEnd) { src := add(src, 96) }
                {
                    if slt(sub(dataEnd, src), 96)
                    {
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    let memPtr_1 := mload(64)
                    finalize_allocation_18628(memPtr_1)
                    let value_2 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    value_2 := calldataload(src)
                    mstore(memPtr_1, value_2)
                    let value_3 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    value_3 := calldataload(add(src, 32))
                    mstore(add(memPtr_1, 32), value_3)
                    let value_4 := /** @src -1:-1:-1 */ 0
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
                let srcPtr := /** @src 2:4462:4464  "22" */ add(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value2, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    let _1 := mload(srcPtr)
                    mstore(pos, mload(_1))
                    mstore(add(pos, 32), mload(add(_1, 32)))
                    mstore(add(pos, 64), mload(add(_1, 64)))
                    pos := add(pos, 96)
                    srcPtr := /** @src 2:4462:4464  "22" */ add(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ srcPtr, 32)
                }
                tail := pos
            }
            /// @ast-id 2238 @src 2:30172:31775  "function _applyGovernanceFees(bytes calldata action) internal returns (bool relevant) {..."
            function fun_applyGovernanceFees(var_action_offset, var_action_length) -> var_relevant
            {
                /// @src 2:30243:30256  "bool relevant"
                var_relevant := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:30367:30377  "action[4:]"
                let expr_2072_offset, expr_2072_length := calldata_array_index_range_access_bytes_calldata_18629(var_action_offset, var_action_length, var_action_length)
                /// @src 2:30356:30421  "abi.decode(action[4:], (uint256, bytes32, GovernanceFeeUpdate[]))"
                let expr_2080_component, expr_component, expr_2080_component_3_mpos := abi_decode_uint256t_bytes32t_array_struct_GovernanceFeeUpdate_dyn(expr_2072_offset, add(expr_2072_offset, expr_2072_length))
                /// @src 2:30435:30452  "keccak256(action)"
                let _659_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:30435:30452  "keccak256(action)" */ var_action_offset, var_action_length, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize())
                /// @src 2:30435:30452  "keccak256(action)"
                let expr := keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:30435:30452  "keccak256(action)" */ _659_mpos, /** @src 2:4462:4464  "22" */ 0x20), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:30435:30452  "keccak256(action)" */ _659_mpos))
                /// @src 2:30466:30569  "abi.encodeWithSelector(..."
                let expr_2092_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:30466:30569  "abi.encodeWithSelector(..."
                let _1 := add(expr_2092_mpos, /** @src 2:4462:4464  "22" */ 0x20)
                /// @src 2:30466:30569  "abi.encodeWithSelector(..."
                mstore(_1, /** @src 2:4462:4464  "22" */ shl(225, 0x0ac2ae7b))
                /// @src 2:30466:30569  "abi.encodeWithSelector(..."
                let _2 := sub(abi_encode_uint256_bytes32_array_struct_GovernanceFeeUpdate_dyn(add(expr_2092_mpos, 36), expr_2080_component, expr_component, expr_2080_component_3_mpos), expr_2092_mpos)
                mstore(expr_2092_mpos, add(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:30466:30569  "abi.encodeWithSelector(..."
                finalize_allocation(expr_2092_mpos, _2)
                /// @src 2:30431:30609  "if (keccak256(action) != keccak256(abi.encodeWithSelector(..."
                if /** @src 2:30435:30570  "keccak256(action) != keccak256(abi.encodeWithSelector(..." */ iszero(eq(expr, /** @src 2:30456:30570  "keccak256(abi.encodeWithSelector(..." */ keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:30456:30570  "keccak256(abi.encodeWithSelector(..." */ expr_2092_mpos))))
                /// @src 2:30431:30609  "if (keccak256(action) != keccak256(abi.encodeWithSelector(..."
                {
                    /// @src 2:30579:30609  "InvalidGovernanceTransaction()"
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:30579:30609  "InvalidGovernanceTransaction()"
                    revert(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:30374:30375  "4" */ 0x04)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _3 := sload(/** @src 2:30637:30658  "activeOwnerConfigHash" */ 0x06)
                /// @src 2:30619:30729  "if (configHash != activeOwnerConfigHash) revert GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)"
                if /** @src 2:30623:30658  "configHash != activeOwnerConfigHash" */ iszero(eq(expr_component, _3))
                /// @src 2:30619:30729  "if (configHash != activeOwnerConfigHash) revert GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)"
                {
                    /// @src 2:30667:30729  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)"
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:30667:30729  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)" */ shl(224, 0xb3d0e4e9))
                    revert(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:30667:30729  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)" */ abi_encode_uint256_uint256_18394(expr_component, _3))
                }
                /// @src 2:30739:30825  "if (updates.length > MAX_GOVERNANCE_FEE_UPDATES) revert InvalidGovernanceTransaction()"
                if /** @src 2:30743:30786  "updates.length > MAX_GOVERNANCE_FEE_UPDATES" */ gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:30743:30757  "updates.length" */ expr_2080_component_3_mpos), /** @src 2:9762:9765  "256" */ 0x0100)
                /// @src 2:30739:30825  "if (updates.length > MAX_GOVERNANCE_FEE_UPDATES) revert InvalidGovernanceTransaction()"
                {
                    /// @src 2:30795:30825  "InvalidGovernanceTransaction()"
                    mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:30795:30825  "InvalidGovernanceTransaction()"
                    revert(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:30374:30375  "4" */ 0x04)
                }
                /// @src 2:30840:30849  "uint256 i"
                let var_i := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:30840:30849  "uint256 i"
                var_i := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:30835:31316  "for (uint256 i; i < updates.length; ++i) {..."
                for { }
                /** @src 2:30970:30974  "true" */ 0x01
                /// @src 2:30840:30849  "uint256 i"
                {
                    /// @src 2:30871:30874  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:30871:30874  "++i" */ var_i, /** @src 2:30970:30974  "true" */ 0x01)
                }
                /// @src 2:30871:30874  "++i"
                {
                    /// @src 2:30851:30869  "i < updates.length"
                    if iszero(lt(var_i, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:30855:30869  "updates.length" */ expr_2080_component_3_mpos)))
                    /// @src 2:30851:30869  "i < updates.length"
                    { break }
                    /// @src 2:30890:30945  "if (updates[i].targetChainId != block.chainid) continue"
                    if /** @src 2:30894:30935  "updates[i].targetChainId != block.chainid" */ iszero(eq(/** @src 2:4462:4464  "22" */ mload(/** @src 2:30894:30904  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i))), /** @src 2:30922:30935  "block.chainid" */ chainid()))
                    /// @src 2:30890:30945  "if (updates[i].targetChainId != block.chainid) continue"
                    {
                        /// @src 2:30937:30945  "continue"
                        continue
                    }
                    /// @src 2:30959:30974  "relevant = true"
                    var_relevant := /** @src 2:30970:30974  "true" */ 0x01
                    /// @src 2:30988:31057  "if (updates[i].protocolId <= 1) revert InvalidGovernanceTransaction()"
                    if /** @src 2:30992:31018  "updates[i].protocolId <= 1" */ iszero(gt(/** @src 2:4462:4464  "22" */ mload(/** @src 2:30992:31013  "updates[i].protocolId" */ add(/** @src 2:30992:31002  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i)), /** @src 2:4462:4464  "22" */ 0x20)), /** @src 2:30970:30974  "true" */ var_relevant))
                    /// @src 2:30988:31057  "if (updates[i].protocolId <= 1) revert InvalidGovernanceTransaction()"
                    {
                        /// @src 2:31027:31057  "InvalidGovernanceTransaction()"
                        mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                        /// @src 2:31027:31057  "InvalidGovernanceTransaction()"
                        revert(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:30374:30375  "4" */ 0x04)
                    }
                    /// @src 2:31076:31085  "uint256 j"
                    let var_j := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:31076:31085  "uint256 j"
                    var_j := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:31071:31306  "for (uint256 j; j < i; ++j) {..."
                    for { }
                    /** @src 2:31087:31092  "j < i" */ lt(var_j, var_i)
                    /// @src 2:31076:31085  "uint256 j"
                    {
                        /// @src 2:31094:31097  "++j"
                        var_j := /** @src 2:2993:2996  "300" */ add(/** @src 2:31094:31097  "++j" */ var_j, /** @src 2:30970:30974  "true" */ var_relevant)
                    }
                    /// @src 2:31094:31097  "++j"
                    {
                        /// @src 2:31121:31212  "updates[j].targetChainId == block.chainid && updates[j].protocolId == updates[i].protocolId"
                        let expr_1 := /** @src 2:31121:31162  "updates[j].targetChainId == block.chainid" */ eq(/** @src 2:4462:4464  "22" */ mload(/** @src 2:31121:31131  "updates[j]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_j))), /** @src 2:30922:30935  "block.chainid" */ chainid())
                        /// @src 2:31121:31212  "updates[j].targetChainId == block.chainid && updates[j].protocolId == updates[i].protocolId"
                        if expr_1
                        {
                            /// @src 2:4462:4464  "22"
                            let _4 := mload(/** @src 2:31166:31187  "updates[j].protocolId" */ add(/** @src 2:31166:31176  "updates[j]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_j)), /** @src 2:4462:4464  "22" */ 0x20))
                            /// @src 2:31121:31212  "updates[j].targetChainId == block.chainid && updates[j].protocolId == updates[i].protocolId"
                            expr_1 := /** @src 2:31166:31212  "updates[j].protocolId == updates[i].protocolId" */ eq(_4, /** @src 2:4462:4464  "22" */ mload(/** @src 2:31191:31212  "updates[i].protocolId" */ add(/** @src 2:31191:31201  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i)), /** @src 2:4462:4464  "22" */ 0x20)))
                        }
                        /// @src 2:31117:31292  "if (updates[j].targetChainId == block.chainid && updates[j].protocolId == updates[i].protocolId) {..."
                        if expr_1
                        {
                            /// @src 2:31243:31273  "InvalidGovernanceTransaction()"
                            mstore(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                            /// @src 2:31243:31273  "InvalidGovernanceTransaction()"
                            revert(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0, /** @src 2:30374:30375  "4" */ 0x04)
                        }
                    }
                }
                /// @src 2:31325:31352  "if (!relevant) return false"
                if /** @src 2:31329:31338  "!relevant" */ iszero(var_relevant)
                /// @src 2:31325:31352  "if (!relevant) return false"
                {
                    /// @src 2:31340:31352  "return false"
                    var_relevant := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                    /// @src 2:31340:31352  "return false"
                    leave
                }
                /// @src 2:31367:31376  "uint256 i"
                let var_i_1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:31367:31376  "uint256 i"
                var_i_1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:31362:31769  "for (uint256 i; i < updates.length; ++i) {..."
                for { }
                /** @src 2:30970:30974  "true" */ 0x01
                /// @src 2:31367:31376  "uint256 i"
                {
                    /// @src 2:31398:31401  "++i"
                    var_i_1 := /** @src 2:2993:2996  "300" */ add(/** @src 2:31398:31401  "++i" */ var_i_1, /** @src 2:30970:30974  "true" */ 0x01)
                }
                /// @src 2:31398:31401  "++i"
                {
                    /// @src 2:31378:31396  "i < updates.length"
                    if iszero(lt(var_i_1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:31382:31396  "updates.length" */ expr_2080_component_3_mpos)))
                    /// @src 2:31378:31396  "i < updates.length"
                    { break }
                    /// @src 2:31417:31472  "if (updates[i].targetChainId != block.chainid) continue"
                    if /** @src 2:31421:31462  "updates[i].targetChainId != block.chainid" */ iszero(eq(/** @src 2:4462:4464  "22" */ mload(/** @src 2:31421:31431  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i_1))), /** @src 2:30922:30935  "block.chainid" */ chainid()))
                    /// @src 2:31417:31472  "if (updates[i].targetChainId != block.chainid) continue"
                    {
                        /// @src 2:31464:31472  "continue"
                        continue
                    }
                    /// @src 2:4462:4464  "22"
                    sstore(/** @src 2:31486:31525  "protocolFeeInWei[updates[i].protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_18444(/** @src 2:4462:4464  "22" */ mload(/** @src 2:31503:31524  "updates[i].protocolId" */ add(/** @src 2:31503:31513  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i_1)), /** @src 2:4462:4464  "22" */ 0x20))), mload(/** @src 2:31528:31547  "updates[i].feeInWei" */ add(/** @src 2:31528:31538  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i_1)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64)))
                    /// @src 2:4462:4464  "22"
                    let _5 := mload(/** @src 2:31635:31656  "updates[i].protocolId" */ add(/** @src 2:31635:31645  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i_1)), /** @src 2:4462:4464  "22" */ 0x20))
                    let _6 := mload(/** @src 2:31674:31693  "updates[i].feeInWei" */ add(/** @src 2:31674:31684  "updates[i]" */ mload(memory_array_index_access_uint16_dyn(expr_2080_component_3_mpos, var_i_1)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64))
                    /// @src 2:31566:31758  "GovernanceFeeUpdated(..."
                    let _7 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                    /// @src 2:31566:31758  "GovernanceFeeUpdated(..."
                    log4(_7, sub(abi_encode_uint256_uint256(_7, _6, expr_2080_component), _7), 0xaf29a23d2bc893d04257fcb829a71cbf3ba313601249fa9581733a5aff968174, /** @src 2:30922:30935  "block.chainid" */ chainid(), /** @src 2:31566:31758  "GovernanceFeeUpdated(..." */ _5, expr_component)
                }
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function abi_decode_uint256t_bytes32t_uint256t_array_address_dyn(headStart, dataEnd) -> value0, value1, value2, value3
            {
                if slt(sub(dataEnd, headStart), 128) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(headStart)
                value0 := value
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(add(headStart, 32))
                value1 := value_1
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
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
            /// @src 2:9699:9702  "256"
            function storage_set_to_zero_array_address_dyn()
            {
                let offset := /** @src 2:29890:29913  "delete governanceOwners" */ 0
                /// @src 2:9699:9702  "256"
                offset := /** @src 2:29890:29913  "delete governanceOwners" */ 0
                /// @src 2:9699:9702  "256"
                let oldLen := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:29890:29913  "delete governanceOwners" */ 0x09)
                /// @src 2:9699:9702  "256"
                sstore(/** @src 2:29890:29913  "delete governanceOwners" */ 0x09, /** @src -1:-1:-1 */ 0)
                /// @src 2:9699:9702  "256"
                if iszero(iszero(oldLen))
                {
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:29890:29913  "delete governanceOwners" */ 0x09)
                    /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                    let data := keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20)
                    /// @src 2:9699:9702  "256"
                    let _1 := add(data, oldLen)
                    let start := data
                    for { } lt(start, _1) { start := add(start, 1) }
                    {
                        sstore(start, /** @src -1:-1:-1 */ 0)
                    }
                }
            }
            /// @src 2:9699:9702  "256"
            function array_push_from_address_to_array_address_dyn_storage_ptr(value0)
            {
                let oldLen := sload(/** @src 2:29890:29913  "delete governanceOwners" */ 0x09)
                /// @src 2:9699:9702  "256"
                if iszero(lt(oldLen, 18446744073709551616)) { panic_error_0x41() }
                sstore(/** @src 2:29890:29913  "delete governanceOwners" */ 0x09, /** @src 2:9699:9702  "256" */ add(oldLen, 1))
                let slot := /** @src -1:-1:-1 */ 0
                /// @src 2:9699:9702  "256"
                let offset := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                if iszero(lt(oldLen, sload(/** @src 2:29890:29913  "delete governanceOwners" */ 0x09)))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                { panic_error_0x32() }
                mstore(/** @src -1:-1:-1 */ 0, /** @src 2:29890:29913  "delete governanceOwners" */ 0x09)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                slot := add(keccak256(/** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0x20), oldLen)
                offset := /** @src -1:-1:-1 */ 0
                /// @src 2:9699:9702  "256"
                sstore(slot, or(and(sload(slot), shl(160, /** @src 2:4462:4464  "22" */ 0xffffffffffffffffffffffff)), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:9699:9702  "256" */ value0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1))))
            }
            /// @src 2:9699:9702  "256"
            function abi_encode_uint256_uint256_array_address_dyn(headStart, value0, value1, value2) -> tail
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, value0)
                mstore(/** @src 2:9699:9702  "256" */ add(headStart, 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                /// @src 2:9699:9702  "256"
                mstore(add(headStart, 64), 96)
                tail := abi_encode_array_address_dyn(value2, add(headStart, 96))
            }
            /// @ast-id 2053 @src 2:29040:30166  "function _applyGovernanceOwners(bytes calldata action) internal {..."
            function fun_applyGovernanceOwners(var_action_1933_offset, var_action_1933_length)
            {
                /// @src 2:29220:29230  "action[4:]"
                let expr_1949_offset, expr_1949_length := calldata_array_index_range_access_bytes_calldata_18629(var_action_1933_offset, var_action_1933_length, var_action_1933_length)
                /// @src 2:29209:29271  "abi.decode(action[4:], (uint256, bytes32, uint256, address[]))"
                let expr_1960_component, expr_1960_component_1, expr_1960_component_2, expr_1960_component_4_mpos := abi_decode_uint256t_bytes32t_uint256t_array_address_dyn(expr_1949_offset, add(expr_1949_offset, expr_1949_length))
                /// @src 2:29285:29302  "keccak256(action)"
                let _762_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:29285:29302  "keccak256(action)" */ var_action_1933_offset, var_action_1933_length, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize())
                /// @src 2:29285:29302  "keccak256(action)"
                let expr := keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 2:29285:29302  "keccak256(action)" */ _762_mpos, /** @src 2:4462:4464  "22" */ 0x20), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:29285:29302  "keccak256(action)" */ _762_mpos))
                /// @src 2:29316:29423  "abi.encodeWithSelector(..."
                let expr_1973_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:29316:29423  "abi.encodeWithSelector(..."
                let _1 := add(expr_1973_mpos, /** @src 2:4462:4464  "22" */ 0x20)
                /// @src 2:29316:29423  "abi.encodeWithSelector(..."
                mstore(_1, /** @src 2:4462:4464  "22" */ shl(226, 0x23d0fe25))
                /// @src 2:29316:29423  "abi.encodeWithSelector(..."
                let _2 := sub(abi_encode_uint256_bytes32_uint256_array_address_dyn(add(expr_1973_mpos, 36), expr_1960_component, expr_1960_component_1, expr_1960_component_2, expr_1960_component_4_mpos), expr_1973_mpos)
                mstore(expr_1973_mpos, add(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 2:29316:29423  "abi.encodeWithSelector(..."
                finalize_allocation(expr_1973_mpos, _2)
                /// @src 2:29281:29463  "if (keccak256(action) != keccak256(abi.encodeWithSelector(..."
                if /** @src 2:29285:29424  "keccak256(action) != keccak256(abi.encodeWithSelector(..." */ iszero(eq(expr, /** @src 2:29306:29424  "keccak256(abi.encodeWithSelector(..." */ keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:29306:29424  "keccak256(abi.encodeWithSelector(..." */ expr_1973_mpos))))
                /// @src 2:29281:29463  "if (keccak256(action) != keccak256(abi.encodeWithSelector(..."
                {
                    /// @src 2:29433:29463  "InvalidGovernanceTransaction()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:26190:26220  "InvalidGovernanceTransaction()" */ shl(226, 0x340fa413))
                    /// @src 2:29433:29463  "InvalidGovernanceTransaction()"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:29227:29228  "4" */ 0x04)
                }
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                let _3 := sload(/** @src 2:29492:29513  "activeOwnerConfigHash" */ 0x06)
                /// @src 2:29473:29610  "if (currentHash != activeOwnerConfigHash) {..."
                if /** @src 2:29477:29513  "currentHash != activeOwnerConfigHash" */ iszero(eq(expr_1960_component_1, _3))
                /// @src 2:29473:29610  "if (currentHash != activeOwnerConfigHash) {..."
                {
                    /// @src 2:29536:29599  "GovernanceOwnerHashMismatch(currentHash, activeOwnerConfigHash)"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:30667:30729  "GovernanceOwnerHashMismatch(configHash, activeOwnerConfigHash)" */ shl(224, 0xb3d0e4e9))
                    /// @src 2:29536:29599  "GovernanceOwnerHashMismatch(currentHash, activeOwnerConfigHash)"
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:29536:29599  "GovernanceOwnerHashMismatch(currentHash, activeOwnerConfigHash)" */ abi_encode_uint256_uint256_18394(expr_1960_component_1, _3))
                }
                /// @src 2:29619:29706  "if (owners.length > MAX_GOVERNANCE_OWNERS) revert InvalidGovernanceOwnerConfiguration()"
                if /** @src 2:29623:29660  "owners.length > MAX_GOVERNANCE_OWNERS" */ gt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:29623:29636  "owners.length" */ expr_1960_component_4_mpos), /** @src 2:9762:9765  "256" */ 0x0100)
                /// @src 2:29619:29706  "if (owners.length > MAX_GOVERNANCE_OWNERS) revert InvalidGovernanceOwnerConfiguration()"
                {
                    /// @src 2:29669:29706  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 2:29669:29706  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    revert(/** @src -1:-1:-1 */ 0, /** @src 2:29227:29228  "4" */ 0x04)
                }
                /// @src 2:29750:29759  "threshold"
                fun_validateGovernanceOwners(expr_1960_component_4_mpos, expr_1960_component_2)
                /// @src 2:29835:29880  "_governanceOwnerConfigHash(threshold, owners)"
                let expr_1 := fun_governanceOwnerConfigHash(expr_1960_component_2, expr_1960_component_4_mpos)
                /// @src 2:29890:29913  "delete governanceOwners"
                storage_set_to_zero_array_address_dyn()
                /// @src 2:29928:29937  "uint256 i"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:29928:29937  "uint256 i"
                var_i := /** @src -1:-1:-1 */ 0
                /// @src 2:29923:29995  "for (uint256 i; i < owners.length; ++i) governanceOwners.push(owners[i])"
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 2:29928:29937  "uint256 i"
                {
                    /// @src 2:29958:29961  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:29958:29961  "++i" */ var_i, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 2:29958:29961  "++i"
                {
                    /// @src 2:29939:29956  "i < owners.length"
                    if iszero(lt(var_i, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:29943:29956  "owners.length" */ expr_1960_component_4_mpos)))
                    /// @src 2:29939:29956  "i < owners.length"
                    { break }
                    /// @src 2:29963:29995  "governanceOwners.push(owners[i])"
                    array_push_from_address_to_array_address_dyn_storage_ptr(/** @src 2:29985:29994  "owners[i]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(expr_1960_component_4_mpos, var_i)))
                }
                /// @src 2:30005:30036  "governanceThreshold = threshold"
                update_storage_value_offsett_bytes32_to_bytes32_18636(expr_1960_component_2)
                /// @src 2:30046:30074  "activeOwnerConfigHash = next"
                update_storage_value_offsett_bytes32_to_bytes32(expr_1)
                /// @src 2:30089:30159  "GovernanceOwnerConfigUpdated(previous, next, nonce, threshold, owners)"
                let _4 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 2:30089:30159  "GovernanceOwnerConfigUpdated(previous, next, nonce, threshold, owners)"
                log3(_4, sub(abi_encode_uint256_uint256_array_address_dyn(_4, expr_1960_component, expr_1960_component_2, expr_1960_component_4_mpos), _4), 0x0d98428e81be81c8c2e5fb18bb96e02d0dad8ff7c3a7cf42a1d4dec9f2073dc0, _3, expr_1)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function allocate_and_zero_memory_struct_struct_Transaction() -> memPtr
            {
                let memPtr_1 := mload(64)
                let newFreePtr := add(memPtr_1, 320)
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1)) { panic_error_0x41() }
                mstore(64, newFreePtr)
                memPtr := memPtr_1
                mstore(memPtr_1, /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 32), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 64), 96)
                mstore(add(memPtr_1, 96), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 128), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 160), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 192), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 224), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 256), /** @src -1:-1:-1 */ 0)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(add(memPtr_1, 288), /** @src -1:-1:-1 */ 0)
            }
            /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
            function read_from_calldatat_address(ptr) -> returnValue
            {
                let value := calldataload(ptr)
                validator_revert_address(value)
                returnValue := value
            }
            function write_to_memory_address(memPtr, value)
            {
                mstore(memPtr, and(value, sub(shl(160, 1), 1)))
            }
            function write_to_memory_uint8(memPtr, value)
            {
                mstore(memPtr, and(value, 0xff))
            }
            /// @ast-id 1931 @src 2:28507:28992  "function _copyGovernanceTx(GnosisSafeTx.Transaction calldata source)..."
            function fun_copyGovernanceTx(var_source_offset) -> var_target_mpos
            {
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                pop(allocate_and_zero_memory_struct_struct_Transaction())
                /// @src 2:28708:28717  "source.to"
                let expr := read_from_calldatat_address(var_source_offset)
                /// @src 2:28731:28743  "source.value"
                let value := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value := calldataload(/** @src 2:28731:28743  "source.value" */ add(var_source_offset, 32))
                /// @src 2:28757:28768  "source.data"
                let expr_1912_offset, expr_1912_length := access_calldata_tail_bytes_calldata(var_source_offset, add(var_source_offset, 64))
                /// @src 2:28782:28798  "source.operation"
                let expr_1 := read_from_calldatat_uint8(add(var_source_offset, 96))
                /// @src 2:28812:28828  "source.safeTxGas"
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_1 := calldataload(/** @src 2:28812:28828  "source.safeTxGas" */ add(var_source_offset, 128))
                /// @src 2:28842:28856  "source.baseGas"
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_2 := calldataload(/** @src 2:28842:28856  "source.baseGas" */ add(var_source_offset, 160))
                /// @src 2:28870:28885  "source.gasPrice"
                let value_3 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_3 := calldataload(/** @src 2:28870:28885  "source.gasPrice" */ add(var_source_offset, 192))
                /// @src 2:28899:28914  "source.gasToken"
                let expr_2 := read_from_calldatat_address(add(var_source_offset, 224))
                /// @src 2:28928:28949  "source.refundReceiver"
                let expr_3 := read_from_calldatat_address(add(var_source_offset, 256))
                /// @src 2:28963:28975  "source.nonce"
                let value_4 := /** @src -1:-1:-1 */ 0
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                value_4 := calldataload(/** @src 2:28963:28975  "source.nonce" */ add(var_source_offset, 288))
                /// @src 2:28670:28985  "GnosisSafeTx.Transaction(..."
                let expr_1927_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ allocate_memory()
                /// @src 2:28670:28985  "GnosisSafeTx.Transaction(..."
                write_to_memory_address(expr_1927_mpos, expr)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ add(expr_1927_mpos, /** @src 2:28731:28743  "source.value" */ 32), /** @src 2:4462:4464  "22" */ value)
                mstore(/** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ add(expr_1927_mpos, /** @src 2:28757:28768  "source.data" */ 64), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ abi_decode_available_length_bytes(/** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ expr_1912_offset, expr_1912_length, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ calldatasize()))
                /// @src 2:28670:28985  "GnosisSafeTx.Transaction(..."
                write_to_memory_uint8(add(expr_1927_mpos, /** @src 2:28782:28798  "source.operation" */ 96), /** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ expr_1)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ add(expr_1927_mpos, /** @src 2:28812:28828  "source.safeTxGas" */ 128), /** @src 2:4462:4464  "22" */ value_1)
                mstore(/** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ add(expr_1927_mpos, /** @src 2:28842:28856  "source.baseGas" */ 160), /** @src 2:4462:4464  "22" */ value_2)
                mstore(/** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ add(expr_1927_mpos, /** @src 2:28870:28885  "source.gasPrice" */ 192), /** @src 2:4462:4464  "22" */ value_3)
                /// @src 2:28670:28985  "GnosisSafeTx.Transaction(..."
                write_to_memory_address(add(expr_1927_mpos, /** @src 2:28899:28914  "source.gasToken" */ 224), /** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ expr_2)
                write_to_memory_address(add(expr_1927_mpos, /** @src 2:28928:28949  "source.refundReceiver" */ 256), /** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ expr_3)
                /// @src 2:4462:4464  "22"
                mstore(/** @src 2:28670:28985  "GnosisSafeTx.Transaction(..." */ add(expr_1927_mpos, /** @src 2:28963:28975  "source.nonce" */ 288), /** @src 2:4462:4464  "22" */ value_4)
                /// @src 2:28661:28985  "target = GnosisSafeTx.Transaction(..."
                var_target_mpos := expr_1927_mpos
            }
            /// @src 1:586:668  "keccak256(..."
            function abi_encode_bytes32_uint256_address(headStart, value1, value2) -> tail
            {
                tail := add(headStart, 96)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, /** @src 1:586:668  "keccak256(..." */ 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 1:586:668  "keccak256(..." */ add(headStart, 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                mstore(/** @src 1:586:668  "keccak256(..." */ add(headStart, 64), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value2, sub(shl(160, 1), 1)))
            }
            /// @src 1:719:963  "keccak256(..."
            function abi_encode_bytes32_address_uint256_bytes32_uint8_uint256_uint256_uint256_address_address_uint256(headStart, value1, value2, value3, value4, value5, value6, value7, value8, value9, value10) -> tail
            {
                tail := add(headStart, 352)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(headStart, /** @src 1:719:963  "keccak256(..." */ 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 32), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value1, sub(shl(160, 1), 1)))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 64), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value2)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 96), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value3)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 128), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value4, 0xff))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 160), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value5)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 192), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value6)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 224), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value7)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 256), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value8, sub(shl(160, 1), 1)))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 288), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(value9, sub(shl(160, 1), 1)))
                mstore(/** @src 1:719:963  "keccak256(..." */ add(headStart, 320), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value10)
            }
            /// @src 1:719:963  "keccak256(..."
            function abi_encode_packed_stringliteral_301a_bytes32_bytes32(pos, value0, value1) -> end
            {
                mstore(pos, shl(240, 6401))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 1:719:963  "keccak256(..." */ add(pos, 2), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value0)
                mstore(/** @src 1:719:963  "keccak256(..." */ add(pos, 34), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ value1)
                /// @src 1:719:963  "keccak256(..."
                end := add(pos, 66)
            }
            /// @ast-id 132 @src 1:970:1709  "function digest(..."
            function fun_digest(var_txData_mpos, var_chainId, var_safe) -> var
            {
                /// @src 1:1143:1241  "abi.encode(..."
                let expr_88_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 1:1143:1241  "abi.encode(..."
                let _1 := add(expr_88_mpos, 0x20)
                let _2 := sub(abi_encode_bytes32_uint256_address(_1, var_chainId, var_safe), expr_88_mpos)
                mstore(expr_88_mpos, add(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 1:1143:1241  "abi.encode(..."
                finalize_allocation(expr_88_mpos, _2)
                /// @src 1:1133:1242  "keccak256(abi.encode(..."
                let expr := keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1133:1242  "keccak256(abi.encode(..." */ expr_88_mpos))
                /// @src 1:1337:1346  "txData.to"
                let _3 := /** @src 2:4462:4464  "22" */ cleanup_address_payable(mload(/** @src 1:1337:1346  "txData.to" */ var_txData_mpos))
                /// @src 2:4462:4464  "22"
                let _4 := mload(/** @src 1:1360:1372  "txData.value" */ add(var_txData_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20))
                /// @src 1:1396:1407  "txData.data"
                let _855_mpos := mload(add(var_txData_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64))
                /// @src 1:1386:1408  "keccak256(txData.data)"
                let expr_1 := keccak256(/** @src 2:4462:4464  "22" */ add(/** @src 1:1386:1408  "keccak256(txData.data)" */ _855_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1386:1408  "keccak256(txData.data)" */ _855_mpos))
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
                let expr_119_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 1:1283:1625  "abi.encode(..."
                let _12 := add(expr_119_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20)
                /// @src 1:1283:1625  "abi.encode(..."
                let _13 := sub(abi_encode_bytes32_address_uint256_bytes32_uint8_uint256_uint256_uint256_address_address_uint256(_12, _3, _4, expr_1, _5, _6, _7, _8, _9, _10, _11), expr_119_mpos)
                mstore(expr_119_mpos, add(_13, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 1:1283:1625  "abi.encode(..."
                finalize_allocation(expr_119_mpos, _13)
                /// @src 1:1273:1626  "keccak256(abi.encode(..."
                let expr_2 := keccak256(/** @src 2:4462:4464  "22" */ _12, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1273:1626  "keccak256(abi.encode(..." */ expr_119_mpos))
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                let expr_128_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                let _14 := add(expr_128_mpos, /** @src 1:1143:1241  "abi.encode(..." */ 0x20)
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                let _15 := sub(abi_encode_packed_stringliteral_301a_bytes32_bytes32(_14, expr, expr_2), expr_128_mpos)
                mstore(expr_128_mpos, add(_15, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 1:1653:1701  "abi.encodePacked(\"\\x19\\x01\", domain, structHash)"
                finalize_allocation(expr_128_mpos, _15)
                /// @src 1:1636:1702  "return keccak256(abi.encodePacked(\"\\x19\\x01\", domain, structHash))"
                var := /** @src 1:1643:1702  "keccak256(abi.encodePacked(\"\\x19\\x01\", domain, structHash))" */ keccak256(/** @src 2:4462:4464  "22" */ _14, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 1:1643:1702  "keccak256(abi.encodePacked(\"\\x19\\x01\", domain, structHash))" */ expr_128_mpos))
            }
            /// @ast-id 3474 @src 7:2129:2907  "function tryRecover(..."
            function fun_tryRecover(var_hash, var_signature_mpos) -> var_recovered, var_err, var_errArg
            {
                /// @src 7:2299:2315  "signature.length"
                let expr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 7:2299:2315  "signature.length" */ var_signature_mpos)
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
                    let expr_3455_component, expr_3455_component_1, expr_3455_component_2 := fun_tryRecover_3662(var_hash, /** @src 7:2535:2731  "assembly (\"memory-safe\") {..." */ byte(/** @src -1:-1:-1 */ 0, /** @src 7:2535:2731  "assembly (\"memory-safe\") {..." */ mload(add(var_signature_mpos, 0x60))), /** @src 7:2751:2776  "tryRecover(hash, v, r, s)" */ var_r, /** @src 7:2535:2731  "assembly (\"memory-safe\") {..." */ mload(add(var_signature_mpos, 0x40)))
                    /// @src 7:2744:2776  "return tryRecover(hash, v, r, s)"
                    var_recovered := expr_3455_component
                    var_err := expr_3455_component_1
                    var_errArg := expr_3455_component_2
                    leave
                }
            }
            /// @ast-id 2359 @src 2:32225:32772  "function _isGovernanceOwner(address account) internal view returns (bool) {..."
            function fun_isGovernanceOwner(var_account) -> var
            {
                /// @src 2:32309:32320  "uint256 low"
                let var_low := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:32309:32320  "uint256 low"
                var_low := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
                /// @src 2:32330:32368  "uint256 high = governanceOwners.length"
                let var_high := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sload(/** @src 2:32345:32361  "governanceOwners" */ 0x09)
                /// @src 2:32330:32368  "uint256 high = governanceOwners.length"
                let var_high_1 := var_high
                /// @src 2:32378:32652  "while (low < high) {..."
                for { }
                /** @src 2:32385:32395  "low < high" */ lt(var_low, var_high)
                /// @src 2:32378:32652  "while (low < high) {..."
                { }
                {
                    /// @src 2:2993:2996  "300"
                    let sum := add(var_low, var_high)
                    if gt(var_low, sum) { panic_error_0x11() }
                    /// @src 2:32428:32444  "(low + high) / 2"
                    let expr := checked_div_uint256_18642(/** @src 2:32429:32439  "low + high" */ sum)
                    /// @src 2:32478:32502  "governanceOwners[middle]"
                    let _1, _2 := storage_array_index_access_address_dyn(expr)
                    let _3 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_dynamict_address_payable(sload(/** @src 2:32478:32502  "governanceOwners[middle]" */ _1), _2)
                    /// @src 2:32516:32642  "if (candidate < account) {..."
                    switch /** @src 2:32520:32539  "candidate < account" */ lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:32520:32539  "candidate < account" */ _3, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)), and(/** @src 2:32520:32539  "candidate < account" */ var_account, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                    case /** @src 2:32516:32642  "if (candidate < account) {..." */ 0 {
                        /// @src 2:32614:32627  "high = middle"
                        var_high := expr
                    }
                    default /// @src 2:32516:32642  "if (candidate < account) {..."
                    {
                        /// @src 2:32559:32575  "low = middle + 1"
                        var_low := /** @src 2:32565:32575  "middle + 1" */ checked_add_uint256_18393(expr)
                    }
                }
                /// @src 2:32665:32730  "low < governanceOwners.length && governanceOwners[low] == account"
                let expr_1 := /** @src 2:32665:32694  "low < governanceOwners.length" */ lt(var_low, var_high_1)
                /// @src 2:32665:32730  "low < governanceOwners.length && governanceOwners[low] == account"
                if expr_1
                {
                    /// @src 2:32698:32719  "governanceOwners[low]"
                    let _4, _5 := storage_array_index_access_address_dyn(var_low)
                    let _6 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ extract_from_storage_value_dynamict_address_payable(sload(/** @src 2:32698:32719  "governanceOwners[low]" */ _4), _5)
                    /// @src 2:32665:32730  "low < governanceOwners.length && governanceOwners[low] == account"
                    expr_1 := /** @src 2:32698:32730  "governanceOwners[low] == account" */ eq(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:32698:32730  "governanceOwners[low] == account" */ _6, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)), and(/** @src 2:32698:32730  "governanceOwners[low] == account" */ var_account, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                }
                /// @src 2:32661:32743  "if (low < governanceOwners.length && governanceOwners[low] == account) return true"
                if expr_1
                {
                    /// @src 2:32732:32743  "return true"
                    var := /** @src 2:32739:32743  "true" */ 0x01
                    /// @src 2:32732:32743  "return true"
                    leave
                }
                /// @src 2:32753:32765  "return false"
                var := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 0
            }
            /// @ast-id 2426 @src 2:32778:33247  "function _validateGovernanceOwners(address[] memory owners, uint256 threshold) internal pure {..."
            function fun_validateGovernanceOwners(var_owners_2362_mpos, var_threshold)
            {
                /// @src 2:32885:32898  "owners.length"
                let expr := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:32885:32898  "owners.length" */ var_owners_2362_mpos)
                /// @src 2:32885:32921  "owners.length == 0 || threshold == 0"
                let expr_1 := /** @src 2:32885:32903  "owners.length == 0" */ iszero(expr)
                /// @src 2:32885:32921  "owners.length == 0 || threshold == 0"
                if iszero(expr_1)
                {
                    expr_1 := /** @src 2:32907:32921  "threshold == 0" */ iszero(var_threshold)
                }
                /// @src 2:32885:32950  "owners.length == 0 || threshold == 0 || threshold > owners.length"
                let expr_2 := expr_1
                if iszero(expr_1)
                {
                    expr_2 := /** @src 2:32925:32950  "threshold > owners.length" */ gt(var_threshold, expr)
                }
                /// @src 2:32881:33021  "if (owners.length == 0 || threshold == 0 || threshold > owners.length) {..."
                if expr_2
                {
                    /// @src 2:32973:33010  "InvalidGovernanceOwnerConfiguration()"
                    mstore(/** @src 2:32902:32903  "0" */ 0x00, /** @src 2:29669:29706  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                    /// @src 2:32973:33010  "InvalidGovernanceOwnerConfiguration()"
                    revert(/** @src 2:32902:32903  "0" */ 0x00, /** @src 2:32973:33010  "InvalidGovernanceOwnerConfiguration()" */ 4)
                }
                /// @src 2:33035:33044  "uint256 i"
                let var_i := /** @src 2:32902:32903  "0" */ 0x00
                /// @src 2:33035:33044  "uint256 i"
                var_i := /** @src 2:32902:32903  "0" */ 0x00
                /// @src 2:33030:33241  "for (uint256 i; i < owners.length; ++i) {..."
                for { }
                /** @src 2:2993:2996  "300" */ 1
                /// @src 2:33035:33044  "uint256 i"
                {
                    /// @src 2:33065:33068  "++i"
                    var_i := /** @src 2:2993:2996  "300" */ add(/** @src 2:33065:33068  "++i" */ var_i, /** @src 2:2993:2996  "300" */ 1)
                }
                /// @src 2:33065:33068  "++i"
                {
                    /// @src 2:33046:33063  "i < owners.length"
                    if iszero(lt(var_i, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 2:33050:33063  "owners.length" */ var_owners_2362_mpos)))
                    /// @src 2:33046:33063  "i < owners.length"
                    { break }
                    /// @src 2:33088:33152  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    let expr_3 := /** @src 2:33088:33111  "owners[i] == address(0)" */ iszero(cleanup_address_payable(/** @src 2:33088:33097  "owners[i]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(var_owners_2362_mpos, var_i))))
                    /// @src 2:33088:33152  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                    if iszero(expr_3)
                    {
                        /// @src 2:33116:33151  "i > 0 && owners[i - 1] >= owners[i]"
                        let expr_4 := /** @src 2:33116:33121  "i > 0" */ iszero(iszero(var_i))
                        /// @src 2:33116:33151  "i > 0 && owners[i - 1] >= owners[i]"
                        if expr_4
                        {
                            /// @src 2:33125:33138  "owners[i - 1]"
                            let _1 := read_from_memoryt_address(memory_array_index_access_uint16_dyn(var_owners_2362_mpos, /** @src 2:33132:33137  "i - 1" */ checked_sub_uint256_18646(var_i)))
                            /// @src 2:33116:33151  "i > 0 && owners[i - 1] >= owners[i]"
                            expr_4 := /** @src 2:33125:33151  "owners[i - 1] >= owners[i]" */ iszero(lt(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:33125:33151  "owners[i - 1] >= owners[i]" */ _1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)), /** @src 2:33125:33151  "owners[i - 1] >= owners[i]" */ cleanup_address_payable(/** @src 2:33142:33151  "owners[i]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(var_owners_2362_mpos, var_i)))))
                        }
                        /// @src 2:33088:33152  "owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])"
                        expr_3 := expr_4
                    }
                    /// @src 2:33084:33231  "if (owners[i] == address(0) || (i > 0 && owners[i - 1] >= owners[i])) {..."
                    if expr_3
                    {
                        /// @src 2:33179:33216  "InvalidGovernanceOwnerConfiguration()"
                        mstore(/** @src 2:32902:32903  "0" */ 0x00, /** @src 2:29669:29706  "InvalidGovernanceOwnerConfiguration()" */ shl(224, 0x3374c57f))
                        /// @src 2:33179:33216  "InvalidGovernanceOwnerConfiguration()"
                        revert(/** @src 2:32902:32903  "0" */ 0x00, /** @src 2:33179:33216  "InvalidGovernanceOwnerConfiguration()" */ 4)
                    }
                }
            }
            /// @ast-id 2445 @src 2:33253:33478  "function _governanceOwnerConfigHash(uint256 threshold, address[] memory owners) internal view returns (bytes32) {..."
            function fun_governanceOwnerConfigHash(var_threshold, var_owners_mpos) -> var
            {
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                let expr_mpos := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                let _1 := add(expr_mpos, 0x20)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(_1, /** @src 0:224:350  "keccak256(..." */ 0xb4237fcada7bd9adba2337f1358a57af9f53602d06e3622b52390b2178c62c41)
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 0:224:350  "keccak256(..." */ add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 64), /** @src 2:33412:33435  "governanceSourceChainId" */ loadimmutable("468"))
                /// @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..."
                mstore(/** @src 0:224:350  "keccak256(..." */ add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 0:224:350  "keccak256(..." */ 96), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 2:33437:33451  "governanceSafe" */ loadimmutable("471"), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
                mstore(/** @src 0:224:350  "keccak256(..." */ add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 0:224:350  "keccak256(..." */ 128), /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ var_threshold)
                /// @src 0:224:350  "keccak256(..."
                mstore(add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 0:224:350  "keccak256(..." */ 160), 160)
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                let _2 := sub(/** @src 0:224:350  "keccak256(..." */ abi_encode_array_address_dyn(var_owners_mpos, add(/** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos, /** @src 0:224:350  "keccak256(..." */ 192)), /** @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)" */ expr_mpos)
                mstore(expr_mpos, add(_2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ not(31)))
                /// @src 0:560:633  "abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners)"
                finalize_allocation(expr_mpos, _2)
                /// @src 2:33375:33471  "return GSSGovernance.ownerConfigHash(governanceSourceChainId, governanceSafe, threshold, owners)"
                var := /** @src 0:550:634  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners))" */ keccak256(/** @src 2:4462:4464  "22" */ _1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(/** @src 0:550:634  "keccak256(abi.encode(OWNER_CONFIG_TYPEHASH, sourceChainId, safe, threshold, owners))" */ expr_mpos))
            }
            /// @ast-id 3662 @src 7:5203:6754  "function tryRecover(..."
            function fun_tryRecover_3662(var_hash, var_v, var_r, var_s) -> var_recovered, var_err, var_errArg
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
                let _1 := /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ mload(64)
                mstore(_1, var_hash)
                mstore(add(_1, 32), and(var_v, 0xff))
                mstore(add(_1, 64), var_r)
                mstore(add(_1, 96), var_s)
                /// @src 7:6541:6565  "ecrecover(hash, v, r, s)"
                mstore(/** @src -1:-1:-1 */ 0, 0)
                /// @src 7:6541:6565  "ecrecover(hash, v, r, s)"
                if iszero(staticcall(gas(), 1, _1, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 128, /** @src -1:-1:-1 */ 0, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ 32))
                /// @src 7:6541:6565  "ecrecover(hash, v, r, s)"
                { revert_forward() }
                let _2 := mload(/** @src -1:-1:-1 */ 0)
                /// @src 7:6575:6688  "if (signer == address(0)) {..."
                if /** @src 7:6579:6599  "signer == address(0)" */ iszero(/** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ and(/** @src 7:6579:6599  "signer == address(0)" */ _2, /** @src 2:733:93141  "contract Relay is IIRelay, IRelayGovernance {..." */ sub(shl(160, 1), 1)))
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
        }
        data ".metadata" hex"a264697066735822122002f04132a8d8d1dd527f0c632b75aaefae5f3f9971a88cbe7251707844333ca864736f6c634300081b0033"
    }
}
