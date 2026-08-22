Filters are small functions that transform values inside templates:
`{{ title | upper }}` pipes `title` through the built-in `upper` filter.
Nicolino lets you define **your own filters in Lua**, without recompiling
anything.

## Quick start

Create a script in a `filters` directory that returns a table of
functions: site-wide in `filters/` at the project root, or inside your
theme in `themes/<your-theme>/filters/`. On name collisions the
site-level script wins.

```lua
-- themes/<your-theme>/filters/text.lua
return {
  shout = function(text)
    return string.upper(text) .. "!"
  end,
}
```

Every function in the table becomes a filter, usable from any template
(or shortcode):

```django
{{ title | shout }}
```

If the site title is "Hello", this renders `HELLO!`.

## See it live

This documentation site uses its own filters — `filters/docs.lua` at
the project root defines a `reverse_title_case` filter, the opposite
of Title Case: the first letter of each word goes lowercase and the
rest go uppercase. The `luademo` shortcode below pipes its body
through that very filter:

{{< luademo >}}hi there{{< /luademo >}}

(One gotcha learned the hard way: shortcode names cannot contain
hyphens, hence `luademo` rather than `lua-demo`.)

## Arguments

The value you pipe in arrives as the first argument; any extra filter
arguments follow:

```lua
return {
  wrap = function(text, tag)
    return "<" .. tag .. ">" .. text .. "</" .. tag .. ">"
  end,
}
```

```django
{{ "important" | wrap("em") }}
```

## Value conversion

Values cross the Lua boundary automatically in both directions:

| Jinja side | Lua side |
|------------|----------|
| string | string |
| integer / float | number |
| boolean | boolean |
| nothing (undefined) | nil |
| array | table with keys `1..n` |
| dictionary | table with string keys |

Returning a table with sequential keys `1..n` gives back an array, so
filters can produce lists to iterate over:

```lua
return {
  letters = function(text)
    local result = {}
    for char in text:gmatch(".") do
      table.insert(result, char)
    end
    return result
  end,
}
```

```django
{% for letter in "abc" | letters %}[{{ letter }}]{% endfor %}
```

Integral numbers come back as integers (`4`, not `4.0`), so numeric
filters render cleanly. A filter returning multiple values: only the
first one is used.

## Multiple filters and name collisions

You can split filters across as many `.lua` files as you like, in both
the site-level and theme directories; all tables are merged into one
namespace. If two files export the same name, the file loaded last wins
(site scripts load after theme scripts) and a warning is logged.

The full standard library is available inside your functions:
`string`, `table`, `math`, `os`, `io`, etc.

## Live reload

Running `nicolino auto`? Edit a filter, save, and pages using it are
re-rendered automatically — no restart needed. A script with a syntax
error fails the build loudly, naming the file and line.

## Security note

Filter scripts run with Lua's full standard library at *build* time,
so a theme's `filters/` directory is trusted code — the same trust
level as the theme's templates or your `conf.yml`. Review it before
installing third-party themes.

## Limitations

- Filters execute inside templates only; markdown content is not a
  template, so use shortcodes there instead.
- Script top-level code runs once per build worker; keep it free of
  side effects beyond defining the returned functions.
