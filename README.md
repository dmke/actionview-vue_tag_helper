# actionview-vue_tag_helper

An ActionView helper for embedding Vue components in server-rendered HTML,
targeting the [Islands architecture](https://jasonformat.com/islands-architecture/):
multiple independent Vue instances mounted on otherwise static pages,
without a full SPA or SSR pipeline.

## Overview

In the Islands model, Rails delivers ordinary HTML and Vue is mounted on
individual "islands" — interactive widgets that need typed props, reactive
state, or component-library primitives. The built-in `tag` helper works
fine for plain HTML but is a poor fit here: it always uses double-quote
delimiters and entity-encodes `"` inside attribute values, turning a
simple JSON prop into noise, and it has no concept of Vue's typed props
or `v-bind` shorthand.

`actionview-vue_tag_helper` provides a `vue` helper with the same
builder interface but tuned for Vue component output:

```erb
<%# tag helper — double-quotes force &quot; encoding inside JSON %>
<%= tag.my_component data: { config: {key: "val"}.to_json } %>
<%# => <my-component data-config="{&quot;key&quot;:&quot;val&quot;}"></my-component> %>

<%# vue helper — switches to single quotes when the value contains " %>
<%= vue.my_component data: { config: {key: "val"} } %>
<%# => <my-component data-config='{"key":"val"}'></my-component> %>
```

### Tag names

Method names are dasherized: `vue.my_feed_item` and `vue.MyFeedItem`
both produce `<my-feed-item>`. The resulting name must contain at least
one hyphen (the HTML Living Standard requirement for custom element
names). Anything that doesn't meet this — a plain word like `vue.div`,
for example — raises `ArgumentError` immediately.

Every tag is emitted with an explicit closing tag; Vue component tags are
never self-closing.

### Typed attributes / v-bind shorthand

Vue components use typed props. Passing `count="42"` (a string) when the
component declares `count: Number` triggers a Vue runtime warning. The
`vue` helper avoids this by inspecting the Ruby value:

| Ruby value | Emitted attribute |
|:-----------|:------------------|
| `String`, `Symbol` | `label="hello"` — plain attribute |
| `true`             | `disabled` — valueless (Vue treats presence as truthy) |
| `Integer`, `Float`, `false`, `Array`, `Hash`, … | `:count="42"` — v-bind shorthand, value serialised as JSON |

```erb
<%= vue.b_btn(disabled: true) %>
<%# => <b-btn disabled></b-btn> %>

<%= vue.x_counter(count: 42, ratio: 1.5) %>
<%# => <x-counter :count="42" :ratio="1.5"></x-counter> %>

<%= vue.my_component(items: %w[a b]) %>
<%# => <my-component :items='["a","b"]'></my-component> %>
```

The `class:` key is exempt: an `Array` or `Hash` value is always
flattened into a space-separated CSS token list, never v-bound.

### `data:` and `aria:` hashes

A Hash under `data:` or `aria:` is expanded into individual prefixed
attributes. Complex values are serialised to JSON; `aria:` values are
always plain strings (WAI-ARIA is string-based).

```erb
<%= vue.my_component(data: { user: { id: 1, name: "Alice" } }) %>
<%# => <my-component data-user='{"id":1,"name":"Alice"}'></my-component> %>
```

## Installation

Add to your `Gemfile`:

```ruby
gem "actionview-vue_tag_helper"
```

The helper is available in all views as soon as the gem is loaded. No
`include` or initialiser is required — it hooks into ActionView via
`ActiveSupport.on_load(:action_view)`.

## License

MIT - see [LICENSE.txt](LICENSE.txt).
