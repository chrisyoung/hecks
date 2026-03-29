Hecks::CLI.register_command(:console, "Start the interactive workshop", group: "Core",
  args: ["NAME"]
) do |name = nil|
  Hecks::Workshop::ConsoleRunner.new(name: name).run
end
