require "./commands/*"
require "./*"

exit Docopt::Dispatch.main("nicolino", ["--help"]) if ARGV.empty?
cmdname = ARGV[0]

if cmdname == "version" || cmdname == "--version"
  puts "nicolino #{VERSION}"
  exit 0
end

exit(Docopt::Dispatch.main("nicolino", ARGV))
