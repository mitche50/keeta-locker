# LPLocker: Secure 90-Day Withdrawal Window for Aerodrome LPs & Extensible Rewards

## Overview
LPLocker is a robust, production-ready smart contract system for securely locking Aerodrome LP tokens with a 90-day withdrawal window, claiming protocol fees, and managing extensible reward sources (e.g., gauges, bribes). It is designed for DAOs, treasuries, and protocols seeking transparent, auditable, and automated liquidity management on EVM chains.

## Features
- **90-Day Withdrawal Window:** Lock LP tokens, then trigger a 90-day window during which withdrawals are allowed.
- **Aerodrome LP Compatibility:** Native support for Aerodrome V2 LPs, including fee claiming via `claimFees()` and reporting claimable rewards.
- **Extensible Rewards:** Register and manage multiple reward sources (e.g., gauges, bribes) via a generic interface.
- **Customizable Fee Receiver:** Direct all claimed fees to a designated address.
- **Comprehensive View Functions:** Monitor lock state, balances, unlock times, and all claimable rewards.
- **Security:** Uses OpenZeppelin SafeERC20, strict access control, and robust error handling.
- **Full Test Coverage:** Thorough Foundry test suite with fuzzing and edge case coverage.

## Contract Structure
- `src/LPLocker.sol`: Main LPLocker contract
- `src/interfaces/IAerodromePool.sol`: Aerodrome LP interface (matches [Aerodrome V2 spec](https://basescan.org/address/0xd9eDC75a3a797Ec92Ca370F19051BAbebfb2edEe#code))
- `src/interfaces/ILPLocker.sol`: LPLocker interface, events, and errors
- `test/`: Foundry test suite and mocks

## Aerodrome Integration
- **Interface:** LPLocker uses the exact Aerodrome V2 LP interface for fee claiming and reporting.
- **Validation:** (Optional) You may add a check to ensure the LP is a real Aerodrome pool by verifying the `factory()` address.
- **Mock:** `MockAerodromeLP` simulates all relevant Aerodrome behaviors for testing.

## Usage
### Build
```sh
forge build
```
### Test (with coverage)
```sh
forge test
forge coverage --report lcov && genhtml lcov.info --output-directory coverage && open coverage/index.html
```
### Format
```sh
forge fmt
```

## How It Works
- **Locking:** Only the owner can lock LP tokens. Once locked, tokens are held until the owner triggers the withdrawal window.
- **Withdrawal:** The owner can trigger a 90-day withdrawal window at any time. During this window, partial or full withdrawal is allowed.
- **Fee Claiming:** Owner can claim Aerodrome LP fees at any time while locked. Claimed tokens are sent to the fee receiver.
- **Reward Sources:** Owner can add/remove arbitrary reward sources implementing the `IRewardSource` interface. All claimable rewards can be queried and claimed in batch.

## Security Notes
- Uses OpenZeppelin SafeERC20 for all transfers.
- All state-changing functions are owner-only.
- (Optional) Add Aerodrome LP validation for extra safety.
- Full test suite with fuzzing and edge case coverage.

## Contributing & Testing
- Fork and clone the repo
- Install Foundry: https://book.getfoundry.sh/getting-started/installation
- Run tests: `forge test`
- Check coverage: `forge coverage --report lcov && genhtml lcov.info --output-directory coverage && open coverage/index.html`
- PRs and issues welcome!

## License
MIT
