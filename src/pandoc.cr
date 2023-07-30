require "./markdown"

module Pandoc
  class File < Markdown::File
    def html
      # FIXME: Figure out how to extract TOC
      ext = Path[@source].extension
      format = Config.options.formats[ext]
      @html, @toc = Pandoc.compile(
        replace_shortcodes,
        @metadata.fetch("toc", nil) != nil,
        format: format)
      @html = HtmlFilters.downgrade_headers(@html)
      @html = HtmlFilters.make_links_absolute(@html, @link)
    end
  end

  # Parse all pandoc posts in a path and build Pandoc::File
  # objects out of them
  def self.read_all(path)
    Log.info { "Reading pandoc files from #{path}" }
    posts = [] of File
    Config.options.formats.keys.each do |ext|
      Dir.glob("#{path}/**/*#{ext}").each do |p|
        begin
          posts << File.new(p)
        rescue ex
          Log.error { "Error parsing #{p}: #{ex.message}" }
          Log.debug { ex }
        end
      end
    end
    posts
  end

  def self.compile(input, toc = false, format = "rst")
    input = IO::Memory.new(input)
    output = IO::Memory.new
    Process.run("pandoc",
      args: ["-f", format, "-t", "html"],
      input: input,
      output: output)
    [output.to_s, ""]
  end
end
