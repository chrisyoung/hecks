# Hecks::HTTP::RouteBuilder
#
# Generates REST routes from a domain's aggregates, commands, and queries.
#
require "time"

module Hecks
  module HTTP
    class RouteBuilder
      def initialize(domain, mod)
        @domain = domain
        @mod = mod
      end

      def build
        routes = []
        @domain.aggregates.each do |agg|
          klass = @mod.const_get(Hecks::Utils.sanitize_constant(agg.name))
          slug = Hecks::Utils.underscore(Hecks::Utils.sanitize_constant(agg.name)) + "s"
          routes.concat(query_routes(agg, klass, slug))
          routes.concat(crud_routes(agg, klass, slug))
        end
        routes
      end

      private

      def crud_routes(agg, klass, slug)
        routes = []
        routes << { method: "GET", path: "/#{slug}", handler: ->(_) { klass.all.map { |r| serialize(r) } } }
        routes << { method: "GET", path: "/#{slug}/:id", handler: ->(req) {
          result = klass.find(req.path.split("/").last)
          result ? serialize(result) : (raise "Not found")
        }}

        create_cmd = agg.commands.find { |c| c.name.start_with?("Create") }
        if create_cmd
          m = derive_method(create_cmd.name, agg.name)
          routes << { method: "POST", path: "/#{slug}", handler: ->(req) {
            serialize(klass.send(m, **parse_body(req)))
          }}
        end

        update_cmd = agg.commands.find { |c| c.name.start_with?("Update") }
        if update_cmd
          routes << { method: "PATCH", path: "/#{slug}/:id", handler: ->(req) {
            existing = klass.find(req.path.split("/").last)
            raise "Not found" unless existing
            serialize(existing.update(**parse_body(req)))
          }}
        end

        routes << { method: "DELETE", path: "/#{slug}/:id", handler: ->(req) {
          id = req.path.split("/").last; klass.delete(id); { deleted: id }
        }}
        routes
      end

      def query_routes(agg, klass, slug)
        agg.queries.map do |query|
          qn = Hecks::Utils.underscore(query.name)
          params = query.block.parameters
          { method: "GET", path: "/#{slug}/#{qn}", handler: ->(req) {
            results = params.empty? ? klass.send(qn.to_sym) : klass.send(qn.to_sym, *params.map { |_, n| req.params[n.to_s] })
            results.respond_to?(:map) ? results.map { |r| serialize(r) } : results
          }}
        end
      end

      def serialize(obj)
        h = {}
        obj.class.instance_method(:initialize).parameters.each do |(_, name)|
          next unless name && obj.respond_to?(name)
          h[name.to_s] = serialize_value(obj.send(name))
        end
        %i[created_at updated_at].each do |ts|
          h[ts.to_s] = serialize_value(obj.send(ts)) if obj.respond_to?(ts) && !h.key?(ts.to_s)
        end
        h
      end

      def serialize_value(val)
        if val.respond_to?(:to_a) && val.respond_to?(:each) && !val.is_a?(Array) && !val.is_a?(Hash) && !val.is_a?(String)
          val.to_a.map { |item| item.respond_to?(:id) ? serialize(item) : serialize_value(item) }
        elsif val.is_a?(Time)
          val.iso8601
        else
          val
        end
      end

      def parse_body(req)
        body = req.body.read
        body.empty? ? {} : JSON.parse(body).transform_keys(&:to_sym)
      end

      def derive_method(cmd_name, agg_name)
        Hecks::Utils.underscore(cmd_name).sub(/_#{Hecks::Utils.underscore(agg_name)}$/, "").to_sym
      end
    end
  end
end
