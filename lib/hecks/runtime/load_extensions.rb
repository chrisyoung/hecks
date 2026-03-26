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
  # Handles discovery and loading of Hecks extensions from the +extensions/+
  # directory. Extensions are Ruby files that register themselves in the
  # +Hecks.extension_registry+ when required. This module provides three
  # loading strategies:
  #
  # - +require_auto+ -- loads only the default set of extensions (AUTO list)
  # - +require_all+ -- loads every +.rb+ file in the extensions directory
  # - +require_one+ -- loads a single named extension
  #
  # Extensions are categorized as either persistence (sqlite, postgres, etc.)
  # or non-persistence (serve, ai, auth, audit, pii). Persistence extensions
  # are loaded explicitly via the +adapter+ keyword in boot/configure.
  # Non-persistence extensions are auto-loaded at boot time.
  module LoadExtensions
    # Absolute path to the extensions directory within the Hecks library.
    EXTENSIONS_DIR = File.expand_path("extensions", __dir__)

    # Extensions loaded automatically at boot (non-persistence).
    # These are the default extensions that will be required when
    # +require_auto+ is called during the boot sequence.
    AUTO = %i[serve ai auth audit pii].freeze

    # Loads a single extension by name from the extensions directory.
    # Silently does nothing if the extension file does not exist or
    # cannot be loaded (e.g., missing dependencies).
    #
    # @param name [Symbol, String] the extension name (e.g., +:audit+, +:serve+)
    # @return [void]
    def self.require_one(name)
      path = File.join(EXTENSIONS_DIR, "#{name}.rb")
      require path if File.exist?(path)
    rescue LoadError
      nil
    end

    # Loads all extensions in the AUTO list. Called during +Hecks.boot+ to
    # ensure standard non-persistence extensions are available. Each extension
    # that fails to load is silently skipped (via +require_one+'s rescue).
    #
    # @return [void]
    def self.require_auto
      AUTO.each { |name| require_one(name) }
    end

    # Loads every +.rb+ file in the extensions directory, sorted alphabetically.
    # Use this when you want all available extensions, not just the default set.
    #
    # @return [void]
    def self.require_all
      Dir[File.join(EXTENSIONS_DIR, "*.rb")].sort.each { |f| require f }
    end

    # Returns the names of all available extensions by scanning the extensions
    # directory for +.rb+ files.
    #
    # @return [Array<Symbol>] extension names (e.g., [:ai, :audit, :auth, :pii, :serve])
    def self.available
      Dir[File.join(EXTENSIONS_DIR, "*.rb")].map { |f| File.basename(f, ".rb").to_sym }
    end
  end
end
