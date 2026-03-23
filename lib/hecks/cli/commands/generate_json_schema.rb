# Hecks::CLI generate json_schema command
#
module Hecks
  class CLI < Thor
    desc "generate:json_schema", "Generate JSON Schema files from domain"
    map "generate:json_schema" => :generate_json_schema
    def generate_json_schema(domain_path = nil)
      domain = resolve_domain(domain_path)
      unless domain
        say "No domain found", :red
        return
      end

      require_relative "../../http/json_schema_generator"
      schemas = HTTP::JsonSchemaGenerator.new(domain).generate

      dir = "schemas"
      FileUtils.mkdir_p(dir)
      schemas.each do |name, schema|
        file = File.join(dir, "#{Hecks::Utils.underscore(name)}.json")
        File.write(file, JSON.pretty_generate(schema))
        say "  #{file}", :green
      end
      say "Generated #{schemas.size} schemas in #{dir}/", :green
    end
  end
end
