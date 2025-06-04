#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Check required environment variables
check_env() {
    if [ -z "$LP_LOCKER_ADDRESS" ]; then
        echo -e "${RED}Error: LP_LOCKER_ADDRESS not set in .env${NC}"
        exit 1
    fi
    
    if [ -z "$LP_TOKEN_ADDRESS" ]; then
        echo -e "${RED}Error: LP_TOKEN_ADDRESS not set in .env${NC}"
        exit 1
    fi
}

# Utility functions
print_header() {
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}          LP Locker - Ledger Interface      ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

print_contract_info() {
    echo -e "${BLUE}Contract Information:${NC}"
    echo -e "LP Locker: ${GREEN}$LP_LOCKER_ADDRESS${NC}"
    echo -e "LP Token:  ${GREEN}$LP_TOKEN_ADDRESS${NC}"
    echo ""
}

# Get Ledger address
get_ledger_address() {
    echo -e "${YELLOW}Connecting to Ledger...${NC}"
    LEDGER_ADDRESS=$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$LEDGER_ADDRESS" ]; then
        echo -e "${RED}Error: Could not connect to Ledger. Please ensure:${NC}"
        echo "  1. Ledger is connected and unlocked"
        echo "  2. Ethereum app is open on Ledger"
        echo "  3. Contract data is enabled in Ethereum app settings"
        exit 1
    fi
    
    echo -e "${GREEN}Connected to Ledger: $LEDGER_ADDRESS${NC}"
    echo ""
}

# Network selection
select_network() {
    echo -e "${YELLOW}Select network:${NC}"
    echo "1) Anvil Local (31337)"
    echo "2) Base Mainnet (8453)"
    echo ""
    read -p "Enter choice (1-2): " network_choice
    
    case $network_choice in
        1)
            RPC_URL="http://127.0.0.1:8545"
            NETWORK_NAME="Anvil Local"
            ;;
        2)
            RPC_URL="https://mainnet.base.org"
            NETWORK_NAME="Base Mainnet"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}Selected: $NETWORK_NAME${NC}"
    echo ""
}

# View contract state
view_contract_state() {
    echo -e "${BLUE}Fetching contract state...${NC}"
    
    # Get all lock IDs and parse them
    echo -e "${PURPLE}📋 All Lock IDs:${NC}"
    LOCK_IDS_RAW=$(cast call $LP_LOCKER_ADDRESS "getAllLockIds()" --rpc-url $RPC_URL)
    
    # Parse the ABI-encoded array of bytes32
    # Use correct format for cast --abi-decode with function signature
    LOCK_IDS_PARSED=$(cast --abi-decode "getLockIds()(bytes32[])" $LOCK_IDS_RAW 2>/dev/null)
    
    if [ $? -ne 0 ] || [[ "$LOCK_IDS_PARSED" == "[]" ]] || [ -z "$LOCK_IDS_PARSED" ]; then
        echo "   No locks found"
    else
        # Remove brackets and split by comma, handle spaces
        LOCK_IDS_CLEAN=$(echo "$LOCK_IDS_PARSED" | sed 's/\[//g' | sed 's/\]//g' | sed 's/, */\n/g')
        LOCK_COUNT=0
        
        # Process each lock ID
        while IFS= read -r lock_id; do
            if [ -n "$lock_id" ] && [ "$lock_id" != "" ]; then
                LOCK_COUNT=$((LOCK_COUNT + 1))
                echo "   Lock #$LOCK_COUNT: $lock_id"
            fi
        done <<< "$LOCK_IDS_CLEAN"
        
        if [ $LOCK_COUNT -eq 0 ]; then
            echo "   No locks found"
        fi
    fi
    
    echo ""
    
    # Get LP balance
    LP_BALANCE=$(cast call $LP_LOCKER_ADDRESS "getLPBalance()" --rpc-url $RPC_URL)
    LP_BALANCE_FORMATTED=$(cast --to-unit $LP_BALANCE ether)
    echo -e "${PURPLE}🏦 Total LP Balance:${NC} $LP_BALANCE_FORMATTED LP tokens"
    
    # Get user's LP token balance
    USER_LP_BALANCE=$(cast call $LP_TOKEN_ADDRESS "balanceOf(address)" $LEDGER_ADDRESS --rpc-url $RPC_URL)
    USER_LP_BALANCE_FORMATTED=$(cast --to-unit $USER_LP_BALANCE ether)
    echo -e "${PURPLE}💰 Your LP Balance:${NC} $USER_LP_BALANCE_FORMATTED LP tokens"
    
    # Get allowance
    ALLOWANCE=$(cast call $LP_TOKEN_ADDRESS "allowance(address,address)" $LEDGER_ADDRESS $LP_LOCKER_ADDRESS --rpc-url $RPC_URL)
    ALLOWANCE_FORMATTED=$(cast --to-unit $ALLOWANCE ether)
    echo -e "${PURPLE}✅ Current Allowance:${NC} $ALLOWANCE_FORMATTED LP tokens"
    
    echo ""
}

