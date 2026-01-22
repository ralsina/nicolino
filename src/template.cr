require "crinja"
require "./theme"

module Templates
  extend self

  def self.get_deps(template)
    source = File.read(template)
    if Croupier::TaskManager.get(template) == source
      Log.debug { "Template #{template} unchanged" }
    else
      Croupier::TaskManager.set(template, source)
    end
    # Pass the current template's k/v key to skip self-includes
    current_template_key = "kv://#{template}"
    find_includes_recursive(Crinja::Template.new(source).nodes, current_template_key)
  end

  # Recursively traverse the AST to find all {% include %} tags
  # current_template is used to skip self-references (templates that include themselves)
  def self.find_includes_recursive(node : Crinja::AST::NodeList, current_template : String) : Array(String)
    find_includes_recursive(node.@children, current_template)
  end

  private def self.find_includes_recursive(nodes : Array(Crinja::AST::TemplateNode), current_template : String) : Array(String)
    deps = [] of String
    nodes.each do |node|
      deps.concat(find_includes_recursive(node, current_template))
    end
    deps
  end

  private def self.find_includes_recursive(node : Crinja::AST::TagNode, current_template : String) : Array(String)
    deps = [] of String
    if node.@name == "include"
      # Resolve included template path to full theme path
      included_template = node.@arguments[0].value.as(String)
      # If include path starts with "templates/", remove it and add theme path
      # If include path starts with "shortcodes/", use it as-is (shortcodes are not in themes)
      # Otherwise it's a relative path, just add theme path
      if included_template.starts_with?("templates/")
        included_key = "#{Theme.path}/#{included_template}"
      elsif included_template.starts_with?("themes/")
        included_key = included_template
      elsif included_template.starts_with?("shortcodes/")
        included_key = included_template
      else
        included_key = "#{Theme.templates_dir}/#{included_template}"
      end
      kv_key = "kv://#{included_key}"

      # Skip self-references (template includes itself)
      unless kv_key == current_template
        deps << kv_key
      end
    end

    # Recursively search in the tag's block (if it has one)
    if block = node.@block
      deps.concat(find_includes_recursive(block, current_template))
    end

    deps
  end

  private def self.find_includes_recursive(node : Crinja::AST::TemplateNode, current_template : String) : Array(String)
    # For other node types that don't contain includes, return empty
    [] of String
  end

  # A Crinja Loader that is aware of the k/v store
  class StoreLoader < Crinja::Loader
    @cache_sources = {} of String => String

    def get_source(env : Crinja, template : String) : {String, String?}
      # No caching in auto mode

      if Croupier::TaskManager.auto_mode?
        return {_get_source(env, template), nil}
      end
      return {@cache_sources[template] ||= _get_source(env, template), nil}
    end

    def _get_source(env : Crinja, template : String) : String
      # Resolve template path - if it doesn't start with themes/, prefix with current theme path
      if template.starts_with?("templates/")
        template_key = "#{Theme.path}/#{template}"
      elsif template.starts_with?("themes/")
        template_key = template
      elsif template.starts_with?("shortcodes/")
        template_key = template
      else
        template_key = "#{Theme.templates_dir}/#{template}"
      end
      source = Croupier::TaskManager.get("#{template_key}")
      raise "Template #{template} not found (looked for #{template_key})" if source.nil?

      # Find all include tags recursively and add them as dependencies
      current_template_key = "kv://#{template_key}"
      includes = Templates.find_includes_recursive(Crinja::Template.new(source).nodes, current_template_key)
      includes.each do |included_key|
        Croupier::TaskManager.tasks["kv://#{template_key}"].inputs << included_key
      end

      source
    end
  end

  # Load templates from theme directory and put them in the k/v store
  def self.load_templates : Int32
    ensure_templates
    ensure_assets
    Log.debug { "Scanning Templates" }
    count = 0
    Dir.glob("#{Theme.templates_dir}/*.tmpl").each do |template|
      # Get template dependencies for auto-mode tracking
      deps = get_deps(template)
      Log.debug { "Template #{template} dependencies: #{deps.inspect}" }

      Croupier::Task.new(
        id: "template",
        inputs: [template], # Only the file itself, not other templates (those are runtime deps)
        output: "kv://#{template}",
        mergeable: false
      ) do
        Log.debug { "👈 #{template}" }
        # Yes, we re-read it when get_deps already did it.
        # In auto mode the content may have changed though.
        File.read(template)
      end

      # Register template dependencies for auto-mode invalidation
      # When a template changes, any task that uses it should be re-run
      unless deps.empty?
        deps.each do |dep|
          # Add the current template as a dependent of the included template
          # We can't easily add reverse deps, but we can track this separately
          # For now, we'll add them to a special registry
          Croupier::TaskManager.tasks[dep]?
        end
      end

      count += 1
    end
    count
  end

  # Ensure all baked-in assets exist in the theme assets/ directory
  # If any are missing, extract them from the baked filesystem
  def self.ensure_assets
    assets_dir = Path[Theme.assets_dir]
    FileUtils.mkdir_p(assets_dir) unless Dir.exists?(assets_dir)

    begin
      # Get list of baked-in asset files
      Nicolino::AssetsFiles.files.each do |file|
        # Get the relative path from assets/
        asset_path = Path[assets_dir, file.path[1..]].normalize

        # Check if file exists
        unless File.exists?(asset_path)
          Log.info { "Installing missing asset: #{asset_path}" }
          FileUtils.mkdir_p(File.dirname(asset_path))
          file.rewind
          File.write(asset_path, file.gets_to_end)
        end
      end
    rescue ex
      Log.debug { "Could not check for missing assets: #{ex.message}" }
    end
  end

  # Ensure all baked-in templates exist in the theme templates/ directory
  # If any are missing, extract them from the baked filesystem
  def self.ensure_templates
    templates_dir = Path[Theme.templates_dir]
    FileUtils.mkdir_p(templates_dir) unless Dir.exists?(templates_dir)

    begin
      # Check each baked template file directly
      Nicolino::TemplateFiles.files.each do |file|
        template_name = Path[file.path].basename.to_s
        template_path = templates_dir / template_name

        unless File.exists?(template_path)
          Log.info { "Installing missing template: #{template_name}" }
          file.rewind
          File.write(template_path, file.gets_to_end)
        end
      end
    rescue ex
      # If we can't access baked files (shouldn't happen), just log and continue
      Log.debug { "Could not check for missing templates: #{ex.message}" }
    end
  end

  # Ensure all baked-in shortcodes exist in the shortcodes/ directory
  # If any are missing, extract them from the baked filesystem
  def self.ensure_shortcodes
    shortcodes_dir = Path["shortcodes"]
    FileUtils.mkdir_p(shortcodes_dir) unless Dir.exists?(shortcodes_dir)

    begin
      # Check each baked shortcode file directly
      Nicolino::ShortcodesFiles.files.each do |file|
        shortcode_name = Path[file.path].basename.to_s
        shortcode_path = shortcodes_dir / shortcode_name

        unless File.exists?(shortcode_path)
          Log.info { "Installing missing shortcode: #{shortcode_name}" }
          file.rewind
          File.write(shortcode_path, file.gets_to_end)
        end
      end
    rescue ex
      # If we can't access baked files (shouldn't happen), just log and continue
      Log.debug { "Could not check for missing shortcodes: #{ex.message}" }
    end
  end


  # Thread-local environment cache
  class EnvCache
    @@envs = Hash(Fiber, Crinja).new
    @@mutex = Mutex.new

    def self.get(env_factory : Proc(Crinja))
      fiber = Fiber.current
      @@mutex.synchronize do
        @@envs[fiber] ||= env_factory.call
      end
    end
  end

  # Create a new Crinja environment
  private def self.create_env
    env = Crinja.new
    env.loader = StoreLoader.new
    env.cache = Crinja::TemplateCache::InMemory.new

    # Convenience filters
    env.filters["link"] = Crinja.filter() do
      return Crinja::Value.new(%(<a href="#{target["link"]}">#{target["name"]}</a>)) unless target["link"].empty?
      return target["name"]
    end

    # Convert image filename to thumbnail filename
    env.filters["thumb_url"] = Crinja.filter() do
      filename = target.to_s
      ext = File.extname(filename)
      basename = filename.chomp(ext)
      return Crinja::Value.new("#{basename}.thumb#{ext}")
    end

    # Shell command execution for the shell shortcode
    env.functions["shell"] = Crinja.function do
      args = arguments.varargs[0].as_h

      # Get command - try named arg or positional arg
      cmd = if args["command"]?
              args["command"].to_s
            elsif args["0"]?
              args["0"].to_s
            else
              return Crinja::Value.new("<span class=\"shell-error\">Error: shell shortcode requires a command argument</span>")
            end

      # Get working directory - default to current dir
      work_dir = if args["cd"]?
                   args["cd"].to_s
                 else
                   "."
                 end

      output = IO::Memory.new
      error = IO::Memory.new
      status = Process.run(
        cmd,
        shell: true,
        output: output,
        error: error,
        chdir: work_dir
      )

      result = output.to_s.strip

      if status.success?
        Crinja::Value.new(result)
      else
        error_msg = error.to_s.strip
        if error_msg.empty?
          error_msg = "Command failed with exit code #{status.exit_code}"
        end
        Log.warn { "Shell command failed: #{cmd} - #{error_msg}" }
        Crinja::Value.new("<span class=\"shell-error\">Command failed: #{error_msg}</span>")
      end
    end

    env
  end

  # Get the thread/fiber-local Crinja environment
  def self.environment
    EnvCache.get(->create_env)
  end
end
