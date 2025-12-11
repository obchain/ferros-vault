"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Navbar } from "@/components/Navbar";
import { StatCard } from "@/components/StatCard";
import { DepositModal } from "@/components/DepositModal";
import { WithdrawModal } from "@/components/WithdrawModal";
import { VaultChart } from "@/components/VaultChart";
import { useVaultData, useUserPosition } from "@/hooks/useVault";

export default function Home() {
  const { isConnected } = useAccount();
  const [showDeposit, setShowDeposit] = useState(false);
  const [showWithdraw, setShowWithdraw] = useState(false);

  const { tvlFormatted, feePct, assetAddress, isLoading: vaultLoading } = useVaultData();
  const { positionFormatted, isLoading: posLoading } = useUserPosition();

  return (
    <>
      <Navbar />

      <main className="main-pad" style={{ maxWidth: 1280, margin: "0 auto", padding: "48px 24px", paddingTop: "calc(56px + 48px)", overflowX: "hidden", width: "100%" }}>

        {/* Header */}
        <div className="fade-in-1" style={{ marginBottom: 48 }}>
          <div style={{ display: "flex", alignItems: "baseline", gap: 16, flexWrap: "wrap" }}>
            <h1 className="font-display glow-amber hero-title" style={{ fontSize: 64, letterSpacing: "0.06em", lineHeight: 1 }}>
              FERROS<span style={{ color: "var(--text-muted)" }}>.</span>VAULT
            </h1>
            <span className="tag tag-amber">ERC-4626</span>
          </div>
          <p className="hero-desc" style={{ marginTop: 12, color: "var(--text-secondary)", fontSize: 14, fontWeight: 400, maxWidth: 480, lineHeight: 1.8 }}>
            Institutional-grade tokenized yield vault on Ethereum Sepolia.
            Deposit USDC, earn yield, withdraw anytime.
          </p>
        </div>

        {/* Stats row */}
        <div className="fade-in-2 stat-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 16, marginBottom: 32 }}>
          <StatCard
            label="Total Value Locked"
            value={`$${tvlFormatted}`}
            sub="USDC deposited"
            accent="amber"
            loading={vaultLoading}
          />
          <StatCard
            label="Performance Fee"
            value={feePct}
            sub="of yield generated"
            accent="cyan"
            loading={vaultLoading}
          />
          <StatCard
            label="Your Position"
            value={isConnected ? `$${positionFormatted}` : "—"}
            sub={isConnected ? "USDC withdrawable" : "Connect wallet"}
            accent="green"
            loading={posLoading && isConnected}
          />
        </div>

        {/* Action buttons */}
        <div className="fade-in-3 action-row" style={{ display: "flex", gap: 12, marginBottom: 48 }}>
          <button
            className="btn-primary"
            style={{ width: "auto", padding: "12px 40px", fontSize: 14 }}
            onClick={() => setShowDeposit(true)}
          >
            DEPOSIT
          </button>
          <button
            className="btn-ghost"
            style={{ padding: "12px 40px", fontSize: 12, letterSpacing: "0.12em" }}
            onClick={() => setShowWithdraw(true)}
          >
            WITHDRAW
          </button>
        </div>

        {/* Chart */}
        <div className="fade-in-4" style={{ marginBottom: 32 }}>
          <VaultChart />
        </div>

        {/* Vault Info */}
        <div className="fade-in-5">
          <div className="info-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: 16 }}>

            <div className="panel-card" style={{ padding: "24px 20px" }}>
              <div style={{ fontSize: 11, letterSpacing: "0.14em", color: "var(--text-muted)", marginBottom: 16, fontWeight: 500 }}>VAULT INFO</div>
              {[
                ["STRATEGY", "MockYieldSource (Testnet)"],
                ["ASSET", "USDC (6 decimals)"],
                ["STANDARD", "ERC-4626 Upgradeable"],
                ["PROXY", "UUPS (ERC-1967)"],
                ["NETWORK", "Ethereum Sepolia"],
              ].map(([k, v]) => (
                <div key={k} style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 4, padding: "9px 0", borderBottom: "1px solid var(--border)", fontSize: 12 }}>
                  <span style={{ color: "var(--text-muted)", fontWeight: 500, letterSpacing: "0.08em" }}>{k}</span>
                  <span style={{ color: "var(--text-primary)", fontWeight: 400 }}>{v}</span>
                </div>
              ))}
            </div>

            <div className="panel-card" style={{ padding: "24px 20px" }}>
              <div style={{ fontSize: 11, letterSpacing: "0.14em", color: "var(--text-muted)", marginBottom: 16, fontWeight: 500 }}>HOW IT WORKS</div>
              {[
                ["01", "Deposit USDC into the vault"],
                ["02", "Receive vault shares (vUSDC)"],
                ["03", "Strategy accrues yield over time"],
                ["04", "Shares appreciate in value vs USDC"],
                ["05", "Withdraw shares → receive USDC + yield"],
              ].map(([n, text]) => (
                <div key={n} style={{ display: "flex", gap: 16, padding: "9px 0", borderBottom: "1px solid var(--border)", fontSize: 13 }}>
                  <span className="font-display" style={{ color: "var(--amber)", fontSize: 15, minWidth: 24, flexShrink: 0 }}>{n}</span>
                  <span style={{ color: "var(--text-primary)", fontWeight: 400 }}>{text}</span>
                </div>
              ))}
            </div>

          </div>
        </div>

      </main>

      <footer style={{ borderTop: "1px solid var(--border)", padding: "20px 16px", textAlign: "center", color: "var(--text-secondary)", fontSize: 12, fontWeight: 400 }}>
        <span style={{ fontFamily: "var(--font-mono)" }}>FERROS VAULT · SEPOLIA TESTNET · NOT FOR PRODUCTION USE</span>
      </footer>

      {showDeposit && <DepositModal assetAddress={assetAddress} onClose={() => setShowDeposit(false)} />}
      {showWithdraw && <WithdrawModal onClose={() => setShowWithdraw(false)} />}
    </>
  );
}
