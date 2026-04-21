# Design System Strategy: Monolithic Precision

## 1. Overview & Creative North Star
The Creative North Star for this design system is **"The Mathematical Gallery."** 

In an idle game focused on 'Number,' the interface must not feel like a toy; it must feel like a high-end precision instrument or a digital exhibition. We are moving away from the "gamified" clutter of traditional idle games and toward a sleek, editorial aesthetic. We achieve this through **Monolithic Precision**: a layout strategy that favors intentional white space (or "dark space"), extreme typographic scale, and a rejection of traditional UI containers.

The goal is to make the player feel like they are interacting with a living piece of kinetic typography. We break the template look by using **Asymmetric Composition**—heavy numbers might sit flush against a left margin while action buttons float with generous, "expensive" padding on the right.

---

## 2. Colors & Surface Logic
This system utilizes a monochromatic palette to enforce a sense of authority and focus. Color is used only as a functional alert (Error), never for decoration.

### The "No-Line" Rule
**Explicit Instruction:** You are prohibited from using 1px solid borders to section off content. In this design system, boundaries are defined strictly through background shifts. 
- To separate a header from a list, transition the background from `surface` (#131313) to `surface-container-low` (#1b1b1b).
- This creates a seamless, "molded" look rather than a "boxed-in" feel.

### Surface Hierarchy & Nesting
Treat the UI as a series of nested obsidian slabs. 
1. **Base Layer:** `surface` (#131313).
2. **Primary Content Areas:** `surface-container` (#1f1f1f).
3. **Elevated Interactions:** `surface-container-high` (#2a2a2a).
4. **Floating Overlays:** Use `surface-bright` (#393939) with a 20px `backdrop-blur` to create a "Glassmorphism" effect, allowing the numbers beneath to bleed through softly.

### Signature Textures
To prevent the black from feeling "dead," apply a subtle linear gradient to large CTA buttons, transitioning from `primary` (#ffffff) to `primary-container` (#d4d4d4). This provides a slight metallic sheen that feels premium and tactile.

---

## 3. Typography
Typography is the primary visual asset of this game. We use two sans-serifs to create a technical yet sophisticated hierarchy.

- **Display & Headlines (Space Grotesk):** This is our "hero" font. Its geometric quirks represent the mathematical nature of the game. Use `display-lg` for the main "Number" count to make it feel like a monumental architectural element.
- **Body & Labels (Manrope):** A clean, high-legibility sans-serif used for data, upgrades, and descriptions. Its modern proportions ensure that even at `label-sm`, the text remains crisp.

**Editorial Rule:** Use extreme contrast in size. Pair a `display-lg` number with a `label-sm` unit descriptor (e.g., "TRIILLION") to create a high-fashion editorial look.

---

## 4. Elevation & Depth
We eschew traditional shadows for **Tonal Layering**.

- **The Layering Principle:** Depth is achieved by "stacking." A card is not a box with a shadow; it is a `surface-container-lowest` (#0e0e0e) shape sitting on a `surface-container` (#1f1f1f) background. This "sunken" or "raised" effect feels more integrated into the hardware.
- **Ambient Shadows:** For floating modals, use an expansive blur (40px+) at 8% opacity using the `on-surface` color. It should feel like a soft glow of light blocked by the element, not a "drop shadow."
- **The "Ghost Border" Fallback:** If accessibility requires a stroke, use the `outline-variant` (#474747) at 15% opacity. Never use a 100% opaque border.

---

## 5. Components

### Buttons
- **Primary:** Solid `primary` (#ffffff) with `on-primary` (#1a1c1c) text. Use `rounded-sm` (2px) for a sharp, architectural look.
- **Secondary (Outlined):** A 1.5px stroke of `primary` (#ffffff). No fill. This is for secondary actions like "Max Buy."
- **Tertiary:** Text-only, using `title-sm` with a subtle `primary` underline, spaced 4px below the baseline.

### Cards & Progress Bars
- **Progress Tracking:** Since we forbid dividers, progress bars should be full-bleed. Use `surface-container-highest` as the track and `primary` as the fill. 
- **Card Separations:** Use vertical white space (32px or 48px) instead of lines. Use `surface-container-low` to grouping related upgrades.

### Floating Numbers (Idle Game Specific)
- **The "Pulse":** When numbers increment, do not use pop-up animations. Use a subtle opacity shift or a scale-up of 1.05x using a "Standard Decelerate" easing curve.

---

## 6. Do's and Don'ts

### Do
- **DO** use `surface-container-lowest` for the main gameplay area to give a sense of infinite depth.
- **DO** lean into asymmetry. A number aligned to the far left with a label on the far right creates a premium "Swiss Style" tension.
- **DO** use `backdrop-blur` on all navigation bars to maintain the "Mathematical Gallery" atmosphere.

### Don't
- **DON'T** use 1px dividers. If you feel the need for a line, use a 16px gap of background color instead.
- **DON'T** use icons unless absolutely necessary. Rely on the strength of the typography (e.g., use "MAX" instead of an arrow icon).
- **DON'T** use standard "Rounded" corners. Stick to `sm` (0.125rem) or `none` for a sharp, modern edge. High roundedness (e.g., `full`) is only for selection chips.

---

## 7. Interaction & Motion
Transitions must be "Liquid yet Heavy." 
- **Surface Transitions:** When a menu opens, use a vertical slide with a "staggered" fade-in for text elements. 
- **Haptic Polish:** Every interaction with a "Number" should feel like a physical click. The UI should react with high-contrast state changes (e.g., a button flash from White to `secondary-fixed-dim` upon press).