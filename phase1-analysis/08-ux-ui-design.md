UX/UI Design Strategy — summary of design decisions:

---

**SECTION 1 — EXECUTIVE SUMMARY**
Three design pillars that resolve the core paradox (security must be invisible): Ambient Security Signals, Risk-Proportionate Interruption, and Native iOS Quality at Every Layer.

**SECTION 2 — VISUAL DESIGN LANGUAGE**
The full color system is built on an indigo-adjacent primary (#3D5AFE / #6979F8 dark) that reads as sophisticated and premium rather than generic enterprise blue. The classification system uses distinct color families — green, blue, amber, rose — that avoid confusion with system colors and hold contrast ratios above 4.5:1 in both modes. Typography is SF Pro throughout (13 named text styles). Every token is a multiple of 4pt.

**SECTION 3 — DESIGN TOKENS**
Every token listed with explicit light and dark values: 54 color tokens, 14 font tokens, 10 spacing tokens, 7 radius tokens, 6 shadow tokens, 10 motion tokens, 5 border tokens, and touch target tokens.

**SECTION 4 — COMPONENT LIBRARY**
9 Priority 1 components and 6 Priority 2 components, each with full anatomy, all states, sizing, and localization/accessibility rules. The Sensitivity Badge is the most critical: 11pt Caption 2 Semibold all-caps, verified WCAG AA in both modes at its 20pt minimum height.

**SECTION 5 — ANIMATION SYSTEM**
Every animation has explicit SwiftUI parameters: entry (0.3s easeOut, +20pt Y offset), exit (0.2s easeIn, 0.92 scale), button press-down (spring response:0.25 dampingFraction:0.8), button release bounce (response:0.35 dampingFraction:0.65), tab bounce (response:0.4 dampingFraction:0.55), critical alert entry (response:0.45 dampingFraction:0.72). List stagger: 40ms per row, capped at 200ms total.

**SECTION 6 — SCREEN STRUCTURE**
27-screen layout structure, frame naming convention (Screen/Device/Mode/State), component naming convention, and layout rules.

**SECTION 7 — 18 SCREEN SPECS**
Each screen has: layout structure with exact measurements, all component references, all states (empty/loading/error/offline/admin), specific animation choreography, and iPhone-vs-iPad differences.

**SECTIONS 8-12 — FLOW MAP, PROTOTYPE, DARK MODE, ROLE VARIANTS, iPAD RULES**
The interaction flow map is fully specified. The five priority prototype flows are chosen to demonstrate the core product narrative. Dark mode contrast ratios are verified for all five classification levels. Enterprise admin vs standard user differences are enumerated component-by-component. iPad rules cover SplitView dimensions, multi-column triggers, and Stage Manager minimum window widths.

The design decisions here inform the HTML prototype and Swift implementation.