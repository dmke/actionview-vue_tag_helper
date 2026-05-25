# frozen_string_literal: true

RSpec.describe ActionView::Helpers::VueTagHelper do
  describe "fixture rendering" do
    let(:view) do
      templates_path = File.expand_path("../../fixtures/templates", __dir__)
      lookup_context = ActionView::LookupContext.new([templates_path])
      ActionView::Base.with_empty_template_cache.new(lookup_context, {}, nil)
    end

    def render(name)
      template, _, handler = name.split(".")
      view.render(template:, handlers: [handler.to_sym])
    end

    it "renders ERB to HTML" do
      expect(render("test.html.erb")).to match_fixture("rendered/test-erb.html")
    end

    it "renders HAML to HTML" do
      expect(render("test.html.haml")).to match_fixture("rendered/test-haml.html")
    end

    it "renders Slim to HTML" do
      expect(render("test.html.slim")).to match_fixture("rendered/test-slim.html")
    end
  end
end
