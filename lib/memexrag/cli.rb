#!/usr/bin/env ruby
# frozen_string_literal: false

module MemexRAG
  class CLI
    extend Drydock

    default :welcome
    debug :on

    before do
      @hostname = `cat /etc/hostname`.strip
    end

    about 'A friendly welcome to the Drydock'
    command :welcome do
      puts UI::Box.info_box("Hey! It's Flowbots!\n\nFor available commands:\n#{$0} --help")
    end

    usage "USAGE: #{$0} test [-f]"
    about 'main menu'
    option :f, :faster, 'A boolean value. Go even faster!'
    command :menu do |obj|
      if obj.option.faster
        puts 'do something'
      else
        puts 'do something else'
      end
    end

    about 'workflows'
    command :workflows do |_obj|
      menu = WorkflowMenu.new
      menu.display
    end

    # about "start osc server"
    # command :osc do |_obj|
    #   $logger.info "starting osc server"
    #   Daemons.run(File.join(File.dirname(__FILE__), 'osc.rb'), $daemon_options)
    # end

    about 'import one or more files and/or folders'
    option :u, :update, 'Update file objects'
    command :import do |obj|
      require 'pathname'

      sources = obj.argv.map { |source| Pathname.new(source) }

      sources.each do |source|
        p source.exist?
        # import = Import.new(source)
        # import.start
      end
    end
  end # end cli class
end # end memexrag module
