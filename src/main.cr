require "./nicolino"
require "colorize"
require "commander"
require "progress_bar"
require "rucksack"

# Log wrapper
struct LogFormat < Log::StaticFormatter
  @@colors = {
    "FATAL" => :red,
    "ERROR" => :red,
    "WARN"  => :yellow,
    "INFO"  => :green,
    "DEBUG" => :blue,
    "TRACE" => :light_blue,
  }

  def run
    string "[#{Time.local}] #{@entry.severity.label}: #{@entry.message}".colorize(@@colors[@entry.severity.label])
  end

  def self.setup(quiet : Bool, progress : Bool, verbosity)
    Colorize.on_tty_only!
    if quiet
      _verbosity = Log::Severity::Fatal
    elsif progress
      _verbosity = Log::Severity::Error
      theme = Progress::Theme.new(
        complete: "-",
        incomplete: "•".colorize(:blue).to_s,
        progress_head: "C".colorize(:yellow).to_s,
        alt_progress_head: "c".colorize(:yellow).to_s
      )
      bar = Progress::Bar.new(theme: theme)
      done = 0
      Croupier::TaskManager.progress_callback = ->(_id : String) {
        done += 1
        new_tick = ((done*100)/Croupier::TaskManager.tasks.size).to_i
        bar.tick(new_tick - bar.current)
      }
    else
      _verbosity = [
        Log::Severity::Fatal,
        Log::Severity::Error,
        Log::Severity::Warn,
        Log::Severity::Info,
        Log::Severity::Debug,
        Log::Severity::Trace,
      ][[verbosity, 5].min]
    end
    Log.setup(
      _verbosity,
      Log::IOBackend.new(io: STDERR, formatter: LogFormat)
    )
  end
end

cli = Commander::Command.new do |cmd|
  cmd.use = "nicolino"
  cmd.long = "nicolino builds websites from markdown files."

  cmd.flags.add do |flag|
    flag.name = "parallel"
    flag.short = "-p"
    flag.long = "--parallel"
    flag.default = false
    flag.description = "Run tasks in parallel."
    flag.persistent = false
  end

  cmd.flags.add do |flag|
    flag.name = "config"
    flag.short = "-c"
    flag.long = "--config"
    flag.default = "conf.yml"
    flag.description = "Specify a config file to use."
    flag.persistent = true
  end

  cmd.flags.add do |flag|
    flag.name = "quiet"
    flag.short = "-q"
    flag.long = "--quiet"
    flag.description = "Don't log anything"
    flag.default = false
    flag.persistent = true
  end

  cmd.flags.add do |flag|
    flag.name = "verbosity"
    flag.short = "-v"
    flag.long = "--verbosity"
    flag.description = "Control the logging verbosity, 0 to 5"
    flag.default = 3
    flag.persistent = true
  end

  cmd.flags.add do |flag|
    flag.name = "progress"
    flag.long = "--progress"
    flag.description = "Show a progress bar instead of messages"
    flag.default = false
    flag.persistent = true
  end

  cmd.flags.add do |flag|
    flag.name = "fastmode"
    flag.long = "--fast-mode"
    flag.description = "Use file timestamps rather than contents to decide rebuilds"
    flag.default = false
    flag.persistent = false
  end

  cmd.flags.add do |flag|
    flag.name = "keep_going"
    flag.short = "-k"
    flag.long = "--keep-going"
    flag.description = "Keep going when a task fails"
    flag.default = false
    flag.persistent = false
  end

  cmd.flags.add do |flag|
    flag.name = "dry_run"
    flag.short = "-n"
    flag.long = "--dry-run"
    flag.description = "Dry run: don't actually do anything"
    flag.default = false
    flag.persistent = false
  end

  cmd.flags.add do |flag|
    flag.name = "run_all"
    flag.short = "-B"
    flag.long = "--run-all"
    flag.description = "Run all tasks, even up-to-date ones"
    flag.default = false
    flag.persistent = false
  end

  cmd.run do |options, arguments|
    begin
      LogFormat.setup(options.@bool["quiet"], options.@bool["progress"], options.@int["verbosity"])
      exit(run(options, arguments))
    rescue ex
      Log.error { ex.message }
      Log.debug { ex.backtrace.join("\n") }
      exit(1)
    end
  end

  cmd.commands.add do |command|
    command.use = "auto"
    command.short = "Run in auto mode"
    command.long = "Run in auto mode, monitoring files for changes"
    command.run do |options, arguments|
      LogFormat.setup(options.@bool["quiet"], options.@bool["progress"], options.@int["verbosity"])
      auto(options, arguments)
    end
  end

  cmd.commands.add do |command|
    command.use = "serve"
    command.short = "Serve the site over HTTP"
    command.long = "Serve the site over HTTP"
    command.run do |options, arguments|
      LogFormat.setup(options.@bool["quiet"], options.@bool["progress"], options.@int["verbosity"])
      serve(options, arguments)
    end
  end

  cmd.commands.add do |command|
    command.use = "clean"
    command.short = "Clean unknown files"
    command.long = "Remove unknown files from output"
    command.run do |options, arguments|
      LogFormat.setup(options.@bool["quiet"], options.@bool["progress"], options.@int["verbosity"])
      clean(options, arguments)
    end
  end

  cmd.commands.add do |command|
    command.use = "init"
    command.short = "Create a new site"
    command.long = "Create a new site"
    command.run do |options, _|
      LogFormat.setup(options.@bool["quiet"], options.@bool["progress"], options.@int["verbosity"])
      {% for name in %(conf.yml
          templates/title.tmpl
          templates/gallery.tmpl
          templates/taxonomy.tmpl
          templates/index.tmpl
          templates/post.tmpl
          templates/page.tmpl
          templates/folder_index.tmpl
          shortcodes/raw.tmpl
          shortcodes/figure.tmpl
          assets/css/custom.css
          assets/favicon.ico).lines.map(&.strip) %}
        FileUtils.mkdir_p(File.dirname({{name}}))
        Log.info { "👉 Creating #{{{name}}}" }
        File.open({{name}}, "w") { |f|
          rucksack({{name}}).read(f)
        }
      {% end %}
      FileUtils.mkdir_p("posts")
      FileUtils.mkdir_p("pages")
      Log.info { "✔️ Done, start writing things in posts and pages!" }
    end
  end

  cmd.commands.add do |command|
    command.use = "new"
    command.short = "Create new content"
    command.run do |options, arguments|
      LogFormat.setup(options.@bool["quiet"], options.@bool["progress"], options.@int["verbosity"])
      new(options, arguments)
    end
  end

  cmd.commands.add do |command|
    command.use = "validate"
    command.short = "Validate existing content"
    command.run do |options, arguments|
      LogFormat.setup(options.@bool["quiet"], options.@bool["progress"], options.@int["verbosity"])
      validate(options, arguments)
    end
  end
end

Commander.run(cli, ARGV)
