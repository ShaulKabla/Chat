export function RadarPulse() {
  return (
    <div className="radar">
      <span className="radar-ring" />
      <span className="radar-ring delay" />
      <span className="radar-ring delay-2" />
      <div className="radar-dot" />
    </div>
  );
}

export function SuccessCheck() {
  return (
    <div className="success-check">
      <svg viewBox="0 0 52 52" aria-hidden="true">
        <circle className="success-circle" cx="26" cy="26" r="24" fill="none" />
        <path className="success-checkmark" fill="none" d="M14 27 L23 36 L38 18" />
      </svg>
    </div>
  );
}

export default function EmptyState({ title, subtitle }) {
  return (
    <div className="empty-state">
      <RadarPulse />
      <div>
        <p className="text-sm uppercase tracking-[0.3em] text-emerald-300">
          {title}
        </p>
        <p className="text-xs text-slate-500 mt-2">{subtitle}</p>
      </div>
    </div>
  );
}
