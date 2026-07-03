# React v2 parity audit — Roku gap analysis

**Branch:** `feature/react-parity-v2-audit`  
**React reference:** `/home/admin3329/Desktop/lg-samsung-tv-player`  
**Roku:** `ott-tv-roku`  
**Date:** 2026-07-03

This document compares each routed screen in the **new** React platform against the current Roku channel. Use it to plan re-replication work: new features, colors, UX, and animations.

---

## Executive summary

| Category | Count |
|----------|-------|
| Screens with existing Roku port | 12 |
| **New screen (no Roku yet)** | **0** |
| Scaffold only in React (skip for now) | New Release |
| Cross-cutting changes (all screens) | Theme tokens, header, feature flags, animations |

**Largest gaps:** Screen-by-screen re-audit (colors/UX), email login flow, Netflix default layout/header, hero timing deltas. Live TV mock EPG + player LIVE mode landed on this branch.

### Implemented on `feature/react-parity-v2-audit`

- [x] React v2 path in docs + scripts (`lg-samsung-tv-player`)
- [x] `epgManagement` in `DefaultFeatures()` + `ThemeManager.epgEnabled`
- [x] Header menu order parity (`Profile` → `Reels*` → `Live TV*`)
- [x] `RouteLiveTv()` + `LiveTvScreen` (mock EPG from `livetv/mockData.ts`)
- [x] Video player `type: LIVE` nav + limited live controls

---

## Route map

| React route | Roku route id | Roku screen | Audit status |
|-------------|---------------|-------------|--------------|
| `/` | `login` | `LoginScreen` | Re-audit |
| `/login-profile` | `login_profile` | `ProfileScreen` | Re-audit |
| `/home` | `home` | `HomeScreen` | Re-audit |
| `/genere` | `genere` | `GenreListScreen` | Re-audit |
| `/detail/:id` | `detail` | `DetailScreen` | Re-audit |
| `/video-player/:id` | `video_player` | `VideoPlayerScreen` | Re-audit |
| `/series-episodes` | `series_episodes` | `SeriesEpisodesScreen` | Re-audit |
| `/search` | `search` | `SearchScreen` | Re-audit |
| `/series` | `series` | `SeriesScreen` | Re-audit |
| `/mylist-detail` | `mylist_detail` | `MyListDetailScreen` | Re-audit |
| `/reels` | `reels` | `ReelsScreen` | Re-audit |
| **`/live-tv`** | **`live_tv`** | **`LiveTvScreen`** | **Implemented (mock EPG)** |
| `/new-release` | `new_release` | — | React route **commented out** — no Roku work |

---

## Cross-cutting (every screen)

### 1. Theme & colors

**React (new):**

- `useTheme` + `BusinessConfigContext` → CSS vars on `:root`
- `colorShadeGenerator` builds `primary-*`, `neutral-*`, `ui-*` from API `colors.primary/secondary/tertiary`
- Static fallbacks: `src/config/themes/*.theme.ts`
- Tailwind maps token classes to vars (`tailwind.config.js`)
- Duration tokens in `src/styles/theme.css`: fast **150ms**, normal **300ms**, slow **500ms**

**Roku today:**

- `ThemeTokenColor` / `BuildThemeTokens` from `businesses/frontend/config`
- `ThemeConfig.brs` for layout enums

**Parity work:**

- [ ] Diff `colorShadeGenerator` vs Roku `ColorShade.brs` / token names
- [ ] Re-verify every screen against **new** class names (not old `-lg-dev` tree)
- [ ] Confirm `portalDesign` / `systemSettings` precedence matches `useTheme`

### 2. Header & navigation

**React (new):**

- Default: **Netflix top header** (`ottHeader.tsx`) when `HeaderType.NETFLIX`
- Menu (`HeaderList.ts`): Home, Search, Movies, Series, My Watchlist, Profile, Reels*, **Live TV***
- *Reels hidden when `features.reelsEnabled === false`
- *Live TV hidden when `features.epgManagement === false`
- Movies/Series → same `/genere` with `state.type`

**Roku today:**

- `AppShell` + header via `HeaderMenu.brs` / sidebar variants
- **No Live TV route or menu item**
- Feature-flag gating for reels/EPG — verify against `BusinessConfig`

**Parity work:**

- [ ] Add `RouteLiveTv()` + menu item gated on `epgManagement`
- [ ] Re-read `ottHeader.tsx` focus, scale, underline classes vs Roku header widgets
- [ ] Align `reelsEnabled` flag behavior

### 3. Animations

**React:** No `framer-motion` in `src/` — CSS transitions + keyframes + `setInterval`.

| Pattern | Source | Timing |
|---------|--------|--------|
| UI transitions | Tailwind `duration-150/200/300/500` | 150–500ms |
| Hero page-flip | `heroBanner.tsx` | 5s swipe |
| Hero cinematic | `heroBannerCinematic.tsx` | 15s swipe; ~150ms fade |
| Hero parallax | `heroBannerParallax.tsx` | 5.5s; 800ms slide |
| Reel enter | `index.css` | 450ms ease-out |
| Live TV backdrop | `livetv/index.tsx` | 150ms crossfade; 15s clock |
| Skeleton shimmer | `index.css` `@keyframes shimmer` | pulse |

**Roku parity work:**

- [ ] Per-screen animation audit — map each to `Animation` + `Interpolator` durations
- [ ] Do **not** port framer-motion; port **timings** from CSS/classes

### 4. Business config & logout

**New in React:**

