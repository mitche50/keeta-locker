// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/LPLocker.sol";
import "../test/mocks/MockAerodromeLP.sol";
import "../test/mocks/MockERC20.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with the account:", deployer);
        console.log("Account balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // For Anvil/testing, we'll use a mock LP token address
        // In production, this would be the actual Aerodrome LP token address
        address mockLPToken;
        address feeReceiver = deployer; // Use deployer as fee receiver for testing
        
        // Check if we're on Anvil (chain ID 31337)
        if (block.chainid == 31337) {
            // Deploy mock tokens for the Aerodrome LP
            MockERC20 token0 = new MockERC20();
            MockERC20 token1 = new MockERC20();
            
            // Deploy a proper MockAerodromeLP for testing on Anvil
            MockAerodromeLP mockAeroLP = new MockAerodromeLP();
            mockAeroLP.setTokens(address(token0), address(token1));
            
            // Mint some LP tokens to the deployer
            mockAeroLP.mint(deployer, 1000000 * 10**18);
            
            mockLPToken = address(mockAeroLP);
            console.log("Mock Token 0 deployed to:", address(token0));
            console.log("Mock Token 1 deployed to:", address(token1));
            console.log("Mock Aerodrome LP Token deployed to:", mockLPToken);
        } else {
            // Use actual Aerodrome LP token address for other networks
            // This should be set via environment variable or hardcoded for specific networks
            mockLPToken = vm.envAddress("LP_TOKEN_ADDRESS");
        }

        // Deploy LPLocker
        LPLocker lpLocker = new LPLocker(mockLPToken, deployer, feeReceiver);
        
        console.log("LPLocker deployed to:", address(lpLocker));
        console.log("LP Token address:", mockLPToken);
        console.log("Fee receiver:", feeReceiver);

        vm.stopBroadcast();

        // Log deployment info (instead of writing to file)
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Chain ID:", block.chainid);
        console.log("LPLocker:", address(lpLocker));
        console.log("LP Token:", mockLPToken);
        console.log("Fee Receiver:", feeReceiver);
        console.log("=========================");
    }
} 