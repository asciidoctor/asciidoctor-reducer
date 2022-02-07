# frozen_string_literal: true

autoload :OptionParser, 'optparse'
autoload :Pathname, 'pathname'

module Asciidoctor::Reducer
  autoload :VERSION, (::File.join __dir__, 'version.rb')

  class Cli
    LOG_LEVELS = (::Logger::Severity.constants false).each_with_object({}) do |level, accum|
      accum[level.to_s.downcase] = (::Logger::Severity.const_get level) unless level == :UNKNOWN
    end

    def parse args
      options = { attributes: {}, log_level: LOG_LEVELS['warn'], safe: :unsafe }

      opt_parser = ::OptionParser.new do |opts|
        opts.program_name = 'asciidoctor-reducer'
        opts.banner = <<~EOS
        Usage: #{opts.program_name} [OPTION]... FILE

        Reduces a composite AsciiDoc document containing includes and conditionals to a single AsciiDoc document.

        EOS

        opts.on '-o FILE', '--output=FILE', 'set the output filename or stream' do |file|
          options[:output_file] = file
        end

        opts.on '-a KEY[=VALUE]', '--attribute=KEY[=VALUE]',
          'set a document attribute in the AsciiDoc document: [key, key!, key=value]' do |attr|
          key, val = attr.split '=', 2
          val ||= ''
          options[:attributes][key] = val
        end

        opts.on '--preserve-conditionals', 'preserve preprocessor conditional directives in the reduced source' do
          options[:preserve_conditionals] = true
        end

        opts.on '--log-level LEVEL', LOG_LEVELS.keys,
          %(set the minimum level of messages to log: [#{LOG_LEVELS.keys.join ', '}] (default: warn)) do |level|
          options[:log_level] = LOG_LEVELS[level]
        end

        opts.on '-q', '--quiet', 'suppress all application log messages' do
          options[:log_level] = nil
        end

        opts.on '-h', '--help', 'display this help text and exit' do
          $stdout.write opts.help
          return 0
        end

        opts.on '-v', '--version', 'display the version information and exit' do
          $stdout.write %(#{opts.program_name} #{VERSION}\n)
          return 0
        end
      end

      args = opt_parser.parse args

      if args.empty?
        opt_parser.warn 'Please specify an AsciiDoc file to reduce.'
        $stdout.write opt_parser.help
        1
      elsif args.size == 1
        options[:input_file] = args[0]
        options[:output_file] = '-' unless options[:output_file]
        [0, options]
      else
        opt_parser.warn %(extra arguments detected (unparsed arguments: #{(args.drop 1).join ' '}))
        $stdout.write opt_parser.help
        [1, options]
      end
    rescue ::OptionParser::InvalidOption
      $stderr.write %(#{opt_parser.program_name}: #{$!.message}\n)
      $stdout.write opt_parser.help
      1
    end

    def self.run args = ARGV
      code, options = new.parse (Array args)
      return code unless code == 0 && options
      old_logger = ::Asciidoctor::LoggerManager.logger
      if (log_level = options.delete :log_level)
        (options[:logger] = ::Asciidoctor::Logger.new $stderr).level = log_level
      else
        options[:logger] = nil
      end
      if (output_file = options.delete :output_file) == '-'
        to = $stdout
      else
        (to = ::Pathname.new output_file).dirname.mkpath
      end
      if (input_file = options.delete :input_file) == '-'
        reduced = (::Asciidoctor.load $stdin, options).source + ?\n
      else
        reduced = (::Asciidoctor.load_file input_file, (options.merge to_file: false)).source + ?\n
      end
      ::Pathname === to ? (to.write reduced, encoding: ::Encoding::UTF_8) : (to.write reduced)
      0
    rescue
      $stderr.write %(asciidoctor-reducer: #{$!.message}\n)
      1
    ensure
      ::Asciidoctor::LoggerManager.logger = old_logger if old_logger
    end
  end
end
