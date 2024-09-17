// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../lib/Bn256.sol";

contract Bn256Mock {

    G1Point public g1 = Bn256.g1();

    function runHashingTest() public view {
        string memory hello = "hello!";
        string memory goodbye = "goodbye.";
        G1Point memory p1;
        G1Point memory p2;
        p1 = Bn256.g1HashToPoint(bytes(hello));
        p2 = Bn256.g1HashToPoint(bytes(goodbye));

        require(p1.x != 0, "X should not equal 0 in a hashed point.");
        require(p1.y != 0, "Y should not equal 0 in a hashed point.");
        require(p2.x != 0, "X should not equal 0 in a hashed point.");
        require(p2.y != 0, "Y should not equal 0 in a hashed point.");

        require(Bn256.isG1PointOnCurve(p1), "Hashed points should be on the curve.");
        require(Bn256.isG1PointOnCurve(p2), "Hashed points should be on the curve.");
    }

    function runHashAndAddTest() public view {
        string memory hello = "hello!";
        string memory goodbye = "goodbye.";
        G1Point memory p1;
        G1Point memory p2;
        p1 = Bn256.g1HashToPoint(bytes(hello));
        p2 = Bn256.g1HashToPoint(bytes(goodbye));

        G1Point memory p3;
        G1Point memory p4;

        p3 = Bn256.g1Add(p1, p2);
        p4 = Bn256.g1Add(p2, p1);

        require(p3.x == p4.x, "Point addition should be commutative.");
        require(p3.y == p4.y, "Point addition should be commutative.");

        require(Bn256.isG1PointOnCurve(p3), "Added points should be on the curve.");
    }

    function runHashAndScalarMultiplyTest() public view {
        string memory hello = "hello!";
        G1Point memory p1;
        G1Point memory p2;
        p1 = Bn256.g1HashToPoint(bytes(hello));

        p2 = Bn256.scalarMultiply(p1, 12);

        require(Bn256.isG1PointOnCurve(p2), "Multiplied point should be on the curve.");
    }

    function publicG1Add(G1Point memory a, G1Point memory b) public view returns (G1Point memory c) {
        c = Bn256.g1Add(a, b);
    }

    function publicG1ScalarMultiply(G1Point memory a, uint256 s) public view returns (G1Point memory c) {
        c = Bn256.scalarMultiply(a, s);
    }
}

// 0xaf919a67ba6e46b58978179552e7a3a673eddb24bacc2f6a5d7c2f74504e2ca6
// 032f919a67ba6e46b58978179552e7a3a673eddb24bacc2f6a5d7c2f74504e2ca6
