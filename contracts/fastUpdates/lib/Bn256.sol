// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {G1Point} from "../../userInterfaces/IBn256.sol";

/**
 * @title Operations on bn256 aka alt_bn128
 * @dev Implementations of common elliptic curve operations on Ethereum's
 * (poorly named) alt_bn128 curve. Whenever possible, use post-Byzantium
 * pre-compiled contracts to offset gas costs. Note that these pre-compiles
 * might not be available on all (eg private) chains. Implementation is taken from
 * https://github.com/keep-network/keep-core/blob/main/solidity-v1/contracts/cryptography/AltBn128.sol
 */
library Bn256 {

  // p is a prime over which we form a basic field, q is order of the group
  // Taken from go-ethereum/crypto/bn256/cloudflare/constants.go
  /* solhint-disable const-name-snakecase */
  uint256 internal constant p = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
  uint256 internal constant q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
  // Generator of G1 group.
  //Taken from go-ethereum/crypto/bn256/cloudflare/curve.go
  uint256 internal constant g1x = 1;
  uint256 internal constant g1y = 2;
  /* solhint-enable const-name-snakecase */

  /**
   * @dev Wrap the modular exponent pre-compile introduced in Byzantium.
   * Returns base^exponent mod p.
   */
  function modExp(uint256 base, uint256 exponent) internal view returns (uint256 o) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      // Args for the precompile: [<length_of_BASE> <length_of_EXPONENT>
      // <length_of_MODULUS> <BASE> <EXPONENT> <MODULUS>]
      let output := mload(0x40)
      let args := add(output, 0x20)
      mstore(args, 0x20)
      mstore(add(args, 0x20), 0x20)
      mstore(add(args, 0x40), 0x20)
      mstore(add(args, 0x60), base)
      mstore(add(args, 0x80), exponent)
      mstore(add(args, 0xa0), p)

      // 0x05 is the modular exponent contract address
      if iszero(staticcall(not(0), 0x05, args, 0xc0, output, 0x20)) {
        revert(0, 0)
      }
      o := mload(output)
    }
  }

  /**
   * @dev g1YFromX computes a Y value for a G1 point based on an X value.
   * This computation is simply evaluating the curve equation for Y on a
   * given X, and allows a point on the curve to be represented by just
   * an X value + a sign bit.
   */
  function g1YFromX(uint256 x) internal view returns (uint256) {
    uint256 ySquare = (modExp(x, 3) + 3) % p;
    // check if there exists square root
    uint256 raised = modExp(ySquare, (p - 1) / uint256(2));
    if (raised != 1 || ySquare == 0) {
      return 0;
    }

    return modExp(ySquare, (p + 1) / 4);
  }

  /**
   * @dev Hash a byte array message, m, and map it deterministically to a
   * point on G1. Note that this approach was chosen for its simplicity /
   * lower gas cost on the EVM, rather than good distribution of points on
   * G1.
   */
  function g1HashToPoint(bytes memory m) internal view returns (G1Point memory o) {
    bytes32 h = sha256(m);
    uint256 x = uint256(h) % p;
    uint256 y;

    while (true) {
      y = g1YFromX(x);
      if (y > 0) {
        o = G1Point(x, y);
        return o;
      }
      x += 1;
    }
  }

  /**
   * @dev Wrap the point addition pre-compile introduced in Byzantium. Return
   * the sum of two points on G1. Revert if the provided points aren't on the
   * curve.
   */
  function g1Add(G1Point memory a, G1Point memory b) internal view returns (G1Point memory c) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let arg := mload(0x40)
      mstore(arg, mload(a))
      mstore(add(arg, 0x20), mload(add(a, 0x20)))
      mstore(add(arg, 0x40), mload(b))
      mstore(add(arg, 0x60), mload(add(b, 0x20)))
      // 0x60 is the ECADD precompile address
      if iszero(staticcall(not(0), 0x06, arg, 0x80, c, 0x40)) {
        revert(0, 0)
      }
    }
  }

  /**
   * @dev Return true if G1 point is on the curve.
   */
  function isG1PointOnCurve(G1Point memory point) internal view returns (bool) {
    return modExp(point.y, 2) == (modExp(point.x, 3) + 3) % p;
  }

  /**
   * @dev Wrap the scalar point multiplication pre-compile introduced in
   * Byzantium. The result of a point from G1 multiplied by a scalar should
   * match the point added to itself the same number of times. Revert if the
   * provided point isn't on the curve.
   */
  function scalarMultiply(G1Point memory p1, uint256 scalar) internal view returns (G1Point memory p2) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
      let arg := mload(0x40)
      mstore(arg, mload(p1))
      mstore(add(arg, 0x20), mload(add(p1, 0x20)))
      mstore(add(arg, 0x40), scalar)
      // 0x07 is the ECMUL precompile address
      if iszero(staticcall(not(0), 0x07, arg, 0x60, p2, 0x40)) {
        revert(0, 0)
      }
    }
  }

  function getQ() internal pure returns (uint256) {
    return q;
  }

  /**
   * @dev Gets generator of G1 group.
   * Taken from go-ethereum/crypto/bn256/cloudflare/curve.go
   */
  function g1() internal pure returns (G1Point memory) {
    return G1Point(g1x, g1y);
  }
}
