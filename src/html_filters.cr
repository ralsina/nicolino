# Functions that take a Lexbor document and return a modified version
# To create a Lexbor document, use `Lexbor::Parser.new(html)`
module HtmlFilters
  # Shift headers so the highest level is n (n=2 means h1->h3, h2->h4, etc.)
  # If n=2 and doc has h3 as the highest, then h3->h2, h4->h3, etc.
  def self.downgrade_headers(doc, n = 2)
    # Find the minimum heading level in the document
    min_level = 6
    (1..6).each do |i|
      headers = doc.nodes("h#{i}").to_a
      unless headers.empty?
        min_level = i
        break
      end
    end

    # Calculate shift amount
    # We want: min_level + shift = n, so shift = n - min_level
    # shift can be positive (downgrade: h1->h2, h2->h3) or negative (upgrade: h3->h2, h4->h3)
    shift = n - min_level

    # If shift is 0, no change needed
    return doc if shift == 0

    # Collect all headers first, before any modifications
    # Store as array of {level, node} tuples
    headers_to_shift = [] of Tuple(Int32, Lexbor::Node)
    (1..6).each do |level|
      doc.nodes("h#{level}").each do |node|
        headers_to_shift << {level, node}
      end
    end

    # Process each header
    headers_to_shift.each do |original_level, node|
      new_level = original_level + shift
      next if new_level > 6 # Don't create h7+
      next if new_level < 1 # Don't create h0 or negative levels

      # Create new heading element
      new_heading = doc.create_node("h#{new_level}")

      # Copy attributes
      if node.attributes.has_key? "class"
        new_heading["class"] = node.attributes["class"]
      end
      node.each_attribute do |key_slice, value_slice|
        key = String.new(key_slice)
        next if key == "class"
        value = value_slice ? String.new(value_slice) : nil
        new_heading[key] = value
      end

      # Move children
      node.children.each do |child|
        new_heading.append_child(child)
      end

      # Replace old heading with new one
      node.insert_before(new_heading)
      node.remove!
    end

    doc
  end

  # A href/src attribute value that make_links_relative would rewrite:
  # anything not starting with "/", "#", a URL scheme (scheme'd values
  # are absolute URLs; resolve+relativize round-trips a different-host
  # absolute URL unchanged), and not empty (an empty value round-trips
  # to empty, and the canonical link that carries it is skipped by the
  # filter anyway).
  NEEDS_LINK_FIX = /(?:href|src)\s*=\s*(?:"(?!["\/#]|[a-zA-Z][a-zA-Z0-9+.\-]*:)[^"]*"|'(?!['\/#]|[a-zA-Z][a-zA-Z0-9+.\-]*:)[^']*')/

  # A code tag whose class doesn't already start with language-,
  # which fix_code_classes would rewrite.
  NEEDS_CODE_FIX = /<code[^>]*\sclass\s*=\s*["'](?!language-|tz-)/

  # Capture form of NEEDS_LINK_FIX: matches a href/src value that
  # make_links_relative would rewrite, capturing the value and the
  # quote character around it.
  NEEDS_LINK_FIX_CAPTURE = /(?:href|src)\s*=\s*(["'])(?!\/|#|[a-zA-Z][a-zA-Z0-9+.\-]*:)(.*?)\1/

  # A href/src lookalike inside a script body or an HTML comment:
  # the parser-based pass ignores those (they are not element
  # attributes), so when they are present the string rewrite is not
  # equivalent and callers must use the parser path instead.
  LINK_FIX_UNSAFE_CONTEXT = /(?:<script[^>]*>[^<]*|\<!--[^>]*)href\s*=\s*["']/

  # A root-relative href/src value that make_links_relative would
  # rewrite (starts with "/" but not a protocol like "//").
  ROOT_RELATIVE_FIX = /(?:href|src)\s*=\s*(["'])\/(?!\/)(.*?)\1/

  # Whether the string-based link rewrite is safe for this html: no
  # href/src lookalikes hiding in script bodies or comments, and no
  # uppercase attribute spellings the capture regex would miss.
  def self.string_rewrite_safe?(html : String) : Bool
    !html.matches?(LINK_FIX_UNSAFE_CONTEXT) && !html.matches?(/HREF\s*=\s*["']|SRC\s*=\s*["']/)
  end

  # Compute a relative path from `base` (a page URL like
  # "/posts/foo/index.html") to the site root.  Used to turn
  # root-relative links (/css/style.css) into page-relative ones
  # (../../css/style.css).
  private def self.relative_prefix(base : String) : String
    # Strip url_prefix if present — it's a virtual mount point,
    # not a real directory in the output tree
    site_prefix = Config.options.url_prefix.chomp("/")
    path = base
    if !site_prefix.empty? && path.starts_with?("/#{site_prefix}")
      path = path.lchop("/#{site_prefix}")
    end
    # Strip leading "/" and split into parts; the last part is a
    # filename so we only count the directory components.
    parts = path.lchop('/').split('/')
    depth = parts.size > 1 ? parts.size - 1 : 0
    return "" if depth == 0
    ("../" * depth)
  end

  # Rewrite relative href/src values directly on the html STRING,
  # without parsing the document. Used when pretty_html is off and
  # only links need fixing: no lexbor parse, no re-serialization
  # (which historically mangled code blocks), same relativize
  # computation as make_links_relative applied to each value.
  # Only call when string_rewrite_safe? says the html has no
  # href/src lookalikes outside real attributes.
  def self.relativize_links_in_string(html : String, base : String) : String
    # Nothing to rewrite: skip the gsub scan entirely
    return html unless html.matches?(NEEDS_LINK_FIX) || html.matches?(ROOT_RELATIVE_FIX)
    prefix = relative_prefix(base)
    base_uri = URI.parse(base)
    # Relative links (not starting with /)
    html = html.gsub(NEEDS_LINK_FIX_CAPTURE) do |match|
      value = $2
      rewritten = md_link_to_html(base_uri.relativize(base_uri.resolve(value)).to_s)
      if rewritten == value
        match
      else
        "#{match[0, match.size - value.size - 1]}#{rewritten}#{$1}"
      end
    end
    # Root-relative links (/css/style.css → ../../css/style.css)
    # relative_prefix already strips url_prefix to compute the real
    # output-tree depth, so just use the bare path after the "/".
    # For root-level pages (prefix empty), still prepend url_prefix.
    # Links generated by Utils.path_to_link already carry the
    # url_prefix: strip it first (strip_url_prefix) so it is not
    # counted twice.
    html = html.gsub(ROOT_RELATIVE_FIX) do |match|
      quote = $1
      path = $2
      value = strip_url_prefix("/#{path}")
      value = value[1..]? || ""
      if prefix.empty? && !Config.options.url_prefix.empty?
        resolved = "/#{Config.options.url_prefix.chomp("/")}/#{value}"
        "#{match[0..-(path.size + quote.size + 2)]}#{resolved}#{quote}"
      elsif !prefix.empty?
        "#{match[0..-(path.size + quote.size + 2)]}#{prefix}#{value}#{quote}"
      else
        match
      end
    end
    html
  end

  # Relativize every href/src value of a finished page in ONE pass over
  # its bytes, with the exact rules of string_rewrite_safe? followed by
  # relativize_links_in_string, which together needed up to six regex
  # passes (each re-validating the page's UTF-8) and two full copies of
  # the page. Returns nil when the page needs the parser path instead
  # (an uppercase HREF/SRC spelling, or an href inside script text or a
  # comment), and the page itself when nothing had to change.
  EQUALS       = '='.ord.to_u8
  LESS_THAN    = '<'.ord.to_u8
  GREATER_THAN = '>'.ord.to_u8
  NEWLINE      = '\n'.ord.to_u8

  def self.relativize_page_links(html : String, base : String) : String?
    # Decided for the whole page before any rewriting, independently of
    # which values the traversal below visits or skips
    return nil unless page_rewrite_safe?(html)
    bytes = html.to_slice
    out = nil.as(String::Builder?)
    copied = 0
    # Per-page constants, built on the first rewrite candidate
    page = nil.as(LinkPage?)
    position = 0
    # Candidates are anchored on "=": Slice#index is memchr, so the
    # scan runs at C speed in dev builds too, and "=" is rare enough in
    # a page that the per-hit checks stay cheap
    while equals = bytes.index(EQUALS, position)
      span = link_attribute_span(bytes, equals)
      if span.nil?
        position = equals + 1
        next
      end
      value_start, value_end = span
      if value_end.nil?
        position = equals + 1
        next
      end
      value = String.new(bytes[value_start, value_end - value_start])
      page ||= LinkPage.new(URI.parse(base), relative_prefix(base), Config.options.url_prefix)
      if rewritten = rewrite_link_value(value, page)
        builder = (out ||= String::Builder.new(bytes.size + 64))
        builder.write(bytes[copied, value_start - copied])
        builder << rewritten
        copied = value_end
      end
      position = value_end + 1
    end
    return html unless out
    out.write(bytes[copied, bytes.size - copied])
    out.to_s
  end

  # Byte-level equivalent of string_rewrite_safe?: false when the page
  # has an uppercase HREF/SRC assignment anywhere, or an href
  # assignment in the text right after a `<script ...>` tag (up to the
  # next "<") or inside a comment (up to the next ">"). Those are the
  # exact shapes of its two regexes, found without running them.
  private def self.page_rewrite_safe?(html : String) : Bool
    bytes = html.to_slice
    return false if assignment_in?(html, "HREF", 0, bytes.size) || assignment_in?(html, "SRC", 0, bytes.size)
    start = 0
    while start = html.byte_index("<script", start)
      # `<script[^>]*>` needs a ">"; without one no later tag has it either
      break unless tag_end = bytes.index(GREATER_THAN, start)
      text_end = bytes.index(LESS_THAN, tag_end + 1) || bytes.size
      return false if assignment_in?(html, "href", tag_end + 1, text_end)
      start += 1
    end
    start = 0
    while start = html.byte_index("<!--", start)
      span_end = bytes.index(GREATER_THAN, start + 4) || bytes.size
      return false if assignment_in?(html, "href", start + 4, span_end)
      start += 1
    end
    true
  end

  # Whether `name\s*=\s*["']` starts anywhere in html[from, to). None
  # of those characters is "<" or ">", so a match that starts inside a
  # span bounded by one of them also ends inside it.
  private def self.assignment_in?(html : String, name : String, from : Int32, to : Int32) : Bool
    bytes = html.to_slice
    index = from
    while (index = html.byte_index(name, index)) && index < to
      j = skip_whitespace(bytes, index + name.bytesize)
      if j < bytes.size && bytes[j] === '='
        j = skip_whitespace(bytes, j + 1)
        return true if j < bytes.size && (bytes[j] === '"' || bytes[j] === '\'')
      end
      index += 1
    end
    false
  end

  # The href/src attribute around the "=" at *equals*, if any:
  # {value start, value end}, where value end is the closing quote's
  # index or nil when the value is unusable (no closing quote, or a
  # newline inside: the regexes' `(.*?)` never matched those). The
  # regex form was `(?:href|src)\s*=\s*["']`.
  private def self.link_attribute_span(bytes : Bytes, equals : Int32) : {Int32, Int32?}?
    return nil unless link_attribute?(bytes, skip_whitespace_back(bytes, equals))
    quote_index = skip_whitespace(bytes, equals + 1)
    return nil unless quote_index < bytes.size && (bytes[quote_index] === '"' || bytes[quote_index] === '\'')
    {quote_index + 1, quoted_value_end(bytes, quote_index)}
  end

  # Index of the quote closing the value that opens at *quote_index*,
  # or nil when there is none or the value holds a newline. Only the
  # value itself is searched, so a page full of links stays linear.
  private def self.quoted_value_end(bytes : Bytes, quote_index : Int32) : Int32?
    value_start = quote_index + 1
    value_end = bytes.index(bytes[quote_index], value_start)
    return nil unless value_end
    bytes[value_start, value_end - value_start].index(NEWLINE) ? nil : value_end
  end

  # First index at or after *index* that is not ASCII whitespace
  private def self.skip_whitespace(bytes : Bytes, index : Int32) : Int32
    while index < bytes.size && bytes[index].unsafe_chr.ascii_whitespace?
      index += 1
    end
    index
  end

  # Index just past the last non-whitespace byte before *index*
  private def self.skip_whitespace_back(bytes : Bytes, index : Int32) : Int32
    while index > 0 && bytes[index - 1].unsafe_chr.ascii_whitespace?
      index -= 1
    end
    index
  end

  # Whether "href" or "src" ends at *name_end*. The regexes matched
  # these spellings anywhere (data-src included), with no word
  # boundary, so neither does this.
  private def self.link_attribute?(bytes : Bytes, name_end : Int32) : Bool
    (name_end >= 4 && starts_with?(bytes, name_end - 4, "href")) ||
      (name_end >= 3 && starts_with?(bytes, name_end - 3, "src"))
  end

  private def self.starts_with?(bytes : Bytes, index : Int32, literal : String) : Bool
    expected = literal.to_slice
    return false if index + expected.size > bytes.size
    offset = 0
    while offset < expected.size
      return false unless bytes[index + offset] == expected[offset]
      offset += 1
    end
    true
  end

  # What every link of one page is rewritten against
  private record LinkPage, base_uri : URI, prefix : String, url_prefix : String

  # Same decision as NEEDS_LINK_FIX_CAPTURE + ROOT_RELATIVE_FIX for one
  # attribute value; nil when the value stays as it is
  private def self.rewrite_link_value(value : String, page : LinkPage) : String?
    return nil if value.empty?
    if value.starts_with?('/')
      # Protocol-relative URLs are left alone
      value.starts_with?("//") ? nil : rewrite_root_relative(value, page)
    else
      return nil if value.starts_with?('#') || scheme?(value)
      base_uri = page.base_uri
      rewritten = md_link_to_html(base_uri.relativize(base_uri.resolve(value)).to_s)
      rewritten == value ? nil : rewritten
    end
  end

  # "/css/x.css" -> "../../css/x.css" (or "/prefix/css/x.css" for a
  # root page of a site served under url_prefix)
  private def self.rewrite_root_relative(value : String, page : LinkPage) : String?
    stripped = strip_url_prefix(value)[1..]? || ""
    if page.prefix.empty? && !page.url_prefix.empty?
      "/#{page.url_prefix.chomp("/")}/#{stripped}"
    elsif !page.prefix.empty?
      "#{page.prefix}#{stripped}"
    end
  end

  # `^[a-zA-Z][a-zA-Z0-9+.\-]*:` without a regex
  private def self.scheme?(value : String) : Bool
    bytes = value.to_slice
    return false if bytes.empty? || !bytes[0].unsafe_chr.ascii_letter?
    index = 1
    while index < bytes.size
      char = bytes[index].unsafe_chr
      return true if char == ':'
      return false unless char.ascii_alphanumeric? || char == '+' || char == '.' || char == '-'
      index += 1
    end
    false
  end

  # Map a relative link to a markdown source file onto its rendered
  # page: content links are written with .md paths so they also work
  # when the source is browsed as markdown (e.g. on GitHub); once
  # rendered, they must target the generated HTML. Anchors survive:
  # foo.md#section becomes foo.html#section. Absolute URLs, root
  # -relative paths, fragment-only links, and non-.md targets pass
  # through untouched, so this is always safe to call on any href/src
  # value regardless of the caller's own filtering.
  def self.md_link_to_html(link : String) : String
    return link if link.starts_with?("/") || link.starts_with?("#")
    return link if link.matches?(/^[a-zA-Z][a-zA-Z0-9+.\-]*:/)
    hash = link.index("#")
    target = hash ? link[0...hash] : link
    anchor = hash ? link[hash..] : ""
    return link unless target.ends_with?(".md")
    "#{target[0...-3]}.html#{anchor}"
  end

  # Make all relative links relative to the page location.
  # base is where the file containing the URIs is located
  # relative to the site root.
  # Handles all tags with href/src attributes.
  # Note: no mutex needed, each call operates on its own document
  private def self.strip_url_prefix(path : String) : String
    prefix = Config.options.url_prefix.chomp("/")
    return path if prefix.empty?
    prefixed = "/#{prefix}"
    return "/" if path == prefixed
    path.starts_with?("#{prefixed}/") ? path.lchop(prefixed) : path
  end

  private def self.resolve_root_relative(path : String, prefix : String) : String
    path = strip_url_prefix(path)
    stripped = path[1..]
    if prefix.empty? && !Config.options.url_prefix.empty?
      "/#{Config.options.url_prefix.chomp("/")}/#{stripped}"
    else
      "#{prefix}#{stripped}"
    end
  end

  # URLs that must never be relativized: in-page anchors, external
  # URLs (including protocol-relative //host/path)
  private def self.external_or_anchor?(url : String)
    url.starts_with?("#") || url.starts_with?("//") ||
      url.matches?(/^[a-zA-Z][a-zA-Z0-9+.\-]*:/)
  end

  # Make all relative links relative to the page location.
  # base is where the file containing the URIs is located
  # relative to the site root.
  # Handles all tags with href/src attributes.
  # Note: no mutex needed, each call operates on its own document
  def self.make_links_relative(doc, base)
    prefix = relative_prefix(base)
    base_uri = URI.parse(base)

    rewrite = ->(node : Lexbor::Node, attr : String) do
      url = node[attr]
      if url.starts_with?("/")
        node[attr] = resolve_root_relative(url, prefix)
      else
        node[attr] = md_link_to_html(base_uri.relativize(base_uri.resolve(url)).to_s)
      end
    end

    {"a", "link"}.each do |tag|
      doc.nodes(tag).each do |node|
        next unless node.has_key? "href"
        next if external_or_anchor?(node["href"])
        next if tag == "link" && node.fetch("rel", nil) == "canonical"
        rewrite.call(node, "href")
      end
    end
    {"img", "script", "video", "audio", "source", "iframe", "embed"}.each do |tag|
      doc.nodes(tag).each do |node|
        next unless node.has_key? "src"
        next if external_or_anchor?(node["src"])
        rewrite.call(node, "src")
      end
    end
    doc
  end

  # Make all relative links absolute against `base` (an absolute URL
  # like "https://example.com/blog/posts/foo/index.html").
  # Handles all tags with href/src attributes; external URLs and
  # in-page anchors are left untouched.
  # Note: no mutex needed, each call operates on its own document
  def self.make_links_absolute(doc, base)
    base_uri = URI.parse(base)

    rewrite = ->(node : Lexbor::Node, attr : String) do
      url = node[attr]
      return if external_or_anchor?(url) || url.empty?
      # Page-relative links follow the site's .md → .html convention,
      # mirroring make_links_relative; convert BEFORE resolving because
      # md_link_to_html leaves absolute URLs alone; root-relative
      # links are resolved as-is
      node[attr] = url.starts_with?("/") ? base_uri.resolve(url).to_s : base_uri.resolve(md_link_to_html(url)).to_s
    end

    {"a", "link"}.each do |tag|
      doc.nodes(tag).each do |node|
        next unless node.has_key? "href"
        next if tag == "link" && node.fetch("rel", nil) == "canonical"
        rewrite.call(node, "href")
      end
    end
    {"img", "script", "video", "audio", "source", "iframe", "embed"}.each do |tag|
      doc.nodes(tag).each do |node|
        next unless node.has_key? "src"
        rewrite.call(node, "src")
      end
    end
    doc
  end

  # Make all relative href/src values absolute against `base` directly
  # on the html STRING, mirroring relativize_links_in_string. The
  # regexes already exclude absolute URLs, protocol-relative URLs and
  # anchors, so those pass through unchanged.
  def self.absolutize_links_in_string(html : String, base : String) : String
    # Nothing to rewrite: skip the gsub scan entirely
    return html unless html.matches?(NEEDS_LINK_FIX) || html.matches?(ROOT_RELATIVE_FIX)
    base_uri = URI.parse(base)
    # Relative links (not starting with /), with the same .md → .html
    # conversion make_links_relative applies to them
    html = html.gsub(NEEDS_LINK_FIX_CAPTURE) do |match|
      quote = $1
      value = $2
      resolved = base_uri.resolve(md_link_to_html(value)).to_s
      "#{match[0, match.size - value.size - 1]}#{resolved}#{quote}"
    end
    # Root-relative links (/images/a.png → https://site/images/a.png)
    html.gsub(ROOT_RELATIVE_FIX) do |match|
      quote = $1
      value = "/#{$2}"
      # match is prefix + "/" + value + quote, so drop 2 (slash+quote)
      "#{match[0, match.size - $2.size - 2]}#{base_uri.resolve(value)}#{quote}"
    end
  end

  # Remove empty paragraph tags
  def self.remove_empty_paragraphs(doc)
    # Collect nodes first, then remove to avoid modifying during iteration
    empty_paragraphs = [] of Lexbor::Node
    doc.nodes("p").each do |node|
      # Remove if it has no text AND no element children: a paragraph
      # holding only an image, video or iframe has no inner text but
      # is far from empty
      next unless node.inner_text.strip.empty?
      has_elements = node.children.any? { |child| !child.is_text? && !child.is_comment? }
      empty_paragraphs << node unless has_elements
    end
    empty_paragraphs.each(&.remove!)
    doc
  end

  # Post-process HTML to add language- prefix to code blocks.
  # Idempotent: safe to run repeatedly (e.g. once per content pass and
  # again on the page render), since it only adds the language- prefix
  # when no token already carries one.
  def self.fix_code_classes(doc)
    doc.css("pre code").each do |node|
      next unless node.has_key? "class"
      classes = node["class"].to_s
      split_classes = classes.split
      next if split_classes.empty?
      # language- codes are already normalized; tz- codes come
      # pre-highlighted from tartrazine and must stay as they are
      next if split_classes.any? { |cls| cls.starts_with?("language-") || cls.starts_with?("tz-") }
      node["data-lang"] = split_classes[0]
      split_classes[0] = "#{split_classes[0]} language-#{split_classes[0]}"
      node["class"] = split_classes.join(" ")
    end
    doc
  end
end
