require 'ohm'

class Placeholder < Ohm::Model
  attribute :name
  attribute :created_at
  attribute :status
  index :name
end
