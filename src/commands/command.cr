require "colorize"
require "log"
require "oplog"
require "polydocopt"
require "progress_bar"

module Nicolino
  module Commands
    # Base for command structs
    abstract struct Command < Polydocopt::Command
      def initialize(@options)
        # Load config and setup logging
        config_file = @options["-c"]? ? @options["-c"].as(String) : "conf.yml"
        Config.config(config_file)
        progress = @options.fetch("--progress", nil)
        if progress
          theme = Progress::Theme.new(
            complete: "-",
            incomplete: "•".colorize(:blue).to_s,
            progress_head: "C".colorize(:yellow).to_s,
            alt_progress_head: "c".colorize(:yellow).to_s,
          )
          bar = Progress::Bar.new(theme: theme)
          done = 0
          Croupier::TaskManager.progress_callback = ->(_id : String) {
            done += 1
            step = done * 100.0 / Croupier::TaskManager.tasks.size - bar.current
            bar.tick(step) if step >= 1
          }
          Oplog.setup(0)
        else
          Oplog.setup(configured_verbosity)
        end
      end

      # Verbosity precedence: -q silences everything, an explicit -v
      # wins, and otherwise the given default applies.
      private def configured_verbosity : Int32
        Command.resolve_verbosity(@options, Config.verbosity)
      end

      # Resolve verbosity from parsed options.
      #
      # Note: docopt represents a flag in a [-q|-v <level>] group as
      # Int32 (0 when absent, 1 when given), and 0 is truthy in Crystal,
      # so neither a plain truthiness test nor `== true` works here.
      def self.resolve_verbosity(options : Hash(String, (Nil | String | Int32 | Bool | Array(String))), default : Int32) : Int32
        quiet = options["-q"]?
        return 0 if quiet.in?(1, true)
        explicit_level = options["-v"]?
        explicit_level.nil? ? default : explicit_level.to_s.to_i
      end

      def run : Int32
        raise Exception.new("Not implemented")
      end
    end
  end
end
