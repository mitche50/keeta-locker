#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Clef configuration
CLEF_KEYSTORE_DIR="$HOME/.clef"
CLEF_CONFIG_DIR="$HOME/.clef"
CLEF_SOCKET="$CLEF_CONFIG_DIR/clef.ipc"
CLEF_PID_FILE="$CLEF_CONFIG_DIR/clef.pid"

print_header() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}     LP Locker - Geth + Clef Interface     ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

check_dependencies() {
    local missing_deps=""
    
    if ! command -v jq &> /dev/null; then
        missing_deps="$missing_deps jq"
    fi
    
    if ! command -v bc &> /dev/null; then
        missing_deps="$missing_deps bc"
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps="$missing_deps curl"
    fi
    
    if [ -n "$missing_deps" ]; then
        echo -e "${RED}❌ Error: Missing required dependencies:$missing_deps${NC}"
        echo -e "${YELLOW}Please install the missing tools:${NC}"
        echo ""
        echo "macOS:"
        echo "  brew install jq bc curl"
        echo ""
        echo "Linux (Ubuntu/Debian):"
        echo "  sudo apt-get install jq bc curl"
        echo ""
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies are installed${NC}"
}

check_env() {
    if [ ! -f .env ]; then
        echo -e "${RED}❌ Error: .env file not found${NC}"
        echo -e "${YELLOW}Please copy env.example to .env and configure it${NC}"
        exit 1
    fi
    
    source .env
    
    if [ -z "$LP_LOCKER_ADDRESS" ]; then
        echo -e "${RED}❌ Error: LP_LOCKER_ADDRESS not set in .env${NC}"
        exit 1
    fi
    
    if [ -z "$LP_TOKEN_ADDRESS" ]; then
        echo -e "${RED}❌ Error: LP_TOKEN_ADDRESS not set in .env${NC}"
        exit 1
    fi
}

check_clef_installed() {
    if ! command -v clef &> /dev/null; then
        echo -e "${RED}❌ Error: Clef is not installed${NC}"
        echo -e "${YELLOW}Clef is part of the Geth package. Please install Geth:${NC}"
        echo ""
        echo "macOS:"
        echo "  brew install ethereum"
        echo ""
        echo "Linux (Ubuntu/Debian):"
        echo "  sudo apt-get install ethereum"
        echo ""
        echo "Other platforms:"
        echo "  Download from: https://geth.ethereum.org/downloads/"
        echo ""
        echo -e "${CYAN}💡 Alternative: Use the Foundry-based approach instead:${NC}"
        echo "  make ledger-interact"
        exit 1
    fi
    
    if ! command -v geth &> /dev/null; then
        echo -e "${RED}❌ Error: Geth is not installed${NC}"
        echo -e "${YELLOW}Please install Geth:${NC}"
        echo ""
        echo "macOS:"
        echo "  brew install ethereum"
        echo ""
        echo "Linux (Ubuntu/Debian):"
        echo "  sudo apt-get install ethereum"
        echo ""
        echo "Other platforms:"
        echo "  Download from: https://geth.ethereum.org/downloads/"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Geth and Clef are installed${NC}"
}

setup_clef() {
    echo -e "${YELLOW}Setting up Clef for Ledger...${NC}"
    
    # Create clef directories
    mkdir -p "$CLEF_CONFIG_DIR"
    
    # Create clef rules file for auto-approval of certain operations
    cat > "$CLEF_CONFIG_DIR/rules.js" << 'EOF'
function ApproveListing() {
    return "Approve"
}

function ApproveSignData(req) {
    console.log("SignData request:")
    console.log(JSON.stringify(req, null, 2))
    return "Approve"
}

function ApproveTransaction(req) {
    console.log("Transaction request:")
    console.log("To:", req.transaction.to)
    console.log("Value:", req.transaction.value)
    console.log("Data:", req.transaction.data)
    console.log("Gas:", req.transaction.gas)
    
    // Auto-approve transactions to our LP Locker contract
    if (req.transaction.to && req.transaction.to.toLowerCase() === process.env.LP_LOCKER_ADDRESS.toLowerCase()) {
        console.log("Auto-approving transaction to LP Locker contract")
        return "Approve"
    }
    
    return "Approve" // For demo purposes, you might want to make this more restrictive
}
EOF

    echo -e "${GREEN}✅ Clef configuration created${NC}"
}

start_clef() {
    # Check if clef is already running
    if [ -f "$CLEF_PID_FILE" ] && kill -0 "$(cat "$CLEF_PID_FILE")" 2>/dev/null; then
        echo -e "${GREEN}✅ Clef is already running${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Starting Clef in basic mode (no hardware wallet auto-discovery)...${NC}"
    
    # Check Clef version and capabilities
    CLEF_VERSION=$(clef --version 2>/dev/null | grep -o "1\.[0-9]*\.[0-9]*" | head -1)
    echo -e "${BLUE}Detected Clef version: $CLEF_VERSION${NC}"
    
    # Kill any existing clef processes to avoid conflicts
    pkill -f "clef.*--http.*--http.port.*8550" 2>/dev/null || true
    sleep 1
    
    echo -e "${CYAN}Starting Clef without automatic hardware wallet discovery${NC}"
    echo -e "${YELLOW}Hardware wallet access will be available when needed for transactions${NC}"
    echo ""
    
    # Create a temporary empty keystore to avoid hardware wallet auto-discovery
    TEMP_KEYSTORE="$CLEF_CONFIG_DIR/temp_keystore"
    mkdir -p "$TEMP_KEYSTORE"
    
    # Create a simple rules file for manual approval
    cat > "$CLEF_CONFIG_DIR/basic_rules.js" << 'EOF'
function ApproveListing() {
    console.log("Account listing requested - manual approval required")
    return "Approve"
}

function ApproveSignData(req) {
    console.log("SignData request:", JSON.stringify(req, null, 2))
    return "Approve"
}

function ApproveTransaction(req) {
    console.log("Transaction request:")
    console.log("To:", req.transaction.to)
    console.log("Value:", req.transaction.value)
    console.log("Data:", req.transaction.data)
    console.log("Gas:", req.transaction.gas)
    return "Approve"
}
EOF
    
    # Start clef with empty keystore to prevent auto-discovery
    LP_LOCKER_ADDRESS="$LP_LOCKER_ADDRESS" clef \
        --keystore "$TEMP_KEYSTORE" \
        --configdir "$CLEF_CONFIG_DIR" \
        --rules "$CLEF_CONFIG_DIR/basic_rules.js" \
        --suppress-bootwarn \
        --http \
        --http.addr "127.0.0.1" \
        --http.port "8550" \
        --chainid "$CHAIN_ID" \
        > "$CLEF_CONFIG_DIR/clef.log" 2>&1 &
    
    CLEF_PID=$!
    echo $CLEF_PID > "$CLEF_PID_FILE"
    
    # Wait for clef HTTP server to start
    echo -e "${BLUE}⏳ Waiting for Clef HTTP server to start...${NC}"
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -m 2 -w "%{http_code}" -o /dev/null http://127.0.0.1:8550/ 2>/dev/null | grep -q "405\|200"; then
            echo -e "${GREEN}✅ Clef HTTP server is responding${NC}"
            break
        fi
        
        sleep 1
        attempt=$((attempt + 1))
        echo -e "${BLUE}   Attempt $attempt/$max_attempts...${NC}"
        
        # Check if process is still running
        if ! kill -0 "$CLEF_PID" 2>/dev/null; then
            echo -e "${RED}❌ Clef process died during startup${NC}"
            echo -e "${YELLOW}Last few log lines:${NC}"
            tail -5 "$CLEF_CONFIG_DIR/clef.log" 2>/dev/null || echo "No logs found"
            return 1
        fi
    done
    
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${RED}❌ Clef HTTP server failed to start after $max_attempts attempts${NC}"
        echo -e "${YELLOW}Clef logs:${NC}"
        tail -10 "$CLEF_CONFIG_DIR/clef.log" 2>/dev/null || echo "No logs found"
        return 1
    fi
    
    echo -e "${GREEN}✅ Clef started successfully (PID: $CLEF_PID)${NC}"
    echo -e "${CYAN}💡 Clef is running in basic mode without hardware wallet auto-discovery${NC}"
    echo -e "${YELLOW}Connect your Ledger when ready to make transactions${NC}"
    
    return 0
}

