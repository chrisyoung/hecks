# Hecks::CLI::Domain#diff
#
# Compares the current domain definition against the last saved snapshot
# and prints all structural and behavioral changes. Used to detect
# breaking changes before building or deploying.
#
#   hecks domain diff
#   hecks domain diff --domain pizzas
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "diff", "Show changes since last build"
      option :domain, type: :string, desc: "Domain gem name or path"
      option :version, type: :string, desc: "Domain version"
      # Compares current domain against the snapshot and prints changes.
      #
      # @return [void]
      def diff
        domain = resolve_domain_option
        return unless domain

        snapshot_path = Migrations::DomainSnapshot::DEFAULT_PATH
        unless Migrations::DomainSnapshot.exists?(path: snapshot_path)
          say "No snapshot found. Run `hecks build` first to create a baseline.", :yellow
          return
        end

        old_domain = Migrations::DomainSnapshot.load(path: snapshot_path)
        changes = Migrations::DomainDiff.call(old_domain, domain)

        if changes.empty?
          say "No changes detected.", :green
          return
        end

        say "#{changes.size} change#{"s" if changes.size != 1} detected:", :yellow
        say ""

        changes.each do |change|
          label = format_change(change)
          color = breaking?(change) ? :red : :green
          say "  #{label}", color
        end

        breaking = changes.count { |c| breaking?(c) }
        if breaking > 0
          say ""
          say "#{breaking} breaking change#{"s" if breaking != 1}!", :red
        end
      end

      private

      def format_change(change)
        case change.kind
        when :add_aggregate
          "+ Added aggregate: #{change.aggregate}"
        when :remove_aggregate
          "- Removed aggregate: #{change.aggregate}"
        when :add_attribute
          "+ Added attribute: #{change.aggregate}.#{change.details[:name]}"
        when :remove_attribute
          "- Removed attribute: #{change.aggregate}.#{change.details[:name]}"
        when :add_command
          "+ Added command: #{change.details[:name]}"
        when :remove_command
          "- Removed command: #{change.details[:name]}"
        when :add_policy
          "+ Added policy: #{change.details[:name]}"
        when :remove_policy
          "- Removed policy: #{change.details[:name]}"
        when :change_policy
          "~ Changed policy: #{change.details[:name]}"
        when :add_validation
          "+ Added validation: #{change.aggregate}.#{change.details[:field]}"
        when :remove_validation
          "- Removed validation: #{change.aggregate}.#{change.details[:field]}"
        when :add_value_object
          "+ Added value object: #{change.details[:name]}"
        when :remove_value_object
          "- Removed value object: #{change.details[:name]}"
        when :add_entity
          "+ Added entity: #{change.details[:name]}"
        when :remove_entity
          "- Removed entity: #{change.details[:name]}"
        when :add_query
          "+ Added query: #{change.details[:name]}"
        when :remove_query
          "- Removed query: #{change.details[:name]}"
        when :add_scope
          "+ Added scope: #{change.details[:name]}"
        when :remove_scope
          "- Removed scope: #{change.details[:name]}"
        when :add_specification
          "+ Added specification: #{change.details[:name]}"
        when :remove_specification
          "- Removed specification: #{change.details[:name]}"
        else
          "#{change.kind}: #{change.aggregate} #{change.details}"
        end
      end

      def breaking?(change)
        %i[remove_aggregate remove_attribute remove_command remove_value_object remove_entity].include?(change.kind)
      end
    end
  end
end
