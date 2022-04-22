# frozen_string_literal: true

require_relative 'api'
autoload :OptionParser, 'optparse'

module Asciidoctor::Reducer
  module Cli
    class << self
      def parse args
        options = { attributes: {}, log_level: LOG_LEVELS['warn'], safe: :unsafe }

        opt_parser = ::OptionParser.new do |opts|
          opts.program_name = 'asciidoctor-reducer'
          opts.banner = <<~END
          Usage: #{opts.program_name} [OPTION]... FILE

          #{::Gem.loaded_specs['asciidoctor-reducer'].summary}

          END

          opts.on '-a KEY[=VALUE]', '--attribute=KEY[=VALUE]',
            'set a document attribute in the AsciiDoc document: [key, key!, key=value]',
            'may be specified multiple times' do |attr|
            key, val = attr.split '=', 2
            val ||= ''
            options[:attributes][key] = val
          end

          opts.on '--log-level LEVEL', %w(debug info warn error fatal),
            'set the minimum level of messages to log: [debug, info, warn, error, fatal] (default: warn)' do |level|
            options[:log_level] = level
          end

          opts.on '-o FILE', '--output=FILE', 'set the output filename or stream' do |file|
            options[:output_file] = file
          end

          opts.on '--preserve-conditionals', 'preserve preprocessor conditional directives in the reduced source' do
            options[:preserve_conditionals] = true
          end

          opts.on '-q', '--quiet', 'suppress all application log messages' do
            options[:log_level] = nil
          end

          opts.on '-rLIBRARY', '--require LIBRARY', 'require the specified library or libraries before reducing',
            'may be specified multiple times' do |path|
            (options[:requires] ||= []).concat path.split ','
          end

          opts.on '-S', '--safe-mode SAFE_MODE', ['unsafe', 'safe', 'server', 'secure'],
            'set safe mode level: [unsafe, safe, server, secure] (default: unsafe)' do |name|
            options[:safe] = name.to_sym
          end

          opts.on '--trace', 'trace the cause of application errors (default: false)' do
            options[:trace] = true
          end

          opts.on '-v', '--version', 'display the version information and exit' do
            print_version opts
            return 0
          end

          opts.on '-h', '--help', 'display this help text and exit' do
            print_help opts
            return 0
          end
        end

        if (args = opt_parser.parse args).empty?
          opt_parser.warn 'Please specify an AsciiDoc file to reduce.'
          print_help opt_parser
          1
        elsif args.size == 1
          if (requires = options.delete :requires)
            requires.uniq.each do |path|
              require path
            rescue ::LoadError
              $stderr.puts %(#{opt_parser.program_name}: '#{path}' could not be required (reason: #{$!.message}))
              return 1
            end
          end
          options[:input_file] = args[0]
          options[:output_file] = '-' unless options[:output_file]
          [0, options]
        else
          opt_parser.warn %(extra arguments detected (unparsed arguments: #{(args.drop 1).join ' '}))
          print_help opt_parser
          1
        end
      rescue ::OptionParser::InvalidOption
        $stderr.puts %(#{opt_parser.program_name}: #{$!.message})
        print_help opt_parser
        1
      end

      def run args = ARGV
        code, options = parse (Array args)
        return code unless code == 0 && options
        trace = options.delete :trace
        old_logger = ::Asciidoctor::LoggerManager.logger
        if (log_level = options.delete :log_level)
          (options[:logger] = ::Asciidoctor::Logger.new $stderr).level = log_level
        else
          options[:logger] = nil
        end
        options[:to] = (output_file = options.delete :output_file) == '-' ? $stdout : (::Pathname.new output_file)
        input = (input_file = options.delete :input_file) == '-' ? $stdin : (::Pathname.new input_file)
        ::Asciidoctor::Reducer.reduce input, options
        0
      rescue ::SignalException
        $stderr.puts if ::Interrupt === $!
        $!.signo
      rescue
        raise $! if trace
        $stderr.puts %(asciidoctor-reducer: #{$!.message.delete_prefix 'asciidoctor: '})
        $stderr.puts '  Use --trace to show backtrace'
        1
      ensure
        ::Asciidoctor::LoggerManager.logger = old_logger if old_logger
      end

      private

      def print_help opt_parser
        $stdout.puts opt_parser.help.chomp
      end

      def print_version opt_parser
        $stdout.puts %(#{opt_parser.program_name} #{VERSION})
      end
    end

    LOG_LEVELS = (::Logger::Severity.constants false).each_with_object({}) do |level, accum|
      accum[level.to_s.downcase] = (::Logger::Severity.const_get level) unless level == :UNKNOWN
    end

    private_constant :LOG_LEVELS
  end
end
