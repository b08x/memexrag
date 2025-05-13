# frozen_string_literal: true

class Collection < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict

  one_to_many :items

  def self.find_or_create(name)
    existing = find(name: name)
    return existing if existing

    create(name: name)
  end

  def validate
    super
    validates_presence :name
    validates_unique :name
  end
end
