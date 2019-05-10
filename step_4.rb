# title Final
# cls & ruby25 final.rb
# поєднує простоту блокуючого синхронного коду (step 2) та ефективність використання EM (step 3)
# використовуючи файбери (корутини) можна позбутися кодбеків і дефередів і зробити код більш прямолінійним
%w[eventmachine em-synchrony em-synchrony/em-http em-synchrony/fiber_iterator json].each {|_| require _ }

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
		EM::S.next_tick do
			f = Fiber.current
			tasks = []
			concurrency = 3

			# get timezone by IP
			tasks << Fiber.new do
				port, ip = Socket.unpack_sockaddr_in(get_peername)
				puts '> get latitude-longitude'
				http = EM::HttpRequest.new(@@location_uri).get
				pp JSON.parse http.response
				# {"latitude"=>50.4547, "longitude"=>30.5238}

				puts '> get timezone'
				http = EM::HttpRequest.new(@@timezone_by_location_uri, connect_timeout: 10).get
				data = JSON.parse http.response
				pp data
				# gmtOffset: 10800
				f.resume  gmt_offset: data['gmtOffset']
			end

			# get time
			tasks << Fiber.new do
				results = []
				EM::S::FiberIterator.new(SITES, concurrency).each do |url|
					my_index = SITES.index url
					puts "> get time #{my_index}"
			        http = EM::HttpRequest.new(URI url).get
					puts "  < res time #{my_index}"
					results << http.response_header['DATE']
				end
				pp results
				f.resume  time: results.sort[1]
			end

			# work hard
			tasks.each &:resume
			res = {}
			tasks.each do
				res.update(((Fiber.yield)))
			end
			puts "\n-- 2 results ready --"
			pp res

			# Answer
			time = Time.parse(res[:time]) + res[:gmt_offset]
			puts ">> Answer: #{time.strftime '%H:%M'}"

			send_response  res: time.strftime('%H:%M')

			EM::S.sleep 0.21
			EM.stop
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