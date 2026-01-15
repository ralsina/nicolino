# Parser for mdbook-style SUMMARY.md files

module Books
  # Represents a chapter entry from SUMMARY.md
  class ChapterEntry
    property title : String
    property path : String?
    property children : Array(ChapterEntry)
    property number : Array(Int32)  # e.g., [1, 2] for "1.2"
    property level : Int32          # Nesting level (0 = root)
    property is_part : Bool = false # True if this is a part title (H1)

    def initialize(@title, @path = nil, @number = [] of Int32, @level = 0)
      @children = [] of ChapterEntry
    end

    # Returns the formatted chapter number (e.g., "1.2.3")
    def formatted_number : String
      return "" if @number.empty?
      @number.join(".")
    end

    # Returns true if this chapter has content (not just a divider)
    def has_content? : Bool
      !@path.nil?
    end
  end

  # Parses SUMMARY.md into a hierarchical chapter structure
  class SummaryParser
    # Extract description from SUMMARY.md (content between title and chapters)
    def self.extract_description(content : String) : String
      lines = content.each_line
      description_lines = [] of String
      in_description = false

      lines.each do |line|
        # Strip trailing whitespace
        line = line.rstrip

        # Skip empty lines at start
        next if line.blank? && description_lines.empty?

        # Check for part title (H1 header) - start collecting description after this
        if line.starts_with?("# ")
          in_description = true
          next
        end

        # Check for separator
        next if line =~ /^---+$/

        # Stop at first chapter/item
        break if in_description && (line.starts_with?("-") || line.starts_with?("*"))

        # Collect description text
        if in_description && !line.blank?
          description_lines << line
        end
      end

      description_lines.join(" ")
    end

    # Parse SUMMARY.md content and return array of root chapters
    def self.parse(content : String) : Array(ChapterEntry)
      lines = content.each_line
      chapters = [] of ChapterEntry
      stack = [] of Tuple(Int32, ChapterEntry) # (level, chapter)

      lines.each do |line|
        # Strip trailing whitespace
        line = line.rstrip

        # Skip empty lines
        next if line.blank?

        # Check for part title (H1 header)
        if line.starts_with?("# ")
          title = line[2..].strip
          chapter = ChapterEntry.new(title, nil, [] of Int32, 0)
          chapter.is_part = true
          chapters << chapter
          next
        end

        # Check for separator
        if line =~ /^---+$/
          next
        end

        # Parse chapter link: - [Title](path.md) or * [Title](path.md)
        if line =~ /^\s*([\-\*])\s*\[([^\]]+)\]\(([^\)]*)\)/
          indent = line.index!($1)
          title = $2
          path = $3

          # Calculate nesting level (2 spaces per level)
          level = (indent // 2).to_i32

          # Pop stack to correct level FIRST (before calculating number)
          while !stack.empty? && stack.last[0] >= level
            stack.pop
          end

          # Determine chapter number (now that stack is at correct level)
          number = calculate_number(chapters, stack, level)

          # Convert empty path to nil
          path = nil if path && path.empty?

          chapter = ChapterEntry.new(title, path, number, level)

          # Add to parent or root
          add_to_hierarchy(chapters, stack, chapter, level)

          next
        end

        # Parse draft chapter: - [Title]() or * [Title]()
        if line =~ /^\s*([\-\*])\s*\[([^\]]+)\]\(\s*\)/
          indent = line.index!($1)
          title = $2

          level = (indent // 2).to_i32

          # Pop stack to correct level FIRST (before calculating number)
          while !stack.empty? && stack.last[0] >= level
            stack.pop
          end

          number = calculate_number(chapters, stack, level)

          # Draft chapter has no path
          chapter = ChapterEntry.new(title, nil, number, level)

          add_to_hierarchy(chapters, stack, chapter, level)
          next
        end
      end

      chapters
    end

    # Calculate chapter number based on position in hierarchy
    private def self.calculate_number(chapters, stack, level) : Array(Int32)
      number = [] of Int32

      if level == 0
        # Root level - count existing root chapters (excluding part titles)
        root_count = chapters.count { |c| !c.is_part }
        number << (root_count + 1)
      else
        # Nested level - get parent number and add child count
        if stack.size > 0
          parent = stack.last
          parent_number = parent[1].number
          number = parent_number.clone

          # Count siblings at this level (add 1 because we haven't added this chapter yet)
          sibling_count = parent[1].children.size + 1
          number << sibling_count
        end
      end

      number
    end

    # Add chapter to the correct parent in the hierarchy
    # Note: Stack should already be popped to correct level before calling this
    private def self.add_to_hierarchy(chapters, stack, chapter, level)
      if stack.empty?
        chapters << chapter
      else
        parent = stack.last[1]
        parent.children << chapter
      end

      # Push to stack
      stack.push({level, chapter})
    end
  end
end
