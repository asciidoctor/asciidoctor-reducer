# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new :spec do |t|
    t.verbose = true
    opts = %W(-f#{ENV['CI'] && ENV['COVERAGE'] ? 'd' : 'p'} --order random)
    opts.unshift '-w' if $VERBOSE || ENV['COVERAGE']
    t.rspec_opts = opts
  end
rescue LoadError
  warn $!.message
end
