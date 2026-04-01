require_relative "../import"

# Hecks CLI — extract command
#
# Auto-detects a project's type and generates a Hecks domain DSL file.
# Supports Rails apps (schema.rb), Rails models-only, and any Ruby
# project (POROs, Structs, Data.define classes).
#
#   hecks extract /path/to/rails/app
#   hecks extract /path/to/ruby/gem --preview --name Billing
#
Hecks::CLI.register_command(:extract, "Extract a domain from an existing project",
  args: %w[PATH],
  options: {
    output:  { type: :string, default: "Bluebook", desc: "Output file path", aliases: "-o" },
    preview: { type: :boolean, default: false, desc: "Preview without writing" },
    name:    { type: :string, desc: "Domain name (default: inferred from directory)" }
  }
) do |path = nil|
  unless path
    puts "Usage: hecks extract /path/to/project"
    puts "       hecks extract /path/to/project --preview --name Blog"
    next
  end

  unless File.directory?(path)
    puts "Error: #{path} is not a directory"
    next
  end

  project_type = if Hecks::Import.rails_project?(path)
                   "Rails (schema.rb + models)"
                 elsif Hecks::Import.rails_models?(path)
                   "Rails (models only)"
                 else
                   "Ruby project"
                 end
  puts "Detected: #{project_type}"
  puts ""

  dsl = Hecks::Import.from_directory(path, domain_name: options[:name])
  puts dsl

  unless options[:preview]
    output = options[:output] || "Bluebook"
    File.write(output, dsl)
    puts "\nWritten to #{output}"
  end
end
