# PROJECT

Consolidated internal working docs for MidnightTracker (architecture/state, dev rules, TODO, issues, testing, and the dev changelog all live here in one file). CLAUDE.md and the root CHANGELOG.md remain separate — CLAUDE.md is auto-loaded by Claude Code, and CHANGELOG.md is a standard convention file external tools (CurseForge, GitHub releases) expect to find under that exact name.

## Table of Contents
- [Addon Context](#addon-context)
- [Dev Rules](#dev-rules)
- [TODO](#todo)
- [Issues](#issues)
- [Testing](#testing)
- [Changelog (Dev)](#changelog-dev)

---

## Addon Context

### Addon Identity
- Addon Name: MidnightTracker
- Primary Purpose: Comprehensive currency and weekly-activity tracker spanning Midnight and prior expansions (Great Vault, crests, PvP, seasonal currencies), shown via a minimap tooltip and an optional on-screen display
- Expansion Target: Midnight (Interface 120001)

### Core Features
- Multi-expansion currency tracking (Midnight, War Within, Dragonflight, Shadowlands, BFA, Legion, WoD, MoP, Cataclysm, WotLK, BC, PvP, Seasonal), organized by category with per-category and per-currency toggles
- Minimap icon (LibDBIcon) with a hover tooltip listing tracked currencies and Great Vault progress
- Optional on-screen display frame (separate from the minimap tooltip) with configurable position, scale, icons-per-row, icon size, font size, border/background
- Great Vault progress tracking (Raid, Mythic+, World/Delves) with visual progress bars
- Zone-based currency filtering (toggle, currently off by default — no Midnight zone detection yet)
- Custom-built settings UI (Config.lua: sliders, checkboxes, buttons) — no Blizzard Settings templates
- Slash command interface (`/mtrack`, `/midnighttracker`, `/mtk`)

### Architecture Overview
- `MidnightTracker.toc` — addon manifest; Interface 120001; load order is Libs → Data → Core → Tracker → Minimap → Display → Config
- `Data.lua` — static currency/category definitions per expansion (`addon.Data.Currencies`, `addon.Data.Categories`); data only, no logic
- `Core.lua` — addon namespace/init, SavedVariables defaults + `InitializeDefaults` merge, one-time settings-repair pass (`settingsRepairV2`), event handling (`PLAYER_LOGIN`, etc.), slash command handler and help text
- `Tracker.lua` — data fetching/caching layer: currency state via `C_CurrencyInfo`, Great Vault via `C_WeeklyRewards`, quest/item helpers via `C_QuestLog`/`C_Item`; zone-relevance and expansion-detection logic; builds the combined trackables list consumed by Minimap/Display
- `Minimap.lua` — LibDataBroker data object + LibDBIcon minimap button; builds and populates the hover tooltip (currency lines, Great Vault progress bars)
- `Display.lua` — standalone on-screen display frame; custom text lines, Great Vault section, position save/restore, show/hide/toggle
- `Config.lua` — fully custom settings UI (sliders, checkboxes, buttons, borders) for Display/General/Expansion category settings; no Blizzard UI templates
- `Libs/` — embedded third-party: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 — not linted or edited

### SavedVariables
`MidnightTrackerDB` (account-wide, `## SavedVariables` in the .toc), defaults centralized in `Core.lua`:
- `minimap` — `hide`, `minimapPos`, `lock`
- `display` — `hidden`, `point`/`relativePoint`/`xOfs`/`yOfs`, `scale`, `iconsPerRow`, `iconSize`, `showBorder`, `showBackground`, `backgroundOpacity`, `fontSize`, `iconSpacing`
- `settings` — `showZeroCurrencies`, `showUndiscovered`, `filterByZone`, `showGreatVault`, `showVaultRaid`/`showVaultMythicPlus`/`showVaultWorld`, `categories` (per-expansion show/hide), `currencies` (per-currency override map)
- `settingsRepairV2` — one-time migration flag; when unset, forces `filterByZone` off and clears per-currency disables (older saved configs could end up hiding all Midnight currencies)

### Known Constraints
- Zone-based currency filtering has no Midnight zone map data yet, so `filterByZone` defaults off
- Some currency entries share the same ID across expansion categories (e.g. Restored Coffer Key, ID 3028, listed under both Midnight and War Within) and rely on Tracker.lua deduping if both categories are enabled
- Root `README.md`, `INSTALL.txt`, and `QUICK_REFERENCE.md` predate this doc pass and are stale in places (e.g. they document `/mt` slash commands and an Interface 110200 target; the actual code uses `/mtrack` and Interface 120001) — left as-is per the scaffolding pass; not yet reconciled with current code

### Known Issues
- None logged yet

### Current Focus
- Session initialization; no active task

### Notes for AI
- Do not guess APIs
- Do not expand scope
- Keep solutions minimal
- Follow CLAUDE.md and this file's Dev Rules section strictly

---

## Dev Rules

### Project Baseline
- WoW addon project
- Interface version: 120001
- Lua only
- No external libraries unless explicitly approved
- Prefer custom UI over Blizzard templates/assets

### Non-Negotiables
- No guessing on WoW APIs
- Verify uncertain API behavior before implementation
- Never do math on secret/protected values
- Never attempt to expose, infer, or bypass restricted values
- Respect combat lockdown and secure frame limitations
- Do not add hidden scope or unrelated cleanup

### Scope Control
- Do only what was requested
- Keep changes minimal and targeted
- Do not rewrite surrounding systems unless required for the task
- If a broader refactor would help, propose it instead of silently doing it

### Structure
- Keep files responsibility-focused
- Avoid duplicate helpers or duplicate implementations
- Reuse existing module boundaries where possible
- Prefer data-only extraction first
- Split growing files before they become unmanageable
- Do not create unnecessary conceptual layers

### Performance
- Event-driven first
- Avoid unnecessary OnUpdate usage
- Cache reused values
- Avoid repeated allocations in hot paths
- Gate disabled features so they stop doing work
- Use dirty/queued refreshes when appropriate instead of constant rebuilding

### SavedVariables
- Use one canonical SavedVariables table
- Keep defaults centralized
- Do not scatter persistence logic across unrelated files

### Localization
- All player-facing strings should be localized
- enUS is source of truth
- Avoid string concatenation for localized UI text
- Missing locale strings should be obvious during development

### UI / Layout
- Support different UI scales and resolutions
- Avoid clipping and zero-width layout states
- Avoid fragile offsets
- Prefer measured or bounded sizing for dynamic content
- Test layouts in narrow and wider frame states

### File and Docs Workflow
Project docs live in docs/PROJECT.md (a single consolidated file).

Maintain these sections when the workflow is active:
- TODO
- Issues
- Changelog (Dev)
- Testing

Definition of done includes:
- requested code change completed
- relevant docs updated
- obvious regressions checked
- completion marker printed in chat

### Required Pre-Flight Check
Before making changes, confirm:
- scope is clear
- solution is minimal
- no duplicate helper is being introduced
- localization rules are being followed
- event-driven approach is preferred
- debug/dev-only code stays isolated when applicable

### Completion Marker
When finishing a prompt or task, print:
PROMPT X COMPLETE

---

## TODO

### Active
- None yet

### Backlog
- None yet

### Completed
- Move finished items here and mark with prompt number/date if desired

---

## Issues

- None logged yet

---

## Testing

- None logged yet

---

## Changelog (Dev)

### Format
- PROMPT X
  - Intent:
  - Files changed:
  - Result:
  - Notes:

### Entries
- (none yet — this section grows as work happens)
