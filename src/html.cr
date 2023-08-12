require "./markdown"

module HTML
  # Posts written directly in HTML
  class File < Markdown::File
    def html(lang = nil)
      lang ||= Locale.language
      # FIXME: Implement TOC using lexbor
      @html[lang] = replace_shortcodes(lang)
      @html[lang] = HtmlFilters.downgrade_headers(html(lang))
      @html[lang] = HtmlFilters.make_links_absolute(html(lang), link)
    end
  end

  # Parse all HTML posts in a path and build HTML::File
  # objects out of them
  def self.read_all(path)
    Log.info { "Reading HTML files from #{path}" }
    posts = [] of File
    all_sources = Utils.find_all(path, "html")
    all_sources.map do |base, sources|
      begin
        next if File.posts.keys.includes? base.to_s
        posts << File.new(sources, base)
      rescue ex
        Log.error { "Error parsing #{base}: #{ex.message}" }
        Log.debug { ex }
      end
    end
    posts
  end
end
