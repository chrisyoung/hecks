# Hecks::DomainVersioning::ApiContract
#
# Serializes a domain's public API surface into a stable JSON structure
# for contract comparison across versions. Captures aggregates, their
# attributes, commands, events, queries, and finders.
#
#   contract = ApiContract.serialize(domain)
#   File.write("api_contract.json", JSON.pretty_generate(contract))
#
module Hecks
  module DomainVersioning
    module ApiContract
      # Serialize a domain's public API surface to a Hash.
      #
      # @param domain [Hecks::DomainModel::Structure::Domain]
      # @return [Hash] serializable API contract
      def self.serialize(domain)
        {
          domain: domain.name,
          version: domain.respond_to?(:version) ? domain.version : nil,
          aggregates: domain.aggregates.map { |agg| serialize_aggregate(agg) }
        }
      end

      # Compare two serialized contracts and return differences.
      #
      # @param old_contract [Hash] previous version contract
      # @param new_contract [Hash] current version contract
      # @return [Array<Hash>] list of differences with :type and :detail keys
      def self.diff(old_contract, new_contract)
        diffs = []
        old_aggs = index_by_name(old_contract[:aggregates] || old_contract["aggregates"] || [])
        new_aggs = index_by_name(new_contract[:aggregates] || new_contract["aggregates"] || [])

        (old_aggs.keys | new_aggs.keys).sort.each do |name|
          old_agg = old_aggs[name]
          new_agg = new_aggs[name]

          if old_agg.nil?
            diffs << { type: :added_aggregate, detail: name }
          elsif new_agg.nil?
            diffs << { type: :removed_aggregate, detail: name }
          else
            diffs.concat(diff_aggregate(name, old_agg, new_agg))
          end
        end
        diffs
      end

      # @api private
      def self.serialize_aggregate(agg)
        {
          name: agg.name,
          attributes: agg.attributes.map { |a| { name: a.name.to_s, type: a.type.to_s } },
          commands: agg.commands.map { |c| { name: c.name, attributes: c.attributes.map { |a| a.name.to_s } } },
          events: agg.events.map { |e| e.name },
          queries: agg.queries.map { |q| q.name.to_s },
          finders: agg.respond_to?(:finders) ? agg.finders.map { |f| f.name.to_s } : []
        }
      end

      # @api private
      def self.diff_aggregate(name, old_agg, new_agg)
        diffs = []
        old_attrs = (old_agg[:attributes] || old_agg["attributes"] || []).map { |a| a[:name] || a["name"] }
        new_attrs = (new_agg[:attributes] || new_agg["attributes"] || []).map { |a| a[:name] || a["name"] }

        (old_attrs - new_attrs).each { |a| diffs << { type: :removed_attribute, detail: "#{name}.#{a}" } }
        (new_attrs - old_attrs).each { |a| diffs << { type: :added_attribute, detail: "#{name}.#{a}" } }

        old_cmds = (old_agg[:commands] || old_agg["commands"] || []).map { |c| c[:name] || c["name"] }
        new_cmds = (new_agg[:commands] || new_agg["commands"] || []).map { |c| c[:name] || c["name"] }

        (old_cmds - new_cmds).each { |c| diffs << { type: :removed_command, detail: "#{name}.#{c}" } }
        (new_cmds - old_cmds).each { |c| diffs << { type: :added_command, detail: "#{name}.#{c}" } }

        diffs
      end

      # @api private
      def self.index_by_name(list)
        list.each_with_object({}) { |item, h| h[item[:name] || item["name"]] = item }
      end

      private_class_method :serialize_aggregate, :diff_aggregate, :index_by_name
    end
  end
end