stop_clef() {
    if [ -f "$CLEF_PID_FILE" ]; then
        PID=$(cat "$CLEF_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "${YELLOW}Stopping Clef...${NC}"
            kill "$PID"
            sleep 2
            # Force kill if still running
            if kill -0 "$PID" 2>/dev/null; then
                kill -9 "$PID" 2>/dev/null
            fi
            rm -f "$CLEF_PID_FILE"
            echo -e "${GREEN}✅ Clef stopped${NC}"
        else
            echo -e "${YELLOW}Clef was not running${NC}"
            rm -f "$CLEF_PID_FILE"
        fi
    else
        echo -e "${YELLOW}Clef PID file not found${NC}"
    fi
    
    # Clean up temporary keystore
    TEMP_KEYSTORE="$CLEF_CONFIG_DIR/temp_keystore"
    if [ -d "$TEMP_KEYSTORE" ]; then
        rm -rf "$TEMP_KEYSTORE"
    fi
    
    # Kill any remaining clef processes on port 8550
    pkill -f "clef.*--http.*--http.port.*8550" 2>/dev/null || true
}

get_ledger_accounts() {
    echo -e "${BLUE}🔍 Auto-detecting Ledger addresses...${NC}"
    
    # Skip automatic Clef account discovery to avoid triggering approval prompts
    # We'll try to access Ledger accounts only when needed for transactions
    echo -e "${YELLOW}Skipping automatic Ledger discovery to avoid Clef crashes...${NC}"
    echo -e "${CYAN}Ledger accounts will be accessed when needed for transactions${NC}"
    echo ""
    
    local detected_addresses=()
    
    # Method 1: If we're on Anvil (local), check the well-known test accounts
    if [ "$RPC_URL" = "http://127.0.0.1:8545" ]; then
        echo -e "${YELLOW}Checking for funded Anvil test accounts...${NC}"
        echo -e "${CYAN}   Detected Anvil local network${NC}"
        # Check well-known Anvil accounts that might be imported to Ledger for testing
        local test_accounts=(
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"  # Anvil account 0
            "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"  # Anvil account 1
            "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"  # Anvil account 2
        )
        
        for addr in "${test_accounts[@]}"; do
            local balance=$(get_balance_wei "$addr")
            if [ "$balance" != "0" ] && [ -n "$balance" ]; then
                local balance_eth=$(wei_to_ether "$balance")
                echo -e "${GREEN}   Found funded account: $addr (${balance_eth} ETH)${NC}"
                detected_addresses+=("$addr")
            fi
        done
        echo ""
    fi
    
    # Method 2: Check if user has a preferred address from previous runs
    if [ -f "$CLEF_CONFIG_DIR/preferred_address" ]; then
        local preferred_addr=$(cat "$CLEF_CONFIG_DIR/preferred_address" 2>/dev/null)
        if [[ "$preferred_addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            echo -e "${CYAN}Found previously used address: $preferred_addr${NC}"
            detected_addresses+=("$preferred_addr")
        fi
    fi
    
    # Present options to user
    if [ ${#detected_addresses[@]} -gt 0 ]; then
        echo -e "${GREEN}🎯 Available addresses:${NC}"
        echo ""
        
        # Remove duplicates and sort
        local unique_addresses=($(printf "%s\n" "${detected_addresses[@]}" | sort -u))
        
        for i in "${!unique_addresses[@]}"; do
            local addr="${unique_addresses[$i]}"
            local balance=$(get_balance_wei "$addr")
            local balance_eth=$(wei_to_ether "$balance")
            echo -e "$((i+1))) $addr (${balance_eth} ETH)"
        done
        echo "$((${#unique_addresses[@]}+1))) Enter address manually"
        echo "$((${#unique_addresses[@]}+2))) Try Ledger discovery (may cause Clef to ask for approval)"
        echo ""
        
        read -p "Select address (1-$((${#unique_addresses[@]}+2))): " addr_choice
        
        if [[ "$addr_choice" =~ ^[0-9]+$ ]] && [ "$addr_choice" -ge 1 ] && [ "$addr_choice" -le ${#unique_addresses[@]} ]; then
            LEDGER_ADDRESS="${unique_addresses[$((addr_choice-1))]}"
            echo -e "${GREEN}✅ Selected: $LEDGER_ADDRESS${NC}"
            # Save as preferred address
            echo "$LEDGER_ADDRESS" > "$CLEF_CONFIG_DIR/preferred_address"
        elif [ "$addr_choice" = "$((${#unique_addresses[@]}+1))" ]; then
            manual_address_entry
        elif [ "$addr_choice" = "$((${#unique_addresses[@]}+2))" ]; then
            try_ledger_discovery
        else
            echo -e "${YELLOW}Invalid selection, using manual entry${NC}"
            manual_address_entry
        fi
    else
        echo -e "${YELLOW}⚠️  No addresses auto-detected${NC}"
        echo -e "${GREEN}Options:${NC}"
        echo "1) Enter address manually"
        echo "2) Try Ledger discovery (may cause Clef to ask for approval)"
        echo ""
        read -p "Select option (1-2): " choice
        
        if [ "$choice" = "1" ]; then
            manual_address_entry
        else
            try_ledger_discovery
        fi
    fi
    
    echo ""
}

# New function to try Ledger discovery when user explicitly requests it
try_ledger_discovery() {
    echo -e "${YELLOW}🔍 Attempting Ledger account discovery...${NC}"
    echo -e "${RED}⚠️  This may cause Clef to ask for approval and potentially crash${NC}"
    echo -e "${CYAN}Make sure your Ledger is connected, unlocked, and Ethereum app is open${NC}"
    echo ""
    
    read -p "Continue with Ledger discovery? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipping Ledger discovery${NC}"
        manual_address_entry
        return
    fi
    
    echo -e "${BLUE}Querying Clef for Ledger accounts...${NC}"
    ACCOUNTS=$(curl -s -m 15 -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"account_list","params":[],"id":1}' \
        http://127.0.0.1:8550 | jq -r '.result[]?' 2>/dev/null)
    
    if [ -n "$ACCOUNTS" ]; then
        echo -e "${GREEN}✅ Found Ledger accounts:${NC}"
        local ledger_addresses=()
        while IFS= read -r account; do
            if [ -n "$account" ] && [[ "$account" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
                local balance=$(get_balance_wei "$account")
                local balance_eth=$(wei_to_ether "$balance")
                echo -e "${GREEN}   $account (${balance_eth} ETH)${NC}"
                ledger_addresses+=("$account")
            fi
        done <<< "$ACCOUNTS"
        
        if [ ${#ledger_addresses[@]} -gt 0 ]; then
            echo ""
            echo "Select Ledger address:"
            for i in "${!ledger_addresses[@]}"; do
                echo "$((i+1))) ${ledger_addresses[$i]}"
            done
            echo "$((${#ledger_addresses[@]}+1))) Enter different address"
            
            read -p "Select (1-$((${#ledger_addresses[@]}+1))): " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#ledger_addresses[@]} ]; then
                LEDGER_ADDRESS="${ledger_addresses[$((choice-1))]}"
                echo -e "${GREEN}✅ Selected: $LEDGER_ADDRESS${NC}"
                echo "$LEDGER_ADDRESS" > "$CLEF_CONFIG_DIR/preferred_address"
                return
            fi
        fi
    fi
    
    echo -e "${YELLOW}Ledger discovery failed or no accounts found${NC}"
    manual_address_entry
}

# Helper function to get balance in wei
get_balance_wei() {
    local address=$1
    
    local balance_json="{
        \"jsonrpc\": \"2.0\",
        \"method\": \"eth_getBalance\",
        \"params\": [\"$address\", \"latest\"],
        \"id\": 1
    }"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$balance_json" \
        "$RPC_URL")
    
    local balance_hex=$(echo "$response" | jq -r '.result' 2>/dev/null)
    if [ "$balance_hex" = "null" ] || [ -z "$balance_hex" ]; then
        echo "0"
    else
        decode_uint256 "$balance_hex"
    fi
}

# Helper function for manual address entry
manual_address_entry() {
    echo -e "${YELLOW}Please enter your Ledger Ethereum address manually:${NC}"
    echo -e "${BLUE}💡 You can find this by:${NC}"
    echo -e "   • Connecting Ledger to MetaMask and copying the address"
    echo -e "   • Using: cast wallet address --ledger (if you have Foundry)"
    echo -e "   • Opening Ethereum app on Ledger and checking the address"
    echo ""
    
    while true; do
        read -p "Enter your Ledger Ethereum address (0x...): " LEDGER_ADDRESS
        
        if [ -z "$LEDGER_ADDRESS" ]; then
            echo -e "${RED}❌ Address cannot be empty${NC}"
            continue
        fi
        
        if [[ ! "$LEDGER_ADDRESS" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
            echo -e "${RED}❌ Invalid Ethereum address format${NC}"
            echo -e "${YELLOW}Address should be 42 characters starting with 0x${NC}"
            continue
        fi
        
        # Check if address has any activity
        local balance=$(get_balance_wei "$LEDGER_ADDRESS")
        local balance_eth=$(wei_to_ether "$balance")
        echo -e "${GREEN}✅ Valid address: $LEDGER_ADDRESS${NC}"
        echo -e "${CYAN}   Balance: ${balance_eth} ETH${NC}"
        
        # Save as preferred address
        echo "$LEDGER_ADDRESS" > "$CLEF_CONFIG_DIR/preferred_address"
        break
    done
}

# Helper function to scan for more addresses
scan_for_addresses() {
    echo -e "${YELLOW}🔍 Scanning additional derivation paths...${NC}"
    echo -e "${BLUE}This requires your Ledger to be connected and unlocked${NC}"
    echo ""
    
    # We can't actually derive addresses without the hardware wallet interaction
    # But we can check if the user knows other addresses they use
    echo -e "${CYAN}Common scenarios:${NC}"
    echo -e "   • If you've used multiple accounts on your Ledger"
    echo -e "   • If you've used different derivation paths"
    echo -e "   • If you've imported Ledger into different wallets"
    echo ""
    
    read -p "Do you have another Ledger address to try? (y/N): " try_another
    if [[ $try_another =~ ^[Yy]$ ]]; then
        manual_address_entry
    else
        echo -e "${YELLOW}Using manual entry...${NC}"
        manual_address_entry
    fi
}

select_network() {
    echo -e "${YELLOW}Select Network:${NC}"
    echo "1) Anvil Local (Development)"
    echo "2) Base Mainnet (Production)"
    echo ""
    read -p "Enter choice (1-2): " network_choice
    
    case $network_choice in
        1)
            NETWORK_NAME="Anvil Local"
            RPC_URL="http://127.0.0.1:8545"
            CHAIN_ID="31337"
            ;;
        2)
            NETWORK_NAME="Base Mainnet"
            RPC_URL="https://mainnet.base.org"
            CHAIN_ID="8453"
            ;;
        *)
            echo -e "${RED}Invalid choice, using Anvil Local${NC}"
            NETWORK_NAME="Anvil Local"
            RPC_URL="http://127.0.0.1:8545"
            CHAIN_ID="31337"
            ;;
    esac
    
    echo -e "${GREEN}Selected: $NETWORK_NAME${NC}"
    echo ""
}

enable_ledger_mode() {
    echo -e "${YELLOW}🔄 Switching Clef to Ledger mode for transaction signing...${NC}"
    
    # Stop current Clef instance
    if [ -f "$CLEF_PID_FILE" ]; then
        local current_pid=$(cat "$CLEF_PID_FILE")
        if kill -0 "$current_pid" 2>/dev/null; then
            echo -e "${BLUE}Stopping basic mode Clef...${NC}"
            kill "$current_pid"
            sleep 2
            if kill -0 "$current_pid" 2>/dev/null; then
                kill -9 "$current_pid" 2>/dev/null
            fi
        fi
        rm -f "$CLEF_PID_FILE"
    fi
    
    # Clean up temp keystore
    TEMP_KEYSTORE="$CLEF_CONFIG_DIR/temp_keystore"
    if [ -d "$TEMP_KEYSTORE" ]; then
        rm -rf "$TEMP_KEYSTORE"
    fi
    
    echo -e "${YELLOW}Please ensure your Ledger is connected, unlocked, and Ethereum app is open${NC}"
    echo -e "${CYAN}Make sure 'Contract data' is enabled in Ethereum app settings${NC}"
    read -p "Press Enter when your Ledger is ready for transaction signing..."
    echo ""
    
    # Start Clef with hardware wallet support but no auto-enumeration
    echo -e "${BLUE}Starting Clef with Ledger support...${NC}"
    
    LP_LOCKER_ADDRESS="$LP_LOCKER_ADDRESS" clef \
        --keystore "$CLEF_KEYSTORE_DIR" \
        --configdir "$CLEF_CONFIG_DIR" \
        --rules "$CLEF_CONFIG_DIR/basic_rules.js" \
        --suppress-bootwarn \
        --http \
        --http.addr "127.0.0.1" \
        --http.port "8550" \
        --chainid "$CHAIN_ID" \
        > "$CLEF_CONFIG_DIR/clef_ledger.log" 2>&1 &
    
    CLEF_PID=$!
    echo $CLEF_PID > "$CLEF_PID_FILE"
    
    # Wait for HTTP server
    echo -e "${BLUE}⏳ Waiting for Ledger-enabled Clef to start...${NC}"
    local max_attempts=15
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -m 2 -w "%{http_code}" -o /dev/null http://127.0.0.1:8550/ 2>/dev/null | grep -q "405\|200"; then
            echo -e "${GREEN}✅ Ledger-enabled Clef is responding${NC}"
            break
        fi
        
        sleep 1
        attempt=$((attempt + 1))
        echo -e "${BLUE}   Attempt $attempt/$max_attempts...${NC}"
        
        if ! kill -0 "$CLEF_PID" 2>/dev/null; then
            echo -e "${RED}❌ Ledger-enabled Clef crashed${NC}"
            echo -e "${YELLOW}Check logs: tail ~/.clef/clef_ledger.log${NC}"
            return 1
        fi
    done
    
    if [ $attempt -ge $max_attempts ]; then
        echo -e "${RED}❌ Ledger-enabled Clef failed to start${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Clef is now running in Ledger mode${NC}"
    return 0
}

execute_transaction_with_clef() {
    local to_address=$1
    local function_sig=$2
    local params=$3
    local value=${4:-"0"}
    
    echo -e "${YELLOW}Preparing transaction...${NC}"
    echo -e "To: ${CYAN}$to_address${NC}"
    echo -e "Function: ${CYAN}$function_sig${NC}"
    echo -e "Parameters: ${CYAN}$params${NC}"
    echo -e "Value: ${CYAN}$value ETH${NC}"
    echo -e "Network: ${CYAN}$NETWORK_NAME ($RPC_URL)${NC}"
    echo ""
    
    # Switch to Ledger mode if we're using a Ledger address
    if [[ "$LEDGER_ADDRESS" == 0x* ]] && [ ${#LEDGER_ADDRESS} -eq 42 ]; then
        echo -e "${BLUE}🔍 Checking if Ledger mode is needed...${NC}"
        
        # Check if this looks like a Ledger address (not one of the test accounts)
        if [[ "$LEDGER_ADDRESS" != "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" ]] && \
           [[ "$LEDGER_ADDRESS" != "0x70997970C51812dc3A010C7d01b50e0d17dc79C8" ]] && \
           [[ "$LEDGER_ADDRESS" != "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC" ]]; then
            
            echo -e "${YELLOW}📱 Transaction requires Ledger hardware wallet${NC}"
            if ! enable_ledger_mode; then
                echo -e "${RED}❌ Failed to enable Ledger mode${NC}"
                return 1
            fi
        fi
    fi
    
    # Encode function call using RPC call to encode the data
    if [ -n "$params" ]; then
        # For functions with parameters, we need to manually encode
        # This is a simplified approach - in production you might want more sophisticated encoding
        case "$function_sig" in
            "approve(address,uint256)")
                # Extract spender and amount from params
                SPENDER=$(echo $params | cut -d' ' -f1)
                AMOUNT=$(echo $params | cut -d' ' -f2)
                # Function selector for approve(address,uint256) is 0x095ea7b3
                CALL_DATA="0x095ea7b3$(printf "%064s" ${SPENDER#0x} | tr ' ' '0')$(printf "%064x" $AMOUNT)"
                ;;
            "lockLiquidity(uint256)")
                AMOUNT=$(echo $params)
                # Function selector for lockLiquidity(uint256) would need to be calculated
                CALL_DATA="0x$(get_function_selector "$function_sig")$(printf "%064x" $AMOUNT)"
                ;;
            "triggerWithdrawal(bytes32)")
                LOCK_ID=$(echo $params)
                CALL_DATA="0x$(get_function_selector "$function_sig")${LOCK_ID#0x}"
                ;;
            "claimLPFees(bytes32)")
                LOCK_ID=$(echo $params)
                CALL_DATA="0x$(get_function_selector "$function_sig")${LOCK_ID#0x}"
                ;;
            "updateClaimableFees(bytes32)")
                LOCK_ID=$(echo $params)
                CALL_DATA="0x$(get_function_selector "$function_sig")${LOCK_ID#0x}"
                ;;
            *)
                echo -e "${RED}❌ Unsupported function signature: $function_sig${NC}"
                return 1
                ;;
        esac
    else
        CALL_DATA="0x$(get_function_selector "$function_sig")"
    fi
    
    echo -e "${BLUE}📝 Encoded call data: ${CALL_DATA}${NC}"
    echo ""
    
    # Get gas estimate using RPC
    GAS_ESTIMATE=$(get_gas_estimate "$to_address" "$CALL_DATA" "$LEDGER_ADDRESS")
    GAS_LIMIT=$((GAS_ESTIMATE * 120 / 100))  # Add 20% buffer
    
    echo -e "${BLUE}⛽ Estimated gas: $GAS_ESTIMATE (using limit: $GAS_LIMIT)${NC}"
    
    # Get gas price using RPC
    GAS_PRICE=$(get_gas_price)
    
    echo -e "${BLUE}💰 Gas price: $GAS_PRICE wei${NC}"
    echo ""
    
    read -p "Confirm transaction? y/N: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Transaction cancelled${NC}"
        return
    fi
    
    echo -e "${YELLOW}🔄 Sending transaction to Clef for signing...${NC}"
    echo -e "${YELLOW}Please review and approve the transaction on your Ledger device${NC}"
    echo ""
    
    # Use only Clef for signing and sending
    sign_and_send_with_clef "$to_address" "$CALL_DATA" "$value" "$GAS_LIMIT" "$GAS_PRICE"
    
    echo ""
}

# Helper function to calculate function selectors
get_function_selector() {
    local function_sig=$1
    case "$function_sig" in
        "approve(address,uint256)")
            echo "095ea7b3"
            ;;
        "lockLiquidity(uint256)")
            echo "2bfbd9cf"
            ;;
        "triggerWithdrawal(bytes32)")
            echo "9cb15243"
            ;;
        "claimLPFees(bytes32)")
            echo "202c28b0"
            ;;
        "updateClaimableFees(bytes32)")
            echo "d5060551"
            ;;
        *)
            echo "00000000"  # Invalid
            ;;
    esac
}

