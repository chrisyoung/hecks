require_relative 'update/update_values'
require_relative 'update/link_to_references'
require_relative 'update/create_new_value'
require_relative 'update/delete_references'

module Hecks
  module Adapters
    class SQLDatabase
      module Commands
        class Update
          attr_reader :id
          def initialize(attributes:, head:)
            @attributes = attributes.clone
            @references = head.references
            @head_table = Table.factory([head]).first
          end

          def call
            DB.transaction do
              update_references
              fetch_record
              update_record
            end
            self
          end

          private

          def update_references
            UpdateValues.new(@references, @attributes, @head_table).call
          end

          def update_record
            @record.update(@attributes)
          end

          def fetch_record
            @record = DB[@head_table.name.to_sym].where(id: @attributes.delete(:id))
          end
        end
      end
    end
  end
end
