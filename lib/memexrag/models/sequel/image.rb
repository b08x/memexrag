# frozen_string_literal: true

class Image < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict

  def validate
    super
    validates_presence :title
    validates_unique :title
  end
end