# Helper function to get gas estimate via RPC
get_gas_estimate() {
    local to_address=$1
    local call_data=$2
    local from_address=$3
    
    local estimate_json="{
        \"jsonrpc\": \"2.0\",
        \"method\": \"eth_estimateGas\",
        \"params\": [{
            \"from\": \"$from_address\",
            \"to\": \"$to_address\",
            \"data\": \"$call_data\"
        }],
        \"id\": 1
    }"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$estimate_json" \
        "$RPC_URL")
    
    local gas_hex=$(echo "$response" | jq -r '.result' 2>/dev/null)
    if [ "$gas_hex" = "null" ] || [ -z "$gas_hex" ]; then
        echo "21000"  # Default gas limit
    else
        printf "%d" "$gas_hex"
    fi
}

# Helper function to get gas price via RPC
get_gas_price() {
    local gas_price_json="{
        \"jsonrpc\": \"2.0\",
        \"method\": \"eth_gasPrice\",
        \"params\": [],
        \"id\": 1
    }"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$gas_price_json" \
        "$RPC_URL")
    
    local gas_price_hex=$(echo "$response" | jq -r '.result' 2>/dev/null)
    if [ "$gas_price_hex" = "null" ] || [ -z "$gas_price_hex" ]; then
        echo "1000000000"  # Default gas price (1 gwei)
    else
        printf "%d" "$gas_price_hex"
    fi
}

