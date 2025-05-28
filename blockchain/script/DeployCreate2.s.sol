// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LPLocker.sol";
import "../src/Create2Factory.sol";

contract DeployCreate2Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address lpTokenAddress = vm.envAddress("LP_TOKEN_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        address deployer = vm.addr(deployerPrivateKey);
        
        // First, deploy the CREATE2 factory if needed
        Create2Factory factory = new Create2Factory();
        console.log("CREATE2 Factory deployed at:", address(factory));
        
        // Get the salt from environment variable (generated using cast create2)
        bytes32 salt = vm.envBytes32("CREATE2_SALT");
        
        // Prepare constructor arguments (LPLocker constructor takes tokenContract, owner, and feeReceiver)
        bytes memory constructorArgs = abi.encode(
            lpTokenAddress,  // tokenContract
            deployer,        // owner
            deployer         // feeReceiver
        );
        
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(LPLocker).creationCode,
            constructorArgs
        );
        
        // Deploy using CREATE2
        address lpLockerAddress = factory.deploy(salt, bytecode);
        
        console.log("LPLocker deployed at:", lpLockerAddress);
        console.log("Salt used:", vm.toString(salt));
        console.log("Owner (deployer):", deployer);
        console.log("Fee Receiver:", deployer);
        console.log("LP Token:", lpTokenAddress);
        
        vm.stopBroadcast();
    }
} 