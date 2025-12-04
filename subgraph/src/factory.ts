import { VaultCreated } from "../generated/VaultFactory/VaultFactory"
import { YieldVault } from "../generated/templates"
import { Vault } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"

export function handleVaultCreated(event: VaultCreated): void {
  let id = event.params.vault.toHexString()

  let vault = new Vault(id)
  vault.asset = event.params.asset
  vault.name = ""
  vault.symbol = ""
  vault.totalAssets = BigInt.fromI32(0)
  vault.totalShares = BigInt.fromI32(0)
  vault.performanceFeeBps = BigInt.fromI32(1000)
  vault.createdAt = event.block.timestamp
  vault.txCount = BigInt.fromI32(0)
  vault.save()

  YieldVault.create(event.params.vault)
}
