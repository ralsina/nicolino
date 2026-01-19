Creates a new post, gallery or page.

## Usage

```text
{{% shell command="bin/nicolino new --help" %}}
```

## Description

The PATH is where it will be created. The kind of object to be
created depends on the PATH.

For example:

* content/galleries/foo will create a new gallery
* content/posts/foo will create a new blog post

Anything else will create a new page. The template for the file
being created is inside models/

Those paths may vary depending on your configuration.
