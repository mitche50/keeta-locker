# LPLocker Development Makefile

# Default target
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Help target
help: ## Show this help message
	@echo "LP Locker Smart Contract - Build & Deploy System"
	@echo "================================================"
	@echo ""
	@echo "Development Environment:"
	@echo "  make anvil              - Start local Anvil blockchain"
	@echo "  make deploy-anvil       - Deploy contract to Anvil"
	@echo "  make deploy-anvil-update - Update existing Anvil deployment"
	@echo "  make deploy-ledger-anvil - Deploy to Anvil with Ledger as owner"
	@echo ""
	@echo "Production Deployment:"
	@echo "  make deploy-base        - Deploy contract to Base mainnet"
	@echo ""
	@echo "Advanced Deployment:"
	@echo "  make generate-vanity    - Generate vanity address with CREATE2"
	@echo "  make deploy-create2-anvil - Deploy with CREATE2 to Anvil"
	@echo "  make deploy-create2-base  - Deploy with CREATE2 to Base"
	@echo ""
	@echo "Testing & Analysis:"
	@echo "  make test               - Run all tests"
	@echo "  make test-gas           - Run tests with gas reports"
	@echo "  make coverage           - Generate coverage report"
	@echo ""
	@echo "Frontend Development:"
	@echo "  make frontend-install   - Install frontend dependencies"
	@echo "  make frontend           - Start frontend dev server"
	@echo "  make frontend-build     - Build frontend for production"
	@echo "  make frontend-preview   - Preview production build"
	@echo ""
	@echo "Ledger Hardware Wallet:"
	@echo "  make ledger-help        - Show detailed Ledger guide"
	@echo "  make ledger-test        - Test device compatibility"
	@echo "  make ledger-interact    - Interactive Ledger interface"
	@echo "  make ledger-check       - Test Ledger connection"
	@echo "  make ledger-view-state  - View contract state"
	@echo ""
	@echo "Code Quality:"
	@echo "  make fmt                - Format all code"
	@echo "  make fmt-check          - Check code formatting"
	@echo "  make lint-frontend      - Lint frontend code"
	@echo ""
	@echo "Utilities:"
	@echo "  make dev                - Start full development environment"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make check-env          - Verify environment setup"
	@echo ""
	@echo "📖 For detailed Ledger usage: make ledger-help"
	@echo "📖 For environment setup: see README.md"

# Blockchain Development
anvil: ## Start Anvil local testnet
	@echo "$(CYAN)Starting Anvil local testnet...$(RESET)"
	anvil --host 0.0.0.0 --port 8545 --chain-id 31337

deploy-anvil: ## Deploy contracts to Anvil
	@echo "$(CYAN)Deploying to Anvil...$(RESET)"
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script script/Deploy.s.sol:DeployScript --rpc-url http://127.0.0.1:8545 --broadcast --legacy

deploy-anvil-update: deploy-anvil ## Deploy to Anvil and update frontend config
	@echo "$(CYAN)Updating frontend configuration...$(RESET)"
	node script/update-frontend-config.js

deploy-ledger-anvil: ## Deploy contracts to Anvil with Ledger as owner
	@echo "$(CYAN)Deploying to Anvil with Ledger as owner...$(RESET)"
	@if [ -z "$(OWNER_ADDRESS)" ]; then \
		echo "$(RED)Error: OWNER_ADDRESS not set$(RESET)"; \
		echo "$(YELLOW)Usage: make deploy-ledger-anvil OWNER_ADDRESS=0x...$(RESET)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Owner will be: $(OWNER_ADDRESS)$(RESET)"
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	OWNER_ADDRESS=$(OWNER_ADDRESS) \
	forge script script/DeployLedger.s.sol:DeployLedgerScript --rpc-url http://127.0.0.1:8545 --broadcast --legacy
	@echo "$(CYAN)Updating frontend configuration...$(RESET)"
	node script/update-frontend-config.js

deploy-base: ## Deploy contracts to Base mainnet
	@echo "$(CYAN)Deploying to Base mainnet...$(RESET)"
	forge script script/Deploy.s.sol:DeployScript --rpc-url base --broadcast --verify

# CREATE2 Vanity Address Deployment
generate-vanity: ## Generate vanity address using CREATE2
	@echo "$(CYAN)Generating vanity address...$(RESET)"
	./script/generate-vanity.sh

deploy-create2-anvil: ## Deploy to Anvil using CREATE2
	@echo "$(CYAN)Deploying to Anvil using CREATE2...$(RESET)"
	PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
	forge script script/DeployCreate2.s.sol:DeployCreate2Script --rpc-url http://127.0.0.1:8545 --broadcast --legacy

