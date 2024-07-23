require "./command.cr"

module Nicolino
  module Commands
    # nicolino clean command
    struct Clean < Command
      @@name = "clean"
      @@doc = <<-DOC
Clean unknown files

It removes files from output/ which are not generated by
Nicolino. Use with care.

Usage:
  nicolino clean  [-c <file>][-q|-v <level>]

Options:
  -c <file>        Specify a config file to use [default: conf.yml]
  -v level         Control the verbosity, 0 to 6 [default: 4]
  -q               Don't log anything [default: false]
DOC

      def run : Int32
        create_tasks
        existing = Set.new(Dir.glob(Path[Config.options.output] / "**/*"))
        targets = Set.new(Croupier::TaskManager.tasks.keys)
        targets = targets.map { |path| Path[path].normalize.to_s }
        to_clean = existing - targets
        # Only delete files
        to_clean.each do |path|
          next if File.info(path).directory?
          Log.warn { "❌ #{path}" }
          File.delete(path)
        end
        0
      end
    end
  end
end

Nicolino::Commands::Clean.register
