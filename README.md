# OTT Accelerator - Roku

Production Roku channel (BrightScript + SceneGraph) replicating the LG/Samsung web CTV app
(`lg-samsung-tv-player-lg-dev`), targeting the same `media/v1/*` backend.

**Project documentation:** [`../docs/README.md`](../docs/README.md)

## Quick start

```bash
cp config.example.json config.json   # fill API URL, domain, auth (gitignored)
make validate
make zip                             # → out/ott-tv-roku.zip
make sim                             # BrightScript Simulator (dev slot)
```

See [`../docs/roku-channel/roku-channel.md`](../docs/roku-channel/roku-channel.md) for full
structure, screen status, branching model, and device install.
