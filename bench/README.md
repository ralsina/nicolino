# Benchmark harness

Reproducibly times a full build of a 4000-file Markdown corpus with Nicolino
and (optionally) Hugo, and records the results. It exists to make the
project's "faster than Hugo" claim measurable rather than anecdotal.

The corpus is a snapshot of Zach Leat's static-site build benchmark
(<https://www.zachleat.com/web/build-benchmark/>), vendored under
[`corpus/`](corpus/).

## Requirements

- a **release** build of `nicolino` (see below; dev builds are unoptimized and
  not representative)
- `hugo` on `PATH` (optional — the Hugo comparison is skipped if absent)
- `bash`, `awk`, `date`

> **Use a release binary.** Dev builds (`shards build -d`) are roughly 2x
> slower and make the results meaningless. Build one locally with
> `shards build --release` (takes ~20 minutes) or, better, let CI do it — see
> the [CI workflow](#ci-workflow) below.

## Usage

```sh
shards build --release
NICOLINO_BIN="$PWD/bin/nicolino" ./bench/run.sh
```

The harness:

1. copies the corpus into a throwaway `bench/site/content/` and
   `bench/hugo/content/posts/`
2. times several full builds of each tool (median of `RUNS` runs, default 3),
   cleaning between runs so every timing measures a fresh build
3. asserts every corpus file rendered
4. writes a timestamped JSON report to `bench/results/` and prints a summary

### Configuration

| Env var           | Default                | Purpose                            |
| ----------------- | ---------------------- | ---------------------------------- |
| `RUNS`            | `3`                    | Number of timed runs per tool      |
| `NICOLINO_BIN`    | `./bin/nicolino`       | Path to the nicolino binary        |
| `HUGO_BIN`        | `$(command -v hugo)`   | Path to hugo (empty skips hugo)    |
| `NICOLINO_FLAGS`  | `--fast-mode -B -p`    | Flags passed to `nicolino build`   |
| `CRYSTAL_WORKERS` | `$(nproc)`             | Crystal worker count               |
| `BUILD_MODE`      | `dev`                  | Recorded in the result JSON        |

## Methodology

- Both tools render the same 4000 files to HTML. The nicolino site uses the
  `pages` feature so every file is rendered regardless of frontmatter dates;
  the hugo site uses a minimal `bench` theme.
- Timing measures wall-clock time of the full build command from a clean
  state (output and cache removed before each run).
- The median of `RUNS` runs is reported to dampen scheduler noise.

## CI workflow

[`.github/workflows/benchmark.yml`](../.github/workflows/benchmark.yml) builds
the optimized `--release` binary in CI and runs the harness on every push to
`main` (and on manual dispatch), installing Hugo so the comparison is
reproduced. The results are:

- published to the Actions run's summary
- uploaded as the `benchmark-results` artifact
- on **manual** dispatch, committed to `bench/results/latest.json` so the
  repo keeps a current baseline (manual-only to avoid re-triggering the slow
  workflow)

## Baseline

The repo's committed baseline is a **dev-build** reference captured when the
corpus was first vendored (see
[`results/20260820T124100Z.json`](results/20260820T124100Z.json)):

- **nicolino 0.22.0** (`--fast-mode -B -p`, 12 workers, dev build): **1.370 s** (4000 html)
- **hugo v0.164.0**: **0.877 s** (4004 html)

Because that run used an unoptimized dev binary it does not reflect shipping
performance. Use the CI workflow (or a local `--release` build) for
representative numbers; the optimized figures are published to each `main`
run's summary and, when refreshed manually, to `bench/results/latest.json`.
