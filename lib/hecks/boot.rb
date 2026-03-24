# Hecks::Boot
#
# Convenience method that loads a domain from a directory, validates it,
# builds the gem, adds it to $LOAD_PATH, and returns a wired Runtime.
# Designed for standalone scripts and small projects that want one-call setup.
#
# Part of the top-level Hecks API. Mixed into the Hecks module via extend.
#
#   app = Hecks.boot(__dir__)
#   Pizza.create(name: "Margherita")
#
module Hecks
  module Boot
    # Load, validate, build, and wire a domain from a directory.
    #
    # @param dir [String] directory containing hecks_domain.rb
    # @param adapter [Symbol] adapter type (default :memory, reserved for future use)
    # @return [Hecks::Services::Runtime]
    def boot(dir, adapter: :memory)
      domain_file = File.join(dir, "hecks_domain.rb")
      unless File.exist?(domain_file)
        raise Hecks::DomainLoadError, "No hecks_domain.rb found in #{dir}"
      end

      domain = eval(File.read(domain_file), TOPLEVEL_BINDING, domain_file, 1)

      valid, errors = validate(domain)
      unless valid
        errors.each { |e| $stderr.puts "  - #{e}" }
        raise Hecks::ValidationError, "Domain validation failed:\n#{errors.map { |e| "  - #{e}" }.join("\n")}"
      end

      output = build(domain, version: Time.now.strftime("%Y.%m.%d.1"), output_dir: dir)

      lib_path = File.join(output, "lib")
      $LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
      require domain.gem_name

      Services::Runtime.new(domain)
    end
  end
end
