module Hecks
  # Hecks::InMemoryLoader
  #
  # Fast domain loading without disk I/O. Generates source strings from each
  # generator and compiles them in memory with virtual filenames for stack
  # traces. This is the default loading strategy used by DomainCompiler#load_domain.
  #
  # The loader orchestrates all domain generators in dependency order:
  # 1. Module shell (top-level constant with error classes)
  # 2. Ports (repository interfaces)
  # 3. Memory adapters (default in-memory persistence)
  # 4. Aggregate root classes
  # 5. Value objects and entities
  # 6. Events, policies, subscribers
  # 7. Specifications, commands, queries (with mixin injection)
  # 8. Workflows, views, services
  #
  # Commands, queries, and specifications get their respective mixins
  # (Hecks::Command, Hecks::Query, Hecks::Specification) injected via
  # source-level string manipulation before compilation.
  #
  #   InMemoryLoader.load(domain, "PizzasDomain")
  #   # => defines PizzasDomain module with all aggregate classes
  #
  module InMemoryLoader
    # Load an entire domain into memory by generating and evaluating source
    # code for all domain components. Creates the top-level module constant
    # (e.g., PizzasDomain) and all nested classes.
    #
    # @param domain [Hecks::DomainModel::Domain] the domain IR to load
    # @param mod [String] the module name to define (e.g., "PizzasDomain")
    # @return [void]
    def self.load(domain, mod)
      gem = domain.gem_name
      load_src(module_shell(mod), "#{gem}.rb")

      domain.aggregates.each do |agg|
        safe = Hecks::Templating::Names.domain_constant_name(agg.name)
        snake = Hecks::Templating::Names.domain_snake_name(safe)
        opts = { domain_module: mod }
        base = "#{gem}/#{snake}"

        # Ports before adapters — adapters include port modules
        load_src(gen(Generators::Infrastructure::PortGenerator, agg, **opts), "#{gem}/ports/#{snake}_repository.rb")
        load_src(gen(Generators::Infrastructure::MemoryAdapterGenerator, agg, **opts), "#{gem}/adapters/#{snake}_memory_adapter.rb")
        load_src(gen(Generators::Domain::AggregateGenerator, agg, **opts), "#{base}/#{snake}.rb")

        agg.value_objects.each { |vo| load_src(gen(Generators::Domain::ValueObjectGenerator, vo, aggregate_name: safe, **opts), "#{base}/#{Hecks::Templating::Names.domain_snake_name(vo.name)}.rb") }
        agg.entities.each { |ent| load_src(gen(Generators::Domain::EntityGenerator, ent, aggregate_name: safe, **opts), "#{base}/#{Hecks::Templating::Names.domain_snake_name(ent.name)}.rb") }
        agg.events.each { |evt| load_src(gen(Generators::Domain::EventGenerator, evt, aggregate_name: safe, **opts), "#{base}/events/#{Hecks::Templating::Names.domain_snake_name(evt.name)}.rb") }
        agg.policies.each { |pol| load_src(gen(Generators::Domain::PolicyGenerator, pol, aggregate_name: safe, **opts), "#{base}/policies/#{Hecks::Templating::Names.domain_snake_name(pol.name)}.rb") }
        agg.subscribers.each { |sub| load_src(gen(Generators::Domain::SubscriberGenerator, sub, aggregate_name: safe, **opts), "#{base}/subscribers/#{Hecks::Templating::Names.domain_snake_name(sub.name)}.rb") }
        load_specifications(agg, safe, opts, base)
        load_commands(agg, safe, opts, base)
        load_queries(agg, safe, opts, base)
      end

      load_workflows(domain, mod, gem)
      load_views(domain, mod, gem)
      load_services(domain, mod, gem)
    end

    # Load all specification classes for an aggregate, injecting the
    # Hecks::Specification mixin into each generated class.
    #
    # @param agg [Hecks::DomainModel::Aggregate] the aggregate owning the specs
    # @param safe [String] sanitized aggregate constant name
    # @param opts [Hash] generator options including :domain_module
    # @param base [String] virtual path prefix for stack traces
    # @return [void]
    def self.load_specifications(agg, safe, opts, base)
      agg.specifications.each do |spec|
        src = gen(Generators::Domain::SpecificationGenerator, spec, aggregate_name: safe, **opts)
        load_src(inject_mixin(src, spec.name, "Hecks::Specification"), "#{base}/specifications/#{Hecks::Templating::Names.domain_snake_name(spec.name)}.rb")
      end
    end

    # Load all command classes for an aggregate, injecting the
    # Hecks::Command mixin. Each command is paired with its corresponding
    # event by index (commands[i] produces events[i]).
    #
    # @param agg [Hecks::DomainModel::Aggregate] the aggregate owning the commands
    # @param safe [String] sanitized aggregate constant name
    # @param opts [Hash] generator options including :domain_module
    # @param base [String] virtual path prefix for stack traces
    # @return [void]
    def self.load_commands(agg, safe, opts, base)
      agg.commands.each_with_index do |cmd, i|
        src = gen(Generators::Domain::CommandGenerator, cmd, aggregate_name: safe, aggregate: agg, event: agg.events[i], **opts)
        load_src(inject_mixin(src, cmd.name, "Hecks::Command"), "#{base}/commands/#{Hecks::Templating::Names.domain_snake_name(cmd.name)}.rb")
      end
    end

    # Load all query classes for an aggregate, injecting the
    # Hecks::Query mixin into each generated class.
    #
    # @param agg [Hecks::DomainModel::Aggregate] the aggregate owning the queries
    # @param safe [String] sanitized aggregate constant name
    # @param opts [Hash] generator options including :domain_module
    # @param base [String] virtual path prefix for stack traces
    # @return [void]
    def self.load_queries(agg, safe, opts, base)
      agg.queries.each do |q|
        src = gen(Generators::Domain::QueryGenerator, q, aggregate_name: safe, **opts)
        load_src(inject_mixin(src, q.name, "Hecks::Query"), "#{base}/queries/#{Hecks::Templating::Names.domain_snake_name(q.name)}.rb")
      end
    end

    # Load all workflow classes for a domain.
    #
    # @param domain [Hecks::DomainModel::Domain] the domain containing workflows
    # @param mod [String] the domain module name
    # @param gem [String] the gem name for virtual path prefixes
    # @return [void]
    def self.load_workflows(domain, mod, gem)
      domain.workflows.each do |wf|
        src = Generators::Domain::WorkflowGenerator.new(wf, domain_module: mod).generate
        load_src(src, "#{gem}/workflows/#{Hecks::Templating::Names.domain_snake_name(wf.name)}.rb")
      end
    end

    # Load all view classes for a domain.
    #
    # @param domain [Hecks::DomainModel::Domain] the domain containing views
    # @param mod [String] the domain module name
    # @param gem [String] the gem name for virtual path prefixes
    # @return [void]
    def self.load_views(domain, mod, gem)
      domain.views.each do |v|
        src = Generators::Domain::ViewGenerator.new(v, domain_module: mod).generate
        load_src(src, "#{gem}/views/#{Hecks::Templating::Names.domain_snake_name(v.name)}.rb")
      end
    end

    # Load all service classes for a domain.
    #
    # @param domain [Hecks::DomainModel::Domain] the domain containing services
    # @param mod [String] the domain module name
    # @param gem [String] the gem name for virtual path prefixes
    # @return [void]
    def self.load_services(domain, mod, gem)
      domain.services.each do |svc|
        src = Generators::Domain::ServiceGenerator.new(svc, domain_module: mod).generate
        load_src(src, "#{gem}/services/#{Hecks::Templating::Names.domain_snake_name(svc.name)}.rb")
      end
    end

    # Generate the top-level module shell source. Defines the domain module
    # constant with standard error classes (ValidationError, InvariantError)
    # and requires securerandom for UUID generation.
    #
    # @param mod [String] the module name (e.g., "PizzasDomain")
    # @return [String] Ruby source code for the module shell
    def self.module_shell(mod)
      "require 'securerandom'\nmodule #{mod}\n" \
      "  class ValidationError < StandardError\n" \
      "    attr_reader :field, :rule\n" \
      "    def initialize(message = nil, field: nil, rule: nil)\n" \
      "      @field = field; @rule = rule; super(message)\n" \
      "    end\n" \
      "  end\n" \
      "  class InvariantError < StandardError; end\n" \
      "end"
    end

    # Shorthand to instantiate a generator and call #generate.
    #
    # @param klass [Class] the generator class to instantiate
    # @param obj [Object] the domain IR object to pass to the generator
    # @param opts [Hash] keyword arguments forwarded to the generator constructor
    # @return [String] generated Ruby source code
    def self.gen(klass, obj, **opts) = klass.new(obj, **opts).generate

    # Compile a source string and evaluate it in the current binding.
    # Uses RubyVM::InstructionSequence for compilation with a virtual
    # filename that appears in stack traces for debugging.
    #
    # @param source [String] Ruby source code to compile and evaluate
    # @param virtual_path [String] filename for stack traces (e.g., "pizzas_domain/pizza/pizza.rb")
    # @return [Object] the result of evaluating the compiled source
    def self.load_src(source, virtual_path)
      RubyVM::InstructionSequence.compile(source, virtual_path).eval
    end

    # Inject a mixin include statement into generated source code by
    # inserting it immediately after the class definition line.
    #
    # @param source [String] the generated Ruby source code
    # @param class_name [String] the class name to find in the source
    # @param mixin [String] the fully qualified mixin name (e.g., "Hecks::Command")
    # @return [String] modified source with the include statement added
    def self.inject_mixin(source, class_name, mixin)
      source.sub("class #{class_name}\n", "class #{class_name}\n        include #{mixin}\n")
    end
  end
end
