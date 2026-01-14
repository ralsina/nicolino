require "./command.cr"

module Nicolino
  module Commands
    # nicolino color_schemes command
    #
    # List available base16 color scheme families.
    struct ColorSchemes < Command
      @@name = "color_schemes"
      @@doc = <<-DOC
List available base16 color scheme families.

Usage:
  nicolino color_schemes [--help][-c <file>][-q|-v <level>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything

Configuration:

Color schemes are configured in conf.yml using a family base name:

  site:
    dark_scheme: "unikitty"
    light_scheme: "unikitty"

The sixteen library will automatically find the dark and light variants
for each family (e.g., unikitty-dark and unikitty-light).

Examples of families with both dark and light variants:
  - unikitty
  - catppuccin
  - rose-pine
  - atelier-cave, atelier-dune, atelier-forest, etc.

Use this command to see all available families and their variants.
DOC

      def run : Int32
        show_families
        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error: #{ex.message}" }
        1
      end

      private def show_families
        puts "Color scheme families (with dark and light variants):"
        puts

        families = Sixteen.theme_families.select { |family|
          !family.dark_themes.empty? && !family.light_themes.empty?
        }.sort_by!(&.base_name)

        families.each do |family|
          puts "#{family.base_name}"
          puts "  dark:  #{family.dark_themes.join(", ")}"
          puts "  light: #{family.light_themes.join(", ")}"
          puts unless family == families.last?
        end

        puts "\nTotal families: #{families.size}"
        puts "\nConfigure in conf.yml using the family base name:"
        puts "  site:"
        puts "    dark_scheme: \"<family-name>\""
        puts "    light_scheme: \"<family-name>\""
      end
    end
  end
end

Nicolino::Commands::ColorSchemes.register
