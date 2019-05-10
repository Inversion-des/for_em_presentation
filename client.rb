# title Client
# cls & ruby25 client.rb
require 'eventmachine'
require 'em-http'
require 'json'

EM.run do
	EM.add_periodic_timer 0.1 do
		puts '.'
	end


	service_url = 'http://127.0.0.1:2233'

	puts '> time?'
	EM::HttpRequest.new(service_url+'/what_time_is_it').get.callback do |http|
		data = JSON.parse http.response
		puts "  < received: #{data}"
	end
	
	EM.add_timer 0.11 do
		puts '> alive?'
		EM::HttpRequest.new(service_url+'/is_alive').get.callback do |http|
			data = JSON.parse http.response
			puts "  < received: #{data}"
		end
	end


	EM.add_timer 2 do
		EM.stop
	end
end