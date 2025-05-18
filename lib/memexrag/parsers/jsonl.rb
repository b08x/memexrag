# frozen_string_literal: true

require 'jsonl'

module MemexRAG
  module Parser
    class JSONL
      EXTENSIONS = ['.jsonl']
      CONTENT_TYPES = ['application/x-jsonlines', 'application/jsonl']

      def self.parse(file)
        File.open(file, 'r') do |f|
          f.each_line do |line|
            extracted_data = extract_data(line)
            yield extracted_data if block_given?
          end
        end
      end

      def self.extract_data(jsonl_entry)
        data = JSON.parse(jsonl_entry)
        {
          'name' => data['name'],
          'send_date' => data['send_date'],
          'mes' => data['mes']
        }
      end

      def self.handles?(file_path)
        super(file_path, EXTENSIONS, CONTENT_TYPES)
      end
    end
  end
end
