# frozen_string_literal: true

class Item < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict

  many_to_one :collection

  def validate
    super
    validates_presence :path
    validates_unique :path
  end
end
