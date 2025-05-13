# frozen_string_literal: true

# Paragraph model for text paragraphs
class Paragraph < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :text

  reference :text_object, :TextObject
  reference :page, :Page

  set :topics, :Topic

  list :sentences, :Sentence
  list :phrases, :Phrase
  list :words, :Word

  index :text

  # Adds sentences to the paragraph
  def add_sentences(sentences)
    sentences.each do |text|
      sentence = Sentence.create(text: text, paragraph: self, text_object: text_object)
      self.sentences.add(sentence)
    end
  end
end
