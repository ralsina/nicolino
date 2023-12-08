---
Title: How templates Work in Nicolino
---

Templates are used to make your content look nice. They are written in
the "Crinja" template languaje, which is basically the same as the
popular "Jinja" used by most static site generators.

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

* site_footer (string): The footer of the site, as defined in the config.
* site_description (string): The description of the site, as defined in the config.
* canonical_url (string): The canonical URL of the site, as defined in the config.

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
