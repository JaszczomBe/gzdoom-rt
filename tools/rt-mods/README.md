# RT External Mod Integration

This directory contains recipes for using external WAD/PK3 mods with GZDoom RT
without committing the mod assets to this repository.

## Layout

Keep the repo and the mod payload separate:

- `tools/rt-mods/mods/` stores small manifests for supported external mods.
- `tools/rt-mods/recipes/` stores scripts that adapt those mods for RT.
- `~/Games/gzdoom-rt/wad/` stores local IWAD files.
- `~/Games/gzdoom-rt/mods/` or `$RT_MODS_DIR` stores the real PK3/WAD files
  downloaded by the user, sorted by mod and version.
- `rt/autoload/<game>/` stores generated local runtime packages.
- `rt/autoload/.rt-mods/` stores install manifests for recipes that need exact
  upgrade/uninstall ownership.

Generated packages and external source mods are local machine state. They should
not be added to git.

Recommended external library layout:

```text
~/Games/gzdoom-rt/
  wad/
    doom2.wad
    heretic.wad
    hexen.wad
  mods/
    doom-voxels/
      2.4-f16e1577/
        VoxelDoom_v2.4.pk3.zip
        VoxelDoom_v2.4.pk3
    heretic-voxels/
      reikall-full-f55ce7cd/
        reikallhereticvoxels.pk3
  rt/
    wad/
    data/
    mat/
```

Keep downloaded archives immutable. Recipes may extract, sanitize, or wrap them
into runtime packages, but versioned mod folders are the upgrade/rollback anchor.
The `rt/` directory is required RT runtime data, not an IWAD/mod source folder;
the engine still expects to find `rt/wad` relative to the launch working
directory.

Downloading and placing external mod assets is intentionally outside the recipe
scope. Recipes only validate files already present in the library and generate
or remove local RT runtime outputs.

## RT Data Baseline

External RT runtime data can be refreshed or replaced independently from this
repo. After copying a fresh `rt/` directory, replay the repo-owned compatibility
patches before testing game support:

```bash
tools/rt-data/apply-compatibility-patches.sh ~/Games/gzdoom-rt/rt
```

That script reapplies liquid material aliases, Heretic light metadata, and
GLDEFS-derived RT light metadata. The mod dispatcher runs it automatically
after a successful recipe install or uninstall when the target RT data tree is
present, so removing a mod should not wipe baseline water, lava, slime, item,
torch, or projectile RT behavior.

## Preparing Sources

Voxel Doom II v2.4 should be placed as:

```text
~/Games/gzdoom-rt/mods/doom-voxels/2.4-f16e1577/
  VoxelDoom_v2.4.pk3.zip
  VoxelDoom_v2.4.pk3
```

The ZIP should be the ModDB `VoxelDoom_v2.4.pk3.zip` file with MD5
`f16e15778600e95c99399d58f4eeb1ed`. Extract `VoxelDoom_v2.4.pk3` from that ZIP
into the same version directory.

Heretic voxel sources should be placed as:

```text
~/Games/gzdoom-rt/mods/heretic-voxels/reikall-full-f55ce7cd/
  reikallhereticvoxels.pk3

~/Games/gzdoom-rt/mods/heretic-voxels/reikall-lite-03da4e08/
  reikallravenvoxelslite.pk3
```

## Installing A Mod

Use the dispatcher:

```bash
tools/rt-mods/install-mod.sh heretic-voxels --variant full
```

For Voxel Doom II, validate the prepared external source without installing it:

```bash
tools/rt-mods/install-mod.sh doom-voxels
```

Doom RT already ships converted older Doom voxel replacements under `rt/replace`
plus matching Cheello scripts under `rt/wad`. Autoloading fresh Voxel Doom II
KVX assets on top of those can misalign actor rotations, especially corpse
frames. A generated KVX package is therefore experimental and opt-in:

```bash
tools/rt-mods/install-mod.sh doom-voxels --install-kvx
```

Recipes should also accept explicit paths so another checkout can be reproduced:

```bash
tools/rt-mods/install-mod.sh heretic-voxels \
  --library ~/Games/gzdoom-rt/mods \
  --rt-dir /path/to/rt \
  --iwad ~/Games/gzdoom-rt/wad/heretic.wad
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
See `mods/doom-voxels.toml` for a versioned external-library example.

## Uninstalling

Use the same dispatcher with the recipe's uninstall option:

```bash
tools/rt-mods/install-mod.sh heretic-voxels --uninstall
```

Voxel Doom II uses the same pattern:

```bash
tools/rt-mods/install-mod.sh doom-voxels --uninstall
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

1. Put the external mod file in the versioned local library outside the repo.
2. Add `tools/rt-mods/mods/<mod-id>.toml` with filenames, hashes, and notes.
3. Add `tools/rt-mods/recipes/<mod_id>.py` or another recipe script.
4. Add the mod ID to `tools/rt-mods/install-mod.sh`.
5. Generate only local outputs under `rt/autoload/<game>/` or `rt/data/`.
6. Commit the manifest, recipe, and documentation only.
