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
require 'fileutils'
require 'open3' unless defined? Open3
require 'shellwords'
require 'stringio'
require 'tempfile'

RSpec.configure do |config|
  config.after :suite do
    FileUtils.rm_r output_dir, force: true, secure: true
  end

  def bin_script name, opts = {}
    bin_path = Gem.bin_path (opts.fetch :gem, 'asciidoctor-reducer'), name
    if (defined? DeepCover) && !(DeepCover.const_defined? :TAKEOVER_IS_ON)
      [Gem.ruby, '-rdeep_cover', bin_path]
    elsif Gem.win_platform?
      [Gem.ruby, bin_path]
    else
      bin_path
    end
  end

  def asciidoctor_reducer_bin
    bin_script 'asciidoctor-reducer'
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

  def jruby?
    RUBY_ENGINE == 'jruby'
  end

  def output_dir
    (FileUtils.mkpath (File.join __dir__, 'output'))[0]
  end

  def reduce_file input_file, opts = {}
    opts[:sourcemap] == false ? (opts.delete :sourcemap) : (opts[:sourcemap] = true)
    Asciidoctor::Reducer.reduce_file input_file, opts
  end

  def run_command cmd, *args
    Dir.chdir __dir__ do
      if Array === cmd
        args.unshift(*cmd)
        cmd = args.shift
      end
      kw_args = Hash === args[-1] ? args.pop : {}
      env_override = kw_args[:env] || {}
      if (out = kw_args[:out])
        Open3.pipeline_w([env_override, cmd, *args, out: out]) {} # rubocop:disable Lint/EmptyBlock
      else
        Open3.capture3 env_override, cmd, *args
      end
    end
  end

  def windows?
    Gem.win_platform?
  end

  def with_tmp_file ext = '.adoc', &block
    Tempfile.create %W(asciidoctor-reducer- #{ext}), output_dir, encoding: 'UTF-8', newline: :universal, &block
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
    cmd = Shellwords.escape File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']
    (defined? DeepCover) && !(DeepCover.const_defined? :TAKEOVER_IS_ON) ? %(#{cmd} -rdeep_cover) : cmd
  end
end

RSpec::Matchers.define :have_size do |expected|
  match {|actual| actual.size == expected }
  failure_message do |actual|
    %(expected #{RSpec::Support::ObjectFormatter.format actual} to have size #{expected}, but was #{actual.size})
  end
end
