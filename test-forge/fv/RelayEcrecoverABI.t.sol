// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable func-name-mixedcase

// Concrete ecrecover-precompile failure-ABI evidence (run on the real EVM, not Halmos).
//
// The `ecrecover` precompile (address 0x01) does NOT revert on a bad signature: the staticcall returns
// SUCCESS with EMPTY return data (returndatasize() == 0) and leaves the caller's output buffer UNTOUCHED
// (stale). Relay therefore cannot assume that an invalid signature reverts. Its raw-assembly recovery
// is made safe by three checks: staticcall
// success, returndatasize()==32, and recovered-signer != 0. This test pins that failure ABI as an
// executable fact and shows the returndatasize discriminator is load-bearing.
//
// Why this is a `forge test`, not a Halmos `check_` harness: Halmos models the 0x01 precompile as a TOTAL
// function returning a well-formed 32-byte address (returndatasize()==32 always), so its BUILT-IN model
// cannot exercise this empty-return/stale-buffer failure mode. The
// real EVM (revm, via `forge test`) does. The companion `RelayEcrecoverSymbolicFV.t.sol` internalizes the
// same obligation *symbolically*: it reaches the empty-return branch via a mock that reproduces the
// precompile's failure ABI, and proves the returndatasize/zero-signer guard rejects it over ALL stale-buffer
// contents. Together the two establish the expected guard behavior concretely and symbolically.
//
// RUN: forge test --match-contract RelayEcrecoverABITest -vvv

contract RelayEcrecoverABITest {
    // A bad signature: r = 0 is not a valid curve coordinate, so recovery fails.
    uint256 internal constant V = 27;
    uint256 internal constant R = 0;
    uint256 internal constant S = 1;

    /// The precompile on a bad signature: success, empty return, output buffer left stale.
    function test_badSig_succeeds_emptyReturn_staleBuffer() external view {
        bytes32 h = keccak256("msg");
        bool ok;
        uint256 outSize;
        bytes32 outWord;
        assembly {
            let p := mload(0x40)
            mstore(p, h)
            mstore(add(p, 0x20), V)
            mstore(add(p, 0x40), R)
            mstore(add(p, 0x60), S)
            let outPtr := add(p, 0x80)
            mstore(outPtr, 0xdead) // sentinel: detect a stale (never-written) output slot
            ok := staticcall(gas(), 0x01, p, 0x80, outPtr, 0x20)
            outSize := returndatasize()
            outWord := mload(outPtr)
        }
        // (1) the precompile does NOT revert on a bad signature:
        require(ok, "ecrecover ABI: precompile reverted on a bad signature");
        // (2) it returns EMPTY data, not 32 bytes:
        require(outSize == 0, "ecrecover ABI: bad signature must return empty data");
        // (3) the output buffer is left UNTOUCHED -> reading it yields stale (here, attacker-free) bytes.
        //     Without a returndatasize==32 check, this stale value would be read as the "recovered signer".
        require(outWord == bytes32(uint256(0xdead)), "ecrecover ABI: failure must leave output buffer stale");
    }

    /// The safe discriminator: requiring returndatasize()==32 rejects the bad signature.
    function test_returndatasizeGuard_rejectsBadSig() external view {
        bytes32 h = keccak256("msg");
        bool accepted;
        assembly {
            let p := mload(0x40)
            mstore(p, h)
            mstore(add(p, 0x20), V)
            mstore(add(p, 0x40), R)
            mstore(add(p, 0x60), S)
            let ok := staticcall(gas(), 0x01, p, 0x80, add(p, 0x80), 0x20)
            // Relay's guard: accept only if the call succeeded AND returned exactly 32 bytes.
            accepted := and(ok, eq(returndatasize(), 32))
        }
        require(!accepted, "ecrecover ABI: returndata-size guard accepted a bad signature");
    }

    /// Solidity's high-level `ecrecover` is safe by construction: it returns address(0) (never reverts).
    function test_solidityBuiltin_returnsZeroOnBadSig() external pure {
        address rec = ecrecover(keccak256("msg"), uint8(V), bytes32(R), bytes32(S));
        require(rec == address(0), "ecrecover ABI: Solidity builtin must return zero on a bad signature");
    }
}
