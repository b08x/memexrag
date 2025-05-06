#!/usr/bin/env ruby
# gitlab_issues.rb - Create GitLab issues from markdown backlog and generate sprint reports
lib_dir = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include?(lib_dir)

require 'memexrag/logging'
include Logging

require 'uri'
require 'json'
require 'optparse'
require 'net/http'
require 'csv'

require 'dotenv/load'

# Check if .env file exists before attempting to load
if File.exist?('.env')
  Dotenv.load('.env', overwrite: true)
else
  puts "\nWARN: .env file not found. Proceeding without environment variables from .env.\n\n"
end


# Parse command line options
options = {
  dry_run: false,
  gitlab_url: ENV['GITLAB_INSTANCE_URL'] || 'https://gitlab.com',
  token: ENV['GITLAB_PRIVATE_TOKEN'],
  action: 'create'
}

OptionParser.new do |opts|
  opts.banner = "Usage: gitlab_issues.rb [options]"
  
  opts.on("--file FILE", "Path to backlog markdown file") { |v| options[:file] = v }
  opts.on("--project-id ID", "GitLab project ID") { |v| options[:project_id] = v }
  opts.on("--dry-run", "Run without creating actual issues") { options[:dry_run] = true }
  opts.on("--sprint NUMBER", "Generate sprint report for given number") { |v| options[:sprint] = v; options[:action] = 'report' }
  opts.on("--export [FORMAT]", "Export issues to CSV or JSON") { |v| options[:export] = v || 'csv'; options[:action] = 'export' }
  opts.on("--status STATUS", "Filter by status (for reports/exports)") { |v| options[:status] = v }
end.parse!

# Validate required inputs
if options[:file].nil? || !File.exist?(options[:file])
  logger.fatal "Error: Backlog file not found or not specified"
  exit 1
end

if options[:action] == 'create' && (options[:project_id].nil? || options[:token].nil?)
  logger.fatal "Error: GitLab project ID and token are required for issue creation"
  exit 1
end

# Read backlog file
content = File.read(options[:file])

# Parse the markdown table
class BacklogParser
  attr_reader :tasks, :headers

  def initialize(markdown_content)
    @markdown_content = markdown_content
    @tasks = []
    @headers = []
    parse
  end

  def parse
    lines = @markdown_content.split("\n")
    
    # Find the table header line
    header_index = lines.find_index { |line| line.start_with?('|') && line.include?('Task ID') }
    return if header_index.nil?
    
    # Parse headers
    header_line = lines[header_index]
    @headers = header_line.split('|').map(&:strip).reject(&:empty?)
    
    # Skip the separator line
    current_index = header_index + 2
    
    # Parse tasks
    while current_index < lines.size && lines[current_index].start_with?('|')
      columns = lines[current_index].split('|').map(&:strip).reject(&:empty?)
      
      # Map columns to a hash using headers as keys
      if columns.size >= @headers.size
        task = {}
        @headers.each_with_index do |header, idx|
          task[header.downcase.gsub(/\s+/, '_')] = columns[idx] if idx < columns.size
        end
        @tasks << task if task['task_id'] && !task['task_id'].empty?
      end
      
      current_index += 1
    end
  end

  def tasks_by_sprint(sprint_number)
    # Extract sprint content from markdown
    sprint_section = @markdown_content.match(/Sprint #{sprint_number}.*?:(.*?)(?:Sprint \d|$)/m)
    return [] unless sprint_section

    # Get task IDs from the sprint section
    task_ids = sprint_section[1].scan(/([A-Z]+-\d+)/).flatten
    
    # Return all tasks that match these IDs
    @tasks.select { |task| task_ids.include?(task['task_id']) }
  end
  
  def filtered_tasks(filters = {})
    filtered = @tasks
    
    if filters[:status]
      filtered = filtered.select { |task| task['status']&.strip == filters[:status] }
    end
    
    if filters[:milestone]
      filtered = filtered.select { |task| task['milestone']&.strip == filters[:milestone] }
    end
    
    if filters[:sprint]
      filtered = tasks_by_sprint(filters[:sprint])
    end
    
    filtered
  end
end

# Create GitLab issues
class GitLabIssueCreator
  def initialize(options)
    @gitlab_url = options[:gitlab_url].chomp('/')
    @project_id = options[:project_id]
    @token = options[:token]
    @dry_run = options[:dry_run]
  end
  
  def create_issue(task)
    # Extract fields
    title = "[#{task['task_id']}] #{task['category']}: #{task['description']}"
    title = "#{title[0..246]}..." if title.length > 250
    
    description = task['description']
    
    # Create labels from category and main grouping
    labels = []
    if task['category']
      labels << task['category'].downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9_:\-\.\?\&]+/, '')
    end
    
    if task['main_grouping'] && task['main_grouping'] != task['category']
      group_label = task['main_grouping'].downcase.gsub(/\s+/, '-').gsub(/[^a-z0-9_:\-\.\?\&]+/, '')
      labels << group_label unless labels.include?(group_label)
    end
    
    # Prepare milestone ID if available
    milestone_id = nil
    if task['milestone'] && task['milestone'].match?(/^\d+$/)
      env_var = "GITLAB_MILESTONE_ID_#{task['milestone']}"
      milestone_id = ENV[env_var] if ENV[env_var] && ENV[env_var].match?(/^\d+$/)
    end
    
    # Build API request
    uri = URI.parse("#{@gitlab_url}/api/v4/projects/#{@project_id}/issues")
    params = {
      title: title,
      description: description,
      labels: labels.join(',')
    }
    params[:milestone_id] = milestone_id if milestone_id
    
    uri.query = URI.encode_www_form(params)
    
    # Log the request
    logger.info "-" * 40
    logger.info "Processing Task ID: #{task['task_id']}"
    logger.info "  Title: #{title}"
    logger.info "  Labels: #{labels.join(', ')}"
    logger.info "  Milestone: #{milestone_id ? milestone_id : 'None'}" if task['milestone']
    
    if @dry_run
      logger.info "  Dry run: Would create issue via #{uri.to_s}"
      return { success: true, dry_run: true, task_id: task['task_id'] }
    end
    
    # Send the API request
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      
      request = Net::HTTP::Post.new(uri.request_uri)
      request['PRIVATE-TOKEN'] = @token
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        logger.info "  Successfully created issue for #{task['task_id']}"
        return { success: true, task_id: task['task_id'], issue: JSON.parse(response.body) }
      else
        logger.error "  Error creating issue for #{task['task_id']}: #{response.code} #{response.message}"
        logger.error "  Response body: #{response.body}"
        return { success: false, task_id: task['task_id'], error: "#{response.code} #{response.message}" }
      end
    rescue => e
      logger.error "  Exception creating issue for #{task['task_id']}: #{e.message}"
      return { success: false, task_id: task['task_id'], error: e.message }
    end
  end
