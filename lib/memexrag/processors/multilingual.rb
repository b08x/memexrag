# frozen_string_literal: true

# Configure multilingual NLP pipeline

SENTENCE_MODEL = 'xx_sent_ud_sm'
NER_MODEL = 'xx_ent_wiki_sm'

ENG_MODEL = 'en_core_web_trf'

module MemexRAG
  module Processors
    class Multilingual
      def initialize
        @en_nlp = Spacy::Language.new('en_core_web_trf') # Medical English model
        @ta_nlp = Spacy::Language.new('') # Multilingual model for Tamil
      end

      def process(text, language)
        if language == :ta
          doc = @ta_nlp.call(text)
          # Custom Tamil radiology terms
          doc = add_custom_terms(doc, RADIOLOGY_TA)
        else
          doc = @en_nlp.call(text)
        end
        extract_entities(doc)
      end
    end
  end
end
