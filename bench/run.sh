#!/usr/bin/env bash
#
# Nicolino vs Hugo/Zola benchmark harness.
#
# Reproducibly times a full build of the vendored 4000-file markdown corpus
# with Nicolino (dev and, optionally, release builds) plus Hugo and Zola when
# installed. All runners are timed in ONE hyperfine invocation so its native
# relative comparison ("X ran N times faster than Y") and --export-markdown
# table cover every tool. Results are written to bench/results/.
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

  local ts out_file md_file
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  out_file="$RESULTS_DIR/$ts.json"
  # Global so the EXIT trap (which fires outside main's scope) can see it.
  work_dir=$(mktemp -d)
  trap 'rm -rf "$work_dir"' EXIT

  local corpus_count
  corpus_count=$(find "$CORPUS" -name '*.md' | wc -l)

  # One shared prepare for every runner of the single hyperfine
  # invocation: reset every site's output and refresh its corpus copy.
  # It runs untimed before each run of each runner; doing all sites at
  # once costs extra wall-clock time but guarantees identical starting
  # conditions no matter which runner executes next.
  local prepare
  prepare=$(cat <<PREP
rm -rf '$NICO_SITE/output' '$NICO_SITE/.kvstore' '$NICO_SITE/.croupier' \\
       '$HUGO_DIR/public' '$ZOLA_SITE/public'
mkdir -p '$NICO_SITE/content' '$HUGO_DIR/content/posts' '$ZOLA_SITE/content'
cp '$CORPUS'/*.md '$NICO_SITE/content/'
cp '$CORPUS'/*.md '$HUGO_DIR/content/posts/'
cp '$CORPUS'/*.md '$ZOLA_SITE/content/'
PREP
)

  # Build the runner list in a bash array so optional runners (release,
  # hugo, zola) are included only when available. Every entry is
  # "<name>|<version-capture-cmd>|<command>"; versions are captured once,
  # after timing, from the same binaries.
  local names=() commands=()
  names+=("nicolino(dev)")
  commands+=("( cd \"$NICO_SITE\" && \"$NICOLINO_BIN\" build $NICOLINO_FLAGS )")
  local have_release=0
  if [[ -n "$NICOLINO_RELEASE_BIN" ]]; then
    have_release=1
    names+=("nicolino(release)")
    commands+=("( cd \"$NICO_SITE\" && \"$NICOLINO_RELEASE_BIN\" build $NICOLINO_FLAGS )")
  fi
  if [[ -n "$HUGO_BIN" ]]; then
    names+=("hugo")
    commands+=("( cd \"$HUGO_DIR\" && \"$HUGO_BIN\" --quiet )")
  fi
  if [[ -n "$ZOLA_BIN" ]]; then
    names+=("zola")
    commands+=("( cd \"$ZOLA_SITE\" && \"$ZOLA_BIN\" build )")
  fi

  local hyperfine_args=(--runs "$RUNS" --warmup "$WARMUP" --style basic \
                        --prepare "$prepare" \
                        --export-json "$work_dir/all.json" \
                        --export-markdown "$work_dir/all.md")
  local i
  for i in "${!names[@]}"; do
    hyperfine_args+=("--command-name" "${names[$i]}" "${commands[$i]}")
  done

  log "Timing ${names[*]} in a single hyperfine invocation..."
  # Human-readable stats go to stderr; stdout stays clean.
  if ! hyperfine "${hyperfine_args[@]}" >&2; then
    log "ERROR: at least one runner failed to build its site; failing the benchmark"
    exit 1
  fi

  # Leave one fresh dev-nicolino build in place for output verification.
  log ""
  log "Preparing final builds for output verification..."
  bash -c "$prepare"
  # shellcheck disable=SC2086 # NICOLINO_FLAGS is intentionally split
  ( cd "$NICO_SITE" && "$NICOLINO_BIN" build $NICOLINO_FLAGS ) >/dev/null
  if [[ -n "$HUGO_BIN" ]]; then
    ( cd "$HUGO_DIR" && "$HUGO_BIN" --quiet ) >/dev/null
  fi
  if [[ -n "$ZOLA_BIN" ]]; then
    ( cd "$ZOLA_SITE" && "$ZOLA_BIN" build ) >/dev/null
  fi

  local nico_html hugo_html=0 zola_html=0
  nico_html=$(count_html "$NICO_SITE/output")
  [[ -n "$HUGO_BIN" ]] && hugo_html=$(count_html "$HUGO_DIR/public")
  [[ -n "$ZOLA_BIN" ]] && zola_html=$(count_html "$ZOLA_SITE/public")

  # Assertion: nicolino must render every corpus file. This also makes the
  # harness usable as a CI smoke gate.
  if [[ "$nico_html" -ne "$corpus_count" ]]; then
    log "ERROR: nicolino produced $nico_html html files, expected $corpus_count"
    exit 1
  fi

  local nico_ver
  nico_ver=$(cd "$ROOT_DIR" && shards version 2>/dev/null || echo "unknown")

  # Map hyperfine's results array back onto named runners: results[i]
  # corresponds to names[i]/commands[i]. Indexes are computed explicitly
  # in bash (below) because optional runners shift every later position.
  local rel_idx="null" hugo_idx="null" zola_idx="null"
  local next=1
  if [[ "$have_release" == 1 ]]; then rel_idx=1; next=2; fi
  if [[ -n "$HUGO_BIN" ]]; then hugo_idx=$next; next=$((next + 1)); fi
  if [[ -n "$ZOLA_BIN" ]]; then zola_idx=$next; fi

  jq -n \
    --arg date "$ts" \
    --argjson corpus_files "$corpus_count" \
    --argjson runs "$RUNS" \
    --argjson warmup "$WARMUP" \
    --argjson cores "$CORES" \
    --arg ver "$nico_ver" \
    --arg flags "$NICOLINO_FLAGS" \
    --argjson html_nico "$nico_html" \
    --argjson html_hugo "$hugo_html" \
    --argjson html_zola "$zola_html" \
    --argjson dev_idx 0 \
    --argjson rel_idx "$rel_idx" \
    --argjson hugo_idx "$hugo_idx" \
    --argjson zola_idx "$zola_idx" \
    --slurpfile raw "$work_dir/all.json" '
    def entry($idx; $mode; $flags; $ver; $html):
      (if $idx == null then null else
        $raw[0].results[$idx] | {
          version: $ver,
          build_mode: $mode,
          flags: $flags,
          median_seconds: .median,
          min_seconds: .min,
          max_seconds: .max,
          times: .times,
          html_files: $html
        }
      end);
    (entry($rel_idx; "release"; $flags; $ver; $html_nico)) as $opt |
    (entry($hugo_idx; null; null; "hugo"; $html_hugo)) as $hugo |
    (entry($zola_idx; null; null; "zola"; $html_zola)) as $zola |
    (entry($dev_idx; "dev"; $flags; $ver; $html_nico)) as $dev |
    {
      date: $date,
      corpus_files: $corpus_files,
      runs: $runs,
      warmup: $warmup,
      cores: $cores,
      nicolino: ($dev + {optimized: $opt}),
      hugo: $hugo,
      zola: $zola,
      ratio_seconds_nicolino_over_hugo:
        (if $hugo == null then null
         else (($dev.median_seconds / $hugo.median_seconds) * 100 | round / 100) end),
      ratio_seconds_nicolino_optimized_over_hugo:
        (if $hugo == null or $opt == null then null
         else (($opt.median_seconds / $hugo.median_seconds) * 100 | round / 100) end),
      ratio_seconds_nicolino_over_zola:
        (if $zola == null then null
         else (($dev.median_seconds / $zola.median_seconds) * 100 | round / 100) end),
      ratio_seconds_nicolino_optimized_over_zola:
        (if $zola == null or $opt == null then null
         else (($opt.median_seconds / $zola.median_seconds) * 100 | round / 100) end)
    }' > "$out_file"

  # Human-readable companion: environment header + hyperfine's own
  # markdown comparison table (median/min/max/relative), plus HTML
  # counts that hyperfine cannot know about.
  md_file="${out_file%.json}.md"
  {
    echo "# Benchmark report — $ts"
    echo
    echo "**$corpus_count** corpus files · $RUNS runs (+$WARMUP warmup) · $CORES cores · Nicolino flags: \`$NICOLINO_FLAGS\`"
    echo
    cat "$work_dir/all.md"
    echo
    echo "HTML files generated: nicolino $nico_html · hugo $hugo_html · zola $zola_html"
    if [[ "$(jq -r '.nicolino.optimized == null' "$out_file")" == "true" ]]; then
      echo
      echo "_No optimized (release) binary was benchmarked this run._"
    fi
  } > "$md_file"

  log ""
  log "Results written to $out_file (report: $md_file)"

  # Echo the key numbers with ratios so logs show the comparison
  # without opening the JSON.
  local summary
  summary=$(jq -r '
    def s($v): if $v == null then "-" else "\($v)s" end;
    def r($a): if $a == null then "-" else "(\($a)× hugo)" end;
    def rz($a): if $a == null then "" else " (\($a)× zola)" end;
    "nicolino(dev)     \(s(.nicolino.median_seconds)) \(r(.ratio_seconds_nicolino_over_hugo))\(rz(.ratio_seconds_nicolino_over_zola))",
    (if .nicolino.optimized then
       "nicolino(release) \(s(.nicolino.optimized.median_seconds)) \(r(.ratio_seconds_nicolino_optimized_over_hugo))\(rz(.ratio_seconds_nicolino_optimized_over_zola))"
     else empty end),
    (if .hugo then "hugo              \(s(.hugo.median_seconds))" else empty end),
    (if .zola then "zola              \(s(.zola.median_seconds))" else empty end)
  ' "$out_file")
  log ""
  log "===== Summary ====="
  while IFS= read -r line; do log "$line"; done <<< "$summary"
}

main "$@"
