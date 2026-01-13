module Utils
  def self.slugify(string)
    string.downcase.strip.gsub(' ', '-').gsub(/[^\w]/, '-').gsub(/-+/, '-')
  end

  # Convert path to link, optionally changing extension
  #
  # >> path_to_link("output/foo/../bar") # => "/bar"
  def self.path_to_link(path, extension = nil)
    p = Path[path].normalize
    # Ensure path starts with "output" and doesn't escape it via ".."
    if p.parts.empty? || p.parts[0] != "output"
      raise "Invalid path: #{path} (must start with output/)"
    end

    # Remove "output" prefix and convert to link
    link_parts = p.parts[1..]
    if extension.nil?
      "/#{link_parts.join("/")}"
    else
      "/#{link_parts.join("/").rchop(p.extension)}#{extension}"
    end
  end

  # Filter out files from directories that correspond to disabled features
  def self.should_skip_file?(base_path : Path) : Bool
    begin
      features = Config.get("features")
    rescue
      return false
    end

    enabled_features = features.as_a
    content_path = Config.options.content

    # Skip gallery directories when galleries feature is disabled
    if !enabled_features.includes?("galleries")
      galleries_path = Path[content_path] / Config.options.galleries
      return true if base_path.to_s.starts_with?(galleries_path.to_s)
    end

    # Skip other feature directories as needed in the future
    # Example: posts, images, etc.

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
      if !stem_ext.empty? && Config.languages.keys.includes? stem_ext[1..]
        stem = stem.stem
      end
      bases << Path[dirname] / stem
    end

    # Now for each base file find sources for all languages
    #
    # If there is a localized file for that language, use it
    # If not, use the file for the first language that has a file
    all_sources = Hash(Path, Hash(String, String)).new
    bases.each do |base|
      sources = Hash(String, String).new
      possible_sources = (["#{base}.#{extension}"] +
                          Config.languages.keys.map { |lang| "#{base}.#{lang}.#{extension}" }) \
        .select { |source| ::File.exists? source }
      Config.languages.keys.each do |lang|
        lang_base = "#{base}.#{lang}.#{extension}"
        if possible_sources.includes? lang_base
          sources[lang] = lang_base
        else
          sources[lang] = possible_sources[0]
        end
      end
      all_sources[base] = sources
    end
    all_sources
  end
end
