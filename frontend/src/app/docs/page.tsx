"use client";

import { useState } from "react";
import { Navbar } from "@/components/Navbar";

const SECTIONS = [
  "OVERVIEW",
  "ARCHITECTURE",
  "CONTRACTS",
  "INTERFACE",
  "DEPOSIT & WITHDRAW",
  "YIELD STRATEGY",
  "SECURITY",
  "FAQ",
] as const;

type Section = typeof SECTIONS[number];

const CONTRACTS = [
  { name: "YieldVault", address: "0xA079817DA19E6b3C741DB521F96Ce135A46d9C18", note: "Main ERC-4626 vault (UUPS proxy)" },
  { name: "VaultFactory", address: "0x01BbE74E7e8bC7545Db661a97948889F488f798D", note: "Deploys new vault instances" },
  { name: "YieldVaultImpl", address: "0xe67FDE4F596639e021B4F1Da3Da43621285537a5", note: "Implementation contract" },
  { name: "MockYieldSource", address: "0x31d93658903E604416F1E8DD6280C0E191236036", note: "Testnet yield strategy (10% APY)" },
  { name: "MockERC20 (USDC)", address: "0x38C3096d7BFeb3F951CBCeE474aC31b61F2dF744", note: "6-decimal test token" },
];

const INTERFACE_ROWS = [
  ["deposit(uint256 assets, address receiver)", "uint256 shares", "Deposit assets, receive shares"],
  ["withdraw(uint256 assets, address receiver, address owner)", "uint256 shares", "Withdraw assets, burn shares"],
  ["redeem(uint256 shares, address receiver, address owner)", "uint256 assets", "Redeem shares for assets"],
  ["totalAssets()", "uint256", "Total assets managed by vault"],
  ["convertToShares(uint256 assets)", "uint256", "Preview shares for asset amount"],
  ["convertToAssets(uint256 shares)", "uint256", "Preview assets for share amount"],
  ["maxDeposit(address)", "uint256", "Max depositable for address"],
  ["maxWithdraw(address)", "uint256", "Max withdrawable for address"],
  ["balanceOf(address)", "uint256", "Share balance of address"],
  ["performanceFeeBps()", "uint256", "Performance fee in basis points"],
];

const FAQ_ROWS = [
  ["What is ERC-4626?", "A tokenized vault standard. Deposits yield fungible shares. Share price rises as yield accrues — no rebasing needed."],
  ["Is this production-ready?", "No. This is a testnet deployment on Ethereum Sepolia using a mock yield source. Do not deposit real funds."],
  ["How is yield generated?", "The MockYieldSource mints tokens to simulate 10% APY. On mainnet this would be replaced by a real strategy (Aave, Compound, etc.)."],
  ["What is the performance fee?", "A configurable % taken from accrued yield. Controlled by the vault owner. Default 10%."],
  ["Can the vault be upgraded?", "Yes. It uses UUPS (ERC-1967) proxy pattern. Only the owner can authorize upgrades via _authorizeUpgrade(). For production, this should be guarded by a multisig and timelock."],
  ["How are shares priced?", "sharePrice = totalAssets / totalSupply. As yield accrues, totalAssets grows while totalSupply stays flat — shares appreciate."],
  ["Is there a pause or emergency stop?", "No. This testnet version does not implement Pausable. A production vault should expose a guardian-controlled pause() to halt deposits and withdrawals during an incident."],
  ["What happens with non-stable assets?", "This vault only supports USDC (stable). Volatile asset strategies would require Chainlink Price Feeds to accurately compute totalAssets() and prevent price manipulation attacks."],
];

function CodeBlock({ children }: { children: string }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    navigator.clipboard.writeText(children);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <div style={{ position: "relative", marginTop: 12, marginBottom: 12 }}>
      <pre style={{
        background: "var(--bg-base)", border: "1px solid var(--border)",
        padding: "14px 16px", fontSize: 12, color: "var(--cyan)",
        overflowX: "auto", lineHeight: 1.7, fontFamily: "var(--font-mono, monospace)",
      }}>{children}</pre>
      <button
        onClick={copy}
        style={{
          position: "absolute", top: 8, right: 8,
          background: "var(--bg-hover)", border: "1px solid var(--border-bright)",
          color: copied ? "var(--green)" : "var(--text-muted)",
          fontSize: 10, padding: "3px 8px", cursor: "pointer", fontFamily: "var(--font-mono)",
          letterSpacing: "0.08em",
        }}
      >
        {copied ? "COPIED" : "COPY"}
      </button>
    </div>
  );
}

