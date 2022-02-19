# frozen_string_literal: true

Asciidoctor::Extensions.register do
  preprocessor do
    process do |doc|
      signal = doc.attr 'signal'
      Process.kill signal, Process.pid
      sleep
    end
  end
end
