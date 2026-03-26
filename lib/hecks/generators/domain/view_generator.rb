# Hecks::Generators::Domain::ViewGenerator
#
# Generates CQRS view (read model) classes that subscribe to domain events
# and maintain projected state. Implements call for uniform interface.
# Part of Generators::Domain.
#
#   gen = ViewGenerator.new(view, domain_module: "ComplianceDomain")
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class ViewGenerator

      def initialize(view, domain_module:)
        @view = view
        @domain_module = domain_module
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Views"
        lines << "    class #{@view.name}"
        projections = @view.projections.is_a?(Hash) ? @view.projections : @view.projections.to_h { |p| [p[:event_name], p[:block]] }
        proj_names = projections.keys
        lines << "      PROJECTIONS = %w[#{proj_names.join(' ')}].freeze unless defined?(PROJECTIONS)"
        lines << ""
        lines << "      attr_reader :state"
        lines << ""
        lines << "      def call(event, state = {})"
        lines << "        name = event.class.name.split('::').last"
        lines << "        method = :\"project_\#{Hecks::Utils.underscore(name)}\""
        lines << "        @state = respond_to?(method) ? send(method, event, state) : state"
        lines << "        self"
        lines << "      end"
        projections.each do |event_name, block|
          method_name = Hecks::Utils.underscore(event_name)
          body = Hecks::Utils.block_source(block)
          lines << ""
          lines << "      def project_#{method_name}(event, state)"
          lines << "        #{body}"
          lines << "      end"
        end
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end
    end
    end
  end
end
