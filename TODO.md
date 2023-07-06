# TODO

## Things that could be done

* Write real templates
* Try maybe gunbolt.org
  or shootingfly/water
  or crinja
* Implement index page generation
* Live / autoreload mode?
* Image gallery
* Support tags
* Teasers
* Add text/teaser to the RSS feed
* HTML manipulation using kostya/lexbor or madeindjs/crystagiri
* Add auto mode
* TUI using termbox2.cr
* Minifier via html-minifier
* live-reload via LiveReload.cr
* Use croupier's k/v store to avoid reading parsing post data
  all the time

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
