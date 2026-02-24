// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../../contracts/fdc/implementation/FdcVerification.sol";
import "../../../../contracts/fdc/implementation/FdcVerificationProxy.sol";
import "../../../../contracts/userInterfaces/IRelay.sol";

// solhint-disable-next-line max-states-count
contract FdcVerificationTest is Test {

    FdcVerification private fdcVerification;
    FdcVerification private fdcVerificationImplementation;
    FdcVerificationProxy private fdcVerificationProxy;
    address private mockFlareContractRegistry;

    address private governance;
    address private addressUpdater;
    address private mockRelay;

    bytes32[] private contractNameHashes;
    address[] private contractAddresses;

    uint8 private constant FDC_PROTOCOL_ID = 200;

    function setUp() public {
        governance = makeAddr("governance");
        addressUpdater = makeAddr("addressUpdater");

        // deploy contracts
        fdcVerificationImplementation = new FdcVerification();
        fdcVerificationProxy = new FdcVerificationProxy(
            IGovernanceSettings(makeAddr("governanceSettings")),
            governance,
            addressUpdater,
            FDC_PROTOCOL_ID,
            address(fdcVerificationImplementation)
        );
        fdcVerification = FdcVerification(address(fdcVerificationProxy));

        // set contract addresses
        mockRelay = makeAddr("relay");

        vm.prank(addressUpdater);
        contractNameHashes = new bytes32[](2);
        contractAddresses = new address[](2);
        contractNameHashes[0] = keccak256(abi.encode("AddressUpdater"));
        contractNameHashes[1] = keccak256(abi.encode("Relay"));
        contractAddresses[0] = addressUpdater;
        contractAddresses[1] = mockRelay;
        fdcVerification.updateContractAddresses(contractNameHashes, contractAddresses);

    }

    function testFdcProtocolId() public {
        assertEq(fdcVerification.fdcProtocolId(), FDC_PROTOCOL_ID);
    }

    function testVerifyAddressValidity() public {
        IAddressValidity.Response memory response;
        response.attestationType = bytes32("AddressValidity");
        response.votingRound = 1;

        IAddressValidity.Proof memory proof = IAddressValidity.Proof({
            merkleProof: new bytes32[](0),
            data: response
        });

        bytes32 merkleRoot = keccak256(abi.encode(response));
        // negative test - invalid merkle proof
        _mockMerkleRoots(1, bytes32(0));
        assertFalse(fdcVerification.verifyAddressValidity(proof));
        // positive test
        _mockMerkleRoots(1, merkleRoot);
        assertTrue(fdcVerification.verifyAddressValidity(proof));
        // negative test - invalid attestationType
        response.attestationType = bytes32("InvalidType");
        assertFalse(fdcVerification.verifyAddressValidity(proof));
    }

    function testVerifyBalanceDecreasingTransaction() public {
        IBalanceDecreasingTransaction.Response memory response;
        response.attestationType = bytes32("BalanceDecreasingTransaction");
        response.votingRound = 1;

        IBalanceDecreasingTransaction.Proof memory proof = IBalanceDecreasingTransaction.Proof({
            merkleProof: new bytes32[](0),
            data: response
        });

        bytes32 merkleRoot = keccak256(abi.encode(response));
        // negative test - invalid merkle proof
        _mockMerkleRoots(1, bytes32(0));
        assertFalse(fdcVerification.verifyBalanceDecreasingTransaction(proof));
        // positive test
        _mockMerkleRoots(1, merkleRoot);
        assertTrue(fdcVerification.verifyBalanceDecreasingTransaction(proof));
        // negative test - invalid attestationType
        response.attestationType = bytes32("InvalidType");
        assertFalse(fdcVerification.verifyBalanceDecreasingTransaction(proof));
    }

    function testVerifyConfirmedBlockHeightExists() public {
        IConfirmedBlockHeightExists.Response memory response;
        response.attestationType = bytes32("ConfirmedBlockHeightExists");
        response.votingRound = 1;

        IConfirmedBlockHeightExists.Proof memory proof = IConfirmedBlockHeightExists.Proof({
            merkleProof: new bytes32[](0),
            data: response
        });

        bytes32 merkleRoot = keccak256(abi.encode(response));
        // negative test - invalid merkle proof
        _mockMerkleRoots(1, bytes32(0));
        assertFalse(fdcVerification.verifyConfirmedBlockHeightExists(proof));
        // positive test
        _mockMerkleRoots(1, merkleRoot);
        assertTrue(fdcVerification.verifyConfirmedBlockHeightExists(proof));
        // negative test - invalid attestationType
        response.attestationType = bytes32("InvalidType");
        assertFalse(fdcVerification.verifyConfirmedBlockHeightExists(proof));
    }

    function testVerifyEVMTransaction() public {
        IEVMTransaction.Response memory response;
        response.attestationType = bytes32("EVMTransaction");
        response.votingRound = 1;

        IEVMTransaction.Proof memory proof = IEVMTransaction.Proof({
            merkleProof: new bytes32[](0),
            data: response
        });

        bytes32 merkleRoot = keccak256(abi.encode(response));
        // negative test - invalid merkle proof
        _mockMerkleRoots(1, bytes32(0));
        assertFalse(fdcVerification.verifyEVMTransaction(proof));
        // positive test
        _mockMerkleRoots(1, merkleRoot);
        assertTrue(fdcVerification.verifyEVMTransaction(proof));
        // negative test - invalid attestationType
        response.attestationType = bytes32("InvalidType");
        assertFalse(fdcVerification.verifyEVMTransaction(proof));
    }

    function testVerifyPayment() public {
        IPayment.Response memory response;
        response.attestationType = bytes32("Payment");
        response.votingRound = 1;

        IPayment.Proof memory proof = IPayment.Proof({
            merkleProof: new bytes32[](0),
            data: response
        });

        bytes32 merkleRoot = keccak256(abi.encode(response));
        // negative test - invalid merkle proof
        _mockMerkleRoots(1, bytes32(0));
        assertFalse(fdcVerification.verifyPayment(proof));
        // positive test
        _mockMerkleRoots(1, merkleRoot);
        assertTrue(fdcVerification.verifyPayment(proof));
        // negative test - invalid attestationType
        response.attestationType = bytes32("InvalidType");
        assertFalse(fdcVerification.verifyPayment(proof));
    }

    function testVerifyReferencedPaymentNonexistence() public {
        IReferencedPaymentNonexistence.Response memory response;
        response.attestationType = bytes32("ReferencedPaymentNonexistence");
        response.votingRound = 1;

        IReferencedPaymentNonexistence.Proof memory proof = IReferencedPaymentNonexistence.Proof({
            merkleProof: new bytes32[](0),
            data: response
        });

        bytes32 merkleRoot = keccak256(abi.encode(response));
        // negative test - invalid merkle proof
        _mockMerkleRoots(1, bytes32(0));
        assertFalse(fdcVerification.verifyReferencedPaymentNonexistence(proof));
        // positive test
        _mockMerkleRoots(1, merkleRoot);
        assertTrue(fdcVerification.verifyReferencedPaymentNonexistence(proof));
        // negative test - invalid attestationType
        response.attestationType = bytes32("InvalidType");
        assertFalse(fdcVerification.verifyReferencedPaymentNonexistence(proof));
    }

    function testVerifyWeb2Json() public {
        IWeb2Json.Response memory response;
        response.attestationType = bytes32("Web2Json");
        response.votingRound = 1;

        IWeb2Json.Proof memory proof = IWeb2Json.Proof({
            merkleProof: new bytes32[](0),
            data: response
        });

        bytes32 merkleRoot = keccak256(abi.encode(response));
        // negative test - invalid merkle proof
        _mockMerkleRoots(1, bytes32(0));
        assertFalse(fdcVerification.verifyWeb2Json(proof));
        // positive test
        _mockMerkleRoots(1, merkleRoot);
        assertTrue(fdcVerification.verifyWeb2Json(proof));
        // negative test - invalid attestationType
        response.attestationType = bytes32("InvalidType");
        assertFalse(fdcVerification.verifyWeb2Json(proof));
    }

    //// Proxy upgrade
    function testUpgradeProxy() public {
        assertEq(fdcVerification.implementation(), address(fdcVerificationImplementation));
        // upgrade
        FdcVerification newFdcVerificationImpl = new FdcVerification();
        vm.prank(governance);
        fdcVerification.upgradeToAndCall(address(newFdcVerificationImpl), bytes(""));
        // check
        assertEq(fdcVerification.implementation(), address(newFdcVerificationImpl));
        assertEq(fdcVerification.governance(), governance);
    }

    function testUpgradeProxyRevertOnlyGovernance() public {
        FdcVerification newFdcVerificationImpl = new FdcVerification();
        vm.expectRevert("only governance");
        fdcVerification.upgradeToAndCall(address(newFdcVerificationImpl), bytes(""));
    }

    // should revert if trying to initialize again
    // revert in GovernedBase.initialise
    function testUpgradeProxyAndInitializeRevert() public {
        FdcVerification newFdcVerificationImpl = new FdcVerification();
        vm.prank(governance);
        vm.expectRevert("initialised != false");
        fdcVerification.upgradeToAndCall(address(newFdcVerificationImpl), abi.encodeCall(
            FdcVerification.initialize, (
                IGovernanceSettings(makeAddr("governanceSettings")),
                governance,
                addressUpdater,
                FDC_PROTOCOL_ID
            )
        ));
    }

    function _mockMerkleRoots(uint256 _votingRoundId, bytes32 _merkleRoot) private {
        vm.mockCall(
            mockRelay,
            abi.encodeWithSelector(IRelay.merkleRoots.selector, FDC_PROTOCOL_ID, _votingRoundId),
            abi.encode(_merkleRoot)
        );
    }
}