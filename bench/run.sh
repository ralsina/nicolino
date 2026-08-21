#!/usr/bin/env bash
#
# Nicolino vs Hugo/Zola benchmark harness.
#
# Reproducibly times a full build of the vendored 4000-file markdown corpus
# with Nicolino and (if installed) Hugo and Zola, using hyperfine for timing
# and statistics. Results are written to bench/results/.
#
# The corpus is a snapshot of Zach Leat's static-site build benchmark
# (https://www.zachleat.com/web/build-benchmark/).
#
# Usage:
#   ./bench/run.sh
#
# Env overrides:
#   RUNS=5                Number of timed runs per tool (default 3)
#   WARMUP=1              Untimed warmup runs per tool (default 1)
#   NICOLINO_BIN          Normal (dev) nicolino binary (default ./bin/nicolino)
#   NICOLINO_RELEASE_BIN  Optimized (--release) nicolino binary; if set it is
#                         also benchmarked and recorded as "optimized"
#   HUGO_BIN              Path to hugo (default: found on PATH)
#   ZOLA_BIN              Path to zola (default: found on PATH)
#   NICOLINO_FLAGS        Flags passed to `nicolino build` (default "--fast-mode -B -p")
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CORPUS="$SCRIPT_DIR/corpus"
NICO_SITE="$SCRIPT_DIR/site-nicolino"
ZOLA_SITE="$SCRIPT_DIR/site-zola"
HUGO_DIR="$SCRIPT_DIR/hugo"
RESULTS_DIR="$SCRIPT_DIR/results"

RUNS="${RUNS:-3}"
WARMUP="${WARMUP:-1}"
NICOLINO_BIN="${NICOLINO_BIN:-$ROOT_DIR/bin/nicolino}"
NICOLINO_RELEASE_BIN="${NICOLINO_RELEASE_BIN:-}"
HUGO_BIN="${HUGO_BIN:-$(command -v hugo || true)}"
ZOLA_BIN="${ZOLA_BIN:-$(command -v zola || true)}"
NICOLINO_FLAGS="${NICOLINO_FLAGS:---fast-mode -B -p}"
CORES="$(nproc)"

mkdir -p "$RESULTS_DIR"

log() { printf '[bench] %s\n' "$*" >&2; }

require() {
  command -v "$1" >/dev/null || { log "ERROR: '$1' is required but not installed"; exit 1; }
}

# Ensure the nicolino binaries exist (build the dev one if missing).
ensure_nicolino() {
  if [[ ! -x "$NICOLINO_BIN" ]]; then
    log "normal (dev) binary not found at $NICOLINO_BIN; building..."
    ( cd "$ROOT_DIR" && shards build -d )
  fi
  if [[ -n "$NICOLINO_RELEASE_BIN" ]] && [[ ! -x "$NICOLINO_RELEASE_BIN" ]]; then
    log "ERROR: NICOLINO_RELEASE_BIN is set but not executable: $NICOLINO_RELEASE_BIN"
    log "  Build it first (e.g. 'shards build --release --output $NICOLINO_RELEASE_BIN')."
    exit 1
  fi
}

# Each SSG has its own committed site directory (config + templates);
# preparation only resets the output dir and refreshes the corpus content.
# These strings are passed to hyperfine --prepare.

