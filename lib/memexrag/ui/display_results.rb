#!/usr/bin/env ruby
# frozen_string_literal: true

# This task displays the results of the text processing workflow.
module DisplayResults
  module_function

  # Executes the task to display the results of the text processing workflow.
  #
  # @param textfile [TextFile] The processed TextFile object to display results for
  # @return [TextFile] The TextFile object that was displayed
  def execute(textfile)
    logger.info "Starting DisplayResults for file: #{textfile.name}"

    analysis_result = textfile.llm_analysis
    display_results(textfile, analysis_result)

    logger.info "DisplayResults completed"
    textfile
  end

  private

  # Displays the results of the text processing workflow.
  #
  # @param textfile [TextFile] The processed TextFile object.
  # @param analysis_result [String, Hash] The LLM analysis results.
  def display_results(textfile, analysis_result)
    file_info = format_file_info(textfile)
    analysis = format_analysis(analysis_result)

    puts UI::ScrollableBox.side_by_side_boxes(
      file_info,
      analysis,
      title1: "File Information",
      title2: "LLM Analysis Result"
    )
  end

  # Formats the file information for display.
  #
  # @param textfile [TextFile] The processed TextFile object.
  # @return [String] The formatted file information.
  def format_file_info(textfile)
    <<~INFO
      Filename: #{textfile.name}
      Topics: #{textfile.topics.to_a.map(&:name).join(', ')}

      Content Preview:
      #{textfile.content}

      Total Segments: #{textfile.segments.count}
      Total Words: #{textfile.lemmas.count}
    INFO
  end

  # Formats the analysis results for display.
  #
  # @param analysis_result [String, Hash] The LLM analysis results.
  # @return [String] The formatted analysis results.
  def format_analysis(analysis_result)
    analysis_result.is_a?(String) ? analysis_result : JSON.pretty_generate(analysis_result)
  end
end
