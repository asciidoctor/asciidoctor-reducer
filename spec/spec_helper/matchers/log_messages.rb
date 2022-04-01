# frozen_string_literal: true

RSpec::Matchers.define :log_messages do |*expecteds, **opts|
  expecteds.empty? ? (expecteds, opts = [opts], {}) : (expecteds = expecteds.flatten)
  expecteds = [] unless expecteds.length > 1 || expecteds[0]
  match notify_expectation_failures: true do |actual|
    with_memory_logger opts[:using_log_level] do |logger|
      (expect Asciidoctor::LoggerManager.logger).to be logger
      actual.call
      if expecteds.empty?
        (expect logger.messages).to be_empty
      else
        expecteds.each_with_index do |expected, idx|
          expected[:at] = idx unless expected.key? :at
          (expect logger).to have_message expected
        end
      end
    end
    true
  end

  supports_block_expectations
end
