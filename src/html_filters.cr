# Functions that take a Lexbor document and return a modified version
# To create a Lexbor document, use `Lexbor::Parser.new(html)`
module HtmlFilters
  @@html_filters_mutex = Mutex.new

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

  # Make all relative links absolute to the site root
  # base is where the file containing the URIs is located
  # relative to the site root
  def self.make_links_relative(doc, base)
    @@html_filters_mutex.synchronize do
      base_uri = URI.parse(base)
      doc.nodes("a").each do |node|
        next unless node.has_key? "href"
        href = node["href"]
        # Fast path: skip anchors and already-root-relative URLs
        if href.starts_with?("#") || href.starts_with?("/")
          next
        end
        node["href"] = base_uri.relativize(base_uri.resolve(href)).to_s
      end
      doc.nodes("link").each do |node|
        next if node.fetch("rel", nil) == "canonical"
        next unless node.has_key? "href"
        href = node["href"]
        if href.starts_with?("/")
          next
        end
        node["href"] = base_uri.relativize(base_uri.resolve(href)).to_s
      end
      doc.nodes("img").each do |node|
        next unless node.has_key? "src"
        src = node["src"]
        if src.starts_with?("/")
          next
        end
        node["src"] = base_uri.relativize(base_uri.resolve(src)).to_s
      end
      doc.nodes("script").each do |node|
        next unless node.has_key? "src"
        src = node["src"]
        if src.starts_with?("/")
          next
        end
        node["src"] = base_uri.relativize(base_uri.resolve(src)).to_s
      end
      doc
    end
  end

  # Remove empty paragraph tags
  def self.remove_empty_paragraphs(doc)
    # Collect nodes first, then remove to avoid modifying during iteration
    empty_paragraphs = [] of Lexbor::Node
    doc.nodes("p").each do |node|
      # Remove if empty or only whitespace
      text = node.inner_text.strip
      empty_paragraphs << node if text.empty?
    end
    empty_paragraphs.each(&.remove!)
    doc
  end

  # Post-process HTML to add language- prefix to code blocks
  def self.fix_code_classes(doc)
    doc.css("pre code").each do |node|
      next unless node.has_key? "class"
      classes = node["class"].to_s
      # If there's a class but no language- prefix, add it
      if classes && !classes.starts_with?("language-")
        split_classes = classes.split
        node["data-lang"] = split_classes[0]
        split_classes[0] = "#{split_classes[0]} language-#{split_classes[0]}"
        node["class"] = split_classes.join(" ")
      end
    end
    doc
  end
end
