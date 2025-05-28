// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Create2Factory
 * @dev Factory contract for deploying contracts using CREATE2 with vanity addresses
 */
contract Create2Factory {
    event ContractDeployed(address indexed deployedAddress, bytes32 indexed salt, address indexed deployer);

    /**
     * @dev Deploys a contract using CREATE2
     * @param salt The salt to use for CREATE2
     * @param bytecode The bytecode of the contract to deploy
     * @return deployedAddress The address of the deployed contract
     */
    function deploy(bytes32 salt, bytes memory bytecode) external returns (address deployedAddress) {
        assembly {
            deployedAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        
        require(deployedAddress != address(0), "Create2Factory: deployment failed");
        
        emit ContractDeployed(deployedAddress, salt, msg.sender);
    }

    /**
     * @dev Computes the address of a contract deployed using CREATE2
     * @param salt The salt to use for CREATE2
     * @param bytecodeHash The keccak256 hash of the bytecode
     * @param deployer The address of the deployer (this factory)
     * @return The computed address
     */
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) external pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            bytecodeHash
        )))));
    }

    /**
     * @dev Computes the address using this factory as the deployer
     * @param salt The salt to use for CREATE2
     * @param bytecodeHash The keccak256 hash of the bytecode
     * @return The computed address
     */
    function computeAddressFromFactory(bytes32 salt, bytes32 bytecodeHash) external view returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            bytecodeHash
        )))));
    }
} 