end

# Main script execution
backlog = BacklogParser.new(content)

case options[:action]
when 'create'
  creator = GitLabIssueCreator.new(options)
  
  pending_tasks = backlog.filtered_tasks(status: 'Pending')
  
  success_count = 0
  error_count = 0
  
  logger.info "Found #{pending_tasks.size} pending tasks in backlog"
  
  pending_tasks.each do |task|
    result = creator.create_issue(task)
    if result[:success]
      success_count += 1
    else
      error_count += 1
    end
  end
  
  logger.info "-" * 40
  if options[:dry_run]
    logger.info "Dry run complete. Would have created #{pending_tasks.size} issues."
  else
    logger.info "Created #{success_count} issues successfully. Encountered #{error_count} errors."
  end

when 'report'
  if options[:sprint].nil?
    logger.error "Sprint number required for sprint report"
    exit 1
  end
  
  sprint_tasks = backlog.tasks_by_sprint(options[:sprint])
  
  if sprint_tasks.empty?
    logger.warn "No tasks found for Sprint #{options[:sprint]}"
    exit 0
  end
  
  # Generate sprint report
  puts "# Sprint #{options[:sprint]} Report"
  puts
  puts "## Tasks Overview"
  puts
  
  # Task statistics
  total = sprint_tasks.size
  completed = sprint_tasks.count { |t| t['status'] == 'Done' }
  in_progress = sprint_tasks.count { |t| t['status'] == 'In Progress' }
  pending = sprint_tasks.count { |t| t['status'] == 'Pending' }
  
  puts "- Total Tasks: #{total}"
  puts "- Completed: #{completed} (#{(completed.to_f/total*100).round(1)}%)"
  puts "- In Progress: #{in_progress} (#{(in_progress.to_f/total*100).round(1)}%)"
  puts "- Pending: #{pending} (#{(pending.to_f/total*100).round(1)}%)"
  puts
  
  # Tasks table
  puts "## Tasks Breakdown"
  puts
  puts "| Task ID | Description | Status | Category |"
  puts "|---------|-------------|--------|----------|"
  
  sprint_tasks.each do |task|
    puts "| #{task['task_id']} | #{task['description']} | #{task['status']} | #{task['category']} |"
  end
  
when 'export'
  filter_options = {}
  filter_options[:status] = options[:status] if options[:status]
  filter_options[:sprint] = options[:sprint] if options[:sprint]
  
  tasks = backlog.filtered_tasks(filter_options)
  
  if tasks.empty?
    logger.warn "No tasks found matching the filter criteria"
    exit 0
  end
  
  case options[:export]
  when 'csv'
    CSV do |csv|
      # Write headers
      csv << backlog.headers
      
      # Write tasks
      tasks.each do |task|
        row = backlog.headers.map { |h| task[h.downcase.gsub(/\s+/, '_')] || '' }
        csv << row
      end
    end
    
  when 'json'
    puts JSON.pretty_generate(tasks)
  end
end
