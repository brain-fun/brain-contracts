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

## Versions

brain.fun ships in two factory versions running side-by-side on mainnet:

| Version | Status | Notes |
|---------|--------|-------|
| **V1** | Legacy | Original factory. Existing tokens stay here and remain fully tradable + claimable. |
| **V2** | Current | Audit-hardened release. All new launches go through V2. |

V2 is a strict security upgrade — same AMM, same parameters, no migration required for existing tokens. See [Audit Fixes](#audit-fixes) for the full delta.

---

## Contracts

### BrainFactory

The factory deploys new Token contracts and manages the creator + protocol fee pools.

| Function | Description |
|----------|-------------|
| `createToken(name, symbol, metadata)` | Deploy a new token. Send TAO to make an initial buy in the same tx (frontrun-protected). |
| `claimCreatorFees()` | Withdraw accumulated creator earnings (pull pattern). |
| `claimProtocolFees()` | Owner-only: withdraw accumulated protocol fees (pull pattern, V2). |
| `depositProtocolFee()` | Internal hook called by Token contracts to credit protocol fees (V2). |
| `getFees()` | Returns the immutable fee rates. |

Fees and virtual reserve are `immutable` in V2 — there are no `setFees` or `setVirtualReserve` setters.

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
- **Sell cap** — If a sell would exceed available TAO, the output is capped while the token reserve is preserved (V2 fix for H-01).

---

## Security

- **ReentrancyGuard** on every state-changing entry point — `buy`, `sell`, `createToken`, `claimCreatorFees`, `claimProtocolFees`, `rescueTAO`.
- **Slippage protection** via `minTokensOut` / `minTaoOut` parameters.
- **Deadline parameter** to prevent stale transactions.
- **Transfer guards** — Cannot transfer tokens to `address(0)` or to the token contract itself.
- **Balance validation** before every sell.
- **Pull pattern** for both creator and protocol fees — fees accumulate in the Factory and are claimed explicitly, avoiding push-based reentrancy and gas-griefing vectors.
- **Existential Deposit guard** — Claim functions cap withdrawals to the actual factory balance, surviving Bittensor EVM's ED quirks ([subtensor #1352](https://github.com/opentensor/subtensor/issues/1352)).
- **Immutable economics** — Fee rates and virtual reserve are `immutable`, removing every admin lever over live token economics.
- **Fee precision** — Single-step fee calculation to avoid compounding rounding errors.

### Audit Fixes (V1 → V2)

V2 addresses every finding from the security audit:

| ID | Severity | Fix |
|----|----------|-----|
| H-01 | High | Sell cap path no longer recalculates `newTokenReserve`, eliminating phantom token inflation. |
| H-02 | High | Protocol fees switched to pull pattern via `depositProtocolFee` / `claimProtocolFees`, removing the push-path DoS vector. |
| M-01 | Medium | Fee rates made `immutable` — no owner can change fees mid-flight. |
| M-03 | Medium | Existential Deposit guard added to all claim paths. |
| L-02, L-04 | Low | `nonReentrant` extended to `createToken`, `claim*`, and `rescueTAO`. |
| L-05, L-07 | Low | `virtualReserve`, `totalFeeRate`, `deployerFeeRate` declared `immutable`. |

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
