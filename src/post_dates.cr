# PostDates module for caching post dates
#
# Parsing post dates from frontmatter is expensive (Cronic + fallback formats).
# This module caches parsed dates in the kv store so we only parse once.
#
# Dates are stored as ISO8601 strings and can be loaded quickly on subsequent builds.

module PostDates
  # Cache for loaded dates
  @@dates_cache : Hash(String, Time?) | Nil = nil

  # Get the date cache, initializing if needed
  private def self.cache : Hash(String, Time?)
    @@dates_cache ||= Hash(String, Time?).new
  end

  # Load a post's date from cache, or nil if not cached
  #
  # The key is based on the post's source file path (language-specific)
  def self.get_date(source_path : String) : Time?
    dates = cache
    return dates[source_path] if dates.has_key?(source_path)

    # Try loading from kv store
    key = cache_key(source_path)
    data = Croupier::TaskManager.get(key)
    return nil if data.nil?

    # Parse ISO8601 string back to Time
    begin
      date = Time::Format::ISO_8601.parse(data)
      dates[source_path] = date
      date
    rescue ex
      Log.error { "Failed to parse cached date for #{source_path}: #{ex.message}" }
      nil
    end
  end

  # Store a post's date in the cache and kv store
  def self.set_date(source_path : String, date : Time) : Nil
    dates = cache
    dates[source_path] = date

    key = cache_key(source_path)
    Croupier::TaskManager.set(key, date.to_s)
  end

  # Clear the dates cache
  def self.clear_cache : Nil
    @@dates_cache = nil
  end

  # Generate kv store key for a post's date
  private def self.cache_key(source_path : String) : String
    # Use source path as key, replacing slashes with underscores
    # e.g., "content/posts/foo.md" -> "post_dates/content_posts_foo.md"
    "post_dates/#{source_path.gsub("/", "_")}"
  end

  # Ensure all posts have their dates cached
  #
  # This parses dates for any posts not already in the cache
  # and stores them in the kv store for future use.
  def self.cache_posts(posts : Array(Markdown::File)) : Nil
    Config.languages.keys.each do |lang|
      posts.each do |post|
        source = post.source(lang)

        # Skip if already cached
        next if cache.has_key?(source)

        # Parse and store the date
        begin
          date = post.date
          set_date(source, date) unless date.nil?
        rescue ex
          Log.warn { "Failed to parse date for #{source}: #{ex.message}" }
        end
      end
    end
  end

  # Load all cached dates in bulk
  #
  # Returns a hash mapping source paths to Time objects
  def self.load_all(posts : Array(Markdown::File)) : Hash(String, Time?)
    result = Hash(String, Time?).new

    Config.languages.keys.each do |lang|
      posts.each do |post|
        source = post.source(lang)
        date = get_date(source)
        result[source] = date unless date.nil?
      end
    end

    result
  end

  # Check if a post's date is already cached
  def self.cached?(source_path : String) : Bool
    cache.has_key?(source_path)
  end
end
