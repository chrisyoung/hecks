# Hecks::Generators::SqlBuilder
#
# SQL generation helpers for SqlAdapterGenerator. Builds the INSERT,
# UPDATE, SELECT (build), and DELETE statement fragments including
# join-table handling for list-type value objects.
#
module Hecks
  module Generators
    module SqlBuilder
      private

      def insert_lines
        cols = ["id"] + scalar_attributes.map { |a| a.name.to_s } + ["created_at", "updated_at"]
        placeholders = cols.map { "?" }.join(", ")
        values = cols.map do |c|
          if %w[created_at updated_at].include?(c)
            "#{snake_name}.#{c}&.iso8601"
          elsif c == "id"
            "#{snake_name}.id"
          else
            "#{snake_name}.#{c}"
          end
        end.join(", ")

        lines = []
        lines << "      def insert(#{snake_name})"
        lines << "        @connection.execute("
        lines << "          \"INSERT INTO #{table_name} (#{cols.join(', ')}) VALUES (#{placeholders})\","
        lines << "          [#{values}]"
        lines << "        )"
        list_value_objects.each do |vo|
          lines.concat(insert_vo_lines(vo))
        end
        lines << "      end"
        lines
      end

      def update_lines
        all_sets = scalar_attributes.map { |a| "#{a.name} = ?" } + ["created_at = ?", "updated_at = ?"]
        sets = all_sets.join(", ")
        all_values = scalar_attributes.map { |a| "#{snake_name}.#{a.name}" } + ["#{snake_name}.created_at&.iso8601", "#{snake_name}.updated_at&.iso8601"]
        values = all_values.join(", ")

        lines = []
        lines << "      def update(#{snake_name})"
        if scalar_attributes.any?
          lines << "        @connection.execute("
          lines << "          \"UPDATE #{table_name} SET #{sets} WHERE id = ?\","
          lines << "          [#{values}, #{snake_name}.id]"
          lines << "        )"
        end
        list_value_objects.each do |vo|
          vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
          lines << "        @connection.execute(\"DELETE FROM #{vo_table} WHERE #{snake_name}_id = ?\", [#{snake_name}.id])"
          lines.concat(insert_vo_lines(vo))
        end
        lines << "      end"
        lines
      end

      def build_lines
        attr_assigns = scalar_attributes.map do |a|
          "          #{a.name}: row[\"#{a.name}\"]"
        end

        lines = []
        lines << "      def build(row)"

        list_value_objects.each do |vo|
          vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
          lines << "        #{Hecks::Utils.underscore(vo.name)}_rows = @connection.execute("
          lines << "          \"SELECT * FROM #{vo_table} WHERE #{snake_name}_id = ?\", [row[\"id\"]]"
          lines << "        )"
          vo_attrs = vo.attributes.map { |a| "#{a.name}: r[\"#{a.name}\"]" }.join(", ")
          lines << "        #{Hecks::Utils.underscore(vo.name)}s = #{Hecks::Utils.underscore(vo.name)}_rows.map { |r| #{@aggregate.name}::#{vo.name}.new(#{vo_attrs}) }"
        end

        all_assigns = ["          id: row[\"id\"]"] + attr_assigns
        list_value_objects.each do |vo|
          attr_name = @aggregate.attributes.find { |a| a.list? && a.type.to_s == vo.name }&.name
          all_assigns << "          #{attr_name}: #{Hecks::Utils.underscore(vo.name)}s" if attr_name
        end
        all_assigns << "          created_at: row[\"created_at\"] ? Time.parse(row[\"created_at\"].to_s) : nil"
        all_assigns << "          updated_at: row[\"updated_at\"] ? Time.parse(row[\"updated_at\"].to_s) : nil"

        lines << "        require \"time\""
        lines << "        #{@aggregate.name}.new("
        lines << all_assigns.join(",\n")
        lines << "        )"
        lines << "      end"
        lines
      end

      def insert_vo_lines(vo)
        vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
        attr_name = @aggregate.attributes.find { |a| a.list? && a.type.to_s == vo.name }&.name
        return [] unless attr_name

        vo_cols = ["id", "#{snake_name}_id"] + vo.attributes.map { |a| a.name.to_s }
        vo_placeholders = vo_cols.map { "?" }.join(", ")
        vo_values = vo.attributes.map { |a| "vo.#{a.name}" }.join(", ")

        lines = []
        lines << "        #{snake_name}.#{attr_name}.each do |vo|"
        lines << "          @connection.execute("
        lines << "            \"INSERT INTO #{vo_table} (#{vo_cols.join(', ')}) VALUES (#{vo_placeholders})\","
        lines << "            [SecureRandom.uuid, #{snake_name}.id, #{vo_values}]"
        lines << "          )"
        lines << "        end"
        lines
      end

      def delete_vo_lines
        lines = []
        list_value_objects.each do |vo|
          vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
          lines << "        @connection.execute(\"DELETE FROM #{vo_table} WHERE #{snake_name}_id = ?\", [id])"
        end
        lines
      end
    end
  end
end
