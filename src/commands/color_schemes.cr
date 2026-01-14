require "./command.cr"

module Nicolino
  module Commands
    # nicolino color_schemes command
    #
    # List and explore available base16 color schemes.
    struct ColorSchemes < Command
      @@name = "color_schemes"
      @@doc = <<-DOC
List and explore available base16 color schemes.

Usage:
  nicolino color_schemes [--help][-c <file>][--families][--info <scheme>][--list][--interactive][-q|-v <level>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  --families        Show theme families (dark/light variant groups)
  --info <scheme>   Show detailed info about a specific scheme
  --list            List all available schemes (default)
  --interactive     Interactive theme browser
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything

Examples:
  nicolino color_schemes              # List all schemes
  nicolino color_schemes --families   # Show dark/light pairs
  nicolino color_schemes --info unikitty-dark

Configuration:

Color schemes are configured in conf.yml:

  site:
    dark_scheme: "unikitty-dark"
    light_scheme: "unikitty-light"

To use a different scheme, simply change the scheme name. The 'sixteen'
library includes 200+ base16 schemes. Use this command to discover them.

When you pick a scheme, consider using both dark and light variants from
the same family for better consistency. Use --families to see related
schemes.
DOC

      def run : Int32
        # Build args for the sixteen command
        args = ["sixteen"]

        if @options["--families"]?
          args << "--families"
        elsif info_scheme = @options["--info"]?
          args << "--info"
          args << info_scheme.as(String)
        elsif @options["--interactive"]?
          args << "--interactive"
        else
          args << "--list"
        end

        # Run the sixteen command with our args
        Log.debug { "Running: sixteen #{args.join(" ")}" }
        result = Process.run("sixteen", args[1..], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
        result.exit_code
      rescue ex : Exception
        Log.error(exception: ex) { "Error: #{ex.message}" }
        1
      end
    end
  end
end

Nicolino::Commands::ColorSchemes.register
