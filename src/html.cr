require "./markdown"

module HTML
  # Posts written directly in HTML
  class File < Markdown::File
    def html(lang = nil)
      lang ||= Locale.language
      # FIXME: Implement TOC using lexbor
      result = replace_shortcodes(lang)
      doc = Lexbor::Parser.new(result)
      doc = HtmlFilters.downgrade_headers(doc)
      doc = HtmlFilters.make_links_relative(doc, link)
      @html[lang] = doc.to_html
    end
  end

  # Parse all HTML posts in a path and build HTML::File
  # objects out of them
  def self.read_all(path)
    Log.debug { "Reading HTML files from #{path}" }
    posts = [] of File
    all_sources = Utils.find_all(path, "html")
    all_sources.map do |base, sources|
      begin
        next if File.posts.keys.includes? base.to_s
        next if Utils.should_skip_file?(base)

        posts << File.new(sources, base)
      rescue ex
        Log.error { "Error parsing #{base}: #{ex.message}" }
        Log.debug { ex }
      end
    end
    posts
  end
end
