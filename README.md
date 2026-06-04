# OTT Accelerator - Roku

Production Roku channel (BrightScript + SceneGraph) that replicates the LG/Samsung
web CTV app (`lg-samsung-tv-player-lg-dev`), targeting the same `media/v1/*` backend.

The full, phased build plan lives in
[`../ROKU_IMPLEMENTATION_PLAN.md`](../ROKU_IMPLEMENTATION_PLAN.md).

## Project structure

```
ott-tv-roku/
├── manifest                 # Channel metadata, splash, icons, ui_resolutions=fhd
├── bsconfig.json            # BrightScript language server / roku-deploy config
├── Makefile                 # build + sideload to a Roku in developer mode
├── config.example.json      # copy to config.json (gitignored) and fill values
├── source/
│   ├── main.brs             # channel entry point
│   └── lib/                 # BrightScript libs (http, registry, theme, helpers)
├── components/
│   ├── MainScene.xml/.brs   # root scene (hosts the ViewManager)
│   ├── core/                # ViewManager, ThemeManager, BusinessConfig, tasks
│   ├── screens/             # Login, Profile, Home, Detail, Player, Search, etc.
│   └── widgets/             # Toast, Spinner, Skeleton, Keyboard, popups
├── images/                  # icons, splash (required by manifest)
├── fonts/                   # optional — only packaged when TTFs are present
└── locale/                  # optional — only packaged when string files exist
```

## Local config

```bash
cp config.example.json config.json   # config.json is gitignored
# then fill in apiBaseUrl, businessDomain, basic auth, etc.
```

## Build & run

```bash
make zip                    # validate + out/ott-tv-roku.zip
make sim                    # install to BrightScript Simulator (dev slot)
```

**BrightScript Simulator:** File → Open Channel Package → `out/ott-tv-roku.zip`,
or run `make sim` (uses `http://127.0.0.1:8080`, password `rokudev`).

Do **not** put empty folders under `components/` in the zip (e.g. placeholder
`cards/` with only `.gitkeep`). The simulator SceneGraph loader fails with
`ENODATA` and will not register **any** components, including `MainScene`.

**Physical Roku** (developer mode enabled):

```bash
make install ROKU_DEV_TARGET=<roku-ip> ROKU_DEV_PASSWORD=<password>
```

## Branching model

Promotion pipeline (no direct commits to environment branches):

```
feature/* ──▶ dev ──▶ preprod ──▶ staging ──▶ production
```

- `dev` — integration branch. All feature branches (e.g. `feature/login`,
  `feature/profile`, `feature/home`) branch from here and merge back here.
- `preprod` / `staging` / `production` — promotion environments. Code is promoted
  upward only after a module is complete and verified.

Feature work flow:

```bash
git checkout dev
git checkout -b feature/login
# ...implement, commit...
git push -u origin feature/login
# open PR into dev; merge when complete
```
