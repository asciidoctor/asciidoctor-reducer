# frozen_string_literal: true

require 'asciidoctor'
require 'asciidoctor/reducer'

puts Asciidoctor::Reducer::VERSION
puts Asciidoctor::Extensions.groups[:reducer] && 'loaded'
