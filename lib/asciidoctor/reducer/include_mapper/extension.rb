# frozen_string_literal: true

module Asciidoctor::Reducer
  class IncludeMapper < ::Asciidoctor::Extensions::TreeProcessor
    def process doc
      if doc.extensions.groups[:reducer]
        unless (includes = doc.catalog[:includes].select {|_, v| v }.keys).empty?
          doc.source_lines.concat ['', %(//# includes=#{includes.join ','})]
        end
      elsif (last_line = doc.source_lines[-1]) && (last_line.start_with? '//# includes=')
        doc.catalog[:includes].update ((last_line.slice 13, last_line.length).split ',').map {|it| [it, true] }.to_h
      end
      doc
    end
  end
end
