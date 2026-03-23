# Hecks::CLI init command
#
module Hecks
  class CLI < Thor
    desc "init [NAME]", "Initialize a Hecks domain in the current directory"
    def init(name = nil)
      if File.exist?("hecks_domain.rb")
        say "domain.rb already exists in this directory", :yellow
        return
      end
      name ||= File.basename(Dir.pwd).split(/[_\-\s]/).map(&:capitalize).join
      File.write("hecks_domain.rb", domain_template(name))
      File.write("verbs.txt", "# Add custom action verbs here (one per line)\n# WordNet handles most English verbs automatically\n")
      File.write(".hecks_version", "")
      say "Initialized Hecks domain: #{name}", :green
      say "  domain.rb   — define your domain here"
      say "  verbs.txt   — add custom action verbs (optional)"
      say ""
      say "Next steps:"
      say "  hecks console   # edit interactively"
      say "  hecks build     # generate the domain gem"
    end
  end
end
