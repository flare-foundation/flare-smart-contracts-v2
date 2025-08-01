// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../../../../contracts/tee/implementation/TeeGovernance.sol";
import "../../../../contracts/tee/proxy/TeeGovernanceProxy.sol";
import "../../../../contracts/userInterfaces/tee/ITeeGovernance.sol";

contract TeeGovernanceTest is Test {

    TeeGovernance private teeGovernance;
    TeeGovernance private teeGovernanceImpl;
    TeeGovernanceProxy private teeGovernanceProxy;

    address private realOwnerExtension1;
    address private realOwnerExtension2;
    address private mockOwner;

    address private initialGovernance;
    address private addressUpdater;
    address private registryAddress;

    uint256 private extensionId;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private mockPausingAddresses;
    address[] private mockSigners;
    uint256[] private privateKeys;


    function setUp() public {
        extensionId = 1;
        realOwnerExtension1 = makeAddr("realOwnerExtension1");
        realOwnerExtension2 = makeAddr("realOwnerExtension2");
        mockOwner = makeAddr("mockOwner");

        initialGovernance = makeAddr("initialGovernance");
        addressUpdater = makeAddr("addressUpdater");
        teeGovernanceImpl = new TeeGovernance();
        
        teeGovernanceProxy = new TeeGovernanceProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            initialGovernance,
            addressUpdater,
            address(teeGovernanceImpl)
        );
        teeGovernance = TeeGovernance(address(teeGovernanceProxy));

        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("TeeExtensionRegistry"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = makeAddr("TeeExtensionRegistry");

        vm.prank(addressUpdater);
        teeGovernance.updateContractAddresses(contractNameHashes, contractAddresses);

        registryAddress = address(teeGovernance.teeExtensionRegistry());

        vm.mockCall(
            registryAddress,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector,
                extensionId
            ),
            abi.encode(realOwnerExtension1)
        );

        vm.mockCall(
            registryAddress,
            abi.encodeWithSelector(
                ITeeExtensionRegistry.getExtensionOwner.selector,
                extensionId + 1
            ),
            abi.encode(realOwnerExtension2)
        );

        mockSigners = new address[](2);
        privateKeys = new uint256[](2);
        (mockSigners[0], privateKeys[0]) = makeAddrAndKey("mockSigner1");
        (mockSigners[1], privateKeys[1]) = makeAddrAndKey("mockSigner2");

        mockPausingAddresses = new address[](2);
        mockPausingAddresses[0] = makeAddr("mockPausingAddresses1");
        mockPausingAddresses[1] = makeAddr("mockPausingAddresses2");
    }


    // setNewTeeGovernance
    function testSetNewTeeGovernanceRevertOnlyExtensionOwner() public {        
        vm.expectRevert(ITeeGovernance.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        teeGovernance.setNewTeeGovernance(
            extensionId,
            mockSigners,
            1
        );
    }

    
    function testSetNewTeeGovernanceRevertNoSigners() public {
        address[] memory emptyMockSigners;
        vm.prank(realOwnerExtension1);
        vm.expectRevert(ITeeGovernance.NoSigners.selector);
        teeGovernance.setNewTeeGovernance(extensionId, emptyMockSigners, 1);
    }


    function testSetNewTeeGovernanceRevertInvalidThreshold() public {
        vm.startPrank(realOwnerExtension1);
        vm.expectRevert(ITeeGovernance.InvalidThreshold.selector);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 0);
        vm.expectRevert(ITeeGovernance.InvalidThreshold.selector);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 3);
        vm.stopPrank();
    }


    function testSetNewTeeGovernanceRevertSignerAlreadyExists() public {
        mockSigners[1] = mockSigners[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.SignerAlreadyExists.selector,
                mockSigners[0]
            )
        );
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
    }


    function testSetNewTeeGovernance() public { 
        bytes32 governanceHash = keccak256(abi.encode(mockSigners, 1));
        vm.prank(realOwnerExtension1);
        vm.expectEmit();
        emit ITeeGovernance.NewTeeGovernanceSet(extensionId, governanceHash, mockSigners, 1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
    }


    // setTeePausingAddresses
    function testSetTeePausingAddressesRevertOnlyExtensionOwner() public {
        vm.expectRevert(ITeeGovernance.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
    }


    function testSetTeePausingAddressesRevertPausingAddressAlreadyExists() public {
        mockPausingAddresses[1] = mockPausingAddresses[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.PausingAddressAlreadyExists.selector,
                mockPausingAddresses[0]
            )
        );
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
    }


    function testSetTeePausingAddresses() public {
        address[] memory emptyPausingAdresses;

        vm.startPrank(realOwnerExtension1);
        // empty
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSet(extensionId, 0, emptyPausingAdresses);
        teeGovernance.setTeePausingAddresses(extensionId, emptyPausingAdresses);
        
        // new list
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSet(extensionId, 1, mockPausingAddresses);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);

        vm.stopPrank();
    }


    // signTeePausingAddresses
    function testSignTeePausingAddressesRevertInvalidNonce() public {
        Signature memory signature = _getSignature(0, mockSigners, privateKeys[0]);
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddressesRevertNotASigner() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);

        Signature memory signature = _getSignature(0, mockPausingAddresses, privateKeys[0]);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.NotASigner.selector,
                mockSigners[0]
            )
        );
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddressesAlreadySigned() public {
        Signature memory signature = _getSignature(0, mockPausingAddresses, privateKeys[0]);
        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
        vm.stopPrank();

        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.AlreadySigned.selector,
                mockSigners[0]
            )
        );
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
    }


    function testSignTeePausingAddresses() public {
        Signature memory signature = _getSignature(0, mockPausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
        vm.stopPrank();
        
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSigned(extensionId, 0, mockSigners[0], signature);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
        vm.stopPrank();
    }


    // getLatestTeeGovernanceHash
    function testGetLatestTeeGovernanceHash() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        
        bytes32 governanceHash = keccak256(abi.encode(mockSigners, 1)); // create governanceHash
        assertEq(teeGovernance.getLatestTeeGovernanceHash(extensionId), governanceHash);
    }


    // getTeeGovernanceThreshold
    function testGetTeeGovernanceThreshold() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);

        uint64 returnedThreshold = 
            teeGovernance.getTeeGovernanceThreshold(
                extensionId, teeGovernance.getLatestTeeGovernanceHash(extensionId)
            );
        assertEq(returnedThreshold, 1);
    }


    // isTeeGovernanceSigner
    function testIsTeeGovernanceSigner() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 2);

        bytes32 governanceHash = teeGovernance.getLatestTeeGovernanceHash(extensionId);
        assertFalse(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, realOwnerExtension1));
        assertTrue(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, mockSigners[0]));
        assertTrue(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, mockSigners[1]));
    }


    // getTeeGovernance
    function testGetTeeGovernanceRevertInvalidGovernanceHash() public {
        address[] memory returnedSigners;
        uint64 returnedThreshold;
        bytes32 governanceHash = teeGovernance.getLatestTeeGovernanceHash(extensionId);
        vm.expectRevert(ITeeGovernance.InvalidGovernanceHash.selector);
        (returnedSigners, returnedThreshold) = teeGovernance.getTeeGovernance(extensionId + 1, governanceHash);
    }


    function testGetTeeGovernance() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);

        bytes32 governanceHash = teeGovernance.getLatestTeeGovernanceHash(extensionId);
        address[] memory returnedSigners;
        uint64 returnedThreshold;
        (returnedSigners, returnedThreshold) = teeGovernance.getTeeGovernance(extensionId, governanceHash);

        assertTrue(
            returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] && 
            returnedThreshold == 1
        );
        assertFalse(
            returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] && 
            returnedThreshold == 0
        );
        assertFalse(
            returnedSigners[0] == realOwnerExtension1 && returnedSigners[1] == mockSigners[1] && 
            returnedThreshold == 1
        );
    }


    // getLatestTeeGovernance
    function testGetLatestTeeGovernanceRevertGovernanceNotSet() public {
        vm.expectRevert(ITeeGovernance.GovernanceNotSet.selector);
        teeGovernance.getLatestTeeGovernance(extensionId);
    }


    function testGetLatestTeeGovernance() public {
        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 2);
        vm.stopPrank();
        
        address[] memory returnedSigners;
        uint64 returnedThreshold;
        (returnedSigners, returnedThreshold) = teeGovernance.getLatestTeeGovernance(extensionId);

        assertTrue(
            returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] &&
            returnedThreshold == 2
        );
        assertFalse(
            returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] &&
            returnedThreshold == 1
        );
        assertFalse(
            returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[0] &&
            returnedThreshold == 1
        );
    }


    // isGovernanceHashValid
    function testIsGovernanceHashValid() public {
        bytes32 governanceHash = keccak256(abi.encode(mockSigners, 1));
        // no governance set
        assertFalse(teeGovernance.isGovernanceHashValid(extensionId, governanceHash));
        
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        
        vm.prank(realOwnerExtension2);
        teeGovernance.setNewTeeGovernance(extensionId + 1, mockSigners, 2);

        assertFalse(teeGovernance.isGovernanceHashValid(extensionId + 1, governanceHash));
        assertTrue(teeGovernance.isGovernanceHashValid(extensionId, governanceHash));

        assertFalse(teeGovernance.isGovernanceHashValid(extensionId, bytes32(0x0)));
        assertTrue(
            teeGovernance.isGovernanceHashValid(
                extensionId, teeGovernance.getLatestTeeGovernanceHash(extensionId)
            )
        );
    }


    // getTeePausingAddresses
    function testGetTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.getTeePausingAddresses(extensionId, 5);
    }


    function testGetTeePausingAddresses() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);

        Signature[] memory returnedSignatures;
        address[] memory returnedPausingAddresses;

        (returnedPausingAddresses, returnedSignatures) = teeGovernance.getTeePausingAddresses(extensionId, 0);
        assertTrue(
            returnedPausingAddresses[0] == mockPausingAddresses[0] &&
            returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 0
        );

        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);

        Signature[] memory signatures = new Signature[](2);
        signatures[0] = _getSignature(0, mockPausingAddresses, privateKeys[0]);
        signatures[1] = _getSignature(0, mockPausingAddresses, privateKeys[1]);

        teeGovernance.signTeePausingAddresses(extensionId, 0, signatures[0]);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signatures[1]);

        (returnedPausingAddresses, returnedSignatures) = teeGovernance.getTeePausingAddresses(extensionId, 0);
        assertTrue(
            returnedPausingAddresses[0] == mockPausingAddresses[0] &&
            returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 2
        );
    }


    // getLatestTeePausingAddresses
    function testGetLatestTeePausingAddressesRevertPausingAddressesNotSet() public {
        vm.expectRevert(ITeeGovernance.PausingAddressesNotSet.selector);
        teeGovernance.getLatestTeePausingAddresses(extensionId);
    }


    function testGetLatestTeePausingAddresses() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);

        uint256 returnedNonce;
        address[] memory returnedPausingAddresses;
        Signature[] memory returnedSignatures;
        (returnedNonce, returnedPausingAddresses, returnedSignatures) =
            teeGovernance.getLatestTeePausingAddresses(extensionId);

        assertTrue(
            returnedNonce == 0 && 
            returnedPausingAddresses[0] == mockPausingAddresses[0] &&
            returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 0    
        );
        
        address[] memory mockSigner = new address[](1);
        uint256 privateKey;
        (mockSigner[0], privateKey) = makeAddrAndKey("mockSigner");

        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigner, 1);

        Signature memory signature = _getSignature(0, mockPausingAddresses, privateKey);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        (returnedNonce, returnedPausingAddresses, returnedSignatures) =
            teeGovernance.getLatestTeePausingAddresses(extensionId);
        assertTrue(
            returnedNonce == 0 && 
            returnedPausingAddresses[0] == mockPausingAddresses[0] &&
            returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 1 && _areSignaturesEq(returnedSignatures[0], signature)
        );
    }


    // isTeePausingAddressesSigner
    function testIsTeePausingAddressesSigner() public {
        assertFalse(teeGovernance.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
        assertFalse(teeGovernance.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        vm.stopPrank();
        
        assertTrue(teeGovernance.isTeePausingAddressesSigner(extensionId, mockSigners[0]));
        assertTrue(teeGovernance.isTeePausingAddressesSigner(extensionId, mockSigners[1]));
    }


    // hasSignedTeePausingAddresses
    function testHasSignedTeePausingAddressesRevertInvalidNonce() public {
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, realOwnerExtension1);
    }


    function testHasSignedTeePausingAddresses() public {
        Signature memory signature = _getSignature(0, mockPausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
        vm.stopPrank();

        // signer: mockSigners[0]
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        assertTrue(teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, mockSigners[0]));
        assertFalse(teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, mockSigners[1]));
    }


    function _areSignaturesEq(
        Signature memory sig1, 
        Signature memory sig2
    ) 
        private pure 
        returns (bool) 
    {
        return sig1.v == sig2.v && sig1.r == sig2.r && sig1.s == sig2.s;
    }


    function _getSignature(
        uint256 nonce,
        address[] memory pausingAddresses,
        uint256 privateKey
    ) 
        private pure
        returns (Signature memory sig)
    {
        bytes32 hashOfPausingAddresses = keccak256(abi.encode("TEE_PAUSING_ADDRESSES", nonce, pausingAddresses));
        bytes32 signedMessageHash = MessageHashUtils.toEthSignedMessageHash(hashOfPausingAddresses);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, signedMessageHash);
        sig = Signature(v, r, s);
    }
}