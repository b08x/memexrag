#!/usr/bin/env ruby
# frozen_string_literal: true

class Document < Ohm::Model
  include Ohm::Timestamps
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :title

  list :pages, :Page

  index :title
end
