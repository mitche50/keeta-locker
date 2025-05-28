#!/bin/bash

# Vanity Address Generator for LPLocker
# This script helps generate vanity addresses using Foundry's cast create2

set -e

echo "🎯 LPLocker Vanity Address Generator"
echo "=================================="

# Check if required tools are installed
if ! command -v cast &> /dev/null; then
    echo "❌ Error: 'cast' command not found. Please install Foundry."
    exit 1
fi

if ! command -v forge &> /dev/null; then
    echo "❌ Error: 'forge' command not found. Please install Foundry."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found. Please create one with PRIVATE_KEY and LP_TOKEN_ADDRESS."
    exit 1
fi

# Source environment variables
source .env

if [ -z "$PRIVATE_KEY" ] || [ -z "$LP_TOKEN_ADDRESS" ]; then
    echo "❌ Error: PRIVATE_KEY and LP_TOKEN_ADDRESS must be set in .env file."
    exit 1
fi

# Get deployer address
DEPLOYER=$(cast wallet address $PRIVATE_KEY)
echo "📍 Deployer address: $DEPLOYER"

# Build contracts to get bytecode
echo "🔨 Building contracts..."
forge build --silent

# Get the init code hash
echo "🧮 Computing init code hash..."

# First, we need to get the bytecode with constructor args
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,address,address)" $LP_TOKEN_ADDRESS $DEPLOYER $DEPLOYER)
CREATION_CODE=$(forge inspect LPLocker bytecode)
INIT_CODE="${CREATION_CODE}${CONSTRUCTOR_ARGS:2}"  # Remove 0x prefix from constructor args
INIT_CODE_HASH=$(cast keccak $INIT_CODE)

echo "📋 Init code hash: $INIT_CODE_HASH"

# Function to generate vanity address
generate_vanity() {
    local pattern=$1
    local description=$2
    
    echo ""
    echo "🔍 Searching for address $description..."
    echo "   Pattern: $pattern"
    echo "   This may take a while..."
    
    # Use cast create2 to find vanity address
    RESULT=$(cast create2 --starts-with $pattern --deployer $DEPLOYER --init-code-hash $INIT_CODE_HASH)
    
    if [ $? -eq 0 ]; then
        echo "✅ Found vanity address!"
        echo "$RESULT"
        
        # Extract salt from result
        SALT=$(echo "$RESULT" | grep "Salt:" | awk '{print $2}')
        ADDRESS=$(echo "$RESULT" | grep "Address:" | awk '{print $2}')
        
        echo ""
        echo "🎉 Success! Your vanity address is: $ADDRESS"
        echo "🧂 Salt to use: $SALT"
        echo ""
        
        # Remove existing CREATE2_SALT if it exists
        if grep -q "CREATE2_SALT=" .env; then
            sed -i.bak '/CREATE2_SALT=/d' .env
        fi
        
        echo "CREATE2_SALT=$SALT" >> .env
        echo "✅ Salt added to .env file!"
        echo ""
        echo "To deploy with this vanity address, run:"
        echo "   make deploy-create2-anvil    # For testing"
        echo "   make deploy-create2-base     # For production"
        
        return 0
    else
        echo "❌ Failed to generate vanity address"
        return 1
    fi
}

# Menu for vanity address options
echo ""
echo "Choose a vanity address pattern:"
echo "1) 5AF3 (SAFE) - Perfect for locker contracts"
echo "2) Custom pattern - Enter your own hex pattern"
echo "3) Random address - Deploy with any address"

read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        generate_vanity "5AF3" "starting with '5AF3' (SAFE)"
        ;;
    2)
        echo ""
        echo "💡 Tips for custom patterns:"
        echo "   - Only use hex characters: 0-9, A-F"
        echo "   - Longer patterns take exponentially longer"
        echo "   - 3-4 characters are recommended"
        echo "   - Examples: CAFE, FEED, DEAD, BEEF"
        echo ""
        read -p "Enter your custom pattern (hex, no 0x prefix): " custom_pattern
        
        # Validate hex pattern
        if [[ ! "$custom_pattern" =~ ^[0-9A-Fa-f]+$ ]]; then
            echo "❌ Error: Pattern must only contain hex characters (0-9, A-F)"
            exit 1
        fi
        
        # Convert to uppercase
        custom_pattern=$(echo "$custom_pattern" | tr '[:lower:]' '[:upper:]')
        
        generate_vanity "$custom_pattern" "starting with '$custom_pattern'"
        ;;
    3)
        echo "🚀 Generating random address..."
        # Generate a random salt
        RANDOM_SALT=$(cast keccak "$(date +%s)$(shuf -i 1000-9999 -n 1)")
        
        # Remove existing CREATE2_SALT if it exists
        if grep -q "CREATE2_SALT=" .env; then
            sed -i.bak '/CREATE2_SALT=/d' .env
        fi
        
        echo "CREATE2_SALT=$RANDOM_SALT" >> .env
        echo "✅ Random salt added to .env: $RANDOM_SALT"
        echo ""
        echo "To deploy with this salt, run:"
        echo "   make deploy-create2-anvil    # For testing"
        echo "   make deploy-create2-base     # For production"
        ;;
    *)
        echo "❌ Invalid choice. Please select 1, 2, or 3."
        exit 1
        ;;
esac 