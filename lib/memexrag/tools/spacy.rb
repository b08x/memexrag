module RubyLLM
  module Spacy
    GEMINI_MODEL = 'gemini-1.5-pro-latest'

    def self.chat
      @chat ||= begin
        c = RubyLLM.chat(model: GEMINI_MODEL)
        c.on_new_message { puts 'Gemini is analyzing...' }
        c.on_end_message do |msg|
          puts "Done! Tokens used: #{msg.input_tokens + msg.output_tokens}" if msg&.output_tokens
        end
        c
      end
    end

    def self.entities(text)
      prompt = "Extract named entities and their types from the following text:\n\n#{text}\n\n" \
               'Return a JSON array with objects like {"text": ..., "type": ...}.'
      response = chat.ask(prompt)
      JSON.parse(response.content)
    rescue JSON::ParserError
      puts "Failed to parse response:\n#{response.content}"
      []
    end
  end
end

class SpaceyTool < RubyLLM::Tool
  description 'Processes text using the Ruby Spacey library'

  param :text,
        desc: 'The text to process'

  param :model_name,
        desc: 'The name of the spaCy model to use', default: 'en_core_web_sm'

  def execute(text:, model_name:)
    require 'ruby-spacy'

    # Load the spaCy model
    begin
      nlp = Spacy::Language.new(model_name)
    rescue StandardError => e
      return "Error loading spaCy model: #{e.message}.  Ensure the model is installed (e.g., python -m spacy download #{model_name}) and that you have ruby-spacy configured correctly."
    end

    # Process the text
    doc = nlp.read(text)

    # Extract relevant information (example: tokens and their POS tags)
    tokens = doc.map { |token| { text: token.text, pos: token.pos_ } }

    tokens.map do |t|
      {
        surface: t.text,
        lemma: t.lemma,
        pos: t.pos,
        tag: t.tag,
        dep: t.dep,
        ent_type: t.ent_type,
        morphology: t.morphology(hash: false)
      }
    end

    # Format the result as a string (you can customize this)
    result = "Tokens and POS tags:\n"
    tokens.each do |token|
      result += "- #{token[:text]} (#{token[:pos]})\n"
    end

    result
  end
end

# Example Usage (assuming a chat object exists)
# spacey_tool = SpaceyTool.new
# chat.with_tool(spacey_tool)

# response = chat.ask('Analyze the sentence: The quick brown rabbit jumps over the lazy frogs.')
# puts response.content
