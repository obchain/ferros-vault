"use client";

import { useState, useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useAccount } from "wagmi";
import { VAULT_ADDRESS } from "@/lib/wagmi";

export function Navbar() {
  const router = useRouter();
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia("(max-width: 768px)");
    const handler = (e: MediaQueryListEvent | MediaQueryList) => {
      setIsMobile(e.matches);
      if (!e.matches) setMenuOpen(false);
    };
    handler(mq);
    mq.addEventListener("change", handler as (e: MediaQueryListEvent) => void);
    setMounted(true);
    return () => mq.removeEventListener("change", handler as (e: MediaQueryListEvent) => void);
  }, []);

  const { isConnected } = useAccount();

  // Before hydration, treat as desktop to match SSR output
  const mobile = mounted && isMobile;

  return (
    <>
      <nav className="panel" style={{
        borderLeft: "none", borderRight: "none", borderTop: "none",
        position: "fixed", top: 0, left: 0, right: 0, zIndex: 40,
        width: "100%",
      }}>
        <div style={{
          maxWidth: 1280, margin: "0 auto", padding: "0 16px",
          display: "flex", alignItems: "center", justifyContent: "space-between",
          height: 56,
        }}>

          {/* Logo */}
          <div style={{ display: "flex", alignItems: "center", gap: 6, flexShrink: 0, minWidth: 0 }}>
            <img src="/favicon.svg" alt="" width={34} height={34} style={{ flexShrink: 0 }} />
            <span className="font-display" style={{ fontSize: 20, color: "var(--text-primary)", letterSpacing: "0.08em", whiteSpace: "nowrap" }}>
              FERROS<span style={{ color: "var(--amber)" }}>.</span>VAULT
            </span>
            {!mobile && (
              <span className="tag tag-green" style={{ marginLeft: 2 }}>SEPOLIA</span>
            )}
          </div>

          {/* Desktop centre links */}
          {!mobile && (
            <div style={{ display: "flex", gap: 28 }}>
              {[["VAULT", "/"], ["ANALYTICS", "/"], ["DOCS", "/docs"]].map(([label, href]) => (
                <button
                  key={label}
                  onClick={() => router.push(href)}
                  className="btn-ghost"
                  style={{
                    border: "none", padding: "4px 0", fontSize: 12, letterSpacing: "0.1em", fontWeight: 500,
                    color: pathname === href ? "var(--amber)" : undefined,
                  }}
                >
                  {label}
                </button>
              ))}
            </div>
          )}

          {/* Right side */}
          <div style={{ display: "flex", alignItems: "center", gap: 10, flexShrink: 0 }}>

            {/* Desktop contract address — only when wallet connected */}
            {!mobile && mounted && isConnected && (
              <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 11 }}>
                <span className="pulse-dot" />
                <span style={{ color: "var(--text-muted)", letterSpacing: "0.1em", fontWeight: 500 }}>VAULT</span>
                <span style={{ fontFamily: "var(--font-mono)", color: "var(--text-secondary)" }}>
                  {VAULT_ADDRESS.slice(0, 6)}…{VAULT_ADDRESS.slice(-4)}
                </span>
              </div>
            )}

            {/* Connect button */}
            <div style={{ flexShrink: 0 }}>
              <ConnectButton showBalance={false} chainStatus="none" accountStatus="address" />
            </div>

            {/* Hamburger — mobile only */}
            {mobile && (
              <button
                onClick={() => setMenuOpen((v) => !v)}
                aria-label="Toggle menu"
                style={{
                  position: "relative", width: 34, height: 34,
                  background: "none", border: "1px solid var(--border-bright)",
                  cursor: "pointer", flexShrink: 0,
                }}
              >
                <span style={{
                  position: "absolute", left: 8, width: 18, height: 2,
                  background: menuOpen ? "var(--amber)" : "var(--text-secondary)",
                  transition: "transform 0.2s, background 0.2s, top 0.2s",
                  top: menuOpen ? 16 : 10,
                  transform: menuOpen ? "rotate(45deg)" : "none",
                  transformOrigin: "center",
                }} />
                <span style={{
                  position: "absolute", left: 8, top: 16, width: 18, height: 2,
                  background: "var(--text-secondary)",
                  transition: "opacity 0.15s",
                  opacity: menuOpen ? 0 : 1,
                }} />
                <span style={{
                  position: "absolute", left: 8, width: 18, height: 2,
                  background: menuOpen ? "var(--amber)" : "var(--text-secondary)",
                  transition: "transform 0.2s, background 0.2s, top 0.2s",
                  top: menuOpen ? 16 : 22,
                  transform: menuOpen ? "rotate(-45deg)" : "none",
                  transformOrigin: "center",
                }} />
              </button>
            )}
          </div>

        </div>
      </nav>

      {/* Mobile drawer */}
      {mobile && menuOpen && (
        <div style={{
          position: "fixed", top: 56, left: 0, right: 0, zIndex: 39,
          background: "var(--bg-panel)",
          borderBottom: "1px solid var(--border-bright)",
          width: "100%",
        }}>
          {[["VAULT", "/"], ["ANALYTICS", "/"], ["DOCS", "/docs"]].map(([label, href]) => (
            <button
              key={label}
              onClick={() => { router.push(href); setMenuOpen(false); }}
              style={{
                display: "block", width: "100%", textAlign: "left",
                padding: "16px 20px", background: "none", border: "none",
                borderBottom: "1px solid var(--border)",
                color: pathname === href ? "var(--amber)" : "var(--text-secondary)",
                fontSize: 13, fontWeight: 500,
                letterSpacing: "0.12em", cursor: "pointer",
                fontFamily: "var(--font-mono)",
              }}
            >
              {label}
            </button>
          ))}
          {isConnected && (
            <div style={{ padding: "14px 20px", display: "flex", alignItems: "center", gap: 8, fontSize: 11, borderTop: "1px solid var(--border)" }}>
              <span className="pulse-dot" />
              <span style={{ color: "var(--text-muted)", fontWeight: 500, letterSpacing: "0.1em" }}>VAULT</span>
              <span style={{ fontFamily: "var(--font-mono)", color: "var(--text-secondary)" }}>
                {VAULT_ADDRESS.slice(0, 6)}…{VAULT_ADDRESS.slice(-4)}
              </span>
            </div>
          )}
        </div>
      )}
    </>
  );
}
