# frozen_string_literal: true

RSpec.describe ActionView::Helpers::TagHelper::VueBuilder do
  subject(:vue) { ctx.vue }

  let(:ctx) { FakeViewContext.new }

  describe "tag name validation" do
    context "with valid names" do
      it { expect { vue.my_component }.not_to raise_error }
      it { expect { vue.my_feed_item }.not_to raise_error }
      it { expect { vue.MyComponent }.not_to raise_error }
      it { expect { vue.MyFeedItem }.not_to raise_error }
      it { expect { vue.my_Component }.not_to raise_error }
    end

    context "with invalid names" do
      it "raises InvalidTagNameError for a plain lowercase word with no hyphen" do
        expect { vue.div }.to raise_error(described_class::InvalidTagNameError, /"div"/)
      end

      it "raises InvalidTagNameError for a single PascalCase word that reduces to one segment" do
        expect { vue.Div }.to raise_error(described_class::InvalidTagNameError, /"Div" \(normalised to "div"\)/)
      end

      it "raises InvalidTagNameError for a name that starts with a digit" do
        expect { vue.send(:"1_thing") }.to raise_error(described_class::InvalidTagNameError)
      end

      it "is rescued by a plain ArgumentError rescue" do
        expect { vue.div }.to raise_error(ArgumentError)
      end
    end
  end

  describe "basic tag generation" do
    it { expect(vue.x_el).to eq "<x-el></x-el>" }
    it { expect(vue.x_el("hello")).to eq "<x-el>hello</x-el>" }
    it { expect(vue.x_el { "world" }).to eq "<x-el>world</x-el>" }
    it { expect(vue.my_component).to eq "<my-component></my-component>" }
    it { expect(vue.my_feed_item).to eq "<my-feed-item></my-feed-item>" }
    it { expect(vue.MyComponent).to eq "<my-component></my-component>" }
    it { expect(vue.BBtn).to eq "<b-btn></b-btn>" }
    it { expect(vue.MyFeedItem).to eq "<my-feed-item></my-feed-item>" }
    it { expect(vue.MyComponent).to eq vue.my_component }
    it { expect(vue.my_input).to match(%r{</my-input>\z}) }
  end

  describe "double-quote delimiters" do
    it { expect(vue.XEl(label: "Hello")).to     eq %(<x-el label="Hello"></x-el>) }
    it { expect(vue.XEl(variant: :primary)).to  eq %(<x-el variant="primary"></x-el>) }
    it { expect(vue.XEl(label: nil)).to         eq "<x-el></x-el>" }
    it { expect(vue.XEl(class: %w[foo bar])).to eq %(<x-el class="foo bar"></x-el>) }
  end

  describe "typed attributes (v-bind shorthand)" do
    it { expect(vue.XEl(disabled: true)).to         eq "<x-el disabled></x-el>" }
    it { expect(vue.XEl(disabled: false)).to        eq %(<x-el :disabled="false"></x-el>) }
    it { expect(vue.XEl(count: 42)).to              eq %(<x-el :count="42"></x-el>) }
    it { expect(vue.XEl(ratio: 1.5)).to             eq %(<x-el :ratio="1.5"></x-el>) }
    it { expect(vue.XEl(items: %w[a b])).to         eq %(<x-el :items='["a","b"]'></x-el>) }
    it { expect(vue.XEl(ids: [1, 2, 3])).to         eq %(<x-el :ids="[1,2,3]"></x-el>) }
    it { expect(vue.XEl(config: { key: "val" })).to eq %(<x-el :config='{"key":"val"}'></x-el>) }
    it { expect(vue.XEl(class: %w[foo bar])).to     eq %(<x-el class="foo bar"></x-el>) }
  end

  describe "single-quote delimiters" do
    it "switches to single quotes when the value contains a double quote" do
      expect(vue.my_component(config: '{"key":"value"}')).to \
        eq %(<my-component config='{"key":"value"}'></my-component>)
    end

    it "handles a JSON string passed directly as an attribute value" do
      expect(vue.data_list(items: '{"items":[1,2,3]}')).to \
        eq %(<data-list items='{"items":[1,2,3]}'></data-list>)
    end

    context "with data: hash" do
      it "single-quotes a data attribute whose JSON representation contains strings" do
        expect(vue.my_component(data: { items: %w[a b] })).to \
          eq %(<my-component data-items='["a","b"]'></my-component>)
      end

      it "double-quotes a data attribute whose JSON representation is quote-free" do
        expect(vue.my_component(data: { ids: [1, 2, 3] })).to \
          eq %(<my-component data-ids="[1,2,3]"></my-component>)
      end

      it "single-quotes a nested object serialised to JSON" do
        expect(vue.my_component(data: { user: { id: 1, name: "Alice" } })).to \
          eq %(<my-component data-user='{"id":1,"name":"Alice"}'></my-component>)
      end

      it "double-quotes a plain string data value" do
        expect(vue.my_component(data: { label: "hello" })).to \
          eq %(<my-component data-label="hello"></my-component>)
      end
    end

    context "with BigDecimal values in data: hash" do
      it "emits fixed-point notation without AS monkey-patch dependency" do
        expect(vue.my_component(data: { price: BigDecimal("3.14") })).to \
          eq %(<my-component data-price="3.14"></my-component>)
      end

      it "preserves full precision (no float rounding)" do
        expect(vue.my_component(data: { ratio: BigDecimal("1.000000001") })).to \
          eq %(<my-component data-ratio="1.000000001"></my-component>)
      end
    end
  end

  describe "escaping inside single-quoted attributes" do
    it { expect(vue.XEl(config: '{"a":"b&c"}')).to eq %(<x-el config='{"a":"b&amp;c"}'></x-el>) }
    it { expect(vue.XEl(config: '{"a":"b<c"}')).to eq %(<x-el config='{"a":"b&lt;c"}'></x-el>) }
    it { expect(vue.XEl(config: '{"a":"b>c"}')).to eq %(<x-el config='{"a":"b&gt;c"}'></x-el>) }
    it { expect(vue.XEl(config: '{"a":"b\'c"}')).to eq %(<x-el config='{"a":"b&#39;c"}'></x-el>) }
  end

  describe "escaping inside double-quoted attributes" do
    it "escapes &" do
      expect(vue.my_component(label: "a&b")).to \
        eq %(<my-component label="a&amp;b"></my-component>)
    end

    it "escapes < and > to prevent XSS" do
      expect(vue.my_component(label: "<script>")).to \
        eq %(<my-component label="&lt;script&gt;"></my-component>)
    end
  end

  describe "escape: false" do
    it "still chooses single-quote delimiters when the value contains a double quote" do
      expect(vue.my_component(escape: false, config: '{"k":"v"}')).to \
        eq %(<my-component config='{"k":"v"}'></my-component>)
    end

    it "keeps double-quote delimiters for plain values" do
      expect(vue.my_component(escape: false, label: "hello")).to \
        eq %(<my-component label="hello"></my-component>)
    end
  end

  describe "html_safe values" do
    it "double-quotes an html_safe value that contains no double quote" do
      expect(vue.my_component(label: "hello".html_safe)).to \
        eq %(<my-component label="hello"></my-component>)
    end

    it "single-quotes an html_safe value that contains a double quote" do
      expect(vue.my_component(config: '{"key":"value"}'.html_safe)).to \
        eq %(<my-component config='{"key":"value"}'></my-component>)
    end

    it "escapes a literal ' inside an html_safe single-quoted attribute" do
      expect(vue.my_component(config: %("it's").html_safe)).to \
        eq %(<my-component config='"it&#39;s"'></my-component>)
    end
  end

  describe "ActionView::Helpers::VueTagHelper#vue" do
    it "returns a VueBuilder instance" do
      expect(ctx.vue).to be_an_instance_of described_class
    end
  end
end
