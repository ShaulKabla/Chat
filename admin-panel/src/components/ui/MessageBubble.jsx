import { useState } from "react";
import { useHaptics } from "./useHaptics";

export default function MessageBubble({ entry }) {
  const [liked, setLiked] = useState(false);
  const [swipeOffset, setSwipeOffset] = useState(0);
  const { trigger } = useHaptics();

  const handleDoubleClick = () => {
    trigger();
    setLiked((prev) => !prev);
  };

  const handlePointerDown = (event) => {
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const handlePointerMove = (event) => {
    if (event.pressure === 0) return;
    const offset = Math.max(0, Math.min(80, event.movementX + swipeOffset));
    setSwipeOffset(offset);
  };

  const handlePointerUp = () => {
    setSwipeOffset(0);
  };

  return (
    <div
      className={`message-bubble ${entry.level === "error" ? "incoming" : "outgoing"}`}
      onDoubleClick={handleDoubleClick}
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      style={{ transform: `translateX(${swipeOffset}px)` }}
    >
      <div className="flex items-center justify-between text-[0.6rem] uppercase tracking-[0.2em] text-slate-400">
        <span>{new Date(entry.timestamp).toLocaleString()}</span>
        <span>{entry.level}</span>
      </div>
      <p className="text-sm text-slate-100 mt-2">{entry.message}</p>
      {entry.meta && (
        <p className="text-xs text-slate-500 mt-2 break-words">{entry.meta}</p>
      )}
      <div className={`reaction ${liked ? "active" : ""}`}>💚</div>
      <div className={`reply-indicator ${swipeOffset > 30 ? "visible" : ""}`}>
        Reply
      </div>
    </div>
  );
}
