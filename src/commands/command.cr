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
        verbosity = @options.fetch("-v", 4).to_s.to_i
        verbosity = 0 if @options["-q"] == 1
        progress = @options.fetch("--progress", nil)
        if progress
          verbosity = 0
          theme = Progress::Theme.new(
            complete: "-",
            incomplete: "•".colorize(:blue).to_s,
            progress_head: "C".colorize(:yellow).to_s,
            alt_progress_head: "c".colorize(:yellow).to_s,
          )
          bar = Progress::Bar.new(theme: theme)
          done = 0
          total = Croupier::TaskManager.tasks.size
          Croupier::TaskManager.progress_callback = ->(_id : String) {
            done += 1
            # Calculate progress, ensuring we reach exactly 100 on the last task
            if done == total
              # Last task - tick to exactly 100
              remaining = 100.0 - bar.current
              bar.tick(remaining) if remaining > 0
            else
              step = done * 100.0 / total - bar.current
              bar.tick(step) if step >= 1
            end
          }
        end
        Oplog.setup(verbosity)
      end

      def run : Int32
        raise Exception.new("Not implemented")
      end
    end
  end
end