# Helper function to get nonce via RPC
get_nonce() {
    local address=$1
    
    local nonce_json="{
        \"jsonrpc\": \"2.0\",
        \"method\": \"eth_getTransactionCount\",
        \"params\": [\"$address\", \"latest\"],
        \"id\": 1
    }"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$nonce_json" \
        "$RPC_URL")
    
    local nonce_hex=$(echo "$response" | jq -r '.result' 2>/dev/null)
    if [ "$nonce_hex" = "null" ] || [ -z "$nonce_hex" ]; then
        echo "0"
    else
        printf "%d" "$nonce_hex"
    fi
}

sign_and_send_with_clef() {
    local to_address=$1
    local call_data=$2
    local value=$3
    local gas_limit=$4
    local gas_price=$5
    
    # Convert value to wei if specified
    if [ "$value" != "0" ]; then
        # Convert ETH to wei (multiply by 10^18)
        VALUE_WEI="0x$(printf '%x' $(echo "$value * 1000000000000000000" | bc))"
    else
        VALUE_WEI="0x0"
    fi
    
    # Get nonce using RPC
    NONCE=$(get_nonce "$LEDGER_ADDRESS")
    
    echo -e "${BLUE}🔧 Transaction details:${NC}"
    echo -e "   From: $LEDGER_ADDRESS"
    echo -e "   To: $to_address"
    echo -e "   Nonce: $NONCE"
    echo -e "   Gas Limit: $gas_limit (0x$(printf '%x' $gas_limit))"
    echo -e "   Gas Price: $gas_price (0x$(printf '%x' $gas_price))"
    echo -e "   Value: $VALUE_WEI"
    echo -e "   Data: $call_data"
    echo ""
    
    # Prepare transaction object for Clef signing
    TX_JSON=$(cat << EOF
{
    "jsonrpc": "2.0",
    "method": "account_signTransaction",
    "params": [{
        "from": "$LEDGER_ADDRESS",
        "to": "$to_address",
        "gas": "0x$(printf '%x' $gas_limit)",
        "gasPrice": "0x$(printf '%x' $gas_price)",
        "value": "$VALUE_WEI",
        "data": "$call_data",
        "nonce": "0x$(printf '%x' $NONCE)"
    }],
    "id": 1
}
EOF
)
    
    echo -e "${BLUE}📤 Sending to Clef:${NC}"
    echo "$TX_JSON" | jq '.' 2>/dev/null || echo "$TX_JSON"
    echo ""
    
    echo -e "${BLUE}🔐 Signing transaction with Clef...${NC}"
    
    # Sign transaction with Clef
    SIGNED_TX=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$TX_JSON" \
        http://127.0.0.1:8550)
    
    echo -e "${BLUE}📥 Clef response:${NC}"
    echo "$SIGNED_TX" | jq '.' 2>/dev/null || echo "$SIGNED_TX"
    echo ""
    
    # Check for errors
    local error=$(echo "$SIGNED_TX" | jq -r '.error.message' 2>/dev/null)
    if [ "$error" != "null" ] && [ -n "$error" ]; then
        echo -e "${RED}❌ Clef signing failed: $error${NC}"
        return 1
    fi
    
    # Extract signed transaction
    RAW_TX=$(echo "$SIGNED_TX" | jq -r '.result.raw' 2>/dev/null)
    
    if [ "$RAW_TX" = "null" ] || [ -z "$RAW_TX" ]; then
        echo -e "${RED}❌ Failed to get signed transaction from Clef${NC}"
        echo -e "${YELLOW}This might indicate:${NC}"
        echo -e "   • Ledger device is locked or disconnected"
        echo -e "   • Ethereum app is not open on Ledger"
        echo -e "   • 'Contract data' is not enabled in Ethereum app settings"
        echo -e "   • Clef is not properly connected to the Ledger"
        echo ""
        echo -e "${CYAN}Please check:${NC}"
        echo -e "   1. Ledger device is connected and unlocked"
        echo -e "   2. Ethereum app is open and shows 'Application is ready'"
        echo -e "   3. In Ethereum app settings: Enable 'Contract data'"
        echo -e "   4. Try reconnecting the Ledger device"
        return 1
    fi
    
    echo -e "${GREEN}✅ Transaction signed with Clef${NC}"
    echo -e "${YELLOW}📡 Broadcasting transaction via RPC...${NC}"
    
    # Broadcast transaction using RPC
    local broadcast_json="{
        \"jsonrpc\": \"2.0\",
        \"method\": \"eth_sendRawTransaction\",
        \"params\": [\"$RAW_TX\"],
        \"id\": 1
    }"
    
    local broadcast_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$broadcast_json" \
        "$RPC_URL")
    
    TX_HASH=$(echo "$broadcast_response" | jq -r '.result' 2>/dev/null)
    local broadcast_error=$(echo "$broadcast_response" | jq -r '.error.message' 2>/dev/null)
    
    if [ "$broadcast_error" != "null" ] && [ -n "$broadcast_error" ]; then
        echo -e "${RED}❌ Transaction broadcast failed: $broadcast_error${NC}"
        return 1
    fi
    
    if [ "$TX_HASH" = "null" ] || [ -z "$TX_HASH" ]; then
        echo -e "${RED}❌ Failed to broadcast transaction${NC}"
        echo -e "${YELLOW}Response: $broadcast_response${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Transaction broadcast successfully!${NC}"
    echo -e "${CYAN}Transaction Hash: $TX_HASH${NC}"
    
    # Wait for confirmation using RPC
    echo -e "${BLUE}⏳ Waiting for confirmation...${NC}"
    wait_for_confirmation "$TX_HASH"
}

