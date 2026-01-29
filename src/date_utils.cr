require "time"
require "log"
require "cronic"

# Date parsing utilities
#
# Provides a unified date parsing function that tries multiple formats
# including standard formats and common CMS-specific formats.
module DateUtils
  # Parse a date string from various formats
  #
  # Tries the following formats in order:
  # - Cronic (natural language dates like "tomorrow", "2 weeks ago")
  # - RFC 2822 (e.g., "Wed, 02 Oct 2002 13:00:00 GMT")
  # - ISO 8601 (e.g., "2022-01-01T00:00:00Z")
  # - Pocketbase (e.g., "2026-01-29 11:57:28.164Z")
  # - HTTP date (via HTTP.parse_time)
  #
  # Returns nil if the date cannot be parsed.
  def self.parse(date_str : String?) : Time?
    return nil if date_str.nil? || date_str.empty?

    # Try Cronic first (natural language parsing)
    begin
      return Cronic.parse(date_str)
    rescue
      # Fall through
    end

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

    # Try Pocketbase format: "2026-01-29 11:57:28.164Z"
    if date_str.matches?(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/)
      begin
        # Remove microseconds and replace space with T
        normalized = date_str.sub(/\.\d+Z$/, "Z").sub(" ", "T")
        return Time::Format::ISO_8601_DATE_TIME.parse(normalized)
      rescue
        # Fall through
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
end