deploy-create2-base: ## Deploy to Base mainnet using CREATE2
	@echo "$(CYAN)Deploying to Base mainnet using CREATE2...$(RESET)"
	forge script script/DeployCreate2.s.sol:DeployCreate2Script --rpc-url base --broadcast --verify

# Testing
test: ## Run smart contract tests
	@echo "$(CYAN)Running tests...$(RESET)"
	forge test

test-gas: ## Run tests with gas reporting
	@echo "$(CYAN)Running tests with gas reporting...$(RESET)"
	forge test --gas-report

coverage: ## Generate test coverage report
	@echo "$(CYAN)Generating coverage report...$(RESET)"
	forge coverage

# Frontend Development
frontend-install: ## Install frontend dependencies
	@echo "$(CYAN)Installing frontend dependencies...$(RESET)"
	cd ../frontend && bun install

frontend: ## Start frontend development server
	@echo "$(CYAN)Starting frontend development server...$(RESET)"
	cd ../frontend && bun run dev

frontend-build: ## Build frontend for production
	@echo "$(CYAN)Building frontend for production...$(RESET)"
	cd ../frontend && bun run build

frontend-preview: ## Preview production build
	@echo "$(CYAN)Previewing production build...$(RESET)"
	cd ../frontend && bun run preview

# Code Quality
fmt: ## Format Solidity code
	@echo "$(CYAN)Formatting Solidity code...$(RESET)"
	forge fmt

fmt-check: ## Check Solidity code formatting
	@echo "$(CYAN)Checking Solidity code formatting...$(RESET)"
	forge fmt --check

lint-frontend: ## Lint frontend code
	@echo "$(CYAN)Linting frontend code...$(RESET)"
	cd ../frontend && bun run lint

clean: ## Clean build artifacts
	@echo "$(CYAN)Cleaning build artifacts...$(RESET)"
	forge clean
	rm -rf ../frontend/dist

# Combined Development
dev: ## Start both Anvil and frontend (requires two terminals)
	@echo "$(YELLOW)This will start Anvil. Run 'make frontend' in another terminal.$(RESET)"
	make anvil

# Utility
check-env: ## Check if required environment variables are set
	@echo "$(CYAN)Checking environment variables...$(RESET)"
	@if [ -f .env ]; then \
		echo "$(GREEN)✓ .env file found$(RESET)"; \
		if grep -q "PRIVATE_KEY" .env; then echo "$(GREEN)✓ PRIVATE_KEY set$(RESET)"; else echo "$(RED)✗ PRIVATE_KEY missing$(RESET)"; fi; \
		if grep -q "LP_TOKEN_ADDRESS" .env; then echo "$(GREEN)✓ LP_TOKEN_ADDRESS set$(RESET)"; else echo "$(RED)✗ LP_TOKEN_ADDRESS missing$(RESET)"; fi; \
		if grep -q "BASESCAN_API_KEY" .env; then echo "$(GREEN)✓ BASESCAN_API_KEY set$(RESET)"; else echo "$(YELLOW)⚠ BASESCAN_API_KEY missing (needed for verification)$(RESET)"; fi; \
	else \
		echo "$(RED)✗ .env file not found$(RESET)"; \
		echo "$(YELLOW)Create .env file with: PRIVATE_KEY, LP_TOKEN_ADDRESS, BASESCAN_API_KEY$(RESET)"; \
	fi

# Ledger Commands
ledger-interact:
	@echo "Starting Foundry Ledger Interface..."
	@./script/ledger-interact.sh

ledger-test:
	@echo "Testing Ledger device compatibility..."
	@./script/test-ledger.sh

ledger-check:
	@echo "Checking Ledger connection..."
	@cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0"

ledger-balance:
	@echo "Checking Ledger balance..."
	@LEDGER_ADDR=$$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null) && \
	echo "Ledger Address: $$LEDGER_ADDR" && \
	echo "ETH Balance:" && \
	cast balance $$LEDGER_ADDR --rpc-url $(RPC_URL)

