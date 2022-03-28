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
require 'forwardable'
require 'open3' unless defined? Open3
require 'shellwords'
require 'socket'
require 'stringio'
require 'tempfile'

unless (Pathname.instance_method :rmtree).arity > 0
  autoload :FileUtils, 'fileutils'
  Pathname.prepend (Module.new do
    def rmtree **kwargs
      FileUtils.rm_rf @path, **kwargs
      nil
    end
  end)
end

class ScenarioBuilder
  extend ::Forwardable
  def_delegators :@example, :described_class, :subject, :the_expected_source, :the_input_source

  UNDEFINED = ::Object.new
  private_constant :UNDEFINED

  attr_reader :example
  attr_reader :result

  def initialize example
    @example = example
    @expected_log_messages = @expected_source = @input_file = @input_source = @output_file = @result = @verify = nil
    @files = []
    @reduce = proc { reduce_file input_file, **@reduce_options }
    @reduce_options = {}
  end

  def build &block
    instance_exec(&block)
    self
  end

  def create_file filename, contents, newline: :universal
    if ::Array === filename
      (file = with_tmp_file filename, newline: newline).write contents
      file.close
      filename = file.path
    else
      filename = fixture_file filename
      ::File.write filename, contents, encoding: 'UTF-8', newline: newline
    end
    @files << filename
    filename
  end

  def create_include_file source
    create_file %w(include- .adoc), source
  end

  def create_input_file source
    create_file %w(main- .adoc), source
  end

  def create_output_file
    (with_tmp_file %w(tmp- .adoc), tmpdir: output_dir).tap(&:close).path
  end

  def expected_log_messages *argv
    @expected_log_messages = argv
  end

  def expected_source source = UNDEFINED
    return @expected_source if source == UNDEFINED
    @expected_source = source.chomp
    verify do
      case @result
      when ::Asciidoctor::Document
        (@example.expect @result).to @example.have_source @expected_source
        if @output_file
          if ::String === @output_file
            actual_source = ::File.read @output_file, mode: 'rb:UTF-8'
          elsif @output_file.respond_to? :string
            actual_source = @output_file.string
          else
            @output_file.rewind if @output_file.eof?
            actual_source = @output_file.read
            @output_file.rewind
          end
          (@example.expect actual_source).to @example.eql @expected_source + ?\n
        end
      when ::String
        (@example.expect @result).to @example.eql @expected_source
      end
    end
    @expected_source
  end

  def input_file
    @input_file ||= (create_input_file @input_source)
  end

  def input_file_basename suffix = nil
    suffix ? (::File.basename input_file, suffix) : (::File.basename input_file)
  end

  def input_source source = UNDEFINED
    source == UNDEFINED ? @input_source : (@input_source = source.chomp)
  end

  def output_file file = UNDEFINED
    file == UNDEFINED ? @output_file : (@output_file = file)
  end

  def reduce value = UNDEFINED, &block
    value == UNDEFINED ? (block_given? ? (@reduce = block) : @reduce) : (@reduce = !!value)
  end

  def reduce_options opts = UNDEFINED
    opts == UNDEFINED ? @reduce_options : (@reduce_options = opts)
  end

  def run
    if @reduce
      if @expected_log_messages
        (@example.expect do
          @verify&.call if (@result = @reduce.call)
        end).to @example.log_messages(*@expected_log_messages)
      elsif (@result = @reduce.call)
        @verify&.call
      end
    end
    @result
  ensure
    @example = nil
    @files.each {|it| ::File.unlink it }
    freeze
  end

  def verify &block
    @verify = block
  end
end

