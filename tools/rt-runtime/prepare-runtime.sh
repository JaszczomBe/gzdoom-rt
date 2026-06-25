#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
compat_version="compat-1"

usage() {
    cat <<'USAGE'
Usage: tools/rt-runtime/prepare-runtime.sh <source-rt-dir> [target-runtime-dir]

Compose a generated GZDoom RT runtime directory from an immutable RT asset
source. Large asset directories are symlinked, mutable metadata is copied and
patched, and the source directory is left untouched.

Defaults:
  target-runtime-dir: $GZDOOM_RT_RUNTIME_DIR, or
                      $XDG_CACHE_HOME/gzdoom-rt/runtime/current, or
                      ~/.cache/gzdoom-rt/runtime/current
USAGE
}

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

source_rt="$1"
target_arg="${2:-${GZDOOM_RT_RUNTIME_DIR:-}}"

if [[ -z "$target_arg" ]]; then
    if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
        target_arg="$XDG_CACHE_HOME/gzdoom-rt/runtime/current"
    else
        target_arg="$HOME/.cache/gzdoom-rt/runtime/current"
    fi
fi

source_rt="$(realpath -m "$source_rt")"
target_arg="$(realpath -m "$target_arg")"

require_path() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        echo "Missing required RT asset path: $path" >&2
        exit 1
    fi
}

require_path "$source_rt/data/textures.json"
require_path "$source_rt/wad"
require_path "$source_rt/mat"
require_path "$source_rt/shaders"
require_path "$source_rt/BlueNoise_LDR_RGBA_128.ktx2"
require_path "$source_rt/WaterNormal_n.ktx2"

if [[ "$source_rt" == "$target_arg" ]]; then
    echo "Source and target runtime are the same path: $source_rt" >&2
    exit 1
fi

manifest_key="$source_rt|$compat_version"
fingerprint="$(printf '%s' "$manifest_key" | sha256sum | cut -c1-16)"

if [[ "$(basename "$target_arg")" == "current" ]]; then
    runtime_parent="$(dirname "$target_arg")"
    runtime_dir="$runtime_parent/$fingerprint"
    current_link="$target_arg"
else
    runtime_parent="$(dirname "$target_arg")"
    runtime_dir="$target_arg"
    current_link=""
fi

tmp_dir="$runtime_dir.tmp.$$"
rm -rf "$tmp_dir"
mkdir -p "$tmp_dir"

link_entry() {
    local name="$1"
    if [[ -e "$source_rt/$name" ]]; then
        ln -s "$source_rt/$name" "$tmp_dir/$name"
    fi
}

for name in \
    bin \
    bin_remix \
    launcher \
    mat_src \
    replace \
    scenes \
    shaders \
    wad \
    BlueNoise_LDR_RGBA_128.ktx2 \
    DirtMask.ktx2 \
    SceneBuildWarning.ktx2 \
    WaterNormal_n.ktx2 \
    CreateKTX2.py \
    LICENSE \
    RTGL1.json \
    RTGL1.json-example \
    RTGL1_Remix.json-example
do
    link_entry "$name"
done

mkdir -p "$tmp_dir/mat"
find "$source_rt/mat" -mindepth 1 -maxdepth 1 -print0 |
    while IFS= read -r -d '' item; do
        ln -s "$item" "$tmp_dir/mat/$(basename "$item")"
    done

cp -a "$source_rt/data" "$tmp_dir/data"
mkdir -p "$tmp_dir/autoload"

bash "$repo_root/tools/rt-data/apply-compatibility-patches.sh" "$tmp_dir"

cat > "$tmp_dir/.gzdoom-rt-runtime" <<EOF
source=$source_rt
compat=$compat_version
fingerprint=$fingerprint
prepared_by=tools/rt-runtime/prepare-runtime.sh
EOF

mkdir -p "$runtime_parent"
rm -rf "$runtime_dir"
mv "$tmp_dir" "$runtime_dir"

if [[ -n "$current_link" ]]; then
    ln -sfn "$runtime_dir" "$current_link"
fi

echo "Prepared RT runtime: $runtime_dir"
if [[ -n "$current_link" ]]; then
    echo "Updated current runtime: $current_link -> $runtime_dir"
fi
