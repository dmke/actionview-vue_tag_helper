# frozen_string_literal: true

require "rails/railtie"

module ActionView
  module VueTagHelper
    # Integrates the +vue+ view helper into Rails applications.
    #
    # When Rails is present this Railtie is required automatically and the
    # helper is included into +ActionView::Base+ via the +:action_view+ load
    # hook, which is the correct integration point for ActionView extensions.
    class Railtie < Rails::Railtie
      initializer "vue_tag_helper.action_view" do
        ActiveSupport.on_load(:action_view) do
          include ActionView::Helpers::VueTagHelper
        end
      end
    end
  end
end
