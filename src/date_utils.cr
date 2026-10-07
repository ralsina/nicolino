require "time"
require "log"
require "http"
require "cronic"

module DateUtils
  # Front matter dates are almost always one of a few fixed shapes.
  # These are tried first, in local time when the string carries no
  # zone (matching what Cronic assumed for them). Cronic's natural
  # language parser is roughly 10,000 times slower than a strict
  # format parse (about 2.5ms per date), and every post's date used
  # to go through it on the main thread before any task could start.
  #
  # Time::Format#parse accepts a matching prefix and ignores the rest,
  # so each pattern is guarded by an anchored regex of its exact shape.
  LOCAL_FORMATS = [
    {/\A\d{4}-\d{2}-\d{2}\z/, "%Y-%m-%d"},
    {/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/, "%Y-%m-%d %H:%M"},
    {/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/, "%Y-%m-%d %H:%M:%S"},
    {/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}\z/, "%Y-%m-%dT%H:%M"},
    {/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\z/, "%Y-%m-%dT%H:%M:%S"},
  ]

  # Zone offsets a formatter accepts: -14:00 .. +14:00. Anything
  # wider would raise from Time::Location rather than fail to parse.
  OFFSET = /[+-](?:0\d|1[0-4]):?[0-5]\d/

  # YAML parses unquoted `date: 2020-02-02` into a Time, and the
  # front matter loader stringifies it with Time#to_s, so these two
  # shapes ("2020-02-02 00:00:00 UTC", "2020-02-02 10:30:00 -03:00")
  # are what most posts actually carry
  TIME_TO_S_UTC    = /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC\z/
  TIME_TO_S_OFFSET = /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} #{OFFSET.source}\z/

  # ISO 8601 / RFC 3339 with a zone designator (Z or ±hh:mm) and an
  # optional fractional second
  ZONED_ISO = /\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|#{OFFSET.source})\z/

  # RFC 2822 ("Wed, 02 Oct 2002 13:00:00 GMT"), day name optional
  RFC_2822 = /\A(?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun), )?\d{1,2} (?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4} \d{2}:\d{2}(?::\d{2})? (?:[+-]\d{4}|[A-Z]{1,5})\z/

  # The three HTTP date shapes (RFC 1123, RFC 850, asctime)
  HTTP_DATE = /\A(?:[A-Z][a-z]{2}, \d{2} [A-Z][a-z]{2} \d{4}|[A-Z][a-z]+, \d{2}-[A-Z][a-z]{2}-\d{2}) \d{2}:\d{2}:\d{2} GMT\z|\A[A-Z][a-z]{2} [A-Z][a-z]{2} [ \d]\d \d{2}:\d{2}:\d{2} \d{4}\z/

  def self.parse(date_str : String?) : Time?
    return if date_str.nil? || date_str.empty?
    date_str = date_str.strip

    strict_parse(date_str) || natural_parse(date_str)
  end

  # Fixed-format parsers, cheapest and most common first. Every
  # formatter is guarded by an anchored regex of the exact shape it
  # handles, because Time::Format#parse accepts a matching prefix and
  # ignores whatever follows. Returns nil when no shape matches or the
  # matched text is not a valid date (month 13, 25:00), in which case
  # `parse` falls through to the natural language parser.
  #
  # Public so specs can prove a shape stays on this path.
  def self.strict_parse(date_str : String) : Time?
    LOCAL_FORMATS.each do |shape, pattern|
      next unless date_str.matches?(shape)
      return attempt { Time::Format.new(pattern, Time::Location.local).parse(date_str) }
    end
    return attempt { Time::Format.new("%F %T UTC", Time::Location::UTC).parse(date_str) } if date_str.matches?(TIME_TO_S_UTC)
    return attempt { Time::Format.new("%F %T %:z").parse(date_str) } if date_str.matches?(TIME_TO_S_OFFSET)
    # Pocketbase/SQL style uses a space separator: "2026-01-29 11:57:28.164Z"
    return attempt { Time::Format::ISO_8601_DATE_TIME.parse(date_str.sub(' ', 'T')) } if date_str.matches?(ZONED_ISO)
    return attempt { Time::Format::RFC_2822.parse(date_str) } if date_str.matches?(RFC_2822)
    return attempt { HTTP.parse_time(date_str) } if date_str.matches?(HTTP_DATE)
    nil
  end

  # Run one formatter, turning every way it can reject the text
  # (unparseable, an invalid calendar component, an offset out of
  # range) into nil
  private def self.attempt(& : -> Time?) : Time?
    yield
  rescue Time::Format::Error | ArgumentError | Time::Location::InvalidTimezoneOffsetError
    nil
  end

  # Natural language fallback ("2 weeks ago", "last tuesday")
  private def self.natural_parse(date_str : String) : Time?
    begin
      return Cronic.parse(date_str)
    rescue
    end

    Log.warn { "Could not parse date: #{date_str}" }
    nil
  end
end
