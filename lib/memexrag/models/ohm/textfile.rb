#!/usr/bin/env ruby
# frozen_string_literal: true

# require 'ohm'
# require 'ohm/model'
require 'set' # Required for using Set

class TextFile < Ohm::Model
  include ::Ohm::DataTypes
  include ::Ohm::Callbacks
  attribute :content
  attribute :metadata

  collection :paragraphs, :Paragraph

  def process_content
    chunker = SemanticChunker.new(content)
    semantic_paragraphs = chunker.process

    semantic_paragraphs.each do |para_data|
      paragraph = Paragraph.create(
        text_file: self,
        main_topics: para_data[:main_topics],
        embedding: para_data[:embedding],
        metadata: para_data[:metadata]
      )
      paragraphs.add(paragraph) # Add to the collection

      para_data[:sentences].each do |sent_data|
        sentence = Sentence.create(
          text: sent_data[:text],
          embedding: sent_data[:embedding],
          topics: sent_data[:topics].to_a, # Convert Set to Array
          paragraph: paragraph
        )

        # Create phrases
        sent_data[:phrases].each do |type, phrases|
          phrases.each do |phrase_text|
            Phrase.create(
              text: phrase_text,
              phrase_type: type,
              sentence: sentence
            )
          end
        end

        # Create words with their linguistic information
        sent_data[:words].each do |word_data|
          Word.create(
            text: word_data[:text],
            lemma: word_data[:lemma],
            pos_tag: word_data[:pos],
            dep_tag: word_data[:dep],
            ner_tag: word_data[:ner],
            synsets: word_data[:synsets],
            sentence: sentence
          )
        end
      end
    end
  end

  def words
    # Efficiently retrieves all words associated with the TextFile
    Paragraph.find(text_file_id: id).flat_map(&:sentences).flat_map { |sentence| Word.find(sentence_id: sentence.id) }
  end

  def words_matching(regex)
    # Filters words by regex
    words.select { |word| word.text =~ regex }
  end

  def longest_word
    # Finds the longest word in the TextFile
    words.max_by { |word| word.text.length }
  end
end

class Paragraph < Ohm::Model
  include ::Ohm::DataTypes
  include ::Ohm::Callbacks
  reference :text_file, TextFile
  attribute :main_topics
  attribute :embedding
  attribute :metadata
  collection :sentences, :Sentence
end

class Sentence < Ohm::Model
  include ::Ohm::DataTypes
  include ::Ohm::Callbacks
  attribute :text
  attribute :embedding
  attribute :topics # Store as an array of strings
  reference :paragraph, Paragraph
  collection :phrases, :Phrase
  collection :words, :Word
end

class Phrase < Ohm::Model
  include ::Ohm::DataTypes
  include ::Ohm::Callbacks
  attribute :text
  attribute :phrase_type
  reference :sentence, Sentence
  collection :words, :Word
end

class Word < Ohm::Model
  include ::Ohm::DataTypes
  include ::Ohm::Callbacks
  attribute :text
  attribute :lemma
  attribute :pos_tag
  attribute :dep_tag
  attribute :ner_tag
  attribute :synsets # Consider storing as JSON if complex
  reference :sentence, Sentence
end

