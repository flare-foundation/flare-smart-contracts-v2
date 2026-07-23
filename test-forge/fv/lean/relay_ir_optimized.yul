/// @use-src 0:"contracts/protocol/implementation/Relay.sol", 1:"contracts/protocol/interface/IIRelay.sol", 2:"contracts/userInterfaces/IRelay.sol", 3:"contracts/userInterfaces/LTS/RandomNumberV2Interface.sol"
object "Relay_2022" {
    code {
        {
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let _1 := memoryguard(0xe0)
            mstore(64, _1)
            if callvalue() { revert(0, 0) }
            let programSize := datasize("Relay_2022")
            let argSize := sub(codesize(), programSize)
            finalize_allocation(_1, argSize)
            codecopy(_1, programSize, argSize)
            let _2 := add(_1, argSize)
            if slt(sub(_2, _1), 96)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let offset := mload(_1)
            if gt(offset, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let _3 := add(_1, offset)
            if slt(sub(_2, _3), 0x0180)
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let memPtr := mload(64)
            let newFreePtr := add(memPtr, 0x0180)
            if or(gt(newFreePtr, sub(shl(64, 1), 1)), lt(newFreePtr, memPtr))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x24)
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
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let _21 := add(memPtr, 320)
            mstore(_21, value_1)
            let offset_1 := mload(add(_3, 352))
            if gt(offset_1, sub(shl(64, 1), 1))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let _22 := add(_3, offset_1)
            if iszero(slt(add(_22, 31), _2))
            {
                revert(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let length := mload(_22)
            if gt(length, sub(shl(64, 1), 1))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x24)
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
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let src := add(_22, 32)
            for { } lt(src, srcEnd) { src := add(src, 64) }
            {
                if slt(sub(_2, src), 64)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let memPtr_2 := mload(64)
                let newFreePtr_1 := add(memPtr_2, 64)
                if or(gt(newFreePtr_1, sub(shl(64, 1), 1)), lt(newFreePtr_1, memPtr_2))
                {
                    mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                    mstore(4, 0x41)
                    revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x24)
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
            if /** @src 0:10504:10558  "_initialConfig.thresholdIncreaseBIPS >= THRESHOLD_BIPS" */ lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(mload(/** @src 0:10504:10540  "_initialConfig.thresholdIncreaseBIPS" */ _18), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffff), /** @src 0:2387:2392  "10000" */ 0x2710)
            {
                let memPtr_3 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_3, shl(229, 4594637))
                mstore(add(memPtr_3, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_3, 36), 28)
                mstore(add(memPtr_3, 68), "threshold increase too small")
                revert(memPtr_3, 100)
            }
            if /** @src 0:10711:10763  "_initialConfig.rewardEpochDurationInVotingEpochs > 0" */ iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(mload(/** @src 0:10711:10759  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _16), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffff))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_4 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_4, shl(229, 4594637))
                mstore(add(memPtr_4, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_4, 36), 26)
                mstore(add(memPtr_4, 68), "reward epoch duration zero")
                revert(memPtr_4, 100)
            }
            if /** @src 0:10812:10857  "_initialConfig.votingEpochDurationSeconds > 0" */ iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:10812:10853  "_initialConfig.votingEpochDurationSeconds" */ _12), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_5 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_5, shl(229, 4594637))
                mstore(add(memPtr_5, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_5, 36), 26)
                mstore(add(memPtr_5, 68), "voting epoch duration zero")
                revert(memPtr_5, 100)
            }
            if /** @src 0:11355:11408  "_initialConfig.initialSigningPolicyHash != bytes32(0)" */ iszero(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11355:11394  "_initialConfig.initialSigningPolicyHash" */ _6))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_6 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_6, shl(229, 4594637))
                mstore(add(memPtr_6, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_6, 36), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_6, 68), "initial signing policy hash zero")
                revert(memPtr_6, 100)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let cleaned := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11476:11525  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _14), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
            let cleaned_1 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11540:11575  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            let product_raw := mul(cleaned_1, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(mload(/** @src 0:11578:11626  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _16), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffff))
            /// @src 0:2387:2392  "10000"
            let product := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ product_raw, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            if iszero(eq(product, product_raw))
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                /// @src 0:2387:2392  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ 0x24)
            }
            let sum := add(cleaned, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ product)
            /// @src 0:2387:2392  "10000"
            if gt(sum, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                /// @src 0:2387:2392  "10000"
                mstore(4, 0x11)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ 0x24)
            }
            if /** @src 0:11476:11701  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:11476:11701  "_initialConfig.firstRewardEpochStartVotingRoundId +..." */ sum, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff), and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11642:11701  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _5), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_7 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_7, shl(229, 4594637))
                mstore(add(memPtr_7, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_7, 36), 40)
                mstore(add(memPtr_7, 68), "invalid initial starting voting ")
                mstore(add(memPtr_7, 100), "round id")
                revert(memPtr_7, 132)
            }
            /// @src 0:11777:11835  "initialRewardEpochId = _initialConfig.initialRewardEpochId"
            mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 160, and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11800:11835  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:11845:11963  "startingVotingRoundIdForInitialRewardEpochId =..."
            mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 192, and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:11904:11963  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _5), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
            let _25 := and(/** @src 0:2387:2392  "10000" */ value1, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:11973:12015  "signingPolicySetter = _signingPolicySetter" */ 0x03, /** @src 0:2387:2392  "10000" */ or(and(sload(/** @src 0:11973:12015  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 0:2387:2392  "10000" */ not(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))), /** @src 0:2387:2392  "10000" */ _25))
            let _26 := mload(/** @src 0:12506:12541  "_initialConfig.initialRewardEpochId" */ memPtr)
            /// @src 0:2387:2392  "10000"
            let _27 := sload(/** @src 0:12467:12476  "stateData" */ 0x07)
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:12467:12476  "stateData" */ 0x07, /** @src 0:2387:2392  "10000" */ or(and(_27, not(shl(152, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:2387:2392  "10000" */ and(shl(152, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ _26), /** @src 0:2387:2392  "10000" */ shl(152, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))))
            let cleaned_2 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12625:12684  "_initialConfig.startingVotingRoundIdForInitialRewardEpochId" */ _5), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
            /// @src 0:2387:2392  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(_26, 0xffffffff))
            /// @src 0:2387:2392  "10000"
            mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32, /** @src 0:12551:12573  "startingVotingRoundIds" */ 0x02)
            /// @src 0:2387:2392  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64), /** @src 0:2387:2392  "10000" */ cleaned_2)
            let _28 := mload(/** @src 0:12760:12799  "_initialConfig.initialSigningPolicyHash" */ _6)
            /// @src 0:2387:2392  "10000"
            mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12721:12756  "_initialConfig.initialRewardEpochId" */ memPtr), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:2387:2392  "10000"
            mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32, /** @src -1:-1:-1 */ 0)
            /// @src 0:2387:2392  "10000"
            sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64), /** @src 0:2387:2392  "10000" */ _28)
            if iszero(/** @src 0:12817:12858  "_initialConfig.randomNumberProtocolId > 1" */ gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12817:12854  "_initialConfig.randomNumberProtocolId" */ _8), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff), 1))
            /// @src 0:2387:2392  "10000"
            {
                let memPtr_8 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_8, shl(229, 4594637))
                mstore(add(memPtr_8, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_8, 36), 37)
                mstore(add(memPtr_8, 68), "random number protocol id must b")
                mstore(add(memPtr_8, 100), "e > 1")
                revert(memPtr_8, 132)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let cleaned_3 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:12945:12982  "_initialConfig.randomNumberProtocolId" */ _8), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff)
            /// @src 0:2387:2392  "10000"
            let _29 := sload(/** @src 0:12467:12476  "stateData" */ 0x07)
            /// @src 0:2387:2392  "10000"
            let toInsert := and(shl(8, mload(/** @src 0:13028:13066  "_initialConfig.firstVotingRoundStartTs" */ _10)), /** @src 0:2387:2392  "10000" */ 0xffffffff00)
            let toInsert_1 := and(shl(40, mload(/** @src 0:13115:13156  "_initialConfig.votingEpochDurationSeconds" */ _12)), /** @src 0:2387:2392  "10000" */ 0xff0000000000)
            let toInsert_2 := and(shl(48, mload(/** @src 0:13213:13262  "_initialConfig.firstRewardEpochStartVotingRoundId" */ _14)), /** @src 0:2387:2392  "10000" */ 0xffffffff000000000000)
            let toInsert_3 := and(shl(80, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:13318:13366  "_initialConfig.rewardEpochDurationInVotingEpochs" */ _16)), /** @src 0:2387:2392  "10000" */ 0xffff00000000000000000000)
            let toInsert_4 := and(shl(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 96, mload(/** @src 0:13410:13446  "_initialConfig.thresholdIncreaseBIPS" */ _18)), /** @src 0:2387:2392  "10000" */ 0xffff000000000000000000000000)
            let toInsert_5 := and(shl(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 192, /** @src 0:2387:2392  "10000" */ mload(/** @src 0:13508:13562  "_initialConfig.messageFinalizationWindowInRewardEpochs" */ _20)), /** @src 0:2387:2392  "10000" */ shl(192, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
            /// @src 0:2387:2392  "10000"
            let _30 := or(toInsert_3, and(or(toInsert_2, and(or(toInsert_1, and(or(toInsert, and(or(and(_29, not(0xffffffffffff)), cleaned_3), not(0xffffffff000000000000))), not(0xffff00000000000000000000))), not(0xffff000000000000000000000000))), not(shl(192, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))))
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:12467:12476  "stateData" */ 0x07, /** @src 0:2387:2392  "10000" */ or(or(toInsert_4, _30), toInsert_5))
            /// @src 0:13576:13610  "_signingPolicySetter != address(0)"
            let _31 := iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _25)
            /// @src 0:13576:13610  "_signingPolicySetter != address(0)"
            let expr := iszero(_31)
            /// @src 0:13572:13755  "if (_signingPolicySetter != address(0)) {..."
            if expr
            {
                /// @src 0:2387:2392  "10000"
                if iszero(/** @src 0:13634:13671  "_initialConfig.feeConfigs.length == 0" */ iszero(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:13634:13659  "_initialConfig.feeConfigs" */ mload(_23))))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_9 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_9, shl(229, 4594637))
                    mstore(add(memPtr_9, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_9, 36), 17)
                    mstore(add(memPtr_9, 68), "fee cannot be set")
                    revert(memPtr_9, 100)
                }
                sstore(/** @src 0:12467:12476  "stateData" */ 0x07, /** @src 0:2387:2392  "10000" */ or(or(toInsert_5, or(toInsert_4, and(_30, not(shl(184, 255))))), shl(184, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 1)))
            }
            let cleaned_4 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:13787:13822  "_initialConfig.feeCollectionAddress" */ _21), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
            /// @src 0:2387:2392  "10000"
            sstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 5, /** @src 0:2387:2392  "10000" */ or(and(sload(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 5), /** @src 0:2387:2392  "10000" */ not(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))), /** @src 0:2387:2392  "10000" */ cleaned_4))
            /// @src 0:14058:14145  "_signingPolicySetter != address(0) || _initialConfig.feeCollectionAddress != address(0)"
            let expr_1 := expr
            if _31
            {
                expr_1 := /** @src 0:14096:14145  "_initialConfig.feeCollectionAddress != address(0)" */ iszero(iszero(cleaned_4))
            }
            /// @src 0:2387:2392  "10000"
            if iszero(expr_1)
            {
                let memPtr_10 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:2387:2392  "10000"
                mstore(memPtr_10, shl(229, 4594637))
                mstore(add(memPtr_10, 4), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:2387:2392  "10000"
                mstore(add(memPtr_10, 36), 27)
                mstore(add(memPtr_10, 68), "fee collection address zero")
                revert(memPtr_10, 100)
            }
            /// @src 0:14213:14226  "uint256 i = 0"
            let var_i := /** @src -1:-1:-1 */ 0
            /// @src 0:14208:14496  "for (uint256 i = 0; i < _initialConfig.feeConfigs.length; i++) {..."
            for { }
            /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 1
            /// @src 0:14213:14226  "uint256 i = 0"
            {
                /// @src 0:14266:14269  "i++"
                var_i := /** @src 0:2387:2392  "10000" */ add(/** @src 0:14266:14269  "i++" */ var_i, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 1)
            }
            /// @src 0:14266:14269  "i++"
            {
                /// @src 0:14232:14257  "_initialConfig.feeConfigs"
                let _mpos := mload(_23)
                /// @src 0:14228:14264  "i < _initialConfig.feeConfigs.length"
                if iszero(lt(var_i, /** @src 0:2387:2392  "10000" */ mload(/** @src 0:14232:14264  "_initialConfig.feeConfigs.length" */ _mpos)))
                /// @src 0:14228:14264  "i < _initialConfig.feeConfigs.length"
                { break }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let cleaned_5 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:14304:14332  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(_mpos, var_i))), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff)
                /// @src 0:2387:2392  "10000"
                if iszero(/** @src 0:14365:14379  "protocolId > 1" */ gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ cleaned_5, 1))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_11 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_11, shl(229, 4594637))
                    mstore(add(memPtr_11, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_11, 36), 19)
                    mstore(add(memPtr_11, 68), "invalid protocol id")
                    revert(memPtr_11, 100)
                }
                let _32 := mload(/** @src 0:14448:14485  "_initialConfig.feeConfigs[i].feeInWei" */ add(/** @src 0:14448:14476  "_initialConfig.feeConfigs[i]" */ mload(memory_array_index_access_struct_FeeConfig_dyn(/** @src 0:14448:14473  "_initialConfig.feeConfigs" */ mload(_23), /** @src 0:14448:14476  "_initialConfig.feeConfigs[i]" */ var_i)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32))
                /// @src 0:2387:2392  "10000"
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ cleaned_5)
                mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04)
                /// @src 0:2387:2392  "10000"
                sstore(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64), /** @src 0:2387:2392  "10000" */ _32)
            }
            /// @src 0:14505:14525  "oldRelay = _oldRelay"
            mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 128, /** @src 0:14505:14525  "oldRelay = _oldRelay" */ value_2)
            /// @src 0:14616:15929  "if(oldRelay != IIRelay(address(0))) {..."
            if /** @src 0:14619:14650  "oldRelay != IIRelay(address(0))" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _24))
            /// @src 0:14616:15929  "if(oldRelay != IIRelay(address(0))) {..."
            {
                /// @src 0:14692:14725  "signingPolicySetter != address(0)"
                let _33 := iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ sload(/** @src 0:11973:12015  "signingPolicySetter = _signingPolicySetter" */ 0x03), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
                /// @src 0:14692:14773  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                let expr_2 := /** @src 0:14692:14725  "signingPolicySetter != address(0)" */ iszero(_33)
                /// @src 0:14692:14773  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                if expr_2
                {
                    /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                    let _34 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                    mstore(_34, /** @src 0:2387:2392  "10000" */ shl(224, 0xa9dbe8ed))
                    /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                    let _35 := staticcall(gas(), _24, _34, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04, /** @src 0:14729:14759  "oldRelay.signingPolicySetter()" */ _34, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                    if iszero(_35)
                    {
                        /// @src 0:2387:2392  "10000"
                        let pos := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                        /// @src 0:2387:2392  "10000"
                        returndatacopy(pos, /** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ returndatasize())
                        revert(pos, returndatasize())
                    }
                    /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                    let expr_3 := /** @src -1:-1:-1 */ 0
                    /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                    if _35
                    {
                        let _36 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32
                        /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                        if gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32, /** @src 0:14729:14759  "oldRelay.signingPolicySetter()" */ returndatasize()) { _36 := returndatasize() }
                        finalize_allocation(_34, _36)
                        /// @src 0:2387:2392  "10000"
                        if slt(sub(/** @src 0:14729:14759  "oldRelay.signingPolicySetter()" */ add(_34, _36), /** @src 0:2387:2392  "10000" */ _34), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                        /// @src 0:2387:2392  "10000"
                        {
                            /// @src 0:397:84701  "contract Relay is IIRelay {..."
                            revert(/** @src -1:-1:-1 */ 0, 0)
                        }
                        /// @src 0:14729:14759  "oldRelay.signingPolicySetter()"
                        expr_3 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ abi_decode_address_fromMemory(/** @src 0:2387:2392  "10000" */ _34)
                    }
                    /// @src 0:14692:14773  "signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)"
                    expr_2 := /** @src 0:14729:14773  "oldRelay.signingPolicySetter() != address(0)" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:14729:14773  "oldRelay.signingPolicySetter() != address(0)" */ expr_3, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))))
                }
                /// @src 0:14691:14877  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                let expr_4 := expr_2
                if iszero(expr_2)
                {
                    /// @src 0:14795:14876  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                    let expr_5 := _33
                    if _33
                    {
                        /// @src 0:397:84701  "contract Relay is IIRelay {..."
                        let cleaned_6 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 128), sub(shl(160, 1), 1))
                        /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                        let _37 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                        /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                        mstore(_37, /** @src 0:2387:2392  "10000" */ shl(224, 0xa9dbe8ed))
                        /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                        let _38 := staticcall(gas(), cleaned_6, _37, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04, /** @src 0:14832:14862  "oldRelay.signingPolicySetter()" */ _37, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                        /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                        if iszero(_38)
                        {
                            /// @src 0:2387:2392  "10000"
                            let pos_1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                            /// @src 0:2387:2392  "10000"
                            returndatacopy(pos_1, /** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ returndatasize())
                            revert(pos_1, returndatasize())
                        }
                        /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                        let expr_6 := /** @src -1:-1:-1 */ 0
                        /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                        if _38
                        {
                            let _39 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32
                            /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                            if gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32, /** @src 0:14832:14862  "oldRelay.signingPolicySetter()" */ returndatasize()) { _39 := returndatasize() }
                            finalize_allocation(_37, _39)
                            /// @src 0:2387:2392  "10000"
                            if slt(sub(/** @src 0:14832:14862  "oldRelay.signingPolicySetter()" */ add(_37, _39), /** @src 0:2387:2392  "10000" */ _37), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                            /// @src 0:2387:2392  "10000"
                            {
                                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                                revert(/** @src -1:-1:-1 */ 0, 0)
                            }
                            /// @src 0:14832:14862  "oldRelay.signingPolicySetter()"
                            expr_6 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ abi_decode_address_fromMemory(/** @src 0:2387:2392  "10000" */ _37)
                        }
                        /// @src 0:14795:14876  "signingPolicySetter == address(0) && oldRelay.signingPolicySetter() == address(0)"
                        expr_5 := /** @src 0:14832:14876  "oldRelay.signingPolicySetter() == address(0)" */ iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:14832:14876  "oldRelay.signingPolicySetter() == address(0)" */ expr_6, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
                    }
                    /// @src 0:14691:14877  "(signingPolicySetter != address(0) && oldRelay.signingPolicySetter() != address(0)) ||..."
                    expr_4 := expr_5
                }
                /// @src 0:2387:2392  "10000"
                if iszero(expr_4)
                {
                    let memPtr_12 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_12, shl(229, 4594637))
                    mstore(add(memPtr_12, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_12, 36), 22)
                    mstore(add(memPtr_12, 68), "old relay incompatible")
                    revert(memPtr_12, 100)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let cleaned_7 := and(/** @src 0:2387:2392  "10000" */ mload(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 128), sub(shl(160, 1), 1))
                /// @src 0:15220:15240  "oldRelay.stateData()"
                let _40 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:15220:15240  "oldRelay.stateData()"
                mstore(_40, /** @src 0:2387:2392  "10000" */ shl(225, 0x0f47d9b5))
                /// @src 0:15220:15240  "oldRelay.stateData()"
                let _41 := staticcall(gas(), cleaned_7, _40, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04, /** @src 0:15220:15240  "oldRelay.stateData()" */ _40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 352)
                /// @src 0:15220:15240  "oldRelay.stateData()"
                if iszero(_41)
                {
                    /// @src 0:2387:2392  "10000"
                    let pos_2 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    returndatacopy(pos_2, /** @src -1:-1:-1 */ 0, /** @src 0:2387:2392  "10000" */ returndatasize())
                    revert(pos_2, returndatasize())
                }
                let expr_component := /** @src -1:-1:-1 */ 0
                let expr_component_1 := 0
                let expr_component_2 := 0
                let expr_component_3 := 0
                /// @src 0:15220:15240  "oldRelay.stateData()"
                if _41
                {
                    let _42 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 352
                    /// @src 0:15220:15240  "oldRelay.stateData()"
                    if gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _42, /** @src 0:15220:15240  "oldRelay.stateData()" */ returndatasize()) { _42 := returndatasize() }
                    finalize_allocation(_40, _42)
                    /// @src 0:2387:2392  "10000"
                    if slt(sub(/** @src 0:15220:15240  "oldRelay.stateData()" */ add(_40, _42), /** @src 0:2387:2392  "10000" */ _40), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 352)
                    /// @src 0:2387:2392  "10000"
                    {
                        /// @src 0:397:84701  "contract Relay is IIRelay {..."
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    pop(abi_decode_uint8_fromMemory(/** @src 0:2387:2392  "10000" */ _40))
                    let value1_1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32))
                    /// @src 0:2387:2392  "10000"
                    let value2 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ abi_decode_uint8_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64))
                    /// @src 0:2387:2392  "10000"
                    let value3 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 96))
                    /// @src 0:2387:2392  "10000"
                    let value4 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ abi_decode_uint16_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 128))
                    pop(abi_decode_uint16_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 160)))
                    pop(abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 192)))
                    /// @src 0:2387:2392  "10000"
                    pop(abi_decode_bool_fromMemory(add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 224)))
                    pop(abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 256)))
                    /// @src 0:2387:2392  "10000"
                    pop(abi_decode_bool_fromMemory(add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 288)))
                    pop(abi_decode_uint32_fromMemory(/** @src 0:2387:2392  "10000" */ add(_40, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 320)))
                    /// @src 0:15220:15240  "oldRelay.stateData()"
                    expr_component := value1_1
                    expr_component_1 := value2
                    expr_component_2 := value3
                    expr_component_3 := value4
                }
                /// @src 0:2387:2392  "10000"
                let _43 := sload(/** @src 0:12467:12476  "stateData" */ 0x07)
                /// @src 0:2387:2392  "10000"
                if iszero(/** @src 0:15279:15339  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ eq(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(8, _43), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff), and(/** @src 0:15279:15339  "stateData.firstVotingRoundStartTs == firstVotingRoundStartTs" */ expr_component, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_13 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_13, shl(229, 4594637))
                    mstore(add(memPtr_13, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_13, 36), 14)
                    mstore(add(memPtr_13, 68), "wrong start ts")
                    revert(memPtr_13, 100)
                }
                if iszero(/** @src 0:15426:15506  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ eq(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(80, _43), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffff), and(/** @src 0:15426:15506  "stateData.rewardEpochDurationInVotingEpochs == rewardEpochDurationInVotingEpochs" */ expr_component_3, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_14 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_14, shl(229, 4594637))
                    mstore(add(memPtr_14, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_14, 36), 27)
                    mstore(add(memPtr_14, 68), "wrong reward epoch duration")
                    revert(memPtr_14, 100)
                }
                if iszero(/** @src 0:15606:15688  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ eq(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(48, _43), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff), and(/** @src 0:15606:15688  "stateData.firstRewardEpochStartVotingRoundId == firstRewardEpochStartVotingRoundId" */ expr_component_2, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_15 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_15, shl(229, 4594637))
                    mstore(add(memPtr_15, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_15, 36), 30)
                    mstore(add(memPtr_15, 68), "wrong first reward epoch start")
                    revert(memPtr_15, 100)
                }
                if iszero(/** @src 0:15791:15857  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ eq(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2387:2392  "10000" */ shr(40, _43), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff), and(/** @src 0:15791:15857  "stateData.votingEpochDurationSeconds == votingEpochDurationSeconds" */ expr_component_1, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff)))
                /// @src 0:2387:2392  "10000"
                {
                    let memPtr_16 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2387:2392  "10000"
                    mstore(memPtr_16, shl(229, 4594637))
                    mstore(add(memPtr_16, /** @src 0:14417:14433  "protocolFeeInWei" */ 0x04), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:2387:2392  "10000"
                    mstore(add(memPtr_16, 36), 27)
                    mstore(add(memPtr_16, 68), "wrong voting epoch duration")
                    revert(memPtr_16, 100)
                }
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            let _44 := mload(64)
            let _45 := datasize("Relay_2022_deployed")
            codecopy(_44, dataoffset("Relay_2022_deployed"), _45)
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
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
                mstore(4, 0x41)
                revert(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x24)
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
                mstore(0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x4e487b71))
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
    object "Relay_2022_deployed" {
        code {
            {
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
            function abi_decode_uint256_15127() -> value
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                let ret := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_bool(_1)
                /// @src 0:9226:9252  "StateData public stateData"
                let ret_1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_24t_uint32(_1)
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                let value := and(sload(/** @src 0:8782:8825  "address payable public feeCollectionAddress" */ 5), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := calldataload(4)
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                mstore(memPos, and(/** @src 0:9819:9887  "uint32 public immutable startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function external_fun_governanceFeeNonce()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:9356:9389  "uint256 public governanceFeeNonce" */ 8)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value0, value1 := abi_decode_bytes_calldata(add(4, offset), calldatasize())
                let offset_1 := calldataload(36)
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let _1 := add(4, offset_1)
                if slt(add(sub(calldatasize(), offset_1), not(3)), 128)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:23283:23346  "require(signingPolicySetter == address(0), \"fee cannot be set\")"
                require_helper_stringliteral_59e4(/** @src 0:23291:23324  "signingPolicySetter == address(0)" */ iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(cleanup_address_payable(sload(/** @src 0:23291:23310  "signingPolicySetter" */ 0x03)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))))
                /// @src 0:23364:23379  "_config.chainId"
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := calldataload(/** @src 0:23364:23379  "_config.chainId" */ add(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ offset_1, 36))
                /// @src 0:23356:23415  "require(_config.chainId == block.chainid, \"wrong chain id\")"
                require_helper_stringliteral_0424(/** @src 0:23364:23396  "_config.chainId == block.chainid" */ eq(value, /** @src 0:23383:23396  "block.chainid" */ chainid()))
                /// @src 0:23433:23456  "_config.descriptionHash"
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value_1 := calldataload(_1)
                /// @src 0:23425:23515  "require(_config.descriptionHash == keccak256(\"RelayGovernance\"), \"wrong description hash\")"
                require_helper_stringliteral_88b2(/** @src 0:23433:23488  "_config.descriptionHash == keccak256(\"RelayGovernance\")" */ eq(value_1, /** @src 0:23460:23488  "keccak256(\"RelayGovernance\")" */ 0xba90a7502e1d792c42ae7da5cf5982d831ebf2254fd5919818faf046187d95d2))
                /// @src 0:23790:23824  "abi.encode(_config, address(this))"
                let expr_mpos := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:23790:23824  "abi.encode(_config, address(this))"
                let _2 := add(expr_mpos, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                /// @src 0:23790:23824  "abi.encode(_config, address(this))"
                let _3 := sub(abi_encode_struct_RelayGovernanceConfig_calldata_address(_2, _1, /** @src 0:23818:23822  "this" */ address()), /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ expr_mpos)
                mstore(expr_mpos, add(_3, not(31)))
                finalize_allocation(expr_mpos, _3)
                /// @src 0:23742:23826  "_verifyCustomSignature(_relayMessage, keccak256(abi.encode(_config, address(this))))"
                let expr := fun_verifyCustomSignature(value0, value1, /** @src 0:23780:23825  "keccak256(abi.encode(_config, address(this)))" */ keccak256(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _2, mload(/** @src 0:23780:23825  "keccak256(abi.encode(_config, address(this)))" */ expr_mpos)))
                /// @src 0:24124:24160  "stateData.lastInitializedRewardEpoch"
                let _4 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_uint32(sload(/** @src 0:24124:24133  "stateData" */ 0x07))
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let _5 := and(/** @src 0:24124:24183  "stateData.lastInitializedRewardEpoch == returnRewardEpochId" */ _4, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
                /// @src 0:24124:24324  "stateData.lastInitializedRewardEpoch == returnRewardEpochId ||..."
                let expr_1 := /** @src 0:24124:24183  "stateData.lastInitializedRewardEpoch == returnRewardEpochId" */ eq(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _5, /** @src 0:24124:24183  "stateData.lastInitializedRewardEpoch == returnRewardEpochId" */ expr)
                /// @src 0:24124:24324  "stateData.lastInitializedRewardEpoch == returnRewardEpochId ||..."
                if iszero(expr_1)
                {
                    /// @src 0:24200:24323  "stateData.lastInitializedRewardEpoch > 0 &&..."
                    let expr_2 := /** @src 0:24200:24240  "stateData.lastInitializedRewardEpoch > 0" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _5))
                    /// @src 0:24200:24323  "stateData.lastInitializedRewardEpoch > 0 &&..."
                    if expr_2
                    {
                        expr_2 := /** @src 0:24260:24323  "stateData.lastInitializedRewardEpoch - 1 == returnRewardEpochId" */ eq(cleanup_from_storage_uint32(/** @src 0:24260:24300  "stateData.lastInitializedRewardEpoch - 1" */ checked_sub_uint32(_4)), /** @src 0:24260:24323  "stateData.lastInitializedRewardEpoch - 1 == returnRewardEpochId" */ expr)
                    }
                    /// @src 0:24124:24324  "stateData.lastInitializedRewardEpoch == returnRewardEpochId ||..."
                    expr_1 := expr_2
                }
                /// @src 0:24103:24372  "require(..."
                require_helper_stringliteral_524a(expr_1)
                /// @src 0:24490:24503  "_config.nonce"
                let value_2 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value_2 := calldataload(/** @src 0:24490:24503  "_config.nonce" */ add(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ offset_1, /** @src 0:24490:24503  "_config.nonce" */ 68))
                /// @src 0:24482:24542  "require(_config.nonce > governanceFeeNonce, \"nonce too low\")"
                require_helper_stringliteral_6b1b(/** @src 0:24490:24524  "_config.nonce > governanceFeeNonce" */ gt(value_2, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sload(/** @src 0:24506:24524  "governanceFeeNonce" */ 0x08)))
                /// @src 0:24552:24586  "governanceFeeNonce = _config.nonce"
                update_storage_value_offsett_uint256_to_uint256(/** @src 0:24573:24586  "_config.nonce" */ value_2)
                /// @src 0:24682:24695  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 0:24701:24722  "_config.newFeeConfigs"
                let _6 := add(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ offset_1, /** @src 0:24701:24722  "_config.newFeeConfigs" */ 100)
                /// @src 0:24677:25062  "for (uint256 i = 0; i < _config.newFeeConfigs.length; i++) {..."
                for { }
                /** @src 0:24839:24840  "1" */ 0x01
                /// @src 0:24682:24695  "uint256 i = 0"
                {
                    /// @src 0:24731:24734  "i++"
                    var_i := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:24731:24734  "i++" */ var_i, /** @src 0:24839:24840  "1" */ 0x01)
                }
                /// @src 0:24731:24734  "i++"
                {
                    /// @src 0:24701:24722  "_config.newFeeConfigs"
                    let expr_offset, expr_length := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:24697:24729  "i < _config.newFeeConfigs.length"
                    if iszero(lt(var_i, /** @src 0:24701:24729  "_config.newFeeConfigs.length" */ expr_length))
                    /// @src 0:24697:24729  "i < _config.newFeeConfigs.length"
                    { break }
                    /// @src 0:24769:24790  "_config.newFeeConfigs"
                    let expr_offset_1, expr_length_1 := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:24769:24804  "_config.newFeeConfigs[i].protocolId"
                    let expr_3 := read_from_calldatat_uint8(/** @src 0:24769:24793  "_config.newFeeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(expr_offset_1, expr_length_1, var_i))
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    let _7 := and(/** @src 0:24826:24840  "protocolId > 1" */ expr_3, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff)
                    /// @src 0:24818:24864  "require(protocolId > 1, \"invalid protocol id\")"
                    require_helper_stringliteral_44e5(/** @src 0:24826:24840  "protocolId > 1" */ gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _7, /** @src 0:24839:24840  "1" */ 0x01))
                    /// @src 0:24909:24930  "_config.newFeeConfigs"
                    let expr_offset_2, expr_length_2 := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:24909:24942  "_config.newFeeConfigs[i].feeInWei"
                    let _8 := add(/** @src 0:24909:24933  "_config.newFeeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(expr_offset_2, expr_length_2, var_i), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:24909:24942  "_config.newFeeConfigs[i].feeInWei"
                    let value_3 := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    value_3 := calldataload(_8)
                    sstore(/** @src 0:24878:24906  "protocolFeeInWei[protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint8(expr_3), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ value_3)
                    /// @src 0:25002:25023  "_config.newFeeConfigs"
                    let expr_offset_3, expr_length_3 := access_calldata_tail_array_struct_FeeConfig_calldata_dyn_calldata(_1, _6)
                    /// @src 0:25002:25035  "_config.newFeeConfigs[i].feeInWei"
                    let _9 := add(/** @src 0:25002:25026  "_config.newFeeConfigs[i]" */ calldata_array_index_access_struct_FeeConfig_calldata_dyn_calldata(expr_offset_3, expr_length_3, var_i), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 32)
                    /// @src 0:25002:25035  "_config.newFeeConfigs[i].feeInWei"
                    let value_4 := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    value_4 := calldataload(_9)
                    /// @src 0:24961:25051  "RelayGovernanceFeeConfigured(protocolId, _config.newFeeConfigs[i].feeInWei, _config.nonce)"
                    let _10 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:24961:25051  "RelayGovernanceFeeConfigured(protocolId, _config.newFeeConfigs[i].feeInWei, _config.nonce)"
                    log2(_10, sub(abi_encode_uint256_uint256(_10, value_4, value_2), _10), 0x56e557c678d8c60ad61135f4d764031042d94e83074d43cad2dd56a0194759c8, _7)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                return(/** @src -1:-1:-1 */ 0, 0)
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            function external_fun_initialRewardEpochId()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 0:9716:9760  "uint32 public immutable initialRewardEpochId" */ loadimmutable("335"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
                return(memPos, 32)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15190(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, 0)
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15191(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:79308:79326  "merkleRootsPrivate" */ 0x01)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15196(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:77378:77394  "protocolFeeInWei" */ 0x04)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15269(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:81625:81646  "toRandomNumberPrivate" */ 0x09)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                dataSlot := keccak256(0, 0x40)
            }
            function mapping_index_access_mapping_uint256_uint256_of_uint256_15271(key) -> dataSlot
            {
                mstore(0, key)
                mstore(0x20, /** @src 0:81703:81720  "isSecureRandomMap" */ 0x06)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ value)
                mstore(32, /** @src 0:8472:8543  "mapping(uint256 rewardEpochId => uint256) public startingVotingRoundIds" */ 2)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x40))
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value0 := abi_decode_uint256_15127()
                let value1 := abi_decode_uint256()
                let value2 := abi_decode_bytes32()
                let offset := calldataload(100)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                if iszero(slt(add(offset, 35), calldatasize()))
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let length := calldataload(add(4, offset))
                if gt(length, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                if gt(add(add(offset, shl(5, length)), 36), calldatasize())
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                let newFreePtr := add(memPtr, and(add(size, 31), /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ not(31)))
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let src := add(offset, 0x20)
                for { } lt(src, srcEnd) { src := add(src, 0x20) }
                {
                    let value := calldataload(src)
                    if iszero(eq(value, and(value, sub(shl(160, 1), 1))))
                    {
                        revert(/** @src -1:-1:-1 */ 0, 0)
                    }
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                if slt(add(sub(calldatasize(), offset), not(3)), 0xc0)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := allocate_memory()
                mstore(value, abi_decode_uint24(add(4, offset)))
                mstore(add(value, 32), abi_decode_uint32(add(offset, 36)))
                mstore(add(value, 64), abi_decode_uint16(add(offset, 68)))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value_1 := calldataload(add(offset, 100))
                mstore(add(value, 96), value_1)
                let offset_1 := calldataload(add(offset, 132))
                if gt(offset_1, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                mstore(add(value, 128), abi_decode_array_address_dyn(add(add(offset, offset_1), 4), calldatasize()))
                let offset_2 := calldataload(add(offset, 164))
                if gt(offset_2, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                mstore(add(value, 160), abi_decode_array_uint16_dyn(add(add(offset, offset_2), 4), calldatasize()))
                /// @src 0:16237:16244  "bytes32"
                let var := modifier_onlySigningPolicySetter(value)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bytes32(memPos, var), memPos))
            }
            function external_fun_lastInitializedRewardEpochData()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(shr(152, sload(/** @src 0:83087:83096  "stateData" */ 0x07)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 0:83206:83228  "startingVotingRoundIds" */ 0x02)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := calldataload(4)
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ value)
                mstore(32, 4)
                let _1 := sload(keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x40))
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let offset := calldataload(4)
                if gt(offset, 0xffffffffffffffff)
                {
                    revert(/** @src -1:-1:-1 */ 0, 0)
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value0, value1 := abi_decode_bytes_calldata(add(4, offset), calldatasize())
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := calldataload(36)
                let ret := /** @src 0:23060:23111  "_verifyCustomSignature(_relayMessage, _messageHash)" */ fun_verifyCustomSignature(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ value0, value1, value)
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := calldataload(4)
                let ret, ret_1, ret_2 := fun_getRandomNumberHistorical(value)
                let memPos := mload(64)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, ret, ret_1, ret_2), memPos))
            }
            function external_fun_signingPolicySetter()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let value := and(sload(/** @src 0:8618:8652  "address public signingPolicySetter" */ 3), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value0 := abi_decode_uint256_15127()
                let _1 := sload(/** @src 0:82168:82177  "stateData" */ 0x07)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := and(shr(8, _1), 0xffffffff)
                if /** @src 0:82154:82201  "_timestamp >= stateData.firstVotingRoundStartTs" */ lt(value0, value)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 16)
                    mstore(add(memPtr, 68), "before the start")
                    revert(memPtr, 100)
                }
                /// @src 0:82240:82286  "_timestamp - stateData.firstVotingRoundStartTs"
                let expr := checked_sub_uint256(value0, cleanup_from_storage_uint32(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ value))
                /// @src 0:82232:82326  "return (_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds"
                let var := /** @src 0:82239:82326  "(_timestamp - stateData.firstVotingRoundStartTs) / stateData.votingEpochDurationSeconds" */ checked_div_uint256(expr, extract_from_storage_value_offsett_uint8(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_5t_uint8(_1)))
                let memPos := mload(64)
                return(memPos, sub(abi_encode_bytes32(memPos, var), memPos))
            }
            function abi_encode_bytes(value, pos) -> end
            {
                let length := mload(value)
                mstore(pos, length)
                mcopy(add(pos, 0x20), add(value, 0x20), length)
                mstore(add(add(pos, length), 0x20), /** @src -1:-1:-1 */ 0)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                end := add(add(pos, and(add(length, 31), /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ not(31))), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x20)
            }
            function external_fun_relay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                /// @src 0:25230:75252  "assembly {..."
                let usr$memPtr := mload(0x40)
                mstore(add(usr$memPtr, 160), sload(7))
                if lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:25230:75252  "assembly {..." */ 15)
                {
                    usr$revertWithMessage_15147(usr$memPtr)
                }
                calldatacopy(usr$memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 4, /** @src 0:25230:75252  "assembly {..." */ 11)
                let _1 := mload(usr$memPtr)
                if lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:25230:75252  "assembly {..." */ add(mul(shr(240, _1), 22), 48))
                {
                    usr$revertWithMessage(usr$memPtr)
                }
                let _2 := usr$calculateSigningPolicyHash_15149(usr$memPtr, add(43, mul(shr(240, _1), 22)))
                mstore(add(usr$memPtr, 0x40), _2)
                mstore(usr$memPtr, and(shr(216, _1), 16777215))
                mstore(add(usr$memPtr, 32), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0)
                /// @src 0:25230:75252  "assembly {..."
                let _3 := sload(keccak256(usr$memPtr, 0x40))
                mstore(add(usr$memPtr, 96), _3)
                if iszero(eq(_2, _3))
                {
                    usr$revertWithMessage_15150(usr$memPtr)
                }
                calldatacopy(usr$memPtr, add(mul(shr(240, _1), 22), 47), 1)
                let usr$protocolId := shr(248, mload(usr$memPtr))
                let usr$signatureStart := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                /// @src 0:25230:75252  "assembly {..."
                let usr$threshold := and(shr(168, _1), 65535)
                if iszero(iszero(usr$protocolId))
                {
                    let usr$memPtrGP0 := mload(0x40)
                    usr$signatureStart := add(mul(shr(240, _1), 22), 85)
                    if lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:25230:75252  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_15151(usr$memPtrGP0)
                    }
                    calldatacopy(usr$memPtrGP0, add(mul(shr(240, _1), 22), 47), 38)
                    let usr$votingRoundId := and(shr(216, mload(usr$memPtrGP0)), 4294967295)
                    mstore(add(usr$memPtrGP0, 96), usr$protocolId)
                    mstore(add(usr$memPtrGP0, 128), 1)
                    mstore(add(usr$memPtrGP0, 128), keccak256(add(usr$memPtrGP0, 96), 0x40))
                    mstore(add(usr$memPtrGP0, 96), usr$votingRoundId)
                    if iszero(iszero(sload(keccak256(add(usr$memPtrGP0, 96), 0x40))))
                    {
                        usr$revertWithMessage_15152(usr$memPtrGP0)
                    }
                    let _4 := eq(usr$protocolId, 1)
                    if _4
                    {
                        if usr$votingRoundId
                        {
                            usr$revertWithMessage_15153(usr$memPtrGP0)
                        }
                        if extract_from_storage_value_offsett_uint8(shr(208, mload(usr$memPtrGP0)))
                        {
                            usr$revertWithMessage_15155(usr$memPtrGP0)
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
                        usr$revertWithMessage_15156(usr$memPtrGP0)
                    }
                    let _6 := mload(add(usr$memPtrGP0, 160))
                    if lt(add(usr$messageRewardEpochId, and(shr(192, _6), 4294967295)), and(shr(152, _6), 4294967295))
                    {
                        usr$revertWithMessage_15157(usr$memPtrGP0)
                    }
                    if and(_5, lt(usr$votingRoundId, and(shr(184, _1), 4294967295)))
                    {
                        usr$revertWithMessage_15158(usr$memPtrGP0)
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
                                usr$revertWithMessage_15160(usr$memPtrGP0)
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
                        usr$revertWithMessage_15163(_9)
                    }
                    if lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:25230:75252  "assembly {..." */ add(mul(shr(240, _1), 22), 59))
                    {
                        usr$revertWithMessage_15164(mload(0x40))
                    }
                    calldatacopy(mload(0x40), add(mul(shr(240, _1), 22), 48), 11)
                    let _10 := mload(0x40)
                    let _11 := mload(_10)
                    let _12 := shr(240, _11)
                    if iszero(_12)
                    {
                        usr$revertWithMessage_15165(_10)
                    }
                    if gt(_12, 300)
                    {
                        usr$revertWithMessage_15166(mload(0x40))
                    }
                    let _13 := mul(_12, 22)
                    usr$signatureStart := add(add(mul(shr(240, _1), 22), _13), 91)
                    if lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:25230:75252  "assembly {..." */ usr$signatureStart)
                    {
                        usr$revertWithMessage_15167(mload(0x40))
                    }
                    let usr$newSigningPolicyRewardEpochId := and(shr(216, _11), 16777215)
                    let _14 := mload(0x40)
                    let usr$tmpLastInitializedRewardEpochId := extract_from_storage_value_offsett_uint32(mload(add(_14, 160)))
                    if iszero(eq(usr$tmpLastInitializedRewardEpochId, and(shr(216, _1), 16777215)))
                    {
                        usr$revertWithMessage_15169(_14)
                    }
                    if iszero(eq(add(1, usr$tmpLastInitializedRewardEpochId), usr$newSigningPolicyRewardEpochId))
                    {
                        usr$revertWithMessage_15170(mload(0x40))
                    }
                    usr$checkThresholdConsistency(mload(0x40), shr(168, _11), add(mul(shr(240, _1), 22), 48))
                    let usr$newSigningPolicyHash := usr$calculateSigningPolicyHash(mload(0x40), add(mul(shr(240, _1), 22), 48), add(43, _13))
                    let _15 := add(mload(0x40), 160)
                    mstore(_15, usr$assignStruct(mload(_15), usr$newSigningPolicyRewardEpochId))
                    mstore(mload(0x40), usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), 2)
                    let _16 := mload(0x40)
                    sstore(keccak256(_16, 0x40), and(shr(184, _11), 4294967295))
                    mstore(_16, usr$newSigningPolicyRewardEpochId)
                    mstore(add(mload(0x40), 32), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0)
                    /// @src 0:25230:75252  "assembly {..."
                    let _17 := mload(0x40)
                    sstore(keccak256(_17, 0x40), usr$newSigningPolicyHash)
                    mstore(add(_17, 32), usr$newSigningPolicyHash)
                    mstore(add(mload(0x40), 96), "SigningPolicyRelayed(uint256)")
                    log2(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0, 0, /** @src 0:25230:75252  "assembly {..." */ keccak256(add(mload(0x40), 96), 29), usr$newSigningPolicyRewardEpochId)
                }
                let _18 := add(usr$signatureStart, 2)
                if lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:25230:75252  "assembly {..." */ _18)
                {
                    usr$revertWithMessage_15172(usr$memPtr)
                }
                calldatacopy(add(usr$memPtr, 0x40), usr$signatureStart, 2)
                let _19 := shr(240, mload(add(usr$memPtr, 0x40)))
                mstore(add(usr$memPtr, 256), _18)
                if lt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ calldatasize(), /** @src 0:25230:75252  "assembly {..." */ add(add(usr$signatureStart, mul(_19, 67)), 2))
                {
                    usr$revertWithMessage_15173(usr$memPtr)
                }
                mstore(usr$memPtr, "0000\x19Ethereum Signed Message:\n32")
                mstore(usr$memPtr, keccak256(add(usr$memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 4), /** @src 0:25230:75252  "assembly {..." */ 60))
                let usr$i := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                /// @src 0:25230:75252  "assembly {..."
                let usr$weight := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                /// @src 0:25230:75252  "assembly {..."
                let usr$nextUnusedIndex := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                /// @src 0:25230:75252  "assembly {..."
                let usr$memPtrFor := mload(0x40)
                for { } lt(usr$i, _19) { usr$i := add(usr$i, 1) }
                {
                    mstore(add(usr$memPtrFor, 32), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0)
                    /// @src 0:25230:75252  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 63), add(add(usr$signatureStart, mul(usr$i, 67)), 2), 67)
                    let usr$index := shr(240, mload(add(usr$memPtrFor, 128)))
                    if gt(add(usr$index, 1), shr(240, _1))
                    {
                        usr$revertWithMessage_15174(usr$memPtrFor)
                    }
                    if lt(usr$index, usr$nextUnusedIndex)
                    {
                        usr$revertWithMessage_15175(usr$memPtrFor)
                    }
                    usr$nextUnusedIndex := add(usr$index, 1)
                    let _20 := and(mload(add(usr$memPtrFor, 32)), 0xff)
                    if iszero(or(eq(_20, 27), eq(_20, 28)))
                    {
                        usr$revertWithMessage_15176(usr$memPtrFor)
                    }
                    if gt(mload(add(usr$memPtrFor, 96)), 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                    {
                        usr$revertWithMessage_15177(usr$memPtrFor)
                    }
                    if iszero(staticcall(not(0), 1, usr$memPtrFor, 128, add(usr$memPtrFor, 0x40), 32))
                    {
                        usr$revertWithMessage_15178(usr$memPtrFor)
                    }
                    if iszero(eq(returndatasize(), 32))
                    {
                        usr$revertWithMessage_15179(usr$memPtrFor)
                    }
                    if iszero(mload(add(usr$memPtrFor, 0x40)))
                    {
                        usr$revertWithMessage_15180(usr$memPtrFor)
                    }
                    mstore(add(usr$memPtrFor, 96), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0)
                    /// @src 0:25230:75252  "assembly {..."
                    calldatacopy(add(usr$memPtrFor, 106), add(47, mul(usr$index, 22)), 22)
                    if iszero(eq(mload(add(usr$memPtrFor, 0x40)), shr(16, mload(add(usr$memPtrFor, 96)))))
                    {
                        usr$revertWithMessage_15181(usr$memPtrFor)
                    }
                    usr$weight := add(usr$weight, and(mload(add(usr$memPtrFor, 96)), 65535))
                    if gt(usr$weight, usr$threshold)
                    {
                        if iszero(usr$protocolId)
                        {
                            sstore(7, mload(add(usr$memPtrFor, 160)))
                            return(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0, 0)
                        }
                        /// @src 0:25230:75252  "assembly {..."
                        if iszero(iszero(usr$protocolId))
                        {
                            let _21 := add(usr$memPtrFor, 192)
                            calldatacopy(_21, add(mul(shr(240, _1), 22), 53), 32)
                            if eq(usr$protocolId, 1)
                            {
                                mstore(usr$memPtrFor, mload(_21))
                                mstore(add(usr$memPtrFor, 32), and(shl(16, _1), shl(232, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 16777215)))
                                /// @src 0:25230:75252  "assembly {..."
                                return(usr$memPtrFor, 35)
                            }
                            if iszero(mload(_21))
                            {
                                usr$revertWithMessage_15182(usr$memPtrFor)
                            }
                            let usr$votingRoundId_1 := usr$extractVotingRoundIdFromMessage(usr$memPtrFor, add(43, mul(shr(240, _1), 22)))
                            mstore(usr$memPtrFor, usr$protocolId)
                            mstore(add(usr$memPtrFor, 32), 1)
                            mstore(add(usr$memPtrFor, 32), keccak256(usr$memPtrFor, 0x40))
                            mstore(usr$memPtrFor, usr$votingRoundId_1)
                            sstore(keccak256(usr$memPtrFor, 0x40), mload(_21))
                            let _22 := add(usr$memPtrFor, 160)
                            if iszero(eq(usr$protocolId, extract_from_storage_value_offsett_uint8(mload(_22))))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, _1), 22), 47), 6)
                                let _23 := shr(208, mload(usr$memPtrFor))
                                mstore(usr$memPtrFor, _23)
                                mstore(_22, and(_23, 0xff))
                                mstore(add(usr$memPtrFor, 96), "ProtocolMessageRelayed(uint8,uin")
                                mstore(add(usr$memPtrFor, 128), "t32,bool,bytes32)")
                                log3(_22, 0x40, keccak256(add(usr$memPtrFor, 96), 49), usr$protocolId, usr$votingRoundId_1)
                                return(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0, 0)
                            }
                            /// @src 0:25230:75252  "assembly {..."
                            if eq(usr$protocolId, extract_from_storage_value_offsett_uint8(mload(_22)))
                            {
                                calldatacopy(usr$memPtrFor, add(mul(shr(240, _1), 22), 47), 6)
                                let usr$isSecure := iszero(iszero(extract_from_storage_value_offsett_uint8(shr(208, mload(usr$memPtrFor)))))
                                let _24 := add(usr$memPtrFor, 256)
                                usr$processRandomMerkleProof(usr$memPtrFor, add(mload(_24), mul(_19, 67)), _21, usr$votingRoundId_1, usr$isSecure)
                                if usr$isSecure
                                {
                                    usr$setIsSecureRandomBit(add(usr$memPtrFor, 96), usr$votingRoundId_1)
                                }
                                let _25 := mload(_22)
                                if gt(usr$votingRoundId_1, and(shr(112, _25), 4294967295))
                                {
                                    sstore(7, usr$assignStruct_15187(usr$assignStruct_15186(_25, usr$votingRoundId_1), usr$isSecure))
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
                                return(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0, 0)
                            }
                        }
                        /// @src 0:25230:75252  "assembly {..."
                        usr$revertWithMessage_15188(mload(0x40))
                    }
                }
                /// @src 0:75273:75300  "revert(\"Not enough weight\")"
                let _26 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:25230:75252  "assembly {..." */ 0x40)
                /// @src 0:75273:75300  "revert(\"Not enough weight\")"
                mstore(_26, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:75273:75300  "revert(\"Not enough weight\")"
                revert(_26, sub(abi_encode_stringliteral_0d64(add(_26, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 4)), /** @src 0:75273:75300  "revert(\"Not enough weight\")" */ _26))
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            function external_fun_getRandomNumber()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let _1 := sload(/** @src 0:80486:80495  "stateData" */ 0x07)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let value := and(shr(112, _1), 0xffffffff)
                mstore(0, value)
                mstore(0x20, /** @src 0:80464:80485  "toRandomNumberPrivate" */ 0x09)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let _2 := sload(keccak256(0, 0x40))
                let cleaned := and(/** @src 0:80665:80698  "stateData.randomVotingRoundId + 1" */ checked_add_uint32(value), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)
                /// @src 0:80578:80750  "_randomTimestamp =..."
                let var__randomTimestamp := /** @src 0:80609:80750  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(shr(8, _1), 0xffffffff), /** @src 0:80657:80750  "uint256(stateData.randomVotingRoundId + 1) *..." */ checked_mul_uint256(cleaned, extract_from_storage_value_offsett_uint8(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(shr(40, _1), 0xff))))
                let memPos := mload(0x40)
                return(memPos, sub(abi_encode_uint256_bool_uint256(memPos, _2, and(shr(144, _1), 0xff), var__randomTimestamp), memPos))
            }
            function external_fun_oldRelay()
            {
                if callvalue() { revert(0, 0) }
                if slt(add(calldatasize(), not(3)), 0) { revert(0, 0) }
                let memPos := mload(64)
                mstore(memPos, and(/** @src 0:9641:9673  "IRelay public immutable oldRelay" */ loadimmutable("332"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
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
            /// @ast-id 1944 @src 0:82381:82784  "function toSigningPolicyHash(uint256 _rewardEpochId) external view returns (bytes32) {..."
            function fun_toSigningPolicyHash(var_rewardEpochId) -> var
            {
                /// @src 0:82457:82464  "bytes32"
                var := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:82480:82488  "oldRelay" */ loadimmutable("332"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:82480:82551  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                let expr := /** @src 0:82480:82510  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:82480:82551  "oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:82514:82551  "_rewardEpochId < initialRewardEpochId" */ lt(var_rewardEpochId, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:82531:82551  "initialRewardEpochId" */ loadimmutable("335"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:82476:82629  "if (oldRelay != IRelay(address(0)) && _rewardEpochId < initialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:82574:82618  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _2 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:82574:82618  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    mstore(_2, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x0c85bf07))
                    /// @src 0:82574:82618  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_bytes32(add(_2, 4), var_rewardEpochId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:82574:82618  "oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:82567:82618  "return oldRelay.toSigningPolicyHash(_rewardEpochId)"
                    var := expr_1
                    leave
                }
                /// @src 0:82638:82718  "require(signingPolicySetter != address(0), \"no access to signing policy hashes\")"
                require_helper_stringliteral_63a2(/** @src 0:82646:82679  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(cleanup_address_payable(sload(/** @src 0:82646:82665  "signingPolicySetter" */ 0x03)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))))
                /// @src 0:82728:82777  "return toSigningPolicyHashPrivate[_rewardEpochId]"
                var := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sload(/** @src 0:82735:82777  "toSigningPolicyHashPrivate[_rewardEpochId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15190(var_rewardEpochId))
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
            /// @ast-id 1690 @src 0:78776:79376  "function isFinalized(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_isFinalized(var__protocolId, var_votingRoundId) -> var
            {
                /// @src 0:78881:78885  "bool"
                var := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:78905:78913  "oldRelay" */ loadimmutable("332"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:78905:79000  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:78905:78935  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:78905:79000  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:78939:79000  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:78956:79000  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:78901:79083  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:79023:79072  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:79023:79072  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(226, 0x0c5eb4cf))
                    /// @src 0:79023:79072  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var__protocolId, var_votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:79023:79072  "oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bool_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:79016:79072  "return oldRelay.isFinalized(_protocolId, _votingRoundId)"
                    var := expr_1
                    leave
                }
                /// @src 0:79301:79369  "return merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)"
                var := /** @src 0:79308:79369  "merkleRootsPrivate[_protocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ sload(/** @src 0:79308:79355  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:79308:79339  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15191(var__protocolId), /** @src 0:79308:79355  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))))
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
            /// @ast-id 1737 @src 0:79424:79897  "function merkleRoots(uint256 _protocolId, uint256 _votingRoundId)..."
            function fun_merkleRoots(var_protocolId, var__votingRoundId) -> var_merkleRoot
            {
                /// @src 0:79529:79548  "bytes32 _merkleRoot"
                var_merkleRoot := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:79568:79576  "oldRelay" */ loadimmutable("332"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:79568:79663  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:79568:79598  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:79568:79663  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:79602:79663  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var__votingRoundId, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:79619:79663  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:79564:79746  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:79686:79735  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _2 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:79686:79735  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    mstore(_2, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(232, 3752811))
                    /// @src 0:79686:79735  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_uint256_uint256(add(_2, 4), var_protocolId, var__votingRoundId), _2), _2, 32)
                    if iszero(_3) { revert_forward() }
                    let expr_1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:79686:79735  "oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    if _3
                    {
                        let _4 := 32
                        if gt(32, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        expr_1 := abi_decode_bytes32_fromMemory(_2, add(_2, _4))
                    }
                    /// @src 0:79679:79735  "return oldRelay.merkleRoots(_protocolId, _votingRoundId)"
                    var_merkleRoot := expr_1
                    leave
                }
                /// @src 0:79755:79826  "require(signingPolicySetter != address(0), \"no access to merkle roots\")"
                require_helper_stringliteral_1c79(/** @src 0:79763:79796  "signingPolicySetter != address(0)" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(cleanup_address_payable(sload(/** @src 0:79763:79782  "signingPolicySetter" */ 0x03)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))))
                /// @src 0:79836:79890  "return merkleRootsPrivate[_protocolId][_votingRoundId]"
                var_merkleRoot := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sload(/** @src 0:79843:79890  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:79843:79874  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15191(var_protocolId), /** @src 0:79843:79890  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var__votingRoundId))
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                for { } lt(i, length) { i := add(i, 1) }
                {
                    let value_1 := calldataload(srcPtr)
                    validator_revert_uint8(value_1)
                    mstore(pos, and(value_1, 0xff))
                    let value_2 := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                diff := add(and(x, 0xffffffff), /** @src 0:25230:75252  "assembly {..." */ not(0))
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                sstore(/** @src 0:24506:24524  "governanceFeeNonce" */ 0x08, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ value)
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
            function mapping_index_access_mapping_uint256_uint256_of_uint8_15268(key) -> dataSlot
            {
                mstore(0, and(key, 0xff))
                mstore(0x20, /** @src 0:81475:81493  "merkleRootsPrivate" */ 0x01)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                size := add(and(add(length, 31), /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ not(31)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x20)
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
                    returndatacopy(add(memPtr, 0x20), /** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ returndatasize())
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
            function checked_sub_uint256_15208(y) -> diff
            {
                diff := sub(/** @src 0:20700:20702  "20" */ 0x14, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:20700:20702  "20" */ 0x14)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_15210(y) -> diff
            {
                diff := sub(/** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_15213(y) -> diff
            {
                diff := sub(/** @src 0:19929:19930  "2" */ 0x02, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:19929:19930  "2" */ 0x02)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                { panic_error_0x11() }
            }
            function checked_sub_uint256_15273(y) -> diff
            {
                diff := sub(/** @src 0:81747:81750  "255" */ 0xff, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ y)
                if gt(diff, /** @src 0:81747:81750  "255" */ 0xff)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
            /// @ast-id 1648 @src 0:75355:78728  "function verify(uint256 _protocolId, uint256 _votingRoundId, bytes32 _leaf, bytes32[] calldata _proof)..."
            function fun_verify(var_protocolId, var_votingRoundId, var_leaf, var_proof_offset, var_proof_length) -> var
            {
                /// @src 0:75500:75504  "bool"
                var := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                let _1 := and(/** @src 0:76248:76256  "oldRelay" */ loadimmutable("332"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:76248:76343  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:76248:76278  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:76248:76343  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:76282:76343  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:76299:76343  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:76244:78700  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                switch expr
                case 0 {
                    /// @src 0:77303:77350  "require(_protocolId > 1, \"invalid protocol id\")"
                    require_helper_stringliteral_44e5(/** @src 0:77311:77326  "_protocolId > 1" */ gt(var_protocolId, /** @src 0:77325:77326  "1" */ 0x01))
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    let _2 := sload(/** @src 0:77378:77407  "protocolFeeInWei[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15196(var_protocolId))
                    /// @src 0:77421:77461  "require(msg.value >= fee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 0:77429:77445  "msg.value >= fee" */ iszero(lt(/** @src 0:77429:77438  "msg.value" */ callvalue(), /** @src 0:77429:77445  "msg.value >= fee" */ _2)))
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    let _3 := sload(/** @src 0:77571:77618  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:77571:77602  "merkleRootsPrivate[_protocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15191(var_protocolId), /** @src 0:77571:77618  "merkleRootsPrivate[_protocolId][_votingRoundId]" */ var_votingRoundId))
                    /// @src 0:77632:77676  "require(root != bytes32(0), \"not finalized\")"
                    require_helper_stringliteral(/** @src 0:77640:77658  "root != bytes32(0)" */ iszero(iszero(_3)))
                    /// @src 0:77690:77803  "require(..."
                    require_helper_stringliteral_c04c(/** @src 0:77715:77749  "_proof.verifyCalldata(root, _leaf)" */ fun_verifyCalldata(var_proof_offset, var_proof_length, _3, var_leaf))
                    /// @src 0:78020:78357  "if (fee > 0) {..."
                    if /** @src 0:78024:78031  "fee > 0" */ iszero(iszero(_2))
                    /// @src 0:78020:78357  "if (fee > 0) {..."
                    {
                        /// @src 0:78191:78232  "feeCollectionAddress.call{value: fee}(\"\")"
                        let expr_component := call(gas(), /** @src 0:78191:78216  "feeCollectionAddress.call" */ cleanup_address_payable(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ cleanup_address_payable(sload(/** @src 0:78191:78211  "feeCollectionAddress" */ 0x05))), /** @src 0:78191:78232  "feeCollectionAddress.call{value: fee}(\"\")" */ _2, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0, 0, 0, 0)
                        /// @src 0:78191:78232  "feeCollectionAddress.call{value: fee}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:78309:78342  "require(feeOk, \"Transfer failed\")"
                        require_helper_stringliteral_25ad(expr_component)
                    }
                    /// @src 0:78387:78402  "msg.value - fee"
                    let expr_1 := checked_sub_uint256(/** @src 0:77429:77438  "msg.value" */ callvalue(), /** @src 0:78387:78402  "msg.value - fee" */ _2)
                    /// @src 0:78416:78690  "if (refund > 0) {..."
                    if /** @src 0:78420:78430  "refund > 0" */ iszero(iszero(expr_1))
                    /// @src 0:78416:78690  "if (refund > 0) {..."
                    {
                        /// @src 0:78530:78564  "msg.sender.call{value: refund}(\"\")"
                        let expr_component_1 := call(gas(), /** @src 0:78530:78540  "msg.sender" */ caller(), /** @src 0:78530:78564  "msg.sender.call{value: refund}(\"\")" */ expr_1, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0, 0, 0, 0)
                        /// @src 0:78530:78564  "msg.sender.call{value: refund}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:78641:78675  "require(refundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_component_1)
                    }
                }
                default /// @src 0:76244:78700  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                {
                    /// @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _4 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)"
                    mstore(_4, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(224, 0x91e7d42f))
                    /// @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)"
                    let _5 := staticcall(gas(), _1, _4, sub(abi_encode_bytes32(add(_4, 4), var_protocolId), _4), _4, 32)
                    if iszero(_5) { revert_forward() }
                    let expr_2 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)"
                    if _5
                    {
                        let _6 := 32
                        if gt(32, returndatasize()) { _6 := returndatasize() }
                        finalize_allocation(_4, _6)
                        expr_2 := abi_decode_uint256_fromMemory(_4, add(_4, _6))
                    }
                    /// @src 0:76697:76740  "require(msg.value >= oldFee, \"too low fee\")"
                    require_helper_stringliteral_4ed5(/** @src 0:76705:76724  "msg.value >= oldFee" */ iszero(lt(/** @src 0:76705:76714  "msg.value" */ callvalue(), /** @src 0:76705:76724  "msg.value >= oldFee" */ expr_2)))
                    /// @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _7 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    mstore(_7, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(225, 0x40428355))
                    /// @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    let _8 := call(gas(), _1, expr_2, _7, sub(abi_encode_uint256_uint256_bytes32_array_bytes32_dyn_calldata(add(_7, /** @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)" */ 4), /** @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ var_protocolId, var_votingRoundId, var_leaf, var_proof_offset, var_proof_length), _7), _7, /** @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)" */ 32)
                    /// @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if iszero(_8) { revert_forward() }
                    let expr_3 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0
                    /// @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                    if _8
                    {
                        let _9 := /** @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)" */ 32
                        /// @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)"
                        if gt(/** @src 0:76645:76683  "oldRelay.protocolFeeInWei(_protocolId)" */ 32, /** @src 0:76764:76838  "oldRelay.verify{value: oldFee}(_protocolId, _votingRoundId, _leaf, _proof)" */ returndatasize()) { _9 := returndatasize() }
                        finalize_allocation(_7, _9)
                        expr_3 := abi_decode_bool_fromMemory(_7, add(_7, _9))
                    }
                    /// @src 0:76852:76896  "require(ok, \"old relay verification failed\")"
                    require_helper_stringliteral_fd5d(expr_3)
                    /// @src 0:76930:76948  "msg.value - oldFee"
                    let expr_4 := checked_sub_uint256(/** @src 0:76705:76714  "msg.value" */ callvalue(), /** @src 0:76930:76948  "msg.value - oldFee" */ expr_2)
                    /// @src 0:76962:77248  "if (oldRefund > 0) {..."
                    if /** @src 0:76966:76979  "oldRefund > 0" */ iszero(iszero(expr_4))
                    /// @src 0:76962:77248  "if (oldRefund > 0) {..."
                    {
                        /// @src 0:77082:77119  "msg.sender.call{value: oldRefund}(\"\")"
                        let expr_1537_component := call(gas(), /** @src 0:77082:77092  "msg.sender" */ caller(), /** @src 0:77082:77119  "msg.sender.call{value: oldRefund}(\"\")" */ expr_4, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0, 0, 0, 0)
                        /// @src 0:77082:77119  "msg.sender.call{value: oldRefund}(\"\")"
                        pop(extract_returndata())
                        /// @src 0:77196:77233  "require(oldRefundOk, \"Refund failed\")"
                        require_helper_stringliteral_940e(expr_1537_component)
                    }
                    /// @src 0:77261:77272  "return true"
                    var := /** @src 0:77268:77272  "true" */ 0x01
                    /// @src 0:77261:77272  "return true"
                    leave
                }
                /// @src 0:78710:78721  "return true"
                var := /** @src 0:78717:78721  "true" */ 0x01
            }
            /// @ast-id 351 @src 0:9966:10098  "modifier onlySigningPolicySetter() {..."
            function modifier_onlySigningPolicySetter(var_signingPolicy_mpos) -> _1
            {
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                if iszero(/** @src 0:10019:10052  "msg.sender == signingPolicySetter" */ eq(/** @src 0:10019:10029  "msg.sender" */ caller(), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(sload(/** @src 0:10033:10052  "signingPolicySetter" */ 0x03), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))))
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 23)
                    mstore(add(memPtr, 68), "only sign policy setter")
                    revert(memPtr, 100)
                }
                /// @src 0:16581:16621  "stateData.lastInitializedRewardEpoch + 1"
                let expr := checked_add_uint32(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_uint32(sload(/** @src 0:16581:16590  "stateData" */ 0x07)))
                /// @src 0:16560:16700  "require(..."
                require_helper_stringliteral_d084(/** @src 0:16581:16653  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ eq(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:16581:16653  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ expr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff), /** @src 0:16581:16653  "stateData.lastInitializedRewardEpoch + 1 == _signingPolicy.rewardEpochId" */ cleanup_uint24(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:16625:16653  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))))
                /// @src 0:17554:17618  "require(_signingPolicy.voters.length > 0, \"must be non-trivial\")"
                require_helper_stringliteral_aacd(/** @src 0:17562:17594  "_signingPolicy.voters.length > 0" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ mload(add(var_signingPolicy_mpos, 128))))))
                /// @src 0:17628:17698  "require(_signingPolicy.voters.length <= MAX_VOTERS, \"too many voters\")"
                require_helper_stringliteral_d1bc(/** @src 0:17636:17678  "_signingPolicy.voters.length <= MAX_VOTERS" */ iszero(gt(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:17636:17657  "_signingPolicy.voters" */ mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))), /** @src 0:2485:2488  "300" */ 0x012c)))
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let length := mload(/** @src 0:17716:17737  "_signingPolicy.voters" */ mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))
                /// @src 0:17708:17795  "require(_signingPolicy.voters.length == _signingPolicy.weights.length, \"size mismatch\")"
                require_helper_stringliteral_6b32(/** @src 0:17716:17777  "_signingPolicy.voters.length == _signingPolicy.weights.length" */ eq(length, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:17748:17770  "_signingPolicy.weights" */ mload(add(var_signingPolicy_mpos, 160)))))
                /// @src 0:17805:17828  "uint256 totalWeight = 0"
                let var_totalWeight := /** @src -1:-1:-1 */ 0
                /// @src 0:17843:17856  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 0:17838:17963  "for (uint256 i = 0; i < _signingPolicy.weights.length; i++) {..."
                for { }
                /** @src 0:16620:16621  "1" */ 0x01
                /// @src 0:17843:17856  "uint256 i = 0"
                {
                    /// @src 0:17893:17896  "i++"
                    var_i := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:17893:17896  "i++" */ var_i, /** @src 0:16620:16621  "1" */ 0x01)
                }
                /// @src 0:17893:17896  "i++"
                {
                    /// @src 0:17862:17884  "_signingPolicy.weights"
                    let _mpos := mload(/** @src 0:17748:17770  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                    /// @src 0:17858:17891  "i < _signingPolicy.weights.length"
                    if iszero(lt(var_i, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:17862:17891  "_signingPolicy.weights.length" */ _mpos)))
                    /// @src 0:17858:17891  "i < _signingPolicy.weights.length"
                    { break }
                    /// @src 0:17912:17952  "totalWeight += _signingPolicy.weights[i]"
                    var_totalWeight := checked_add_uint256(var_totalWeight, cleanup_from_storage_uint16(/** @src 0:17927:17952  "_signingPolicy.weights[i]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos, var_i))))
                }
                /// @src 0:17972:18024  "require(totalWeight < 2**16, \"total weight too big\")"
                require_helper_stringliteral_f10c(/** @src 0:17980:17999  "totalWeight < 2**16" */ lt(var_totalWeight, /** @src 0:17994:17999  "2**16" */ 0x010000))
                /// @src 0:18055:18114  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_1 := checked_mul_uint256_15199(/** @src 0:18055:18088  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:18063:18087  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 0:18034:18195  "require(..."
                require_helper_stringliteral_d8d1(/** @src 0:18055:18150  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) >= totalWeight * MIN_THRESHOLD_BIPS" */ iszero(lt(expr_1, /** @src 0:18118:18150  "totalWeight * MIN_THRESHOLD_BIPS" */ checked_mul_uint256_15200(var_totalWeight))))
                /// @src 0:18226:18285  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS)"
                let expr_2 := checked_mul_uint256_15199(/** @src 0:18226:18259  "uint256(_signingPolicy.threshold)" */ cleanup_from_storage_uint16(/** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:18063:18087  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))))
                /// @src 0:18205:18364  "require(..."
                require_helper_stringliteral_185c(/** @src 0:18226:18321  "uint256(_signingPolicy.threshold) * uint256(THRESHOLD_BIPS) <= totalWeight * MAX_THRESHOLD_BIPS" */ iszero(gt(expr_2, /** @src 0:18289:18321  "totalWeight * MAX_THRESHOLD_BIPS" */ checked_mul_uint256_15202(var_totalWeight))))
                /// @src 0:18409:18559  "new bytes(..."
                let expr_mpos := allocate_and_zero_memory_array_bytes(/** @src 0:18432:18549  "SIGNING_POLICY_PREFIX_BYTES +..." */ checked_add_uint256_15204(/** @src 0:18478:18549  "_signingPolicy.voters.length *..." */ checked_mul_uint256_15203(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:18478:18499  "_signingPolicy.voters" */ mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))))
                /// @src 0:18570:18587  "Counters memory m"
                let zero_struct_Counters_mpos := /** @src 0:3954:3956  "22" */ allocate_and_zero_memory_struct_struct_Counters()
                /// @src 0:18903:18924  "_signingPolicy.voters"
                let _mpos_1 := mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 0:18889:18933  "bytes2(uint16(_signingPolicy.voters.length))"
                let expr_3 := convert_uint16_to_bytes2(/** @src 0:18896:18932  "uint16(_signingPolicy.voters.length)" */ cleanup_from_storage_uint16(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:18903:18931  "_signingPolicy.voters.length" */ _mpos_1)))
                /// @src 0:18947:18983  "bytes3(_signingPolicy.rewardEpochId)"
                let expr_4 := convert_uint24_to_bytes3(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:18954:18982  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos)))
                /// @src 0:18997:19038  "bytes4(_signingPolicy.startVotingRoundId)"
                let expr_5 := convert_uint32_to_bytes4(/** @src 0:3954:3956  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32))))
                /// @src 0:19052:19084  "bytes2(_signingPolicy.threshold)"
                let expr_6 := convert_uint16_to_bytes2(/** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:18063:18087  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64))))
                /// @src 0:3954:3956  "22"
                let _2 := mload(/** @src 0:19114:19133  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 0:19149:19182  "bytes20(_signingPolicy.voters[0])"
                let expr_7 := convert_address_to_bytes20(/** @src 0:19157:19181  "_signingPolicy.voters[0]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn_15205(_mpos_1)))
                /// @src 0:18863:19251  "bytes.concat(..."
                let expr_mpos_1 := bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(expr_3, expr_4, expr_5, expr_6, _2, expr_7, /** @src 0:19196:19241  "bytes1(uint8(_signingPolicy.weights[0] >> 8))" */ convert_uint8_to_bytes1(/** @src 0:19203:19240  "uint8(_signingPolicy.weights[0] >> 8)" */ extract_from_storage_value_offsett_uint8(/** @src 0:19209:19239  "_signingPolicy.weights[0] >> 8" */ shift_right_uint16_uint8(/** @src 0:19209:19234  "_signingPolicy.weights[0]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn_15205(/** @src 0:19209:19231  "_signingPolicy.weights" */ mload(/** @src 0:17748:17770  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))))))))
                /// @src 0:19262:19408  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                for { }
                /** @src 0:16620:16621  "1" */ 0x01
                /// @src 0:19262:19408  "for (; m.signingPolicyPos < 64; m.signingPolicyPos++) {..."
                {
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:19294:19312  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 0:19294:19314  "m.signingPolicyPos++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19294:19312  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                }
                /// @src 0:19294:19314  "m.signingPolicyPos++"
                {
                    /// @src 0:3954:3956  "22"
                    let _3 := mload(/** @src 0:19294:19312  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 0:19269:19292  "m.signingPolicyPos < 64"
                    if iszero(lt(_3, /** @src 0:18063:18087  "_signingPolicy.threshold" */ 64))
                    /// @src 0:19269:19292  "m.signingPolicyPos < 64"
                    { break }
                    /// @src 0:19371:19397  "toHash[m.signingPolicyPos]"
                    let _4 := read_from_memoryt_bytes1(memory_array_index_access_bytes(expr_mpos_1, /** @src 0:3954:3956  "22" */ _3))
                    let _5 := mload(/** @src 0:19294:19312  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))
                    /// @src 0:19330:19397  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]"
                    mstore8(memory_array_index_access_bytes(expr_mpos, _5), byte(/** @src -1:-1:-1 */ 0, /** @src 0:19330:19397  "signingPolicyBytes[m.signingPolicyPos] = toHash[m.signingPolicyPos]" */ _4))
                }
                /// @src 0:19418:19457  "bytes32 currentHash = keccak256(toHash)"
                let var_currentHash := /** @src 0:19440:19457  "keccak256(toHash)" */ keccak256(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:19440:19457  "keccak256(toHash)" */ expr_mpos_1, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:19440:19457  "keccak256(toHash)" */ expr_mpos_1))
                /// @src 0:3954:3956  "22"
                mstore(zero_struct_Counters_mpos, /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(/** @src 0:19495:19506  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:16620:16621  "1" */ 0x01)
                /// @src 0:3954:3956  "22"
                mstore(/** @src 0:19520:19532  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:18063:18087  "_signingPolicy.threshold" */ 64), /** @src 0:16620:16621  "1" */ 0x01)
                /// @src 0:3954:3956  "22"
                mstore(/** @src 0:19546:19556  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:19114:19133  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                /// @src 0:19571:21777  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                for { }
                /** @src 0:16620:16621  "1" */ 0x01
                /// @src 0:19571:21777  "while (m.weightIndex < _signingPolicy.voters.length) {..."
                { }
                {
                    /// @src 0:3954:3956  "22"
                    let _6 := mload(/** @src 0:19578:19591  "m.weightIndex" */ zero_struct_Counters_mpos)
                    /// @src 0:19578:19622  "m.weightIndex < _signingPolicy.voters.length"
                    if iszero(lt(_6, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:19594:19615  "_signingPolicy.voters" */ mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128)))))
                    /// @src 0:19578:19622  "m.weightIndex < _signingPolicy.voters.length"
                    { break }
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128), /** @src -1:-1:-1 */ 0)
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:19663:19673  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src -1:-1:-1 */ 0)
                    /// @src 0:3954:3956  "22"
                    mstore(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160), /** @src -1:-1:-1 */ 0)
                    /// @src 0:19740:21450  "while (..."
                    for { }
                    /** @src 0:16620:16621  "1" */ 0x01
                    /// @src 0:19740:21450  "while (..."
                    { }
                    {
                        /// @src 0:19764:19824  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        let expr_8 := /** @src 0:19764:19776  "m.count < 32" */ lt(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128)), /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32)
                        /// @src 0:19764:19824  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if expr_8
                        {
                            /// @src 0:3954:3956  "22"
                            let _7 := mload(/** @src 0:19780:19793  "m.weightIndex" */ zero_struct_Counters_mpos)
                            /// @src 0:19764:19824  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                            expr_8 := /** @src 0:19780:19824  "m.weightIndex < _signingPolicy.voters.length" */ lt(_7, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:19796:19817  "_signingPolicy.voters" */ mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))))
                        }
                        /// @src 0:19764:19824  "m.count < 32 && m.weightIndex < _signingPolicy.voters.length"
                        if iszero(expr_8) { break }
                        /// @src 0:3954:3956  "22"
                        let _8 := mload(/** @src 0:19861:19874  "m.weightIndex" */ zero_struct_Counters_mpos)
                        /// @src 0:19857:21394  "if (m.weightIndex < m.voterIndex) {..."
                        switch /** @src 0:19861:19889  "m.weightIndex < m.voterIndex" */ lt(_8, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19520:19532  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:18063:18087  "_signingPolicy.threshold" */ 64)))
                        case /** @src 0:19857:21394  "if (m.weightIndex < m.voterIndex) {..." */ 0 {
                            /// @src 0:3954:3956  "22"
                            mstore(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160), /** @src 0:20700:20715  "20 - m.voterPos" */ checked_sub_uint256_15208(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19546:19556  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:19114:19133  "_signingPolicy.seed" */ 96))))
                            /// @src 0:3954:3956  "22"
                            let _9 := mload(/** @src 0:19546:19556  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:19114:19133  "_signingPolicy.seed" */ 96))
                            /// @src 0:20737:20742  "m.pos"
                            let _10 := add(zero_struct_Counters_mpos, 224)
                            /// @src 0:3954:3956  "22"
                            mstore(_10, _9)
                            /// @src 0:20846:20867  "_signingPolicy.voters"
                            let _mpos_2 := mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                            /// @src 0:20830:20923  "uint256(uint160(_signingPolicy.voters[m.voterIndex])) <<..."
                            let _11 := shift_left_uint256_uint8_15209(/** @src 0:20830:20883  "uint256(uint160(_signingPolicy.voters[m.voterIndex]))" */ cleanup_address_payable(/** @src 0:20838:20882  "uint160(_signingPolicy.voters[m.voterIndex])" */ cleanup_address_payable(/** @src 0:20846:20881  "_signingPolicy.voters[m.voterIndex]" */ read_from_memoryt_address(memory_array_index_access_uint16_dyn(_mpos_2, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19520:19532  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:18063:18087  "_signingPolicy.threshold" */ 64)))))))
                            /// @src 0:3954:3956  "22"
                            let _12 := mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128))
                            /// @src 0:20967:21240  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 0:20971:20999  "m.count + m.bytesToTake > 32" */ gt(/** @src 0:20971:20994  "m.count + m.bytesToTake" */ checked_add_uint256(_12, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160))), /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 0:20967:21240  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19546:19556  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:19114:19133  "_signingPolicy.seed" */ 96), /** @src -1:-1:-1 */ 0)
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19520:19532  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:18063:18087  "_signingPolicy.threshold" */ 64), /** @src 0:21203:21217  "m.voterIndex++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19520:19532  "m.voterIndex" */ add(zero_struct_Counters_mpos, /** @src 0:18063:18087  "_signingPolicy.threshold" */ 64))))
                            }
                            default /// @src 0:20967:21240  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 0:21043:21055  "32 - m.count"
                                let _13 := checked_sub_uint256_15210(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128)))
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160), /** @src 0:3954:3956  "22" */ _13)
                                mstore(/** @src 0:19546:19556  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:19114:19133  "_signingPolicy.seed" */ 96), /** @src 0:21081:21108  "m.voterPos += m.bytesToTake" */ checked_add_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19546:19556  "m.voterPos" */ add(zero_struct_Counters_mpos, /** @src 0:19114:19133  "_signingPolicy.seed" */ 96)), /** @src 0:3954:3956  "22" */ _13))
                            }
                            mstore(/** @src 0:19663:19673  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 0:21261:21375  "m.nextSlot |= bytes32(..." */ or(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19663:19673  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shr(/** @src 0:21340:21351  "8 * m.count" */ checked_mul_uint256_15211(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128))), /** @src 0:3954:3956  "22" */ shl(/** @src 0:21324:21333  "8 * m.pos" */ checked_mul_uint256_15211(/** @src 0:3954:3956  "22" */ mload(/** @src 0:21328:21333  "m.pos" */ _10)), /** @src 0:3954:3956  "22" */ _11))))
                        }
                        default /// @src 0:19857:21394  "if (m.weightIndex < m.voterIndex) {..."
                        {
                            /// @src 0:3954:3956  "22"
                            mstore(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160), /** @src 0:19929:19944  "2 - m.weightPos" */ checked_sub_uint256_15213(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19495:19506  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32))))
                            /// @src 0:3954:3956  "22"
                            let _14 := mload(/** @src 0:19495:19506  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 0:19966:19971  "m.pos"
                            let _15 := add(zero_struct_Counters_mpos, 224)
                            /// @src 0:3954:3956  "22"
                            mstore(_15, _14)
                            /// @src 0:20105:20127  "_signingPolicy.weights"
                            let _mpos_3 := mload(/** @src 0:17748:17770  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                            /// @src 0:20061:20181  "uint256(..."
                            let _16 := shift_left_uint256_uint8(/** @src 0:20061:20169  "uint256(..." */ cleanup_from_storage_uint16(/** @src 0:20105:20142  "_signingPolicy.weights[m.weightIndex]" */ read_from_memoryt_uint16(memory_array_index_access_uint16_dyn(_mpos_3, /** @src 0:3954:3956  "22" */ mload(/** @src 0:20128:20141  "m.weightIndex" */ zero_struct_Counters_mpos)))))
                            /// @src 0:3954:3956  "22"
                            let _17 := mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128))
                            /// @src 0:20225:20501  "if (m.count + m.bytesToTake > 32) {..."
                            switch /** @src 0:20229:20257  "m.count + m.bytesToTake > 32" */ gt(/** @src 0:20229:20252  "m.count + m.bytesToTake" */ checked_add_uint256(_17, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160))), /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32)
                            case /** @src 0:20225:20501  "if (m.count + m.bytesToTake > 32) {..." */ 0 {
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19495:19506  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32), /** @src -1:-1:-1 */ 0)
                                /// @src 0:3954:3956  "22"
                                mstore(zero_struct_Counters_mpos, /** @src 0:20463:20478  "m.weightIndex++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:20463:20478  "m.weightIndex++" */ zero_struct_Counters_mpos)))
                            }
                            default /// @src 0:20225:20501  "if (m.count + m.bytesToTake > 32) {..."
                            {
                                /// @src 0:20301:20313  "32 - m.count"
                                let _18 := checked_sub_uint256_15210(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128)))
                                /// @src 0:3954:3956  "22"
                                mstore(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160), /** @src 0:3954:3956  "22" */ _18)
                                mstore(/** @src 0:19495:19506  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:20339:20367  "m.weightPos += m.bytesToTake" */ checked_add_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19495:19506  "m.weightPos" */ add(zero_struct_Counters_mpos, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32)), /** @src 0:3954:3956  "22" */ _18))
                            }
                            mstore(/** @src 0:19663:19673  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192), /** @src 0:20522:20637  "m.nextSlot |= bytes32(..." */ or(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19663:19673  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shr(/** @src 0:20602:20613  "8 * m.count" */ checked_mul_uint256_15211(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128))), /** @src 0:3954:3956  "22" */ shl(/** @src 0:20586:20595  "8 * m.pos" */ checked_mul_uint256_15211(/** @src 0:3954:3956  "22" */ mload(/** @src 0:20590:20595  "m.pos" */ _15)), /** @src 0:3954:3956  "22" */ _16))))
                        }
                        mstore(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128), /** @src 0:21411:21435  "m.count += m.bytesToTake" */ checked_add_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128)), /** @src 0:3954:3956  "22" */ mload(/** @src 0:19709:19722  "m.bytesToTake" */ add(zero_struct_Counters_mpos, /** @src 0:17748:17770  "_signingPolicy.weights" */ 160))))
                    }
                    /// @src 0:21463:21767  "if (m.count > 0) {..."
                    if /** @src 0:21467:21478  "m.count > 0" */ iszero(iszero(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128))))
                    /// @src 0:21463:21767  "if (m.count > 0) {..."
                    {
                        /// @src 0:21522:21559  "bytes.concat(currentHash, m.nextSlot)"
                        let expr_mpos_2 := bytes_concat_bytes32_bytes32(var_currentHash, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19663:19673  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192)))
                        /// @src 0:21498:21560  "currentHash = keccak256(bytes.concat(currentHash, m.nextSlot))"
                        var_currentHash := /** @src 0:21512:21560  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ keccak256(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:21512:21560  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:21512:21560  "keccak256(bytes.concat(currentHash, m.nextSlot))" */ expr_mpos_2))
                        /// @src 0:21583:21596  "uint256 i = 0"
                        let var_i_1 := /** @src -1:-1:-1 */ 0
                        /// @src 0:21578:21753  "for (uint256 i = 0; i < m.count; i++) {..."
                        for { }
                        /** @src 0:16620:16621  "1" */ 0x01
                        /// @src 0:21583:21596  "uint256 i = 0"
                        {
                            /// @src 0:21611:21614  "i++"
                            var_i_1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:21611:21614  "i++" */ var_i_1, /** @src 0:16620:16621  "1" */ 0x01)
                        }
                        /// @src 0:21611:21614  "i++"
                        {
                            /// @src 0:21598:21609  "i < m.count"
                            if iszero(lt(var_i_1, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19638:19645  "m.count" */ add(zero_struct_Counters_mpos, /** @src 0:17562:17583  "_signingPolicy.voters" */ 128))))
                            /// @src 0:21598:21609  "i < m.count"
                            { break }
                            /// @src 0:3954:3956  "22"
                            let _19 := mload(/** @src 0:19663:19673  "m.nextSlot" */ add(zero_struct_Counters_mpos, 192))
                            /// @src 0:21679:21692  "m.nextSlot[i]"
                            if iszero(lt(var_i_1, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32))
                            /// @src 0:21679:21692  "m.nextSlot[i]"
                            { panic_error_0x32() }
                            /// @src 0:21638:21692  "signingPolicyBytes[m.signingPolicyPos] = m.nextSlot[i]"
                            mstore8(memory_array_index_access_bytes(expr_mpos, /** @src 0:3954:3956  "22" */ mload(/** @src 0:19294:19312  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))), /** @src 0:21679:21692  "m.nextSlot[i]" */ byte(var_i_1, _19))
                            /// @src 0:3954:3956  "22"
                            mstore(/** @src 0:19294:19312  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256), /** @src 0:21714:21734  "m.signingPolicyPos++" */ increment_uint256(/** @src 0:3954:3956  "22" */ mload(/** @src 0:19294:19312  "m.signingPolicyPos" */ add(zero_struct_Counters_mpos, 256))))
                        }
                    }
                }
                /// @src 0:22163:22207  "abi.encodePacked(block.chainid, currentHash)"
                let expr_mpos_3 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:18063:18087  "_signingPolicy.threshold" */ 64)
                /// @src 0:22163:22207  "abi.encodePacked(block.chainid, currentHash)"
                let _20 := add(expr_mpos_3, /** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ 32)
                /// @src 0:22163:22207  "abi.encodePacked(block.chainid, currentHash)"
                let _21 := sub(abi_encode_packed_uint256_bytes32(_20, /** @src 0:22180:22193  "block.chainid" */ chainid(), /** @src 0:22163:22207  "abi.encodePacked(block.chainid, currentHash)" */ var_currentHash), expr_mpos_3)
                mstore(expr_mpos_3, add(_21, /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ not(31)))
                /// @src 0:22163:22207  "abi.encodePacked(block.chainid, currentHash)"
                finalize_allocation(expr_mpos_3, _21)
                /// @src 0:22153:22208  "keccak256(abi.encodePacked(block.chainid, currentHash))"
                let expr_9 := keccak256(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _20, mload(/** @src 0:22153:22208  "keccak256(abi.encodePacked(block.chainid, currentHash))" */ expr_mpos_3))
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                sstore(/** @src 0:22218:22274  "toSigningPolicyHashPrivate[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:22245:22273  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ expr_9)
                let _22 := cleanup_uint24(mload(/** @src 0:22337:22365  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:22298:22365  "stateData.lastInitializedRewardEpoch = _signingPolicy.rewardEpochId"
                update_storage_value_offsett_uint32_to_uint32(cleanup_uint24(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _22))
                sstore(/** @src 0:22375:22427  "startingVotingRoundIds[_signingPolicy.rewardEpochId]" */ mapping_index_access_mapping_uint256_bytes32_of_uint24_15220(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _22), /** @src 0:22375:22463  "startingVotingRoundIds[_signingPolicy.rewardEpochId] = _signingPolicy.startVotingRoundId" */ cleanup_from_storage_uint32(/** @src 0:3954:3956  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))))
                /// @src 0:22516:22544  "_signingPolicy.rewardEpochId"
                let _23 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ cleanup_uint24(mload(/** @src 0:22516:22544  "_signingPolicy.rewardEpochId" */ var_signingPolicy_mpos))
                /// @src 0:22558:22591  "_signingPolicy.startVotingRoundId"
                let _24 := /** @src 0:3954:3956  "22" */ cleanup_from_storage_uint32(mload(/** @src 0:19004:19037  "_signingPolicy.startVotingRoundId" */ add(var_signingPolicy_mpos, 32)))
                /// @src 0:22605:22629  "_signingPolicy.threshold"
                let _25 := /** @src 0:2485:2488  "300" */ cleanup_from_storage_uint16(mload(/** @src 0:18063:18087  "_signingPolicy.threshold" */ add(var_signingPolicy_mpos, 64)))
                /// @src 0:3954:3956  "22"
                let _26 := mload(/** @src 0:19114:19133  "_signingPolicy.seed" */ add(var_signingPolicy_mpos, 96))
                /// @src 0:22676:22697  "_signingPolicy.voters"
                let _mpos_4 := mload(/** @src 0:17562:17583  "_signingPolicy.voters" */ add(var_signingPolicy_mpos, 128))
                /// @src 0:22711:22733  "_signingPolicy.weights"
                let _mpos_5 := mload(/** @src 0:17748:17770  "_signingPolicy.weights" */ add(var_signingPolicy_mpos, 160))
                /// @src 0:22478:22812  "SigningPolicyInitialized(..."
                let _27 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:18063:18087  "_signingPolicy.threshold" */ 64)
                /// @src 0:22478:22812  "SigningPolicyInitialized(..."
                log2(_27, sub(abi_encode_uint32_uint16_uint256_array_address_dyn_array_uint16_dyn_bytes_uint64(_27, _24, _25, _26, _mpos_4, _mpos_5, expr_mpos, /** @src 0:3954:3956  "22" */ and(/** @src 0:22786:22801  "block.timestamp" */ timestamp(), /** @src 0:3954:3956  "22" */ 0xffffffffffffffff)), /** @src 0:22478:22812  "SigningPolicyInitialized(..." */ _27), 0x91d0280e969157fc6c5b8f952f237b03d934b18534dafcac839075bbc33522f8, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:22478:22812  "SigningPolicyInitialized(..." */ _23, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffff))
                /// @src 0:10090:10091  "_"
                _1 := expr_9
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
                    let memPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2485:2488  "300"
                    mstore(memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2485:2488  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2485:2488  "300" */ add(memPtr, 36), 15)
                    mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:2485:2488  "300" */ memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 68), /** @src 0:2485:2488  "300" */ "too many voters")
                    revert(memPtr, 100)
                }
            }
            function require_helper_stringliteral_6b32(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2485:2488  "300"
                    mstore(memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2485:2488  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2485:2488  "300" */ add(memPtr, 36), 13)
                    mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:2485:2488  "300" */ memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 68), /** @src 0:2485:2488  "300" */ "size mismatch")
                    revert(memPtr, 100)
                }
            }
            function memory_array_index_access_uint16_dyn_15205(baseRef) -> addr
            {
                if iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:2485:2488  "300" */ baseRef)) { panic_error_0x32() }
                addr := add(baseRef, 32)
            }
            function memory_array_index_access_uint16_dyn(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:2485:2488  "300" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, shl(5, index)), 32)
            }
            function read_from_memoryt_uint16(ptr) -> returnValue
            {
                returnValue := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:2485:2488  "300" */ mload(ptr), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffff)
            }
            /// @src 0:2485:2488  "300"
            function checked_add_uint256_15204(y) -> sum
            {
                sum := add(/** @src 0:4092:4094  "43" */ 0x2b, /** @src 0:2485:2488  "300" */ y)
                if gt(/** @src 0:4092:4094  "43" */ 0x2b, /** @src 0:2485:2488  "300" */ sum) { panic_error_0x11() }
            }
            function checked_add_uint256_15274(x) -> sum
            {
                sum := add(x, /** @src 0:81475:81493  "merkleRootsPrivate" */ 0x01)
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
                    let memPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2485:2488  "300"
                    mstore(memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2485:2488  "300"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2485:2488  "300" */ add(memPtr, 36), 20)
                    mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:2485:2488  "300" */ memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 68), /** @src 0:2485:2488  "300" */ "total weight too big")
                    revert(memPtr, 100)
                }
            }
            /// @src 0:2387:2392  "10000"
            function checked_mul_uint256_15199(x) -> product
            {
                product := mul(x, 0x2710)
                if iszero(or(iszero(x), eq(0x2710, div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15200(x) -> product
            {
                product := mul(x, /** @src 0:2540:2544  "5000" */ 0x1388)
                /// @src 0:2387:2392  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:2540:2544  "5000" */ 0x1388, /** @src 0:2387:2392  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15202(x) -> product
            {
                product := mul(x, /** @src 0:2596:2600  "6600" */ 0x19c8)
                /// @src 0:2387:2392  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:2596:2600  "6600" */ 0x19c8, /** @src 0:2387:2392  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15203(x) -> product
            {
                product := mul(x, /** @src 0:3954:3956  "22" */ 0x16)
                /// @src 0:2387:2392  "10000"
                if iszero(or(iszero(x), eq(/** @src 0:3954:3956  "22" */ 0x16, /** @src 0:2387:2392  "10000" */ div(product, x)))) { panic_error_0x11() }
            }
            function checked_mul_uint256_15211(y) -> product
            {
                product := shl(3, y)
                if iszero(eq(y, and(y, sub(shl(253, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 1), 1))))
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
                    let memPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2540:2544  "5000"
                    mstore(memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2540:2544  "5000"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2540:2544  "5000" */ add(memPtr, 36), 19)
                    mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:2540:2544  "5000" */ memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 68), /** @src 0:2540:2544  "5000" */ "too small threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 0:2596:2600  "6600"
            function require_helper_stringliteral_185c(condition)
            {
                if iszero(condition)
                {
                    let memPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:2596:2600  "6600"
                    mstore(memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:2596:2600  "6600"
                    mstore(add(memPtr, 4), 32)
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    mstore(/** @src 0:2596:2600  "6600" */ add(memPtr, 36), 17)
                    mstore(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:2596:2600  "6600" */ memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 68), /** @src 0:2596:2600  "6600" */ "too big threshold")
                    revert(memPtr, 100)
                }
            }
            /// @src 0:3954:3956  "22"
            function allocate_and_zero_memory_array_bytes(length) -> memPtr
            {
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let _1 := array_allocation_size_bytes(length)
                let memPtr_1 := mload(64)
                finalize_allocation(memPtr_1, _1)
                mstore(memPtr_1, length)
                /// @src 0:3954:3956  "22"
                memPtr := memPtr_1
                calldatacopy(add(memPtr_1, 32), calldatasize(), add(array_allocation_size_bytes(length), /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ not(31)))
            }
            /// @src 0:3954:3956  "22"
            function allocate_and_zero_memory_struct_struct_Counters() -> memPtr
            {
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let memPtr_1 := mload(64)
                let newFreePtr := add(memPtr_1, /** @src 0:3954:3956  "22" */ 288)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                if or(gt(newFreePtr, 0xffffffffffffffff), lt(newFreePtr, memPtr_1)) { panic_error_0x41() }
                mstore(64, newFreePtr)
                /// @src 0:3954:3956  "22"
                memPtr := memPtr_1
                mstore(memPtr_1, /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, 32), /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                mstore(add(memPtr_1, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64), /** @src -1:-1:-1 */ 0)
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
                converted := and(shl(232, value), /** @src 0:25230:75252  "assembly {..." */ shl(232, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 16777215))
            }
            /// @src 0:3954:3956  "22"
            function convert_uint32_to_bytes4(value) -> converted
            {
                converted := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(shl(224, /** @src 0:3954:3956  "22" */ value), shl(224, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
            }
            /// @src 0:3954:3956  "22"
            function read_from_memoryt_address(ptr) -> returnValue
            {
                returnValue := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:3954:3956  "22" */ mload(ptr), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
            }
            /// @src 0:3954:3956  "22"
            function convert_address_to_bytes20(value) -> converted
            {
                converted := and(shl(96, value), not(0xffffffffffffffffffffffff))
            }
            function shift_right_uint16_uint8(value) -> result
            {
                result := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(shr(8, /** @src 0:3954:3956  "22" */ value), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xff)
            }
            /// @src 0:3954:3956  "22"
            function convert_uint8_to_bytes1(value) -> converted
            {
                converted := and(shl(248, value), shl(248, 255))
            }
            function bytes_concat_bytes2_bytes3_bytes4_bytes2_bytes32_bytes20_bytes1(param, param_1, param_2, param_3, param_4, param_5, param_6) -> outPtr
            {
                outPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 0x20), and(param, shl(240, 65535)))
                mstore(add(outPtr, 34), and(param_1, /** @src 0:25230:75252  "assembly {..." */ shl(232, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 16777215)))
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 37), and(param_2, shl(224, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff)))
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 41), and(param_3, shl(240, 65535)))
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                mstore(/** @src 0:3954:3956  "22" */ add(outPtr, 43), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ param_4)
                /// @src 0:3954:3956  "22"
                mstore(add(outPtr, 75), and(param_5, not(0xffffffffffffffffffffffff)))
                mstore(add(outPtr, 95), and(param_6, shl(248, 255)))
                mstore(outPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64)
                /// @src 0:3954:3956  "22"
                finalize_allocation(outPtr, 96)
            }
            function increment_uint256(value) -> ret
            {
                if eq(value, /** @src 0:25230:75252  "assembly {..." */ not(0))
                /// @src 0:3954:3956  "22"
                { panic_error_0x11() }
                ret := add(value, 1)
            }
            function memory_array_index_access_bytes(baseRef, index) -> addr
            {
                if iszero(lt(index, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:3954:3956  "22" */ baseRef))) { panic_error_0x32() }
                addr := add(add(baseRef, index), 32)
            }
            function read_from_memoryt_bytes1(ptr) -> returnValue
            {
                returnValue := and(mload(ptr), shl(248, 255))
            }
            function shift_left_uint256_uint8_15209(value) -> result
            {
                result := shl(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 96, /** @src 0:3954:3956  "22" */ value)
            }
            function shift_left_uint256_uint8(value) -> result
            {
                result := shl(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 240, /** @src 0:3954:3956  "22" */ value)
            }
            function bytes_concat_bytes32_bytes32(param, param_1) -> outPtr
            {
                outPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                mstore(/** @src 0:3954:3956  "22" */ add(outPtr, 0x20), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ param)
                mstore(/** @src 0:3954:3956  "22" */ add(outPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64), param_1)
                /// @src 0:3954:3956  "22"
                mstore(outPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64)
                /// @src 0:3954:3956  "22"
                finalize_allocation(outPtr, 96)
            }
            function abi_encode_packed_uint256_bytes32(pos, value0, value1) -> end
            {
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                mstore(pos, value0)
                mstore(/** @src 0:3954:3956  "22" */ add(pos, 32), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ value1)
                /// @src 0:3954:3956  "22"
                end := add(pos, 64)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24(key) -> dataSlot
            {
                mstore(/** @src -1:-1:-1 */ 0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:3954:3956  "22" */ key, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffff))
                /// @src 0:3954:3956  "22"
                mstore(0x20, /** @src -1:-1:-1 */ 0)
                /// @src 0:3954:3956  "22"
                dataSlot := keccak256(/** @src -1:-1:-1 */ 0, /** @src 0:3954:3956  "22" */ 0x40)
            }
            function mapping_index_access_mapping_uint256_bytes32_of_uint24_15220(key) -> dataSlot
            {
                mstore(0, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:3954:3956  "22" */ key, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffff))
                /// @src 0:3954:3956  "22"
                mstore(0x20, /** @src 0:22375:22397  "startingVotingRoundIds" */ 0x02)
                /// @src 0:3954:3956  "22"
                dataSlot := keccak256(0, 0x40)
            }
            function update_storage_value_offsett_uint32_to_uint32(value)
            {
                let _1 := sload(/** @src 0:16581:16590  "stateData" */ 0x07)
                /// @src 0:3954:3956  "22"
                sstore(/** @src 0:16581:16590  "stateData" */ 0x07, /** @src 0:3954:3956  "22" */ or(and(_1, not(shl(152, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:3954:3956  "22" */ and(shl(152, value), shl(152, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))))
            }
            /// @src 0:3954:3956  "22"
            function abi_encode_array_uint16_dyn(value, pos) -> end
            {
                let length := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:3954:3956  "22" */ value)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                mstore(pos, length)
                /// @src 0:3954:3956  "22"
                pos := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(pos, 0x20)
                /// @src 0:3954:3956  "22"
                let srcPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:3954:3956  "22" */ value, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x20)
                /// @src 0:3954:3956  "22"
                let i := /** @src -1:-1:-1 */ 0
                /// @src 0:3954:3956  "22"
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    mstore(pos, and(/** @src 0:3954:3956  "22" */ mload(srcPtr), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffff))
                    /// @src 0:3954:3956  "22"
                    pos := add(pos, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x20)
                    /// @src 0:3954:3956  "22"
                    srcPtr := add(srcPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0x20)
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
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                mstore(headStart, and(value0, 0xffffffff))
                mstore(/** @src 0:3954:3956  "22" */ add(headStart, 32), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(value1, 0xffff))
                mstore(/** @src 0:3954:3956  "22" */ add(headStart, 64), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ value2)
                /// @src 0:3954:3956  "22"
                mstore(add(headStart, 96), 224)
                let pos := tail_1
                let length := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:3954:3956  "22" */ value3)
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                mstore(tail_1, length)
                /// @src 0:3954:3956  "22"
                pos := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:3954:3956  "22" */ headStart, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 256)
                /// @src 0:3954:3956  "22"
                let srcPtr := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 0:3954:3956  "22" */ value3, 32)
                let i := 0
                for { } lt(i, length) { i := add(i, 1) }
                {
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    mstore(pos, and(/** @src 0:3954:3956  "22" */ mload(srcPtr), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1)))
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
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
            function abi_decode_uint256t_boolt_uint256_fromMemory(headStart, dataEnd) -> value0, value1, value2
            {
                if slt(sub(dataEnd, headStart), 96) { revert(0, 0) }
                let value := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                value := mload(headStart)
                value0 := value
                value1 := abi_decode_t_bool_fromMemory(add(headStart, 32))
                let value_1 := /** @src -1:-1:-1 */ 0
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
            function checked_div_uint256_15270(x) -> r
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
            /// @ast-id 1876 @src 0:80822:82010  "function getRandomNumberHistorical(uint256 _votingRoundId)..."
            function fun_getRandomNumberHistorical(var_votingRoundId) -> var_randomNumber, var_isSecureRandom, var_randomTimestamp
            {
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let _1 := and(/** @src 0:81055:81063  "oldRelay" */ loadimmutable("332"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sub(shl(160, 1), 1))
                /// @src 0:81055:81150  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                let expr := /** @src 0:81055:81085  "oldRelay != IRelay(address(0))" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _1))
                /// @src 0:81055:81150  "oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId"
                if expr
                {
                    expr := /** @src 0:81089:81150  "_votingRoundId < startingVotingRoundIdForInitialRewardEpochId" */ lt(var_votingRoundId, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:81106:81150  "startingVotingRoundIdForInitialRewardEpochId" */ loadimmutable("338"), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))
                }
                /// @src 0:81051:81234  "if (oldRelay != IRelay(address(0)) && _votingRoundId < startingVotingRoundIdForInitialRewardEpochId) {..."
                if expr
                {
                    /// @src 0:81173:81223  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _2 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                    /// @src 0:81173:81223  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    mstore(_2, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(227, 0x150fe287))
                    /// @src 0:81173:81223  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    let _3 := staticcall(gas(), _1, _2, sub(abi_encode_bytes32(add(_2, 4), var_votingRoundId), _2), _2, 96)
                    if iszero(_3) { revert_forward() }
                    let expr_1803_component := /** @src 0:81082:81083  "0" */ 0x00
                    let expr_component := 0x00
                    let expr_component_1 := 0x00
                    /// @src 0:81173:81223  "oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    if _3
                    {
                        let _4 := 96
                        if gt(96, returndatasize()) { _4 := returndatasize() }
                        finalize_allocation(_2, _4)
                        let expr_component_2, expr_component_3, expr_component_4 := abi_decode_uint256t_boolt_uint256_fromMemory(_2, add(_2, _4))
                        expr_1803_component := expr_component_2
                        expr_component := expr_component_3
                        expr_component_1 := expr_component_4
                    }
                    /// @src 0:81166:81223  "return oldRelay.getRandomNumberHistorical(_votingRoundId)"
                    var_randomNumber := expr_1803_component
                    var_isSecureRandom := expr_component
                    var_randomTimestamp := expr_component_1
                    leave
                }
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                let _5 := sload(/** @src 0:81494:81503  "stateData" */ 0x07)
                /// @src 0:81454:81599  "require(..."
                require_helper_stringliteral_2275(/** @src 0:81475:81557  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId] != bytes32(0)" */ iszero(iszero(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ sload(/** @src 0:81475:81543  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256(/** @src 0:81475:81527  "merkleRootsPrivate[stateData.randomNumberProtocolId]" */ mapping_index_access_mapping_uint256_uint256_of_uint8_15268(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offsett_uint8(_5)), /** @src 0:81475:81543  "merkleRootsPrivate[stateData.randomNumberProtocolId][_votingRoundId]" */ var_votingRoundId)))))
                /// @src 0:81609:81662  "_randomNumber = toRandomNumberPrivate[_votingRoundId]"
                var_randomNumber := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sload(/** @src 0:81625:81662  "toRandomNumberPrivate[_votingRoundId]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15269(var_votingRoundId))
                /// @src 0:81672:81836  "_isSecureRandom =..."
                var_isSecureRandom := /** @src 0:81702:81836  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))..." */ eq(/** @src 0:81702:81797  "(isSecureRandomMap[_votingRoundId / 256] >> (255 - _votingRoundId % 256)) & bytes32(uint256(1))" */ and(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ shr(/** @src 0:81747:81773  "255 - _votingRoundId % 256" */ checked_sub_uint256_15273(/** @src 0:81753:81773  "_votingRoundId % 256" */ mod_uint256(var_votingRoundId)), /** @src 0:397:84701  "contract Relay is IIRelay {..." */ sload(/** @src 0:81703:81742  "isSecureRandomMap[_votingRoundId / 256]" */ mapping_index_access_mapping_uint256_uint256_of_uint256_15271(/** @src 0:81721:81741  "_votingRoundId / 256" */ checked_div_uint256_15270(var_votingRoundId)))), /** @src 0:81475:81493  "merkleRootsPrivate" */ 0x01), 0x01)
                /// @src 0:81877:81910  "stateData.firstVotingRoundStartTs"
                let _6 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_1t_uint32(_5)
                /// @src 0:81933:81951  "_votingRoundId + 1"
                let expr_1 := checked_add_uint256_15274(var_votingRoundId)
                /// @src 0:81846:82003  "_randomTimestamp =..."
                var_randomTimestamp := /** @src 0:81877:82003  "stateData.firstVotingRoundStartTs +..." */ checked_add_uint256(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ and(/** @src 0:81877:82003  "stateData.firstVotingRoundStartTs +..." */ _6, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff), /** @src 0:81925:82003  "uint256(_votingRoundId + 1) *..." */ checked_mul_uint256(expr_1, extract_from_storage_value_offsett_uint8(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ extract_from_storage_value_offset_5t_uint8(_5))))
            }
            function abi_encode_stringliteral_0d64(headStart) -> tail
            {
                mstore(headStart, 32)
                mstore(add(headStart, 32), 17)
                mstore(add(headStart, 64), "Not enough weight")
                tail := add(headStart, 96)
            }
            /// @src 0:25230:75252  "assembly {..."
            function usr$revertWithMessage_15147(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy metadata")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Invalid sign policy length")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15150(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 28)
                mstore(add(usr_memPtr, 0x44), "Signing policy hash mismatch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15151(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "Too short message")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15152(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Already relayed")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15153(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "Wrong message format")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15155(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Wrong message format2")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15156(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong sign policy reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15157(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Message too old")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15158(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "Delayed sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15160(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Must use new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15163(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 26)
                mstore(add(usr_memPtr, 0x44), "Sign policy relay disabled")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15164(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 23)
                mstore(add(usr_memPtr, 0x44), "No new sign policy size")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15165(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "must be non-trivial")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15166(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "too many voters")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15167(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 30)
                mstore(add(usr_memPtr, 0x44), "Wrong size for new sign policy")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15169(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "Not with last intialized")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15170(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not next reward epoch")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15172(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "No signature count")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15173(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 21)
                mstore(add(usr_memPtr, 0x44), "Not enough signatures")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15174(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of range")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15175(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 18)
                mstore(add(usr_memPtr, 0x44), "Index out of order")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15176(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad v")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15177(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 5)
                mstore(add(usr_memPtr, 0x44), "Bad s")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15178(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "ecrecover error")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15179(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "ecrecover returned bad data")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15180(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 11)
                mstore(add(usr_memPtr, 0x44), "Zero signer")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15181(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 15)
                mstore(add(usr_memPtr, 0x44), "Wrong signature")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15182(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "zero merkle root")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15188(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 24)
                mstore(add(usr_memPtr, 0x44), "This should never happen")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15276(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 20)
                mstore(add(usr_memPtr, 0x44), "total weight too big")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15277(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 19)
                mstore(add(usr_memPtr, 0x44), "too small threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15278(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 17)
                mstore(add(usr_memPtr, 0x44), "too big threshold")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15279(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 16)
                mstore(add(usr_memPtr, 0x44), "No random number")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15280(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 22)
                mstore(add(usr_memPtr, 0x44), "Incorrect merkle proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$revertWithMessage_15281(usr_memPtr)
            {
                mstore(usr_memPtr, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                /// @src 0:25230:75252  "assembly {..."
                mstore(add(usr_memPtr, 0x04), 0x20)
                mstore(add(usr_memPtr, 0x24), 27)
                mstore(add(usr_memPtr, 0x44), "Invalid random number proof")
                revert(usr_memPtr, 0x64)
            }
            function usr$assignStruct(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, /** @src 0:3954:3956  "22" */ not(shl(152, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:25230:75252  "assembly {..." */ shl(152, usr$newVal))
            }
            function usr$assignStruct_15186(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(112, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 0xffffffff))), /** @src 0:25230:75252  "assembly {..." */ shl(112, usr$newVal))
            }
            function usr$assignStruct_15187(usr_structObj, usr$newVal) -> usr_newStructObj
            {
                usr_newStructObj := or(and(usr_structObj, not(shl(144, /** @src 0:3954:3956  "22" */ 255))), /** @src 0:25230:75252  "assembly {..." */ shl(144, usr$newVal))
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
                    mstore(_1, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ shl(229, 4594637))
                    /// @src 0:25230:75252  "assembly {..."
                    mstore(add(_1, 0x04), 0x20)
                    mstore(add(_1, 0x24), 23)
                    mstore(add(_1, 0x44), "Invalid voting round id")
                    revert(_1, 0x64)
                }
                usr_rewardEpochId := div(sub(usr$_votingRoundId, usr$firstRewardEpochStartVotingRoundId), and(shr(80, usr_stateDataObj), 65535))
            }
            function usr$calculateSigningPolicyHash_15149(usr_memPos, usr_policyLength) -> usr_policyHash
            {
                calldatacopy(usr_memPos, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 4, /** @src 0:25230:75252  "assembly {..." */ 32)
                let usr$endPos := add(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ 4, /** @src 0:25230:75252  "assembly {..." */ and(usr_policyLength, /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ not(31)))
                /// @src 0:25230:75252  "assembly {..."
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
                let usr$endPos := add(usr_calldataPos, and(usr_policyLength, /** @src 0:23790:23824  "abi.encode(_config, address(this))" */ not(31)))
                /// @src 0:25230:75252  "assembly {..."
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
                    usr$revertWithMessage_15276(usr_memPtr)
                }
                let _1 := mul(and(usr_metadata, 65535), 10000)
                if lt(_1, mul(usr$totalWeight, 5000))
                {
                    usr$revertWithMessage_15277(usr_memPtr)
                }
                if gt(_1, mul(usr$totalWeight, 6600))
                {
                    usr$revertWithMessage_15278(usr_memPtr)
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
                    usr$revertWithMessage_15279(usr_memPtr)
                }
                if iszero(iszero(and(sub(calldatasize(), usr_proofStart), 31)))
                {
                    usr$revertWithMessage_15280(usr_memPtr)
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
                    usr$revertWithMessage_15281(usr_memPtr)
                }
                calldatacopy(_3, usr_proofStart, 32)
                mstore(usr_memPtr, usr_votingRoundId)
                mstore(_2, 9)
                sstore(keccak256(usr_memPtr, 64), mload(_3))
            }
            /// @src 0:397:84701  "contract Relay is IIRelay {..."
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
            /// @ast-id 2021 @src 0:83271:84699  "function _verifyCustomSignature(..."
            function fun_verifyCustomSignature(var_relayMessage_offset, var_relayMessage_length, var_messageHash) -> var_rewardEpochId
            {
                /// @src 0:83578:83611  "address(this).call(_relayMessage)"
                let _1 := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(64)
                calldatacopy(_1, var_relayMessage_offset, var_relayMessage_length)
                let _2 := add(_1, var_relayMessage_length)
                mstore(_2, /** @src -1:-1:-1 */ 0)
                /// @src 0:83578:83611  "address(this).call(_relayMessage)"
                let expr_1986_component := call(gas(), /** @src 0:83586:83590  "this" */ address(), /** @src -1:-1:-1 */ 0, /** @src 0:83578:83611  "address(this).call(_relayMessage)" */ _1, sub(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ _2, /** @src 0:83578:83611  "address(this).call(_relayMessage)" */ _1), /** @src -1:-1:-1 */ 0, 0)
                /// @src 0:83578:83611  "address(this).call(_relayMessage)"
                let expr_component_mpos := extract_returndata()
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                if iszero(expr_1986_component)
                {
                    let memPtr := mload(64)
                    mstore(memPtr, shl(229, 4594637))
                    mstore(add(memPtr, 4), 32)
                    mstore(add(memPtr, 36), 19)
                    mstore(add(memPtr, 68), "Verification failed")
                    revert(memPtr, 100)
                }
                if iszero(/** @src 0:84213:84236  "returnData.length == 35" */ eq(/** @src 0:397:84701  "contract Relay is IIRelay {..." */ mload(/** @src 0:84213:84230  "returnData.length" */ expr_component_mpos), /** @src 0:84234:84236  "35" */ 0x23))
                /// @src 0:397:84701  "contract Relay is IIRelay {..."
                {
                    let memPtr_1 := mload(64)
                    mstore(memPtr_1, shl(229, 4594637))
                    mstore(add(memPtr_1, 4), 32)
                    mstore(add(memPtr_1, 36), 23)
                    mstore(add(memPtr_1, 68), "Wrong verification data")
                    revert(memPtr_1, 100)
                }
                /// @src 0:84395:84580  "assembly {..."
                let var_returnHash := mload(add(expr_component_mpos, 0x20))
                let var_returnRewardEpochId := shr(232, mload(add(expr_component_mpos, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 64)))
                /// @src 0:84589:84656  "require(bytes32(returnHash) == _messageHash, \"Invalid config hash\")"
                require_helper_stringliteral_a3dc(/** @src 0:84597:84632  "bytes32(returnHash) == _messageHash" */ eq(var_returnHash, var_messageHash))
                /// @src 0:84666:84692  "return returnRewardEpochId"
                var_rewardEpochId := var_returnRewardEpochId
            }
            /// @ast-id 2538 @src 5:4637:4809  "function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {..."
            function fun_verifyCalldata(var_proof_2521_offset, var_proof_2521_length, var_root, var_leaf) -> var
            {
                /// @src 5:5324:5351  "bytes32 computedHash = leaf"
                let var_computedHash := var_leaf
                /// @src 5:5366:5379  "uint256 i = 0"
                let var_i := /** @src -1:-1:-1 */ 0
                /// @src 5:5361:5495  "for (uint256 i = 0; i < proof.length; i++) {..."
                for { }
                /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 1
                /// @src 5:5366:5379  "uint256 i = 0"
                {
                    /// @src 5:5399:5402  "i++"
                    var_i := /** @src 0:397:84701  "contract Relay is IIRelay {..." */ add(/** @src 5:5399:5402  "i++" */ var_i, /** @src 0:397:84701  "contract Relay is IIRelay {..." */ 1)
                }
                /// @src 5:5399:5402  "i++"
                {
                    /// @src 5:5381:5397  "i < proof.length"
                    let _1 := iszero(lt(var_i, /** @src 5:5385:5397  "proof.length" */ var_proof_2521_length))
                    /// @src 5:5381:5397  "i < proof.length"
                    if _1 { break }
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    _1 := /** @src -1:-1:-1 */ 0
                    /// @src 5:5475:5483  "proof[i]"
                    let value := /** @src -1:-1:-1 */ 0
                    /// @src 0:397:84701  "contract Relay is IIRelay {..."
                    value := calldataload(add(var_proof_2521_offset, shl(5, var_i)))
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
        data ".metadata" hex"a26469706673582212208bb8035361a51c754b18490061610475cb4e5b482b1cf825ff13d41575549edc64736f6c634300081b0033"
    }
}
