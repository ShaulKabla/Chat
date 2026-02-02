# Design System — Anon Chat Premium UI

## Color Palette
- **Deep Obsidian**: `#050505`
- **Electric Emerald (Accent)**: `#00E676`
- **Glass Surface**: `rgba(255, 255, 255, 0.08)`
- **Glass Border**: `rgba(148, 163, 184, 0.2)`
- **Glow**: `rgba(0, 230, 118, 0.35)`

## Typography
- **Base Font**: Inter, `font-weight: 400`
- **Headings**: `font-weight: 600`
- **Caps/Overline**: `letter-spacing: 0.2em - 0.35em`

## Spacing Scale
- `--space-xs`: 0.5rem
- `--space-sm`: 0.75rem
- `--space-md`: 1rem
- `--space-lg`: 1.5rem
- `--space-xl`: 2rem
- `--space-2xl`: 3rem

## Radius
- `--radius-sm`: 0.75rem
- `--radius-md`: 1rem
- `--radius-lg`: 1.5rem
- `--radius-xl`: 2rem

## Shadows & Glass
- Soft shadow: `0 24px 60px rgba(3, 7, 18, 0.6)`
- Glass blur: `backdrop-filter: blur(22px)`

## Animation Tokens
- **Pop In**: `550ms cubic-bezier(0.2, 0.7, 0.2, 1)`
- **Glow Pulse**: `2.6s ease-in-out infinite`
- **Skeleton Pulse**: `1.4s ease-in-out infinite`

## Micro-Interactions
- Double-tap/Double-click toggles a “reaction.”
- Swipe/drag reveals a “Reply” affordance.
- Haptic feedback (via `navigator.vibrate`) for buttons and state changes.
