---
title: "Code Blocks"
date: 2026-08-23
tags: [code, demo]
---

Fenced code blocks with language tags. This post deliberately has no
Spanish translation: switch to `es` and it appears flagged as
untranslated (`is_fallback: true`).

## Crystal

```crystal
module Nicolino
  def self.build(site : String) : Nil
    config = Config.load("#{site}/conf.yml")
    tasks = TaskRegistry.new
    Features.enable(config, tasks)
    tasks.run(parallel: true)
  end
end
```

## Python

```python
from dataclasses import dataclass

@dataclass
class Post:
    title: str
    date: str
    tags: list[str] = field(default_factory=list)

posts = sorted(posts, key=lambda p: p.date, reverse=True)
```

## Shell

```bash
# from zero to a themed site
nicolino init mysite
cd mysite
nicolino theme install terminal
sed -i 's/theme: default/theme: terminal/' conf.yml
nicolino serve
```

## JSON

```json
{
  "name": "nicolino",
  "version": "0.24.0",
  "language": "crystal",
  "features": ["posts", "taxonomies", "base16"]
}
```

Inline code like `Config.load` should also look right in running
text.
