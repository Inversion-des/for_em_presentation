# title step_1
# cls & ruby25 step_1.rb
# sockets + many threads (8 одночасних при одному запиті)
# на кожен запит є блокуючий, тому ми їх робимо у тредах

%w[socket net/http json time].each {|_| require _ }

class MicroService
	SITES = %w[http://www.gov.ua http://kyivstar.ua http://www.google.com.ua]
	@@location_uri = URI 'http://api.ipstack.com/46.219.188.122?access_key=c9bc9b3980b6ce6de9db75b8db1d6fd9&fields=latitude,longitude'
	@@timezone_by_location_uri = URI 'http://api.timezonedb.com/v2.1/get-time-zone?key=0HD6A7CVP8I5&by=position&lat=50.4547&lng=30.5238&fields=countryCode,cityName,gmtOffset&format=json'

	def initialize
		server = TCPServer.open '127.0.0.1', 2233
		Thread.new do
			loop do
				puts '.'
				sleep 0.1
			end
		end
		loop do
			Thread.new(((server.accept))) do |client|
				while !(msg = (((client.recv 500))) ).empty?
					if msg =~ /GET \/(\S+)/
						action = $1
						puts "<<-- action received: #{action}"
						res = self.send action, client
						send_response client, res
					end
				end
			end
		end
	end

	def send_response(client, data)
		msg = JSON.generate data
		puts ">> " + msg
		client.puts "HTTP/1.1 200\r\nContent-length: #{msg.length}\r\n\r\n#{msg}"
	end

	def what_time_is_it(client)
		result = {}
		tasks = []
		
		# get timezone by IP
		tasks << Thread.new do
			port, ip = Socket.unpack_sockaddr_in(client.getpeername)
			puts '> get latitude-longitude'
			res = Net::HTTP.get(@@location_uri)
			pp JSON.parse res
			# {"latitude"=>50.4547, "longitude"=>30.5238}

			puts '> get timezone'
			res = Net::HTTP.get(@@timezone_by_location_uri)
			data = JSON.parse res
			pp data
			# gmtOffset: 10800
			result.update  gmt_offset: data['gmtOffset']
		end
		
		# get time
		tasks << Thread.new do
			results = []
			threads = SITES.map do |url|
				Thread.new do
					my_index = SITES.index url
					puts "> get time #{my_index}"
					response = Net::HTTP.get_response(URI url)
					results << response['DATE']
					puts "  < res time #{my_index}"
				end
			end
			threads.each &:join
			pp results
			result.update  time: results.sort[1]
		end

		tasks.each &:join
		puts "\n-- 2 results ready --"
		pp result

		# Answer
		time = Time.parse(result[:time]) + result[:gmt_offset]
		puts ">> Answer: #{time.strftime '%H:%M'}"

		{res: time.strftime('%H:%M')}
	end

	def is_alive(client)
		{res:'yes'}
	end

end

MicroService.new