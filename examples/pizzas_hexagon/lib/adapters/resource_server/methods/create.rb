module PizzasHexagon
  module Adapters
    module ResourceServer
      class Methods
        class Create
          def initialize(hexagon:)
            @hexagon = hexagon
          end

          def call(body:, module_name:)
            @body        = body.read
            @module_name = module_name.to_sym
            run_command
            [JSON.generate(command_result.to_h)]
          end

          private

          attr_reader :hexagon, :body, :module_name, :command_result

          def status
            return 500 if command_result.errors.count > 0
            return 200
          end

          def run_command
            @command_result = hexagon.call(
              module_name: module_name,
              command:     :create,
              args:        params
            )
          end

          def params
            JSON.parse(body, symbolize_names: true)
          end
        end
      end
    end
  end
end
