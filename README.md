# CryptoVentures DAO

A comprehensive governance system for a decentralized investment fund.

## Core Components

- **CVGToken**: Staking-based governance token (1 ETH = 1000 CVG).
- **CVGTreasury**: Multi-category fund management.
- **CVGTimelock**: Time-delayed execution security.
- **CVGDAO**: Core governance logic with quadratic-style weighted voting.

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Compile contracts:**
   ```bash
   npx hardhat compile
   ```

3. **Run tests:**
   ```bash
   npx hardhat test
   ```

4. **Deploy (Local):**
   ```bash
   npx hardhat run scripts/deploy.js
   ```

## Proposal Types

| Type | Quorum | Threshold | Voting Period | Timelock |
|------|--------|-----------|---------------|----------|
| High Conviction | 20% | 60% | 7 Days | 3 Days |
| Experimental | 10% | 50% | 3 Days | 1 Day |
| Operational | 5% | 50% | 1 Day | 0 Days |

## Roles

- **Proposer**: Can create new proposals (requires 1000 CVG stake).
- **Executor**: Can trigger execution of approved and queued proposals.
- **Guardian**: Can cancel proposals in emergency.
- **Voter**: Any CVG holder.
