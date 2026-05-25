# frozen_string_literal: true

require "action_view"

module ActionView
  module Helpers
    module TagHelper
      # VueBuilder generates Vue component markup from a proxy-style builder
      # interface identical to the built-in +tag+ helper:
      #
      # @example
      #   vue.my_component(label: "Hello")
      #   # => <my-component label="Hello"></my-component>
      #
      # It is intentionally *not* a subclass of TagBuilder.  The two helpers
      # have different semantics and will diverge further as Vue-specific
      # features are added.
      #
      # ## Tag names
      #
      # Method names are dasherized before use as the HTML tag name
      # (+my_feed_item+ → +my-feed-item+).  The resulting name must be a valid
      # kebab-cased custom-element name: all-lowercase, letters/digits only,
      # and at least one hyphen separating two non-empty segments.  Anything
      # else — PascalCase, a plain lowercase word, underscores — raises
      # +ArgumentError+ immediately, before attributes or content are evaluated.
      #
      # @example
      #   vue.my_component   # => <my-component></my-component>  ✓
      #   vue.MyComponent    # => <my-component></my-component>  ✓  (PascalCase normalised)
      #   vue.div            # => ArgumentError ("div")          ✗
      #
      # This mirrors the HTML Living Standard requirement that custom element
      # names contain at least one hyphen, which also guarantees they can never
      # collide with current or future built-in HTML elements.
      #
      # ## Closing tags
      #
      # Every tag is emitted with an explicit closing tag.  Vue component tags
      # are never self-closing.
      #
      # ## Attribute quoting
      #
      # Standard TagBuilder always uses double-quote delimiters and escapes any
      # literal +"+ inside a value as +&quot;+.  That is safe but verbose — a
      # JSON blob like +{"key":"value"}+ becomes
      # +data="{&quot;key&quot;:&quot;value&quot;}"+.
      #
      # VueBuilder switches to single-quote delimiters whenever the stringified
      # value contains a double-quote, so the same blob is emitted as
      # +data='{"key":"value"}'+.  The delimiter decision is independent
      # of the +escape:+ flag.
      #
      # Escaping rules when single-quote delimiters are chosen:
      #
      #   &  →  &amp;
      #   <  →  &lt;
      #   >  →  &gt;
      #   '  →  &#39;   (protects the delimiter)
      #   "  →  (unchanged — the whole point)
      #
      # Values already marked +html_safe?+ are passed through as-is except that
      # a literal +\'+ is escaped when single-quote delimiters are in use.
      #
      # ## Typed attributes / v-bind shorthand
      #
      # Vue components use typed props (+defineProps<{ count: number }>()+).
      # Passing a plain HTML string like +count="42"+ triggers a Vue runtime
      # warning because the prop expects a Number, not a String.
      #
      # VueBuilder avoids this by inspecting the Ruby value type:
      #
      # - +String+ / +Symbol+ — emitted as a plain attribute (no colon).
      # - +true+ — emitted as a valueless attribute (+disabled+).  Vue
      #   interprets attribute presence as a truthy boolean.
      # - everything else (+Integer+, +Float+, +BigDecimal+, +false+,
      #   +Array+, +Hash+, …) — the attribute name is prefixed with +:+
      #   (the +v-bind+ shorthand) and the value is serialised with
      #   +#to_json+.  The resulting JSON string is then subject to the
      #   normal single/double-quote quoting rules.
      #
      # @example
      #   vue.my_component(count: 42)
      #   # => <my-component :count="42"></my-component>
      #
      #   vue.my_component(items: ["a", "b"])
      #   # => <my-component :items='["a","b"]'></my-component>
      #
      #   vue.b_btn(disabled: true)
      #   # => <b-btn disabled></b-btn>
      #
      #   vue.b_btn(disabled: false)
      #   # => <b-btn :disabled="false"></b-btn>
      #
      # The +class:+ key is exempt from the v-bind rule: an Array or Hash
      # value is always flattened into a space-separated CSS token list.
      #
      # ## data: and aria: hashes
      #
      # A Hash passed under the +data:+ or +aria:+ key is expanded into
      # individual prefixed attributes.  Values are serialised as follows:
      #
      # - +String+, +Symbol+ — passed through unchanged.
      # - +BigDecimal+ — converted with +to_s("F")+ (fixed-point notation,
      #   independent of any ActiveSupport monkey-patches).
      # - everything else — serialised with +#to_json+.
      #
      # @example
      #   vue.my_component(data: {items: ["a", "b"]})
      #   # => <my-component data-items='["a","b"]'></my-component>
      #
      class VueBuilder
        # Raised when a method name cannot be normalised to a valid kebab-cased
        # Vue component tag name (i.e. one containing at least one hyphen).
        #
        # Inherits from +ArgumentError+ so existing rescues on +ArgumentError+
        # continue to work.
        #
        # @param original [String] the method name as called (pre-normalisation)
        # @param normalised [String] the name after +.underscore.dasherize+
        class InvalidTagNameError < ArgumentError
          def initialize(original, normalised = original)
            detail = if original == normalised
              original.inspect
            else
              "#{original.inspect} (normalised to #{normalised.inspect})"
            end

            super(<<~MESSAGE.strip)
              Vue component tag names must be kebab-cased with at least one hyphen
              (e.g. "my-component"), got: #{detail}
            MESSAGE
          end
        end

        # Valid Vue/custom-element tag name after dasherization:
        # lowercase segments of letters and digits joined by hyphens, with at
        # least one hyphen present.
        KEBAB_TAG_RE = /\A[a-z][a-z0-9]*(-[a-z0-9]+)+\z/
        private_constant :KEBAB_TAG_RE

        # Characters that need escaping inside single-quoted HTML attributes.
        # Note the deliberate absence of +" +: it is safe unescaped when the
        # delimiter is a single quote.
        SINGLE_QUOTE_ATTR_ESCAPE = {
          "&" => "&amp;",
          "<" => "&lt;",
          ">" => "&gt;",
          "'" => "&#39;",
        }.freeze
        private_constant :SINGLE_QUOTE_ATTR_ESCAPE

        def initialize(view_context)
          @view_context = view_context
        end

        private

        def respond_to_missing?(*, **)
          true
        end

        def method_missing(called, *args, escape: true, **options, &)
          original = called.name
          name     = original.underscore.dasherize
          raise InvalidTagNameError.new(original, name) unless KEBAB_TAG_RE.match?(name)

          content  = build_inline_content(args, escape, &)
          "<#{name}#{build_tag_options(options, escape)}>#{content}</#{name}>".html_safe # rubocop:disable Rails/OutputSafety
        end

        def build_inline_content(args, escape, &block)
          return @view_context.capture(self, &block) if block

          args.first&.then { |i| escape ? ERB::Util.unwrapped_html_escape(i) : i.to_s }
        end

        # Serialises the options hash to an HTML attribute string.
        #
        # +data:+ and +aria:+ sub-hashes are expanded into prefixed attributes.
        # All other key/value pairs are forwarded to +typed_tag_option+.
        # +nil+ values are always omitted.
        #
        # @param options [Hash]
        # @param escape [Boolean]
        # @return [String, nil]
        def build_tag_options(options, escape)
          return if options.blank?

          output = +""
          options.each_pair { |k, v| append_one_option(output, k, v, escape) }
          output unless output.empty?
        end

        def append_one_option(output, key, value, escape)
          return if key.blank?

          case key.to_s
          when "data"
            value.is_a?(Hash) && append_data_options(output, value, escape)
          when "aria"
            value.is_a?(Hash) && append_aria_options(output, value, escape)
          else
            output << " " << typed_tag_option(key, value, escape) unless value.nil?
          end
        end

        def append_data_options(output, hash, escape)
          hash.each_pair do |k, v|
            output << " " << prefix_tag_option("data", k, v, escape) unless k.blank? || v.nil?
          end
        end

        def append_aria_options(output, hash, escape)
          hash.each_pair do |k, v|
            next if k.blank? || v.nil?

            v = resolve_aria_value(v)
            output << " " << prefix_tag_option("aria", k, v, escape) unless v.nil?
          end
        end

        def resolve_aria_value(value)
          case value
          when Array, Hash
            tokens = TagHelper.build_tag_values(value)
            tokens.any? ? @view_context.safe_join(tokens, " ") : nil
          else
            value.to_s
          end
        end

        # Applies Vue-aware typing rules before delegating to +tag_option+.
        #
        # - +true+ — emits a valueless attribute (e.g. +disabled+).
        # - +String+, +Symbol+ — passes through to +tag_option+ unchanged; no colon prefix.
        # - +Array+, +Hash+ under +class:+ — passes through for CSS token-list expansion.
        # - everything else — prepends +:+ to the key (v-bind shorthand) and serialises
        #   the value with +#to_json+, then passes to +tag_option+.
        def typed_tag_option(key, value, escape)
          case value
          when true
            escape ? ERB::Util.xml_name_escape(key.to_s) : key.to_s
          when String, Symbol
            tag_option(key, value, escape)
          when Array, Hash
            key.to_s == "class" ? tag_option(key, value, escape) : tag_option(":#{key}", value.to_json, escape)
          else
            tag_option(":#{key}", value.to_json, escape)
          end
        end

        # Serialises a +data-*+ or +aria-*+ attribute.
        #
        # - +String+, +Symbol+ — passed through unchanged.
        # - +BigDecimal+ — converted with +to_s("F")+ (fixed-point notation, no
        #   ActiveSupport dependency).  Using +to_json+ would produce a
        #   JSON-encoded string literal (+'"3.14"'+) rather than a plain decimal
        #   string (++"3.14"++); using bare +to_s+ without the format argument
        #   produces scientific notation (++"0.314e1"++) in plain Ruby.
        # - everything else — serialised with +#to_json+.
        #
        # @param prefix [String] +"data"+ or +"aria"+
        # @param key [#to_s]
        # @param value [Object]
        # @param escape [Boolean]
        # @return [String]
        def prefix_tag_option(prefix, key, value, escape)
          attr_key = "#{prefix}-#{key.to_s.dasherize}"
          value    = case value
          when String, Symbol
            value
          when BigDecimal
            value.to_s("F")
          else
            value.to_json
          end
          tag_option(attr_key, value, escape)
        end

        # Serialises a single attribute key/value pair.
        #
        # Arrays and Hashes under a +class+ key are flattened to a
        # space-separated token list with double-quote delimiters.  All other
        # values go through +build_quoted_attr+ for the single/double-quote
        # delimiter decision.
        #
        # @param key [String]
        # @param value [Object]
        # @param escape [Boolean]
        # @return [String]
        def tag_option(key, value, escape)
          key = ERB::Util.xml_name_escape(key.to_s) if escape
          case value
          when Array, Hash
            token_list_attr(key, value, escape)
          when Regexp
            build_quoted_attr(key, value.source, escape)
          else
            build_quoted_attr(key, value.to_s, escape)
          end
        end

        def token_list_attr(key, value, escape)
          value = TagHelper.build_tag_values(value) if key == "class"
          value = escape ? @view_context.safe_join(value, " ") : value.join(" ")
          value = value.gsub('"', "&quot;") if value.include?('"')
          %(#{key}="#{value}")
        end

        # Chooses single-quote or double-quote delimiters based solely on
        # whether +raw+ contains a double-quote character, then escapes and
        # wraps the value.
        #
        # The delimiter choice is independent of +escape+: it is a structural
        # concern (preventing attribute breakage), not a safety one.
        #
        # +raw+ must already be a String.  If it is +html_safe?+, the
        # escaping step is skipped on the double-quote path (mirroring
        # +ERB::Util.unwrapped_html_escape+) and reduced to +\'+ escaping only
        # on the single-quote path.
        #
        # @param key [String]
        # @param raw [String]
        # @param escape [Boolean]
        # @return [String]
        def build_quoted_attr(key, raw, escape)
          if raw.include?('"')
            escaped = escape ? escape_for_single_quoted_attr(raw) : raw
            %(#{key}='#{escaped}')
          else
            value = escape ? ERB::Util.unwrapped_html_escape(raw) : raw
            value = value.gsub('"', "&quot;") if value.include?('"')
            %(#{key}="#{value}")
          end
        end

        # Escapes +str+ for embedding in a single-quoted HTML attribute.
        #
        # For +html_safe?+ strings, only the single-quote delimiter character
        # is escaped — the caller is responsible for the rest of the content.
        # For plain strings, +&+, +<+, +>+, and +'+ are all escaped; +"+ is
        # intentionally left as-is.
        #
        # @param str [String]
        # @return [String]
        def escape_for_single_quoted_attr(str)
          if str.html_safe?
            str.include?("'") ? str.gsub("'", "&#39;") : str
          else
            str.gsub(/[&<>']/, SINGLE_QUOTE_ATTR_ESCAPE)
          end
        end
      end
    end
  end
end
