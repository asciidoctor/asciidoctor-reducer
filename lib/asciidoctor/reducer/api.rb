# frozen_string_literal: true

autoload :Pathname, 'pathname'
require_relative 'extensions'

module Asciidoctor::Reducer
  autoload :VERSION, (::File.join __dir__, 'version.rb')

  class << self
    # Reduces the AsciiDoc source and either returns the reduced Asciidoctor::Document or writes the source to a file.
    #
    # This method accepts all the options supported by Asciidoctor.load.
    #
    # @param input [String, File, Pathname] the AsciiDoc source to reduce.
    # @param opts [Hash] additional options to configure the behavior of the reducer.
    # @option opts [File, Pathname, Class] :to (nil) the target to which to write the reduced source.
    #
    # @return [Asciidoctor::Document, nil] the reduced document object or nil if the :to option is specified.
    def reduce input, opts = {}
      opts = opts&.merge || {}
      if (extension_registry = Extensions.prepare_registry opts[:extension_registry] || opts[:extensions])
        opts[:extension_registry] = extension_registry
      end
      opts[:safe] ||= :safe
      to = opts.delete :to
      case input
      when ::File
        doc = ::Asciidoctor.load_file input, opts
      when ::Pathname
        doc = ::Asciidoctor.load_file input.to_path, opts
      else
        doc = ::Asciidoctor.load input, opts
      end
      write doc, to
    end

    # Reduces the AsciiDoc file and either returns the reduced Asciidoctor::Document or writes the source to a file.
    #
    # This method accepts all the options supported by Asciidoctor.load.
    #
    # @param input_file [String] the path of the AsciiDoc file to reduce.
    # @param opts [Hash] additional options to configure the behavior of the reducer.
    # @option opts [File, Pathname, Class] :to (nil) the target to which to write the reduced source.
    #
    # @return [Asciidoctor::Document, nil] the reduced document object or nil if the :to option is specified.
    def reduce_file input_file, opts = {}
      reduce (::Pathname.new input_file), opts
    end

    private

    def write doc, to
      return doc unless to && to != '/dev/null'
      output = doc.source
      return output if to == ::String
      output += LF unless output.empty?
      if ::Pathname === to || (!(to.respond_to? :write) && (to = ::Pathname.new to.to_s))
        to.dirname.mkpath
        to.write output, encoding: UTF_8, newline: :universal
      else
        to.write output
      end
      doc
    end
  end

  LF = ?\n
  UTF_8 = ::Encoding::UTF_8

  private_constant :LF, :UTF_8
end
