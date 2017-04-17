module Hecks
  module Adapters
    class DynamoDB
      module Commands
        class Delete
          def initialize(query, head, client)
            @head = head
            @query = query
            @client = client
          end

          def call
            delete_item
            self
          end

          private

          attr_reader :client, :head, :query

          def delete_item
            client.delete_item(key: query, table_name: head.name)
          end
        end
      end
    end
  end
end
