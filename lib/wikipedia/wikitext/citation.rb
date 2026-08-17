# frozen_string_literal: true

module Wikipedia
  module Wikitext
    # A citation template together with the ref that contains it.
    Citation = Data.define(:template, :ref) do
      def [](key) = template[key]

      def name = template.normalized_name

      def offset = template.offset
    end
  end
end
