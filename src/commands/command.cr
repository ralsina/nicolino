require "colorize"
require "log"
require "oplog"
require "polydocopt"

module Nicolino
  module Commands
    # Base for command structs
    abstract struct Command < Polydocopt::Command
      def initialize(@options)
        # Load config and setup logging
        Config.config(@options.fetch("-c", "conf.yml").as(String))
        verbosity = @options.fetch("-v", 4).to_s.to_i
        verbosity = 0 if @options["-q"] == 1
        Oplog.setup(verbosity)
      end

      def run : Int32
        raise Exception.new("Not implemented")
      end
    end
  end
end
