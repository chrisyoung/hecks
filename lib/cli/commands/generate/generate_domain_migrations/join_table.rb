class GenerateDomainMigrations < Thor::Group
  class MigrationBuilder
    class JoinTable
      def initialize(table, column)
        @table = table
        @column = column
      end

      def name
        "#{@table.name}_#{@column.name}"
      end

      def columns
        [@table.name, @column.name].map do |name|
          Column.new(name: name + '_id', type: 'Integer')
        end
      end
    end
  end
end