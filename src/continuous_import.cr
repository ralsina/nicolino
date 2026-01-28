require "xml"
require "http"
require "uri"
require "crinja"
require "log"

# require "totem"

# Continuous Import module
#
# Fetches content from external RSS/Atom feeds and generates posts
# based on templates. Similar to Nikola's continuous import feature.
module ContinuousImport
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
    property metadata : Hash(String, YAML::Any)
    property feed_format : String?
    property pocketbase_collection : String?
    property pocketbase_filter : String?

    def initialize(@urls, @template, @output_folder, @format = "md",
                   @source_extension = nil, @lang = "en", @tags = "",
                   @skip_titles = [] of String, @start_at = nil,
                   @metadata = {} of String => YAML::Any,
                   @feed_format = nil, @pocketbase_collection = nil,
                   @pocketbase_filter = nil)
    end

    # Load from config (YAML::Any from config)
    def self.from_any(any) : self
      # Handle urls - can be array or single string
      urls_val = any["urls"]
      urls = if urls_val.responds_to?(:as_a)
               urls_val.as_a.map(&.as_s)
             else
               [urls_val.as_s]
             end

      template = any["template"].as_s
      output_folder = any["output_folder"].as_s
      format = any["format"]? ? any["format"].as_s : "md"
      source_extension = any["source_extension"]?.try(&.as_s)
      lang = any["lang"]? ? any["lang"].as_s : "en"
      tags = any["tags"]? ? any["tags"].as_s : ""

      skip_titles_val = any["skip_titles"]?
      skip_titles = if skip_titles_val && skip_titles_val.responds_to?(:as_a)
                      skip_titles_val.as_a.map(&.as_s)
                    else
                      [] of String
                    end

      start_at = any["start_at"]?.try(&.as_s)

      feed_format = any["feed_format"]?.try(&.as_s)

      pocketbase_collection = any["pocketbase_collection"]?.try(&.as_s)
      pocketbase_filter = any["pocketbase_filter"]?.try(&.as_s)

      metadata = {} of String => YAML::Any
      if meta_val = any["metadata"]?
        if meta_val.responds_to?(:as_h)
          meta_val.as_h.each do |k, v|
            metadata[k.to_s] = v
          end
        end
      end

      new(urls, template, output_folder, format, source_extension,
        lang, tags, skip_titles, start_at, metadata,
        feed_format, pocketbase_collection, pocketbase_filter)
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

  # Fetch articles from Pocketbase CMS
  def self.fetch_pocketbase(url : String, collection : String, filter : String? = nil) : Array(FeedItem)
    api_url = build_pocketbase_url(url, collection, filter)
    Log.info { "Fetching Pocketbase collection: #{collection} from #{url}" }

    response = HTTP::Client.get(api_url)
    unless response.success?
      Log.error { "Failed to fetch Pocketbase collection: #{response.status_code}" }
      return [] of FeedItem
    end

    parse_pocketbase_response(response.body, collection)
  rescue ex : JSON::ParseException
    Log.error(exception: ex) { "Failed to parse Pocketbase JSON response: #{ex.message}" }
    Log.debug { ex.backtrace.join("\n") }
    [] of FeedItem
  rescue ex : Exception
    Log.error(exception: ex) { "Failed to fetch Pocketbase collection: #{ex.message}" }
    Log.debug { ex.backtrace.join("\n") }
    [] of FeedItem
  end

  # Build Pocketbase API URL
  private def self.build_pocketbase_url(url : String, collection : String, filter : String?) : String
    # If URL already contains the API path, use it as-is
    # Otherwise build the full API URL
    if url.includes?("/api/collections/")
      api_url = url.rstrip('/')
    else
      api_url = "#{url.rstrip('/')}/api/collections/#{collection}/records"
    end

    if filter
      separator = api_url.includes?('?') ? '&' : '?'
      api_url += "#{separator}filter=#{URI.encode_path_segment(filter)}"
    end
    api_url
  end

  # Parse Pocketbase JSON response into FeedItems
  private def self.parse_pocketbase_response(body : String, collection : String) : Array(FeedItem)
    json = JSON.parse(body)
    items = [] of FeedItem
    records = json["items"]?.try(&.as_a) || [] of JSON::Any

    records.each do |record|
      item = parse_pocketbase_record(record)
      items << item if item
    end

    Log.info { "Parsed #{items.size} articles from Pocketbase collection #{collection}" }
    items
  end

  # Parse a single Pocketbase record into a FeedItem
  private def self.parse_pocketbase_record(record : JSON::Any) : FeedItem?
    title = record["title"]?.try(&.as_s) || "Untitled"
    content = record["content"]?.try(&.as_s) || ""
    id = record["id"]?.try(&.as_s) || ""
    link = "pocketbase://#{id}"

    pub_date = extract_pocketbase_date(record)
    data = extract_pocketbase_data(record)

    FeedItem.new(title, link, pub_date, content, data)
  end

  # Extract date from Pocketbase record (tries published, created, updated)
  private def self.extract_pocketbase_date(record : JSON::Any) : Time?
    pub_date = nil
    ["published", "created", "updated"].each do |date_field|
      if date_str = record[date_field]?.try(&.as_s)
        pub_date = parse_date(date_str)
        break if pub_date
      end
    end
    pub_date
  end

  # Extract all fields from Pocketbase record into data hash
  private def self.extract_pocketbase_data(record : JSON::Any) : Hash(String, String | Array(String))
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

  # Parse date from various formats
  private def self.parse_date(date_str : String?) : Time?
    return nil if date_str.nil? || date_str.empty?

    # Try common date formats
    formats = [
      Time::Format::RFC_2822,
      Time::Format::ISO_8601_DATE_TIME,
    ]

    formats.each do |format|
      begin
        return format.parse(date_str)
      rescue
        # Try next format
      end
    end

    # Try parsing as HTTP date
    begin
      return HTTP.parse_time(date_str)
    rescue
      # Fall through
    end

    Log.warn { "Could not parse date: #{date_str}" }
    nil
  end

  # Get metadata value from item, trying multiple keys
  private def self.get_metadata(item : FeedItem, keys : Array(String)) : String?
    keys.each do |key|
      if value = item.data[key]?
        return value.to_s
      end
    end
    nil
  end

  # Generate post from feed item
  def self.generate_post(item : FeedItem, config : FeedConfig, template_content : String) : String
    # Prepare template context
    context = {
      "item"    => item.data,
      "title"   => item.title,
      "link"    => item.link,
      "content" => item.content,
    }

    # Render template
    output = Crinja.render(template_content, context)

    output
  end

  # Generate filename for post
  def self.generate_filename(item : FeedItem, config : FeedConfig) : String
    # Use date from metadata if specified
    date_str = if pub_date = item.pub_date
                 pub_date.to_s("%Y-%m-%d")
               else
                 Time.utc.to_s("%Y-%m-%d")
               end

    # Slugify title
    slug = item.title.downcase.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-").gsub(/-+/, "-")

    "#{date_str}-#{slug}#{config.file_extension}"
  end

  # Get date for post metadata
  private def self.get_post_date(item : FeedItem, config : FeedConfig) : Time
    # Try metadata fields in order
    if date_val = config.metadata["date"]?
      keys = if date_val.as_a?
               date_val.as_a.map(&.as_s)
             else
               [date_val.as_s]
             end

      keys.each do |key|
        if value = item.data[key]?
          if parsed = parse_date(value.to_s)
            return parsed
          end
        end
      end
    end

    # Fall back to pubDate
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
      # Fetch from JSON/Pocketbase
      collection = config.pocketbase_collection
      filter = config.pocketbase_filter
      if collection
        config.urls.each do |url|
          items = fetch_pocketbase(url, collection, filter)
          all_items.concat(items)
        end
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

    # Check if already exists
    filename = generate_filename(item, config)
    if existing_posts.includes?(filename)
      Log.debug { "Skipping existing: #{filename}" }
      return true
    end

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

    # Generate frontmatter
    date = get_post_date(item, config)
    title = if title_val = config.metadata["title"]?
              get_metadata(item, [title_val.as_s]) || item.title
            else
              item.title
            end

    frontmatter = <<-FRONT
      ---
      title: "#{title.gsub(/"/, "\\\"")}"
      date: #{date.to_s("%Y-%m-%d %H:%M:%S %z")}
      tags: #{config.tags}
      lang: #{config.lang}
      ---

      FRONT

    File.write(output_path, frontmatter + content)
    Log.info { "Created: #{output_path}" }
  end

  # Import all configured feeds
  def self.import_all
    ci_value = Config.options.continuous_import
    return if ci_value.nil? || ci_value.empty?

    feeds = ci_value
    templates_dir = Config.options.continuous_import_templates

    feeds.each do |name, cfg|
      begin
        feed_cfg = FeedConfig.from_any(cfg)
        import_feed(name, feed_cfg, templates_dir)
      rescue ex : Exception
        Log.error(exception: ex) { "Failed to import feed '#{name}': #{ex.message}" }
      end
    end
  end
end
