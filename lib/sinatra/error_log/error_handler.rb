
#
# This module adds sinatra handlers to log 404, app and javascript errors to log files
# and a view to show them later
#
# In addition to this file, you also need error.js file (if you want to log javascript errors), and the
# errors.erb view, to make it easier to view the logs
#
# @reednj, 29/05/2015
#

require 'yaml'

#
# Helper classes
#

class ErrorHelper
	@log_dir = 'log'
	@log_file = 'error.log'

	def self.configure_log_path!
		Dir.mkdir(@log_dir) if !File.directory?(@log_dir)
	end

	def self.log_path(filename = nil)
		File.join(@log_dir, filename || @log_file)
	end

	def self.log_js_error(js_data, options = nil)
		options ||= {}
		request = options[:request]
		configure_log_path!
		
		url = js_data[:url]
		url = URI(js_data[:url] || 'http://reddit-stream.com/').path

		client = {
			:user_agent => request.user_agent,
			:username => js_data[:username],
			:ip => request.ip
		}

		other = {
			:referrer => request.referrer,
			:page_url => js_data[:page_url]
		}

		data = {
			:name => 'Javascript', 
			:method => 'SCRIPT',
			:path => url,
			:message => js_data[:error_msg],
			:line_number => js_data[:line_number],
			:client => client,
			:other => other,
			:date => Time.now.utc.iso8601
		}

		log_data(data, options[:filename])
	end

	def self.log_simple_error(message, options=nil)
		options ||= {}
		e = options[:e]
		configure_log_path!

		data = {
			:name => 'Error',
			:path => options[:path],
			:method => options[:method],
			:params => options[:params],
			:message => message,
			:date => Time.now.utc.iso8601, 
		}

		if !e.nil? 
			data[:name] = (e.respond_to? 'name')? ("#{e.class} (#{e.name})") : e.class
			data[:backtrace] = e.backtrace
		end

		log_data(data, options[:filename])
	end

	def self.log_error(message, options = nil)
		options ||= {}
		configure_log_path!

		request = options[:request]

		if request.nil?
			# if we don't have any request data, then we can't do much more than just log the message
			# and the time, so do that...
			self.log_simple_error message, options
			return
		end

		e = request.env['sinatra.error']
		Dir.mkdir(@log_dir) if !File.directory?(@log_dir)

		client = {
			:user_agent => request.user_agent,
			:ip => request.ip
		}

		other = {
			:referrer => request.referrer
		}

		if e.nil?
			data = {
				:name => 'unknown error', 
				:path => request.path, 
				:date => Time.now.utc.iso8601, 
				:message => message,
				:method => request.request_method,
				:params => request.params,
				:client => client,
				:other => other
			}
		else
			message = e.message
			message.gsub!(/"data:image\/png;(.*)"/, '""')  if message.include? 'src="data:image/png'
			name = (e.respond_to? 'name')? ("#{e.class} (#{e.name})") : e.class
			data = {
				:name => name, 
				:path => request.path, 
				:message => message, 
				:backtrace => e.backtrace, 
				:date => Time.now.utc.iso8601,
				:method => request.request_method,
				:params => request.params,
				:client => client,
				:other => other
			}
		end

		log_data(data, options[:filename])
	end

	def self.log_data(data, filename=nil)
		File.append(self.log_path(filename), data.to_json + "\n")
	end

	def self.error_list(file_prefix = nil)
		filename = file_prefix.nil? ? nil : "#{file_prefix}_error.log"
		path = self.log_path(filename)
		return [] if !File.exists? path

		max_length = 200
		data = nil

		File.open(path, 'r:UTF-8') do |file| 
			data = file.read 
		end

		data = data.split "\n"
		data = data[-max_length..-1] if data.length > max_length
		data.map do |line| 
			JSON.parse(line, {:symbolize_names => true} ) 
		end
	end

	def self.clear_log(file_prefix)
		filename = file_prefix.nil? ? nil : "#{file_prefix}_error.log"
		path = self.log_path(filename)
		File.truncate path, 0
	end
end

