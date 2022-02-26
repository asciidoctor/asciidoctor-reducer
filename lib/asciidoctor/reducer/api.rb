# frozen_string_literal: true

autoload :Pathname, 'pathname'
require_relative 'extensions'

module Asciidoctor::Reducer
  autoload :VERSION, (::File.join __dir__, 'version.rb')

  class << self
    def reduce input, opts = {}
      opts = opts.merge extension_registry: (Extensions.prepare_registry opts[:extension_registry] || opts[:extensions])
      opts[:safe] = ::Asciidoctor::SafeMode::SAFE unless opts.key? :safe
      case input
      when ::File
        doc = ::Asciidoctor.load_file input, opts
      when ::Pathname
        doc = ::Asciidoctor.load_file input.to_path, opts
      else
        doc = ::Asciidoctor.load input, opts
      end
      write doc, opts[:to]
    end

    def reduce_file input_file, opts = {}
      reduce (::Pathname.new input_file), opts
    end

    private

    def write doc, to
      if to && to != '/dev/null'
        output = doc.source
        return output if to == ::String
        output += LF unless output.empty?
        if ::Pathname === to || (!(to.respond_to? :write) && (to = ::Pathname.new to.to_s))
          to.dirname.mkpath
          to.write output, encoding: UTF_8
        else
          to.write output
        end
      end
      doc
    end
  end

  LF = ?\n
  UTF_8 = ::Encoding::UTF_8

  private_constant :LF, :UTF_8
end
