require "./markdown"

module HTML
  # Posts written directly in HTML
  class File < Markdown::File
    def html
      lang = Locale.language
      # FIXME: Implement TOC using lexbor
      @html[lang] = replace_shortcodes
      @html[lang] = HtmlFilters.downgrade_headers(html)
      @html[lang] = HtmlFilters.make_links_absolute(html, link)
    end
  end

  # Parse all HTML posts in a path and build HTML::File
  # objects out of them
  def self.read_all(path)
    Log.info { "Reading HTML files from #{path}" }
    posts = [] of File
    Dir.glob("#{path}/**/*.html").each do |p|
      begin
        # FIXME: do properly
        posts << File.new({"en" => p}, Path[p])
      rescue ex
        Log.error { "Error parsing #{p}: #{ex.message}" }
        Log.debug { ex }
      end
    end
    posts
  end
end