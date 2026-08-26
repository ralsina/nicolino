require "lexbor"

module Utils
  def self.slugify(string)
    string.downcase.strip.gsub(' ', '-').gsub(/[^\w]/, '-').gsub(/-+/, '-')
  end

  # Plain-text excerpt of an HTML fragment, for meta description tags:
  # strips tags via lexbor, collapses whitespace, and truncates to at
  # most *limit* characters at a word boundary with an ellipsis.
  def self.text_excerpt(html : String, limit = 200) : String
    return "" if html.strip.empty?
    text = Lexbor::Parser.new(html).body.try(&.inner_text) || ""
    text = text.gsub(/\s+/, " ").strip
    return text if text.size <= limit
    cut = text[0, limit]
    if space = cut.rindex(' ')
      cut = cut[0, space]
    end
    "#{cut}…"
  end

  def self.titlecase(string)
    string.split(/[-_\s]/).map(&.capitalize).join(" ")
  end

  # Convert path to link, optionally changing extension
  #
  # >> path_to_link("output/foo/../bar") # => "/bar"
  def self.path_to_link(path, extension = nil)
    p = Path[path].normalize
    output_parts = Path[Config.options.output].normalize.parts
    # Ensure path starts with the output dir and doesn't escape it via ".."
    if p.parts.size < output_parts.size || p.parts[0, output_parts.size] != output_parts
      raise "Invalid path: #{path} (must start with #{Config.options.output})"
    end

    # Remove the output dir prefix and convert to link
    link_parts = p.parts[output_parts.size..]
    if extension.nil?
      "/#{link_parts.join("/")}"
    else
      "/#{link_parts.join("/").rchop(p.extension)}#{extension}"
    end
  end

  # Suffix to append to a filename for a given language
  # (empty for the default language, ".#{lang}" otherwise)
  def self.lang_suffix(lang : String) : String
    lang == Config.default_lang ? "" : ".#{lang}"
  end

  # The configured output directory with a trailing slash, for building
  # URL prefixes (e.g. "output/", "public/site/")
  def self.output_prefix : String
    output = Path[Config.options.output].normalize.to_s
    output.ends_with?("/") ? output : "#{output}/"
  end

  # Glob patterns for markdown, html and pandoc content under a base path
  def self.content_globs(base_path : Path) : Array(String)
    globs = [] of String
    globs << "#{base_path}/**/*.md"
    globs << "#{base_path}/**/*.html"
    Config.options.pandoc_formats.keys.each do |ext|
      globs << "#{base_path}/**/*#{ext}"
    end
    globs
  end

  # Create the right content file for a source based on its extension
  # kind is used in error messages (e.g. "post", "page")
  def self.create_content_file(sources : Hash(String, String), base : Path, kind : String) : Markdown::File?
    first_source = sources.values.first? || return
    ext = Path[first_source].extension
    case ext
    when ".html"
      HTML::File.new(sources, base)
    when /\.(rst|tex|latex|mdoc|adoc|asciidoc)$/
      Pandoc::File.new(sources, base)
    else
      Markdown::File.new(sources, base)
    end
  rescue ex
    Log.error { "Error creating #{kind} file #{base}: #{ex.message}" }
    Log.debug { ex }
    nil
  end

  # Process inputs in parallel chunks, returning per-chunk results in order.
  # Errors in a chunk are logged and that chunk is skipped.
  def self.parallel_chunks(inputs : Array(String), chunk_size : Int32 = 100, &block : Array(String), Int32 -> T) : Array(T) forall T
    num_chunks = (inputs.size // chunk_size) + 1
    channels = Channel(T | Exception).new
    num_chunks.times do |chunk_idx|
      spawn do
        begin
          start_idx = chunk_idx * chunk_size
          end_idx = Math.min(start_idx + chunk_size, inputs.size)
          chunk_data = inputs[start_idx...end_idx]
          channels.send(block.call(chunk_data, start_idx))
        rescue ex
          channels.send(ex)
        end
      end
    end

    results = [] of T
    num_chunks.times do
      result = channels.receive
      case result
      when Exception
        Log.error(exception: result) { "Error in parallel chunk; skipping it" }
      else
        results << result
      end
    end
    results
  end

  # Filter out files from directories that correspond to disabled features
  def self.should_skip_file?(base_path : Path) : Bool
    enabled_features = Config.features
    content_path = Config.content

    # Skip gallery directories when galleries feature is disabled
    if !enabled_features.includes?("galleries")
      galleries_path = Path[content_path] / Config.galleries
      return true if base_path.to_s.starts_with?(galleries_path.to_s)
    end

    # Skip books directories when the books feature is enabled: the
    # Books feature renders those sources itself. When disabled, let
    # them flow through the regular content pipeline instead of
    # silently dropping them
    if enabled_features.includes?("books")
      books_path = Path[content_path] / Config.books
      return true if base_path.to_s.starts_with?(books_path.to_s)
    end

    false
  end

  # Find all files with given extension in path,
  # if two files are alternative languages of one another
  # they are grouped together.
  def self.find_all(path, extension)
    bases = Set(Path).new
    # Find base files for posts
    Dir.glob("#{path}/**/*.#{extension}").each do |fname|
      base = Path[fname]
      dirname = base.dirname
      stem = Path[base.stem]
      stem_ext = stem.extension
      if !stem_ext.empty? && Config.languages.includes? stem_ext[1..]
        stem = stem.stem
      end
      bases << Path[dirname] / stem
    end

    # Now for each base file find sources for all languages
    #
    # If there is a localized file for that language, use it.
    # Otherwise:
    # - With content fallback (default), use the first available
    #   source (usually the unsuffixed base file) so every language
    #   gets a version of the content, flagged as fallback.
    # - Without content fallback, only the unsuffixed base file may
    #   be shared; languages with no dedicated file get no source at
    #   all and their pages are simply not generated.
    all_sources = Hash(Path, Hash(String, String)).new
    bases.each do |base|
      sources = Hash(String, String).new
      possible_sources = (["#{base}.#{extension}"] +
                          Config.languages.map { |lang| "#{base}.#{lang}.#{extension}" }) \
        .select { |source| ::File.exists? source }
      Config.languages.each do |lang|
        lang_base = "#{base}.#{lang}.#{extension}"
        if possible_sources.includes? lang_base
          sources[lang] = lang_base
        elsif Config.content_fallback? || possible_sources[0] == "#{base}.#{extension}"
          sources[lang] = possible_sources[0]
        end
      end
      all_sources[base] = sources unless sources.empty?
    end
    all_sources
  end

  # Alternate-language links for a generated page. Two output
  # conventions exist (issue #54):
  #
  # - :file_suffix (default): "<stem>.<lang>.html" / "<stem>.html",
  #   used by post and folder index pages
  #   (output/posts/index.es.html)
  # - :dir_suffix: the FIRST directory under output/ carries the
  #   language marker (output/tags.es/foo/index.html), used by
  #   taxonomies, the archive and galleries roots
  #
  # Returns one {lang, link, title} hash per other configured
  # language. This is the site-level helper behind translation
  # switcher menus.
  def self.language_links_for(output_path : String | Path, lang : String,
                              style : Symbol = :file_suffix) : Array(Hash(String, String))
    result = [] of Hash(String, String)
    output_str = output_path.to_s

    Config.languages.each do |other_lang|
      next if other_lang == lang

      alt_path = case style
                 when :dir_suffix
                   dir_suffix_alt_path(output_str, lang, other_lang)
                 else
                   # If current is output/posts/index.html, the alternate is
                   # output/posts/index.es.html; if current is index.es.html, the
                   # alternate for another language L is index.L.html (and the
                   # default language has no suffix)
                   if lang == Config.default_lang
                     output_str.sub(/\.html$/, ".#{other_lang}.html")
                   else
                     output_str.sub(/\.#{lang}\.html$/, other_lang == Config.default_lang ? ".html" : ".#{other_lang}.html")
                   end
                 end

      site_title = begin
        Config[other_lang].title
      rescue
        other_lang.upcase
      end
      result << {
        "lang"  => other_lang,
        "link"  => Utils.path_to_link(Path[alt_path]),
        "title" => site_title,
      }
    end

    result
  end

  # Alternate path for the dir-suffix convention: the language
  # marker rides on the first directory under the output root
  # (output/tags.es/foo/index.html <-> output/tags/foo/index.html)
  private def self.dir_suffix_alt_path(output_str : String, lang : String, other_lang : String) : String
    parts = output_str.split('/')
    idx = parts.index(Config.options.output.rstrip('/')) || 0
    component = parts[idx + 1]?
    return output_str unless component

    parts[idx + 1] = if lang == Config.default_lang
                       "#{component}.#{other_lang}"
                     elsif component.ends_with?(".#{lang}")
                       stripped = component.rchop(".#{lang}")
                       other_lang == Config.default_lang ? stripped : "#{stripped}.#{other_lang}"
                     else
                       component
                     end
    parts.join('/')
  end
end
