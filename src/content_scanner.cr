require "./markdown"
require "./utils"

module ContentScanner
  # Single scan phase: assign content to features in priority order
  # First feature to match a file claims it
  #
  # Features is an array of tuples:
  # - name: Feature name for results hash
  # - globs: Array of glob patterns to scan
  # - create_file: Block that creates a Markdown::File from sources and base path
  def self.scan_all(
    features : Array(NamedTuple(name: String, globs: Array(String), create_file: Hash(String, String), Path -> Markdown::File?))
  ) : Hash(String, Array(Markdown::File))
    result = Hash(String, Array(Markdown::File)).new

    # Track claimed bases across all features
    claimed_bases = Set(Path).new

    features.each do |feature|
      feature_name = feature[:name]
      all_sources = Hash(Path, Hash(String, String)).new

      feature[:globs].each do |glob|
        # Extract path and extension from glob pattern
        # e.g., "content/posts/**/*.md" => path="content/posts", ext="md"
        path, ext = parse_glob(glob)
        next unless path && ext

        # Use Utils.find_all to get language-grouped sources
        sources = Utils.find_all(path, ext)

        sources.each do |base, lang_sources|
          # Skip if already claimed by higher priority feature
          next if claimed_bases.includes?(base)

          # Skip if already registered
          next if Markdown.posts.has_key?(base.to_s)

          # Skip if should be skipped
          next if Utils.should_skip_file?(base)

          # Claim this base
          claimed_bases.add(base)
          all_sources[base] = lang_sources
        end
      end

      # Create files in parallel using the existing files_from pattern
      unless all_sources.empty?
        create_file = feature[:create_file]
        files = Markdown.files_from(all_sources) do |lang_sources, base|
          create_file.call(lang_sources, base)
        end
        result[feature_name] = files
      end
    end

    result
  end

  # Parse a glob pattern to extract path and extension
  # e.g., "content/posts/**/*.md" => {"content/posts", "md"}
  private def self.parse_glob(glob : String) : {String?, String?}
    # Match patterns like "path/**/*.ext" or "path/*.ext"
    if glob =~ /\A(.+?)\/\*\*\/\*\.(.+)\z/
      {Path[$1].to_s, $2}
    elsif glob =~ /\A(.+?)\/\*\.(.+)\z/
      {Path[$1].to_s, $2}
    else
      {nil, nil}
    end
  end
end
