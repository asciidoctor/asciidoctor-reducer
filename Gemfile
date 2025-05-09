# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'asciidoctor', ENV['ASCIIDOCTOR_VERSION'], require: false if ENV.key? 'ASCIIDOCTOR_VERSION'
if (Gem::Version.new RUBY_VERSION) >= (Gem::Version.new '3.3.0')
  gem 'logger'
end

group :coverage do
  gem 'deep-cover-core', '~> 1.1.0', require: false
  gem 'simplecov', '~> 0.22.0', require: false
end

group :docs do
  gem 'yard', require: false
end

group :lint do
  gem 'rubocop', '~> 1.75.0', require: false
  gem 'rubocop-rake', '~> 0.7.0', require: false
  gem 'rubocop-rspec', '~> 3.6.0', require: false
end unless (Gem::Version.new RUBY_VERSION) < (Gem::Version.new '2.7.0')