class SemanticChunker
  def initialize(text)
    @nlp = SpacyModelRegistry.load_model('en_core_web_trf')

    @text = text

    @paragraphs = []
    @sentences = []
    @topics = {}
  end

  def process
    # First pass: Extract and analyze sentences
    extract_and_analyze_sentences

    # Second pass: Group sentences into paragraphs by topic coherence
    form_topic_based_paragraphs
    @paragraphs
  end

  private

  def extract_and_analyze_sentences
    doc = @nlp.read(@text)

    doc.sents.each do |sent|
      sentence = {
        text: sent.text,
        topics: extract_sentence_topics(sent),
        embedding: generate_sentence_embedding(sent),
        phrases: extract_phrases(sent),
        words: extract_words_with_senses(sent)
      }

      @sentences << sentence

      # Aggregate topics for later use
      sentence[:topics].each do |topic|
        @topics[topic] ||=
          @topics[topic] << (@sentences.length - 1) # Store sentence index
      end
    end
  end

  def extract_sentence_topics(sent)
    topics = Set.new

    # Extract topics from noun chunks using WordNet
    sent.noun_chunks.each do |chunk|
      synsets = get_wordnet_synsets(chunk.root.lemma_)
      # Get hypernyms to find more general topics
      topics.merge(synsets.flat_map(&:hypernyms).map(&:name))
    end

    # Add topics from named entities
    sent.ents.each do |ent|
      topics.add(ent.label_)
    end

    # Add topics from key verbs (actions often indicate topic shifts)
    # sent.select { |token| token.pos_ == "VERB" && token.dep_ == "ROOT" }
    #    .each { |token| topics.add(token.lemma_) }
    topics
  end

  def extract_phrases(sent)
    {
      noun_phrases: sent.noun_chunks.map(&:text),
      verb_phrases: extract_verb_phrases(sent),
      prep_phrases: extract_prep_phrases(sent)
    }
  end

  def extract_words_with_senses(sent)
    sent.map do |token|
      {
        text: token.text,
        lemma: token.lemma_,
        pos: token.pos_,
        dep: token.dep_,
        synsets: get_wordnet_synsets(token.lemma_),
        ner: token.ent_type_ || 'O'
      }
    end
  end

  def form_topic_based_paragraphs
    current_paragraph = []
    current_topics = Set.new

    @sentences.each_with_index do |sentence, idx|
      if should_start_new_paragraph?(sentence, current_topics, idx)
        finalize_paragraph(current_paragraph) if current_paragraph.any?
        current_paragraph = [sentence]
        current_topics = sentence[:topics]
      else
        current_paragraph << sentence
        current_topics.merge(sentence[:topics])
      end
    end

    # Handle the last paragraph
    finalize_paragraph(current_paragraph) if current_paragraph.any?
  end

  def should_start_new_paragraph?(sentence, current_topics, idx)
    return true if current_topics.empty? # First sentence starts a paragraph

    # Calculate topic overlap with current paragraph
    topic_overlap = (sentence[:topics] & current_topics).size.to_f / [sentence[:topics].size, current_topics.size].max

    # Check embedding similarity with previous sentence
    prev_embedding_sim = @nlp.read(sentence[:text]).similarity @nlp.read(@sentences[idx - 1][:text]) if idx.positive?

    # Consider starting new paragraph if:
    # 1. Low topic overlap with current paragraph
    # 2. Low embedding similarity with previous sentence
    # 3. Significant change in named entities
    # 4. Presence of discourse markers indicating topic shifts
    topic_overlap < 0.3 ||
      (prev_embedding_sim && prev_embedding_sim < 0.5) ||
      entity_shift?(@sentences[idx - 1], sentence) ||
      topic_shift_markers?(sentence)
  end

  def finalize_paragraph(sentences)
    # Create paragraph with metadata
    paragraph = {
      sentences: sentences,
      main_topics: find_main_topics(sentences),
      embedding: aggregate_embeddings(sentences.map { |s| s[:embedding] }),
      metadata: generate_paragraph_metadata(sentences)
    }

    @paragraphs << paragraph
  end

  def find_main_topics(sentences)
    # Count topic occurrences
    topic_counts = Hash.new(0)
    sentences.each do |sentence|
      sentence[:topics].each { |topic| topic_counts[topic] += 1 }
    end

    # Select topics that appear in multiple sentences
    threshold = sentences.length * 0.3 # At least 30% of sentences
    topic_counts.select { |_topic, count| count >= threshold }.keys
  end

  def generate_paragraph_metadata(sentences)
    {
      sentence_count: sentences.length,
      word_count: sentences.sum { |s| s[:words].length },
      entities: extract_unique_entities(sentences),
      temporal_markers: find_temporal_markers(sentences),
      discourse_markers: find_discourse_markers(sentences)
    }
  end

  def entity_shift?(prev_sent, curr_sent)
    prev_entities = prev_sent[:words].map { |w| w[:ner] }.to_set
    curr_entities = curr_sent[:words].map { |w| w[:ner] }.to_set
    (prev_entities & curr_entities).empty? &&
      (prev_entities.any? || curr_entities.any?)
  end

  def topic_shift_markers?(sentence)
    discourse_markers = [
      'however',
      'moreover',
      'furthermore',
      'meanwhile',
      'in contrast',
      'on the other hand',
      'turning to'
    ]
    sentence[:text].downcase.split.any? { |word| discourse_markers.include?(word) }
  end

  def get_wordnet_synsets(lemma)
    # Implementation to get WordNet synsets
    # You'll need to integrate with a WordNet library
    # Placeholder: Replace with actual WordNet integration
  end

  def generate_sentence_embedding(_sent)
    # Implementation to generate embeddings
    # Could use various embedding models
    Array.new(10, rand) # Placeholder: Replace with actual embedding generation
  end

  def extract_verb_phrases(sent)
    # Replace with actual verb phrase extraction logic
    sent.map { |token| token.text if token.pos_ == 'VERB' }.compact
  end

  def extract_prep_phrases(sent)
    # Replace with actual prepositional phrase extraction logic
    sent.map { |token| token.text if token.pos_ == 'ADP' }.compact
  end

  def extract_unique_entities(sentences)
    sentences.flat_map { |s| s[:words].map { |w| w[:ner] } }.uniq
  end

  def find_temporal_markers(sentences)
    # Replace with actual temporal marker extraction logic
  end

  def find_discourse_markers(sentences)
    # Replace with actual discourse marker extraction logic
  end

  def aggregate_embeddings(embeddings)
    # Replace with actual embedding aggregation logic
    embeddings.flatten
  end
end
