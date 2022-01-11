# frozen_string_literal: true

case ENV['COVERAGE']
when 'deep'
  ENV['DEEP_COVER'] = 'true'
  require 'deep_cover'
when 'true'
  require 'deep_cover/builtin_takeover'
  require 'simplecov'
end

require 'asciidoctor/reducer'
require 'fileutils'
require 'pathname'
require 'shellwords'
require 'tempfile'

RSpec.configure do |config|
  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true
  end

  def fixtures_dir
    File.join __dir__, 'fixtures'
  end

  def fixture_file path, opts = {}
    if opts[:relative]
      (((Pathname.new fixtures_dir) / path).relative_path_from Pathname.new Dir.pwd).to_s
    else
      File.join fixtures_dir, path
    end
  end

  def output_dir
    (FileUtils.mkpath (File.join __dir__, 'output'))[0]
  end

  def with_tmp_file ext = '.adoc', &block
    Tempfile.create %W(asciidoctor-reducer- #{ext}), output_dir, &block
  end

  def with_memory_logger level = nil
    old_logger, logger = Asciidoctor::LoggerManager.logger, Asciidoctor::MemoryLogger.new
    logger.level = level if level
    Asciidoctor::LoggerManager.logger = logger
    yield logger
  ensure
    Asciidoctor::LoggerManager.logger = old_logger
  end

  def ruby
    Shellwords.escape File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']
  end
end

RSpec::Matchers.define :have_size do |expected|
  match {|actual| actual.size == expected }
  failure_message do |actual|
    %(expected #{RSpec::Support::ObjectFormatter.format actual} to have size #{expected}, but was #{actual.size})
  end
end
