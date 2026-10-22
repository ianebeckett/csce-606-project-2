source "https://rubygems.org"

ruby "4.0.1"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "delayed_job_active_record", "~> 4.1"
gem "importmap-rails"
gem "jbuilder"
gem "bcrypt", "~> 3.1"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false
gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "minitest"
  gem "simplecov", require: false
  gem "rspec-rails", "~> 8.0", require: false
  gem "cucumber-rails", "~> 4.1", require: false
  gem "capybara", "~> 3.40", require: false
  gem "database_cleaner-active_record", "~> 2.2", require: false
end

group :development do
  gem "web-console"
  gem "rubocop", require: false
end
