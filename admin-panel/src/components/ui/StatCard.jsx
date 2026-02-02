import GlassPanel from "./GlassPanel";

export default function StatCard({ label, value, hint, children }) {
  return (
    <GlassPanel className="p-5 relative overflow-hidden">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-slate-400">{label}</p>
          <p className="text-3xl font-semibold mt-2 text-slate-50">{value}</p>
          {hint && <p className="text-xs text-slate-500 mt-2">{hint}</p>}
        </div>
        {children}
      </div>
      <div className="ambient-glow" aria-hidden="true" />
    </GlassPanel>
  );
}
