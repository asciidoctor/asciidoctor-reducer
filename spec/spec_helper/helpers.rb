# frozen_string_literal: true

require 'shellwords'
require 'socket'
require 'open3'
require 'tempfile'
require_relative 'scenario_builder'

module RSpec::ExampleGroupHelpers
  def describe_method refname, *args, &block
    describe refname, *args do
      subject { super().method refname.slice 1, refname.length }
      instance_exec(&block)
    end
  end

  def windows?
    Gem.win_platform?
  end
end

module RSpec::ExampleHelpers
  ROOT_DIR = File.absolute_path (File.join __dir__, '..', '..')
  SPEC_DIR = File.absolute_path (File.join __dir__, '..')

  def asciidoctor_reducer_bin
    bin_script 'asciidoctor-reducer'
  end

  def bin_script name, gem_name: 'asciidoctor-reducer'
    bin_path = Gem.bin_path gem_name, name
    if (defined? DeepCover) && !(DeepCover.const_defined? :TAKEOVER_IS_ON)
      [Gem.ruby, '-rdeep_cover', bin_path]
    elsif Gem.win_platform?
      [Gem.ruby, bin_path]
    else
      bin_path
    end
  end

  def create_scenario &block
    (ScenarioBuilder.new block.binding.receiver).build(&block)
  end

  def fixtures_dir
    File.join SPEC_DIR, 'fixtures'
  end

  def fixture_file path, relative: false
    if relative
      (((Pathname.new fixtures_dir) / path).relative_path_from Pathname.new Dir.pwd).to_s
    else
      File.join fixtures_dir, path
    end
  end

  def jruby?
    RUBY_ENGINE == 'jruby'
  end

  def output_dir
    ((Pathname.new SPEC_DIR) / 'output').tap(&:mkpath).to_s
  end

  def resolve_localhost
    Socket.ip_address_list.find(&:ipv4?).ip_address
  end

  def ruby
    cmd = Shellwords.escape File.join RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']
    (defined? DeepCover) && !(DeepCover.const_defined? :TAKEOVER_IS_ON) ? %(#{cmd} -rdeep_cover) : cmd
  end

  def run_command cmd, *args
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

  def run_scenario &block
    create_scenario(&block).run
  end

  def unrequire name
    $".delete File.expand_path %(lib/#{name}.rb), ROOT_DIR
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
    if Array === basename
      if basename[0].include? '/'
        prefix, ext = basename
        subdir, _, prefix = prefix.rpartition '/'
        tmpdir = fixture_file subdir
        basename = [prefix, ext]
      end
    else
      basename = ['tmp-', basename]
    end
    Tempfile.create basename, tmpdir, encoding: 'UTF-8', newline: newline, &block
  end
end
