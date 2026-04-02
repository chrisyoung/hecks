require "hecks/generators/built_in"

module Hecks
  # Hecks::InMemoryLoader
  #
  # Fast domain loading without disk I/O. Uses the generator registry
  # to discover and run generators, then evals the output in memory.
  #
  #   InMemoryLoader.load(domain, "PizzasDomain")
  #
  module InMemoryLoader
    extend HecksTemplating::NamingHelpers

    def self.load(domain, mod)
      gem = domain.gem_name
      load_src(module_shell(mod, domain.version), "#{gem}.rb")

      # Load shared kernel type aliases
      load_kernel_aliases(domain, mod)

      domain.aggregates.each do |agg|
        safe = domain_constant_name(agg.name)
        snake = domain_snake_name(safe)
        opts = { domain_module: mod }
        base = "#{gem}/#{snake}"

        # Aggregate-scope generators
        Generators.for(:aggregate).each do |g|
          if g[:name] == :lifecycle
            next unless agg.lifecycle
            load_src(gen(g[:klass], agg.lifecycle, aggregate_name: safe, **opts), "#{base}/lifecycle.rb")
          else
            load_src(gen(g[:klass], agg, **opts), "#{base}/#{g[:name]}.rb")
          end
        end

        # Child-scope generators (iterate collections)
        Generators.for(:child).each do |g|
          collection = agg.send(g[:source])
          collection.each_with_index do |item, i|
            extra = child_extra_opts(g, agg, item, i, safe)
            src = gen(g[:klass], item, aggregate_name: safe, **extra, **opts)
            src = inject_mixin(src, item.name, g[:mixin]) if g[:mixin]
            path = "#{base}/#{g[:source]}/#{domain_snake_name(item.name)}.rb"
            load_src(src, path)
          end
        end
      end

      # Domain-scope generators
      Generators.for(:domain).each do |g|
        domain.send(g[:source]).each do |item|
          src = g[:klass].new(item, domain_module: mod).generate
          load_src(src, "#{gem}/#{g[:source]}/#{domain_snake_name(item.name)}.rb")
        end
      end
    end

    # Extra opts needed by specific generators (commands need aggregate + event)
    def self.child_extra_opts(g, agg, item, index, safe)
      if g[:name] == :command
        { aggregate: agg, event: agg.events[index] }
      else
        {}
      end
    end

    def self.module_shell(mod, version = nil)
      version_line = version ? "  VERSION = #{version.inspect}\n  def self.version; VERSION; end\n" : ""
      "require 'securerandom'\nmodule #{mod}\n" \
      "#{version_line}" \
      "  class ValidationError < StandardError\n" \
      "    attr_reader :field, :rule\n" \
      "    def initialize(message = nil, field: nil, rule: nil)\n" \
      "      @field = field; @rule = rule; super(message)\n" \
      "    end\n" \
      "  end\n" \
      "  class InvariantError < StandardError; end\n" \
      "end"
    end

    def self.gen(klass, obj, **opts) = klass.new(obj, **opts).generate

    def self.load_src(source, virtual_path)
      RubyVM::InstructionSequence.compile(source, virtual_path).eval
    end

    # Loads type aliases from shared kernel domains into the consuming
    # domain module. Each kernel value object becomes a constant alias.
    def self.load_kernel_aliases(domain, mod)
      return unless domain.respond_to?(:uses_kernels)
      (domain.uses_kernels || []).each do |kernel_name|
        kernel_domain = Hecks::SharedKernelRegistry.lookup(kernel_name)
        next unless kernel_domain
        kernel_mod = Hecks::Utils.sanitize_constant(kernel_name) + "Domain"
        kernel_domain.aggregates.each do |agg|
          agg_name = domain_constant_name(agg.name)
          agg.value_objects.each do |vo|
            fqn = "#{kernel_mod}::#{agg_name}::#{vo.name}"
            alias_src = "module #{mod}\n  #{vo.name} = #{fqn} if defined?(#{fqn})\nend"
            load_src(alias_src, "#{domain.gem_name}/kernels/#{domain_snake_name(vo.name)}.rb")
          end
        end
      end
    end

    def self.inject_mixin(source, class_name, mixin)
      source.sub("class #{class_name}\n", "class #{class_name}\n        include #{mixin}\n")
    end
  end
end
