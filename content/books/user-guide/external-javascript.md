---
title: External JavaScript
---

Nicolino generates static HTML, but that HTML is a perfectly good host for
JavaScript-driven widgets: charts, maps, comment systems, or anything else
that runs in the browser. This chapter shows the two building blocks you
need: loading external libraries, and wrapping them in shortcodes so your
content stays clean markdown.

## Loading a library

To load a library on every page of your site, add the script tags to your
theme's `templates/page.tmpl`, usually right before `</body>`:

```html
<script src="https://cdn.jsdelivr.net/npm/vega@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
```

If you only need it on specific pages, put the tags directly in those
pages' markdown instead — Nicolino passes raw HTML through untouched.

## Wrapping widgets in a shortcode

Shortcodes let you hide fiddly boilerplate behind a friendly tag.
This is all it takes to make a Vega-Lite shortcode — save it as
`shortcodes/vegalite.tmpl` in your site (it ships with Nicolino):

```html
<div class="vega-chart" id="{{chart_id}}"></div>
<script>
  document.addEventListener("DOMContentLoaded", function() {
    var spec = {{inner}};
    vegaEmbed('#{{chart_id}}', spec, {actions: false});
  });
</script>
```

You can read [the shipped version](https://github.com/ralsina/nicolino/blob/main/shortcodes/vegalite.tmpl)
for details such as optional chart ids.

## Drawing a chart

Once the libraries are loaded and the shortcode exists, charts are just
markdown. Use the *verbatim* shortcode form (the one with angle
brackets) so the JSON reaches the browser exactly as written, instead
of being processed as markdown:

{{< raw >}}
```
{{< vegalite id="doc-example-bar" >}}
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "description": "A simple bar chart with embedded data.",
  "data": {
    "values": [
      {"category": "A", "amount": 28},
      {"category": "B", "amount": 55},
      {"category": "C", "amount": 43},
      {"category": "D", "amount": 91},
      {"category": "E", "amount": 81}
    ]
  },
  "mark": "bar",
  "encoding": {
    "x": {"field": "category", "type": "nominal"},
    "y": {"field": "amount", "type": "quantitative"}
  }
}
{{< /vegalite >}}
```
{{< /raw >}}

Here is that same chart for real:

{{< vegalite id="doc-example-bar-live" >}}
{"$schema":"https://vega.github.io/schema/vega-lite/v5.json",
"data":{"values":[
{"category":"A","amount":28},{"category":"B","amount":55},
{"category":"C","amount":43},{"category":"D","amount":91},
{"category":"E","amount":81}]},
"mark":"bar",
"encoding":{"x":{"field":"category","type":"nominal"},
"y":{"field":"amount","type":"quantitative"}}}
{{< /vegalite >}}

Give every chart on a page its own `id`. The whole
[Vega-Lite specification](https://vega.github.io/vega-lite/docs/) is at
your disposal: anything that works in their online editor works inside
the shortcode.

## Larger datasets

Inlining JSON works well for small datasets. When data grows, keep the
spec small by pointing at an external file:

```json
"data": {"url": "/data/sales.json"}
```

Place `data/sales.json` in your content directory so it gets copied to
the output, or fetch it from an external source at build time using the
[Import](import.md) feature.

<script src="https://cdn.jsdelivr.net/npm/vega@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
