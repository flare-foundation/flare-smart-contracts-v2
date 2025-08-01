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

    address private initialGovernance;
    address private addressUpdater;
    address private registryAddress;

    uint256 private extensionId;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    address[] private mockPausingAddresses;
    address[] private mockSigners;
    uint256[] private privateKeys;

    function areSignaturesEq(
        Signature memory sig1, 
        Signature memory sig2
    ) 
        private pure 
        returns (bool) 
    {
        return sig1.v == sig2.v && sig1.r == sig2.r && sig1.s == sig2.s;
    }

    function getSignature(
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


    function setUp() public {
        extensionId = 1;
        realOwnerExtension1 = makeAddr("realOwnerExtension1");
        realOwnerExtension2 = makeAddr("realOwnerExtension2");

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


    function testOnlyExtensionOwner() public {
        address mockOwner = makeAddr("mockOwner");
        
        vm.expectRevert(ITeeGovernance.OnlyExtensionOwner.selector);
        vm.prank(mockOwner);
        // any function with onlyExtensionOwner modifier
        teeGovernance.setNewTeeGovernance(
            extensionId,
            mockSigners,
            1 // any
        );
    }

    
    function testSetNewTeeGovernance() public {
        address[] memory emptyMockSigners;
        
        vm.startPrank(realOwnerExtension1);
        
        vm.expectRevert(ITeeGovernance.NoSigners.selector);
        teeGovernance.setNewTeeGovernance(extensionId, emptyMockSigners, 1);

        vm.expectRevert(ITeeGovernance.InvalidThreshold.selector);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 0);
        vm.expectRevert(ITeeGovernance.InvalidThreshold.selector);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 3);

        uint64 signersThreshold = 1;
        bytes32 governanceHash = keccak256(abi.encode(mockSigners, signersThreshold));
        vm.expectEmit();
        emit ITeeGovernance.NewTeeGovernanceSet(extensionId, governanceHash, mockSigners, signersThreshold);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, signersThreshold);

        emptyMockSigners = new address[](2);
        emptyMockSigners[0] = makeAddr("emptyMocksigners1");
        emptyMockSigners[1] = emptyMockSigners[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.SignerAlreadyExists.selector,
                emptyMockSigners[0]
            )
        );
        teeGovernance.setNewTeeGovernance(extensionId, emptyMockSigners, signersThreshold);

        vm.stopPrank();
    }


    function testSetTeePausingAddresses() public {
        address[] memory emptyPausingAdresses;
        address[] memory pausingAddresses;

        vm.startPrank(realOwnerExtension1);
        // empty
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSet(extensionId, 0, emptyPausingAdresses);
        teeGovernance.setTeePausingAddresses(extensionId, emptyPausingAdresses);
        
        // new list
        pausingAddresses = new address[](1);
        pausingAddresses[0] = makeAddr("pausingAddress1");
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSet(extensionId, 1, pausingAddresses);
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);


        // duplicate values
        pausingAddresses = new address[](2);
        pausingAddresses[0] = makeAddr("pausingAddress2");
        pausingAddresses[1] = pausingAddresses[0]; // duplicate
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.PausingAddressAlreadyExists.selector,
                pausingAddresses[1]
            )
        );
        teeGovernance.setTeePausingAddresses(extensionId, pausingAddresses);

        // empty
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSet(extensionId, 2, emptyPausingAdresses);
        teeGovernance.setTeePausingAddresses(extensionId, emptyPausingAdresses);

        vm.stopPrank();
    }


    function testSignTeePausingAddresses() public {
        
        (address signer, uint256 privateKey) = makeAddrAndKey("signer");
        Signature memory signature;
        
        address[] memory mockSigner = new address[](1);
        mockSigner[0] = signer;

        vm.startPrank(realOwnerExtension1);
        // nonce can't be 0 (yet)
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
        
        // create a list to be signed
        teeGovernance.setNewTeeGovernance(extensionId, mockSigner, 1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);

        assertTrue(
            teeGovernance.isTeeGovernanceSigner(
                extensionId, 
                teeGovernance.getLatestTeeGovernanceHash(extensionId), signer
            )
        );

        signature = getSignature(0, mockPausingAddresses, privateKey);
        
        vm.expectEmit();
        emit ITeeGovernance.NewPausingAddressesSigned(extensionId, 0, signer, signature);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.AlreadySigned.selector,
                signer
            )
        );
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        vm.stopPrank();
    }


    function testGetLatestTeeGovernanceHash() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        
        bytes32 governanceHash = keccak256(abi.encode(mockSigners, 1)); // create governanceHash
        assertEq(teeGovernance.getLatestTeeGovernanceHash(extensionId), governanceHash);
    }


    function testGetTeeGovernanceThreshold() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);

        uint64 returnedThreshold = teeGovernance.getTeeGovernanceThreshold(extensionId, teeGovernance.getLatestTeeGovernanceHash(extensionId));
        assertEq(returnedThreshold, 1);
    }


    function testIsTeeGovernanceSigner() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 2);

        bytes32 governanceHash = teeGovernance.getLatestTeeGovernanceHash(extensionId);
        assertFalse(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, realOwnerExtension1));
        assertTrue(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, mockSigners[0]));
        assertTrue(teeGovernance.isTeeGovernanceSigner(extensionId, governanceHash, mockSigners[1]));
    }


    function testGetTeeGovernance() public {
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);

        bytes32 governanceHash = teeGovernance.getLatestTeeGovernanceHash(extensionId);
        address[] memory returnedSigners;
        uint64 returnedThreshold;
        (returnedSigners, returnedThreshold) = teeGovernance.getTeeGovernance(extensionId, governanceHash);

        assertTrue(returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] && 
            returnedThreshold == 1);
        assertFalse(returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] && 
            returnedThreshold == 2);
        assertFalse(returnedSigners[0] == realOwnerExtension1 && returnedSigners[1] == mockSigners[1] && 
            returnedThreshold == 1);

        vm.expectRevert(ITeeGovernance.InvalidGovernanceHash.selector);
        (returnedSigners, returnedThreshold) = teeGovernance.getTeeGovernance(extensionId + 1, governanceHash);
    }


    function testGetLatestTeeGovernance() public {
        vm.expectRevert(ITeeGovernance.GovernanceNotSet.selector);
        teeGovernance.getLatestTeeGovernance(extensionId);

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 2);
        vm.stopPrank();
        
        address[] memory returnedSigners;
        uint64 returnedThreshold;
        (returnedSigners, returnedThreshold) = teeGovernance.getLatestTeeGovernance(extensionId);

        assertTrue(returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] && returnedThreshold == 2);
        assertFalse(returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[1] && returnedThreshold == 1);
        assertFalse(returnedSigners[0] == mockSigners[0] && returnedSigners[1] == mockSigners[0] && returnedThreshold == 1);
    }


    function testIsGovernanceHashValid() public {
        bytes32 governanceHash = keccak256(abi.encode(mockSigners, 1));
        // no governance set
        assertFalse(teeGovernance.isGovernanceHashValid(extensionId, governanceHash));
        
        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        
        vm.prank(realOwnerExtension2);
        teeGovernance.setNewTeeGovernance(extensionId + 1, mockSigners, 2);

        assertFalse(teeGovernance.isGovernanceHashValid(extensionId + 1, governanceHash)); // wrong threshold
        assertTrue(teeGovernance.isGovernanceHashValid(extensionId, governanceHash));

        assertFalse(teeGovernance.isGovernanceHashValid(extensionId, bytes32(0x0)));
        assertTrue(teeGovernance.isGovernanceHashValid(extensionId, teeGovernance.getLatestTeeGovernanceHash(extensionId)));
    }


    function testGetTeePausingAddresses() public {
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.getTeePausingAddresses(extensionId, 5);

        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);

        Signature[] memory returnedSignatures;
        address[] memory returnedPausingAddresses;

        (returnedPausingAddresses, returnedSignatures) = teeGovernance.getTeePausingAddresses(extensionId, 0);
        assertTrue(returnedPausingAddresses[0] == mockPausingAddresses[0] && returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 0
        );

        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);

        Signature[] memory signatures = new Signature[](2);
        signatures[0] = getSignature(0, mockPausingAddresses, privateKeys[0]);
        signatures[1] = getSignature(0, mockPausingAddresses, privateKeys[1]);

        assertTrue(teeGovernance.isTeeGovernanceSigner(extensionId, teeGovernance.getLatestTeeGovernanceHash(extensionId), mockSigners[0]));

        teeGovernance.signTeePausingAddresses(extensionId, 0, signatures[0]);
        teeGovernance.signTeePausingAddresses(extensionId, 0, signatures[1]);


        (returnedPausingAddresses, returnedSignatures) = teeGovernance.getTeePausingAddresses(extensionId, 0);
        assertTrue(returnedPausingAddresses[0] == mockPausingAddresses[0] && returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 2
        );
    }


    function testGetLatestTeePausingAddresses() public {
        vm.expectRevert(ITeeGovernance.GovernanceNotSet.selector);
        teeGovernance.getLatestTeeGovernance(extensionId);

        vm.prank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);

        uint256 returnedNonce;
        address[] memory returnedPausingAddresses;
        Signature[] memory returnedSignatures;
        (returnedNonce, returnedPausingAddresses, returnedSignatures) = teeGovernance.getLatestTeePausingAddresses(extensionId);

        assertTrue(
            returnedNonce == 0 && 
            returnedPausingAddresses[0] == mockPausingAddresses[0] && returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 0    
        );

        
        address[] memory mockSigner = new address[](1);
        uint256 privateKey;
        (mockSigner[0], privateKey) = makeAddrAndKey("mockSigner");

        vm.prank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigner, 1);

        Signature memory signature = getSignature(0, mockPausingAddresses, privateKey);

        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        (returnedNonce, returnedPausingAddresses, returnedSignatures) = teeGovernance.getLatestTeePausingAddresses(extensionId);
        assertTrue(
            returnedNonce == 0 && 
            returnedPausingAddresses[0] == mockPausingAddresses[0] && returnedPausingAddresses[1] == mockPausingAddresses[1] &&
            returnedSignatures.length == 1 && areSignaturesEq(returnedSignatures[0], signature)
        );
    }


    function testIsTeePausingAddressesSigner() public {
        assertFalse(teeGovernance.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        Signature memory signature = getSignature(0, mockPausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
        assertFalse(teeGovernance.isTeePausingAddressesSigner(extensionId, realOwnerExtension1));

        vm.expectRevert(
            abi.encodeWithSelector(
                ITeeGovernance.NotASigner.selector,
                mockSigners[0]
            )
        );
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        vm.stopPrank();
        
        assertTrue(teeGovernance.isTeePausingAddressesSigner(extensionId, mockSigners[0]));
        assertTrue(teeGovernance.isTeePausingAddressesSigner(extensionId, mockSigners[1]));
    }


    function testHasSignedTeePausingAddresses() public {
        vm.expectRevert(ITeeGovernance.InvalidNonce.selector);
        teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, realOwnerExtension1);

        Signature memory signature = getSignature(0, mockPausingAddresses, privateKeys[0]);

        vm.startPrank(realOwnerExtension1);
        teeGovernance.setNewTeeGovernance(extensionId, mockSigners, 1);
        teeGovernance.setTeePausingAddresses(extensionId, mockPausingAddresses);
        vm.stopPrank();

        // signer: mockSigners[0]
        teeGovernance.signTeePausingAddresses(extensionId, 0, signature);

        assertTrue(teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, mockSigners[0]));
        assertFalse(teeGovernance.hasSignedTeePausingAddresses(extensionId, 0, mockSigners[1]));
    }
}