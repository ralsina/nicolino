# Benchmark harness

Reproducibly times a full build of a 4000-file Markdown corpus with Nicolino
and (optionally) Hugo, and records the results. It exists to make the
project's "faster than Hugo" claim measurable rather than anecdotal.

The corpus is a snapshot of Zach Leat's static-site build benchmark
(<https://www.zachleat.com/web/build-benchmark/>), vendored under
[`corpus/`](corpus/).

## Requirements

- a `nicolino` binary (the harness builds a **normal (dev)** one if missing)
- an **optimized (`--release`)** binary, optionally, via `NICOLINO_RELEASE_BIN`
- `hugo` on `PATH` (optional — the Hugo comparison is skipped if absent)
- `bash`, `awk`, `date`

> **Both build modes are measured.** Dev builds (`shards build -d`) are roughly
> 2x slower than `--release` builds, so the harness times both and records them
> under `nicolino` (dev) and `nicolino.optimized` in the result JSON. For
> shipping-performance numbers you care about the **optimized** figure; the
> dev figure shows the headroom optimization gives. Build a release binary
> locally with `shards build --release` (takes ~20 minutes) or let CI do it —
> see the [CI workflow](#ci-workflow) below.

## Usage

```sh
shards build --release --output bench/release-bin/nicolino
NICOLINO_BIN="$PWD/bin/nicolino" \
NICOLINO_RELEASE_BIN="$PWD/bench/release-bin/nicolino" \
./bench/run.sh
```

The harness:

1. copies the corpus into a throwaway `bench/site/content/` and
   `bench/hugo/content/posts/`
2. times several full builds of each tool (median of `RUNS` runs, default 3),
   cleaning between runs so every timing measures a fresh build
3. asserts every corpus file rendered
4. writes a timestamped JSON report to `bench/results/` and prints a summary

### Configuration

| Env var               | Default                | Purpose                                  |
| --------------------- | ---------------------- | ---------------------------------------- |
| `RUNS`                | `3`                    | Number of timed runs per tool            |
| `NICOLINO_BIN`        | `./bin/nicolino`       | Normal (dev) nicolino binary             |
| `NICOLINO_RELEASE_BIN`| *(unset)*              | Optimized (`--release`) binary; when set it is also benchmarked |
| `HUGO_BIN`            | `$(command -v hugo)`   | Path to hugo (empty skips hugo)          |
| `NICOLINO_FLAGS`      | `--fast-mode -B -p`    | Flags passed to `nicolino build`         |

The result JSON records the machine's core count (`cores`) for context.
Note: nicolino's parallelism is fixed at compile time (Crystal MT); there is
no runtime worker knob, so results are comparable across machines modulo CPU
speed and core count.

## Methodology

- Both tools render the same 4000 files to HTML. The nicolino site uses the
  `pages` feature so every file is rendered regardless of frontmatter dates;
  the hugo site uses a minimal `bench` theme.
- Timing measures wall-clock time of the full build command from a clean
  state (output and cache removed before each run).
- The median of `RUNS` runs is reported to dampen scheduler noise.

## CI workflow

[`.github/workflows/benchmark.yml`](../.github/workflows/benchmark.yml) builds
both the normal (`-d`) and optimized (`--release`) binaries in CI and runs the
harness on every push to `main` (and on manual dispatch), installing the
**latest** Hugo release directly from GitHub (the Ubuntu apt package is years
behind and skews the comparison) so the timings are representative. The
results are:

- published to the Actions run's summary
- uploaded as the `benchmark-results` artifact
- on **manual** dispatch, committed to `bench/results/latest.json` so the
  repo keeps a current baseline (manual-only to avoid re-triggering the slow
  workflow)

## Baseline

The repo's committed baseline is a **dev-build** reference captured in the
dual-mode format (see
[`results/20260820T135134Z.json`](results/20260820T135134Z.json)):

- **nicolino 0.22.0** (`--fast-mode -B -p`, 12 cores, dev build): **1.169 s** (4000 html)
- **hugo v0.164.0**: **0.604 s** (4004 html)

That run used an unoptimized dev binary so it does not reflect shipping
performance. Use the CI workflow (or a local `--release` build) for
representative numbers; the optimized figures are published to each `main`
run's summary and, when refreshed manually, to `bench/results/latest.json`.
