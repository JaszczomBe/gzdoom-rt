# RT External Mod Integration

This directory contains recipes for using external WAD/PK3 mods with GZDoom RT
without committing the mod assets to this repository.

## Layout

Keep the repo and the mod payload separate:

- `tools/rt-mods/mods/` stores small manifests for supported external mods.
- `tools/rt-mods/recipes/` stores scripts that adapt those mods for RT.
- `~/Games/gzdoom-rt-mods/` or another local directory stores the real PK3/WAD
  files downloaded by the user.
- `rt/autoload/<game>/` stores generated local runtime packages.

Generated packages and external source mods are local machine state. They should
not be added to git.

## Installing A Mod

Use the dispatcher:

```bash
tools/rt-mods/install-mod.sh heretic-voxels --variant full
```

Recipes should also accept explicit paths so another checkout can be reproduced:

```bash
tools/rt-mods/install-mod.sh heretic-voxels \
  --source ~/Games/gzdoom-rt-mods/heretic \
  --rt-dir /path/to/rt \
  --iwad /path/to/heretic.wad
```

The old Heretic voxel helper remains as a compatibility wrapper:

```bash
tools/rt-data/install-heretic-voxels.sh --variant lite
```

## Recipe Rules

Each recipe should:

- Refuse missing source files with a clear message.
- Record expected source checksums in its manifest.
- Warn or fail when checksums differ, unless the user explicitly opts into an
  unknown version.
- Generate wrapper PK3s instead of modifying the original mod.
- Place outputs under game-scoped autoload folders like `rt/autoload/heretic/`.
- Keep edits idempotent, so rerunning the recipe does not duplicate metadata.
- Create backups before touching shared RT data such as `rt/data/textures.json`.
- Support uninstall through the same dispatcher, removing only generated files
  and metadata owned by that recipe.

For RT compatibility, recipes may:

- Sanitize incompatible lumps such as old `VOXELDEF` entries.
- Add wrapper lumps that restore actor or frame associations.
- Translate `GLDEFS` dynamic lights into RT material metadata.
- Add material aliases for generated model or voxel textures such as `vx_*`.
- Generate or refresh GLTF cache data when the source mod makes that useful.

## Manifests

A manifest is a small documentation and validation record, not a package manager.
It should identify:

- Mod ID and title.
- Source directory environment variable.
- Supported variants and filenames.
- Known SHA-256 hashes.
- Generated filenames and target game autoload folder.
- Required RT metadata or wrapper steps.
- License notes explaining why the assets are external.

See `mods/heretic-voxels.toml` for the first example.

## Uninstalling

Use the same dispatcher with the recipe's uninstall option:

```bash
tools/rt-mods/install-mod.sh heretic-voxels --uninstall
```

Compatibility wrappers pass the option through:

```bash
tools/rt-data/install-heretic-voxels.sh --uninstall
```

Recipes should avoid restoring whole shared-data backups during uninstall,
because other mods may have been installed afterward. Instead, generated
metadata should be surrounded by recipe-owned markers such as
`// BEGIN RT MOD <mod-id>` and `// END RT MOD <mod-id>`. Uninstall should remove
that marked block, any older unmarked entries known to belong to the recipe, and
the generated local packages. A fresh backup of the current shared file should
be written before making that surgical edit.

## Adding A New Mod

1. Put the external mod file in a local cache outside the repo.
2. Add `tools/rt-mods/mods/<mod-id>.toml` with filenames, hashes, and notes.
3. Add `tools/rt-mods/recipes/<mod_id>.py` or another recipe script.
4. Add the mod ID to `tools/rt-mods/install-mod.sh`.
5. Generate only local outputs under `rt/autoload/<game>/` or `rt/data/`.
6. Commit the manifest, recipe, and documentation only.
