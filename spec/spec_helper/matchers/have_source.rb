# frozen_string_literal: true

RSpec::Matchers.define :have_source do |expected|
  match {|actual| actual.source == expected }
  failure_message do |actual|
    message = %(expected #{actual} to have source #{expected.inspect})
    differ = RSpec::Expectations.differ
    (RSpec::Matchers::MultiMatcherDiff.from expected, actual.source).message_with_diff message, differ
  end
end
