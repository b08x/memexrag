#!/usr/bin/env ruby
# frozen_string_literal: true

require "tty-box"
require "tty-screen"

# This module provides methods for creating and displaying scrollable boxes in the UI.
module UI
  # This module provides methods for creating and displaying scrollable boxes in the UI.
  module ScrollableBox
    module_function

    # Creates and displays two scrollable boxes side-by-side for comparison.
    #
    # @param text1 [String] The text to display in the first box.
    # @param text2 [String] The text to display in the second box.
    # @param title1 [String] The title for the first box (default: "Box 1").
    # @param title2 [String] The title for the second box (default: "Box 2").
    #
    # @return [void]
    def side_by_side_boxes(text1, text2, title1: "Box 1", title2: "Box 2")
      # Calculate screen width, screen height, box width, and box height.
      screen_width = TTY::Screen.width / 1.25
      screen_height = TTY::Screen.height
      box_width = (screen_width / 2.5) - 2
      box_height = screen_height - 4 # Leave some space for prompts

      # Create scrollable boxes for the given texts.
      box1 = create_scrollable_box(text1, box_width, box_height, title1)
      box2 = create_scrollable_box(text2, box_width, box_height, title2)

      # Display the boxes and handle user navigation.
      display_boxes(box1, box2, box_height)
    end

    private

    # Creates a scrollable box data structure.
    #
    # @param text [String] The text to display in the box.
    # @param width [Integer] The width of the box.
    # @param height [Integer] The height of the box.
    # @param title [String] The title of the box.
    #
    # @return [Hash] A hash containing the box data.
    def self.create_scrollable_box(text, width, height, title)
      # Split the text into lines.
      lines = text.split("\n")
      # Calculate the total number of pages based on the text length and box height.
      total_pages = (lines.length.to_f / (height - 2)).ceil
      # Return a hash containing the box data.
      {
        title:,
        lines:,
        width:,
        height:,
        total_pages:,
        current_page: 1
      }
    end

    # Displays the scrollable boxes and handles user navigation.
    #
    # @param box1 [Hash] The data for the first box.
    # @param box2 [Hash] The data for the second box.
    # @param box_height [Integer] The height of the boxes.
    #
    # @return [void]
    def self.display_boxes(box1, box2, box_height)
      # Loop until the user quits.
      loop do
        # Clear the screen.
        system("clear") || system("cls")
        # Print the boxes and navigation info.
        print_boxes(box1, box2, box_height)
        print_navigation_info(box1, box2)

        # Get user input.
        input = STDIN.getch
        # Handle user input for navigation and quitting.
        case input.downcase
        when "q"
          break
        when "a"
          box1[:current_page] = [1, box1[:current_page] - 1].max
        when "d"
          box1[:current_page] = [box1[:total_pages], box1[:current_page] + 1].min
        when "j"
          box2[:current_page] = [1, box2[:current_page] - 1].max
        when "l"
          box2[:current_page] = [box2[:total_pages], box2[:current_page] + 1].min
        end
      end
    end

    # Prints the scrollable boxes to the console.
    #
    # @param box1 [Hash] The data for the first box.
    # @param box2 [Hash] The data for the second box.
    # @param box_height [Integer] The height of the boxes.
    #
    # @return [void]
    def self.print_boxes(box1, box2, box_height)
      # Calculate the starting line for each box based on the current page.
      start_line1 = (box1[:current_page] - 1) * (box_height - 2)
      start_line2 = (box2[:current_page] - 1) * (box_height - 2)

      # Extract the content for each box based on the starting line and box height.
      box1_content = box1[:lines][start_line1, box_height - 2].join("\n")
      box2_content = box2[:lines][start_line2, box_height - 2].join("\n")

      # Create framed boxes for each box with the extracted content.
      box1_frame = TTY::Box.frame(width: box1[:width], height: box_height, title: { top_left: box1[:title] }) do
        box1_content
      end
      box2_frame = TTY::Box.frame(width: box2[:width], height: box_height, title: { top_left: box2[:title] }) do
        box2_content
      end

      # Print the boxes side-by-side.
      puts box1_frame.split("\n").zip(box2_frame.split("\n")).map { |a, b| "#{a}  #{b}" }.join("\n")
    end

    # Prints navigation information for the scrollable boxes.
    #
    # @param box1 [Hash] The data for the first box.
    # @param box2 [Hash] The data for the second box.
    #
    # @return [void]
    def self.print_navigation_info(box1, box2)
      # Print the current page and total pages for each box, along with navigation instructions.
      puts "Box 1: Page #{box1[:current_page]}/#{box1[:total_pages]} (A/D to navigate)"
      puts "Box 2: Page #{box2[:current_page]}/#{box2[:total_pages]} (J/L to navigate)"
      puts "Press Q to exit"
    end
  end
end
