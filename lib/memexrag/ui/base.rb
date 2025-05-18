#!/usr/bin/env ruby
# frozen_string_literal: true

# This module provides user interface (UI) elements and functions for the Flowbots application.
module UI
  # The width of the title box.
  TITLE_WIDTH = 80
  # An instance of the Pastel gem for colorizing text.
  PASTEL = Pastel.new

  module_function

  # Returns the TTY::Prompt instance used for user interaction.
  #
  # @return [TTY::Prompt] The TTY::Prompt instance.
  def prompt
    @prompt ||= TTY::Prompt.new(enable_color: true, active_color: :cyan)
  end

  # Displays a message to the user with the specified type and logs it.
  #
  # @param type [Symbol] The type of message (:ok, :warn, :error, or nil).
  # @param statement [String] The message to display.
  #
  # @return [void]
  def say(type, statement)
    # Default to :ok type if nil.
    type = :ok if type.nil?

    # Display the message based on the type and log it.
    case type
    when :ok
      prompt.ok(statement)
      logger.info statement
    when :warn
      prompt.warn(statement)
      logger.warn statement
    when :error
      prompt.error(statement)
      logger.fatal statement
    else
      puts PASTEL.say(statement)
    end
  end

  # Displays an information message in a framed box.
  #
  # @param text [String] The text to display in the info box.
  #
  # @return [void]
  def info(text)
    # Display the header.
    header
    # Create a framed box with the specified text and title.
    box = TTY::Box.frame(width: TITLE_WIDTH, title: { top_left: " Information " }, padding: 1) do
      text
    end
    # Print the box.
    puts box
  end

  # Displays the Flowbots header in a framed box.
  #
  # @return [void]
  def header
    # Create a framed box with the Flowbots title and mbota foreground color.
    box = TTY::Box.frame(width: TITLE_WIDTH, title: { top_left: " Flowbots " }, style: { fg: :mbota })
    # Print the box.
    puts box
  end

  # Displays the Flowbots footer in a framed box.
  #
  # @return [void]
  def footer
    # Create a framed box with the "Alright" title in the bottom right corner.
    box = TTY::Box.frame(width: TITLE_WIDTH, title: { bottom_right: " Alright " })
    # Print the box.
    puts box
  end

  # Displays the main menu and prompts the user for a choice.
  #
  # @return [Symbol] The value of the selected choice.
  def main_menu
    # Define the choices for the main menu.
    choices = [
      { name: "Start Workflow", value: :workflow },
      { name: "Configure Settings", value: :settings },
      { name: "View Logs", value: :logs },
      { name: "Exit", value: :exit }
    ]

    # Display the main menu prompt and return the selected choice.
    prompt.select("Welcome to Flowbots. What would you like to do?", choices)
  end

  # Creates and returns a TTY::Spinner instance with the specified text.
  #
  # @param text [String] The text to display next to the spinner.
  #
  # @return [TTY::Spinner] The TTY::Spinner instance.
  def spinner(text)
    TTY::Spinner.new("[:spinner] #{text}", format: :dots)
  end
end
