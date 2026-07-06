# React reference app (source of truth)

**Canonical path (only):**

```
/home/admin3329/Desktop/lg-samsung-tv-player
```

All Roku parity work reads from this repo. The previous tree
`lg-samsung-tv-player-lg-dev` under `Roku-Tv-Final/` is **retired** — do not use it.

## Quick entry points

| Area | Path |
|------|------|
| Routes | `src/routes/route.ts`, `src/routes/routePaths.ts` |
| Header menu | `src/components/header/HeaderList.ts`, `ottHeader.tsx` |
| Theme config | `src/config/theme.config.ts`, `src/hooks/useTheme.ts` |
| Business / feature flags | `src/context/BusinessConfigContext.tsx` |
| Design tokens | `src/styles/theme.css`, `tailwind.config.js` |
| API paths | `src/utils/constant/api.endpoint.ts` |

## Screen → React source map

| Screen | React entry |
|--------|-------------|
| Login | `src/features/login/index.tsx` |
| Profile | `src/features/profile/profile.tsx` |
| Home | `src/features/home/index.tsx` |
| Genre (Movies/Series) | `src/features/genre-list/index.tsx` |
| Detail | `src/features/contentdetail/index.tsx` |
| Video player | `src/features/contentdetail/video/index.tsx` |
| Series episodes | `src/features/contentdetail/season/seriesEpisode.tsx` |
| Search | `src/features/search/search.tsx` |
| Series (See All) | `src/features/series/index.tsx` |
| Watchlist | `src/features/list-detail/index.tsx` |
| Reels | `src/features/reels/index.tsx` |
| **Live TV** | `src/features/livetv/index.tsx` |

## Relative path from this repo

From `ott-tv-roku/`:

```
../../lg-samsung-tv-player
```
