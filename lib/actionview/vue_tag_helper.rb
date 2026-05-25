# frozen_string_literal: true

require "action_view"
require "bigdecimal"
require "active_support/core_ext/object/json"
require_relative "vue_tag_helper/version"
require_relative "vue_tag_helper/vue_builder"

module ActionView
  module Helpers
    # Provides the +vue+ view helper, a sibling of the built-in +tag+ helper
    # tuned for rendering Vue component markup.
    #
    # See ActionView::Helpers::TagHelper::VueBuilder for full documentation on
    # how attribute quoting differs from the standard TagBuilder.
    #
    # @example
    #   vue.MyComponent(label: "Hello", data: {items: [{id: 1}]})
    #   # => <my-component label="Hello" data-items='[{"id":1}]'></my-component>
    #
    module VueTagHelper
      # Returns the VueBuilder proxy for this view context.
      #
      # Every call within the same render cycle returns the same instance,
      # mirroring how +tag+ works.
      #
      # @return [ActionView::Helpers::TagHelper::VueBuilder]
      def vue
        @vue ||= TagHelper::VueBuilder.new(self)
      end
    end
  end
end

if defined?(Rails::Railtie)
  require_relative "vue_tag_helper/railtie"
else
  ActiveSupport.on_load(:action_view) { include ActionView::Helpers::VueTagHelper }
end
