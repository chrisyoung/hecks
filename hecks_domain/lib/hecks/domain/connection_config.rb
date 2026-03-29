# Hecks::ConnectionConfig
#
# Value objects for domain connection configuration, replacing plain hashes
# in DomainConnections. Each supports hash-style [] access for backward compat.
#
#   config = PersistConfig.new(type: :sqlite, path: "db.sqlite3")
#   config.type       # => :sqlite
#   config[:type]     # => :sqlite
#
module Hecks
  PersistConfig = Struct.new(:type, :options, keyword_init: true) do
    def initialize(type:, **options)
      super(type: type, options: options)
    end

    def [](key) = key == :type ? type : options[key]
    def to_h = { type: type, **options }
    def ==(other) = other.is_a?(Hash) ? to_h == other : super
    def eql?(other) = self == other
    def hash = to_h.hash
  end

  SendConfig = Struct.new(:name, :handler, :options, keyword_init: true) do
    def initialize(name:, handler: nil, **options)
      super(name: name, handler: handler, options: options)
    end

    def [](key)
      case key
      when :name then name
      when :handler then handler
      else options[key]
      end
    end

    def to_h = { name: name, handler: handler, **options }
    def ==(other) = other.is_a?(Hash) ? to_h == other : super
    def eql?(other) = self == other
    def hash = to_h.hash
  end

  ExtensionConfig = Struct.new(:name, :options, keyword_init: true) do
    def initialize(name:, **options)
      super(name: name, options: options)
    end

    def [](key) = key == :name ? name : options[key]
    def to_h = { name: name, **options }
    def ==(other) = other.is_a?(Hash) ? to_h == other : super
    def eql?(other) = self == other
    def hash = to_h.hash
  end
end