function SectionTitle({ children }: { children: string }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{ width: 32, height: 2, background: "var(--amber)", marginBottom: 12 }} />
      <h2 className="font-display" style={{ fontSize: 28, letterSpacing: "0.06em", color: "var(--text-primary)" }}>{children}</h2>
    </div>
  );
}

function Para({ children }: { children: React.ReactNode }) {
  return <p style={{ color: "var(--text-secondary)", fontSize: 14, lineHeight: 1.85, marginBottom: 16 }}>{children}</p>;
}

export default function DocsPage() {
  const [active, setActive] = useState<Section>("OVERVIEW");

  return (
    <>
      <Navbar />

      <div className="docs-layout" style={{ maxWidth: 1280, margin: "0 auto", padding: "0 16px", paddingTop: "calc(56px + 40px)", display: "flex", gap: 0, minHeight: "100vh" }}>

        {/* Sidebar */}
        <aside style={{
          width: 220, flexShrink: 0, paddingRight: 32,
          position: "sticky", top: "calc(56px + 40px)", height: "fit-content",
          display: "none",
        }} className="docs-sidebar">
          <div style={{ fontSize: 10, letterSpacing: "0.16em", color: "var(--text-muted)", marginBottom: 16, fontWeight: 500 }}>DOCUMENTATION</div>
          {SECTIONS.map((s) => (
            <button
              key={s}
              onClick={() => setActive(s)}
              style={{
                display: "block", width: "100%", textAlign: "left",
                padding: "9px 12px", background: "none",
                border: "none", borderLeft: `2px solid ${active === s ? "var(--amber)" : "var(--border)"}`,
                color: active === s ? "var(--amber)" : "var(--text-secondary)",
                fontSize: 11, fontWeight: active === s ? 600 : 400,
                letterSpacing: "0.1em", cursor: "pointer",
                fontFamily: "var(--font-mono)", marginBottom: 2,
                transition: "all 0.15s",
              }}
            >
              {s}
            </button>
          ))}
        </aside>

        {/* Mobile section picker */}
        <div className="docs-mobile-nav" style={{ display: "none", marginBottom: 24, width: "100%" }}>
          <select
            value={active}
            onChange={(e) => setActive(e.target.value as Section)}
            style={{
              width: "100%", background: "var(--bg-card)", border: "1px solid var(--border-bright)",
              color: "var(--text-primary)", padding: "10px 14px", fontSize: 12,
              fontFamily: "var(--font-mono)", cursor: "pointer", outline: "none",
            }}
          >
            {SECTIONS.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>

        {/* Content */}
        <main style={{ flex: 1, minWidth: 0, paddingBottom: 80 }}>

          {active === "OVERVIEW" && (
            <div className="fade-in-1">
              <SectionTitle>OVERVIEW</SectionTitle>
              <Para>Ferros Vault is an institutional-grade ERC-4626 tokenized yield vault deployed on Ethereum Sepolia. It accepts USDC deposits, mints proportional vault shares, and accrues yield via a pluggable strategy interface.</Para>
              <Para>The vault is upgradeable via the UUPS (ERC-1967) proxy pattern and enforces reentrancy protection, access control, and CEI ordering throughout.</Para>

              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 12, margin: "28px 0" }}>
                {[
                  ["STANDARD", "ERC-4626"],
                  ["PROXY", "UUPS / ERC-1967"],
                  ["ASSET", "USDC (6 dec)"],
                  ["NETWORK", "Ethereum Sepolia"],
                  ["CHAIN ID", "11155111"],
                  ["STRATEGY", "MockYieldSource"],
                ].map(([k, v]) => (
                  <div key={k} className="panel-card" style={{ padding: "16px 18px" }}>
                    <div style={{ fontSize: 10, color: "var(--text-muted)", letterSpacing: "0.14em", fontWeight: 500, marginBottom: 6 }}>{k}</div>
                    <div style={{ fontSize: 13, color: "var(--amber)", fontFamily: "var(--font-mono)" }}>{v}</div>
                  </div>
                ))}
              </div>

              <div className="panel-card" style={{ padding: "16px 20px", borderLeft: "3px solid var(--amber)" }}>
                <div style={{ fontSize: 11, fontWeight: 600, color: "var(--amber)", letterSpacing: "0.1em", marginBottom: 6 }}>⚠ TESTNET ONLY</div>
                <div style={{ fontSize: 13, color: "var(--text-secondary)" }}>This deployment uses a mock yield source that mints tokens to simulate APY. Not audited for mainnet use.</div>
              </div>
            </div>
          )}

          {active === "ARCHITECTURE" && (
            <div className="fade-in-1">
              <SectionTitle>ARCHITECTURE</SectionTitle>
              <Para>The system is composed of four on-chain contracts connected via interfaces.</Para>

              {/* Responsive Architecture Diagram */}
              <div style={{ margin: "28px 0", overflowX: "auto" }}>
                <div style={{ minWidth: 300, display: "flex", flexDirection: "column", alignItems: "center", gap: 0 }}>

                  {/* User */}
                  <div style={{ display: "flex", justifyContent: "space-between", width: "100%", maxWidth: 600, gap: 12 }}>
                    <div className="panel-card" style={{ flex: 1, padding: "12px 16px", textAlign: "center", borderColor: "var(--border-bright)" }}>
                      <div style={{ fontSize: 10, color: "var(--text-muted)", letterSpacing: "0.12em", marginBottom: 4 }}>ACTOR</div>
                      <div className="font-display" style={{ fontSize: 16, color: "var(--text-primary)", letterSpacing: "0.06em" }}>USER</div>
                      <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 4 }}>deposit / withdraw</div>
                    </div>
                    <div className="panel-card" style={{ flex: 1, padding: "12px 16px", textAlign: "center", borderColor: "var(--amber-dim)" }}>
                      <div style={{ fontSize: 10, color: "var(--text-muted)", letterSpacing: "0.12em", marginBottom: 4 }}>FACTORY</div>
                      <div className="font-display" style={{ fontSize: 16, color: "var(--amber)", letterSpacing: "0.06em" }}>VaultFactory</div>
                      <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 4 }}>ERC-1967 deploy</div>
                    </div>
                  </div>

                  {/* Arrow down */}
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "flex-start", width: "100%", maxWidth: 600, paddingLeft: "calc(25% - 8px)", height: 32 }}>
                    <div style={{ width: 2, height: 32, background: "var(--cyan-dim)", margin: "0 auto" }} />
                  </div>

                  {/* YieldVault Proxy */}
                  <div style={{ width: "100%", maxWidth: 600 }}>
                    <div className="panel-card" style={{ padding: "14px 20px", textAlign: "center", borderColor: "var(--cyan-dim)", borderWidth: 2 }}>
                      <div style={{ fontSize: 10, color: "var(--cyan)", letterSpacing: "0.14em", marginBottom: 4 }}>ERC-4626 · UUPS PROXY · ERC-1967</div>
                      <div className="font-display" style={{ fontSize: 20, color: "var(--cyan)", letterSpacing: "0.08em" }}>YieldVault</div>
                      <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 6 }}>deposit · withdraw · redeem · convertToShares · totalAssets</div>
                    </div>
                  </div>

                  {/* Arrow down */}
                  <div style={{ width: "100%", maxWidth: 600, display: "flex", justifyContent: "space-between", height: 32, paddingLeft: "15%", paddingRight: "15%" }}>
                    <div style={{ width: 2, background: "var(--border-bright)" }} />
                    <div style={{ width: 2, background: "var(--border-bright)" }} />
                  </div>

                  {/* Impl + Strategy */}
                  <div style={{ display: "flex", width: "100%", maxWidth: 600, gap: 12 }}>
                    <div className="panel-card" style={{ flex: 1, padding: "12px 16px", textAlign: "center", borderColor: "var(--border-bright)" }}>
                      <div style={{ fontSize: 10, color: "var(--text-muted)", letterSpacing: "0.12em", marginBottom: 4 }}>LOGIC CONTRACT</div>
                      <div className="font-display" style={{ fontSize: 15, color: "var(--text-primary)", letterSpacing: "0.04em" }}>YieldVaultImpl</div>
                      <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 4 }}>ERC4626 · UUPS · Ownable · ReentrancyGuard</div>
                    </div>
                    <div className="panel-card" style={{ flex: 1, padding: "12px 16px", textAlign: "center", borderColor: "var(--green)" }}>
                      <div style={{ fontSize: 10, color: "var(--green)", letterSpacing: "0.12em", marginBottom: 4 }}>STRATEGY</div>
                      <div className="font-display" style={{ fontSize: 15, color: "var(--green)", letterSpacing: "0.04em" }}>MockYieldSource</div>
                      <div style={{ fontSize: 11, color: "var(--text-muted)", marginTop: 4 }}>IYieldStrategy · 10% APY · testnet</div>
                    </div>
                  </div>

                  {/* Legend */}
                  <div style={{ marginTop: 20, display: "flex", gap: 20, flexWrap: "wrap", justifyContent: "center" }}>
                    {[["var(--cyan)", "Core Vault"], ["var(--amber)", "Factory"], ["var(--green)", "Strategy"], ["var(--border-bright)", "Logic / Impl"]].map(([color, label]) => (
                      <div key={label as string} style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 11, color: "var(--text-muted)" }}>
                        <div style={{ width: 10, height: 10, border: `2px solid ${color}` }} />
                        {label}
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              {[
                ["VaultFactory", "Owner-controlled factory. Deploys ERC-1967 proxy instances of YieldVault. Maintains a registry of vaults per asset."],
                ["YieldVault (Proxy)", "The ERC-4626 vault. Accepts ERC-20 deposits, mints shares, delegates asset management to an IYieldStrategy. Upgradeable via UUPS."],
                ["YieldVaultImpl", "The logic contract behind the proxy. Inherits ERC4626Upgradeable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable."],
                ["IYieldStrategy", "Interface for pluggable yield strategies. Methods: deposit(), withdraw(), totalAssets(). MockYieldSource implements this for testnet."],
              ].map(([name, desc]) => (
                <div key={name as string} style={{ display: "flex", flexDirection: "column", gap: 6, padding: "16px 0", borderBottom: "1px solid var(--border)" }}>
                  <span className="font-display" style={{ fontSize: 15, color: "var(--cyan)", letterSpacing: "0.04em" }}>{name}</span>
                  <div style={{ fontSize: 13, color: "var(--text-secondary)", lineHeight: 1.7 }}>{desc}</div>
                </div>
              ))}

              <div style={{ marginTop: 28 }}>
                <div style={{ fontSize: 11, color: "var(--text-muted)", letterSpacing: "0.12em", fontWeight: 500, marginBottom: 12 }}>DEPOSIT FLOW</div>
                <CodeBlock>{`User → approve(USDC, vault, amount)
     → vault.deposit(amount, receiver)
        → USDC transferred from user to vault
        → vault approves strategy
        → strategy.deposit(amount)
        → lastHarvestAssets += amount
        → shares minted to receiver`}</CodeBlock>
              </div>

              <div style={{ marginTop: 16 }}>
                <div style={{ fontSize: 11, color: "var(--text-muted)", letterSpacing: "0.12em", fontWeight: 500, marginBottom: 12 }}>WITHDRAW FLOW</div>
                <CodeBlock>{`User → vault.withdraw(amount, receiver, owner)
        → lastHarvestAssets -= amount
        → strategy.withdraw(amount)
        → USDC transferred to receiver
        → shares burned from owner`}</CodeBlock>
              </div>
            </div>
          )}

          {active === "CONTRACTS" && (
            <div className="fade-in-1">
              <SectionTitle>CONTRACTS</SectionTitle>
              <Para>All contracts deployed on Ethereum Sepolia (Chain ID: 11155111). Verified on Etherscan.</Para>

              <div style={{ display: "flex", flexDirection: "column", gap: 2, marginTop: 8 }}>
                {CONTRACTS.map(({ name, address, note }) => (
                  <div key={name} className="panel-card" style={{ padding: "16px 20px" }}>
                    <div style={{ display: "flex", justifyContent: "space-between", flexWrap: "wrap", gap: 8, marginBottom: 6 }}>
                      <span className="font-display" style={{ fontSize: 16, color: "var(--text-primary)", letterSpacing: "0.04em" }}>{name}</span>
                      <a
                        href={`https://sepolia.etherscan.io/address/${address}`}
                        target="_blank" rel="noopener noreferrer"
                        style={{ fontSize: 11, color: "var(--cyan)", fontFamily: "var(--font-mono)", textDecoration: "none" }}
                      >
                        ETHERSCAN ↗
                      </a>
                    </div>
                    <div style={{ fontFamily: "var(--font-mono)", fontSize: 12, color: "var(--amber)", marginBottom: 6, wordBreak: "break-all" }}>{address}</div>
                    <div style={{ fontSize: 12, color: "var(--text-muted)" }}>{note}</div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {active === "INTERFACE" && (
            <div className="fade-in-1">
              <SectionTitle>INTERFACE</SectionTitle>
              <Para>YieldVault implements the full ERC-4626 standard. All view functions are read-only and free to call.</Para>

              <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                {INTERFACE_ROWS.map(([fn, ret, desc]) => (
                  <div key={fn} className="panel-card" style={{ padding: "14px 16px" }}>
                    <div style={{ fontFamily: "var(--font-mono)", color: "var(--cyan)", fontSize: 11, wordBreak: "break-all", marginBottom: 6 }}>{fn}</div>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 12, flexWrap: "wrap" }}>
                      <span style={{ fontFamily: "var(--font-mono)", color: "var(--amber)", fontSize: 11 }}>→ {ret}</span>
                      <span style={{ fontSize: 12, color: "var(--text-secondary)", textAlign: "right" }}>{desc}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {active === "DEPOSIT & WITHDRAW" && (
            <div className="fade-in-1">
              <SectionTitle>DEPOSIT & WITHDRAW</SectionTitle>

              <Para>Before depositing, you must approve the vault to spend your USDC. The vault uses <span style={{ color: "var(--amber)" }}>maxUint256</span> approval by default to avoid repeated approvals.</Para>

              <div style={{ fontSize: 11, color: "var(--text-muted)", letterSpacing: "0.12em", fontWeight: 500, marginBottom: 8, marginTop: 20 }}>STEP 1 — APPROVE</div>
              <CodeBlock>{`// Approve vault to spend USDC
IERC20(USDC).approve(vault, type(uint256).max);`}</CodeBlock>

              <div style={{ fontSize: 11, color: "var(--text-muted)", letterSpacing: "0.12em", fontWeight: 500, marginBottom: 8, marginTop: 20 }}>STEP 2 — DEPOSIT</div>
              <CodeBlock>{`// Deposit 1000 USDC (6 decimals)
uint256 shares = vault.deposit(1000e6, msg.sender);`}</CodeBlock>

              <div style={{ fontSize: 11, color: "var(--text-muted)", letterSpacing: "0.12em", fontWeight: 500, marginBottom: 8, marginTop: 20 }}>WITHDRAW</div>
              <CodeBlock>{`// Withdraw 1000 USDC worth of assets
uint256 burned = vault.withdraw(1000e6, receiver, owner);

// Or redeem all shares
uint256 maxShares = vault.balanceOf(msg.sender);
uint256 assets = vault.redeem(maxShares, receiver, msg.sender);`}</CodeBlock>

              <div style={{ fontSize: 11, color: "var(--text-muted)", letterSpacing: "0.12em", fontWeight: 500, marginBottom: 8, marginTop: 20 }}>PREVIEW BEFORE TRANSACTING</div>
              <CodeBlock>{`// How many shares will I get for 500 USDC?
uint256 shares = vault.convertToShares(500e6);

// How many USDC will I get for my shares?
uint256 assets = vault.convertToAssets(myShares);

// What is the current share price? (scaled to 1e6)
uint256 price = vault.convertToAssets(1e6);`}</CodeBlock>
            </div>
          )}

          {active === "YIELD STRATEGY" && (
            <div className="fade-in-1">
              <SectionTitle>YIELD STRATEGY</SectionTitle>
              <Para>The vault delegates asset management to any contract implementing <span style={{ color: "var(--amber)" }}>IYieldStrategy</span>. The strategy is set at initialization and can be updated by the vault owner.</Para>

              <CodeBlock>{`interface IYieldStrategy {
    function deposit(uint256 assets) external;
    function withdraw(uint256 assets) external;
    function totalAssets() external view returns (uint256);
}`}</CodeBlock>

              <Para>MockYieldSource simulates yield by minting tokens at a configurable APY rate (default 10%). Yield is calculated using elapsed time since last accrual:</Para>

              <CodeBlock>{`// Yield formula (simplified)
yieldAmount = balance × apyBps × elapsed
              ─────────────────────────────
                    10000 × 365 days`}</CodeBlock>

              <div style={{ marginTop: 24 }}>
                {[
                  ["APY", "1000 bps (10%)"],
                  ["Max APY cap", "5000 bps (50%)"],
                  ["Accrual trigger", "On deposit, withdraw, setApy()"],
                  ["Yield source", "Token minting (testnet only)"],
                ].map(([k, v]) => (
                  <div key={k as string} style={{ display: "flex", justifyContent: "space-between", padding: "9px 0", borderBottom: "1px solid var(--border)", fontSize: 13 }}>
                    <span style={{ color: "var(--text-muted)", fontWeight: 500 }}>{k}</span>
                    <span style={{ color: "var(--text-primary)", fontFamily: "var(--font-mono)", fontSize: 12 }}>{v}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {active === "SECURITY" && (
            <div className="fade-in-1">
              <SectionTitle>SECURITY</SectionTitle>
              <Para>Ferros Vault was analyzed with Slither v0.11.5. All High severity findings were resolved. Final result: 0 active findings.</Para>

              {[
                { sev: "HIGH", status: "FIXED", title: "CEI violation in setApy()", desc: "State written after external mint() call. Fixed by computing yield inline, updating all state, then calling mint()." },
                { sev: "LOW", status: "FIXED", title: "Incorrect equality on uint256", desc: "elapsed == 0 guard changed to elapsed < 1 to match Slither's preferred pattern." },
                { sev: "LOW", status: "FIXED", title: "Missing ReentrancyGuard on createVault()", desc: "VaultFactory gained ReentrancyGuard + nonReentrant modifier on createVault()." },
                { sev: "INFO", status: "NOTED", title: "Proxy address computed before state update", desc: "Structural requirement of ERC-1967 deployment — cannot reorder. Mitigated by nonReentrant." },
              ].map(({ sev, status, title, desc }) => (
                <div key={title} className="panel-card" style={{ padding: "16px 20px", marginBottom: 8, borderLeft: `3px solid ${sev === "HIGH" ? "var(--red)" : sev === "LOW" ? "var(--amber)" : "var(--border-bright)"}` }}>
                  <div style={{ display: "flex", gap: 10, alignItems: "center", marginBottom: 8, flexWrap: "wrap" }}>
                    <span className="tag" style={{ borderColor: sev === "HIGH" ? "var(--red)" : sev === "LOW" ? "var(--amber-dim)" : "var(--border-bright)", color: sev === "HIGH" ? "var(--red)" : sev === "LOW" ? "var(--amber)" : "var(--text-muted)" }}>{sev}</span>
                    <span className="tag tag-green">{status}</span>
                    <span style={{ fontSize: 13, fontWeight: 600, color: "var(--text-primary)" }}>{title}</span>
                  </div>
                  <div style={{ fontSize: 13, color: "var(--text-secondary)", lineHeight: 1.7 }}>{desc}</div>
                </div>
              ))}

              <div className="panel-card" style={{ padding: "16px 20px", marginTop: 20, borderLeft: "3px solid var(--green)" }}>
                <div style={{ fontSize: 11, fontWeight: 600, color: "var(--green)", letterSpacing: "0.1em", marginBottom: 6 }}>SECURITY PRACTICES</div>
                <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  {["CEI (Checks-Effects-Interactions) pattern enforced", "ReentrancyGuardUpgradeable on all state-modifying functions", "OwnableUpgradeable with 2-step transfer (Ownable2Step)", "_disableInitializers() in implementation constructor", "All privileged functions emit audit trail events", "No floating pragma — pinned to 0.8.24"].map((item) => (
                    <div key={item} style={{ fontSize: 13, color: "var(--text-secondary)", display: "flex", gap: 10 }}>
                      <span style={{ color: "var(--green)", flexShrink: 0 }}>✓</span>
                      {item}
                    </div>
                  ))}
                </div>
              </div>

              <div style={{ marginTop: 32, marginBottom: 16 }}>
                <div style={{ width: 32, height: 2, background: "var(--amber)", marginBottom: 12 }} />
                <div className="font-display" style={{ fontSize: 20, color: "var(--text-primary)", letterSpacing: "0.06em", marginBottom: 4 }}>KNOWN LIMITATIONS</div>
                <div style={{ fontSize: 13, color: "var(--text-muted)" }}>Gaps between this testnet deployment and a production institutional vault.</div>
              </div>

              {[
                {
                  color: "var(--amber)",
                  label: "CENTRALIZATION RISK",
                  title: "Single-owner upgrade authority",
                  desc: "Ownable2Step prevents accidental ownership transfers, but a single EOA holds unrestricted UUPS upgrade authority. Production path: replace owner with a Gnosis Safe multisig and add a TimelockController (48–72h delay) in front of all upgrade calls.",
                },
                {
                  color: "var(--cyan)",
                  label: "ORACLE DEPENDENCY",
                  title: "No price feed for non-stable assets",
                  desc: "MockYieldSource targets USDC (1:1 stable). Any strategy involving volatile assets (ETH, wBTC, LSTs) requires Chainlink Price Feeds inside totalAssets() to compute accurate share prices. Without it, manipulated spot prices could enable sandwich attacks against depositors.",
                },
                {
                  color: "var(--red)",
                  label: "CIRCUIT BREAKER",
                  title: "No emergency pause mechanism",
                  desc: "The vault has no pause() function. A production vault handling significant TVL should inherit PausableUpgradeable and expose a guardian-controlled pause to halt deposits and withdrawals during an incident. This is a standard institutional risk management requirement.",
                },
              ].map(({ color, label, title, desc }) => (
                <div key={label} className="panel-card" style={{ padding: "16px 20px", marginBottom: 8, borderLeft: `3px solid ${color}` }}>
                  <div style={{ display: "flex", gap: 10, alignItems: "center", marginBottom: 8, flexWrap: "wrap" }}>
                    <span className="tag" style={{ borderColor: color, color }}>{label}</span>
                    <span style={{ fontSize: 13, fontWeight: 600, color: "var(--text-primary)" }}>{title}</span>
                  </div>
                  <div style={{ fontSize: 13, color: "var(--text-secondary)", lineHeight: 1.75 }}>{desc}</div>
                </div>
              ))}
            </div>
          )}

          {active === "FAQ" && (
            <div className="fade-in-1">
              <SectionTitle>FAQ</SectionTitle>
              <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                {FAQ_ROWS.map(([q, a]) => (
                  <FaqItem key={q} q={q as string} a={a as string} />
                ))}
              </div>
            </div>
          )}

        </main>
      </div>

      <footer style={{ borderTop: "1px solid var(--border)", padding: "20px 16px", textAlign: "center", color: "var(--text-secondary)", fontSize: 12 }}>
        <span style={{ fontFamily: "var(--font-mono)" }}>FERROS VAULT · SEPOLIA TESTNET · NOT FOR PRODUCTION USE</span>
      </footer>
    </>
  );
}

function FaqItem({ q, a }: { q: string; a: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="panel-card" style={{ overflow: "hidden" }}>
      <button
        onClick={() => setOpen((v) => !v)}
        style={{
          width: "100%", display: "flex", justifyContent: "space-between", alignItems: "center",
          padding: "16px 20px", background: "none", border: "none", cursor: "pointer", gap: 16,
        }}
      >
        <span style={{ fontSize: 13, fontWeight: 500, color: "var(--text-primary)", textAlign: "left", fontFamily: "var(--font-mono)" }}>{q}</span>
        <span style={{ color: "var(--amber)", fontSize: 16, flexShrink: 0, transition: "transform 0.2s", transform: open ? "rotate(45deg)" : "none" }}>+</span>
      </button>
      {open && (
        <div style={{ padding: "0 20px 16px", fontSize: 13, color: "var(--text-secondary)", lineHeight: 1.8, borderTop: "1px solid var(--border)" }}>
          <div style={{ paddingTop: 14 }}>{a}</div>
        </div>
      )}
    </div>
  );
}
