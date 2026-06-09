---
name: Asansor Executive
colors:
  surface: '#f7fafd'
  surface-dim: '#d7dadd'
  surface-bright: '#f7fafd'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f1f4f7'
  surface-container: '#ebeef1'
  surface-container-high: '#e5e8eb'
  surface-container-highest: '#e0e3e6'
  on-surface: '#181c1e'
  on-surface-variant: '#42474f'
  inverse-surface: '#2d3133'
  inverse-on-surface: '#eef1f4'
  outline: '#727780'
  outline-variant: '#c2c7d1'
  surface-tint: '#2d6197'
  primary: '#00355f'
  on-primary: '#ffffff'
  primary-container: '#0f4c81'
  on-primary-container: '#8ebdf9'
  inverse-primary: '#a0c9ff'
  secondary: '#43617e'
  on-secondary: '#ffffff'
  secondary-container: '#beddff'
  on-secondary-container: '#43627f'
  tertiary: '#755b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#cea62c'
  on-tertiary-container: '#4f3d00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d2e4ff'
  primary-fixed-dim: '#a0c9ff'
  on-primary-fixed: '#001c37'
  on-primary-fixed-variant: '#07497d'
  secondary-fixed: '#cee5ff'
  secondary-fixed-dim: '#aacaeb'
  on-secondary-fixed: '#001d33'
  on-secondary-fixed-variant: '#2a4965'
  tertiary-fixed: '#ffe08e'
  tertiary-fixed-dim: '#ecc246'
  on-tertiary-fixed: '#241a00'
  on-tertiary-fixed-variant: '#584400'
  background: '#f7fafd'
  on-background: '#181c1e'
  surface-variant: '#e0e3e6'
typography:
  display-lg:
    fontFamily: Nunito Sans
    fontSize: 36px
    fontWeight: '800'
    lineHeight: 44px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Nunito Sans
    fontSize: 28px
    fontWeight: '800'
    lineHeight: 36px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Nunito Sans
    fontSize: 22px
    fontWeight: '800'
    lineHeight: 28px
  headline-sm:
    fontFamily: Nunito Sans
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 24px
  body-lg:
    fontFamily: Nunito Sans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 24px
  body-md:
    fontFamily: Nunito Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-lg:
    fontFamily: Nunito Sans
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 20px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Nunito Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.04em
  headline-lg-mobile:
    fontFamily: Nunito Sans
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 32px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  container-padding: 20px
  stack-gap-sm: 8px
  stack-gap-md: 16px
  stack-gap-lg: 24px
  grid-gutter: 16px
  panel-padding: 24px
---

## Brand & Style

This design system is built on the pillars of **reliability, precision, and architectural elegance**. Designed specifically for high-stakes elevator maintenance and fault management, the aesthetic balances the industrial nature of the hardware with a premium, executive digital experience. 

The visual direction employs a **Refined Corporate** style. It rejects the coldness of traditional enterprise software in favor of "Soft-Touch Professionalism." This is achieved through generous whitespace, high-quality typography, and a "Glass-Industrial" approach—where structural elements feel solid and dependable, yet surfaces possess a subtle translucency and depth that suggests modern sophistication. 

The target audience—technicians and facility managers—should feel a sense of calm and control. The UI remains utilitarian at its core but presents information with an editorial level of clarity and prestige.

## Colors

The palette is anchored by **Primary Navy (#0F4C81)**, a color of trust and stability, and **Dark Navy (#0B2F4A)** for high-contrast text and structural elements. **Accent Gold (#C9A227)** is used sparingly to denote status, premium features, or critical focus points, providing a sophisticated warmth against the cool blues.

The background uses a soft, off-white **#F4F7FA** to reduce eye strain during long shifts, while the **Surface White (#FFFFFF)** provides clear elevation for cards and interactive panels. Functional colors for alerts (Success, Warning, Error) should be desaturated to maintain the professional tone, avoiding neon or overly vibrant hues.

## Typography

The typography system relies exclusively on **Nunito Sans** to ensure a cohesive, modern feel. The hierarchy is driven by extreme weight contrast: **Extra Bold (800)** for titles creates an authoritative, "architectural" header style, while **Medium (500)** is used for body copy to ensure optimal legibility and a softer, more approachable reading experience than standard weights.

Labels and small metadata should utilize **Semi-Bold (600)** or **Bold (700)** with slight letter spacing to maintain clarity on mobile screens. All headlines utilize a tighter letter spacing to feel more "locked-in" and intentional.

## Layout & Spacing

This design system uses a **Fluid Mobile-First Grid** with a 4-column structure for phone views. The spacing rhythm is based on an **8px base unit**, emphasizing "High-Quality Spacing"—meaning margins are slightly more generous than typical utility apps to evoke a premium feel.

- **Safe Zones:** Always maintain a minimum 20px horizontal margin from the screen edge.
- **Vertical Rhythm:** Use 24px (stack-gap-lg) to separate major sections/cards and 16px (stack-gap-md) for elements within a group.
- **Content Density:** Maintain a "breathable" layout. Never crowd fault descriptions or technical data; use generous padding within cards to ensure the interface feels expensive and organized.

## Elevation & Depth

Hierarchy is established through **Tonal Layering and Soft Shadows**. 

1. **The Base:** The #F4F7FA background acts as the canvas.
2. **The Panel Layer:** Primary content cards use #FFFFFF with a very soft, diffused shadow: `0px 10px 30px rgba(15, 76, 129, 0.06)`. This subtle navy tint in the shadow tethers the surface to the brand color.
3. **The Glass Layer:** For top navigation bars or floating action buttons, use a "Glassmorphism" effect: `rgba(255, 255, 255, 0.8)` background with a `20px` backdrop blur. This provides a sense of modernity and depth without clutter.
4. **Active States:** When an element is pressed, it should "sink" visually, reducing the shadow and slightly darkening the surface color.

## Shapes

The shape language is sophisticated and modern, moving away from sharp industrial corners toward more human-centric, rounded forms.

- **Main Panels/Cards:** 22px (Custom roundedness for a soft, containerized feel).
- **Interactive Inputs:** 14px (Balanced for precision and touch-friendliness).
- **Buttons:** 16px (Provides a distinct shape that separates action from data entry).
- **Icons:** Use a 2px stroke weight with rounded terminals to match the typography's softness.

## Components

### Buttons
- **Primary:** Solid #0F4C81, White text, 16px corners. High-elevation shadow.
- **Secondary:** Outline #0F4C81, 2px stroke. No shadow.
- **Tertiary/Ghost:** Dark Navy text, no background. Used for "Cancel" or "Back."

### Cards & Panels
Main data containers must use the 22px corner radius. They should feature a 1px inner border in #E1E8F0 to define the edge against the background, especially for glass surfaces.

### Input Fields
Inputs use a 14px radius and a light grey background (#EDF2F7). On focus, the border transitions to Primary Navy with a subtle 4px outer glow in the same color (10% opacity). Labels sit above the field in Label-LG Bold.

### Chips & Status Indicators
Status chips (e.g., "In Progress," "Fault Detected") use a 100px pill shape. They should utilize low-saturation background tints with high-contrast text for professional readability.

### Task List Items
List items should have a subtle separator line (1px, #E1E8F0) and utilize the Secondary Navy for icons to signify a "technical" utility.

### Specialty: Fault Gauge
For elevator metrics, use a custom radial gauge with a 4px stroke, utilizing the Accent Gold to highlight the current performance value against a Navy background.