# Helper function to wait for transaction confirmation via RPC
wait_for_confirmation() {
    local tx_hash=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local receipt_json="{
            \"jsonrpc\": \"2.0\",
            \"method\": \"eth_getTransactionReceipt\",
            \"params\": [\"$tx_hash\"],
            \"id\": 1
        }"
        
        local receipt_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            --data "$receipt_json" \
            "$RPC_URL")
        
        local receipt=$(echo "$receipt_response" | jq -r '.result' 2>/dev/null)
        
        if [ "$receipt" != "null" ] && [ -n "$receipt" ]; then
            local status=$(echo "$receipt_response" | jq -r '.result.status' 2>/dev/null)
            if [ "$status" = "0x1" ]; then
                echo -e "${GREEN}✅ Transaction confirmed!${NC}"
            else
                echo -e "${RED}❌ Transaction failed (reverted)${NC}"
            fi
            return 0
        fi
        
        sleep 2
        attempt=$((attempt + 1))
        echo -e "${BLUE}⏳ Still waiting... (attempt $attempt/$max_attempts)${NC}"
    done
    
    echo -e "${YELLOW}⚠️  Transaction sent but confirmation timeout${NC}"
}

# Contract interaction functions
approve_lp_tokens() {
    read -p "Enter amount to approve in LP tokens: " amount
    
    if [ -z "$amount" ]; then
        echo -e "${RED}Amount cannot be empty${NC}"
        return
    fi
    
    # Convert to wei (multiply by 10^18) using bash arithmetic
    AMOUNT_WEI=$(echo "$amount * 1000000000000000000" | bc)
    execute_transaction_with_clef "$LP_TOKEN_ADDRESS" 'approve(address,uint256)' "$LP_LOCKER_ADDRESS $AMOUNT_WEI"
}

