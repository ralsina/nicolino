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
for each family. If a variant doesn't exist, it will be auto-generated.

Examples of theme families:
  - unikitty, catppuccin, rose-pine
  - atelier-cave, atelier-dune, atelier-forest, etc.
  - dracula, monokai, nord, solarized

Use --apply to set the color scheme, or run without options to list
all available families with color swatches.
DOC

      def run : Int32
        if family_name = @options["--apply"]? ? @options["--apply"].as(String) : nil
          apply_family(family_name)
        else
          show_families
        end
        0
      rescue ex : Exception
        STDERR.puts "Error: #{ex.message}"
        STDERR.puts ex.backtrace.first(10).join("\n") if @options["--error-trace"]?
        1
      end

      private def apply_family(family_name : String)
        # Validate the family exists (all families are now valid since sixteen can auto-generate)
        families = Sixteen.theme_families

        family = families.find { |fam| fam.base_name == family_name }

        unless family
          Log.error { "Color scheme family '#{family_name}' not found" }
          Log.info { "Run 'nicolino color_schemes' to see available families" }
          return
        end

        # Get the variants that will be used (same logic as show_families)
        dark_theme = if name = family.dark_themes.find { true }
                       Sixteen.theme(name)
                     elsif name = family.light_themes.find { true }
                       Sixteen.theme(name).invert_for_theme(:dark)
                     elsif name = family.other_variants.find { true }
                       Sixteen.theme(name).invert_for_theme(:dark)
                     else
                       raise "No themes found for family #{family.base_name}"
                     end

        light_theme = if name = family.light_themes.find { true }
                        Sixteen.theme(name)
                      elsif name = family.dark_themes.find { true }
                        Sixteen.theme(name).invert_for_theme(:light)
                      elsif name = family.other_variants.find { true }
                        Sixteen.theme(name).invert_for_theme(:light)
                      else
                        raise "No themes found for family #{family.base_name}"
                      end

        # Write the family base name to conf.yml (base16.cr will resolve variants)
        config_file = @options["-c"]? ? @options["-c"].as(String) : "conf.yml"

        unless File.exists?(config_file)
          Log.error { "Config file '#{config_file}' not found" }
          return
        end

        content = File.read(config_file)

        # Check if color_scheme already exists, otherwise add it
        if content.includes?("color_scheme:")
          # Update existing color_scheme
          content = content.gsub(/color_scheme:\s*["']([^"']+)["']/, "color_scheme: \"#{family.base_name}\"")
        else
          # Remove dark_scheme and light_scheme, add color_scheme
          content = content.gsub(/dark_scheme:\s*["'][^"']+["']\s*\n/, "")
          content = content.gsub(/light_scheme:\s*["'][^"']+["']\s*\n/, "")

          # Add color_scheme after the description line
          content = content.gsub(/(description:\s*"[^"]*"\n)/, "\\1  color_scheme: \"#{family.base_name}\"\n")
        end

        File.write(config_file, content)

        Log.info { "Updated #{config_file}:" }
        Log.info { "  color_scheme: \"#{family.base_name}\"" }
        Log.info { "" }
        Log.info { "Variants in this family:" }
        Log.info { "  dark:  #{dark_theme.name}" }
        Log.info { "  light: #{light_theme.name}" }
        Log.info { "" }
        Log.info { "Run 'nicolino build' to apply the new color scheme." }
      end

      private def show_families
        families = Sixteen.theme_families
          .select { |family|
            # Only show families that have at least one theme
            !family.dark_themes.empty? || !family.light_themes.empty? || !family.other_variants.empty?
          }
          .sort_by!(&.base_name)

        families.each do |family|
          # For dark: use first dark theme, or first light theme inverted, or first theme inverted
          dark_theme = if name = family.dark_themes.find { true }
                         Sixteen.theme(name)
                       elsif name = family.light_themes.find { true }
                         Sixteen.theme(name).invert_for_theme(:dark)
                       elsif name = family.other_variants.find { true }
                         Sixteen.theme(name).invert_for_theme(:dark)
                       else
                         raise "No themes found for family #{family.base_name}"
                       end

          # For light: use first light theme, or first dark theme inverted, or first theme inverted
          light_theme = if name = family.light_themes.find { true }
                          Sixteen.theme(name)
                        elsif name = family.dark_themes.find { true }
                          Sixteen.theme(name).invert_for_theme(:light)
                        elsif name = family.other_variants.find { true }
                          Sixteen.theme(name).invert_for_theme(:light)
                        else
                          raise "No themes found for family #{family.base_name}"
                        end

          puts "#{family.base_name}"
          puts "  #{dark_theme.term_palette} dark: #{dark_theme.name}"
          puts "  #{light_theme.term_palette} light: #{light_theme.name}"

          puts unless family == families.last?
        end

        puts "\nTotal families: #{families.size}"
        puts "\nApply a scheme: nicolino color_schemes --apply <family>"
      end
    end
  end
end

Nicolino::Commands::ColorSchemes.register
