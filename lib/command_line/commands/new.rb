# frozen_string_literal: true

module Hecks
  class Commands
    class New < Thor::Group
      namespace :hecks
      include Thor::Actions

      class_option :nobuilder, aliases: '-n', desc: 'load schema from builder'
      class_option :dry_run, aliases: '-d', desc: 'Use when specifying a schema file to output the commands, without running them'

      def self.source_root
        File.dirname(__FILE__)
      end

      def load_from_builder
        return if options[:nobuilder]
        Hecks::Builder.new(
          hecks_file: File.read('HECKS'),
          name:    File.basename(Dir.getwd),
          dry_run: !options[:dry_run].nil?
        ).call
      end

      def create_hexagon_folder
        return unless options[:nobuilder]
        directory('../../generators/templates/new', ".")
      end

      private

      def name
        File.basename(Dir.getwd)
      end

      def module_name
        name.camelize
      end

      def domain_module_name
        domain_name.camelize
      end

      def condensed_module_name
        name.delete('_')
      end
    end
  end
end