lock_liquidity() {
    read -p "Enter amount to lock in LP tokens: " amount
    
    if [ -z "$amount" ]; then
        echo -e "${RED}Amount cannot be empty${NC}"
        return
    fi
    
    # Convert to wei (multiply by 10^18) using bash arithmetic
    AMOUNT_WEI=$(echo "$amount * 1000000000000000000" | bc)
    execute_transaction_with_clef "$LP_LOCKER_ADDRESS" 'lockLiquidity(uint256)' "$AMOUNT_WEI"
}

trigger_withdrawal() {
    read -p "Enter Lock ID 0x...: " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    execute_transaction_with_clef "$LP_LOCKER_ADDRESS" 'triggerWithdrawal(bytes32)' "$lock_id"
}

claim_fees() {
    read -p "Enter Lock ID 0x...: " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    execute_transaction_with_clef "$LP_LOCKER_ADDRESS" 'claimLPFees(bytes32)' "$lock_id"
}

update_fees() {
    read -p "Enter Lock ID 0x...: " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    execute_transaction_with_clef "$LP_LOCKER_ADDRESS" 'updateClaimableFees(bytes32)' "$lock_id"
}

# Helper function to make contract calls via RPC
call_contract() {
    local contract_address=$1
    local function_selector=$2
    local params=${3:-""}
    
    local call_data="0x${function_selector}${params}"
    
    local call_json="{
        \"jsonrpc\": \"2.0\",
        \"method\": \"eth_call\",
        \"params\": [{
            \"to\": \"$contract_address\",
            \"data\": \"$call_data\"
        }, \"latest\"],
        \"id\": 1
    }"
    
    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$call_json" \
        "$RPC_URL")
    
    echo "$response" | jq -r '.result' 2>/dev/null
}

# Helper function to decode uint256 from hex
decode_uint256() {
    local hex_value=$1
    # Remove 0x prefix if present
    hex_value=${hex_value#0x}
    
    # Handle empty or invalid hex
    if [ -z "$hex_value" ] || [ "$hex_value" = "0" ]; then
        echo "0"
        return
    fi
    
    # Convert to uppercase using tr instead of ${var^^} for compatibility
    hex_value=$(echo "$hex_value" | tr 'a-f' 'A-F')
    
    # Convert hex to decimal using bc (handles large numbers)
    echo "ibase=16; $hex_value" | bc 2>/dev/null || echo "0"
}

# Helper function to decode address from hex
decode_address() {
    local hex_data=$1
    local offset=${2:-0}
    
    # Extract 40 characters (20 bytes) from the specified offset
    local addr_hex=${hex_data:$((offset + 24)):40}  # Skip 24 chars padding, take 40 chars
    echo "0x$addr_hex"
}

# Helper function to decode bool from hex
decode_bool() {
    local hex_data=$1
    local offset=${2:-0}
    
    # Get the last character of the 32-byte word
    local bool_hex=${hex_data:$((offset + 62)):2}
    if [ "$bool_hex" = "01" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Helper function to format wei to ether
wei_to_ether() {
    local wei_amount=$1
    if [ -z "$wei_amount" ] || [ "$wei_amount" = "0" ]; then
        echo "0.0"
    else
        # Use bc for large number division to avoid overflow
        # Divide by 10^18 (1000000000000000000)
        echo "scale=6; $wei_amount / 1000000000000000000" | bc 2>/dev/null || echo "0.0"
    fi
}

# Get function selectors for reading functions
get_read_function_selector() {
    local function_sig=$1
    case "$function_sig" in
        "getLPBalance()")
            echo "6f43f17b"
            ;;
        "getAllLockIds()")
            echo "bc4ab7fb"
            ;;
        "getLockInfo(bytes32)")
            echo "8e5464db"
            ;;
        "getClaimableFees(bytes32)")
            echo "4a6d7142"
            ;;
        "getTotalAccumulatedFees(bytes32)")
            echo "22a0cb0d"
            ;;
        *)
            echo "00000000"  # Invalid
            ;;
    esac
}

