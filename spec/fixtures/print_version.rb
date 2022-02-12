# frozen_string_literal: true

require 'asciidoctor/reducer'

puts Asciidoctor::Reducer::VERSION
puts Asciidoctor::Extensions.groups[:reducer] && 'loaded'
