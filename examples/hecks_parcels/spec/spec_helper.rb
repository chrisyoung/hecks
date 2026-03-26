require "hecks"
app = Hecks.boot(File.join(__dir__, ".."))

RSpec.configure do |config|
  config.order = :random
end
