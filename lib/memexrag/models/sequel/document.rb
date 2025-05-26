# frozen_string_literal: true

class Document < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict

  one_to_many :sections

  def validate
    super
    validates_presence :title
    validates_unique :title
  end
end
