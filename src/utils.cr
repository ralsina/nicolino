module Utils
  def self.slugify(string)
    string.downcase.strip.gsub(' ', '-').gsub(/[^\w]/, '-').gsub(/-+/, '-')
  end

  # Convert path to link, optionally changing extension
  #
  # >> path_to_link("output/foo/../bar") # => "/bar"
  def self.path_to_link(path, extension = nil)
    p = Path[path].normalize
    raise "Invalid path: #{path}" unless p.parts[0] == "output"

    return "/#{p.parts[1..].join("/")}" if extension.nil?
    "/#{p.parts[1..].join("/").rchop(p.extension)}#{extension}"
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
