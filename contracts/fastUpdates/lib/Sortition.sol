// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Bn256} from "./Bn256.sol";


struct SortitionCredential {
    uint256 replicate;
    Bn256.G1Point gamma;
    uint256 c;
    uint256 s;
}

struct SortitionState {
    uint256 baseSeed;
    uint256 blockNumber;
    uint256 scoreCutoff;
    uint256 weight;

    Bn256.G1Point pubKey;
}

function verifySortitionCredential(
    SortitionState memory sortitionState,
    SortitionCredential memory sortitionCredential
) view returns (bool, uint256) {
    require(sortitionCredential.replicate < sortitionState.weight,
        "Credential's replicate value is not less than provider's weight");
    bool check = verifySortitionProof(sortitionState, sortitionCredential);
    uint256 vrfVal = sortitionCredential.gamma.x;

    return (check && vrfVal <= sortitionState.scoreCutoff, vrfVal);
}

function verifySortitionProof(
    SortitionState memory sortitionState,
    SortitionCredential memory sortitionCredential
) view returns (bool) {
    require(Bn256.isG1PointOnCurve(sortitionState.pubKey)); // this also checks that it is not zero
    require(Bn256.isG1PointOnCurve(sortitionCredential.gamma));
    Bn256.G1Point memory u = Bn256.g1Add(
        Bn256.scalarMultiply(sortitionState.pubKey, sortitionCredential.c),
        Bn256.scalarMultiply(Bn256.g1(), sortitionCredential.s)
    );

    bytes memory seed =
        abi.encodePacked(sortitionState.baseSeed, sortitionState.blockNumber, sortitionCredential.replicate);
    Bn256.G1Point memory h = Bn256.g1HashToPoint(seed);

    Bn256.G1Point memory v = Bn256.g1Add(
        Bn256.scalarMultiply(sortitionCredential.gamma, sortitionCredential.c),
        Bn256.scalarMultiply(h, sortitionCredential.s)
    );
    uint256 c2 = uint256(sha256(abi.encode(Bn256.g1(), h, sortitionState.pubKey, sortitionCredential.gamma, u, v)));
    c2 = c2 % Bn256.getQ();

    return c2 == sortitionCredential.c;
}

function verifySignature(
    Bn256.G1Point memory pk,
    bytes32 message,
    uint256 signature,
    Bn256.G1Point memory r
) view {
    // Construct e = H(Pₓ ‖ Pₚ ‖ m ‖ Rₑ) mod Q
    uint256 e = uint256(keccak256(abi.encodePacked(pk.x, pk.y, message, r.x, r.y))) % Bn256.getQ();

    Bn256.G1Point memory gs = Bn256.scalarMultiply(Bn256.g1(), signature);
    Bn256.G1Point memory pke = Bn256.scalarMultiply(pk, e);
    Bn256.G1Point memory rCheck = Bn256.g1Add(gs, pke);

    require((r.x == rCheck.x) && (r.y == rCheck.y), "public key verification error");
}