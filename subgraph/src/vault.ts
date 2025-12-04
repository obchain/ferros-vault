import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent,
  Harvested,
} from "../generated/templates/YieldVault/YieldVault"
import {
  Vault,
  Deposit,
  Withdraw,
  YieldAccrual,
  User,
  VaultDailySnapshot,
} from "../generated/schema"
import { BigInt, BigDecimal } from "@graphprotocol/graph-ts"

const ZERO_BI = BigInt.fromI32(0)
const ZERO_BD = BigDecimal.fromString("0")
const ONE_BI = BigInt.fromI32(1)

function getOrCreateUser(address: string): User {
  let user = User.load(address)
  if (!user) {
    user = new User(address)
    user.totalDeposited = ZERO_BI
    user.totalWithdrawn = ZERO_BI
    user.save()
  }
  return user as User
}

function updateDailySnapshot(vault: Vault, timestamp: BigInt, apy: BigDecimal): void {
  let dayId = timestamp.div(BigInt.fromI32(86400))
  let id = vault.id + "-" + dayId.toString()

  let snapshot = VaultDailySnapshot.load(id)
  if (!snapshot) {
    snapshot = new VaultDailySnapshot(id)
    snapshot.vault = vault.id
  }

  snapshot.totalAssets = vault.totalAssets
  snapshot.totalShares = vault.totalShares
  snapshot.apy = apy
  snapshot.timestamp = timestamp
  snapshot.save()
}

export function handleDeposit(event: DepositEvent): void {
  let vaultId = event.address.toHexString()
  let vault = Vault.load(vaultId)
  if (!vault) return

  let user = getOrCreateUser(event.params.owner.toHexString())
  user.totalDeposited = user.totalDeposited.plus(event.params.assets)
  user.save()

  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let deposit = new Deposit(id)
  deposit.vault = vaultId
  deposit.user = user.id
  deposit.assets = event.params.assets
  deposit.shares = event.params.shares
  deposit.timestamp = event.block.timestamp
  deposit.txHash = event.transaction.hash
  deposit.save()

  vault.totalAssets = vault.totalAssets.plus(event.params.assets)
  vault.totalShares = vault.totalShares.plus(event.params.shares)
  vault.txCount = vault.txCount.plus(ONE_BI)
  vault.save()

  updateDailySnapshot(vault as Vault, event.block.timestamp, ZERO_BD)
}

export function handleWithdraw(event: WithdrawEvent): void {
  let vaultId = event.address.toHexString()
  let vault = Vault.load(vaultId)
  if (!vault) return

  let user = getOrCreateUser(event.params.owner.toHexString())
  user.totalWithdrawn = user.totalWithdrawn.plus(event.params.assets)
  user.save()

  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let withdraw = new Withdraw(id)
  withdraw.vault = vaultId
  withdraw.user = user.id
  withdraw.assets = event.params.assets
  withdraw.shares = event.params.shares
  withdraw.timestamp = event.block.timestamp
  withdraw.txHash = event.transaction.hash
  withdraw.save()

  vault.totalAssets = vault.totalAssets.minus(event.params.assets)
  vault.totalShares = vault.totalShares.minus(event.params.shares)
  vault.txCount = vault.txCount.plus(ONE_BI)
  vault.save()

  updateDailySnapshot(vault as Vault, event.block.timestamp, ZERO_BD)
}

export function handleHarvested(event: Harvested): void {
  let vaultId = event.address.toHexString()
  let vault = Vault.load(vaultId)
  if (!vault) return

  // Annualised APY = (gain / totalAssets) * 100 * (SECONDS_PER_YEAR / elapsed)
  // Without elapsed time in the event, report gain ratio * 100 as a lower bound.
  // Full rolling APY requires lastHarvestTimestamp — stored in a future schema upgrade.
  let apy = ZERO_BD
  if (vault.totalAssets.gt(ZERO_BI) && event.params.gain.gt(ZERO_BI)) {
    let gain = event.params.gain.toBigDecimal()
    let total = vault.totalAssets.toBigDecimal()
    let SECONDS_PER_YEAR = BigDecimal.fromString("31536000")
    // Use block timestamp delta from snapshot for approximate elapsed
    let dayId = event.block.timestamp.div(BigInt.fromI32(86400))
    let prevId = vault.id + "-" + dayId.minus(ONE_BI).toString()
    let prevSnapshot = VaultDailySnapshot.load(prevId)
    let elapsed = prevSnapshot
      ? event.block.timestamp.minus(prevSnapshot.timestamp).toBigDecimal()
      : BigDecimal.fromString("86400")
    if (elapsed.gt(ZERO_BD)) {
      apy = gain.div(total).times(SECONDS_PER_YEAR).div(elapsed).times(BigDecimal.fromString("100"))
    }
  }

  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let accrual = new YieldAccrual(id)
  accrual.vault = vaultId
  accrual.gain = event.params.gain
  accrual.feeShares = event.params.feeShares
  accrual.apy = apy
  accrual.timestamp = event.block.timestamp
  accrual.txHash = event.transaction.hash
  accrual.save()

  vault.totalAssets = vault.totalAssets.plus(event.params.gain)
  vault.totalShares = vault.totalShares.plus(event.params.feeShares)
  vault.txCount = vault.txCount.plus(ONE_BI)
  vault.save()

  updateDailySnapshot(vault as Vault, event.block.timestamp, apy)
}
