# frozen_string_literal: true

case ENV['COVERAGE']
when 'deep'
  ENV['DEEP_COVER'] = 'true'
  require 'deep_cover'
when 'true'
  require 'deep_cover/builtin_takeover'
  require 'simplecov'
end

require 'asciidoctor/reducer/api'
require 'asciidoctor/reducer/cli'
require 'stringio'
require_relative 'spec_helper/ext/pathname'
require_relative 'spec_helper/helpers'
require_relative 'spec_helper/matchers'

RSpec.configure do |config|
  config.after :suite do
    (Pathname.new (Object.new.extend RSpec::ExampleHelpers).output_dir).rmtree secure: true
  end
  config.extend RSpec::ExampleGroupHelpers
  config.include RSpec::ExampleHelpers
end
