# frozen_string_literal: true

class Task < Ohm::Model
  attribute :name
  attribute :status
  attribute :assigned_to
  attribute :created_at
  index :name
end
