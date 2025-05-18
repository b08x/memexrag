# frozen_string_literal: true

module MemexRAG
  module Parser
    class JSON
      def self.parse(file_path)
        json = File.new(file_path, 'r')
        parser = Yajl::Parser.new(symbolize_keys: true)
        parser.parse(json)
      end
    end
  end
end
