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
* CLI arg to only build a specific thing
* HTML manipulation using kostya/lexbor

* ~~Verbosity levels~~
* ~~Asset copying~~
* ~~Fix bug where pages are rebuilt uselessly~~
* ~~Load templates lazy~~
* ~~Normalize metadata key case~~
* ~~Real CLI interface~~

## Things that are not such a great idea, and why

* Use ECR as template engine

  ECR is too static, all templates need to be declared
  at compile time. That means that although performance
  may be great (not tested) it's not possible to have
  a post say "I want to use template 'whatever' and
  have it.

  It *would* be possible to generate code for all templates
  and rebuild nicolino every time a template is added, but
  that looks like a lot of work.
