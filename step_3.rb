# title step_3
# cls & ruby25 step_3.rb
# позбулися тредів, блокувань і тепер сокети опитуються в реакторі
# але через асинхронну роботу запитів появилися вкладені колбеки (5) і проміси (dfrd)

%w[eventmachine em-http json].each {|_| require _ }

class MicroService < EM::Connection
	SITES = %w[http://www.gov.ua http://kyivstar.ua http://www.google.com.ua]
	@@location_uri = URI 'http://api.ipstack.com/46.219.188.122?access_key=c9bc9b3980b6ce6de9db75b8db1d6fd9&fields=latitude,longitude'
	@@timezone_by_location_uri = URI 'http://api.timezonedb.com/v2.1/get-time-zone?key=0HD6A7CVP8I5&by=position&lat=50.4547&lng=30.5238&fields=countryCode,cityName,gmtOffset&format=json'

	def receive_data(msg)
		if msg =~ /GET \/(\S+)/
			action = $1
			puts "<<-- action received: #{action}"
			self.send action
		end
	end

	def send_response(data)
		msg = JSON.generate data
		send_data "HTTP/1.1 200\r\nContent-length: #{msg.length}\r\n\r\n#{msg}"
	end

	def what_time_is_it
		tasks = EM::MultiRequest.new
		result = {}

		# get timezone by IP
		EM::DefaultDeferrable.new.tap do |dfrd|
			tasks.add :get_timezone, dfrd
			port, ip = Socket.unpack_sockaddr_in(get_peername)
			puts '> get latitude-longitude'
			EM::HttpRequest.new(@@location_uri).get.callback do |http|
				pp JSON.parse http.response
				# {"latitude"=>50.4547, "longitude"=>30.5238}

				puts '> get timezone'
				EM::HttpRequest.new(@@timezone_by_location_uri).get.callback do |http|
					data = JSON.parse http.response
					pp data
					# gmtOffset: 10800
					result.update  gmt_offset: data['gmtOffset']
					dfrd.succeed
				end
			end
		end

		# get time
		EM::DefaultDeferrable.new.tap do |dfrd|
			tasks.add :get_time, dfrd
			EM::MultiRequest.new.tap do |multi|
				results = []
				SITES.each do |url|
					my_index = SITES.index url
					puts "> get time #{my_index}"
					request = EM::HttpRequest.new(URI url).get
					request.callback do
						# results << http
						puts "  < res time #{my_index}"
					end
					multi.add my_index, request
				end
				multi.callback do
					results = multi.responses[:callback].map do |index, http|
						http.response_header['DATE']
					end
					pp results
					result.update  time: results.sort[1]
					dfrd.succeed
				end
			end
		end

		tasks.callback do
			puts "\n-- 2 results ready --"
			pp result
	
			# Answer
			time = Time.parse(result[:time]) + result[:gmt_offset]
			puts ">> Answer: #{time.strftime '%H:%M'}"
	
			send_response res: time.strftime('%H:%M')
	
			EM.add_timer 0.2 do
				EM.stop
			end
		end

	end

	def is_alive
		puts ">> yes"
		send_response res:'yes'
	end
end

EM.run do
	EM.add_periodic_timer 0.1 do
		puts '.'
	end

	EM.start_server '127.0.0.1', 2233, MicroService		
end