NICO_PREPARE="rm -rf '$NICO_SITE/output' '$NICO_SITE/.kvstore' '$NICO_SITE/.croupier'
mkdir -p '$NICO_SITE/content'
cp '$CORPUS'/*.md '$NICO_SITE/content/'"

HUGO_PREPARE="rm -rf '$HUGO_DIR/public'
mkdir -p '$HUGO_DIR/content/posts'
cp '$CORPUS'/*.md '$HUGO_DIR/content/posts/'"

ZOLA_PREPARE="rm -rf '$ZOLA_SITE/public'
mkdir -p '$ZOLA_SITE/content'
cp '$CORPUS'/*.md '$ZOLA_SITE/content/'"

# Time one tool with hyperfine; writes raw results JSON to $2 and prints
# the median seconds. A failing build fails the benchmark: a tool that is
# installed but cannot build the site is a broken benchmark, not a skip.
bench_tool() {
  local label="$1" out_json="$2" prepare="$3"
  shift 3
  # hyperfine's human-readable stats go to stderr; stdout must stay clean
  # because the caller captures this function's output (the median).
  # NOTE: callers must use `var=$(bench_tool ...) || exit 1`: set -e is
  # disabled inside command substitutions, so failures need explicit checks.
  if ! hyperfine \
    --command-name "$label" \
    --runs "$RUNS" \
    --warmup "$WARMUP" \
    --style basic \
    --prepare "$prepare" \
    --export-json "$out_json" \
    "$@" >&2; then
    log "ERROR: '$label' failed to build the site; failing the benchmark"
    return 1
  fi
  jq -r '.results[0].median' "$out_json"
}

count_html() {
  find "$1" -name '*.html' | wc -l
}

main() {
  require hyperfine
  require jq

  log "Nicolino vs Hugo/Zola benchmark"
  log "  corpus: $(find "$CORPUS" -name '*.md' | wc -l) files"
  log "  runs per tool: $RUNS (+$WARMUP warmup), hyperfine median"
  log "  cores: $CORES"
  log "  nicolino flags: $NICOLINO_FLAGS"
  log ""

  ensure_nicolino

  local ts out_file
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  out_file="$RESULTS_DIR/$ts.json"
  # Global so the EXIT trap (which fires outside main's scope) can see it.
  work_dir=$(mktemp -d)
  trap 'rm -rf "$work_dir"' EXIT

  local nico_time nico_release_time="" hugo_time="" zola_time=""

  log "Timing Nicolino (normal/dev)..."
  nico_time=$(bench_tool "nicolino-dev" "$work_dir/nicolino.json" "$NICO_PREPARE" \
    "( cd \"$NICO_SITE\" && \"$NICOLINO_BIN\" build $NICOLINO_FLAGS )") || exit 1
  log "  nicolino dev median: ${nico_time}s"

  if [[ -n "$NICOLINO_RELEASE_BIN" ]]; then
    log ""
    log "Timing Nicolino (optimized/release)..."
    nico_release_time=$(bench_tool "nicolino-release" "$work_dir/nicolino-rel.json" "$NICO_PREPARE" \
      "( cd \"$NICO_SITE\" && \"$NICOLINO_RELEASE_BIN\" build $NICOLINO_FLAGS )") || exit 1
    log "  nicolino release median: ${nico_release_time}s"
  else
    log ""
    log "NICOLINO_RELEASE_BIN not set; skipping optimized build"
  fi

  if [[ -n "$HUGO_BIN" ]]; then
    log ""
    log "Timing Hugo..."
    hugo_time=$(bench_tool "hugo" "$work_dir/hugo.json" "$HUGO_PREPARE" \
      "( cd \"$HUGO_DIR\" && \"$HUGO_BIN\" --quiet )") || exit 1
    log "  hugo median: ${hugo_time}s"
  else
    log ""
    log "hugo not found; skipping comparison"
  fi

  if [[ -n "$ZOLA_BIN" ]]; then
    log ""
    log "Timing Zola..."
    zola_time=$(bench_tool "zola" "$work_dir/zola.json" "$ZOLA_PREPARE" \
      "( cd \"$ZOLA_SITE\" && \"$ZOLA_BIN\" build )") || exit 1
    log "  zola median: ${zola_time}s"
  else
    log ""
    log "zola not found; skipping comparison"
  fi

  # Leave one fresh build in place for output verification below.
  log ""
  log "Preparing final builds for output verification..."
  bash -c "$NICO_PREPARE"
  # shellcheck disable=SC2086 # NICOLINO_FLAGS is intentionally split
  ( cd "$NICO_SITE" && "$NICOLINO_BIN" build $NICOLINO_FLAGS ) >/dev/null
  if [[ -n "$HUGO_BIN" ]]; then
    bash -c "$HUGO_PREPARE"
    ( cd "$HUGO_DIR" && "$HUGO_BIN" --quiet ) >/dev/null
  fi
  if [[ -n "$ZOLA_BIN" ]]; then
    bash -c "$ZOLA_PREPARE"
    ( cd "$ZOLA_SITE" && "$ZOLA_BIN" build ) >/dev/null
  fi

  local nico_html hugo_html=0 zola_html=0
  nico_html=$(count_html "$NICO_SITE/output")
  [[ -n "$HUGO_BIN" ]] && hugo_html=$(count_html "$HUGO_DIR/public")
  [[ -n "$ZOLA_BIN" ]] && zola_html=$(count_html "$ZOLA_SITE/public")

  # Assertion: nicolino must render every corpus file. This also makes the
  # harness usable as a CI smoke gate.
  local corpus_count
  corpus_count=$(find "$CORPUS" -name '*.md' | wc -l)
  if [[ "$nico_html" -ne "$corpus_count" ]]; then
    log "ERROR: nicolino produced $nico_html html files, expected $corpus_count"
    exit 1
  fi

  local nico_ver
  nico_ver=$(cd "$ROOT_DIR" && shards version 2>/dev/null || echo "unknown")

  # Per-tool entries; optional tools get an explicit null entry so the
  # final assembly can slurp every file unconditionally.
  jq -n \
    --arg ver "$nico_ver" \
    --arg flags "$NICOLINO_FLAGS" \
    --argjson median "$nico_time" \
    --argjson html "$nico_html" \
    --argjson rel "${nico_release_time:-null}" \
    --slurpfile raw "$work_dir/nicolino.json" \
    '{
      version: $ver,
      build_mode: "dev",
      flags: $flags,
      median_seconds: $median,
      html_files: $html,
      times: $raw[0].results[0].times,
      optimized: (if $rel == null then null else {
        version: $ver, build_mode: "release", flags: $flags,
        median_seconds: $rel, html_files: $html
      } end)
    }' > "$work_dir/entry-nicolino.json"

  echo 'null' > "$work_dir/entry-hugo.json"
  echo 'null' > "$work_dir/entry-zola.json"

  if [[ -n "$HUGO_BIN" ]]; then
    jq -n \
      --arg ver "$("$HUGO_BIN" version | head -1)" \
      --argjson median "$hugo_time" \
      --argjson html "$hugo_html" \
      --slurpfile raw "$work_dir/hugo.json" \
      '{version: $ver, median_seconds: $median, html_files: $html, times: $raw[0].results[0].times}' \
      > "$work_dir/entry-hugo.json"
  fi

  if [[ -n "$ZOLA_BIN" ]]; then
    jq -n \
      --arg ver "$("$ZOLA_BIN" --version)" \
      --argjson median "$zola_time" \
      --argjson html "$zola_html" \
      --slurpfile raw "$work_dir/zola.json" \
      '{version: $ver, median_seconds: $median, html_files: $html, times: $raw[0].results[0].times}' \
      > "$work_dir/entry-zola.json"
  fi

  jq -n \
    --arg date "$ts" \
    --argjson corpus_files "$corpus_count" \
    --argjson runs "$RUNS" \
    --argjson warmup "$WARMUP" \
    --argjson cores "$CORES" \
    --slurpfile nico "$work_dir/entry-nicolino.json" \
    --slurpfile hugo "$work_dir/entry-hugo.json" \
    --slurpfile zola "$work_dir/entry-zola.json" \
    '{
      date: $date,
      corpus_files: $corpus_files,
      runs: $runs,
      warmup: $warmup,
      cores: $cores,
      nicolino: $nico[0],
      hugo: $hugo[0],
      zola: $zola[0],
      ratio_seconds_nicolino_over_hugo:
        (if $hugo[0] == null then null
         else (($nico[0].median_seconds / $hugo[0].median_seconds) * 100 | round / 100) end),
      ratio_seconds_nicolino_optimized_over_hugo:
        (if $hugo[0] == null or $nico[0].optimized == null then null
         else (($nico[0].optimized.median_seconds / $hugo[0].median_seconds) * 100 | round / 100) end),
      ratio_seconds_nicolino_over_zola:
        (if $zola[0] == null then null
         else (($nico[0].median_seconds / $zola[0].median_seconds) * 100 | round / 100) end)
    }' > "$out_file"

  log ""
  log "Results written to $out_file"

  log ""
  log "===== Summary ====="
  log "nicolino (dev):     ${nico_time}s (${nico_html} html)"
  if [[ -n "$nico_release_time" ]]; then
    log "nicolino (release): ${nico_release_time}s (${nico_html} html)"
  fi
  if [[ -n "$hugo_time" ]]; then
    log "hugo:               ${hugo_time}s (${hugo_html} html)"
  fi
  if [[ -n "$zola_time" ]]; then
    log "zola:               ${zola_time}s (${zola_html} html)"
  fi
}

main "$@"
