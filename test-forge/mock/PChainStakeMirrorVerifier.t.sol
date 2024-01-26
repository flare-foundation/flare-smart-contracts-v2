// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/mock/PChainStakeMirrorVerifier.sol";

contract PChainStakeMirrorVerifierTest is Test {
  PChainStakeMirrorVerifier private verifier;
  address private mockRelay;

  function setUp() public {
    mockRelay = makeAddr("relay");
    IPChainStakeMirrorMultiSigVoting pChainStakeMirrorVoting = IPChainStakeMirrorMultiSigVoting(makeAddr("voting"));
    verifier = new PChainStakeMirrorVerifier(pChainStakeMirrorVoting, IRelay(mockRelay), 60, 2678400, 10, 1e8);
  }

  function testVerifyStake() public {
    uint64 startTime = 15;

    (
      IPChainStakeMirrorVerifier.PChainStake memory stakeData,
      bytes32[] memory merkleProof,
      bytes32 merkleRoot
    ) = constructMerkleProof(startTime, 15000, 1e4, 3);

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(merkleRoot)
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, true);
  }

  function testVerifyStakeNoRelay() public {
    uint64 startTime = 15;

    (
      IPChainStakeMirrorVerifier.PChainStake memory stakeData,
      bytes32[] memory merkleProof,
      bytes32 merkleRoot
    ) = constructMerkleProof(startTime, 15000, 1e4, 3);

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(bytes32(0))
    );

    vm.mockCall(
      makeAddr("voting"),
      abi.encodeWithSelector(bytes4(keccak256("getMerkleRoot(uint256)")), 3),
      abi.encode(merkleRoot)
    );

    vm.mockCall(
      makeAddr("voting"),
      abi.encodeWithSelector(bytes4(keccak256("getEpochId(uint256)")), startTime),
      abi.encode(3)
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, true);
  }

  function testVerifyStakeFailStartTime1() public {
    uint64 startTime = 150000;

    (
      IPChainStakeMirrorVerifier.PChainStake memory stakeData,
      bytes32[] memory merkleProof,
      bytes32 merkleRoot
    ) = constructMerkleProof(startTime, 15000, 1e4, 3);

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(merkleRoot)
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, false);
  }

  function testVerifyStakeFailStartTime2() public {
    uint64 startTime = 15003;

    (
      IPChainStakeMirrorVerifier.PChainStake memory stakeData,
      bytes32[] memory merkleProof,
      bytes32 merkleRoot
    ) = constructMerkleProof(startTime, 15000, 1e4, 3);

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(merkleRoot)
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, false);
  }

  function testVerifyStakeFailStartTime3() public {
    uint64 startTime = 15000;

    (
      IPChainStakeMirrorVerifier.PChainStake memory stakeData,
      bytes32[] memory merkleProof,
      bytes32 merkleRoot
    ) = constructMerkleProof(startTime, 1500000000, 1e4, 3);

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(merkleRoot)
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, false);
  }

  function testVerifyStakeFailWeight1() public {
    uint64 startTime = 15000;

    (
      IPChainStakeMirrorVerifier.PChainStake memory stakeData,
      bytes32[] memory merkleProof,
      bytes32 merkleRoot
    ) = constructMerkleProof(startTime, 15100, 1e9, 3);

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(merkleRoot)
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, false);
  }

  function testVerifyStakeFailWeight2() public {
    uint64 startTime = 15000;

    (
      IPChainStakeMirrorVerifier.PChainStake memory stakeData,
      bytes32[] memory merkleProof,
      bytes32 merkleRoot
    ) = constructMerkleProof(startTime, 15100, 1, 3);

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(merkleRoot)
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, false);
  }

  function testVerifyStakeFailRoot() public {
    uint64 startTime = 15000;

    (IPChainStakeMirrorVerifier.PChainStake memory stakeData, bytes32[] memory merkleProof, ) = constructMerkleProof(
      startTime,
      15100,
      1,
      3
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("getVotingRoundId(uint256)")), startTime),
      abi.encode(3)
    );

    vm.mockCall(
      mockRelay,
      abi.encodeWithSelector(bytes4(keccak256("merkleRoots(uint256,uint256)")), 1, 3),
      abi.encode(keccak256("neki"))
    );

    bool verify = verifier.verifyStake(stakeData, merkleProof);

    assertEq(verify, false);
  }

  function constructMerkleProof(
    uint64 startTime,
    uint64 endTime,
    uint64 weight,
    uint8 depth
  )
    internal
    returns (IPChainStakeMirrorVerifier.PChainStake memory stakeData, bytes32[] memory merkleProof, bytes32 merkleRoot)
  {
    stakeData = IPChainStakeMirrorVerifier.PChainStake(
      keccak256(abi.encode("txId")),
      0,
      bytes20(makeAddr("inputAddress")),
      bytes20(makeAddr("nodeId")),
      startTime,
      endTime,
      weight
    );

    bytes32 stakeHash = keccak256(abi.encode(stakeData));

    merkleProof = new bytes32[](depth);

    bytes32 currentHash = stakeHash;

    for (uint8 j = 0; j < depth; j++) {
      bytes32 otherHash = keccak256(abi.encode(j));
      merkleProof[j] = otherHash;
      currentHash = otherHash < currentHash
        ? keccak256(abi.encode(otherHash, currentHash))
        : keccak256(abi.encode(currentHash, otherHash));
    }
    merkleRoot = currentHash;
  }
}
