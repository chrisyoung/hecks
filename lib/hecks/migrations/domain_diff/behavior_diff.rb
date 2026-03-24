# Hecks::Migrations::DomainDiff::BehaviorDiff
#
# Detects changes in behavioral domain elements: commands, policies,
# validations, invariants, queries, scopes, subscribers, and
# specifications. Mixed into DomainDiff.
#
module Hecks
  module Migrations
    class DomainDiff
      module BehaviorDiff
        private

        def diff_commands(old_agg, new_agg)
          diff_named_collection(old_agg, new_agg, :commands, :command)
        end

        def diff_policies(old_agg, new_agg)
          changes = []
          old_pols = old_agg.policies.select(&:reactive?)
          new_pols = new_agg.policies.select(&:reactive?)
          old_names = old_pols.map(&:name)
          new_names = new_pols.map(&:name)

          (new_names - old_names).each do |name|
            pol = new_pols.find { |p| p.name == name }
            changes << Change.new(
              kind: :add_policy, context: :behavior, aggregate: new_agg.name,
              details: { name: name, event: pol.event_name, trigger: pol.trigger_command }
            )
          end

          (old_names - new_names).each do |name|
            changes << Change.new(
              kind: :remove_policy, context: :behavior, aggregate: new_agg.name,
              details: { name: name }
            )
          end

          # Changed wiring
          (old_names & new_names).each do |name|
            old_pol = old_pols.find { |p| p.name == name }
            new_pol = new_pols.find { |p| p.name == name }
            if old_pol.event_name != new_pol.event_name || old_pol.trigger_command != new_pol.trigger_command
              changes << Change.new(
                kind: :change_policy, context: :behavior, aggregate: new_agg.name,
                details: { name: name, event: new_pol.event_name, trigger: new_pol.trigger_command }
              )
            end
          end

          changes
        end

        def diff_validations(old_agg, new_agg)
          changes = []
          old_fields = old_agg.validations.map(&:field)
          new_fields = new_agg.validations.map(&:field)

          (new_fields - old_fields).each do |field|
            v = new_agg.validations.find { |val| val.field == field }
            changes << Change.new(
              kind: :add_validation, context: :behavior, aggregate: new_agg.name,
              details: { field: field, rules: v.rules }
            )
          end

          (old_fields - new_fields).each do |field|
            changes << Change.new(
              kind: :remove_validation, context: :behavior, aggregate: new_agg.name,
              details: { field: field }
            )
          end

          changes
        end

        def diff_invariants(old_agg, new_agg)
          old_msgs = old_agg.invariants.map(&:message)
          new_msgs = new_agg.invariants.map(&:message)
          changes = []

          (new_msgs - old_msgs).each do |msg|
            changes << Change.new(
              kind: :add_invariant, context: :behavior, aggregate: new_agg.name,
              details: { message: msg }
            )
          end

          (old_msgs - new_msgs).each do |msg|
            changes << Change.new(
              kind: :remove_invariant, context: :behavior, aggregate: new_agg.name,
              details: { message: msg }
            )
          end

          changes
        end

        def diff_queries(old_agg, new_agg)
          diff_named_collection(old_agg, new_agg, :queries, :query)
        end

        def diff_scopes(old_agg, new_agg)
          diff_named_collection(old_agg, new_agg, :scopes, :scope)
        end

        def diff_subscribers(old_agg, new_agg)
          old_names = (old_agg.subscribers || []).map(&:name)
          new_names = (new_agg.subscribers || []).map(&:name)
          changes = []

          (new_names - old_names).each do |name|
            sub = new_agg.subscribers.find { |s| s.name == name }
            changes << Change.new(
              kind: :add_subscriber, context: :behavior, aggregate: new_agg.name,
              details: { name: name, event: sub.event_name }
            )
          end

          (old_names - new_names).each do |name|
            changes << Change.new(
              kind: :remove_subscriber, context: :behavior, aggregate: new_agg.name,
              details: { name: name }
            )
          end

          changes
        end

        def diff_specifications(old_agg, new_agg)
          diff_named_collection(old_agg, new_agg, :specifications, :specification)
        end

        # Generic add/remove for named collections (commands, queries, scopes, specs)
        def diff_named_collection(old_agg, new_agg, method, kind_prefix)
          old_items = (old_agg.send(method) || [])
          new_items = (new_agg.send(method) || [])
          old_names = old_items.map(&:name)
          new_names = new_items.map(&:name)
          changes = []

          (new_names - old_names).each do |name|
            changes << Change.new(
              kind: :"add_#{kind_prefix}", context: :behavior, aggregate: new_agg.name,
              details: { name: name }
            )
          end

          (old_names - new_names).each do |name|
            changes << Change.new(
              kind: :"remove_#{kind_prefix}", context: :behavior, aggregate: new_agg.name,
              details: { name: name }
            )
          end

          changes
        end
      end
    end
  end
end
