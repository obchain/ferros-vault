"use client";

import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { formatUnits } from "viem";
import { useDeposit, useTokenBalance } from "@/hooks/useVault";

interface DepositModalProps {
  assetAddress?: `0x${string}`;
  onClose: () => void;
}

type Step = "input" | "approve" | "deposit" | "success";

export function DepositModal({ assetAddress, onClose }: DepositModalProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const [step, setStep] = useState<Step>("input");

  const { balance, allowance, balanceFormatted, refetch: refetchBalance } = useTokenBalance(assetAddress);
  const { deposit, approve, isPending, isConfirming, isSuccess, error, hash } = useDeposit();

  const parsed = amount ? BigInt(Math.floor(parseFloat(amount) * 1_000_000)) : BigInt(0);
  const needsApproval = allowance !== undefined && parsed > BigInt(0) && allowance < parsed;
  const insufficient = balance !== undefined && parsed > balance;

  useEffect(() => {
    if (isSuccess) {
      if (step === "approve") {
        refetchBalance();
        setStep("deposit");
      } else if (step === "deposit") {
        setStep("success");
      }
    }
  }, [isSuccess, step, refetchBalance]);

  const handleMax = () => {
    if (balance !== undefined) setAmount(formatUnits(balance, 6));
  };

  const handleAction = async () => {
    if (!assetAddress || !amount) return;
    if (needsApproval) {
      setStep("approve");
      await approve(assetAddress, amount);
    } else {
      setStep("deposit");
      await deposit(amount);
    }
  };

  const busy = isPending || isConfirming;

  return (
    <div style={{
      position: "fixed", inset: 0, zIndex: 50,
      background: "rgba(8,11,16,0.85)", backdropFilter: "blur(4px)",
      display: "flex", alignItems: "center", justifyContent: "center",
      padding: 16,
    }} onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="panel modal-box" style={{ width: "100%", maxWidth: 440, padding: 32, position: "relative" }}>

        {/* Header */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 28 }}>
          <div>
            <div className="accent-line" />
            <h2 className="font-display" style={{ fontSize: 28, color: "var(--text-primary)", letterSpacing: "0.06em" }}>DEPOSIT</h2>
          </div>
          <button onClick={onClose} className="btn-ghost" style={{ padding: "4px 10px", fontSize: 16 }}>✕</button>
        </div>

        {step === "success" ? (
          <div style={{ textAlign: "center", padding: "24px 0" }}>
            <div style={{ fontSize: 48, marginBottom: 16 }}>✓</div>
            <div className="font-display" style={{ fontSize: 24, color: "var(--green)", marginBottom: 8 }}>DEPOSITED</div>
            <div style={{ color: "var(--text-muted)", fontSize: 12, marginBottom: 24 }}>
              {amount} USDC deposited successfully
            </div>
            {hash && (
              <div style={{ fontSize: 11, color: "var(--cyan)", fontFamily: "var(--font-mono)", marginBottom: 24, wordBreak: "break-all" }}>
                {hash.slice(0, 20)}…{hash.slice(-8)}
              </div>
            )}
            <button className="btn-primary" onClick={onClose}>CLOSE</button>
          </div>
        ) : (
          <>
            {/* Balance */}
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8, fontSize: 11 }}>
              <span style={{ color: "var(--text-muted)" }}>WALLET BALANCE</span>
              <button onClick={handleMax} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--amber)", fontFamily: "var(--font-mono)", fontSize: 11 }}>
                {balanceFormatted} USDC · MAX
              </button>
            </div>

            {/* Input */}
            <div style={{ position: "relative", marginBottom: 20 }}>
              <input
                type="number"
                className="vault-input"
                placeholder="0.00"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                disabled={busy}
                style={{ fontSize: 20, padding: "14px 70px 14px 14px" }}
              />
              <span style={{ position: "absolute", right: 14, top: "50%", transform: "translateY(-50%)", color: "var(--text-muted)", fontSize: 12 }}>USDC</span>
            </div>

            {/* Status steps */}
            <div style={{ display: "flex", gap: 8, marginBottom: 20 }}>
              {(needsApproval ? ["APPROVE", "DEPOSIT"] : ["DEPOSIT"]).map((s, i) => (
                <div key={s} style={{ flex: 1, display: "flex", alignItems: "center", gap: 6 }}>
                  {i > 0 && <div style={{ width: 16, height: 1, background: "var(--border)" }} />}
                  <div style={{
                    flex: 1, textAlign: "center", padding: "6px 0", fontSize: 10, letterSpacing: "0.1em",
                    border: "1px solid",
                    borderColor: step === s.toLowerCase() ? "var(--amber)" : "var(--border)",
                    color: step === s.toLowerCase() ? "var(--amber)" : "var(--text-muted)",
                  }}>{s}</div>
                </div>
              ))}
            </div>

            {error && (
              <div style={{ marginBottom: 16, padding: "8px 12px", border: "1px solid var(--red)", color: "var(--red)", fontSize: 11 }}>
                {error.slice(0, 80)}
              </div>
            )}

            {insufficient && amount && (
              <div style={{ marginBottom: 16, padding: "8px 12px", border: "1px solid var(--red)", color: "var(--red)", fontSize: 11 }}>
                INSUFFICIENT BALANCE
              </div>
            )}

            <button
              className="btn-primary"
              disabled={busy || !amount || !address || insufficient || parseFloat(amount) <= 0}
              onClick={handleAction}
            >
              {busy
                ? (isConfirming ? "CONFIRMING…" : "PENDING…")
                : needsApproval ? "APPROVE USDC" : "DEPOSIT"}
            </button>

            {!address && (
              <div style={{ marginTop: 12, textAlign: "center", fontSize: 11, color: "var(--text-muted)" }}>
                Connect wallet to deposit
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
