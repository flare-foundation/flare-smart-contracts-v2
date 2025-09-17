// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Test } from "forge-std/Test.sol";
import { TeeSystemStateVerifier } from "../../../../contracts/tee/implementation/TeeSystemStateVerifier.sol";
import { TeeSystemStateVerifierProxy } from "../../../../contracts/tee/proxy/TeeSystemStateVerifierProxy.sol";
import { IITeeSystemStateVerifier } from "../../../../contracts/tee/interface/IITeeSystemStateVerifier.sol";
import { ITeeMachineRegistry } from "../../../../contracts/userInterfaces/tee/ITeeMachineRegistry.sol";
import { ITeeExtensionRegistry } from "../../../../contracts/userInterfaces/tee/ITeeExtensionRegistry.sol";
import { IGovernanceSettings } from "flare-smart-contracts/contracts/userInterfaces/IGovernanceSettings.sol";

contract TeeSystemStateVerifierTest is Test {

    TeeSystemStateVerifier private teeSystemStateVerifier;
    TeeSystemStateVerifier private teeSystemStateVerifierImpl;
    TeeSystemStateVerifierProxy private teeSystemStateVerifierProxy;

    address private initialGovernance;
    address private addressUpdater;
    address private teeExtensionRegistry;
    address private teeMachineRegistry;

    address private teeId;
    bytes32 private stateVersion;
    IITeeSystemStateVerifier.TeeSystemState private teeSystemState;
    bytes32 private teeGovernanceHash;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    function setUp() public {
        teeId = makeAddr("teeId");
        stateVersion = keccak256("stateVersion");
        teeGovernanceHash = keccak256("teeGovernanceHash");
        teeSystemState.status = IITeeSystemStateVerifier.TeeMachineStatus.ACTIVE;
        teeSystemState.initialTeeId = teeId;
        teeSystemState.teeGovernanceHash = teeGovernanceHash;

        addressUpdater = makeAddr("addressUpdater");
        initialGovernance = makeAddr("initialGovernance");

        teeSystemStateVerifierImpl = new TeeSystemStateVerifier();
        teeSystemStateVerifierProxy = new TeeSystemStateVerifierProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeSystemStateVerifierImpl)
        );
        teeSystemStateVerifier = TeeSystemStateVerifier(address(teeSystemStateVerifierProxy));

        contractNameHashes = new bytes32[](3);
        contractAddresses = new address[](3);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractNameHashes[2] = keccak256(abi.encode("TeeMachineRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");
        contractAddresses[2] = makeAddr("TeeMachineRegistry");

        vm.prank(addressUpdater);
        teeSystemStateVerifier.updateContractAddresses(contractNameHashes, contractAddresses);

        teeExtensionRegistry = address(teeSystemStateVerifier.teeExtensionRegistry());
        teeMachineRegistry = address(teeSystemStateVerifier.teeMachineRegistry());

        _mockGetTeeMachineWithAttestationData();
        _mockGetExtensionId();
        _mockGetTeeGovernanceHash(teeGovernanceHash);
    }


    // verifyTeeSystemState
    function testVerifyTeeSystemStateNotValid1() public {
        teeSystemState.status = IITeeSystemStateVerifier.TeeMachineStatus.PAUSED;
        bool isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertFalse(isValid);
    }

    function testVerifyTeeSystemStateNotValid2() public {
        teeSystemState.initialTeeId = makeAddr("wrongTeeId");
        bool isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertFalse(isValid);
    }

    function testVerifyTeeSystemStateNotValid3() public {
        teeSystemState.teeGovernanceHash = keccak256("wrongTeeGovernanceHash");
        bool isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertFalse(isValid);
    }


    function testVerifyTeeSystemStateReturnStateVersion() public {
        assertNotEq(teeGovernanceHash, bytes32(0));
        _mockGetTeeGovernanceHash(teeGovernanceHash);
        bool isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, bytes32(0), abi.encode(teeSystemState)
        );
        assertFalse(isValid);

        isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, bytes32(0), new bytes(0)
        );
        assertFalse(isValid);

        _mockGetTeeGovernanceHash(bytes32(0));
        isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, bytes32(0), abi.encode(teeSystemState)
        );
        assertFalse(isValid);
        isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, bytes32(0), new bytes(0)
        );
        assertTrue(isValid);
    }


    function testVerifyTeeSystemStateRevertEvmError() public {
        vm.expectRevert();
        teeSystemStateVerifier.verifyTeeSystemState(
            teeId, stateVersion, new bytes(0)
        );
    }


    function testVerifyTeeSystemState() public view {
        bool isValid = teeSystemStateVerifier.verifyTeeSystemState(
            teeId, stateVersion, abi.encode(teeSystemState)
        );
        assertTrue(isValid);
    }


    function _mockGetTeeMachineWithAttestationData() private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getTeeMachineWithAttestationData.selector
            ),
            abi.encode(
                ITeeMachineRegistry.TeeMachineWithAttestationData(
                    teeId,
                    teeId,
                    "url",
                    keccak256("codeHash"),
                    keccak256("platform")
                )
            )
        );
    }


    function _mockGetExtensionId() private {
        vm.mockCall(
            teeMachineRegistry,
            abi.encodeWithSelector(
                ITeeMachineRegistry.getExtensionId.selector
            ),
            abi.encode(1)
        );
    }

    function _mockGetTeeGovernanceHash(bytes32 _teeGovernanceHash) private {
        vm.mockCall(
            teeExtensionRegistry,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getTeeGovernanceHash.selector
            ),
            abi.encode(_teeGovernanceHash)
        );
    }
}