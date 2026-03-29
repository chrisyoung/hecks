# Hecks::DumpFormatRegistryMethods
#
# Registry for dump/serialization formats. Each format (schema, swagger, rpc,
# domain, glossary) registers a callable that receives a domain and a say
# proc for output, then writes the appropriate file.
#
#   Hecks.register_dump_format(:schema, desc: "JSON Schema") do |domain, say:|
#     File.write("schema.json", JSON.pretty_generate(schema_data))
#     say.call("Dumped schema.json", :green)
#   end
#   Hecks.dump_formats  # => { schema: { desc: ..., handler: #<Proc> }, ... }
#
module Hecks
  module DumpFormatRegistryMethods
    def dump_formats
      @dump_format_registry
    end

    def register_dump_format(name, desc: name.to_s, &handler)
      @dump_format_registry[name.to_sym] = { desc: desc, handler: handler }
    end
  end
end
