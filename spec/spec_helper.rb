# frozen_string_literal: true

require "bundler/setup"
require "action_view"
require "actionview/vue_tag_helper"
require "haml/rails_template"
require "slim"

# Slim ships a Railtie that only runs inside a full Rails app. Register the
# ActionView template handler manually, mirroring what the Railtie does.
Slim::RailsTemplate = Temple::Templates::Rails(
  Slim::Engine,
  register_as:     :slim,
  generator:       Temple::Generators::RailsOutputBuffer,
  disable_capture: true,
  streaming:       true
)

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order                            = :random
  config.warnings                         = true
end

# Minimal view-context stub that satisfies ActionView::Helpers::TagHelper's
# dependency on +safe_join+ and +capture+.
class FakeViewContext
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::CaptureHelper
  include ActionView::Helpers::OutputSafetyHelper
  include ActionView::Helpers::VueTagHelper

  def output_buffer
    @output_buffer ||= ActionView::OutputBuffer.new
  end

  attr_writer :output_buffer
end
