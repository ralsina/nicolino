# TODO

## Bugs

* If a template is modified, auto mode goes nuts, prints

  `ERROR: Error running task for LiveReload: Task`
  `LiveReload:: failed: Invalid path: kv://templates/page.tmpl`

  That is fixed in main but need to confirm auto mode works
  correctly when updating templates

## Things that could be done

* Link preprocessor
  * Figure out the equivalent of Nikola's `link://` schema
  * Patch served pages to use localhost:port instead of the configured URL

* Template rewrite:
  * Support fallback templates. So, for example a taxonomy can be custom but
    fallback to index.tmpl
  * Support multiple template paths
  * Templates created while in auto mode aren't detected

* More tasks
  * Add pages to taxonomies besides posts
  * Implement "Archive" of all content
  * Link checker (for internal links)
  * Draft / future / expired

* Code QoL
  * Figure out per-command flags or migrate off commander
    (at-grandpa/clim looks good)
  * Need better date parser, like dateparser from Python
  * Add slug-for-url support?
  * Port thumbnail shortcode from Nikola
  * Support arbitrary command pipelines
  * Plugins using veelenga/lua.cr? anyolite/mruby? What plugins? Crinja custom filters?
  * Implement something like nikola's continuous import (different binary?)
  * Reorganize theme so it's self contained
  * Usage of link without lang in File::html() call to make_links_absolute
    is probably wrong

* Misc
  * The markdown compiler doesn't force language-foo class on code blocks
  * Fix search box
  * Write folder_index template
  * Support video in galleries (I have `.mov` files there!)

* Galleries
  * Make galleries without a "index.md" file work properly?
  * ~~Galleries with empty index.md have no title~~
  * Crumbs links are garbage

* Bugs:
  * ~~Respect configurable "content" directory in markdown posts~~

* ~~More robust post metadata loading (posts without metadata)~~
* ~~Image gallery index / Generic folder index~~
* ~~Validator for posts~~
* ~~Do not *always* parse shortcode replacements as markdown (for pandoc)~~
  {{< >}} shortcodes are not markdown
* ~~Better document parsing errors~~
* ~~Add progress bar using mgomes/progress_bar (requires croupier work)~~
* ~~Taxonomies have no titles~~
* ~~Try to be close to hugo's input layout if possible~~
* ~~Implement `new_post` `new_page` commands~~
* ~~Un-hardcode a bunch of things~~
  * ~~output/~~
  * ~~posts~~
  * ~~pages~~
  * ~~output/posts/index.html~~
* ~~Implement init command (with data via rucksack?)~~
* ~~Think how to do translations~~
* ~~Add RSS link elements where appropriate~~
* ~~Un-ad-hoc path handlings (lchop output and such)~~
* ~~Add noindex meta tag to "index" pages, and remove~~
  ~~them from sitemap~~
* ~~Add slugification where needed~~
* ~~HTML "compiler"~~
* ~~Fix bug of multiple `output/tags/index.html` when importing~~
  ~~large site.~~
* ~~Use nanobowers/cronic to parse dates~~
* ~~Automatically show taxonomies in post headings~~
* ~~Use a real config library~~
* ~~Implement `clean`~~
* ~~Support arbitrary compilers defined in config somehow (start with pandoc)~~
* ~~Make auto mode more resilient to bad inputs~~
* ~~Detect new posts/pages and handle that in auto mode~~
* ~~Fix bug in auto where changes are only triggering once~~
* ~~Enable/disable features from config~~
* ~~Make sure all things have proper titles~~
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

* Minifier via html-minifier

  While I will *maybe* implement arbitrary command pipelines,
  which will provide a backdoor to this, I don't think it's
  worth implementing on its own. Further I don't think minifying
  the small HTML files generated by nicolino is worth it.

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

  Checked amauryt/cr-cmark-gfm and it's not faster than discount.

* TUI using homonoidian/termbox2.cr

  Not really needed. Can't think of a usecase, really.
