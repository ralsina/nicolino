require "./command.cr"

module Nicolino
  module Commands
    # nicolino new command
    struct New < Command
      @@name = "new"
      @@doc = <<-DOC
Creates a new post, gallery or page.

The PATH is where it will be created. The kind of object to be
created depends on the PATH.

For example:

* content/galleries/foo will create a new gallery
* content/posts/foo will create a new blog post

Anything else will create a new page. The template for the file
being created is inside models/

Those paths may vary depending on your configuration.

Usage:
  nicolino new PATH [-c <file>][-q|-v <level>]

Options:
  -c <file>        Specify a config file to use [default: conf.yml]
  -v level         Control the verbosity, 0 to 6 [default: 4]
  -q               Don't log anything [default: false]
DOC

      def run : Int32
        path = Path[@options["PATH"].as(String)]
        raise "Can't create #{path}, new is used to create data inside #{Config.options.content}" \
          if path.parts[0] != Config.options.content.rstrip("/")
        if path.parts.size < 3
          kind = "page"
        else
          # FIXME: This could be generalized so it works with more than one level
          # of subdirectory, so galleries could be in content/image/galleries
          kind = {
            Config.options.galleries.rstrip("/") => "gallery",
            Config.options.posts.rstrip("/")     => "post",
          }.fetch(path.parts[1], "page")
        end
        # Call the proper module's content generator with the path
        if kind == "post"
          Markdown.new_post path
        elsif kind == "gallery"
          Gallery.new_gallery path
        else
          Markdown.new_page path
        end
        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error creating new content: #{ex.message}" }
        1
      end
    end
  end
end

Nicolino::Commands::New.register
