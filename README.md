# Ferros Vault

> Production-grade ERC-4626 yield vault protocol — upgradeable proxy architecture, two-slope interest rate model, on-chain indexing, and a full-stack DeFi dashboard.

Deployed on **Arbitrum Sepolia** · **Optimism Sepolia**

---

## Overview

Ferros is a modular, permissionless yield vault protocol built on the ERC-4626 tokenized vault standard. The protocol enables yield-bearing positions through a factory-deployed vault architecture with configurable yield rates and a Compound V2-inspired two-slope interest rate model.

---

## Repository Structure

```
ferros-vault/
├── contracts/                  Foundry smart contract project
│   ├── src/
│   │   ├── YieldVault.sol          ERC-4626 core vault
│   │   ├── VaultFactory.sol        ERC-1967 proxy factory
│   │   └── InterestRateModel.sol   Two-slope rate model
│   ├── test/
│   │   ├── YieldVault.t.sol        Unit tests
│   │   ├── YieldVaultFuzz.t.sol    Fuzz invariant tests
│   │   └── Integration.t.sol       Fork integration tests
│   └── script/
│       └── Deploy.s.sol            Multi-chain deployment
├── frontend/                   Next.js 14 dashboard
└── subgraph/                   The Graph indexing layer
```

---

## Smart Contracts

| Contract | Description |
|---|---|
| `YieldVault` | ERC-4626 vault with UUPS upgradeable proxy and time-based yield accrual |
| `VaultFactory` | Deploys ERC-1967 proxy instances of YieldVault for any ERC-20 asset |
| `InterestRateModel` | Stateless two-slope utilization model for borrow and supply rate calculation |

---

## Tech Stack

| Layer | Stack |
|---|---|
| Contracts | Foundry · Solidity 0.8.24 · OpenZeppelin v5 (upgradeable) |
| Testing | Forge unit + fuzz tests · Slither static analysis |
| Indexing | The Graph · AssemblyScript · GraphQL |
| Frontend | Next.js 14 · TypeScript · Tailwind CSS · wagmi v2 · viem · RainbowKit |
| Networks | Arbitrum Sepolia (421614) · Optimism Sepolia (11155420) |

---

## Getting Started

### Prerequisites

- [Node.js v20+](https://nodejs.org/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Install

```bash
git clone git@github.com:obchain/ferros-vault.git
cd ferros-vault/contracts
forge install
forge build
```

### Run Tests

```bash
cd contracts
forge test -vvv
forge coverage
```

### Deploy

```bash
cd contracts
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $ARBITRUM_SEPOLIA_RPC \
  --broadcast \
  --verify
```

---

## Contract Addresses

| Network | Contract | Address |
|---|---|---|
| Arbitrum Sepolia | YieldVault | — |
| Arbitrum Sepolia | VaultFactory | — |
| Arbitrum Sepolia | InterestRateModel | — |
| Optimism Sepolia | YieldVault | — |
| Optimism Sepolia | VaultFactory | — |
| Optimism Sepolia | InterestRateModel | — |

---

## Security

- Slither static analysis run before every deployment
- ERC-4626 inflation attack mitigated via OpenZeppelin virtual shares
- UUPS proxy pattern with `_disableInitializers()` enforced in implementation constructor
- `nonReentrant` guard on all state-mutating vault functions
- Full findings documented in [SECURITY.md](SECURITY.md)

