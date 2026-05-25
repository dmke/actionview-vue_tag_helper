# frozen_string_literal: true

require_relative "lib/actionview/vue_tag_helper/version"

Gem::Specification.new do |spec|
  spec.name    = "actionview-vue_tag_helper"
  spec.version = ActionView::VueTagHelper::VERSION
  spec.authors = ["Dominik Menke"]

  spec.summary     = "ActionView helper for embedding Vue component islands in server-rendered HTML"
  spec.description = <<~DESC
    Extends ActionView with a `vue` helper for the Islands architecture: Vue
    components mounted on otherwise static, server-rendered pages. Unlike the
    built-in `tag` helper, it emits v-bind shorthand for typed props, switches
    to single-quote attribute delimiters when values contain double quotes (e.g.
    JSON), and validates that tag names are legal kebab-cased custom element names.
  DESC

  spec.homepage = "https://github.com/dmke/actionview-vue_tag_helper"
  spec.license  = "MIT"

  spec.required_ruby_version             = ">= 4.0"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = spec.homepage
  spec.metadata["bug_tracker_uri"]       = "#{spec.homepage}/issues"
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*.rb",
    "CHANGELOG.md",
    "LICENSE.txt",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "actionview", ">= 8.0"
end
