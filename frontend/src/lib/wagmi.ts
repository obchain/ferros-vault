import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "Ferros Vault",
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ?? "demo",
  chains: [sepolia],
  ssr: true,
});

export const VAULT_ADDRESS = (process.env.NEXT_PUBLIC_VAULT_ADDRESS ?? "0xA079817DA19E6b3C741DB521F96Ce135A46d9C18") as `0x${string}`;
export const FACTORY_ADDRESS = (process.env.NEXT_PUBLIC_FACTORY_ADDRESS ?? "0x01BbE74E7e8bC7545Db661a97948889F488f798D") as `0x${string}`;
