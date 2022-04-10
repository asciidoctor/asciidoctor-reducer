# frozen_string_literal: true

require 'delegate'

class ScenarioBuilder < SimpleDelegator
  UNDEFINED = ::Object.new

  attr_reader :result

  def initialize example
    super
    @chdir = ::Dir.pwd
    @expected_exit_status = 0
    @expected_log_messages = @expected_source = @include_source = @input_source = @output_file = @result = nil
    @files = []
    @finally = @verify = nil
    @reduce = proc { ::Asciidoctor::Reducer.reduce_file input_file, **reduce_options }
    @reduce_options = {}
  end

  def build &block
    instance_exec(&block)
    self
  ensure
    finalize if $!
  end

  def chdir dir
    @chdir = dir
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

  def create_extension_file source
    create_file %w(ext- .rb), source
  end

  def create_include_file source, subdir: nil
    create_file [subdir ? (File.join subdir, 'include-') : 'include-', '.adoc'], source
  end

  def create_input_file source, subdir: nil
    create_file [subdir ? (File.join subdir, 'main-') : 'main-', '.adoc'], source
  end

  def create_output_file
    (with_tmp_file %w(tmp- .adoc), tmpdir: output_dir).tap(&:close).path
  end

  def expected_exit_status status = UNDEFINED
    status == UNDEFINED ? @expected_exit_status : (@expected_exit_status = status)
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
        (expect @result).to have_source @expected_source
        verify_output_file = true if @output_file
      when ::String
        (expect @result).to eql @expected_source
      when ::Integer
        (expect @result).to eql @expected_exit_status
        verify_output_file = true if @output_file
      end
      if verify_output_file
        if ::String === @output_file
          actual_source = ::File.read @output_file, mode: 'rb:UTF-8'
        elsif @output_file.respond_to? :string
          actual_source = @output_file.string
        else
          @output_file.rewind if @output_file.eof?
          actual_source = @output_file.read
          @output_file.rewind
        end
        (expect actual_source).to eql @expected_source + (@expected_source.empty? ? '' : ?\n)
      end
    end
    @expected_source
  end

  def finally &block
    @finally = block
  end

  def include_file file = UNDEFINED, **kwargs
    file == UNDEFINED ? (@include_file ||= (create_include_file @include_source, **kwargs)) : (@include_file = file)
  end

  def include_file_basename suffix = nil
    suffix ? (::File.basename include_file, suffix) : (::File.basename include_file)
  end

  def include_source source = UNDEFINED
    source == UNDEFINED ? @include_source : (@include_source = source.chomp)
  end

  def input_file file = UNDEFINED
    file == UNDEFINED ? (@input_file ||= (create_input_file @input_source)) : (@input_file = file)
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
      ::Dir.chdir @chdir do
        if @expected_log_messages
          expect do
            if (@result = @reduce.call)
              @verify&.call @result
            end
          end.to log_messages(*@expected_log_messages)
        elsif (@result = @reduce.call)
          @verify&.call @result
        end
      end
    end
    @result
  ensure
    finalize
    freeze
  end

  def verify &block
    @verify = block
  end

  private

  def finalize
    @finally&.call
    @files.reject! {|it| ::File.unlink it }
    __setobj__ nil
  end

  private_constant :UNDEFINED
end
