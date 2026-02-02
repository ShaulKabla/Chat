import { useHaptics } from "./useHaptics";

export default function GradientButton({ className = "", onClick, children, ...props }) {
  const { trigger } = useHaptics();

  const handleClick = (event) => {
    trigger();
    onClick?.(event);
  };

  return (
    <button
      {...props}
      onClick={handleClick}
      className={`gradient-button ${className}`}
    >
      {children}
    </button>
  );
}
