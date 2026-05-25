# frozen_string_literal: true

require "fileutils"

FIXTURE_DIR = File.expand_path("../../fixtures", __dir__)

RSpec::Matchers.define :match_fixture do |fixture_name|
  match do |actual|
    @fixture_file = File.join(FIXTURE_DIR, fixture_name)

    if ENV["REGENERATE_FIXTURES"] == "1"
      FileUtils.mkdir_p(File.dirname(@fixture_file))
      File.write(@fixture_file, actual)
    elsif !File.exist?(@fixture_file)
      raise <<~MSG.strip
        Fixture file not found: #{@fixture_file}
        Run with REGENERATE_FIXTURES=1 to generate it.
      MSG
    end

    @fixture_content = File.read(@fixture_file)
    actual == @fixture_content
  end

  failure_message do |actual|
    <<~MSG.chomp
      expected output to match fixture #{fixture_name.inspect}
        file: #{@fixture_file}

      --- expected
      #{@fixture_content}
      +++ actual
      #{actual}
    MSG
  end

  failure_message_when_negated do |_actual|
    "expected output not to match fixture #{fixture_name.inspect}"
  end
end
