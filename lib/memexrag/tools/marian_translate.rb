# frozen_string_literal: true
module MemexRAG
  module Tools
    class DravidianTranslator < RubyLLM::Tool
      description "Translates between English and Dravidian languages using a Python script."
      
      param :text,
            type: :string,
            desc: 'The input text to be translated.',
            required: true


      def initialize
        super
      end

      def execute(text:, mode: "round-trip", target_lang: "tam")
        unless ["en-to-dra", "dra-to-en", "round-trip"].include?(mode)
          raise ArgumentError, "Invalid mode.  Must be one of: en-to-dra, dra-to-en, round-trip"
        end

        unless ["tam", "mal", "kan", "tel"].include?(target_lang)
          raise ArgumentError, "Invalid target_lang. Must be one of: tam, mal, kan, tel"
        end

        @command = "python scripts/en_tam_en.py --text \"#{text}\" --mode #{mode} --target-lang #{target_lang}"

        begin
          translation = `#{@command}`.strip
          if $?.success?
            return translation
          else
            raise "Translation failed: #{translation}"
          end
        rescue => e
          raise "Error during translation: #{e.message}"
        end
      end
    end

end
end