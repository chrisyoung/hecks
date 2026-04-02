# Hecks::Crud::SourceBuilder
#
# Generates Ruby source code strings for CRUD command and event classes.
# Used by CommandGenerator to produce in-memory source that gets compiled
# and evaluated via RubyVM::InstructionSequence.
#
# Each method returns a heredoc string containing a complete Ruby module
# definition that reopens the domain module, aggregate class, and the
# Commands or Events namespace.
#
#   src = SourceBuilder.create_command_source(agg, cmd, evt, "PizzasDomain")
#   RubyVM::InstructionSequence.compile(src, "(crud)").eval
#
module Hecks
  module Crud
    module SourceBuilder
      extend HecksTemplating::NamingHelpers

      # Dispatch to the right verb source generator.
      #
      # @param verb [String] "Create", "Update", or "Delete"
      # @return [String] Ruby source
      def self.command_source(verb, agg, cmd, evt, mod_name)
        case verb
        when "Create" then create_command_source(agg, cmd, evt, mod_name)
        when "Update" then update_command_source(agg, cmd, evt, mod_name)
        when "Delete" then delete_command_source(agg, evt, mod_name)
        end
      end

      # Generate Create command source.
      #
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @param cmd [Hecks::DomainModel::Behavior::Command]
      # @param evt [Hecks::DomainModel::Behavior::DomainEvent]
      # @param mod_name [String]
      # @return [String]
      def self.create_command_source(agg, cmd, evt, mod_name)
        params = cmd.attributes.map { |a| "#{a.name}: nil" }.join(", ")
        ivars = cmd.attributes.map { |a| "          @#{a.name} = #{a.name}" }.join("\n")
        readers = cmd.attributes.map { |a| ":#{a.name}" }.join(", ")
        args = agg.attributes.map { |a| "#{a.name}: #{a.name}" }.join(", ")
        <<~RUBY
          module #{mod_name}
            class #{agg.name}
              module Commands
                class #{cmd.name}
                  include Hecks::Command
                  emits "#{evt.name}"
                  attr_reader #{readers}
                  def initialize(#{params})
          #{ivars}
                  end
                  def call
                    #{agg.name}.new(#{args})
                  end
                end
              end
            end
          end
        RUBY
      end

      # Generate Update command source.
      #
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @param cmd [Hecks::DomainModel::Behavior::Command]
      # @param evt [Hecks::DomainModel::Behavior::DomainEvent]
      # @param mod_name [String]
      # @return [String]
      def self.update_command_source(agg, cmd, evt, mod_name)
        ref_name = domain_snake_name(agg.name)
        params = cmd.attributes.map { |a| "#{a.name}: nil" } + ["#{ref_name}: nil"]
        ivars = cmd.attributes.map { |a| "          @#{a.name} = #{a.name}" }
        ivars << "          @#{ref_name} = #{ref_name}"
        readers = (cmd.attributes.map { |a| ":#{a.name}" } + [":#{ref_name}"]).join(", ")
        merge_args = ["id: existing.id"]
        agg.attributes.each do |a|
          merge_args << "#{a.name}: #{a.name}.nil? ? existing.#{a.name} : #{a.name}"
        end
        <<~RUBY
          module #{mod_name}
            class #{agg.name}
              module Commands
                class #{cmd.name}
                  include Hecks::Command
                  emits "#{evt.name}"
                  attr_reader #{readers}
                  def initialize(#{params.join(", ")})
          #{ivars.join("\n")}
                  end
                  def call
                    _ref_val = #{ref_name}
                    _lookup_id = _ref_val.respond_to?(:id) ? _ref_val.id : _ref_val
                    existing = repository.find(_lookup_id)
                    raise #{mod_name}::Error, "#{agg.name} not found: \#{_lookup_id}" unless existing
                    #{agg.name}.new(#{merge_args.join(", ")})
                  end
                end
              end
            end
          end
        RUBY
      end

      # Generate Delete command source.
      #
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @param evt [Hecks::DomainModel::Behavior::DomainEvent]
      # @param mod_name [String]
      # @return [String]
      def self.delete_command_source(agg, evt, mod_name)
        ref_name = domain_snake_name(agg.name)
        <<~RUBY
          module #{mod_name}
            class #{agg.name}
              module Commands
                class Delete#{agg.name}
                  include Hecks::Command
                  emits "#{evt.name}"
                  attr_reader :#{ref_name}
                  def initialize(#{ref_name}: nil)
                    @#{ref_name} = #{ref_name}
                  end
                  def call
                    _ref_val = #{ref_name}
                    _lookup_id = _ref_val.respond_to?(:id) ? _ref_val.id : _ref_val
                    existing = repository.find(_lookup_id)
                    raise #{mod_name}::Error, "#{agg.name} not found: \#{_lookup_id}" unless existing
                    repository.delete(_lookup_id)
                    nil
                  end
                end
              end
            end
          end
        RUBY
      end

      # Generate event class source.
      #
      # @param evt [Hecks::DomainModel::Behavior::DomainEvent]
      # @param agg [Hecks::DomainModel::Structure::Aggregate]
      # @param mod_name [String]
      # @return [String]
      def self.event_source(evt, agg, mod_name)
        readers = (evt.attributes.map { |a| ":#{a.name}" } + [":occurred_at"]).join(", ")
        params = evt.attributes.map { |a| "#{a.name}: nil" }.join(", ")
        ivars = evt.attributes.map { |a| "          @#{a.name} = #{a.name}" }.join("\n")
        <<~RUBY
          module #{mod_name}
            class #{agg.name}
              module Events
                class #{evt.name}
                  attr_reader #{readers}
                  def initialize(#{params})
          #{ivars}
                    @occurred_at = Time.now
                    freeze
                  end
                end
              end
            end
          end
        RUBY
      end
    end
  end
end
