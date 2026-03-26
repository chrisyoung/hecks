# Hecks::AttachmentMethods
#
# Service mixin that adds file attachment tracking to aggregate instances.
# Bound by AggregateWiring when the aggregate is marked attachable in the DSL.
# Attachments are metadata references (name, url, content_type) — not file storage.
#
#   AttachmentMethods.bind(PizzaClass)
#   pizza = Pizza.create(name: "Margherita")
#   pizza.attach(name: "photo.jpg", url: "https://example.com/photo.jpg", content_type: "image/jpeg")
#   pizza.attachments  # => [{ name: "photo.jpg", url: "...", content_type: "image/jpeg" }]
#
module Hecks
  module AttachmentMethods
    def self.bind(klass)
      klass.prepend(InstanceMethods)
    end

    module InstanceMethods
      def initialize(**attrs)
        super(**attrs)
        @attachments = []
      end

      def attach(name:, url:, content_type: nil)
        @attachments << { name: name, url: url, content_type: content_type }
      end

      def attachments
        @attachments.dup
      end
    end
  end
end
