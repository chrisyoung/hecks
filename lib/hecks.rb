# = Hecks (meta-gem loader)
#
# Adds all sub-gem lib/ directories to $LOAD_PATH so that a single
# `gem "hecks", path: "..."` in a Gemfile is enough to use the
# entire framework — no individual sub-gem entries needed.
#
#   gem "hecks", path: "../.."
#
root = File.expand_path("../..", __FILE__)
Dir[File.join(root, "*/lib")].each do |lib_dir|
  $LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
end

# Now that hecksties/lib is on the load path, load the real Hecks module.
# Remove ourselves from $LOADED_FEATURES so the real hecks.rb can load.
$LOADED_FEATURES.delete(__FILE__)
require "hecks/version"
load File.join(root, "hecksties", "lib", "hecks.rb")
