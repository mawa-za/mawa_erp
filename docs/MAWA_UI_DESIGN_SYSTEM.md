# MAWA ERP Visual Design System

This release applies the approved professional MAWA look and feel across the ERP application.

## Application-wide review scope

- 108 screen/page source files reviewed.
- 74 dialog-bearing source files reviewed.
- 118 card-bearing source files reviewed.
- Home dashboard and all feature-group pages redesigned explicitly.
- Funeral Arrangement Wizard package step, stepper, cost summary and Add Extra dialog redesigned explicitly.
- Login experience redesigned explicitly.
- All remaining pages inherit the shared theme for page background, app bars, typography, cards, forms, buttons, tabs, tables, navigation, dialogs, bottom sheets, chips, snackbars, scrollbars and status components.

## Visual principles

1. **Clear hierarchy** — deep navy titles, restrained red actions and readable muted supporting text.
2. **Consistent geometry** — 16 px cards, 20 px dialogs and 10 px form/button radii.
3. **Consistent card dimensions** — workcenter grids use fixed visual heights rather than variable aspect ratios.
4. **Purposeful descriptions** — group and workcenter cards explain the business outcome rather than merely repeat the title.
5. **Professional density** — generous whitespace without wasting operational screen space.
6. **Responsive composition** — desktop side navigation, adaptive grids and stacked mobile/tablet layouts.
7. **Accessible actions** — clear primary, secondary, destructive and disabled states.

## Shared tokens

The semantic colours, spacing, radii, shadows and responsive breakpoints are defined in:

- `lib/core/theme/mawa_design.dart`
- `lib/core/theme/app_theme.dart`

Reusable presentation components are defined in:

- `lib/core/widgets/mawa_ui.dart`

New pages should use these tokens and components instead of introducing new hardcoded colours, radii or shadows.

## Page standards

- Pages use the MAWA light grey canvas and white content surfaces.
- App bars are 68 px high with a subtle divider and no heavy elevation.
- Content should be centred and constrained on very wide monitors.
- Page titles use `headlineMedium`; section titles use `titleLarge`.
- List and detail pages should group related data in cards or clearly separated sections.
- Empty states should explain what is missing and what the user can do next.

## Dialog standards

- Maximum practical width should be used rather than full-screen desktop dialogs.
- Dialogs use a clear icon/title/supporting-text header.
- Form fields are vertically aligned with 16 px spacing.
- Actions are separated from content and use `Cancel` plus one clear primary action.
- Destructive actions use the MAWA red/error treatment and require confirmation.

## Card description standards

Descriptions should answer: **What can I accomplish here?**

Avoid generic text such as “Manage records”. Prefer outcome-focused text such as:

> Coordinate every funeral service stage, from collection and mortuary care to arrangements, claims, invoicing and payment.
