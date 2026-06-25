#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../.." && pwd)"

usage() {
    cat <<'USAGE'
Usage: tools/rt-mods/install-mod.sh <mod-id> [recipe options]

Install a locally supplied external mod through a repo-owned RT compatibility
recipe. The mod asset itself stays outside git.

Known mod IDs:
  doom-voxels
  heretic-voxels

Examples:
  tools/rt-mods/install-mod.sh doom-voxels
  tools/rt-mods/install-mod.sh doom-voxels --install-kvx
  tools/rt-mods/install-mod.sh doom-voxels --uninstall
  tools/rt-mods/install-mod.sh heretic-voxels --variant full
  tools/rt-mods/install-mod.sh heretic-voxels --variant lite
  tools/rt-mods/install-mod.sh heretic-voxels --uninstall
USAGE
}

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mod_id="$1"
shift

compat_rt_dir="${RT_DATA_DIR:-$repo_root/rt}"
recipe_args=("$@")
for ((i = 0; i < ${#recipe_args[@]}; i++)); do
    case "${recipe_args[$i]}" in
        --rt-dir=*)
            compat_rt_dir="${recipe_args[$i]#--rt-dir=}"
            ;;
        --rt-dir)
            if (( i + 1 < ${#recipe_args[@]} )); then
                compat_rt_dir="${recipe_args[$((i + 1))]}"
            fi
            ;;
    esac
done

case "$mod_id" in
    doom-voxels)
        python3 "$script_dir/recipes/doom_voxels.py" --repo-root "$repo_root" "$@"
        ;;
    heretic-voxels)
        python3 "$script_dir/recipes/heretic_voxels.py" --repo-root "$repo_root" "$@"
        ;;
    *)
        echo "Unknown RT mod recipe: $mod_id" >&2
        usage >&2
        exit 2
        ;;
esac

if [[ -f "$compat_rt_dir/data/textures.json" ]]; then
    "$repo_root/tools/rt-data/apply-compatibility-patches.sh" "$compat_rt_dir"
else
    echo "Skipped RT compatibility baseline: missing $compat_rt_dir/data/textures.json" >&2
fi
