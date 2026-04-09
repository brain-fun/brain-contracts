# brain.fun — Smart Contracts

Token launchpad on Bittensor EVM. Create, trade, and discover tokens with a built-in bonding curve AMM.

**Live at [brain.fun](https://brain.fun)** | **Follow [@braintao](https://x.com/braintao)**

---

## Overview

brain.fun lets anyone launch a token in seconds on the Bittensor network. Each token comes with its own embedded AMM — no external DEX needed. Liquidity is bootstrapped through a virtual reserve bonding curve, meaning tokens are tradable from block one.

### How it works

1. **Deploy** — Pick a name, symbol, and image. One transaction creates your token with a bonding curve.
2. **Trade** — Buy and sell directly against the contract. Price follows `x * y = k` with a virtual TAO reserve.
3. **Earn** — Token creators earn 0.5% of every trade. Fees accumulate in the Factory and can be claimed anytime.

### Key properties

- **Fair launch** — No pre-mine, no team allocation. 100% of supply starts in the bonding curve.
- **No rug pulls** — Liquidity lives inside the contract itself. There's no LP to remove.
- **Instant liquidity** — Every token is tradable immediately. The bonding curve provides liquidity at every price point.
- **Creator incentives** — Deployers earn ongoing revenue from trading activity on their token.

---

## Contracts

### BrainFactory

The factory deploys new Token contracts and manages the creator fee pool.

| Function | Description |
|----------|-------------|
| `createToken(name, symbol, metadata)` | Deploy a new token. Send TAO to make an initial buy in the same tx (frontrun-protected). |
| `claimCreatorFees()` | Withdraw accumulated creator earnings. |
| `getFees()` | Returns current fee rates. |
| `setFees(total, deployer)` | Admin: update fee split (max 10%). |
| `setVirtualReserve(amount)` | Admin: set virtual reserve for new tokens. |

### Token

Each token is a standalone ERC-20 with an embedded constant-product AMM.

| Function | Description |
|----------|-------------|
| `buy(minTokensOut, deadline)` | Buy tokens with TAO. |
| `sell(tokenAmount, minTaoOut, deadline)` | Sell tokens for TAO. |
| `getPrice()` | Current spot price in TAO. |
| `getAmountOut(taoIn)` | Estimate tokens received for a given TAO input. |
| `getTaoOut(tokenAmount)` | Estimate TAO received for selling tokens. |
| `getTokenInfo()` | All token state in a single call. |

Standard ERC-20: `transfer`, `approve`, `transferFrom`, `balanceOf`, `allowance`, `increaseAllowance`, `decreaseAllowance`.

---

## Parameters

| Parameter | Value |
|-----------|-------|
| Total supply | 1,000,000,000 (18 decimals) |
| Virtual reserve | 10 TAO |
| Starting price | ~0.00000001 TAO |
| Trading fee | 1% (0.5% creator + 0.5% protocol) |
| Max fee cap | 10% |

---

## AMM Design

The bonding curve uses a constant-product formula with a virtual reserve:

```
effectiveTao = virtualReserve + realReserve
k = effectiveTao * tokenReserve
```

- **Virtual reserve** provides initial liquidity without requiring upfront capital.
- **Rounding is always against the trader** — the pool's `k` value never decreases, preventing value extraction through dust trades.
- **Sell cap** — If a sell would exceed available TAO, the output is capped and reserves are recalculated to maintain the invariant.

---

## Security

- **ReentrancyGuard** on all state-changing functions (buy, sell, claim).
- **Slippage protection** via `minTokensOut` / `minTaoOut` parameters.
- **Deadline parameter** to prevent stale transactions.
- **Transfer guards** — Cannot transfer tokens to `address(0)` or to the token contract itself.
- **Balance validation** before every sell.
- **Pull pattern** for creator fees — fees accumulate in the Factory and are claimed explicitly, avoiding push-based reentrancy vectors.
- **Fee precision** — Single-step fee calculation to avoid compounding rounding errors.

---

## Deployment

### Mainnet (Bittensor EVM — Chain 964)

| Contract | Address |
|----------|---------|
| BrainFactory | [`0xBa270A620cafAA69a97AbcC4d83C850297ca05B2`](https://evm.taostats.io/address/0xBa270A620cafAA69a97AbcC4d83C850297ca05B2) |

Both contracts are verified on the block explorer.

### Build & deploy

```bash
npm install
npx hardhat compile

# Deploy factory
PRIVATE_KEY=0x... npx hardhat run scripts/deploy-factory-only.js --network bittensorMainnet

# Verify
PRIVATE_KEY=0x... npx hardhat verify --network bittensorMainnet <FACTORY_ADDRESS>
```

### Configuration

```
Solidity: 0.8.24
EVM: cancun
Optimizer: 200 runs
viaIR: true
```

---

## License

MIT

---

[brain.fun](https://brain.fun) · [@braintao](https://x.com/braintao)