RSpec.configure do |config|
  config.after :suite do
    (Pathname.new output_dir).rmtree secure: true
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

  def create_scenario &block
    (ScenarioBuilder.new block.binding.receiver).build(&block)
  end

  def describe_method refname, *args, &block
    describe refname, *args do
      subject { super().method refname.slice 1, refname.length }
      instance_exec(&block)
    end
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
    (p = (Pathname.new __dir__) / 'output').mkpath || p.to_s
  end

  def reduce_file input_file, opts = {}
    opts[:sourcemap] == false ? (opts.delete :sourcemap) : (opts[:sourcemap] = true)
    Asciidoctor::Reducer.reduce_file input_file, opts
  end

  def resolve_localhost
    Socket.ip_address_list.find(&:ipv4?).ip_address
  end

  def ruby
    cmd = Shellwords.escape File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']
    (defined? DeepCover) && !(DeepCover.const_defined? :TAKEOVER_IS_ON) ? %(#{cmd} -rdeep_cover) : cmd
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

  def run_scenario &block
    create_scenario(&block).run
  end

  def windows?
    Gem.win_platform?
  end

  def with_local_webserver host = resolve_localhost, port = 9876
    base_dir = fixtures_dir
    server = TCPServer.new host, port
    server_thread = Thread.start do
      Thread.current[:requests] = requests = []
      while (session = server.accept)
        requests << (request = session.gets)
        if %r/^GET (\S+) HTTP\/1\.1$/ =~ request.chomp
          resource = (resource = $1) == '' ? '.' : resource
        else
          session.print %(HTTP/1.1 405 Method Not Allowed\r\nContent-Type: text/plain\r\n\r\n405 - Method not allowed)
          session.close
          next
        end
        resource = (resource.split '?', 2)[0] if resource.include? '?'
        if File.file? (resource_file = (File.join base_dir, resource))
          if (ext = (File.extname resource_file)[1..-1])
            mimetype = ext == 'adoc' ? 'text/plain' : %(image/#{ext})
          else
            mimetype = 'text/plain'
          end
          session.print %(HTTP/1.1 200 OK\r\nContent-Type: #{mimetype}\r\n\r\n)
          File.open resource_file, mode: 'rb:UTF-8:UTF-8' do |fd|
            session.write fd.read 256 until fd.eof?
          end
        else
          session.print %(HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\n\r\n)
          session.print '404 - Resource not found.'
        end
        session.close
      end
    end
    begin
      yield %(http://#{host}:#{port}), server_thread
    ensure
      server_thread.exit
      server_thread.value
      server.close
    end
  end

  def with_memory_logger level = nil
    old_logger, logger = Asciidoctor::LoggerManager.logger, Asciidoctor::MemoryLogger.new
    logger.level = level if level
    Asciidoctor::LoggerManager.logger = logger
    yield logger
  ensure
    Asciidoctor::LoggerManager.logger = old_logger
  end

  def with_tmp_file basename = '.adoc', tmpdir: fixtures_dir, newline: :universal, &block
    basename = %W(tmp- #{basename}) unless Array === basename
    Tempfile.create basename, tmpdir, encoding: 'UTF-8', newline: newline, &block
  end
end

RSpec::Matchers.define :have_size do |expected|
  match {|actual| actual.size == expected }
  failure_message do |actual|
    %(expected #{RSpec::Support::ObjectFormatter.format actual} to have size #{expected}, but was #{actual.size})
  end
end

RSpec::Matchers.define :have_source do |expected|
  match {|actual| actual.source == expected }
  failure_message do |actual|
    message = %(expected #{actual} to have source #{expected.inspect})
    differ = RSpec::Expectations.differ
    (RSpec::Matchers::ExpectedsForMultipleDiffs.from expected).message_with_diff message, differ, actual.source
  end
end

RSpec::Matchers.define :have_message do |expected|
  actual = nil
  match notify_expectation_failures: true do |logger|
    messages = logger.messages
    expected_at = expected[:at] || 0
    next unless (actual = messages[expected_at]) && actual[:severity] == expected[:severity]
    actual_message = Hash === (actual_message = actual[:message]) ? actual_message[:text] : actual_message
    if Regexp === (expected_message = expected[:message])
      result = true if expected_message.match? actual_message
    elsif expected_message.start_with? '~'
      result = true if actual_message.start_with? expected_message.delete_prefix '~'
    elsif actual_message === expected_message
      result = true
    end
    (expect messages).to have_size expected_at + 1 if expected[:last]
    result
  end

  failure_message do
    if Regexp === (expected_message = expected[:message])
      match_clause = %(matching #{expected_message})
    elsif expected_message.start_with? '~'
      match_clause = %(starting with `#{expected_message.delete_prefix '~'}')
    else
      match_clause = %(`#{expected_message}')
    end
    %(expected #{expected[:severity]} message #{match_clause} to have been logged) +
      (actual ? %(, but got #{actual[:severity]} message `#{Hash === (m = actual[:message]) ? m[:text] : m}') : '')
  end
end

RSpec::Matchers.define :log_messages do |*expecteds, **opts|
  expecteds.empty? ? (expecteds, opts = [opts], {}) : (expecteds = expecteds.flatten)
  expecteds = [] unless expecteds.length > 1 || expecteds[0]
  match notify_expectation_failures: true do |actual|
    with_memory_logger opts[:using_log_level] do |logger|
      (expect Asciidoctor::LoggerManager.logger).to be logger
      actual.call
      if expecteds.empty?
        (expect logger.messages).to be_empty
      else
        expecteds.each_with_index do |expected, idx|
          expected[:at] = idx unless expected.key? :at
          (expect logger).to have_message expected
        end
      end
    end
    true
  end

  supports_block_expectations
end