# Quick Ledger Actions (with confirmation prompts)
ledger-view-state:
	@echo "Viewing contract state with Ledger address..."
	@LEDGER_ADDR=$$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null) && \
	echo "Ledger Address: $$LEDGER_ADDR" && \
	echo "LP Locker: $(LP_LOCKER_ADDRESS)" && \
	echo "LP Token: $(LP_TOKEN_ADDRESS)" && \
	echo "" && \
	echo "Contract LP Balance:" && \
	cast call $(LP_LOCKER_ADDRESS) "getLPBalance()" --rpc-url $(RPC_URL) | cast --to-unit - ether && \
	echo "Your LP Balance:" && \
	cast call $(LP_TOKEN_ADDRESS) "balanceOf(address)" $$LEDGER_ADDR --rpc-url $(RPC_URL) | cast --to-unit - ether && \
	echo "Current Allowance:" && \
	cast call $(LP_TOKEN_ADDRESS) "allowance(address,address)" $$LEDGER_ADDR $(LP_LOCKER_ADDRESS) --rpc-url $(RPC_URL) | cast --to-unit - ether

ledger-approve:
	@echo "Approving LP tokens for Ledger..."
	@read -p "Enter amount to approve (in LP tokens): " amount && \
	AMOUNT_WEI=$$(cast --to-wei $$amount ether) && \
	LEDGER_ADDR=$$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null) && \
	echo "Approving $$amount LP tokens..." && \
	forge script script/LedgerInteraction.s.sol:LedgerInteractionScript \
		--sig "approveLPToken(uint256)" $$AMOUNT_WEI \
		--rpc-url $(RPC_URL) \
		--ledger \
		--sender $$LEDGER_ADDR \
		--broadcast

ledger-lock:
	@echo "Locking LP tokens with Ledger..."
	@read -p "Enter amount to lock (in LP tokens): " amount && \
	AMOUNT_WEI=$$(cast --to-wei $$amount ether) && \
	LEDGER_ADDR=$$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null) && \
	echo "Locking $$amount LP tokens..." && \
	forge script script/LedgerInteraction.s.sol:LedgerInteractionScript \
		--sig "lockLiquidity(uint256)" $$AMOUNT_WEI \
		--rpc-url $(RPC_URL) \
		--ledger \
		--sender $$LEDGER_ADDR \
		--broadcast

ledger-claim:
	@echo "Claiming fees with Ledger..."
	@read -p "Enter Lock ID (0x...): " lock_id && \
	LEDGER_ADDR=$$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null) && \
	echo "Claiming fees for lock: $$lock_id" && \
	forge script script/LedgerInteraction.s.sol:LedgerInteractionScript \
		--sig "claimLPFees(bytes32)" $$lock_id \
		--rpc-url $(RPC_URL) \
		--ledger \
		--sender $$LEDGER_ADDR \
		--broadcast

# Help for Ledger commands
ledger-help:
	@echo "Ledger Hardware Wallet Commands:"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - Ledger device connected and unlocked"
	@echo "  - Ethereum app open on Ledger"
	@echo "  - Contract data enabled in Ethereum app settings"
	@echo ""
	@echo "Interactive Interface:"
	@echo "  make ledger-interact     - Full interactive menu"
	@echo "  make ledger-clef         - Geth + Clef interface (more robust)"
	@echo ""
	@echo "Quick Commands:"
	@echo "  make ledger-check        - Test Ledger connection"
	@echo "  make ledger-balance      - Check Ledger ETH balance"
	@echo "  make ledger-view-state   - View contract state"
	@echo ""
	@echo "Transaction Commands:"
	@echo "  make ledger-approve      - Approve LP tokens"
	@echo "  make ledger-lock         - Lock LP tokens"
	@echo "  make ledger-claim        - Claim fees"
	@echo ""
	@echo "Environment Variables (set in .env):"
	@echo "  LP_LOCKER_ADDRESS        - Deployed contract address"
	@echo "  LP_TOKEN_ADDRESS         - LP token contract address"

ledger-clef:
	@echo "Starting Geth + Clef Ledger Interface..."
	@./script/ledger-clef.sh

ledger-debug:
	@echo "Testing Ledger transaction setup..."
	@LEDGER_ADDR=$$(cast wallet address --ledger --mnemonic-derivation-path "m/44'/60'/0'/0/0" 2>/dev/null) && \
	echo "Ledger Address: $$LEDGER_ADDR" && \
	echo "Testing simple transaction simulation..." && \
	forge script script/LedgerInteraction.s.sol:LedgerInteractionScript \
		--sig "getLPBalance()" \
		--rpc-url $(RPC_URL) \
		--sender $$LEDGER_ADDR \
		-vvv

.PHONY: help anvil deploy-anvil deploy-anvil-update deploy-ledger-anvil deploy-base generate-vanity deploy-create2-anvil deploy-create2-base test test-gas coverage frontend-install frontend frontend-build frontend-preview fmt fmt-check lint-frontend clean dev check-env ledger-interact ledger-test ledger-check ledger-balance ledger-view-state ledger-approve ledger-lock ledger-claim ledger-help ledger-debug 