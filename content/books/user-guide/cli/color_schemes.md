List and apply available base16 color scheme families.

## Usage

```text
{{% shell command="bin/nicolino color_schemes --help" %}}
```

## Description

Color schemes are configured in conf.yml using a family base name:

```yaml
site:
  color_scheme: "unikitty"
```text

The sixteen library will automatically find the dark and light variants
for each family. If a variant doesn't exist, it will be auto-generated.

Examples of theme families:
  - unikitty, catppuccin, rose-pine
  - atelier-cave, atelier-dune, atelier-forest, etc.
  - dracula, monokai, nord, solarized

Use `--apply` to set the color scheme, or run without options to list
all available families with color swatches.

You can browse all the color families at <https://sixteen.ralsina.me>
