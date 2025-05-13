# frozen_string_literal: true

class Document < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict

  def self.find_or_create(title)
    existing = find(title: title)
    return existing if existing

    create(title: title)
  end

  def validate
    super
    validates_presence :title
    validates_unique :title
  end
end
