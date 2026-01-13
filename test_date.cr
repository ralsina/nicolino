require "time"

date_str = "Mon, 24 Nov 2008 00:00:00 +0000"
puts "Parsing: #{date_str}"

# Try RFC2822/2822 format
begin
  time = Time::Format::RFC_2822.parse(date_str)
  puts "Success! Parsed as: #{time}"
rescue ex
  puts "RFC_2822 failed: #{ex.message}"
end

# Try HTTP format
begin
  time = Time::Format::HTTP_DATE.parse(date_str)
  puts "HTTP_DATE success! Parsed as: #{time}"
rescue ex
  puts "HTTP_DATE failed: #{ex.message}"
end
