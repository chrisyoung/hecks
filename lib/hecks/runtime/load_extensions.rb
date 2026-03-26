# Hecks::LoadExtensions
#
# Discovers and loads extensions by walking the extensions/ directory.
# No registration needed — any .rb file in extensions/ is an extension.
# Called by Boot to auto-detect available extensions.
#
#   Hecks::LoadExtensions.require_all    # load everything
#   Hecks::LoadExtensions.require_auto   # load only the default set
#   Hecks::LoadExtensions.require_one(:audit)
#
module Hecks
  module LoadExtensions
    EXTENSIONS_DIR = File.expand_path("extensions", __dir__)

    # Extensions loaded automatically at boot (non-persistence).
    AUTO = %i[serve ai auth audit pii].freeze

    def self.require_one(name)
      path = File.join(EXTENSIONS_DIR, "#{name}.rb")
      require path if File.exist?(path)
    rescue LoadError
      nil
    end

    def self.require_auto
      AUTO.each { |name| require_one(name) }
    end

    def self.require_all
      Dir[File.join(EXTENSIONS_DIR, "*.rb")].sort.each { |f| require f }
    end

    def self.available
      Dir[File.join(EXTENSIONS_DIR, "*.rb")].map { |f| File.basename(f, ".rb").to_sym }
    end
  end
end
