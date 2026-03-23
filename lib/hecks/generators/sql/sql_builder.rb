# Hecks::Generators::SQL::SqlBuilder
#
# Sequel-based generation helpers for SqlAdapterGenerator. Builds insert,
# update, build, and delete method bodies using Sequel dataset operations.
# Handles join tables for list-type value objects.
#
module Hecks
  module Generators
    module SQL
      module SqlBuilder
      private

      def insert_lines
        col_hash = scalar_attributes.map { |a| a.json? ? "#{a.name}: JSON.generate(#{snake_name}.#{a.name} || nil)" : "#{a.name}: #{snake_name}.#{a.name}" }
        col_hash << "id: #{snake_name}.id"
        col_hash << "created_at: #{snake_name}.created_at&.iso8601"
        col_hash << "updated_at: #{snake_name}.updated_at&.iso8601"

        lines = []
        lines << "      def insert(#{snake_name})"
        lines << "        @db[:#{table_name}].insert(#{col_hash.join(', ')})"
        list_value_objects.each do |vo|
          lines.concat(insert_vo_lines(vo))
        end
        lines << "      end"
        lines
      end

      def update_lines
        col_hash = scalar_attributes.map { |a| a.json? ? "#{a.name}: JSON.generate(#{snake_name}.#{a.name} || nil)" : "#{a.name}: #{snake_name}.#{a.name}" }
        col_hash << "created_at: #{snake_name}.created_at&.iso8601"
        col_hash << "updated_at: #{snake_name}.updated_at&.iso8601"

        lines = []
        lines << "      def update(#{snake_name})"
        if scalar_attributes.any?
          lines << "        @db[:#{table_name}].where(id: #{snake_name}.id).update(#{col_hash.join(', ')})"
        end
        list_value_objects.each do |vo|
          vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
          lines << "        @db[:#{vo_table}].where(#{snake_name}_id: #{snake_name}.id).delete"
          lines.concat(insert_vo_lines(vo))
        end
        lines << "      end"
        lines
      end

      def build_lines
        attr_assigns = scalar_attributes.map do |a|
          if a.json?
            "          #{a.name}: (row[:#{a.name}] ? JSON.parse(row[:#{a.name}]) : nil)"
          else
            "          #{a.name}: row[:#{a.name}]"
          end
        end

        lines = []
        lines << "      def build(row)"

        list_value_objects.each do |vo|
          vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
          vo_snake = Hecks::Utils.underscore(vo.name)
          lines << "        #{vo_snake}_rows = @db[:#{vo_table}].where(#{snake_name}_id: row[:id]).all"
          vo_attrs = vo.attributes.map { |a| "#{a.name}: r[:#{a.name}]" }.join(", ")
          lines << "        #{vo_snake}s = #{vo_snake}_rows.map { |r| #{Hecks::Utils.sanitize_constant(@aggregate.name)}::#{vo.name}.new(#{vo_attrs}) }"
        end

        all_assigns = ["          id: row[:id]"] + attr_assigns
        list_value_objects.each do |vo|
          attr_name = @aggregate.attributes.find { |a| a.list? && a.type.to_s == vo.name }&.name
          all_assigns << "          #{attr_name}: #{Hecks::Utils.underscore(vo.name)}s" if attr_name
        end
        lines << "        require \"time\""
        lines << "        agg = #{Hecks::Utils.sanitize_constant(@aggregate.name)}.new("
        lines << all_assigns.join(",\n")
        lines << "        )"
        lines << "        agg.instance_variable_set(:@created_at, row[:created_at] ? Time.parse(row[:created_at].to_s) : nil)"
        lines << "        agg.instance_variable_set(:@updated_at, row[:updated_at] ? Time.parse(row[:updated_at].to_s) : nil)"
        lines << "        agg"
        lines << "      end"
        lines
      end

      def insert_vo_lines(vo)
        vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
        attr_name = @aggregate.attributes.find { |a| a.list? && a.type.to_s == vo.name }&.name
        return [] unless attr_name

        vo_cols = vo.attributes.map { |a| "#{a.name}: vo.#{a.name}" }

        lines = []
        lines << "        #{snake_name}.#{attr_name}.each do |vo|"
        lines << "          @db[:#{vo_table}].insert(id: SecureRandom.uuid, #{snake_name}_id: #{snake_name}.id, #{vo_cols.join(', ')})"
        lines << "        end"
        lines
      end

      def delete_vo_lines
        lines = []
        list_value_objects.each do |vo|
          vo_table = "#{table_name}_#{Hecks::Utils.underscore(vo.name)}s"
          lines << "        @db[:#{vo_table}].where(#{snake_name}_id: id).delete"
        end
        lines
      end
      end
    end
  end
end
