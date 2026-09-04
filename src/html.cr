require "./markdown"
require "./toc"

module HTML
  # Posts written directly in HTML
  class File < Markdown::File
    # Produce the {html, toc} pair for this file; memoization and
    # thread safety are handled by Markdown::File#html
    private def compile_html(lang)
      result = replace_shortcodes(lang)
      doc = Lexbor::Parser.new(result)
      doc = HtmlFilters.downgrade_headers(doc)
      doc = HtmlFilters.remove_empty_paragraphs(doc)
      # Links stay root-relative here: the same body is embedded in
      # listing pages at different depths, so links must only be
      # relativized at the final page render.
      html_with_classes = HtmlFilters.fix_code_classes(doc).to_html

      # TOC is opt-in via `toc` metadata, matching markdown posts:
      # short HTML posts (book reviews, feed imports) would otherwise
      # all sprout a one-entry TOC for their single heading
      if metadata(lang).has_key?("toc")
        Toc.extract_and_annotate(html_with_classes)
      else
        {html_with_classes, ""}
      end
    end
  end

  # Parse all HTML posts in a path and build HTML::File
  # objects out of them
  def self.read_all(path)
    Log.debug { "Reading HTML files from #{path}" }
    all_sources = Utils.find_all(path, "html")
    todo = all_sources.reject do |base, _|
      Markdown.posts.has_key?(base.to_s) || Utils.should_skip_file?(base)
    end
    Markdown.files_from(todo) do |sources, base|
      File.new(sources, base)
    rescue ex
      Log.error { "Error parsing #{base}: #{ex.message}" }
      Log.debug { ex }
      nil
    end
  end
end
