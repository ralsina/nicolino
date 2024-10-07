require "./commands/*"
require "./*"

exit Polydocopt.main("nicolino", ["--help"]) if ARGV.empty?
cmdname = ARGV[0]

if cmdname == "version"
  puts "nicolino #{VERSION}"
  exit 0
end

exit(Polydocopt.main("nicolino", ARGV))
