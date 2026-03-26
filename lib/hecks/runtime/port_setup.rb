# Hecks::Runtime::PortSetup
#
# Wires all five ports onto aggregate classes: repository (persistence),
# commands, queries, introspection, versioning, attachments, and port
# enforcement. Called once during Runtime initialization and again when
# an adapter is swapped.
#
#   class Runtime
#     include PortSetup
#   end
#
module Hecks
  class Runtime
    module PortSetup
      private

      def wire_ports!
        @domain.aggregates.each { |agg| wire_aggregate(agg) }
      end

      def wire_aggregate!(name)
        agg = @domain.aggregates.find { |a| a.name == name.to_s }
        wire_aggregate(agg) if agg
      end

      def wire_aggregate(agg)
        agg_class = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
        repo = @repositories[agg.name]
        defaults = build_defaults(agg)

        Persistence.bind(agg_class, agg, repo)
        Commands.bind(agg_class, agg, @command_bus, repo, defaults)
        Querying.bind(agg_class, agg)
        Introspection.bind(agg_class, agg)
        Versioning.bind(agg_class, repo) if agg.versioned?
        AttachmentMethods.bind(agg_class) if agg.attachable?
        wire_query_objects(agg, agg_class)
        PortEnforcer.new(port_name: @port_name).enforce!(agg, agg_class)
      end

      def build_defaults(agg)
        agg.attributes.each_with_object({}) { |attr, h| h[attr.name] = attr.list? ? [] : nil }
      end

      def wire_query_objects(agg, agg_class)
        repo = @repositories[agg.name]
        queries_mod = begin; agg_class.const_get(:Queries); rescue NameError; nil; end

        agg.queries.each do |query|
          method_name = Hecks::Utils.underscore(query.name).to_sym
          query_class = begin
            queries_mod&.const_defined?(query.name, false) && queries_mod.const_get(query.name)
          rescue StandardError
            nil
          end

          if query_class&.respond_to?(:repository=)
            query_class.repository = repo
            agg_class.define_singleton_method(method_name) { |*args| query_class.call(*args) }
          else
            query_block = query.block
            agg_class.define_singleton_method(method_name) do |*args|
              builder = Querying::QueryBuilder.new(repo)
              builder.instance_exec(*args, &query_block)
            end
          end
        end
      end
    end
  end
end
