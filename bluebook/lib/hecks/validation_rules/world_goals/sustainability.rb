module Hecks
  module ValidationRules
    module WorldGoals

      # Hecks::ValidationRules::WorldGoals::Sustainability
      #
      # When the :sustainability goal is declared, this rule flags creation commands
      # that lack corresponding cleanup, archive, or delete commands. Resource-heavy
      # or consumable-creating commands should have matching disposal or deprecation
      # paths to avoid leaving dangling or abandoned resources.
      #
      # This is an advisory warning, not an error. It encourages thoughtful resource
      # lifecycle management.
      #
      #   world_goals :sustainability
      #
      #   aggregate "Session" do
      #     command "CreateSession" do
      #       attribute :token, String
      #     end
      #     # <-- warns: no cleanup path for session lifetime
      #   end
      #
      #   aggregate "Session" do
      #     command "CreateSession" do
      #       attribute :token, String
      #     end
      #     command "ExpireSession" do   # <-- better: matched cleanup
      #       attribute :token, String
      #     end
      #   end
      #
      class Sustainability < BaseRule
        CREATE_PATTERNS = %w[Create Add Register Allocate Open Start Spawn].freeze
        CLEANUP_PATTERNS = %w[Delete Remove Archive Deactivate Close Stop Expire Retire Discard].freeze

        def errors
          []
        end

        def warnings
          return [] unless @domain.world_goals.include?(:sustainability)

          issues = []
          @domain.aggregates.each do |agg|
            creation_commands = agg.commands.select { |cmd| creation_command?(cmd.name) }
            cleanup_commands = agg.commands.select { |cmd| cleanup_command?(cmd.name) }

            if creation_commands.any? && cleanup_commands.empty?
              creation_names = creation_commands.map { |c| c.name }.join(", ")
              issues << "Sustainability: #{agg.name} has creation commands (#{creation_names}) " \
                        "but no corresponding cleanup, archive, or delete commands. " \
                        "Consider adding Delete, Archive, or Expire commands to complete the resource lifecycle."
            end
          end
          issues
        end

        private

        def creation_command?(name)
          CREATE_PATTERNS.any? { |pat| name.include?(pat) }
        end

        def cleanup_command?(name)
          CLEANUP_PATTERNS.any? { |pat| name.include?(pat) }
        end
      end
      Hecks.register_validation_rule(Sustainability)
    end
  end
end
