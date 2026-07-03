# OTT Accelerator - Roku

Production Roku channel (BrightScript + SceneGraph) replicating the LG/Samsung web CTV app
(`lg-samsung-tv-player` at `/home/admin3329/Desktop/lg-samsung-tv-player`), targeting the same `media/v1/*` backend.

**Project documentation:** [`../docs/README.md`](../docs/README.md)

## Quick start

```bash
cp config.example.json config.json   # fill API URL, domain, auth (gitignored)
make validate
make zip                             # → out/ott-tv-roku.zip
make sim                             # BrightScript Simulator (dev slot)
make icons                           # regenerate sidebar menu PNGs from React SVGs
```

**Home layout:** edit `ThemeHomeLayout()`, `ThemeHeaderStyle()`, and `ThemeHeroBannerStyle()` in
`source/lib/theme/ThemeConfig.brs` (mirrors React `src/config/theme.config.ts`), then `make sim`.

**Profile UI** follows `ThemeHeaderStyle()` only: `TC_HeaderNetflix()` → circular avatars;
`TC_HeaderSidebar()` → square gradient cards. `homeLayout` and hero style do not affect Profile.

See [`../docs/roku-channel/roku-channel.md`](../docs/roku-channel/roku-channel.md) for full
structure, screen status, branching model, and device install.
