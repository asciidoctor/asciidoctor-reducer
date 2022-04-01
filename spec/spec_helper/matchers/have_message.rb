# frozen_string_literal: true

RSpec::Matchers.define :have_message do |expected|
  actual = nil
  match notify_expectation_failures: true do |logger|
    messages = logger.messages
    expected_at = expected[:at] || 0
    next unless (actual = messages[expected_at]) && actual[:severity] == expected[:severity]
    actual_message = Hash === (actual_message = actual[:message]) ? actual_message[:text] : actual_message
    if Regexp === (expected_message = expected[:message])
      result = true if expected_message.match? actual_message
    elsif expected_message.start_with? '~'
      result = true if actual_message.start_with? expected_message.delete_prefix '~'
    elsif actual_message === expected_message
      result = true
    end
    (expect messages).to have_size expected_at + 1 if expected[:last]
    result
  end

  failure_message do
    if Regexp === (expected_message = expected[:message])
      match_clause = %(matching #{expected_message})
    elsif expected_message.start_with? '~'
      match_clause = %(starting with `#{expected_message.delete_prefix '~'}')
    else
      match_clause = %(`#{expected_message}')
    end
    %(expected #{expected[:severity]} message #{match_clause} to have been logged) +
      (actual ? %(, but got #{actual[:severity]} message `#{Hash === (m = actual[:message]) ? m[:text] : m}') : '')
  end
end
