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
- **Immutable economics** — Fee rates and virtual reserve are set at deploy time and cannot be changed. No admin levers over live tokens.

---

## Contracts

### BrainFactory

The factory deploys new Token contracts and manages the creator + protocol fee pools.

| Function | Description |
|----------|-------------|
| `createToken(name, symbol, metadata)` | Deploy a new token. Send TAO to make an initial buy in the same tx (frontrun-protected). |
| `claimCreatorFees()` | Withdraw accumulated creator earnings (pull pattern). |
| `claimProtocolFees()` | Owner-only: withdraw accumulated protocol fees (pull pattern). |
| `getFees()` | Returns the immutable fee rates. |

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
| Virtual reserve | 10 TAO (immutable) |
| Starting price | ~0.00000001 TAO |
| Trading fee | 1% (0.5% creator + 0.5% protocol, immutable) |

---

## AMM Design

The bonding curve uses a constant-product formula with a virtual reserve:

```
effectiveTao = virtualReserve + realReserve
k = effectiveTao * tokenReserve
```

- **Virtual reserve** provides initial liquidity without requiring upfront capital.
- **Rounding is always against the trader** — the pool's `k` value never decreases, preventing value extraction through dust trades.
- **Sell cap** — If a sell would exceed available TAO, the output is capped while the token reserve is preserved.

---

## Security

- **ReentrancyGuard** on every state-changing entry point — `buy`, `sell`, `createToken`, `claimCreatorFees`, `claimProtocolFees`, `rescueTAO`.
- **Slippage protection** via `minTokensOut` / `minTaoOut` parameters.
- **Deadline parameter** to prevent stale transactions.
- **Transfer guards** — Cannot transfer tokens to `address(0)` or to the token contract itself.
- **Balance validation** before every sell.
- **Pull pattern** for both creator and protocol fees — fees accumulate in the Factory and are claimed explicitly, avoiding push-based reentrancy and gas-griefing vectors.
- **Immutable economics** — Fee rates and virtual reserve are `immutable`, removing every admin lever over live token economics.
- **Fee precision** — Single-step fee calculation to avoid compounding rounding errors.

---

## Deployments

Mainnet — Bittensor EVM (Chain 964):

| Version | Contract | Address |
|---------|----------|---------|
| V2 (current) | BrainFactory | [`0x3EDFEdaFa3dAd70a3F72EdB8be8e818d1922E04c`](https://evm.taostats.io/address/0x3EDFEdaFa3dAd70a3F72EdB8be8e818d1922E04c) |
| V1 (legacy) | BrainFactory | [`0xBa270A620cafAA69a97AbcC4d83C850297ca05B2`](https://evm.taostats.io/address/0xBa270A620cafAA69a97AbcC4d83C850297ca05B2) |

Both factories are verified on the block explorer. New launches go through V2; V1 tokens remain fully tradable and claimable.

---

## License

MIT

---

[brain.fun](https://brain.fun) · [@braintao](https://x.com/braintao)
