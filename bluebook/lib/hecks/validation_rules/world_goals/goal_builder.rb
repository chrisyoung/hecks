module Hecks
  module ValidationRules
    module WorldGoals

      # Hecks::ValidationRules::WorldGoals::GoalBuilder
      #
      # DSL builder for user-defined world goals. Collects extension requirements
      # and a validation block, then materializes an anonymous BaseRule subclass
      # that self-registers with the validator.
      #
      #   Hecks.define_goal(:audit_trail) do
      #     requires_extension :audit
      #     validate do |domain|
      #       domain.aggregates.flat_map do |agg|
      #         agg.commands.select { |c| c.actors.empty? }.map do |cmd|
      #           "#{agg.name}##{cmd.name} has no actor — audit trail incomplete"
      #         end
      #       end
      #     end
      #   end
      #
      class GoalBuilder
        # @return [Symbol] the goal name
        attr_reader :name

        # @return [Array<Symbol>] extensions this goal requires
        attr_reader :required_extensions

        def initialize(name)
          @name = name.to_sym
          @required_extensions = []
          @validate_block = nil
        end

        # Declare that this goal requires a specific extension to be meaningful.
        #
        # @param ext_name [Symbol] the extension name (e.g. :audit, :logging)
        # @return [void]
        def requires_extension(ext_name)
          @required_extensions << ext_name.to_sym
        end

        # Register the validation block that inspects the domain for violations.
        # The block receives the domain IR and must return an array of strings.
        #
        # @yield [domain] block that returns violation messages
        # @yieldparam domain [Hecks::DomainModel::Structure::Domain]
        # @yieldreturn [Array<String>] violation messages (empty = pass)
        # @return [void]
        def validate(&block)
          @validate_block = block
        end

        # Materialize and register the goal as a BaseRule subclass.
        #
        # Creates an anonymous class under WorldGoals, names it with a constant,
        # and registers it so the Validator picks it up automatically.
        #
        # @return [Class] the generated BaseRule subclass
        def build!
          goal_name = @name
          label = goal_name.to_s.split("_").map(&:capitalize).join(" ")
          vblock = @validate_block
          required = @required_extensions

          rule_class = Class.new(BaseRule) do
            define_method(:errors) do
              return [] unless @domain.world_goals.include?(goal_name)

              raw = vblock ? vblock.call(@domain) : []
              raw.map { |msg| "#{label}: #{msg}" }
            end

            define_method(:required_extensions) { required }
          end

          const_name = goal_name.to_s.split("_").map(&:capitalize).join
          if WorldGoals.const_defined?(const_name)
            old = WorldGoals.const_get(const_name)
            Hecks.deregister_validation_rule(old)
            WorldGoals.send(:remove_const, const_name)
          end
          WorldGoals.const_set(const_name, rule_class)
          Hecks.register_validation_rule(rule_class)
          rule_class
        end
      end
    end
  end
end
