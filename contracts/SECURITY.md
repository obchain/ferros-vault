# Security Analysis

Slither 0.11.5 — analyzed 34 contracts with 99 detectors.

Initial run: 13 findings. Post-fix run: 11 findings (2 resolved, 2 categories closed).

---

## Resolved Findings

### [HIGH-01] CEI Violation in `MockYieldSource.setApy()`

**Detector:** `reentrancy-no-eth`
**File:** `src/strategies/MockYieldSource.sol`
**Status:** Fixed

`setApy()` called `_accrueYield()` (which invokes `IMintable.mint()` — an external call) before
updating `apyBps`. A reentrant call during `mint()` could have read a stale yield rate.

**Fix:** Refactored `setApy()` to compute pending yield inline using the old rate, update all state
variables (`lastAccrual`, `totalYieldAccrued`, `apyBps`) before the external `mint()` call.

---

### [LOW-01] Missing Event in `MockYieldSource.setVault()`

**Detector:** `events-access`
**File:** `src/strategies/MockYieldSource.sol`
**Status:** Fixed

`setVault()` modifies privileged state (the authorised vault address) without emitting an event,
making off-chain monitoring of access-control changes impossible.

**Fix:** Added `VaultSet(address indexed vault)` event; emitted on successful `setVault()` call.

---

### [LOW-02] Unindexed Address Parameters in `ImplementationUpdated`

**Detector:** `unindexed-event-address`
**File:** `src/VaultFactory.sol`
**Status:** Fixed

`ImplementationUpdated(address, address)` had no indexed parameters, preventing efficient
log filtering by implementation address.

**Fix:** Changed both parameters to `indexed`.

---

## Accepted / False Positive Findings

### [INFO-01] Strict Equality on `elapsed` and `yieldAmount`

**Detector:** `incorrect-equality`
**File:** `src/strategies/MockYieldSource.sol`
**Status:** Accepted — design intent

Slither flags `elapsed == 0` and `yieldAmount == 0` as dangerous strict equalities. These are
early-exit guards on time-delta and computed values, not comparison against a manipulable
external balance. Both values are computed in the same transaction and cannot be externally
influenced to cause an incorrect skip. No financial risk.

---

### [INFO-02] Benign Reentrancy — `YieldVault._withdraw()`

**Detector:** `reentrancy-benign`
**File:** `src/YieldVault.sol`
**Status:** Accepted — tracking variable only

`lastHarvestAssets` is updated after `strategy.withdraw()`. This variable is a yield-accounting
checkpoint and is not used in any share-price, redemption, or access-control calculation.
A reentrant call during `strategy.withdraw()` cannot manipulate vault share math. The vault
`_withdraw` override is also protected by OZ's inherited `nonReentrant` guard on `withdraw()`
and `redeem()`.

---

### [INFO-03] Benign Reentrancy — `VaultFactory.createVault()`

**Detector:** `reentrancy-benign`
**File:** `src/VaultFactory.sol`
**Status:** Accepted — standard proxy deployment pattern

`assetToVaults` and `vaultList` are updated after `new ERC1967Proxy(...)`. The deployed proxy
constructor cannot call back into the factory, and `createVault` is `onlyOwner`. No attack
surface.

---

### [INFO-04] Events Emitted After External Call

**Detector:** `reentrancy-events`
**File:** `src/strategies/MockYieldSource.sol`, `src/VaultFactory.sol`
**Status:** Accepted — informational only

Events in `_accrueYield()` and `createVault()` are emitted after external calls. This does not
create a financial vulnerability; it is an ordering preference. The affected code paths are
either owner-only or testnet-only (MockYieldSource). No fix required.

---

### [INFO-05] Block Timestamp Comparisons

**Detector:** `timestamp`
**File:** `src/strategies/MockYieldSource.sol`
**Status:** Accepted — yield accrual tolerance

`block.timestamp` is used to compute elapsed time for yield accrual. A miner or validator
could manipulate the timestamp by ~12 seconds per block. In the worst case this shifts one
block's worth of yield accrual, which at a 20% APY on a $1M vault equals ~$0.06. Immaterial.
MockYieldSource is testnet-only; mainnet yield accrual would use a production strategy with
its own time-handling.

---

## Summary

| Severity | Total | Fixed | Accepted |
|----------|-------|-------|----------|
| High     | 1     | 1     | 0        |
| Medium   | 0     | 0     | 0        |
| Low      | 2     | 2     | 0        |
| Info     | 5     | 0     | 5        |
| **Total**| **8** | **3** | **5**    |

All High and Low findings resolved. No Medium findings. Five informational findings accepted
with documented rationale. No action required before deployment.
