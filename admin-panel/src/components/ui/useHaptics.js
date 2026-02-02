export const useHaptics = () => {
  const trigger = (duration = 14) => {
    if (navigator?.vibrate) {
      navigator.vibrate(duration);
    }
  };

  return { trigger };
};
