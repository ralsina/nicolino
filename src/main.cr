require "commander"

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

  cmd.run do |options, arguments|
    options.bool["parallel"]
    run(options, arguments)
  end
end

Commander.run(cli, ARGV)
