// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LPLocker.sol";

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
            // Deploy a mock ERC20 token for testing on Anvil
            MockERC20 mockToken = new MockERC20("Mock LP Token", "MLP");
            mockLPToken = address(mockToken);
            console.log("Mock LP Token deployed to:", mockLPToken);
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

// Simple mock ERC20 for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        totalSupply = 1000000 * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
} 