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
  heretic-voxels

Examples:
  tools/rt-mods/install-mod.sh heretic-voxels --variant full
  tools/rt-mods/install-mod.sh heretic-voxels --variant lite --source ~/Games/gzdoom-rt-mods/heretic
  tools/rt-mods/install-mod.sh heretic-voxels --uninstall
USAGE
}

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mod_id="$1"
shift

case "$mod_id" in
    heretic-voxels)
        exec python3 "$script_dir/recipes/heretic_voxels.py" --repo-root "$repo_root" "$@"
        ;;
    *)
        echo "Unknown RT mod recipe: $mod_id" >&2
        usage >&2
        exit 2
        ;;
esac
