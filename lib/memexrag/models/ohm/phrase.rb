# frozen_string_literal: true

class Phrase < Ohm::Model
  include Ohm::DataTypes
  include Ohm::Callbacks

  attribute :text
  attribute :phrase_type
  attribute :metadata, Type::Hash

  # Direct reference
  reference :sentence, :Sentence

  # Indexes
  index :text
  index :phrase_type
  index :sentence_id

  def before_save
    self.text = text.strip if text
  end

  # Class methods
  class << self
    def find_by_type(type)
      find(phrase_type: type)
    end

    def find_by_text(text)
      find(text: text.strip)
    end

    def find_by_sentence(sentence)
      find(sentence: sentence)
    end
  end
end
