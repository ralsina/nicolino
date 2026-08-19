require "crinja"
require "./theme"

module Templates
  extend self

  # Compute the kv:// dependencies of a template file: every other
  # template it references through {% include %}, {% extends %},
  # {% import %} or {% from ... import %}.
  def self.get_deps(template)
    source = File.read(template)
    if Croupier::TaskManager.get(template) == source
      Log.debug { "Template #{template} unchanged" }
    else
      Croupier::TaskManager.set(template, source)
    end
    DependencyVisitor.new("kv://#{template}").dependencies(source)
  end

  # Resolve a template reference as written in a tag (see
  # DependencyVisitor) to the key it is stored under, using the same
  # rules as Templates::StoreLoader
  def self.resolve_template_key(reference : String) : String
    if reference.starts_with?("templates/")
      "#{Theme.path}/#{reference}"
    elsif reference.starts_with?("themes/")
      reference
    elsif reference.starts_with?("shortcodes/")
      reference
    else
      "#{Theme.templates_dir}/#{reference}"
    end
  end

  # A visitor over a parsed template's AST that collects references to
  # other templates, following crinja's visitor pattern (see
  # Crinja::Visitor and Visitor::Inspector). The parser AST has no
  # accept method, so this visitor owns the traversal itself.
  #
  # Only statically resolvable references (string literals) are
  # collected: a dynamic reference like {% include somevar %} can't be
  # tracked without rendering, so it is skipped (and logged at debug
  # level) instead of producing a bogus dependency.
  class DependencyVisitor < Crinja::Visitor(Array(String))
    # The visit macro builds type names as AST::<name>; make that
    # resolve from this class
    alias AST = Crinja::AST

    # Tags whose string literal arguments name other templates
    REFERENCE_TAGS = {"include", "extends", "import", "from"}

    def initialize(@current_template : String)
      @dependencies = [] of String
    end

    # Parse *source* and return the kv:// keys of all referenced
    # templates, deduplicated and sorted. Self-references (a template
    # including itself) are skipped.
    def dependencies(source : String) : Array(String)
      visit(Crinja::Template.new(source).nodes)
      @dependencies.uniq!.sort!
    end

    visit(NodeList) do
      node.children.each { |child| visit(child) }
    end

    visit(TagNode) do
      collect_references(node) if REFERENCE_TAGS.includes?(node.name)
      visit(node.block) unless node.block.nil?
    end

    visit(TemplateNode) do
      # FixedString, Note, EndTagNode and PrintStatement carry no
      # template references
    end

    private def collect_references(node : Crinja::AST::TagNode) : Nil
      literals = node.arguments.select(&.kind.string?)
      if literals.empty?
        Log.debug { "Skipping untrackable dynamic #{node.name} reference in #{@current_template}" }
        return
      end
      # An include may name a list of alternative templates; taking
      # every string literal covers both that form and the plain one
      literals.each do |literal|
        key = "kv://#{Templates.resolve_template_key(literal.value)}"
        next if key == @current_template # self-inclusion
        @dependencies << key
      end
    end
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

      # Note: include dependencies are declared at task-creation time in
      # load_templates (see get_deps), NOT discovered here. Mutating task
      # inputs at render time was racy under parallel builds (issue #21)
      # and could not order the current run's waves anyway.
      source
    end
  end

  # Load templates from theme directory and put them in the k/v store
  def self.load_templates : Int32
    ensure_theme
    Log.debug { "Scanning Templates" }
    count = 0
    Dir.glob("#{Theme.templates_dir}/*.tmpl").each do |template|
      # Get template dependencies (the templates it includes) so they
      # can be declared as inputs: this orders the kv tasks correctly
      # in parallel builds and invalidates dependents on change
      deps = get_deps(template)
      Log.debug { "Template #{template} dependencies: #{deps.inspect}" }

      FeatureTask.new(
        feature_name: "templates",
        id: "template",
        inputs: [template] + deps,
        output: "kv://#{template}",
        mergeable: false
      ) do
        Log.debug { "👈 #{template}" }
        # Yes, we re-read it when get_deps already did it.
        # In auto mode the content may have changed though.
        File.read(template)
      end

      count += 1
    end
    count
  end

  # Ensure all baked-in theme files exist in the themes/default/ directory
  # If any are missing, extract them from the baked filesystem
  def self.ensure_theme
    theme_dir = Path[Theme.path]
    FileUtils.mkdir_p(theme_dir) unless Dir.exists?(theme_dir)

    begin
      # Get list of baked-in theme files
      Nicolino::ThemeFiles.files.each do |file|
        # Get the relative path from themes/default/
        theme_path = Path[theme_dir, file.path[1..]].normalize

        # Check if file exists
        unless File.exists?(theme_path)
          Log.info { "Installing missing theme file: #{theme_path}" }
          FileUtils.mkdir_p(File.dirname(theme_path))
          file.rewind
          File.write(theme_path, file.gets_to_end)
        end
      end
    rescue ex
      Log.debug { "Could not check for missing theme files: #{ex.message}" }
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

  # Pool of Crinja environments.
  #
  # Croupier spawns fresh worker fibers for every wave (and for every
  # rebuild in auto mode), so a per-fiber cache would rebuild each
  # environment - and re-parse every template in it - on each wave,
  # while leaking the dead fibers' entries.
  #
  # Environments are checked out lazily on first use by the fiber
  # running a task (so tasks that never render, like image processing,
  # don't create one) and returned by FeatureTask's ensure block, so
  # environments and their template caches are reused across waves
  # without ever being shared by two concurrent workers.
  class EnvCache
    @@pool = [] of Crinja
    @@checkouts = Hash(Fiber, Crinja).new
    @@mutex = Mutex.new

    # Check out an environment for the current fiber, creating (or
    # reusing a pooled) one if needed. Idempotent within a fiber.
    def self.acquire(env_factory : Proc(Crinja)) : Crinja
      @@mutex.synchronize do
        @@checkouts[Fiber.current] ||= (@@pool.pop? || env_factory.call)
      end
    end

    # Return the current fiber's environment to the pool, if it has
    # one. Extra environments beyond the pool limit are dropped.
    def self.release : Nil
      @@mutex.synchronize do
        if env = @@checkouts.delete(Fiber.current)
          @@pool << env if @@pool.size < System.cpu_count
        end
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

  # Get the Crinja environment for the current task, checking one out
  # of the pool on first use (see EnvCache). Calls outside a task
  # simply keep their environment checked out for the fiber's lifetime.
  def self.environment
    EnvCache.acquire(->create_env)
  end

  # The build-constant site variables templates see (per language),
  # used by TemplatePreprocessor to fold constant subtrees at load
  # time. Keep in sync with Render.apply_template's site vars.
  def self.constants_for(lang) : Hash(String, Crinja::Value)
    lang_config = Config[lang]
    {
      "site_title"       => Crinja::Value.new(lang_config.title),
      "site_description" => Crinja::Value.new(lang_config.description),
      "site_url"         => Crinja::Value.new(lang_config.url),
      "site_footer"      => Crinja::Value.new(lang_config.footer),
      "site_nav_items"   => Crinja::Value.new(lang_config.nav_items),
    }
  end

  # The (folded) template for *name* in *lang* on the current
  # fiber's environment
  def self.get_template(name : String, lang : String) : Crinja::Template
    env = environment
    return env.get_template(name) if ENV["NO_FOLD"]?
    TemplatePreprocessor.get_template(env, name, lang, constants_for(lang))
  end
end
