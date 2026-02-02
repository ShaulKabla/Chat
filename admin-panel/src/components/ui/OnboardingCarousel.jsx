import { useEffect, useState } from "react";

const steps = [
  {
    title: "Stay Anonymous",
    copy: "Your identity is never shared. Enjoy conversations without pressure."
  },
  {
    title: "Be Respectful",
    copy: "Kindness is mandatory. Report abuse to keep the space safe."
  },
  {
    title: "Start Chatting",
    copy: "Jump into the queue and let the radar pair you instantly."
  }
];

export default function OnboardingCarousel() {
  const [active, setActive] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => {
      setActive((prev) => (prev + 1) % steps.length);
    }, 4000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="glass-panel p-6 space-y-4">
      <div className="text-xs uppercase tracking-[0.35em] text-emerald-400">
        Onboarding
      </div>
      <div className="space-y-3">
        {steps.map((step, index) => (
          <div
            key={step.title}
            className={`onboarding-step ${index === active ? "active" : ""}`}
          >
            <h3 className="text-lg font-semibold text-slate-50">{step.title}</h3>
            <p className="text-sm text-slate-400">{step.copy}</p>
          </div>
        ))}
      </div>
      <div className="flex gap-2">
        {steps.map((step, index) => (
          <span
            key={step.title}
            className={`h-1.5 w-6 rounded-full transition-all duration-300 ${
              index === active ? "bg-emerald-400" : "bg-slate-700"
            }`}
          />
        ))}
      </div>
    </div>
  );
}
