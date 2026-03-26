# Hecks::CLI::Domain#init
#
# Scaffolds a new Hecks domain in the current directory. Creates hecks_domain.rb
# with a starter template, verbs.txt for custom action verbs, and .hecks_version.
#
#   hecks domain init [NAME]
#
module Hecks
  class CLI < Thor
    class Domain < Thor
      desc "init [NAME]", "Initialize a Hecks domain in the current directory"
      option :force, type: :boolean, desc: "Overwrite without prompting"
      # Initializes a Hecks domain in the current directory.
      #
      # Creates three files:
      # - hecks_domain.rb: the domain definition with a starter aggregate
      # - verbs.txt: for custom action verbs (WordNet handles most automatically)
      # - .hecks_version: CalVer version tracking file
      #
      # If name is not provided, derives it from the current directory name
      # by splitting on underscores/hyphens/spaces and PascalCasing.
      #
      # @param name [String, nil] the domain name in PascalCase; auto-derived if nil
      # @return [void]
      def init(name = nil)
        name ||= File.basename(Dir.pwd).split(/[_\-\s]/).map(&:capitalize).join
        write_or_diff("hecks_domain.rb", domain_template(name))
        write_or_diff("verbs.txt", "# Add custom action verbs here (one per line)\n# WordNet handles most English verbs automatically\n")
        write_or_diff(".hecks_version", "")
        say "Initialized Hecks domain: #{name}", :green
        say "  domain.rb   — define your domain here"
        say "  verbs.txt   — add custom action verbs (optional)"
        say ""
        say "Next steps:"
        say "  hecks domain console   # edit interactively"
        say "  hecks domain build     # generate the domain gem"
      end
    end
  end
end
