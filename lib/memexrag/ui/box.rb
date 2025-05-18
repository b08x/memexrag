#!/usr/bin/env ruby
# frozen_string_literal: true

require "tty-box"
require "tty-screen"

# This module provides methods for creating and displaying boxes in the UI.
module UI
  # This module provides methods for creating and displaying boxes in the UI.
  module Box
    module_function

    # Creates a box containing two texts side-by-side for comparison.
    #
    # @param text1 [String] The first text to display.
    # @param text2 [String] The second text to display.
    # @param title1 [String] The title for the first text box (default: "Text 1").
    # @param title2 [String] The title for the second text box (default: "Text 2").
    #
    # @return [String] The combined box containing both texts.
    def comparison_box(text1, text2, title1: "Text 1", title2: "Text 2")
      # Calculate the screen width and text width.
      screen_width = TTY::Screen.width - 2
      text_width = [text1.length, text2.length, 40].max + 4
      # Determine the width of the boxes based on screen width, text width, and title width.
      width = [text_width, screen_width, TITLE_WIDTH].min

      # Create the first box with the specified title and padding.
      box1 = TTY::Box.frame(width:, title: { top_left: title1 }, padding: 1) { text1 }
      # Create the second box with the specified title and padding.
      box2 = TTY::Box.frame(width:, title: { top_left: title2 }, padding: 1) { text2 }
      # Concatenate the two boxes and return the result.
      box1 + box2
    end

    # Creates a box displaying the evaluation result with a success style.
    #
    # @param result [String] The evaluation result to display.
    # @param title [String] The title for the box (default: "Evaluation Result").
    #
    # @return [String] The box containing the evaluation result.
    def eval_result_box(result, title: "Evaluation Result")
      # Create a success box with the specified result, title, width, height, and padding.
      TTY::Box.success(
        result,
        title: { top_left: title },
        width: 80,
        height: (TTY::Screen.height / 1.25).round,
        padding: 1
      )
    end

    # Creates a box displaying an exception message with an error style.
    #
    # @param message [String] The exception message to display.
    #
    # @return [String] The box containing the exception message.
    def exception_box(message)
      # Create an error box with the specified message, title, width, and padding.
      TTY::Box.error(
        message,
        title: { top_left: "Error" },
        width: [TTY::Screen.width - 2, TITLE_WIDTH].min,
        padding: 1
      )
    end

    # Creates a box displaying an information message with an info style.
    #
    # @param message [String] The information message to display.
    # @param title [String] The title for the box (default: "Info").
    #
    # @return [String] The box containing the information message.
    def info_box(message, title: "Info")
      # Create an info box with the specified message, title, width, and padding.
      TTY::Box.info(message, title: { top_left: title }, width: [TTY::Screen.width - 2, 50].min, padding: 1)
    end

    # Creates a box displaying data in multiple columns with headers.
    #
    # @param data [Array<Array>] A 2D array of data to display in the columns.
    # @param titles [Array<String>] An array of titles for the columns.
    #
    # @return [String] The box containing the multi-column data.
    def multi_column_box(data, titles)
      # Calculate the maximum width for each column based on the data.
      max_widths = data.transpose.map { |col| col.map(&:to_s).map(&:length).max }
      # Calculate the total width of the box based on column widths and separators.
      total_width = max_widths.sum + (3 * (max_widths.size - 1)) + 4

      # Format each row of data with appropriate padding.
      rows = data.map do |row|
        row.zip(max_widths).map { |cell, width| cell.to_s.ljust(width) }.join(" | ")
      end

      # Format the header row with appropriate padding.
      header = titles.zip(max_widths).map { |title, width| title.to_s.ljust(width) }.join(" | ")
      # Create a separator line for the header.
      separator = max_widths.map { |w| "-" * w }.join("-+-")

      # Combine the header, separator, and data rows into a single string.
      content = [
        header,
        separator,
        rows.join("\n")
      ].join("\n")

      # Create a framed box with the formatted content and appropriate width.
      TTY::Box.frame(content, width: [total_width, TTY::Screen.width - 2].min, padding: 1)
    end
  end
end
