source 'https://rubygems.org'

ruby File.read('.ruby-version').chomp

gem 'bootsnap', require: false
gem 'dotenv-rails'
gem 'http'
gem 'rails', '~> 8.0.2'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'solid_queue'
gem 'tzinfo-data'

group :development, :test do
  gem 'brakeman', require: false
  gem 'debug', platforms: %i[ mri windows ], require: 'debug/prelude'
  gem 'factory_bot_rails'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'webmock'
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end
