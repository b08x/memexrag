# frozen_string_literal: true

# Defines the Topic model.
class Topic < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :name
  attribute :description
  attribute :vector

  unique :name
  index :name

  collection :paragraphs, :Paragraph
  collection :sentences, :Sentence
  collection :phrases, :Phrase
  collection :words, :Word
end
