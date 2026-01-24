require "lexbor"
require "./utils"

module Toc
  # Extract table of contents from HTML and add anchors to headings
  # Returns a tuple of [html_with_anchors, toc_html_fragment]
  def self.extract_and_annotate(html : String) : Tuple(String, String)
    doc = Lexbor::Parser.new(html)
    headings = doc.css("h1, h2, h3, h4, h5, h6")

    return {html, ""} if headings.empty?

    # Build TOC as a flat list first with anchors
    toc_items = [] of Tuple(Int32, String, String) # level, anchor, text

    headings.each do |heading|
      level = heading.tag_name[1].to_i
      text = heading.inner_text

      # Generate slug for anchor if not present
      id_attr = heading["id"]?
      anchor = id_attr || Utils.slugify(text)

      # Add id attribute to the heading if not present
      heading["id"] = anchor unless id_attr

      toc_items << {level, anchor, text}
    end

    # Convert the flat list to nested HTML
    toc_html = build_nested_toc(toc_items)

    # Get the modified HTML
    modified_html = doc.to_html

    {modified_html, toc_html}
  end

  # Build nested TOC HTML
  private def self.build_nested_toc(items : Array(Tuple(Int32, String, String))) : String
    return "" if items.empty?

    String.build do |io|
      io << "<ul>"
      current_depth = 0

      items.each_with_index do |(level, anchor, text), index|
        # Calculate depth difference
        depth_diff = current_depth - level

        # Close lists if going back up
        if depth_diff > 0
          depth_diff.times { io << "</ul></li>" }
        elsif depth_diff < 0 && index > 0
          # Going deeper - open new list
          io << "<ul>"
          current_depth = level
        end

        # Add current item
        io << %(<li><a href="##{anchor}">#{text}</a>)
      end

      # Close all remaining lists
      current_depth.times { io << "</ul></li>" }
      io << "</li></ul>"
    end
  end
end