# View specific lock details
view_lock_details() {
    read -p "Enter Lock ID (0x...): " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    echo -e "${BLUE}📊 Fetching lock details for: ${CYAN}$lock_id${NC}"
    echo ""
    
    # Get lock info
    LOCK_INFO_RAW=$(cast call $LP_LOCKER_ADDRESS "getLockInfo(bytes32)" $lock_id --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error: Invalid lock ID or lock does not exist${NC}"
        return
    fi
    
    # Parse lock info manually - cast --abi-decode returns multi-line format
    LOCK_INFO_PARSED=$(cast --abi-decode "getLockInfo(bytes32)(address,address,address,uint256,uint256,bool,bool)" $LOCK_INFO_RAW)
    
    # Extract fields from multi-line output (each line is a field)
    OWNER=$(echo "$LOCK_INFO_PARSED" | sed -n '1p')
    FEE_RECEIVER=$(echo "$LOCK_INFO_PARSED" | sed -n '2p')
    TOKEN_CONTRACT=$(echo "$LOCK_INFO_PARSED" | sed -n '3p')
    AMOUNT=$(echo "$LOCK_INFO_PARSED" | sed -n '4p')
    LOCK_END_TIME=$(echo "$LOCK_INFO_PARSED" | sed -n '5p')
    IS_LOCKED=$(echo "$LOCK_INFO_PARSED" | sed -n '6p')
    IS_WITHDRAWAL_TRIGGERED=$(echo "$LOCK_INFO_PARSED" | sed -n '7p')
    
    # Clean up the amount field (remove any extra formatting)
    AMOUNT=$(echo "$AMOUNT" | sed 's/\[.*\]//g' | xargs)
    
    # Format amounts
    AMOUNT_FORMATTED=$(cast --to-unit $AMOUNT ether 2>/dev/null || echo "Error formatting amount")
    
    # Format timestamp
    if [[ "$LOCK_END_TIME" != "0" ]] && [[ "$LOCK_END_TIME" =~ ^[0-9]+$ ]]; then
        LOCK_END_DATE=$(date -r $LOCK_END_TIME '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Invalid timestamp")
    else
        LOCK_END_DATE="Not set"
    fi
    
    # Display formatted lock information
    echo -e "${YELLOW}🔒 Lock Information:${NC}"
    echo -e "   Owner:                 ${GREEN}$OWNER${NC}"
    echo -e "   Fee Receiver:          ${GREEN}$FEE_RECEIVER${NC}"
    echo -e "   Token Contract:        ${GREEN}$TOKEN_CONTRACT${NC}"
    echo -e "   Amount Locked:         ${CYAN}$AMOUNT_FORMATTED LP tokens${NC}"
    echo -e "   Lock End Time:         ${CYAN}$LOCK_END_DATE${NC}"
    echo -e "   Liquidity Locked:      ${CYAN}$IS_LOCKED${NC}"
    echo -e "   Withdrawal Triggered:  ${CYAN}$IS_WITHDRAWAL_TRIGGERED${NC}"
    echo ""
    
    # Get claimable fees
    echo -e "${YELLOW}💰 Claimable Fees:${NC}"
    CLAIMABLE_FEES_RAW=$(cast call $LP_LOCKER_ADDRESS "getClaimableFees(bytes32)" $lock_id --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Parse fees using multi-line format
        CLAIMABLE_FEES_PARSED=$(cast --abi-decode "getClaimableFees(bytes32)(address,uint256,address,uint256)" $CLAIMABLE_FEES_RAW)
        
        TOKEN0=$(echo "$CLAIMABLE_FEES_PARSED" | sed -n '1p')
        AMOUNT0=$(echo "$CLAIMABLE_FEES_PARSED" | sed -n '2p')
        TOKEN1=$(echo "$CLAIMABLE_FEES_PARSED" | sed -n '3p')
        AMOUNT1=$(echo "$CLAIMABLE_FEES_PARSED" | sed -n '4p')
        
        # Clean amounts and format
        AMOUNT0=$(echo "$AMOUNT0" | sed 's/\[.*\]//g' | xargs)
        AMOUNT1=$(echo "$AMOUNT1" | sed 's/\[.*\]//g' | xargs)
        
        AMOUNT0_FORMATTED=$(cast --to-unit $AMOUNT0 ether 2>/dev/null || echo "0.0")
        AMOUNT1_FORMATTED=$(cast --to-unit $AMOUNT1 ether 2>/dev/null || echo "0.0")
        
        echo -e "   Token 0 (${GREEN}${TOKEN0:0:10}...${NC}): ${CYAN}$AMOUNT0_FORMATTED${NC}"
        echo -e "   Token 1 (${GREEN}${TOKEN1:0:10}...${NC}): ${CYAN}$AMOUNT1_FORMATTED${NC}"
    else
        echo -e "   ${RED}Error loading claimable fees${NC}"
    fi
    echo ""
    
    # Get total accumulated fees
    echo -e "${YELLOW}📊 Total Accumulated Fees:${NC}"
    TOTAL_FEES_RAW=$(cast call $LP_LOCKER_ADDRESS "getTotalAccumulatedFees(bytes32)" $lock_id --rpc-url $RPC_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        # Parse fees using multi-line format
        TOTAL_FEES_PARSED=$(cast --abi-decode "getTotalAccumulatedFees(bytes32)(address,uint256,address,uint256)" $TOTAL_FEES_RAW)
        
        TOTAL_TOKEN0=$(echo "$TOTAL_FEES_PARSED" | sed -n '1p')
        TOTAL_AMOUNT0=$(echo "$TOTAL_FEES_PARSED" | sed -n '2p')
        TOTAL_TOKEN1=$(echo "$TOTAL_FEES_PARSED" | sed -n '3p')
        TOTAL_AMOUNT1=$(echo "$TOTAL_FEES_PARSED" | sed -n '4p')
        
        # Clean amounts and format
        TOTAL_AMOUNT0=$(echo "$TOTAL_AMOUNT0" | sed 's/\[.*\]//g' | xargs)
        TOTAL_AMOUNT1=$(echo "$TOTAL_AMOUNT1" | sed 's/\[.*\]//g' | xargs)
        
        TOTAL_AMOUNT0_FORMATTED=$(cast --to-unit $TOTAL_AMOUNT0 ether 2>/dev/null || echo "0.0")
        TOTAL_AMOUNT1_FORMATTED=$(cast --to-unit $TOTAL_AMOUNT1 ether 2>/dev/null || echo "0.0")
        
        echo -e "   Token 0 (${GREEN}${TOTAL_TOKEN0:0:10}...${NC}): ${CYAN}$TOTAL_AMOUNT0_FORMATTED${NC}"
        echo -e "   Token 1 (${GREEN}${TOTAL_TOKEN1:0:10}...${NC}): ${CYAN}$TOTAL_AMOUNT1_FORMATTED${NC}"
    else
        echo -e "   ${RED}Error loading total accumulated fees${NC}"
    fi
    
    echo ""
}

# Execute transaction with Ledger
execute_transaction() {
    local function_name=$1
    local params=$2
    
    echo -e "${YELLOW}Preparing transaction...${NC}"
    echo -e "Function: ${CYAN}$function_name${NC}"
    echo -e "Parameters: ${CYAN}$params${NC}"
    echo -e "Network: ${CYAN}$NETWORK_NAME ($RPC_URL)${NC}"
    echo -e "Ledger Address: ${CYAN}$LEDGER_ADDRESS${NC}"
    echo ""
    
    # Verify environment variables
    if [ -z "$RPC_URL" ]; then
        echo -e "${RED}❌ Error: RPC_URL is not set${NC}"
        return 1
    fi
    
    if [ -z "$LEDGER_ADDRESS" ]; then
        echo -e "${RED}❌ Error: LEDGER_ADDRESS is not set${NC}"
        return 1
    fi
    
    if [ -z "$LP_LOCKER_ADDRESS" ]; then
        echo -e "${RED}❌ Error: LP_LOCKER_ADDRESS is not set${NC}"
        return 1
    fi
    
    # Test network connectivity
    echo -e "${BLUE}🔍 Testing network connectivity...${NC}"
    BLOCK_NUMBER=$(cast block-number --rpc-url $RPC_URL 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error: Cannot connect to network at $RPC_URL${NC}"
        echo -e "${YELLOW}Please check your network selection and RPC endpoint${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Connected to network (block: $BLOCK_NUMBER)${NC}"
    
    # Verify Ledger is still connected
    echo -e "${BLUE}🔍 Verifying Ledger connection...${NC}"
    CURRENT_LEDGER=$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null)
    if [ $? -ne 0 ] || [ "$CURRENT_LEDGER" != "$LEDGER_ADDRESS" ]; then
        echo -e "${RED}❌ Error: Ledger connection lost or address changed${NC}"
        echo -e "${YELLOW}Please ensure Ledger is connected and Ethereum app is open${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Ledger connected ($CURRENT_LEDGER)${NC}"
    
    # Check account balance for gas
    echo -e "${BLUE}🔍 Checking account balance...${NC}"
    BALANCE=$(cast balance $LEDGER_ADDRESS --rpc-url $RPC_URL 2>/dev/null)
    if [ $? -eq 0 ]; then
        BALANCE_ETH=$(cast --to-unit $BALANCE ether)
        echo -e "${GREEN}✅ Account balance: $BALANCE_ETH ETH${NC}"
        
        # Simple check if balance is very low (compare wei directly)
        if [ "$BALANCE" -lt "1000000000000000" ]; then  # Less than 0.001 ETH
            echo -e "${YELLOW}⚠️  Warning: Low ETH balance may cause transaction to fail${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Could not check balance${NC}"
    fi
    
    echo ""
    read -p "Confirm transaction? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Transaction cancelled${NC}"
        return
    fi
    
    echo -e "${YELLOW}🔄 Executing transaction...${NC}"
    echo -e "${YELLOW}Please confirm on your Ledger device when prompted${NC}"
    echo ""
    
    # Add more verbose output for debugging
    echo -e "${BLUE}📝 Transaction details:${NC}"
    echo -e "   Script: script/LedgerInteraction.s.sol:LedgerInteractionScript"
    echo -e "   Function: $function_name"
    echo -e "   Params: $params"
    echo -e "   RPC: $RPC_URL"
    echo -e "   Sender: $LEDGER_ADDRESS"
    echo ""
    
    # Execute with Ledger
    forge script script/LedgerInteraction.s.sol:LedgerInteractionScript \
        --sig "$function_name" $params \
        --rpc-url $RPC_URL \
        --ledger \
        --sender $LEDGER_ADDRESS \
        --broadcast \
        -vvv
    
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✅ Transaction successful!${NC}"
    else
        echo -e "${RED}❌ Transaction failed with exit code: $EXIT_CODE${NC}"
        echo -e "${YELLOW}Common issues:${NC}"
        echo -e "  • Ledger device locked or Ethereum app closed"
        echo -e "  • Transaction rejected on Ledger device"
        echo -e "  • Insufficient gas or balance"
        echo -e "  • Network connectivity issues"
        echo -e "  • Contract function requirements not met"
    fi
    echo ""
}

# Menu functions
approve_lp_tokens() {
    read -p "Enter amount to approve (in LP tokens): " amount
    
    if [ -z "$amount" ]; then
        echo -e "${RED}Amount cannot be empty${NC}"
        return
    fi
    
    # Convert to wei
    AMOUNT_WEI=$(cast --to-wei $amount ether)
    execute_transaction "approveLPToken(uint256)" $AMOUNT_WEI
}

lock_liquidity() {
    read -p "Enter amount to lock (in LP tokens): " amount
    
    if [ -z "$amount" ]; then
        echo -e "${RED}Amount cannot be empty${NC}"
        return
    fi
    
    # Convert to wei
    AMOUNT_WEI=$(cast --to-wei $amount ether)
    execute_transaction "lockLiquidity(uint256)" $AMOUNT_WEI
}

trigger_withdrawal() {
    read -p "Enter Lock ID (0x...): " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    execute_transaction "triggerWithdrawal(bytes32)" $lock_id
}

cancel_withdrawal() {
    read -p "Enter Lock ID (0x...): " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    execute_transaction "cancelWithdrawalTrigger(bytes32)" $lock_id
}

withdraw_lp() {
    read -p "Enter Lock ID (0x...): " lock_id
    read -p "Enter amount to withdraw (in LP tokens): " amount
    
    if [ -z "$lock_id" ] || [ -z "$amount" ]; then
        echo -e "${RED}Lock ID and amount cannot be empty${NC}"
        return
    fi
    
    # Convert to wei
    AMOUNT_WEI=$(cast --to-wei $amount ether)
    execute_transaction "withdrawLP(bytes32,uint256)" "$lock_id $AMOUNT_WEI"
}

top_up_lock() {
    read -p "Enter Lock ID (0x...): " lock_id
    read -p "Enter amount to add (in LP tokens): " amount
    
    if [ -z "$lock_id" ] || [ -z "$amount" ]; then
        echo -e "${RED}Lock ID and amount cannot be empty${NC}"
        return
    fi
    
    # Convert to wei
    AMOUNT_WEI=$(cast --to-wei $amount ether)
    execute_transaction "topUpLock(bytes32,uint256)" "$lock_id $AMOUNT_WEI"
}

claim_fees() {
    read -p "Enter Lock ID (0x...): " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    execute_transaction "claimLPFees(bytes32)" $lock_id
}

update_fees() {
    read -p "Enter Lock ID (0x...): " lock_id
    
    if [ -z "$lock_id" ]; then
        echo -e "${RED}Lock ID cannot be empty${NC}"
        return
    fi
    
    execute_transaction "updateClaimableFees(bytes32)" $lock_id
}

change_fee_receiver() {
    read -p "Enter new fee receiver address (0x...): " new_receiver
    
    if [ -z "$new_receiver" ]; then
        echo -e "${RED}Address cannot be empty${NC}"
        return
    fi
    
    execute_transaction "changeFeeReceiver(address)" $new_receiver
}

recover_token() {
    read -p "Enter token address to recover (0x...): " token_address
    read -p "Enter amount to recover (in tokens): " amount
    
    if [ -z "$token_address" ] || [ -z "$amount" ]; then
        echo -e "${RED}Token address and amount cannot be empty${NC}"
        return
    fi
    
    # Convert to wei (assuming 18 decimals)
    AMOUNT_WEI=$(cast --to-wei $amount ether)
    execute_transaction "recoverToken(address,uint256)" "$token_address $AMOUNT_WEI"
}

# Main menu
show_menu() {
    echo -e "${YELLOW}Available Actions:${NC}"
    echo "1)  View Contract State"
    echo "2)  View Lock Details"
    echo "3)  Approve LP Tokens"
    echo "4)  Lock Liquidity"
    echo "5)  Trigger Withdrawal"
    echo "6)  Cancel Withdrawal"
    echo "7)  Withdraw LP Tokens"
    echo "8)  Top Up Lock"
    echo "9)  Claim Fees"
    echo "10) Update Fees"
    echo "11) Change Fee Receiver"
    echo "12) Recover Token"
    echo "0)  Exit"
    echo ""
}

# Main execution
main() {
    print_header
    check_env
    select_network
    get_ledger_address
    print_contract_info
    
    while true; do
        show_menu
        read -p "Enter choice (0-12): " choice
        echo ""
        
        case $choice in
            1) view_contract_state ;;
            2) view_lock_details ;;
            3) approve_lp_tokens ;;
            4) lock_liquidity ;;
            5) trigger_withdrawal ;;
            6) cancel_withdrawal ;;
            7) withdraw_lp ;;
            8) top_up_lock ;;
            9) claim_fees ;;
            10) update_fees ;;
            11) change_fee_receiver ;;
            12) recover_token ;;
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
main 