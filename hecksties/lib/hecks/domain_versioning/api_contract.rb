# Hecks::DomainVersioning::ApiContract
#
# Serializes a domain's public API surface to a stable JSON representation.
# The contract captures aggregate names, attribute names/types, command
# signatures, and query names -- everything a consumer depends on.
# Used by contract_check to detect unacknowledged breaking changes.
#
#   contract = ApiContract.serialize(domain)
#   File.write(".hecks_api_contract.json", JSON.pretty_generate(contract))
#
#   changes = ApiContract.diff(old_contract, new_contract)
#   # => [{ kind: :remove_attribute, aggregate: "Pizza", details: { name: :color } }, ...]
#
require "json"

module Hecks
  module DomainVersioning
    module ApiContract
      CONTRACT_FILE = ".hecks_api_contract.json"

      # Serialize a domain's public API surface to a Hash suitable for JSON.
      #
      # @param domain [Hecks::DomainModel::Domain] the domain to serialize
      # @return [Hash] JSON-serializable contract representation
      def self.serialize(domain)
        {
          domain: domain.name,
          version: domain.version,
          aggregates: domain.aggregates.map { |agg| serialize_aggregate(agg) }
        }
      end

      # Write the contract JSON file to disk.
      #
      # @param domain [Hecks::DomainModel::Domain] domain to snapshot
      # @param base_dir [String] project root directory
      # @return [String] path to the written file
      def self.save(domain, base_dir: Dir.pwd)
        path = File.join(base_dir, CONTRACT_FILE)
        File.write(path, JSON.pretty_generate(serialize(domain)) + "\n")
        path
      end

      # Load a previously saved contract from disk.
      #
      # @param base_dir [String] project root directory
      # @return [Hash, nil] the contract hash, or nil if no file exists
      def self.load(base_dir: Dir.pwd)
        path = File.join(base_dir, CONTRACT_FILE)
        return nil unless File.exist?(path)
        JSON.parse(File.read(path), symbolize_names: true)
      end

      # Compare two contract hashes and return Change-like structs.
      #
      # @param old_contract [Hash] the baseline contract
      # @param new_contract [Hash] the current contract
      # @return [Array<Hecks::Migrations::DomainDiff::Change>] detected changes
      def self.diff(old_contract, new_contract)
        changes = []
        old_aggs = index_by_name(old_contract[:aggregates] || [])
        new_aggs = index_by_name(new_contract[:aggregates] || [])

        changes.concat(diff_aggregates(old_aggs, new_aggs))
        changes.concat(diff_existing_aggregates(old_aggs, new_aggs))
        changes
      end

      # Serialize a single aggregate to a contract hash.
      #
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @return [Hash]
      def self.serialize_aggregate(agg)
        {
          name: agg.name,
          attributes: agg.attributes.map { |a| { name: a.name.to_s, type: a.ruby_type } },
          commands: agg.commands.map { |c| serialize_command(c) },
          queries: (agg.queries || []).map(&:name)
        }
      end

      # Serialize a single command to a contract hash.
      #
      # @param cmd [Hecks::DomainModel::Behavior::Command]
      # @return [Hash]
      def self.serialize_command(cmd)
        {
          name: cmd.name,
          attributes: cmd.attributes.map { |a| { name: a.name.to_s, type: a.ruby_type } }
        }
      end

      # --- private helpers ---

      def self.index_by_name(list)
        list.each_with_object({}) { |item, h| h[item[:name]] = item }
      end

      def self.diff_aggregates(old_aggs, new_aggs)
        changes = []
        (old_aggs.keys - new_aggs.keys).each do |name|
          changes << make_change(:remove_aggregate, name, {})
        end
        (new_aggs.keys - old_aggs.keys).each do |name|
          changes << make_change(:add_aggregate, name, {})
        end
        changes
      end

      def self.diff_existing_aggregates(old_aggs, new_aggs)
        changes = []
        (old_aggs.keys & new_aggs.keys).each do |name|
          changes.concat(diff_attributes(name, old_aggs[name], new_aggs[name]))
          changes.concat(diff_commands(name, old_aggs[name], new_aggs[name]))
        end
        changes
      end

      def self.diff_attributes(agg_name, old_agg, new_agg)
        changes = []
        old_attrs = index_by_name(old_agg[:attributes] || [])
        new_attrs = index_by_name(new_agg[:attributes] || [])

        (old_attrs.keys - new_attrs.keys).each do |attr_name|
          changes << make_change(:remove_attribute, agg_name, { name: attr_name.to_sym })
        end
        (new_attrs.keys - old_attrs.keys).each do |attr_name|
          a = new_attrs[attr_name]
          changes << make_change(:add_attribute, agg_name, { name: attr_name.to_sym, type: a[:type] })
        end
        (old_attrs.keys & new_attrs.keys).each do |attr_name|
          old_type = old_attrs[attr_name][:type]
          new_type = new_attrs[attr_name][:type]
          next if old_type == new_type
          changes << make_change(:change_attribute_type, agg_name, {
            name: attr_name.to_sym, old_type: old_type, new_type: new_type
          })
        end
        changes
      end

      def self.diff_commands(agg_name, old_agg, new_agg)
        changes = []
        old_cmds = index_by_name(old_agg[:commands] || [])
        new_cmds = index_by_name(new_agg[:commands] || [])

        (old_cmds.keys - new_cmds.keys).each do |cmd_name|
          changes << make_change(:remove_command, agg_name, { name: cmd_name })
        end
        (new_cmds.keys - old_cmds.keys).each do |cmd_name|
          changes << make_change(:add_command, agg_name, { name: cmd_name })
        end
        (old_cmds.keys & new_cmds.keys).each do |cmd_name|
          old_attr_names = (old_cmds[cmd_name][:attributes] || []).map { |a| a[:name] }
          new_attr_names = (new_cmds[cmd_name][:attributes] || []).map { |a| a[:name] }
          (new_attr_names - old_attr_names).each do |attr_name|
            changes << make_change(:add_required_command_attribute, agg_name, {
              command: cmd_name, name: attr_name.to_sym
            })
          end
        end
        changes
      end

      def self.make_change(kind, aggregate, details)
        Hecks::Migrations::DomainDiff::Change.new(
          kind: kind, context: nil, aggregate: aggregate, details: details
        )
      end

      private_class_method :index_by_name, :diff_aggregates,
                           :diff_existing_aggregates, :diff_attributes,
                           :diff_commands, :make_change
    end
  end
end
