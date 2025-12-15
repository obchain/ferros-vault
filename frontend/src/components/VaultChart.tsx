"use client";

import { useState } from "react";
import { useQuery } from "@apollo/client";
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from "recharts";
import { GET_VAULT_DAILY_SNAPSHOTS } from "@/lib/graphql/queries";
import { VAULT_ADDRESS } from "@/lib/wagmi";

type Range = "7D" | "30D" | "90D";

const RANGES: Range[] = ["7D", "30D", "90D"];

const rangeDays: Record<Range, number> = { "7D": 7, "30D": 30, "90D": 90 };

function formatTs(ts: string) {
  const d = new Date(parseInt(ts) * 1000);
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

interface Snapshot {
  timestamp: string;
  totalAssets: string;
  apy: string;
}

interface CustomTooltipProps {
  active?: boolean;
  payload?: Array<{ value: number; name: string }>;
  label?: string;
}

function CustomTooltip({ active, payload, label }: CustomTooltipProps) {
  if (!active || !payload?.length) return null;
  return (
    <div style={{ background: "var(--bg-card)", border: "1px solid var(--border-bright)", padding: "10px 14px" }}>
      <div style={{ fontSize: 10, color: "var(--text-muted)", marginBottom: 6 }}>{label}</div>
      {payload.map((p) => (
        <div key={p.name} style={{ fontSize: 12, color: p.name === "tvl" ? "var(--amber)" : "var(--cyan)" }}>
          {p.name === "tvl" ? `TVL: $${p.value.toLocaleString()}` : `APY: ${p.value.toFixed(2)}%`}
        </div>
      ))}
    </div>
  );
}

export function VaultChart() {
  const [range, setRange] = useState<Range>("30D");

  const cutoff = Math.floor(Date.now() / 1000) - rangeDays[range] * 86400;

  const { data, loading } = useQuery(GET_VAULT_DAILY_SNAPSHOTS, {
    variables: { vault: VAULT_ADDRESS.toLowerCase(), first: rangeDays[range] },
    skip: !VAULT_ADDRESS,
  });

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const snapshots: Snapshot[] = ((data as any)?.vaultDailySnapshots ?? []).filter(
    (s: Snapshot) => parseInt(s.timestamp) >= cutoff
  );

  const chartData = snapshots.map((s: Snapshot) => ({
    date: formatTs(s.timestamp),
    tvl: parseFloat(s.totalAssets) / 1e6,
    apy: parseFloat(s.apy) * 100,
  }));

  return (
    <div className="panel-card" style={{ padding: "24px 28px" }}>
      <div className="chart-header" style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: "0.12em", color: "var(--text-muted)", marginBottom: 4, fontWeight: 500 }}>HISTORICAL PERFORMANCE</div>
          <div className="font-display" style={{ fontSize: 20, letterSpacing: "0.06em" }}>TVL / APY</div>
        </div>
        <div style={{ display: "flex", gap: 6 }}>
          {RANGES.map((r) => (
            <button
              key={r}
              className="btn-ghost"
              style={{
                padding: "4px 12px", fontSize: 10, letterSpacing: "0.1em",
                borderColor: range === r ? "var(--amber)" : undefined,
                color: range === r ? "var(--amber)" : undefined,
              }}
              onClick={() => setRange(r)}
            >
              {r}
            </button>
          ))}
        </div>
      </div>

      {loading ? (
        <div style={{ height: 200, display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-muted)", fontSize: 12 }}>
          LOADING DATA…
        </div>
      ) : chartData.length === 0 ? (
        <div style={{ height: 200, display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-muted)", fontSize: 12 }}>
          NO HISTORICAL DATA — DEPOSIT TO GENERATE SNAPSHOTS
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={220}>
          <AreaChart data={chartData} margin={{ top: 4, right: 0, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="tvlGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#F5A623" stopOpacity={0.2} />
                <stop offset="95%" stopColor="#F5A623" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="apyGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#00D4FF" stopOpacity={0.15} />
                <stop offset="95%" stopColor="#00D4FF" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="2 6" stroke="var(--border)" vertical={false} />
            <XAxis dataKey="date" tick={{ fill: "var(--text-secondary)", fontSize: 11, fontWeight: 400 }} axisLine={false} tickLine={false} />
            <YAxis yAxisId="tvl" orientation="left" tick={{ fill: "var(--text-secondary)", fontSize: 11, fontWeight: 400 }} axisLine={false} tickLine={false} tickFormatter={(v) => `$${(v / 1000).toFixed(0)}k`} />
            <YAxis yAxisId="apy" orientation="right" tick={{ fill: "var(--text-secondary)", fontSize: 11, fontWeight: 400 }} axisLine={false} tickLine={false} tickFormatter={(v) => `${v.toFixed(1)}%`} />
            <Tooltip content={<CustomTooltip />} />
            <Area yAxisId="tvl" type="monotone" dataKey="tvl" name="tvl" stroke="var(--amber)" strokeWidth={1.5} fill="url(#tvlGrad)" dot={false} />
            <Area yAxisId="apy" type="monotone" dataKey="apy" name="apy" stroke="var(--cyan)" strokeWidth={1.5} fill="url(#apyGrad)" dot={false} />
          </AreaChart>
        </ResponsiveContainer>
      )}

      <div style={{ display: "flex", gap: 24, marginTop: 16 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, color: "var(--text-secondary)", fontWeight: 400 }}>
          <div style={{ width: 16, height: 2, background: "var(--amber)" }} />
          TVL (USD)
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, color: "var(--text-secondary)", fontWeight: 400 }}>
          <div style={{ width: 16, height: 2, background: "var(--cyan)" }} />
          APY (%)
        </div>
      </div>
    </div>
  );
}
