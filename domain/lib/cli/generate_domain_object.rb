# frozen_string_literal: true
module HecksDomain
  module CLI
    # Generate a domain object
    class GenerateDomainObject < Thor::Group
      include Thor::Actions

      class_option :head_name,   aliases: '-h', desc: 'the name of the aggregate head'
      class_option :attributes,  aliases: '-a', type: :array, desc: 'attributes for the aggregate head'
      class_option :optional_attributes, aliases: '-o', type: :array, desc: "attributes that aren't required"
      class_option :read_only_attributes, aliases: '-d', type: :array, desc: "read only attributes"
      class_option :name,        aliases: '-n', desc: 'attributes for the aggregate head'
      class_option :type,        aliases: '-t', desc: 'The type of domain object you want to create'
      class_option :module_name, aliases: '-m', desc: 'Domain Module'
      class_option :referenced_entity, aliases: '-r', desc: 'Referenced Entity'

      def self.source_root
        File.dirname(__FILE__) + '/templates'
      end

      def create_aggregate_folder
        directory(options[:type].to_s, '.')
      end

      private

      def assignment_template(attributes, assign_from_hash: false)
        AssignmentTemplate.new(
          attributes,
          assign_from_hash: assign_from_hash
        ).render
      end

      def writable_attributes(attributes)
        attributes.select do |attribute|
          !(options[:read_only_attributes] || []).include?(
            HecksDomainBuilder::Attribute.new(attribute).name
          )
        end
      end

      def setter_template(attributes, tab_count: 0)
        SetterTemplate.new(
          writable_attributes(attributes),
          tab_count: tab_count
        ).render
      end

      def option_format(format, include_id: false)
        OptionFormatter.new(
          options[:attributes],
          options[:optional_attributes] || [],
          options[:read_only_attributes] || []
        ).call(format, include_id: include_id)
      end

      def head_name
        options[:head_name]
      end

      def name
        options[:name]
      end

      def file_name
        name.underscore
      end

      def attribute_names_without_id
        attributes_without_id.map(&:name)
      end

      def module_name
        options[:module_name]
      end

      def domain_name
        Dir.pwd.split('/').last
      end

      def attributes_without_id_as_string
        attributes_without_id.map { |attribute| ':' + HecksDomainBuilder::Attribute.new(attribute).name }.join ', '
      end

      def attributes
        options[:attributes] + ['id:integer']
      end

      def attributes_without_id
        options[:attributes]
      end
    end
  end
end
