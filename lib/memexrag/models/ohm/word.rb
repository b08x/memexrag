# frozen_string_literal: true

class Word < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :text
  attribute :lemma
  attribute :metadata, Type::Hash

  # Direct reference
  reference :sentence, :Sentence

  # Indexes
  index :text
  index :lemma
  index :sentence_id

  def before_save
    self.text = text.downcase.strip if text
    self.lemma = lemma.downcase.strip if lemma
  end

  # Class methods
  class << self
    def find_by_text(text)
      find(text: text.downcase.strip)
    end

    def find_by_lemma(lemma)
      find(lemma: lemma.downcase.strip)
    end

    def find_by_sentence(sentence)
      find(sentence: sentence)
    end
  end
end
