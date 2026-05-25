# frozen_string_literal: true

RSpec.describe ActionView::Helpers::VueTagHelper do
  describe "on_load wiring" do
    it "is included into ActionView::Base by the on_load hook" do
      expect(ActionView::Base.ancestors).to include(described_class)
    end
  end

  describe "ActionView::Base instance" do
    subject(:view) do
      ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
    end

    it "responds to #vue" do
      expect(view).to respond_to(:vue)
    end

    it "#vue returns a VueBuilder" do
      expect(view.vue).to be_an_instance_of(ActionView::Helpers::TagHelper::VueBuilder)
    end

    it "renders a component with a string attribute" do
      expect(view.vue.my_component(label: "Hello")).to \
        eq %(<my-component label="Hello"></my-component>)
    end

    it "renders a v-bind typed attribute" do
      expect(view.vue.x_counter(count: 42)).to \
        eq %(<x-counter :count="42"></x-counter>)
    end

    it "renders a data: sub-hash" do
      expect(view.vue.my_component(data: { items: %w[a b] })).to \
        eq %(<my-component data-items='["a","b"]'></my-component>)
    end
  end
end
