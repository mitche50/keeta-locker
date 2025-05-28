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
	@echo "$(CYAN)LPLocker Development Commands$(RESET)"
	@echo "=============================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

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

.PHONY: help anvil deploy-anvil deploy-anvil-update deploy-base generate-vanity deploy-create2-anvil deploy-create2-base test test-gas coverage frontend-install frontend frontend-build frontend-preview fmt fmt-check lint-frontend clean dev check-env 