#!/usr/bin/env bash
#
# Nicolino vs Hugo benchmark harness.
#
# Reproducibly times a full build of the vendored 4000-file markdown corpus
# with Nicolino and (if installed) Hugo, reporting the median wall-clock
# time of several runs. Results are written to bench/results/.
#
# The corpus is a snapshot of Zach Leat's static-site build benchmark
# (https://www.zachleat.com/web/build-benchmark/).
#
# Usage:
#   ./bench/run.sh
#
# Env overrides:
#   RUNS=5            Number of timed runs (default 3)
#   NICOLINO_BIN      Path to the nicolino binary (default ./bin/nicolino)
#   HUGO_BIN          Path to hugo (default: found on PATH)
#   NICOLINO_FLAGS    Flags passed to `nicolino build` (default "--fast-mode -B -p")
#   CRYSTAL_WORKERS   Crystal worker count for nicolino
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CORPUS="$SCRIPT_DIR/corpus"
SITE_DIR="$SCRIPT_DIR/site"
HUGO_DIR="$SCRIPT_DIR/hugo"
RESULTS_DIR="$SCRIPT_DIR/results"

RUNS="${RUNS:-3}"
NICOLINO_BIN="${NICOLINO_BIN:-$ROOT_DIR/bin/nicolino}"
HUGO_BIN="${HUGO_BIN:-$(command -v hugo || true)}"
NICOLINO_FLAGS="${NICOLINO_FLAGS:---fast-mode -B -p}"
WORKERS="${CRYSTAL_WORKERS:-$(nproc)}"

mkdir -p "$RESULTS_DIR"

log() { printf '[bench] %s\n' "$*" >&2; }

median() {
  printf '%s\n' "$@" | sort -n | awk '{
    a[NR]=$0
  } END {
    n = NR
    if (n % 2 == 1) print a[(n + 1) / 2]
    else print (a[n / 2] + a[n / 2 + 1]) / 2
  }'
}

# Ensure the nicolino binary exists (build it if missing).
ensure_nicolino() {
  if [[ ! -x "$NICOLINO_BIN" ]]; then
    log "nicolino binary not found at $NICOLINO_BIN; building..."
    ( cd "$ROOT_DIR" && shards build -d )
  fi
}

nicolino_setup() {
  rm -rf "$SITE_DIR/output" "$SITE_DIR/.kvstore" "$SITE_DIR/.croupier"
  mkdir -p "$SITE_DIR/content"
  cp "$CORPUS"/*.md "$SITE_DIR/content/"
}

nicolino_run() {
  # shellcheck disable=SC2086 # NICOLINO_FLAGS is intentionally split
  ( cd "$SITE_DIR" && "$NICOLINO_BIN" build $NICOLINO_FLAGS )
}

hugo_setup() {
  rm -rf "$HUGO_DIR/public"
  mkdir -p "$HUGO_DIR/content/posts"
  cp "$CORPUS"/*.md "$HUGO_DIR/content/posts/"
}

hugo_run() {
  ( cd "$HUGO_DIR" && "$HUGO_BIN" --quiet )
}

bench() {
  # bench <label> <setup-fn> <run-fn> -> prints median seconds
  local label="$1" setup_fn="$2" run_fn="$3"
  local times=() elapsed
  for ((i = 1; i <= RUNS; i++)); do
    "$setup_fn"
    local start end
    start=$(date +%s%N)
    "$run_fn" >/dev/null 2>&1
    end=$(date +%s%N)
    elapsed=$(awk -v s="$start" -v e="$end" 'BEGIN { printf "%.4f", (e - s) / 1000000000 }')
    times+=("$elapsed")
    log "  $label run $i/$RUNS: ${elapsed}s"
  done
  median "${times[@]}"
}

count_html() {
  find "$1" -name '*.html' | wc -l
}

main() {
  log "Nicolino vs Hugo benchmark"
  log "  corpus: $(find "$CORPUS" -name '*.md' | wc -l) files"
  log "  runs per tool: $RUNS (median)"
  log "  workers: $WORKERS"
  log "  nicolino flags: $NICOLINO_FLAGS"
  log ""

  ensure_nicolino
  nicolino_setup
  hugo_setup

  local nico_time hugo_time
  log "Timing Nicolino..."
  nico_time=$(bench "nicolino" nicolino_setup nicolino_run)
  log "  nicolino median: ${nico_time}s"

  hugo_time=""
  if [[ -n "$HUGO_BIN" ]]; then
    log ""
    log "Timing Hugo..."
    hugo_time=$(bench "hugo" hugo_setup hugo_run)
    log "  hugo median: ${hugo_time}s"
  else
    log ""
    log "hugo not found; skipping comparison"
  fi

  local nico_html hugo_html=""
  nico_html=$(count_html "$SITE_DIR/output")
  if [[ -n "$HUGO_BIN" ]]; then
    hugo_html=$(count_html "$HUGO_DIR/public")
  fi

  # Assertion: nicolino must render every corpus file. This also makes the
  # harness usable as a CI smoke gate.
  local corpus_count
  corpus_count=$(find "$CORPUS" -name '*.md' | wc -l)
  if [[ "$nico_html" -ne "$corpus_count" ]]; then
    log "ERROR: nicolino produced $nico_html html files, expected $corpus_count"
    exit 1
  fi

  # Write results
  local ts out_file
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  out_file="$RESULTS_DIR/$ts.json"

  local nico_ver
  nico_ver=$(cd "$ROOT_DIR" && shards version 2>/dev/null || echo "unknown")
  local hugo_ver="null"
  [[ -n "$HUGO_BIN" ]] && hugo_ver="\"$($HUGO_BIN version | head -1)\""
  local ratio="null"
  if [[ -n "$hugo_time" ]] && [[ -n "$nico_time" ]]; then
    ratio=$(awk -v n="$nico_time" -v h="$hugo_time" 'BEGIN { printf "%.2f", n / h }')
  fi

  cat > "$out_file" <<JSON
{
  "date": "$ts",
  "corpus_files": $(find "$CORPUS" -name '*.md' | wc -l),
  "runs": $RUNS,
  "workers": $WORKERS,
  "build_mode": "${BUILD_MODE:-dev}",
  "nicolino": {
    "version": "$nico_ver",
    "flags": "$NICOLINO_FLAGS",
    "median_seconds": $nico_time,
    "html_files": $nico_html
  },
  "hugo": {
    "version": $hugo_ver,
    "median_seconds": ${hugo_time:-null},
    "html_files": ${hugo_html:-0}
  },
  "ratio_seconds_nicolino_over_hugo": $ratio
}
JSON
  log ""
  log "Results written to $out_file"

  log ""
  log "===== Summary ====="
  log "nicolino: ${nico_time}s (${nico_html} html)"
  if [[ -n "$hugo_time" ]]; then
    log "hugo:     ${hugo_time}s (${hugo_html} html)"
    log "ratio (nicolino/hugo): $ratio x"
  fi
}

main "$@"
