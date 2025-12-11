"use client";

interface StatCardProps {
  label: string;
  value: string;
  sub?: string;
  accent?: "amber" | "cyan" | "green";
  loading?: boolean;
  className?: string;
}

export function StatCard({ label, value, sub, accent = "amber", loading, className = "" }: StatCardProps) {
  const accentColor = accent === "amber" ? "var(--amber)" : accent === "cyan" ? "var(--cyan)" : "var(--green)";

  return (
    <div className={`panel-card ${className}`} style={{ padding: "24px 28px", position: "relative", overflow: "hidden" }}>
      {/* Corner accent */}
      <div style={{
        position: "absolute", top: 0, right: 0,
        width: 48, height: 48,
        borderLeft: `1px solid ${accentColor}`,
        borderBottom: `1px solid ${accentColor}`,
        opacity: 0.3,
      }} />

      <div style={{ fontSize: 11, letterSpacing: "0.14em", color: "var(--text-muted)", marginBottom: 12, textTransform: "uppercase", fontWeight: 500 }}>
        {label}
      </div>

      {loading ? (
        <div style={{ height: 36, width: "60%", background: "var(--bg-hover)", animation: "pulse 1.5s ease-in-out infinite" }} />
      ) : (
        <div className="font-display" style={{ fontSize: 36, color: accentColor, lineHeight: 1, letterSpacing: "0.04em" }}>
          {value}
        </div>
      )}

      {sub && !loading && (
        <div style={{ marginTop: 8, fontSize: 12, color: "var(--text-secondary)", fontFamily: "var(--font-mono)" }}>
          {sub}
        </div>
      )}
    </div>
  );
}
