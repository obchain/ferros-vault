"use client";

import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { formatUnits } from "viem";
import { useWithdraw, useUserPosition } from "@/hooks/useVault";

interface WithdrawModalProps {
  onClose: () => void;
}

export function WithdrawModal({ onClose }: WithdrawModalProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const [success, setSuccess] = useState(false);

  const { maxWithdraw, positionFormatted, refetch } = useUserPosition();
  const { withdraw, isPending, isConfirming, isSuccess, error, hash } = useWithdraw();

  const parsed = amount ? BigInt(Math.floor(parseFloat(amount) * 1_000_000)) : BigInt(0);
  const exceeds = maxWithdraw !== undefined && parsed > BigInt(0) && parsed > maxWithdraw;
  const busy = isPending || isConfirming;

  useEffect(() => {
    if (isSuccess) {
      refetch();
      setSuccess(true);
    }
  }, [isSuccess, refetch]);

  const handleMax = () => {
    if (maxWithdraw !== undefined) setAmount(formatUnits(maxWithdraw, 6));
  };

  return (
    <div style={{
      position: "fixed", inset: 0, zIndex: 50,
      background: "rgba(8,11,16,0.85)", backdropFilter: "blur(4px)",
      display: "flex", alignItems: "center", justifyContent: "center",
      padding: 16,
    }} onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="panel modal-box" style={{ width: "100%", maxWidth: 440, padding: 32 }}>

        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 28 }}>
          <div>
            <div className="accent-line" style={{ background: "var(--cyan)" }} />
            <h2 className="font-display" style={{ fontSize: 28, color: "var(--text-primary)", letterSpacing: "0.06em" }}>WITHDRAW</h2>
          </div>
          <button onClick={onClose} className="btn-ghost" style={{ padding: "4px 10px", fontSize: 16 }}>✕</button>
        </div>

        {success ? (
          <div style={{ textAlign: "center", padding: "24px 0" }}>
            <div style={{ fontSize: 48, marginBottom: 16 }}>✓</div>
            <div className="font-display" style={{ fontSize: 24, color: "var(--green)", marginBottom: 8 }}>WITHDRAWN</div>
            <div style={{ color: "var(--text-muted)", fontSize: 12, marginBottom: 24 }}>
              {amount} USDC withdrawn to your wallet
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
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8, fontSize: 11 }}>
              <span style={{ color: "var(--text-muted)" }}>AVAILABLE TO WITHDRAW</span>
              <button onClick={handleMax} style={{ background: "none", border: "none", cursor: "pointer", color: "var(--cyan)", fontFamily: "var(--font-mono)", fontSize: 11 }}>
                {positionFormatted} USDC · MAX
              </button>
            </div>

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

            {error && (
              <div style={{ marginBottom: 16, padding: "8px 12px", border: "1px solid var(--red)", color: "var(--red)", fontSize: 11 }}>
                {error.slice(0, 80)}
              </div>
            )}

            {exceeds && amount && (
              <div style={{ marginBottom: 16, padding: "8px 12px", border: "1px solid var(--red)", color: "var(--red)", fontSize: 11 }}>
                EXCEEDS WITHDRAWABLE BALANCE
              </div>
            )}

            <button
              className="btn-primary"
              style={{ background: "var(--cyan)", color: "var(--bg-base)" }}
              disabled={busy || !amount || !address || exceeds || parseFloat(amount) <= 0}
              onClick={() => withdraw(amount)}
            >
              {busy ? (isConfirming ? "CONFIRMING…" : "PENDING…") : "WITHDRAW"}
            </button>

            {!address && (
              <div style={{ marginTop: 12, textAlign: "center", fontSize: 11, color: "var(--text-muted)" }}>
                Connect wallet to withdraw
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
