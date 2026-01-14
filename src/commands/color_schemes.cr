require "./command.cr"

module Nicolino
  module Commands
    # nicolino color_schemes command
    #
    # List and apply available base16 color scheme families.
    struct ColorSchemes < Command
      @@name = "color_schemes"
      @@doc = <<-DOC
List and apply available base16 color scheme families.

Usage:
  nicolino color_schemes [--help][-c <file>][--apply <family>][-q|-v <level>]

Options:
  --help            Show this help message
  -c <file>         Specify a config file to use [default: conf.yml]
  --apply <family>  Apply a color scheme family to conf.yml
  -v level          Control the verbosity, 0 to 6 [default: 4]
  -q                Don't log anything

Configuration:

Color schemes are configured in conf.yml using a family base name:

  site:
    color_scheme: "unikitty"

The sixteen library will automatically find the dark and light variants
for each family (e.g., unikitty-dark and unikitty-light).

Examples of families with both dark and light variants:
  - unikitty
  - catppuccin
  - rose-pine
  - atelier-cave, atelier-dune, atelier-forest, etc.

Use --apply to set the color scheme, or run without options to list
all available families.
DOC

      def run : Int32
        if family_name = @options["--apply"]?
          apply_family(family_name.as(String))
        else
          show_families
        end
        0
      rescue ex : Exception
        Log.error(exception: ex) { "Error: #{ex.message}" }
        1
      end

      private def apply_family(family_name : String)
        # Validate the family exists
        families = Sixteen.theme_families.select { |fam|
          !fam.dark_themes.empty? && !fam.light_themes.empty?
        }

        family = families.find { |fam| fam.base_name == family_name }

        unless family
          Log.error { "Color scheme family '#{family_name}' not found" }
          Log.info { "Run 'nicolino color_schemes' to see available families" }
          return
        end

        # For families with multiple dark variants, use the first one as default
        # (e.g., catppuccin uses catppuccin-mocha as default dark)
        dark_theme = family.dark_themes.first

        # Read and update conf.yml
        config_file = @options["-c"]? ? @options["-c"].as(String) : "conf.yml"

        unless File.exists?(config_file)
          Log.error { "Config file '#{config_file}' not found" }
          return
        end

        content = File.read(config_file)

        # Check if color_scheme already exists, otherwise add it
        if content.includes?("color_scheme:")
          # Update existing color_scheme
          content = content.gsub(/color_scheme:\s*["']([^"']+)["']/, "color_scheme: \"#{dark_theme}\"")
        else
          # Remove dark_scheme and light_scheme, add color_scheme
          content = content.gsub(/dark_scheme:\s*["'][^"']+["']\s*\n/, "")
          content = content.gsub(/light_scheme:\s*["'][^"']+["']\s*\n/, "")

          # Add color_scheme after the description line
          content = content.gsub(/(description:\s*"[^"]*"\n)/, "\\1  color_scheme: \"#{dark_theme}\"\n")
        end

        File.write(config_file, content)

        Log.info { "Updated #{config_file}:" }
        Log.info { "  color_scheme: \"#{dark_theme}\"" }
        Log.info { "" }
        Log.info { "Variants in this family:" }
        Log.info { "  dark:  #{family.dark_themes.join(", ")}" }
        Log.info { "  light: #{family.light_themes.join(", ")}" }
        Log.info { "" }
        Log.info { "Note: Using '#{dark_theme}' as the default dark variant." }
        Log.info { "      To use a different variant, edit conf.yml manually." }
        Log.info { "" }
        Log.info { "Run 'nicolino build' to apply the new color scheme." }
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
        puts "\nApply a scheme: nicolino color_schemes --apply <family>"
      end
    end
  end
end

Nicolino::Commands::ColorSchemes.register
