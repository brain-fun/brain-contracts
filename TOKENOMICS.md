# BRAIN Tokenomics

## Overview

BRAIN is a token launched on brain.fun, the native token launchpad on Bittensor EVM (Chain 964). It uses a bonding curve AMM for price discovery and trading.

## Token Details

| Parameter | Value |
|-----------|-------|
| Name | Brain |
| Symbol | BRAIN |
| Chain | Bittensor EVM (Chain 964) |
| Contract | [0xB24495CEFaeB233d7943F3E74819BbA7D462e0B3](https://evm.taostats.io/token/0xB24495CEFaeB233d7943F3E74819BbA7D462e0B3) |
| Total Supply | 1,000,000,000 BRAIN |
| Decimals | 18 |

## Distribution

BRAIN has a fair launch model with no pre-allocation, no team tokens, and no vesting schedule.

- **100% of supply** starts in the bonding curve pool
- Tokens are distributed solely through open market purchases
- No private sale, no seed round, no VC allocation
- No airdrop or free distribution
- Creator earns 0.5% of every trade as an ongoing fee

## Supply Breakdown

| Allocation | Amount | Percentage |
|------------|--------|------------|
| Bonding Curve Pool | Dynamic | Remaining supply available for purchase |
| Circulating (purchased by traders) | Dynamic | Tokens bought from the bonding curve |
| Pre-mine / Team | 0 | 0% |
| Investor / VC | 0 | 0% |
| Airdrop | 0 | 0% |

## Bonding Curve Mechanism

The token uses a constant product AMM (x * y = k) with a virtual reserve:

- **Virtual Reserve:** 10 TAO (provides initial liquidity without upfront capital)
- **Starting Price:** ~0.00000001 TAO per BRAIN
- Price increases with every buy, decreases with every sell
- All liquidity is embedded in the contract — no external LP, no removable liquidity
- Liquidity is permanently locked by design

## Fee Structure

A 1% fee is applied on every trade (buy and sell):

| Fee | Rate | Recipient |
|-----|------|-----------|
| Creator Fee | 0.5% | Token creator (claimable from factory contract) |
| Protocol Fee | 0.5% | brain.fun protocol |

## Contract Verification

- Factory: [0xBa270A620cafAA69a97AbcC4d83C850297ca05B2](https://evm.taostats.io/address/0xBa270A620cafAA69a97AbcC4d83C850297ca05B2#code) (verified)
- Token: [0xB24495CEFaeB233d7943F3E74819BbA7D462e0B3](https://evm.taostats.io/address/0xB24495CEFaeB233d7943F3E74819BbA7D462e0B3#code) (verified)

## Links

- Website: [brain.fun](https://brain.fun)
- Twitter: [@braintao](https://x.com/braintao)
- GitHub: [github.com/brain-fun](https://github.com/brain-fun)
