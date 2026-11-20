#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
    for candidate in godot4 godot /Applications/Godot.app/Contents/MacOS/Godot; do
        if command -v "$candidate" >/dev/null 2>&1; then
            godot_bin="$candidate"
            break
        fi
    done
fi

check_script() {
    local output status=0
    output="$("$godot_bin" --headless --path "$project_dir" --check-only --script "$1" 2>&1)" || status=$?
    printf '%s\n' "$output"
    if [[ "$status" -ne 0 || "$output" == *"ERROR:"* ]]; then
        return 1
    fi
}

if [[ -z "$godot_bin" ]]; then
    printf 'Godot 4.4+ not found. Add godot or godot4 to PATH, or set GODOT_BIN.\n' >&2
    exit 1
fi

case "${1:-}" in
    build)
        version="$("$godot_bin" --version)"
        if [[ ! "$version" =~ ^4\.([0-9]+)\. || "${BASH_REMATCH[1]}" -lt 4 ]]; then
            printf 'Godot 4.4+ is required, found %s.\n' "$version" >&2
            exit 1
        fi
        check_script res://src/headless.gd
        check_script res://src/main.gd
        ;;
    play)
        exec "$godot_bin" --path "$project_dir"
        ;;
    headless)
        shift
        exec "$godot_bin" --headless --path "$project_dir" --script res://src/headless.gd -- "$@"
        ;;
    verify)
        GODOT_BIN="$godot_bin" DAO_BEN_TEST_BASH="$BASH" "${PYTHON_BIN:-python3}" \
            -m unittest discover -s "$project_dir/tests" -p 'verify_phase*.py' -v
        exec "$godot_bin" --headless --path "$project_dir" --fixed-fps 60 --script res://tests/campaign_flow.gd
        ;;
    *)
        printf 'Usage: bash tools/game.sh {build|play|headless|verify}\n' >&2
        exit 2
        ;;
esac
