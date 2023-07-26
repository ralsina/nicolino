# TODO

## Things that could be done

* Enable/disable features from config
* Support arbitrary compilers defined in config somehow
* Support arbitrary command pipelines
* TUI using homonoidian/termbox2.cr
* Minifier via html-minifier
* Use nanobowers/cronic to parse dates
* Plugins using veelenga/lua.cr?
* Implement `new_post` `new_page` commands
* Implement init command (with data via rucksack?)
* Implement something like nikola's continuous import (different binary?)
* Reorganize theme so it's self contained
* Detect new posts/pages and handle that in auto mode
* Think how to do translations
* Image gallery index / Generic folder index
* Try to be close to hugo's input layout if possible
* Draft / future / expired
* Link checker (for internal links)
* Automatically show taxonomies in post headings
* Make sure all things have proper titles

* ~~Search using lucaong/minisearch?~~
* ~~Sitemap~~
* ~~Generalize tags/index into taxonomies~~
* ~~Link fixer~~
* ~~Decide what to do on output conflicts (like a page and~~
  ~~posts index)~~
* ~~Breadcrumbs~~
* ~~Parse templates to find dependencies and load recursively~~
* ~~Fix bug that broke incremental rendering for HTML.~~
  ~~Templates in k/v store are always stale.~~
* ~~Find a way to separate toc from summary~~
* ~~Sort post lists by date~~
* ~~Support tags~~
* ~~Teasers~~
* ~~Add text/teaser to the RSS feed~~
* ~~Fixed RSS generating wrong description in items~~
* ~~Parse and support shortcodes like nikola/hugo~~
* ~~Cleanup dependency handling (make posts calculate theirs)~~
* ~~Make theme selection persistent~~
* ~~Apply theme selection to code blocks~~
* ~~Image gallery~~
* ~~Think how to do TOC in markdown~~
* ~~Figure out why code blocks work on serve and not on auto (?!!?)~~
* ~~Check code block styling~~
* ~~Downgrade H1 to H3 in post content~~
* ~~Add a lightbox~~
* ~~Image copy/resize via pixie~~
* ~~HTML manipulation using kostya/lexbor~~ In place, can be used more.
* ~~live-reload via LiveReload.cr and server in auto mode~~
* ~~Implement index page generation~~ (at least ONE index page)
* ~~Write real templates (used picocss)~~
* ~~Add server mode~~
* ~~Add auto mode~~
* ~~Try crinja~~
* ~~CLI arg to only build a specific thing~~
* ~~Add flag for "run all / keep running / fast mode" and whatever~~
  ~~other flags Croupier has now.~~
* ~~Verbosity levels~~
* ~~Asset copying~~
* ~~Fix bug where pages are rebuilt uselessly~~
* ~~Load templates lazy~~
* ~~Normalize metadata key case~~
* ~~Real CLI interface~~

## Things that are not such a great idea, and why

* Use ECR as template engine

  ECR is too static, all templates need to be declared
  at compile time. That means it's not possible to have
  a post say "I want to use template 'whatever' and
  have it do so if the template was unknown at nicolino
  compile time.

  It *is* be possible to generate code for all templates
  and rebuild nicolino every time a template is added,
  a POC is in the [ecr-templates branch](https://github.com/ralsina/nicolino/tree/ecr-templates)
  but some testing indicates the performance gains are
  marginal.

* Check out other markdown implementations (md4c, hoedown, michaelrsweet/mmd)

  Discount seems to do pretty much everything I want, it's performant
  and it has a nice, tiny binding I wrote. So, LGTM.
