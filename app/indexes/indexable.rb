# frozen_string_literal: true

require 'elasticsearch/model'

# Base Elasticsearch indexing definitions
#
# Make sure to include your custom index file
# in your model alongside Indexable.
module Indexable
  def self.included(base)
    base.include Elasticsearch::Model

    base.index_name("#{base.model_name.plural}_#{Rails.env}") unless Rails.env.production?

    base.after_commit on: [:create] do
      __elasticsearch__.index_document(Rails.env.test? ? { refresh: "true" } : {})
    end

    base.after_commit on: [:update] do
      update_index # XXX
    end

    base.after_commit on: [:destroy] do
      __elasticsearch__.delete_document(Rails.env.test? ? { refresh: "true" } : {})
    end
  end

  def update_index(defer: true, priority: :high)
    # TODO: race condition hack, makes tests SLOW!!!
    return __elasticsearch__.index_document refresh: "true" if Rails.env.test?

    if defer
      if priority == :high
        IndexUpdateJob.perform_async(self.class.to_s, id)
      elsif priority == :rebuild
        IndexRebuildJob.perform_later(self.class.to_s, id)
      else
        raise ArgumentError, 'No such priority known'
      end
    else
      __elasticsearch__.index_document
    end
  end
end
