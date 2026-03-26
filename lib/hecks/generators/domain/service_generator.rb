# Hecks::Generators::Domain::ServiceGenerator
#
# Generates domain service classes that orchestrate commands across
# aggregates. Each service has attributes, a call method, and returns
# self with results attached. Part of Generators::Domain.
#
#   gen = ServiceGenerator.new(service, domain_module: "ModelRegistryDomain")
#   gen.generate
#
module Hecks
  module Generators
    module Domain
    class ServiceGenerator

      def initialize(service, domain_module:)
        @service = service
        @domain_module = domain_module
      end

      def generate
        lines = []
        lines << "module #{@domain_module}"
        lines << "  module Services"
        lines << "    class #{@service.name}"
        attrs = @service.attributes
        unless attrs.empty?
          lines << "      attr_reader #{attrs.map { |a| ":#{a.name}" }.join(', ')}, :results"
          lines << ""
          params = attrs.map { |a| "#{a.name}:" }.join(", ")
          lines << "      def initialize(#{params})"
          attrs.each { |a| lines << "        @#{a.name} = #{a.name}" }
          lines << "        @results = []"
          lines << "      end"
        else
          lines << "      attr_reader :results"
          lines << ""
          lines << "      def initialize"
          lines << "        @results = []"
          lines << "      end"
        end
        lines << ""
        lines << "      def call"
        lines << "        #{call_body}"
        lines << "        self"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines.join("\n") + "\n"
      end

      private

      def call_body
        Hecks::Utils.block_source(@service.call_body)
      end
    end
    end
  end
end
