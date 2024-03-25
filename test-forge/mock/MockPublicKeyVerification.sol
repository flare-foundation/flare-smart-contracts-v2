// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../contracts/protocol/interface/IIPublicKeyVerifier.sol";

contract MockPublicKeyVerification is IIPublicKeyVerifier {

    function verifyPublicKey(
        address _voter,
        bytes32 _part1,
        bytes32 _part2,
        bytes memory _verificationData
    )
        external pure
    {
        (uint256 signature, uint256 x, uint256 y) = abi.decode(_verificationData, (uint256, uint256, uint256));

        require(
            _voter != address(0) && _part1 != bytes32(0) &&_part2 != bytes32(0) && signature == 1 && x == 2 && y == 3,
            "public key verification failed");
    }
}