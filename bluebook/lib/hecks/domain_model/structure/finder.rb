# Hecks::DomainModel::Structure::Finder
#
# Value object representing a custom finder declared on an aggregate.
# Finders are named repository methods that locate aggregates by a
# specific attribute. The memory adapter auto-implements them as
# +find_by_<name>+ on the repository.
#
#   Finder.new(name: :email, attribute: :email)
#   # => generates find_by_email(value) on the repository
#
module Hecks
  module DomainModel
    module Structure
      class Finder
        # @return [Symbol] the finder name (e.g., :email, :name)
        attr_reader :name

        # @return [Symbol] the attribute to search by
        attr_reader :attribute

        # @param name [Symbol] the finder name
        # @param attribute [Symbol] the attribute to filter on
        def initialize(name:, attribute: nil)
          @name = name.to_sym
          @attribute = (attribute || name).to_sym
        end
      end
    end
  end
end
