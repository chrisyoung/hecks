# frozen_string_literal: true
module Hecks
  module Adapters
    class Application
      module Commands
        class Update
          attr_accessor :args, :errors, :id

          def initialize(chained_command = nil, args: nil, repository: Repository)

            @repository      = repository
            @chained_command = chained_command
            @args            = args || chained_command.args
            @errors          = []
            @id              = @args.delete(:id)
          end


          def repository
            return @repository unless chained_command.respond_to?(:repository)
            chained_command.repository || @repository
          end

          def name
            self.class.to_s.split('::').last.underscore
          end

          def call
            call_chained_command
            update
            self
          end

          def to_h
            { id: id, args: args }
          end

          private

          attr_reader :repository_result, :chained_command

          def call_chained_command
            return unless chained_command
            @errors = chained_command.call.errors
          end

          def update
            return if @errors.count.positive?
            @repository_result = repository.update(id, args)
          end
        end
      end
    end
  end
end
