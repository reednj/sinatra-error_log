require 'sinatra/base'

require "sinatra/error_log/error_handler"
require "sinatra/error_log/version"


module Sinatra
	module ErrorLog
		module Helpers
			# if we have a plaintext response body (less than 128 chars for example)
			# with no html tags, then this method will return it, otherwise it just returns
			# nil
			def short_response_body
				if response.body[0] && response.body[0].length > 0 && response.body[0].length < 128
					return response.body[0]
				else
					return nil
				end
			end

			def log_error(message, options=nil)
				options ||= {}
				options[:request] = request
				ErrorHelper.log_error(message, options)
			end
		end
		
		def self.registered(app)
			app.helpers ErrorLog::Helpers

			app.after '*' do
				if response.server_error?
					# if we get an error message that matches anything in this array, we don't want to log it
					# as they are too common, and cause distraction. We will track them some other way
					error_msg = short_response_body()

					if !settings.production?
						e = request.env['sinatra.error']
						error_msg = e.message if error_msg.nil? && !e.nil?
					end

					log_error(error_msg)
				end
			end

			app.get '/admin/errors/raise' do
				raise 'test exception'
			end

			app.get '/admin/errors/raise/:code' do |code|
				halt (code.to_i || 500), 'test error'
			end

			# standard route to handle the displaying the errors to the user
			# define your own view, or use the default
			app.get '/admin/errors/?:file?' do |file|
				views_path = File.join File.dirname(__FILE__), 'error_log/views'

				erb :'errors', 
					:layout => :_layout, 
					:views => views_path,
					:locals => {
						:file => file,
						:error_list => ErrorHelper.error_list(file).reverse
					}
			end

			app.get '/admin/errors/clear/?:file?' do |file|
				ErrorHelper.clear_log file
				redirect to("/admin/errors/#{file}")
			end

		end
	end

	register ErrorLog
end
