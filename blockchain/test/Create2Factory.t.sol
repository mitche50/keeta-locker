// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Create2Factory.sol";
import "../src/LPLocker.sol";

contract Create2FactoryTest is Test {
    Create2Factory public factory;
    address public lpToken;
    address public owner;
    address public feeReceiver;

    function setUp() public {
        factory = new Create2Factory();
        lpToken = makeAddr("lpToken");
        owner = makeAddr("owner");
        feeReceiver = makeAddr("feeReceiver");
    }

    function testDeployContract() public {
        bytes32 salt = keccak256("test");
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(lpToken, owner, feeReceiver);
        
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(LPLocker).creationCode,
            constructorArgs
        );
        
        // Deploy using CREATE2
        vm.prank(owner);
        address deployedAddress = factory.deploy(salt, bytecode);
        
        // Verify deployment
        assertTrue(deployedAddress != address(0));
        assertTrue(deployedAddress.code.length > 0);
        
        // Verify it's a valid LPLocker contract
        LPLocker locker = LPLocker(deployedAddress);
        assertEq(locker.owner(), owner);
        assertEq(locker.feeReceiver(), feeReceiver);
        assertEq(locker.tokenContract(), lpToken);
    }

    function testComputeAddress() public {
        bytes32 salt = keccak256("test");
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(lpToken, owner, feeReceiver);
        
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(LPLocker).creationCode,
            constructorArgs
        );
        
        bytes32 bytecodeHash = keccak256(bytecode);
        
        // Compute address before deployment
        address computedAddress = factory.computeAddressFromFactory(salt, bytecodeHash);
        
        // Deploy and verify the address matches
        address deployedAddress = factory.deploy(salt, bytecode);
        
        assertEq(computedAddress, deployedAddress);
    }

    function testComputeAddressWithExternalDeployer() public {
        bytes32 salt = keccak256("test");
        bytes32 bytecodeHash = keccak256("test bytecode");
        address deployer = makeAddr("deployer");
        
        address computedAddress = factory.computeAddress(salt, bytecodeHash, deployer);
        
        // Manually compute the expected address
        address expectedAddress = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            bytecodeHash
        )))));
        
        assertEq(computedAddress, expectedAddress);
    }

    function testDeploymentEvent() public {
        bytes32 salt = keccak256("test");
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(lpToken, owner, feeReceiver);
        
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(LPLocker).creationCode,
            constructorArgs
        );
        
        // Compute the expected deployed address
        bytes32 bytecodeHash = keccak256(bytecode);
        address expectedAddress = factory.computeAddressFromFactory(salt, bytecodeHash);
        
        // Expect the event to be emitted with correct parameters
        vm.expectEmit(true, true, true, true);
        emit Create2Factory.ContractDeployed(expectedAddress, salt, address(this));
        
        address deployedAddress = factory.deploy(salt, bytecode);
        
        assertEq(deployedAddress, expectedAddress);
    }

    function testCannotDeployTwiceWithSameSalt() public {
        bytes32 salt = keccak256("test");
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(lpToken, owner, feeReceiver);
        
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(LPLocker).creationCode,
            constructorArgs
        );
        
        // First deployment should succeed
        factory.deploy(salt, bytecode);
        
        // Second deployment with same salt should fail
        vm.expectRevert("Create2Factory: deployment failed");
        factory.deploy(salt, bytecode);
    }

    function testDifferentSaltsProduceDifferentAddresses() public {
        bytes32 salt1 = keccak256("test1");
        bytes32 salt2 = keccak256("test2");
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(lpToken, owner, feeReceiver);
        
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(LPLocker).creationCode,
            constructorArgs
        );
        
        address address1 = factory.deploy(salt1, bytecode);
        address address2 = factory.deploy(salt2, bytecode);
        
        assertTrue(address1 != address2);
    }

    function testFuzzDeployment(bytes32 salt) public {
        // Skip zero salt to avoid potential issues
        vm.assume(salt != bytes32(0));
        
        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(lpToken, owner, feeReceiver);
        
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(LPLocker).creationCode,
            constructorArgs
        );
        
        bytes32 bytecodeHash = keccak256(bytecode);
        
        // Compute address before deployment
        address computedAddress = factory.computeAddressFromFactory(salt, bytecodeHash);
        
        // Deploy and verify the address matches
        address deployedAddress = factory.deploy(salt, bytecode);
        
        assertEq(computedAddress, deployedAddress);
        assertTrue(deployedAddress != address(0));
        assertTrue(deployedAddress.code.length > 0);
    }
} 