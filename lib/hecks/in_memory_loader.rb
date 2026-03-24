# Hecks::InMemoryLoader
#
# Fast domain loading without disk I/O. Generates source strings from each
# generator and compiles them in memory with virtual filenames for stack
# traces. Injected by Hecks::TestHelper to keep tests fast. Production
# code uses the file-based path in DomainCompiler instead.
#
#   Hecks.load_strategy = :memory
#   Hecks.load_domain(domain)  # uses InMemoryLoader
#
module Hecks
  module InMemoryLoader
    def self.load(domain, mod)
      gem = domain.gem_name
      load_src(module_shell(mod), "#{gem}.rb")

      domain.aggregates.each do |agg|
        safe = Hecks::Utils.sanitize_constant(agg.name)
        snake = Hecks::Utils.underscore(safe)
        opts = { domain_module: mod }
        base = "#{gem}/#{snake}"

        # Ports before adapters — adapters include port modules
        load_src(gen(Generators::Infrastructure::PortGenerator, agg, **opts), "#{gem}/ports/#{snake}_repository.rb")
        load_src(gen(Generators::Infrastructure::MemoryAdapterGenerator, agg, **opts), "#{gem}/adapters/#{snake}_memory_adapter.rb")
        load_src(gen(Generators::Domain::AggregateGenerator, agg, **opts), "#{base}/#{snake}.rb")

        agg.value_objects.each { |vo| load_src(gen(Generators::Domain::ValueObjectGenerator, vo, aggregate_name: safe, **opts), "#{base}/#{Hecks::Utils.underscore(vo.name)}.rb") }
        agg.entities.each { |ent| load_src(gen(Generators::Domain::EntityGenerator, ent, aggregate_name: safe, **opts), "#{base}/#{Hecks::Utils.underscore(ent.name)}.rb") }
        agg.events.each { |evt| load_src(gen(Generators::Domain::EventGenerator, evt, aggregate_name: safe, **opts), "#{base}/events/#{Hecks::Utils.underscore(evt.name)}.rb") }
        agg.policies.each { |pol| load_src(gen(Generators::Domain::PolicyGenerator, pol, aggregate_name: safe, **opts), "#{base}/policies/#{Hecks::Utils.underscore(pol.name)}.rb") }
        agg.subscribers.each { |sub| load_src(gen(Generators::Domain::SubscriberGenerator, sub, aggregate_name: safe, **opts), "#{base}/subscribers/#{Hecks::Utils.underscore(sub.name)}.rb") }
        load_specifications(agg, safe, opts, base)
        load_commands(agg, safe, opts, base)
        load_queries(agg, safe, opts, base)
      end
    end

    def self.load_specifications(agg, safe, opts, base)
      agg.specifications.each do |spec|
        src = gen(Generators::Domain::SpecificationGenerator, spec, aggregate_name: safe, **opts)
        load_src(inject_mixin(src, spec.name, "Hecks::Specification"), "#{base}/specifications/#{Hecks::Utils.underscore(spec.name)}.rb")
      end
    end

    def self.load_commands(agg, safe, opts, base)
      agg.commands.each_with_index do |cmd, i|
        src = gen(Generators::Domain::CommandGenerator, cmd, aggregate_name: safe, aggregate: agg, event: agg.events[i], **opts)
        load_src(inject_mixin(src, cmd.name, "Hecks::Command"), "#{base}/commands/#{Hecks::Utils.underscore(cmd.name)}.rb")
      end
    end

    def self.load_queries(agg, safe, opts, base)
      agg.queries.each do |q|
        src = gen(Generators::Domain::QueryGenerator, q, aggregate_name: safe, **opts)
        load_src(inject_mixin(src, q.name, "Hecks::Query"), "#{base}/queries/#{Hecks::Utils.underscore(q.name)}.rb")
      end
    end

    def self.module_shell(mod)
      "require 'securerandom'\nmodule #{mod}\n  class ValidationError < StandardError; end\n  class InvariantError < StandardError; end\nend"
    end

    def self.gen(klass, obj, **opts) = klass.new(obj, **opts).generate

    def self.load_src(source, virtual_path)
      RubyVM::InstructionSequence.compile(source, virtual_path).eval
    end

    def self.inject_mixin(source, class_name, mixin)
      source.sub("class #{class_name}\n", "class #{class_name}\n        include #{mixin}\n")
    end
  end
end
