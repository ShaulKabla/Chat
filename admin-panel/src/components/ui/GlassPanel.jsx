export default function GlassPanel({ children, className = "" }) {
  return (
    <div className={`glass-panel glow-border ${className}`}>
      {children}
    </div>
  );
}