- `LogoutRedirect` on `BUSINESS_MISMATCH`
- `features.reelsEnabled`, `features.epgManagement` in resolved config

**Roku parity work:**

- [ ] Audit `BusinessConfig.brs` for new flags
- [ ] Implement mismatch logout if React shows dialog

---

## Per-screen audit

### Login (`features/login/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| **New** | `emailLogin.tsx`, `LoginMode` enum | Audit QR vs email paths |
| UX | `onboardingSkeleton.tsx` | Match skeleton vs loader |
| Theme | Login uses portal tokens | Re-read classes in `index.tsx` |
| API | Same `media/v1/device` family | Verify `NextStep` unchanged |

### Profile (`features/profile/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| UX | OTP, confirm popup, avatar grid | Diff `profile.tsx` vs `ProfileScreen` |
| Layout | Netflix circular vs sidebar square | Still tied to `headerStyle` |
| Loading | Skeleton on fetch | Compare loader/skeleton |

### Home (`features/home/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Layout | Default `HomeLayout.NETFLIX` → `netflixContent.tsx` | Verify `ThemeHomeLayout()` default |
| Hero | `HeroBannerSwitch` → flip / cinematic / parallax | Re-diff all three `.tsx` files |
| Timings | Cinematic 15s (was 15s in old — confirm deltas) | Update `HomeConstants.brs` |
| Rows | `contentRow.tsx`, `netflixContent.tsx` | Row types, focus, loaders |

### Genre list (`features/genre-list/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| API | `contents/catalogue` | Unchanged path — verify response shape |
| Hero + rows | Same pattern as home subset | Re-audit colors/focus |

### Detail (`features/contentdetail/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| More Like This | Drawer + shimmer | Already special-cased on Roku |
| Watchlist | add/remove | Verify action.ts |
| `isLive` | Still in types; live play via player | Wire when Live TV lands |

### Video player (`features/contentdetail/video/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Live play | Navigate with `type: 'LIVE'` from Live TV | Add live mode branch |
| Settings | Quality, captions, binge | B-1/B-2 platform limits unchanged |
| Progress | PATCH progress API | Verify |

### Series episodes (`features/contentdetail/season/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Tabs | `seasonTabs.tsx` | Re-audit focus order |
| Row | `seriesRow.tsx` | Card layout |

### Search (`features/search/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Keyboard | `customkeyboard.tsx` | Re-diff layout |
| Grid | `searchgrid.tsx` loader (black + 64px spinner) | Already ported — re-verify classes |
| Card | `search-horizontalcard.tsx` | Horizontal card parity |

### Series see-all (`features/series/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Grid | `seriesCol.tsx`, `seriesRow.tsx` | Re-audit |

### Watchlist (`features/list-detail/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Cards | `listDetailCard.tsx` | Re-read radii, colors |
| API | `watch-list/my-list`, details | Verify |

### Reels (`features/reels/`)

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Gating | `reelsEnabled` flag | Hide menu when false |
| Enter anim | 450ms CSS | Match `ReelsScreen` |
| API | `contents/reels` | Verify |

### Live TV (`features/livetv/`) — **NEW**

| Area | React v2 notes | Roku action |
|------|----------------|-------------|
| Route | `/live-tv` | Add `RouteLiveTv`, `LiveTvScreen` |
| Data | **Mock only** (`mockData.ts`) — no API yet | Port UI; stub data; API TBD |
| Layout | Top ~45% hero (backdrop, title, Play Now / Play From Beginning) | New SceneGraph layout |
| EPG | Bottom ~55% grid, 36h timeline, 10px/min, virtualized rows | New `EpgGrid` widget |
| Focus | `EPG_GRID`, `PROGRAM_{row}_{col}`, `CHANNEL_ROW_{n}` | Remote navigation |
| Playback | → `VIDEO_PLAYER` with `type: LIVE` | Extend player |
| Clock | NOW line, 15s tick | Timer |
| Gating | `epgManagement` feature flag | Header + route |
| Anim | 150ms backdrop crossfade | `Animation` 0.15s |

### New Release — **skip**

Route, pages, and features **commented out** in React. Roku `RouteNewRelease` exists but unused — no work until React enables it.

---

## Suggested workstreams (priority)

| P | Workstream | Est. scope |
|---|------------|------------|
| P0 | Update all parity docs/rules to new React path | Small |
| P0 | Cross-cutting: business flags, header menu, theme token diff | Medium |
| P1 | Per-screen re-audit (login → reels) — colors, copy, animation, API | Large |
| P1 | **Live TV screen** (mock parity) | Large |
| P2 | Video player `LIVE` mode | Medium |
| P3 | New Release (when React uncomments) | TBD |

---

## Per-screen checklist (use for each PR)

- [ ] Open React `features/<x>` + `pages/<x>` + `services/action.ts`
- [ ] List every `className` / color / font / spacing → map to Roku tokens or hex
- [ ] Trace mount → fetch → loading → content → focus → unmount
- [ ] Note timers, polls, debounces, guards
- [ ] List animations with **exact ms** from CSS or constants
- [ ] Compare API method, path, body, headers to `Endpoints.brs`
- [ ] Run `make validate` + sim logs for the screen
- [ ] Add `⚠ Parity Note` only for true platform limits

---

## Next steps on this branch

1. Merge parity path updates (rules, README, scripts, this audit).
2. Open child branches per workstream (`feature/livetv-screen`, `feature/header-v2`, etc.).
3. Screen-by-screen PRs with React file paths cited in PR description.
4. Do **not** implement Live TV APIs until backend contract exists — mock parity first matches React today.
