require "lua"
require "./theme"

# User-defined template filters written in Lua.
#
# Scripts live either site-wide in `filters/*.lua` (like shortcodes) or
# in the current theme's `filters/*.lua`; on name collisions the
# site-level script wins. Each script must return a table mapping filter
# names to functions; every function becomes a Crinja filter callable as
# `{{ value | name(extra, args) }}`, invoked as `name(value, extra, args)`.
#
# Example (themes/<theme>/filters/example.lua):
# ```lua
# return {
#   shout = function(text)
#     return string.upper(text) .. "!"
#   end,
# }
# ```
#
# Loading model: each Crinja environment owns one `State` which parses
# every script exactly once per build. Script top-level code runs once
# per environment, so keep it free of side effects (returning the table
# of functions is all that matters).
#
# Concurrency: the env pool in Templates guarantees an environment is
# never used by two fibers at once, so Lua states need no locking.
#
# Staleness: script files are declared as inputs of every template-
# rendering task family (posts, pages, taxonomies, listings, books,
# galleries, archive, base16), so Croupier re-renders affected pages
# when they change and reports them through its modified set; States
# rebuild off that signal instead of polling the filesystem.
#
# Security: scripts run with Lua's full standard library (os, io, debug),
# so themes are trusted code. Anyone who can write filters/*.lua can do
# anything the build user can — same trust level as conf.yml or the shell
# shortcode, but worth knowing before installing third-party themes.
module LuaFilters
  Log = ::Log.for("nicolino.lua")

  # Directory holding user scripts for the current theme.
  # Internal (used by State); not part of the public API.
  def self.filters_dir : String
    "#{Theme.path}/filters"
  end

  # All script files currently on disk: site-level `filters/*.lua`
  # first-class like shortcodes, plus the current theme's scripts.
  # Site files sort last so their exports win name collisions.
  # Internal (used by State); not part of the public API.
  def self.script_paths : Array(String)
    combine_paths(
      Dir.glob("#{filters_dir}/*.lua"),
      Dir.glob("filters/*.lua"),
    )
  end

  # Merge theme and site script lists; both groups stay alphabetically
  # sorted, theme group first. State loads paths in order and last
  # export wins, so site-level scripts override theme defaults.
  # Internal (exercised by specs); not part of the public API.
  def self.combine_paths(theme_paths : Array(String), site_paths : Array(String)) : Array(String)
    theme_paths.sort + site_paths.sort
  end

  def self.enabled? : Bool
    !script_paths.empty?
  end

  # Script file paths to declare as task inputs, so pages rendered with
  # these filters get invalidated (and watched in auto mode) when any
  # script changes.
  def self.dependency_paths : Array(String)
    enabled? ? script_paths : [] of String
  end

  # Register all exported functions as Crinja filters on *env*.
  #
  # The State is built eagerly here: this both discovers filter names
  # and performs the environment's only parse of the scripts. The
  # closures bind that same State, so concurrent fibers never share a
  # Lua state (one State per environment, guaranteed by Templates).
  def self.register(env : Crinja) : Nil
    return unless enabled?

    state = State.new
    names = state.filter_names
    return if names.empty?

    names.each do |filter_name|
      # NOTE: no `name:` argument here — passing one appends the
      # callable to Crinja's process-wide filter library defaults,
      # which races when parallel fibers create environments.
      env.filters[filter_name] = Crinja.filter do
        state.call_function(filter_name, target, arguments.varargs)
      end
    end
    Log.info { "Registered #{names.size} Lua filter(s): #{names.join(", ")}" }
  end

  # One Lua state per Crinja environment.
  #
  # Scripts are parsed on first use and re-parsed only when Croupier
  # reports one of them modified (edge-triggered: at most one rebuild
  # per change detection cycle, no filesystem polling).
  class State
    @stack : Lua::Stack? = nil
    @functions = {} of String => Lua::Function
    @caller : Lua::Function? = nil
    @paths : Array(String)? = nil
    @handled_modified = Set(String).new

    # *explicit_paths* overrides theme discovery (used by specs);
    # production states resolve paths from the current theme at build
    # time.
    def initialize(explicit_paths : Array(String)? = nil)
      @explicit_paths = explicit_paths
    end

    # Lua-side helper defined once per state. Filters are addressed by
    # NAME because lua.cr cannot push Lua::Function handles back into
    # the interpreter; Crystal copies each export to a hidden global
    # before first use instead.
    CALLER_SOURCE = <<-LUA
      function __nicolino_call(name, args)
        local fn = _G["__nicolino_fn_" .. name]
        if not fn then
          error("unknown filter: " .. tostring(name))
        end
        return fn(table.unpack(args))
      end
      return __nicolino_call
      LUA

    # Values that can cross the Crystal→Lua boundary. The explicit Nil
    # member is required: a recursive alias needs it so nested
    # containers may hold nils.
    private alias LuaArg = Nil | Bool | Int32 | Int64 | Float64 | String | Array(LuaArg) | Hash(String, LuaArg) # ameba:disable Style/VerboseNilType

    # Convert a Crinja value into something `Lua::Stack` can push

    private def to_lua_arg(value : Crinja::Value) : LuaArg
      case raw = value.raw
      when Nil
        nil
      when Bool
        raw
      when Int32, Int64
        raw
      when Float32, Float64
        raw.to_f
      when String
        raw
      when Crinja::SafeString
        raw.to_s
      when Crinja::Undefined
        nil
      when Array(Crinja::Value)
        raw.map { |item| to_lua_arg(item) }
      when Crinja::Dictionary
        converted = {} of String => LuaArg
        raw.each do |key, item|
          converted[dict_key(key)] = to_lua_arg(item)
        end
        converted
      else
        raise Crinja::TypeError.new(value, "can't pass #{raw.class} to a Lua filter")
      end
    end

    # Stringify a dictionary key for Lua table conversion
    private def dict_key(key : Crinja::Value) : String
      case raw = key.raw
      when String
        raw
      when Crinja::SafeString
        raw.to_s
      when Number, Bool
        raw.to_s
      else
        raise Crinja::TypeError.new(key, "unsupported dictionary key type #{raw.class} for Lua filter")
      end
    end

    # Convert a Lua return value into a Crinja value
    private def from_lua_value(value, filter_name : String) : Crinja::Value
      case value
      when Nil
        Crinja::Value.new(nil)
      when Bool
        Crinja::Value.new(value)
      when Int32, Int64
        Crinja::Value.new(value)
      when Float64
        float_to_value(value)
      when String
        Crinja::Value.new(value)
      when Lua::Table
        Crinja::Value.new(table_to_value(value, filter_name))
      else
        raise "Lua filter '#{filter_name}' returned unsupported type #{value.class}"
      end
    end

    # Integral floats become integers so templates render `4` rather
    # than `4.0`; everything else (fractions, NaN, infinities, huge
    # values) stays a float.
    private def float_to_value(value : Float64) : Crinja::Value
      begin
        as_int = value.to_i64
      rescue ArgumentError
        return Crinja::Value.new(value)
      end
      value == as_int ? Crinja::Value.new(as_int) : Crinja::Value.new(value)
    end

    # A Lua table becomes an Array when its keys are exactly 1..n,
    # otherwise a String-keyed hash
    private def table_to_value(table : Lua::Table, filter_name : String)
      pairs = table.to_a

      all_integer_keys = pairs.all? do |pair|
        key, _value = pair
        key.is_a?(Float64) && key == key.to_i64
      end

      if all_integer_keys &&
         pairs.map { |pair| pair[0].as(Float64).to_i64 }.sort! == (1..pairs.size).to_a
        ordered = pairs.sort_by { |pair| pair[0].as(Float64) }
        ordered.map { |pair| from_lua_value(pair[1], filter_name) }
      else
        converted = {} of String => Crinja::Value
        pairs.each do |pair|
          key, item = pair
          converted[dict_key(Crinja::Value.new(key))] = from_lua_value(item, filter_name)
        end
        converted
      end
    end

    # Names exported by all scripts combined
    def filter_names : Array(String)
      ensure_built
      @functions.keys.sort!
    end

    # Call Lua function *filter_name* as `f(target, *extra_args)` and
    # convert the first return value back to a Crinja value
    def call_function(filter_name : String, target : Crinja::Value, extra_args : Array(Crinja::Value)) : Crinja::Value
      ensure_built
      function = @functions[filter_name]?
      unless function
        available = @functions.keys.sort!.join(", ")
        raise "Lua filter '#{filter_name}' not found. Available: #{available}"
      end

      lua_args = ([target] + extra_args).map { |value| to_lua_arg(value) }
      caller_function = @caller
      unless caller_function
        raise "Lua state not fully initialized"
      end
      result = caller_function.call(filter_name, lua_args)
      # Multiple return values: only the first crosses back over
      result = result.first if result.is_a?(Array)
      from_lua_value(result, filter_name)
    rescue ex : Lua::LuaError
      raise "Lua filter '#{filter_name}' failed: #{ex.message}"
    end

    # Destroy the Lua state.
    def close : Nil
      stack = @stack
      stack.close if stack && !stack.closed?
      @stack = nil
      @caller = nil
      @functions.clear
    end

    # Orphaned States (dropped transient environments) release their C
    # resources instead of leaking them to process exit
    def finalize
      close
    rescue
      # A finalizer must never raise
    end

    # Build or rebuild if Croupier reported any script modified since
    # our last build
    private def ensure_built : Nil
      return if @stack && !scripts_changed_since_build?
      rebuild
    end

    # Edge-triggered check: each detection of a modified path fires
    # once, then stays quiet until Croupier stops reporting the path
    # (next cycle recomputes the set) or reports it again. Without the
    # edge trigger we would rebuild on every single filter call, since
    # Croupier's modified set persists through a whole run.
    # Internal (exercised by specs); not part of the public API.
    def scripts_changed_since_build? : Bool
      paths = @paths
      return false unless paths

      changed = false
      paths.each do |path|
        if Croupier::TaskManager.modified?(path)
          changed = true unless @handled_modified.includes?(path)
          @handled_modified.add(path)
        else
          @handled_modified.delete(path)
        end
      end
      changed
    end

    private def rebuild : Nil
      close
      paths = @explicit_paths || LuaFilters.script_paths
      return if paths.empty?

      stack = Lua::Stack.new
      @stack = stack
      @paths = paths
      load_scripts(stack, paths)
      caller_value = stack.run(CALLER_SOURCE, "nicolino_caller")
      unless caller_value.is_a?(Lua::Function)
        raise "Failed to define Lua caller trampoline"
      end
      @caller = caller_value
    end

    # Load every script into *stack*, collecting exported functions
    private def load_scripts(stack : Lua::Stack, paths : Array(String)) : Nil
      paths.each do |path|
        source = File.read(path)
        begin
          exports = stack.run(source, path)
        rescue ex : Lua::SyntaxError
          # Lua elides long chunk names in messages; re-raise with the
          # full path so users can find the broken file
          raise "Lua syntax error in #{path}: #{ex.message}"
        end
        unless exports.is_a?(Lua::Table)
          kind = exports.nil? ? "nothing" : "a #{exports.class}"
          raise "Lua script #{path} must return a table of functions, got #{kind}"
        end
        exports.each do |key, entry|
          unless key.is_a?(String)
            raise "Lua script #{path}: filter names must be strings, got #{key.class}"
          end
          unless entry.is_a?(Lua::Function)
            raise "Lua script #{path}: export '#{key}' is #{entry.class}, expected function"
          end
          if @functions.has_key?(key)
            Log.warn { "Lua filter '#{key}' redefined by #{path}, overriding" }
          end
          @functions[key] = entry
          export_to_global(stack, key, entry)
        end
        Log.debug { "Loaded Lua filters from #{path}" }
      end
    end

    # Copy an exported function to a hidden global so the caller
    # trampoline can find it by name (lua.cr's high-level API cannot
    # push function handles back into the interpreter)
    private def export_to_global(stack : Lua::Stack, name : String, function : Lua::Function) : Nil
      reference = function.ref
      unless reference
        raise "Lua filter '#{name}' lost its registry reference"
      end
      stack.rawgeti(reference)
      LibLua.setglobal(stack.state, "__nicolino_fn_#{name}")
    end
  end
end
