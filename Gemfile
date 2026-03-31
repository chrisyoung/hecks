source "https://rubygems.org"

gemspec

%w[hecksties hecks_runtime hecks_multidomain hecks_workshop hecks_cli hecks_persist hecks_on_rails hecks_explorer hecks_ai hecks_watchers hecks_watcher_agent bluebook hecksagon].each do |component|
  gemspec path: component if File.exist?("#{component}/#{component}.gemspec")
end

group :development, :test do
  gem "rake"
  gem "rspec", "~> 3.0"
  gem "webrick"
  gem "railties", "~> 8.0"
  gem "sqlite3", ">= 1.4", "< 3.0"
  gem "rdoc", ">= 6.4", "< 6.7"
  gem "sdoc"
end