view_contract_state() {
    echo -e "${YELLOW}📊 Contract State:${NC}"
    
    echo -e "${YELLOW}🔒 Contract Information:${NC}"
    echo -e "   Contract Address: ${CYAN}$LP_LOCKER_ADDRESS${NC}"
    echo -e "   LP Token Address: ${CYAN}$LP_TOKEN_ADDRESS${NC}"
    echo -e "   Connected Account: ${CYAN}$LEDGER_ADDRESS${NC}"
    echo ""
    
    # Get ETH balance of the connected account
    local balance_json="{
        \"jsonrpc\": \"2.0\",
        \"method\": \"eth_getBalance\",
        \"params\": [\"$LEDGER_ADDRESS\", \"latest\"],
        \"id\": 1
    }"
    
    local balance_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "$balance_json" \
        "$RPC_URL")
    
    local balance_hex=$(echo "$balance_response" | jq -r '.result' 2>/dev/null)
    if [ "$balance_hex" != "null" ] && [ -n "$balance_hex" ]; then
        local balance_wei=$(printf "%d" "$balance_hex")
        local balance_eth=$(wei_to_ether "$balance_wei")
        echo -e "   Account ETH Balance: ${CYAN}${balance_eth} ETH${NC}"
    else
        echo -e "   Account ETH Balance: ${RED}Unable to fetch${NC}"
    fi
    echo ""
    
    # Get LP token balance in the contract
    echo -e "${YELLOW}💰 LP Token Balance in Contract:${NC}"
    local lp_balance_selector=$(get_read_function_selector "getLPBalance()")
    local lp_balance_hex=$(call_contract "$LP_LOCKER_ADDRESS" "$lp_balance_selector")
    
    if [ "$lp_balance_hex" != "null" ] && [ -n "$lp_balance_hex" ] && [ "$lp_balance_hex" != "0x" ]; then
        local lp_balance_wei=$(decode_uint256 "$lp_balance_hex")
        local lp_balance_tokens=$(wei_to_ether "$lp_balance_wei")
        echo -e "   Total LP Tokens: ${CYAN}${lp_balance_tokens} tokens${NC}"
    else
        echo -e "   Total LP Tokens: ${RED}Unable to fetch${NC}"
    fi
    echo ""
    
    # Get all lock IDs
    echo -e "${YELLOW}🔒 All Locks:${NC}"
    local lock_ids_selector=$(get_read_function_selector "getAllLockIds()")
    local lock_ids_hex=$(call_contract "$LP_LOCKER_ADDRESS" "$lock_ids_selector")
    
    if [ "$lock_ids_hex" != "null" ] && [ -n "$lock_ids_hex" ] && [ "$lock_ids_hex" != "0x" ]; then
        # Parse dynamic array of bytes32
        # For dynamic arrays, the response format is:
        # - First 32 bytes: offset to array data (usually 0x20 = 32)
        # - Next 32 bytes: array length
        # - Then: array elements (each 32 bytes)
        local data=${lock_ids_hex#0x}  # Remove 0x prefix
        
        # Check if we have enough data for offset + length
        if [ ${#data} -lt 128 ]; then  # Need at least 128 chars (64 for offset + 64 for length)
            echo -e "   ${RED}❌ Invalid response from getAllLockIds()${NC}"
            echo ""
        else
            # Skip the offset (first 64 chars) and get the array length
            local array_length_hex=${data:64:64}  # Start at position 64, take 64 chars
            local array_length=$(decode_uint256 "$array_length_hex")
            
            echo -e "   Found ${CYAN}$array_length${NC} locks"
            echo ""
            
            if [ "$array_length" -gt 0 ] && [ "$array_length" -le 100 ]; then  # Sanity check
                # Calculate required data length: 64 (offset) + 64 (length) + array_length * 64 (each bytes32)
                local required_length=$((128 + array_length * 64))
                
                if [ ${#data} -ge $required_length ]; then
                    # Process each lock ID
                    for ((i=0; i<array_length; i++)); do
                        # Each bytes32 is 64 hex characters, starting after offset + length
                        local offset=$((128 + i * 64))
                        local lock_id_hex=${data:$offset:64}
                        
                        # Skip empty lock IDs (all zeros)
                        if [[ "$lock_id_hex" =~ ^0+$ ]] || [ -z "$lock_id_hex" ]; then
                            continue
                        fi
                        
                        local lock_id="0x$lock_id_hex"
                        
                        echo -e "   ${GREEN}📋 Lock #$((i + 1))${NC}"
                        echo -e "      ${BLUE}Lock ID:${NC} $lock_id"
                        echo ""
                        
                        # Get detailed lock information
                        get_lock_details "$lock_id" "      "
                        echo ""
                    done
                else
                    echo -e "   ${RED}❌ Insufficient data returned from contract${NC}"
                    echo -e "   ${YELLOW}Expected: $required_length chars, Got: ${#data} chars${NC}"
                    echo ""
                fi
            elif [ "$array_length" -gt 100 ]; then
                echo -e "   ${RED}❌ Suspiciously high number of locks ($array_length), likely parsing error${NC}"
                echo ""
            fi
        fi
    else
        echo -e "   ${CYAN}No locks found or error reading contract${NC}"
        echo ""
    fi
    
    # Available actions
    echo -e "${CYAN}💡 Available Public Actions (Anyone Can Call):${NC}"
    echo -e "   • Claim fees for any lock - fees go to designated receiver" 
    echo -e "   • Update fee calculations"
    echo ""
    echo -e "${YELLOW}⚠️  Owner-Only Actions:${NC}"
    echo -e "   • Lock liquidity, trigger/cancel withdrawals, withdraw LP tokens"
    echo -e "   • Change fee receiver, recover tokens, top up locks"
    echo ""
}

# Helper function to get detailed lock information
get_lock_details() {
    local lock_id=$1
    local indent=${2:-""}
    
    # Get lock info
    local lock_info_selector=$(get_read_function_selector "getLockInfo(bytes32)")
    local lock_id_param=${lock_id#0x}  # Remove 0x prefix
    local lock_info_hex=$(call_contract "$LP_LOCKER_ADDRESS" "$lock_info_selector" "$lock_id_param")
    
    if [ "$lock_info_hex" != "null" ] && [ -n "$lock_info_hex" ] && [ "$lock_info_hex" != "0x" ]; then
        # Decode the tuple (address,address,address,uint256,uint256,bool,bool)
        # Each field is 32 bytes (64 hex chars)
        local data=${lock_info_hex#0x}  # Remove 0x prefix
        
        local owner=$(decode_address "$data" 0)
        local fee_receiver=$(decode_address "$data" 64)
        local token_contract=$(decode_address "$data" 128)
        local amount_hex="0x${data:192:64}"
        local lock_end_time_hex="0x${data:256:64}"
        local is_locked=$(decode_bool "$data" 320)
        local is_withdrawal_triggered=$(decode_bool "$data" 384)
        
        local amount_wei=$(decode_uint256 "$amount_hex")
        local amount_tokens=$(wei_to_ether "$amount_wei")
        local lock_end_time=$(decode_uint256 "$lock_end_time_hex")
        
        # Format timestamp
        if [ "$lock_end_time" != "0" ]; then
            local lock_end_date=$(date -r "$lock_end_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Invalid timestamp")
            
            # Calculate remaining time
            local current_time=$(date +%s)
            if [ "$lock_end_time" -gt "$current_time" ]; then
                local remaining=$((lock_end_time - current_time))
                local days=$((remaining / 86400))
                local hours=$(( (remaining % 86400) / 3600 ))
                local time_status="${YELLOW}${days}d ${hours}h remaining${NC}"
            else
                local time_status="${GREEN}Ready for withdrawal${NC}"
            fi
        else
            local lock_end_date="Not set"
            local time_status="${YELLOW}No withdrawal triggered${NC}"
        fi
        
        # Format status
        if [ "$is_locked" = "true" ]; then
            local lock_status="${GREEN}Active${NC}"
        else
            local lock_status="${RED}Inactive${NC}"
        fi
        
        if [ "$is_withdrawal_triggered" = "true" ]; then
            local withdrawal_status="${YELLOW}Withdrawal triggered${NC}"
        else
            local withdrawal_status="${CYAN}No withdrawal triggered${NC}"
        fi
        
        # Display lock information
        echo -e "${indent}${YELLOW}🔒 Lock Information:${NC}"
        echo -e "${indent}   Owner:                 ${GREEN}$owner${NC}"
        echo -e "${indent}   Fee Receiver:          ${GREEN}$fee_receiver${NC}"
        echo -e "${indent}   Amount Locked:         ${CYAN}$amount_tokens LP tokens${NC}"
        echo -e "${indent}   Lock End Time:         ${CYAN}$lock_end_date${NC}"
        echo -e "${indent}   Status:                $lock_status"
        echo -e "${indent}   Withdrawal:            $withdrawal_status"
        echo -e "${indent}   Time Lock:             $time_status"
        echo ""
        
        # Get claimable fees
        get_claimable_fees "$lock_id" "${indent}   "
        
        # Get total accumulated fees
        get_total_fees "$lock_id" "${indent}   "
    else
        echo -e "${indent}${RED}❌ Could not get lock details${NC}"
    fi
}

# Helper function to get claimable fees
get_claimable_fees() {
    local lock_id=$1
    local indent=${2:-""}
    
    echo -e "${indent}${YELLOW}💰 Claimable Fees:${NC}"
    
    local fees_selector=$(get_read_function_selector "getClaimableFees(bytes32)")
    local lock_id_param=${lock_id#0x}
    local fees_hex=$(call_contract "$LP_LOCKER_ADDRESS" "$fees_selector" "$lock_id_param")
    
    if [ "$fees_hex" != "null" ] && [ -n "$fees_hex" ] && [ "$fees_hex" != "0x" ]; then
        # Decode tuple (address,uint256,address,uint256)
        local data=${fees_hex#0x}
        
        local token0=$(decode_address "$data" 0)
        local amount0_hex="0x${data:64:64}"
        local token1=$(decode_address "$data" 128)
        local amount1_hex="0x${data:192:64}"
        
        local amount0_wei=$(decode_uint256 "$amount0_hex")
        local amount1_wei=$(decode_uint256 "$amount1_hex")
        local amount0_tokens=$(wei_to_ether "$amount0_wei")
        local amount1_tokens=$(wei_to_ether "$amount1_wei")
        
        echo -e "${indent}   Token 0 (${GREEN}${token0:0:10}...${NC}): ${CYAN}$amount0_tokens${NC}"
        echo -e "${indent}   Token 1 (${GREEN}${token1:0:10}...${NC}): ${CYAN}$amount1_tokens${NC}"
    else
        echo -e "${indent}   ${RED}Error loading claimable fees${NC}"
    fi
    echo ""
}

# Helper function to get total accumulated fees
get_total_fees() {
    local lock_id=$1
    local indent=${2:-""}
    
    echo -e "${indent}${YELLOW}📊 Total Accumulated Fees:${NC}"
    
    local fees_selector=$(get_read_function_selector "getTotalAccumulatedFees(bytes32)")
    local lock_id_param=${lock_id#0x}
    local fees_hex=$(call_contract "$LP_LOCKER_ADDRESS" "$fees_selector" "$lock_id_param")
    
    if [ "$fees_hex" != "null" ] && [ -n "$fees_hex" ] && [ "$fees_hex" != "0x" ]; then
        # Decode tuple (address,uint256,address,uint256)
        local data=${fees_hex#0x}
        
        local token0=$(decode_address "$data" 0)
        local amount0_hex="0x${data:64:64}"
        local token1=$(decode_address "$data" 128)
        local amount1_hex="0x${data:192:64}"
        
        local amount0_wei=$(decode_uint256 "$amount0_hex")
        local amount1_wei=$(decode_uint256 "$amount1_hex")
        local amount0_tokens=$(wei_to_ether "$amount0_wei")
        local amount1_tokens=$(wei_to_ether "$amount1_wei")
        
        echo -e "${indent}   Token 0 (${GREEN}${token0:0:10}...${NC}): ${CYAN}$amount0_tokens${NC}"
        echo -e "${indent}   Token 1 (${GREEN}${token1:0:10}...${NC}): ${CYAN}$amount1_tokens${NC}"
    else
        echo -e "${indent}   ${RED}Error loading total accumulated fees${NC}"
    fi
}

test_clef_connection() {
    echo -e "${BLUE}🔍 Testing Clef connection...${NC}"
    
    # First check if Clef process is still running
    if [ -f "$CLEF_PID_FILE" ]; then
        local clef_pid=$(cat "$CLEF_PID_FILE")
        if ! kill -0 "$clef_pid" 2>/dev/null; then
            echo -e "${RED}❌ Clef process is not running (PID $clef_pid not found)${NC}"
            echo -e "${YELLOW}Checking recent Clef logs...${NC}"
            echo ""
            tail -5 "$CLEF_CONFIG_DIR/clef.log" 2>/dev/null || echo "No logs found"
            echo ""
            echo -e "${CYAN}Possible issues:${NC}"
            echo -e "   • Ledger device disconnected or locked"
            echo -e "   • Ethereum app not open on Ledger"
            echo -e "   • Clef crashed during account derivation"
            echo ""
            return 1
        else
            echo -e "${GREEN}✅ Clef process is running (PID: $clef_pid)${NC}"
        fi
    else
        echo -e "${RED}❌ No Clef PID file found${NC}"
        return 1
    fi
    
    # Test basic HTTP connectivity
    echo -e "${BLUE}Testing HTTP endpoint...${NC}"
    local http_test=$(curl -s -m 5 -w "%{http_code}" -o /dev/null http://127.0.0.1:8550/ 2>/dev/null)
    
    if [ "$http_test" = "405" ] || [ "$http_test" = "200" ]; then
        echo -e "${GREEN}✅ HTTP endpoint responding (HTTP $http_test)${NC}"
    else
        echo -e "${RED}❌ HTTP endpoint not responding (got: $http_test)${NC}"
        return 1
    fi
    
    # Test basic connectivity with JSON-RPC
    local test_response=$(curl -s -m 10 -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"account_list","params":[],"id":1}' \
        http://127.0.0.1:8550 2>/dev/null)
    
    if [ -z "$test_response" ]; then
        echo -e "${RED}❌ No response from Clef JSON-RPC endpoint${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📥 Clef JSON-RPC response:${NC}"
    echo "$test_response" | jq '.' 2>/dev/null || echo "$test_response"
    echo ""
    
    # Check for specific errors
    local error=$(echo "$test_response" | jq -r '.error.message' 2>/dev/null)
    if [ "$error" != "null" ] && [ -n "$error" ]; then
        echo -e "${RED}❌ Clef error: $error${NC}"
        
        if [[ "$error" == *"no accounts"* ]] || [[ "$error" == *"account derivation"* ]]; then
            echo -e "${YELLOW}💡 This suggests Ledger connection issues${NC}"
            echo -e "${CYAN}Try:${NC}"
            echo -e "   1. Disconnect and reconnect your Ledger"
            echo -e "   2. Close and reopen the Ethereum app"
            echo -e "   3. Ensure 'Contract data' is enabled in settings"
            echo -e "   4. Restart this script"
        fi
        return 1
    fi
    
    # Check if we got account data
    local accounts=$(echo "$test_response" | jq -r '.result[]?' 2>/dev/null)
    if [ -n "$accounts" ]; then
        echo -e "${GREEN}✅ Clef is working and has account access${NC}"
        echo -e "${CYAN}Available accounts:${NC}"
        echo "$accounts" | while read -r account; do
            echo "   $account"
        done
    else
        echo -e "${YELLOW}⚠️  Clef is responding but has no accounts${NC}"
        echo -e "${BLUE}This might mean:${NC}"
        echo -e "   • Account listing was not approved"
        echo -e "   • Ledger is not properly connected"
        echo -e "   • No accounts were successfully derived"
    fi
    
    echo ""
    return 0
}

show_menu() {
    echo -e "${YELLOW}Available Actions:${NC}"
    echo "1)  View Contract State"
    echo "2)  Approve LP Tokens"
    echo "3)  Lock Liquidity"
    echo "4)  Trigger Withdrawal"
    echo "5)  Claim Fees"
    echo "6)  Update Fees"
    echo "7)  Test Clef Connection"
    echo "8)  Restart Clef"
    echo "9)  Stop Clef"
    echo "0)  Exit"
    echo ""
}

cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    stop_clef
    exit 0
}

# Trap cleanup on script exit
trap cleanup EXIT INT TERM

main() {
    print_header
    check_dependencies
    check_env
    check_clef_installed
    setup_clef
    select_network
    
    if ! start_clef; then
        echo -e "${RED}❌ Failed to start Clef${NC}"
        exit 1
    fi
    
    if ! get_ledger_accounts; then
        echo -e "${RED}❌ Failed to get Ledger accounts${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Ready for transactions!${NC}"
    echo -e "${CYAN}Contract: $LP_LOCKER_ADDRESS${NC}"
    echo -e "${CYAN}Network: $NETWORK_NAME${NC}"
    echo -e "${CYAN}Account: $LEDGER_ADDRESS${NC}"
    echo ""
    
    while true; do
        show_menu
        read -p "Enter choice 0-9: " choice
        echo ""
        
        case $choice in
            1) view_contract_state ;;
            2) approve_lp_tokens ;;
            3) lock_liquidity ;;
            4) trigger_withdrawal ;;
            5) claim_fees ;;
            6) update_fees ;;
            7) test_clef_connection ;;
            8) 
                echo -e "${YELLOW}Restarting Clef...${NC}"
                stop_clef
                echo ""
                if start_clef; then
                    echo -e "${GREEN}✅ Clef restarted successfully${NC}"
                    # Update ledger accounts
                    get_ledger_accounts
                else
                    echo -e "${RED}❌ Failed to restart Clef${NC}"
                fi
                ;;
            9) 
                stop_clef
                echo -e "${GREEN}Clef stopped${NC}"
                ;;
            0) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                echo ""
                ;;
        esac
    done
}

# Run main function
main "$@" 