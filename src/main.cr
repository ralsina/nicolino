require "./nicolino"
require "commander"
require "colorize"

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
    string "#{@entry.severity.label}: #{@entry.message}".colorize(@@colors[@entry.severity.label])
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
    flag.name = "fastmode"
    flag.long = "--fast-mode"
    flag.description = "Use file timestamps rather than contents to decide rebuilds"
    flag.default = false
    flag.persistent = true
  end

  cmd.flags.add do |flag|
    flag.name = "keep_going"
    flag.short = "-k"
    flag.long = "--keep-going"
    flag.description = "Keep going when a task fails"
    flag.default = false
    flag.persistent = true
  end

  cmd.flags.add do |flag|
    flag.name = "dry_run"
    flag.short = "-n"
    flag.long = "--dry-run"
    flag.description = "Dry run: don't actually do anything"
    flag.default = false
    flag.persistent = true
  end

  cmd.flags.add do |flag|
    flag.name = "run_all"
    flag.short = "-B"
    flag.long = "--run-all"
    flag.description = "Run all tasks, even up-to-date ones"
    flag.default = false
    flag.persistent = true
  end

  cmd.run do |options, arguments|
    if options.@bool["quiet"]
      verbosity = Log::Severity::Fatal
    else
      verbosity = [
        Log::Severity::Fatal,
        Log::Severity::Error,
        Log::Severity::Warn,
        Log::Severity::Info,
        Log::Severity::Debug,
        Log::Severity::Trace,
      ][[options.@int["verbosity"], 5].min]
    end
    Log.setup(
      verbosity,
      Log::IOBackend.new(io: STDERR, formatter: LogFormat)
    )
    options.bool["parallel"]
    run(options, arguments)
  end
end

Commander.run(cli, ARGV)
