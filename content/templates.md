---
Title: How templates Work in Nicolino
---

Templates are used to make your content look nice. They are written in
the [Crinja template languaje](https://straight-shoota.github.io/crinja/),
which is basically the same as the popular "Jinja2" used by most static
site generators.

They can expand `variables` and use `filters` to transform them. They
can also do some limited logic, like iterate over lists of things or
display elements conditionally.

## Basic Syntax

Just go and read a Jinja tutorial, most things are the same. But here
is an example anyway, I hope the syntax is readable enough:

```django
{% include "templates/title.tmpl" %}
{% if date | length > 0 %}
date: {{date}}
{% endif %}
</br>
{% if toc %}
{{toc}}
{% endif %}
{{html}}
```

## Global variables

These variables are available in all templates:

* `site_footer` (string): The footer of the site, as defined in the config.
* `site_description` (string): Th description of the site, as defined in the config.
* `canonical_url` (string): The canonical URL of the site, as defined in the config.

And everything else you define in your `conf.yml` file under `site`.

Example:

```yaml
# Some site options. These are available in templates
# as site_name (ex: site_title)
site:
  title: "Nicolino Test Blog"
  description: "This is the demo site for Nicolino"
  url: "https://example.com"
  footer: "Default Nicolino Theme"
```

## Filters

A filter in Jinja is a function that you can use in the templates.
For example, you could have a filter called `backwards` that takes a string and turns it backwards. So if you had this in your template

```jinja2
{{ "sarlanga" | backwards }}
```

Your document would have the "agnalras" string in it.

Our template engine [Crinja](https://straight-shoota.github.io/crinja/)
supports all the [builtin filters](https://jinja.palletsprojects.com/en/2.9.x/templates/#list-of-builtin-filters) from jinja2.

You can also extend it with your own filters written in [Wren](https://wren.io) by writing a wren function and placing it in `template_extensions/filters/filtername.wren`

This, for example, is an implementation of the `backwards` filter:

```wren
var filter = Fn.new { |target|
    var y = ""
    for (c in (target.count-1)..0) {
        y = y + target[c]
    }
    return y
}
```

In your custom filters the first argument is always `target`, the string
being filtered. If your filter supports more arguments, they will be passed in
**alphabetical order**.

For example, consider this `hello` filter:

```wren
var filter = Fn.new { |target, greeting, is_super|
  var result = ""
  if (is_super) {
    result = "Super "
  }
  return result + greeting + " " + target
}
```

If your template contained this:

```jinja2
{{ "world" | greeting(greeting="Hi", is_super=true) }}
{{ "mundo" | greeting(greeting="Hola", is_super=false) }}
```

The output will be

```
Super Hi world
Hola mundo
```

**NOTE:** Filters written in wren are slower than the filters that come with Crinja. On the other hand, you probably won't notice the difference unless you are using a ton of them.

## Available Templates

### page

Used to show ... pages. The basic look of the whole site. All the pages in the site use this template.

In it you can use the following variables:

* content: The actual content of the page.

### post

This is used to format a blog post and turn it into `content` to be inserted in the `page` template.

In it you can use the following variables:

* breadcrumbs: a list of breadcrumbs describing page hierarchy
* date: The date of the post (optional)
* html: The actual content of the post
* link: Link to the page's canonical location
* source: Path to the source file (probably won't ever need to use it)
* summary: A summary for the content of the post
* taxonomies: A list of taxonomies for the post
* title: The title of the post
* toc: The table of contents of the post (optional)
* metadata: the full post metadata

### index

TBD

### taxonomy

TBD

### title

TBD

### gallery

TBD
