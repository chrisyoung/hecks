source "https://rubygems.org"

gemspec

%w[hecksties hecks_model hecks_domain hecks_runtime hecks_session hecks_cli hecks_persist hecks_on_rails].each do |component|
  gemspec path: component if File.exist?("#{component}/#{component}.gemspec")
end

group :development, :test do
  gem "rake"
  gem "rspec", "~> 3.0"
  gem "sqlite3", ">= 1.4", "< 3.0"
end
