#!/usr/bin/env ruby
# frozen_string_literal: true

#
## Sentence model for individual sentences
class Sentence < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :text

  reference :paragraph, :Paragraph
  reference :page, :Page

  set :topics, :Topic

  collection :phrases, :Phrase

  list :words, :Word

  index :text

  # Adds words to the sentence
  def add_words(words_data)
    words_data.each do |data|
      word = Word.create(
        word: data[:word],
        pos: data[:pos],
        tag: data[:tag],
        dep: data[:dep],
        ner: data[:ner],
        text_object: text_object,
        sentence: sentence
      )
      words.add(word)
    end
  end
end
