require_relative "../import"

Hecks::CLI.register_command(:import, "Import a Rails app as a Hecks domain",
  args: %w[SOURCE PATH],
  options: {
    output: { type: :string, default: "hecks_domain.rb", desc: "Output file path", aliases: "-o" },
    preview: { type: :boolean, default: false, desc: "Preview without writing" },
    name: { type: :string, desc: "Domain name (default: inferred from directory)" }
  }
) do |source = nil, path = nil|
  unless source && path
    puts "Usage: hecks import rails /path/to/app"
    puts "       hecks import schema /path/to/schema.rb"
    next
  end

  dsl = case source
        when "rails"
          Hecks::Import.from_rails(path, domain_name: options[:name])
        when "schema"
          Hecks::Import.from_schema(path, domain_name: options[:name] || "MyDomain")
        else
          puts "Unknown source: #{source}. Use 'rails' or 'schema'."
          next
        end

  puts dsl
  unless options[:preview]
    output = options[:output] || "hecks_domain.rb"
    File.write(output, dsl)
    puts "\nWritten to #{output}"
  end
end
