# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Eole
**Generated:** 2026-08-07 22:46:44
**Updated:** 2026-08-14
**Category:** Guided breathwork and meditation
**Direction:** Clarte aquatique - quiet, precise, reassuring
**Design Dials:** Variance 4/10 | Motion 3/10 | Density 4/10

---

## Global Rules

### Color Palette

| Role | Hex | CSS Variable |
|------|-----|--------------|
| Primary | `#087D9D` | `--color-primary` |
| On Primary | `#FFFFFF` | `--color-on-primary` |
| Secondary | `#35B7CA` | `--color-secondary` |
| Accent/CTA | `#7FD4DC` | `--color-accent` |
| Background | `#EEF7F9` | `--color-background` |
| Surface | `#FFFFFF` | `--color-surface` |
| Surface soft | `#E6F3F6` | `--color-surface-soft` |
| Foreground | `#102F3B` | `--color-foreground` |
| Muted text | `#59737D` | `--color-muted` |
| Border | `#D7E8EC` | `--color-border` |
| Destructive | `#B64343` | `--color-danger` |
| Ring | `#087D9D` | `--color-ring` |

**Color Notes:** Water blue and soft cyan. White surfaces stay translucent only when they improve hierarchy; they never exist as decorative glass alone.

### Typography

- **Heading Font:** Iowan Old Style, puis Palatino/Georgia
- **Body Font:** Avenir Next, puis Avenir/Segoe UI
- **Mood:** calm, wellness, health, relaxing, natural, organic
- **Chargement:** polices système uniquement, pour un affichage immédiat et sans dépendance réseau.

### Spacing Variables

*Density: 4/10 — Standard*

| Token | Value | Usage |
|-------|-------|-------|
| `--space-xs` | `4px` / `0.25rem` | Tight gaps |
| `--space-sm` | `8px` / `0.5rem` | Icon gaps, inline spacing |
| `--space-md` | `16px` / `1rem` | Standard padding |
| `--space-lg` | `24px` / `1.5rem` | Section padding |
| `--space-xl` | `32px` / `2rem` | Large gaps |
| `--space-2xl` | `48px` / `3rem` | Section margins |
| `--space-3xl` | `64px` / `4rem` | Hero padding |

### Shape and depth

| Token | Value | Usage |
|-------|-------|-------|
| `--radius-sm` | `12px` | Controls and navigation |
| `--radius-md` | `20px` | Cards and grouped controls |
| `--radius-lg` | `28px` | Hero and large sections |
| `--shadow-soft` | `0 10px 32px rgba(31,78,91,.055)` | Quiet separation |
| `--shadow-float` | `0 18px 52px rgba(18,79,94,.09)` | Hero or important overlay only |

---

## Component Specs

### Buttons

```css
/* Primary Button */
.btn-primary {
  background: #087D9D;
  color: white;
  padding: 12px 24px;
  border-radius: 999px;
  font-weight: 650;
  transition: transform 120ms cubic-bezier(0, 0, .2, 1), background-color 200ms cubic-bezier(0, 0, .2, 1);
  cursor: pointer;
}

.btn-primary:hover {
  transform: translateY(-1px);
}

/* Secondary Button */
.btn-secondary {
  background: #E6F3F6;
  color: #075E77;
  border: 1px solid #D7E8EC;
  padding: 12px 24px;
  border-radius: 999px;
  font-weight: 650;
  transition: background-color 200ms cubic-bezier(0, 0, .2, 1);
  cursor: pointer;
}
```

### Cards

```css
.card {
  background: #FFFFFF;
  border: 1px solid #D7E8EC;
  border-radius: 20px;
  padding: 24px;
  box-shadow: var(--shadow-soft);
  transition: transform 120ms cubic-bezier(0, 0, .2, 1), box-shadow 200ms cubic-bezier(0, 0, .2, 1);
}

.card[href]:hover,
button.card:hover {
  transform: translateY(-1px);
}
```

### Inputs

```css
.input {
  padding: 12px 16px;
  border: 1px solid #D7E8EC;
  border-radius: 12px;
  font-size: 16px;
  transition: border-color 200ms ease;
}

.input:focus {
  border-color: #087D9D;
  outline: none;
  box-shadow: 0 0 0 3px #087D9D33;
}
```

### Modals

```css
.modal-overlay {
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
}

.modal {
  background: white;
  border-radius: 28px;
  padding: 32px;
  box-shadow: var(--shadow-float);
  max-width: 500px;
  width: 90%;
}
```

---

## Style Guidelines

**Style:** Quiet aquatic clarity

**Keywords:** calm, restrained, spacious, legible, tactile, natural, accessible

**Best For:** Modern enterprise apps, SaaS platforms, health/wellness, modern business tools, professional, hybrid

**Key Effects:** gentle tonal hierarchy, very soft depth, short state transitions, visible focus, WCAG AA

### Page Pattern

**Pattern Name:** Immediate guided practice

- **Primary path:** one-tap start from the home screen with a safe default protocol.
- **Secondary path:** adjust the protocol without competing with the start action.
- **During practice:** one dominant visual, one instruction, progress kept secondary.
- **After practice:** factual result and a quiet next action; no gamification pressure.

---

## Motion

- Page entry: opacity only, `320ms`, standard ease-out.
- Interaction feedback: `120-200ms`; never animate layout dimensions.
- Session phase transitions: `520ms`, smooth ease-in-out.
- Continuous motion is reserved for the active breathing guide and explicit loading states.
- `prefers-reduced-motion` removes every decorative and page-entry animation.

### Audio

- Breath cues target about `-34 LUFS` so they guide without startling.
- Ambient loops target about `-30 LUFS`, then are attenuated by the user-controlled gain.
- True peaks stay below `-3 dBTP` and every loop uses soft fades.
- Startup loads only the two breath cues and the selected ambience; other ambiences load on demand.

---

## Anti-Patterns (Do NOT Use)

- ❌ Inconsistent styling
- ❌ Poor contrast ratios

### Additional Forbidden Patterns

- ❌ **Emojis as icons** — Use SVG icons (Heroicons, Lucide, Simple Icons)
- ❌ **Missing cursor:pointer** — All clickable elements must have cursor:pointer
- ❌ **Layout-shifting hovers** — Avoid scale transforms that shift layout
- ❌ **Low contrast text** — Maintain 4.5:1 minimum contrast ratio
- ❌ **Instant state changes** — Always use transitions (150-300ms)
- ❌ **Invisible focus states** — Focus states must be visible for a11y

---

## Pre-Delivery Checklist

Before delivering any UI code, verify:

- [ ] No emojis used as icons (use SVG instead)
- [ ] All icons from consistent icon set (Heroicons/Lucide)
- [ ] `cursor-pointer` on all clickable elements
- [ ] Hover states with smooth transitions (150-300ms)
- [ ] Light mode: text contrast 4.5:1 minimum
- [ ] Focus states visible for keyboard navigation
- [ ] `prefers-reduced-motion` respected
- [ ] Responsive: 375px, 768px, 1024px, 1440px
- [ ] No content hidden behind fixed navbars
- [ ] No horizontal scroll on mobile
