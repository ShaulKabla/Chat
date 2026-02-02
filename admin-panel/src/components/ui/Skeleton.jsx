export function SkeletonLine({ className = "" }) {
  return <div className={`skeleton-line ${className}`} />;
}

export function SkeletonCard() {
  return (
    <div className="glass-panel p-5 space-y-3">
      <SkeletonLine className="w-24" />
      <SkeletonLine className="w-32 h-8" />
      <SkeletonLine className="w-16" />
    </div>
  );
}
