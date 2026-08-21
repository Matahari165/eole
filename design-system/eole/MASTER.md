# Design System Master File

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Eole
**Generated:** 2026-08-07 22:46:44
**Updated:** 2026-08-21
**Category:** Guided breathwork and meditation
**Direction:** Souffle ouvert - natural, minimal, quietly alive
**Design Dials:** Variance 3/10 | Motion 3/10 | Density 4/10

---

## Global Rules

### Color Palette

| Role | Hex | CSS Variable |
|------|-----|--------------|
| Primary | `#176F65` | `--color-primary` |
| On Primary | `#FFFFFF` | `--color-on-primary` |
| Secondary | `#84B8A8` | `--color-secondary` |
| Accent/CTA | `#BAD7CC` | `--color-accent` |
| Background | `#EFF4F1` | `--color-background` |
| Surface | `#FFFFFF` | `--color-surface` |
| Surface soft | `#E5EEEA` | `--color-surface-soft` |
| Foreground | `#17332E` | `--color-foreground` |
| Muted text | `#5F726C` | `--color-muted` |
| Border | `#D6E1DC` | `--color-border` |
| Destructive | `#B64343` | `--color-danger` |
| Ring | `#176F65` | `--color-ring` |

**Color Notes:** Mineral green and quiet plant neutrals. The accent stays functional; translucent white surfaces create hierarchy without becoming decorative glass objects.

### Typography

- **Heading Font:** Avenir Next, puis Avenir/Segoe UI
- **Body Font:** Avenir Next, puis Avenir/Segoe UI
- **Mood:** calm, breathing, natural, minimal, tactile
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
| `--radius-sm` | `10px` | Controls and navigation |
| `--radius-md` | `16px` | Cards and grouped controls |
| `--radius-lg` | `22px` | Hero and large sections |
| `--shadow-soft` | `0 12px 36px rgba(38,73,64,.055)` | Quiet separation |
| `--shadow-float` | `0 22px 64px rgba(29,69,60,.1)` | Hero or important overlay only |

---

## Component Specs

### Buttons

```css
/* Primary Button */
.btn-primary {
  background: #176F65;
  color: white;
  padding: 12px 24px;
  border-radius: 13px;
  font-weight: 650;
  transition: transform 120ms cubic-bezier(0, 0, .2, 1), background-color 200ms cubic-bezier(0, 0, .2, 1);
  cursor: pointer;
}

.btn-primary:hover {
  transform: translateY(-1px);
}

/* Secondary Button */
.btn-secondary {
  background: #E5EEEA;
  color: #0C514B;
  border: 1px solid #D6E1DC;
  padding: 12px 24px;
  border-radius: 13px;
  font-weight: 650;
  transition: background-color 200ms cubic-bezier(0, 0, .2, 1);
  cursor: pointer;
}
```

### Cards

```css
.card {
  background: #FFFFFF;
  border: 1px solid #D6E1DC;
  border-radius: 16px;
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
  border: 1px solid #D6E1DC;
  border-radius: 10px;
  font-size: 16px;
  transition: border-color 200ms ease;
}

.input:focus {
  border-color: #176F65;
  outline: none;
  box-shadow: 0 0 0 3px #176F6533;
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
  border-radius: 22px;
  padding: 32px;
  box-shadow: var(--shadow-float);
  max-width: 500px;
  width: 90%;
}
```

---

## Style Guidelines

**Style:** Open breath

**Keywords:** calm, restrained, breathable, legible, tactile, natural, accessible

**Best For:** Modern enterprise apps, SaaS platforms, health/wellness, modern business tools, professional, hybrid

**Key Effects:** open two-stroke breath mark, mineral glass, very soft depth, short state transitions, visible focus, WCAG AA

### Page Pattern

**Pattern Name:** Immediate guided practice

- **Primary path:** one-tap start from the home screen with a safe default protocol.
- **Secondary path:** adjust the protocol without competing with the start action.
- **During practice:** one dominant visual, one instruction, progress kept secondary.
- **After practice:** factual result and a quiet next action; no gamification pressure.

### Premium experience rules

- Only the current practice phase is mounted and animated. Hidden phases never consume rendering work or remain exposed to assistive technologies.
- The breathing guide owns the continuous motion. Other screens use short transitions for feedback and continuity only.
- Ambient sound fades in over several seconds and automatically steps back under breath cues and bells.
- Mobile translucent surfaces become near-solid to protect readability and reduce costly backdrop compositing.
- Greeting and loading copy remain stable between server render and hydration to avoid visual shifts.

---

## Motion

- Page entry: opacity only, `320ms`, standard ease-out.
- Interaction feedback: `120-200ms`; never animate layout dimensions.
- Session phase transitions: background crossfade `520ms`; phase content enter `360ms`.
- Continuous motion is reserved for the active breathing guide and explicit loading states.
- `prefers-reduced-motion` removes every decorative and page-entry animation.

### Audio

- Breath cues target about `-34 LUFS` so they guide without startling.
- Ambient loops target about `-30 LUFS`, then are attenuated by the user-controlled gain.
- True peaks stay below `-3 dBTP` and every loop uses soft fades.
- Startup loads only the two breath cues and the selected ambience; other ambiences load on demand.
- Ambience fade-in: `2.4s`; fade-out: `850ms`; track crossfade: `1.8s`.
- Breath cues and bells duck ambience temporarily instead of competing for attention.

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
- ❌ **Leaf, lotus, wave, or generic wellness symbols as branding** — Use the open breath mark
- ❌ **Baked-in icon background, frame, shadow, or gradient** — Keep every logo asset transparent

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
