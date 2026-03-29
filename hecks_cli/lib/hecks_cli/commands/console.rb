Hecks::CLI.register_command(:console, "Start the interactive workbench",
  args: ["NAME"]
) do |name = nil|
  Hecks::Workbench::ConsoleRunner.new(name: name).run
end
