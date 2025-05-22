# frozen_string_literal: true

class Item < Sequel::Model
  plugin :validation_helpers
  plugin :insert_conflict

  many_to_one :collection

  def before_create
    self.created_at ||= Time.now
    super
  end

  def after_update
    super
    updated_at || Time.now
  end

  def validate
    super
    validates_presence :path
    validates_unique :path
  end
end
