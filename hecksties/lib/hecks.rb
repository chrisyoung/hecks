require "json"
require "date"
require "ostruct"

JSON::Validator.use_multi_json = false if defined?(JSON::Validator)

require_relative "hecks/errors"
require_relative "hecks/autoloads"

# Default modules — loaded with require "hecks"
require "hecks_contracts"
require "hecks_templating"
require "hecks/domain/inspector"
require "hecks/domain/builder_methods"
require "hecks/domain/compiler"
require "hecks/domain/in_memory_loader"
require "hecks/domain/event_storm_importer"
require "hecks/domain/visualizer_methods"
require "hecks/runtime/boot"
require "hecks/workshop"

# Registries
require_relative "hecks/registries/extension_registry"
require_relative "hecks/registries/domain_registry"
require_relative "hecks/registries/cross_domain"
require_relative "hecks/registries/thread_context"
require_relative "hecks/registries/target_registry"
require_relative "hecks/registries/adapter_registry"
require_relative "hecks/registries/validation_registry"
require_relative "hecks/registries/dump_format_registry"

# = Hecks
#
# Top-level entry point. Modules load lazily — require only what you use.
#
#   require "hecks"                  # core DSL + registries
#   require "hecks_contracts"        # data contracts
#   require "hecks_multidomain"      # multi-domain boot + filtered bus
#   require "hecks_explorer"         # web explorer + HTTP server
#   require "hecks_ai"               # MCP server + AI tools
#
module Hecks
  extend DomainInspector
  extend DomainBuilderMethods
  extend DomainCompiler
  extend EventStormImporter
  extend DomainVisualizerMethods
  extend Boot
  extend ExtensionRegistryMethods
  extend DomainRegistryMethods
  extend CrossDomainMethods
  extend ThreadContextMethods
  extend TargetRegistryMethods
  extend AdapterRegistryMethods
  extend ValidationRegistryMethods
  extend DumpFormatRegistryMethods

  @configuration = nil
  @loaded_domains = {}
  @domain_objects = {}
  @last_domain = nil
  @load_strategy = :memory
  @extension_registry = {}
  @extension_meta = {}
  @cross_domain_queries = {}
  @cross_domain_views = {}
  @target_registry = {}
  @adapter_registry = %i[memory sqlite postgres mysql mysql2 filesystem filesystem_store]
  @validation_rules = []
  @dump_format_registry = {}

  def self.configure(&block)
    @configuration = Configuration.new
    @configuration.instance_eval(&block)
    @configuration.boot! unless defined?(::Rails)
    @configuration
  end

  def self.configuration
    @configuration
  end

  def self.load(domain, force: false, **opts, &config)
    load_domain(domain, force: force)
    Runtime.new(domain, **opts, &config)
  end

  # Built-in build targets
  register_target(:ruby) { |domain, **opts| Hecks.build(domain, **opts) }
  register_target(:static) { |domain, **opts| Hecks.build_static(domain, **opts) }
  register_target(:go) { |domain, **opts| Hecks.build_go(domain, **opts) }
  register_target(:rails) { |domain, **opts| Hecks.build_rails(domain, **opts) }

  # Built-in dump formats
  register_dump_format(:schema, desc: "JSON Schema") { |domain, say:| require "hecks_serve"; File.write("schema.json", JSON.pretty_generate(Hecks::HTTP::JsonSchemaGenerator.new(domain).generate)); say.call("Dumped schema.json", :green) }
  register_dump_format(:swagger, desc: "OpenAPI 3.0") { |domain, say:| require "hecks_serve"; File.write("openapi.json", JSON.pretty_generate(Hecks::HTTP::OpenapiGenerator.new(domain).generate)); say.call("Dumped openapi.json", :green) }
  register_dump_format(:rpc, desc: "JSON-RPC discovery") { |domain, say:| require "hecks_serve"; File.write("rpc_methods.json", JSON.pretty_generate(Hecks::HTTP::RpcDiscovery.new(domain).generate)); say.call("Dumped rpc_methods.json", :green) }
  register_dump_format(:domain, desc: "domain gem") { |domain, say:| FileUtils.mkdir_p("domain"); say.call("Dumped domain gem to domain/#{File.basename(Hecks.build(domain, output_dir: "domain"))}/", :green) }
  register_dump_format(:glossary, desc: "plain-English glossary") { |domain, say:| File.write("glossary.md", Hecks::DomainGlossary.new(domain).generate.join("\n") + "\n"); say.call("Dumped glossary.md", :green) }

  if defined?(::Rails::Railtie)
    begin
      require "active_hecks/railtie"
    rescue LoadError
    end
  end
end

# Sub-gems load lazily — only when required
# require "hecks_contracts"    # loads contracts + registers them
# require "hecks_templating"   # loads naming helpers
# require "hecks_multidomain"  # loads multi-domain support
# require "hecks_explorer"     # loads web explorer
# require "hecks_ai"           # loads MCP server
