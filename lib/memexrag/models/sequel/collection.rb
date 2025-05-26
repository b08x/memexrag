# frozen_string_literal: true

class Collection < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict

  one_to_many :items

  many_to_one :parent, class: self
  one_to_many :children, key: :parent_id, class: self

  one_to_many :text_files, class: :Item do |ds|
    ds.filter(type: 'text')
  end

  one_to_many :documents, class: :Item do |ds|
    ds.filter(type: 'doc')
  end

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
