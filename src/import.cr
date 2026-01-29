require "xml"
require "http"
require "uri"
require "crinja"
require "log"
require "openssl"

# require "totem"

# Import module
#
# Fetches content from external RSS/Atom/JSON feeds and generates posts
# based on templates. Similar to Nikola's continuous import feature.
module Import
  # Configuration for a single feed
  class FeedConfig
    property urls : Array(String)
    property template : String
    property output_folder : String
    property format : String
    property source_extension : String?
    property lang : String
    property tags : String
    property skip_titles : Array(String)
    property start_at : String?

    # Field mappings: metadata_field -> source_field
    # Example: {"title" => "title", "date" => "published", "content" => "body"}
    property fields : Hash(String, String)

    # Static field values (applied to all items)
    # Example: {"tags" => "blog, imported"}
    property static : Hash(String, String)

    # Feed format: "json" for JSON APIs, nil for RSS/Atom
    property feed_format : String?

    # Authorization token for API requests
    property token : String?

    def initialize(@urls, @template, @output_folder, @format = "md",
                   @source_extension = nil, @lang = "en", @tags = "",
                   @skip_titles = [] of String, @start_at = nil,
                   @fields = {} of String => String,
                   @static = {} of String => String,
                   @feed_format = nil, @token = nil)
    end

    # Load from config (YAML::Any from config)
    def self.from_any(any, feed_name : String) : self
      urls = parse_urls(any["urls"])
      template = any["template"].as_s
      output_folder = any["output_folder"].as_s
      format = any["format"]? ? any["format"].as_s : "md"
      source_extension = any["source_extension"]?.try(&.as_s)
      lang = any["lang"]? ? any["lang"].as_s : "en"
      tags = any["tags"]? ? any["tags"].as_s : ""
      skip_titles = parse_skip_titles(any["skip_titles"]?)
      start_at = any["start_at"]?.try(&.as_s)
      fields = parse_field_mapping(any["fields"]?)
      static = parse_field_mapping(any["static"]?)
      feed_format = any["feed_format"]?.try(&.as_s)

      # Try token from config, then fallback to environment variable
      token = any["token"]?.try(&.as_s)
      if token.nil?
        env_var = "NICOLINO_IMPORT_#{feed_name.upcase}_TOKEN"
        token = ENV[env_var]?
      end

      new(urls, template, output_folder, format, source_extension,
        lang, tags, skip_titles, start_at, fields, static, feed_format, token)
    end

    # Parse urls from config (can be array or single string)
    private def self.parse_urls(any) : Array(String)
      if any.responds_to?(:as_a)
        any.as_a.map(&.as_s)
      else
        [any.as_s]
      end
    end

    # Parse skip_titles from config
    private def self.parse_skip_titles(any) : Array(String)
      return [] of String unless any
      return [] of String unless any.responds_to?(:as_a)
      any.as_a.map(&.as_s)
    end

    # Parse field mapping from config
    private def self.parse_field_mapping(any) : Hash(String, String)
      return {} of String => String unless any
      return {} of String => String unless any.responds_to?(:as_h)

      result = {} of String => String
      any.as_h.each do |k, v|
        result[k.to_s] = v.as_s
      end
      result
    end

    # Get the actual file extension to use
    def file_extension : String
      @source_extension || ".#{@format}"
    end

    # Check if this is a JSON/Pocketbase feed
    def json_feed?
      @feed_format == "json"
    end
  end

  # Feed item parsed from RSS/Atom
  struct FeedItem
    property title : String
    property link : String
    property pub_date : Time?
    property content : String
    property data : Hash(String, String | Array(String))

    def initialize(@title, @link, @pub_date, @content, @data = {} of String => String | Array(String))
    end
  end

  # Parse an RSS/Atom feed from URL
  def self.fetch_feed(url : String) : Array(FeedItem)
    Log.info { "Fetching feed: #{url}" }

    response = HTTP::Client.get(url)
    unless response.success?
      Log.error { "Failed to fetch #{url}: #{response.status_code}" }
      return [] of FeedItem
    end

    items = [] of FeedItem

    begin
      doc = XML.parse(response.body)

      # Detect feed type - try Atom first (with namespace)
      atom_entries = doc.xpath_nodes("//*[local-name()='feed']/*[local-name()='entry']")
      rss_items = doc.xpath_nodes("//rss/channel/item")

      if !atom_entries.empty?
        # Atom
        atom_entries.each do |entry_node|
          item = parse_atom_item(entry_node)
          items << item if item
        end
      elsif !rss_items.empty?
        # RSS 2.0
        rss_items.each do |item_node|
          item = parse_rss_item(item_node)
          items << item if item
        end
      elsif !doc.xpath_nodes("//item").empty?
        # RSS 1.0 / 0.9
        doc.xpath_nodes("//item").each do |item_node|
          item = parse_rss_item(item_node)
          items << item if item
        end
      else
        Log.warn { "Unknown feed format for #{url}" }
      end
    rescue ex : Exception
      Log.error(exception: ex) { "Failed to parse feed #{url}: #{ex.message}" }
      Log.debug { ex.backtrace.join("\n") }
    end

    Log.info { "Parsed #{items.size} items from #{url}" }
    items
  end

  # Fetch articles from JSON API (Pocketbase or generic)
  def self.fetch_json(url : String, token : String? = nil) : Array(FeedItem)
    Log.info { "Fetching JSON feed from: #{url}" }

    uri = URI.parse(url)
    client = HTTP::Client.new(uri)
    if token
      client.before_request do |request|
        request.headers["Authorization"] = "Bearer #{token}"
      end
    end

    response = client.get(uri.request_target)
    unless response.success?
      Log.error { "Failed to fetch JSON feed: #{response.status_code}" }
      return [] of FeedItem
    end

    parse_json_response(response.body, url)
  rescue ex : JSON::ParseException
    Log.error(exception: ex) { "Failed to parse JSON response: #{ex.message}" }
    Log.debug { ex.backtrace.join("\n") }
    [] of FeedItem
  rescue ex : Exception
    Log.error(exception: ex) { "Failed to fetch JSON feed: #{ex.message}" }
    Log.debug { ex.backtrace.join("\n") }
    [] of FeedItem
  end

  # Parse JSON response into FeedItems
  # Supports both Pocketbase format ({"items": [...]}) and generic arrays ([...])
  private def self.parse_json_response(body : String, url : String) : Array(FeedItem)
    json = JSON.parse(body)
    items = [] of FeedItem

    # Detect format: Pocketbase uses {"items": [...]} or direct array [...]
    records = if json.as_h? && json["items"]?
                json["items"].as_a
              elsif json.as_a?
                json.as_a
              else
                [] of JSON::Any
              end

    records.each do |record|
      item = parse_json_record(record)
      items << item if item
    end

    Log.info { "Parsed #{items.size} items from #{url}" }
    items
  end

  # Parse a single JSON record into a FeedItem
  private def self.parse_json_record(record : JSON::Any) : FeedItem?
    title = extract_json_title(record)
    content = extract_json_content(record)
    link = extract_json_link(record)
    pub_date = extract_json_date(record)
    data = extract_json_data(record)

    FeedItem.new(title, link, pub_date, content, data)
  end

  # Extract title from JSON record, trying common field names
  private def self.extract_json_title(record : JSON::Any) : String
    record["title"]?.try(&.as_s) ||
      record["name"]?.try(&.as_s) ||
      record["headline"]?.try(&.as_s) || "Untitled"
  end

  # Extract content from JSON record, trying common field names
  private def self.extract_json_content(record : JSON::Any) : String
    record["content"]?.try(&.as_s) ||
      record["body"]?.try(&.as_s) ||
      record["description"]?.try(&.as_s) ||
      record["text"]?.try(&.as_s) || ""
  end

  # Extract link from JSON record
  private def self.extract_json_link(record : JSON::Any) : String
    return record["url"]?.try(&.as_s) || "" if record["url"]?
    return record["link"]?.try(&.as_s) || "" if record["link"]?

    id = record["id"]?.try(&.as_s) || ""
    id.empty? ? "" : "json://#{id}"
  end

  # Extract date from JSON record (tries common field names)
  private def self.extract_json_date(record : JSON::Any) : Time?
    date_fields = ["published", "date", "created", "updated", "pubDate", "published_at"]
    date_fields.each do |date_field|
      if date_str = record[date_field]?.try(&.as_s)
        if parsed = parse_date(date_str)
          return parsed
        end
      end
    end
    nil
  end

  # Extract all fields from JSON record into data hash
  private def self.extract_json_data(record : JSON::Any) : Hash(String, String | Array(String))
    data = {} of String => String | Array(String)
    record.as_h.each do |key, val|
      case val.raw
      when String
        data[key] = val.as_s
      when Array
        data[key] = val.as_a.map(&.to_s).join(", ")
      when Bool, Int64, Float64, Nil
        data[key] = val.to_s
      end
    end
    data
  end

  # Parse an RSS item node
  private def self.parse_rss_item(item_node : XML::Node) : FeedItem?
    data = {} of String => String | Array(String)

    # Extract standard fields by iterating children
    title = "Untitled"
    link = ""
    description = ""
    pub_date_str = ""

    item_node.children.each do |child|
      next unless child.element?

      case child.name
      when "title"                          then title = child.content || "Untitled"
      when "link"                           then link = child.content || ""
      when "description", "content:encoded" then description = child.content || ""
      when "pubDate"                        then pub_date_str = child.content || ""
      end

      # Store all fields in data hash
      data[child.name] = child.content || ""
    end

    pub_date = parse_date(pub_date_str)

    FeedItem.new(title, link, pub_date, description, data)
  end

  # Parse an Atom entry node
  private def self.parse_atom_item(entry_node : XML::Node) : FeedItem?
    data = {} of String => String | Array(String)

    title = "Untitled"
    link = ""
    content = ""
    pub_date_str = ""

    entry_node.children.each do |child|
      next unless child.element?

      title, link, content, pub_date_str = process_atom_child(
        child, title, link, content, pub_date_str
      )
      data[child.name] = child.content || ""
    end

    pub_date = parse_date(pub_date_str)

    FeedItem.new(title, link, pub_date, content, data)
  end

  # Process a single child node in Atom entry
  private def self.process_atom_child(
    child : XML::Node,
    title : String,
    link : String,
    content : String,
    pub_date_str : String,
  ) : Tuple(String, String, String, String)
    title = extract_atom_title(child, title)
    link = extract_atom_link(child, link)
    content = extract_atom_content(child, content)
    pub_date_str = extract_atom_date(child, pub_date_str)

    {title, link, content, pub_date_str}
  end

  # Extract title from Atom child node
  private def self.extract_atom_title(child : XML::Node, current : String) : String
    return current unless child.name == "title"
    child.content || "Untitled"
  end

  # Extract link from Atom child node
  private def self.extract_atom_link(child : XML::Node, current : String) : String
    return current unless child.name == "link"
    child["href"]? || ""
  end

  # Extract content from Atom child node
  private def self.extract_atom_content(child : XML::Node, current : String) : String
    return current unless {"content", "summary"}.includes?(child.name)
    return current unless current.empty?
    child.content || ""
  end

  # Extract date from Atom child node
  private def self.extract_atom_date(child : XML::Node, current : String) : String
    return current unless {"published", "updated"}.includes?(child.name)
    return current unless current.empty?
    child.content || ""
  end

  # Parse date from various formats (delegated to DateUtils)
  private def self.parse_date(date_str : String?) : Time?
    DateUtils.parse(date_str)
  end

  # Get a mapped field value from a FeedItem
  private def self.get_mapped_field(item : FeedItem, config : FeedConfig, metadata_field : String) : String?
    # Look up which source field maps to this metadata field
    source_field = config.fields[metadata_field]?
    return nil unless source_field

    item.data[source_field]?.try(&.to_s)
  end

  # Generate post from feed item
  def self.generate_post(item : FeedItem, config : FeedConfig, template_content : String) : String
    # Build template context from field mappings
    context = {} of String => String

    # Apply field mappings (metadata_field -> source_field)
    config.fields.each do |target_name, source_field|
      if value = item.data[source_field]?
        context[target_name] = value.to_s
      end
    end

    # Format date properly if present (ISO 8601 for TinaCMS compatibility)
    if date_source = config.fields["date"]?
      if date_value = item.data[date_source]?
        if parsed_time = parse_date(date_value.to_s)
          context["date"] = parsed_time.to_s("%Y-%m-%dT%H:%M:%S%z")
        end
      end
    end

    # Handle tags: combine config.tags + field mapping + static tags
    tags = build_tags(item, config)
    context["tags"] = tags unless tags.empty?

    # Add static fields (can override mapped fields, except tags which we handle above)
    config.static.each do |name, value|
      context[name] = value unless name == "tags"
    end

    # Add special computed fields
    context["lang"] = config.lang
    context["link"] = item.link

    # Render template
    Crinja.render(template_content, context)
  end

  # Build combined tags from config, field mapping, and static
  private def self.build_tags(item : FeedItem, config : FeedConfig) : String
    tags_parts = [] of String

    # Add tags from config
    tags_parts << config.tags unless config.tags.empty?

    # Add tags from field mapping
    if tags_field = config.fields["tags"]?
      if tags_value = item.data[tags_field]?
        tags_parts << tags_value.to_s unless tags_value.to_s.empty?
      end
    end

    # Add static tags
    if static_tags = config.static["tags"]?
      tags_parts << static_tags unless static_tags.empty?
    end

    tags_parts.join(", ").strip
  end

  # Generate filename for post
  def self.generate_filename(item : FeedItem, config : FeedConfig) : String
    # Try to use stable ID first: {hash}-{title}.{ext}
    # Otherwise fall back to date+slug
    item_hash = get_stable_hash(item)

    # Slugify title
    slug = item.title.downcase.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-").gsub(/-+/, "-")

    if item_hash
      "#{item_hash}-#{slug}#{config.file_extension}"
    else
      # Fall back to date+slug format
      date_str = if pub_date = item.pub_date
                   pub_date.to_s("%Y-%m-%d")
                 else
                   Time.utc.to_s("%Y-%m-%d")
                 end
      "#{date_str}-#{slug}#{config.file_extension}"
    end
  end

  # Get stable hash for item (8 chars)
  # Returns nil if no stable ID is found
  private def self.get_stable_hash(item : FeedItem) : String?
    # Try common ID field names
    ["id", "guid", "entry_id", "post_id"].each do |id_field|
      if id_value = item.data[id_field]?
        id_str = id_value.to_s.strip
        return short_hash(id_str) unless id_str.empty?
      end
    end
    nil
  end

  # Generate git-style short hash (8 chars) from stable ID
  private def self.short_hash(id : String) : String
    digest = OpenSSL::Digest.new("sha256")
    digest.update(id)
    digest.final[0...16].hexstring[0...8]
  end

  # Find existing file with same hash (for title change detection)
  private def self.find_existing_by_hash(output_dir : String, hash : String, ext : String) : String?
    Dir.glob(File.join(output_dir, "#{hash}-*#{ext}")).first?
  end

  # Get date for post metadata from field mappings
  private def self.get_post_date(item : FeedItem, config : FeedConfig) : Time
    # Try the "date" field mapping first
    if date_field = config.fields["date"]?
      if date_str = item.data[date_field]?
        if parsed = parse_date(date_str.to_s)
          return parsed
        end
      end
    end

    # Fall back to pubDate from feed parsing
    item.pub_date || Time.utc
  end

  # Default template (baked-in) for simple use cases
  DEFAULT_TEMPLATE = <<-TEMPLATE
  {{ content }}
  TEMPLATE

  # Import items from a feed configuration
  def self.import_feed(name : String, config : FeedConfig, templates_dir : String)
    Log.info { "Importing feed: #{name}" }

    template_content = load_feed_template(config, templates_dir)
    output_dir = setup_feed_output_dir(config)
    existing_posts = get_existing_posts(output_dir, config)
    start_date = parse_date(config.start_at)

    # Fetch and process all URLs
    all_items = fetch_all_feed_items(config)

    # Sort by date (newest first)
    all_items.sort_by! { |item| item.pub_date || Time.utc }
    all_items.reverse!

    imported_count = 0
    skipped_count = 0

    all_items.each do |item|
      if should_skip_item(item, config, start_date, existing_posts)
        skipped_count += 1
        next
      end

      filename = generate_filename(item, config)
      write_feed_post(item, config, template_content, output_dir, filename)
      imported_count += 1
    end

    Log.info { "Imported #{imported_count} posts, skipped #{skipped_count}" }
  end

  # Load template for feed, falling back to default
  private def self.load_feed_template(config : FeedConfig, templates_dir : String) : String
    template_path = File.join(templates_dir, config.template)
    if File.exists?(template_path)
      template_content = File.read(template_path)
      Log.debug { "Using template: #{template_path}" }
      template_content
    else
      Log.info { "Template not found: #{template_path}, using default template" }
      DEFAULT_TEMPLATE
    end
  end

  # Setup output directory for feed
  private def self.setup_feed_output_dir(config : FeedConfig) : String
    output_dir = File.join("content", config.output_folder)
    Dir.mkdir_p(output_dir)
    output_dir
  end

  # Get set of existing post filenames
  private def self.get_existing_posts(output_dir : String, config : FeedConfig) : Set(String)
    Dir.glob(File.join(output_dir, "*#{config.file_extension}"))
      .map { |filepath| File.basename(filepath) }
      .to_set
  end

  # Fetch all items from all configured URLs
  private def self.fetch_all_feed_items(config : FeedConfig) : Array(FeedItem)
    all_items = [] of FeedItem

    if config.json_feed?
      # Fetch from JSON APIs (Pocketbase or others)
      config.urls.each do |url|
        Log.debug { "Fetching JSON feed from #{url}" }
        items = fetch_json(url, config.token)
        Log.debug { "Got #{items.size} items" }
        all_items.concat(items)
      end
    else
      # Fetch from RSS/Atom feeds
      config.urls.each do |url|
        items = fetch_feed(url)
        all_items.concat(items)
      end
    end

    all_items
  end

  # Check if an item should be skipped
  private def self.should_skip_item(
    item : FeedItem,
    config : FeedConfig,
    start_date : Time?,
    existing_posts : Set(String),
  ) : Bool
    # Check if should be skipped
    if config.skip_titles.includes?(item.title)
      Log.debug { "Skipping skipped title: #{item.title}" }
      return true
    end

    # Check date filter
    if start_date && (pub = item.pub_date)
      if pub < start_date
        Log.debug { "Skipping old item: #{item.title} (#{item.pub_date})" }
        return true
      end
    end

    # Note: We no longer skip existing files - we update them instead
    # This ensures CMS changes are always propagated to Nicolino

    false
  end

  # Write a feed post to file
  private def self.write_feed_post(
    item : FeedItem,
    config : FeedConfig,
    template_content : String,
    output_dir : String,
    filename : String,
  )
    content = generate_post(item, config, template_content)
    output_path = File.join(output_dir, filename)

    # Check if file already exists (before writing)
    is_update = File.exists?(output_path)

    # Check if title changed (same hash, different filename)
    item_hash = get_stable_hash(item)
    if item_hash
      if existing = find_existing_by_hash(output_dir, item_hash, config.file_extension)
        if existing != filename
          Log.info { "Title changed, deleting old: #{existing}" }
          File.delete(existing)
          is_update = true # This is an update (from old file)
        end
      end
    end

    # Write (or overwrite) the file
    File.write(output_path, content)
    action = is_update ? "Updated" : "Created"
    Log.info { "#{action}: #{output_path}" }
  end

  # Import all configured feeds
  def self.import_all
    ci_value = Config.options.import
    return if ci_value.nil? || ci_value.empty?

    feeds = ci_value
    templates_dir = Config.options.import_templates

    feeds.each do |name, cfg|
      begin
        feed_cfg = FeedConfig.from_any(cfg, name)
        Log.debug { "Feed #{name}: feed_format=#{feed_cfg.feed_format.inspect}, json_feed?=#{feed_cfg.json_feed?}" }
        import_feed(name, feed_cfg, templates_dir)
      rescue ex : Exception
        Log.error(exception: ex) { "Failed to import feed '#{name}': #{ex.message}" }
      end
    end
  end
end
