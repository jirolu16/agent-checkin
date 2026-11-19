# Agent Check-In

**The daily check-in dApp for Agent ID holders on BNB Chain.**

Agent Check-In gives every Binance Agentic Wallet **Agent ID** a daily ritual: check in once a day, build a streak, earn points, unlock soulbound badges, and climb the leaderboard. Think of it as a heartbeat for the agent economy: a simple, verifiable, on-chain proof that an agent's owner shows up every day.

Built for the **Binance Wallet Agent ID Hackathon** (BNB Chain).

## How Agent ID is used

Agent ID is the gate and the identity of the whole product:

- The contract reads the official SPACE ID "AI" Agent ID registry on BNB Chain mainnet, `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`, and only addresses holding an Agent ID (`balanceOf > 0`) can check in.
- All state (streaks, points, badges, referrals) is keyed to the Agent ID holding address. No other sign-up exists: your Agent ID is your account.
- Badges are soulbound ERC-721 tokens minted by the check-in contract itself, so an agent's consistency record travels with the wallet that holds its Agent ID.

## Features

- **Daily check-in**: one check-in per UTC day per Agent ID holder.
- **Streaks and points**: 10 points per check-in plus a streak bonus (up to +20). Missing a day resets the streak; your best streak is kept forever.
- **Soulbound streak badges** (ERC-721, non-transferable):
  - Bronze: 7-day streak, +10% points on future check-ins
  - Silver: 30-day streak, +25%
  - Gold: 100-day streak, +50%
  - Diamond: 365-day streak, +100%
- **Referrals**: bind a referrer at your first check-in and they earn 10% of your check-in points. Hard cap: 5 referrals per referrer.
- **Leaderboard**: top agents by points, readable fully on chain.
- **Safety by design**: the contract holds no funds, has no owner and no admin functions, and never moves anyone's assets. Points are a leaderboard score only, not a token, and badges carry no promise of value.

## Contracts

| Network | Contract | Address |
| --- | --- | --- |
| BSC Testnet | AgentCheckInV3 | `0xFFc297C92c70D344a1A88Dc1bADcF1290326f311` |
| BSC Testnet | MockAgentID (testnet demo gate) | `0xc176D6f36Bd0055073Eb08EC1683485D71D8bE7E` |
| BNB Mainnet | AgentCheckInV3 | `0xc176D6f36Bd0055073Eb08EC1683485D71D8bE7E` |

On testnet the real Agent ID registry is not deployed, so the testnet build gates on a clearly labelled mock registry with the same `balanceOf` interface. The mainnet build points at the real registry address above. Contract sources are verified on Sourcify with an exact match.

## Run it

Open the live page and connect the wallet that holds your Agent ID on BNB Chain mainnet, then check in. A full testnet demo (mock Agent ID mint, check-ins, badges, referrals, all with testnet funds only) is available by adding `#testnet` to the page URL.

## Tech

- Solidity 0.8.26, single-file contract, no dependencies
- Vanilla JS + ethers.js frontend, one static HTML file
- Tests: local EVM simulation of streaks, badge minting, boost math, and referral rules

## License

MIT
