# title step_2
# cls & ruby25 step_2.rb
# воно працює, але все синхронно, довго і другий запит заблокований
# тут можна використати .defer + проміси = буде трохи швидше
# бо використовується тредпул

%w[eventmachine net/http json time].each {|_| require _ }

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
		result = {}

		#-- get timezone by IP
		port, ip = Socket.unpack_sockaddr_in(get_peername)
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


		# get time
		results = []
		SITES.map do |url|
			my_index = SITES.index url
			puts "> get time #{my_index}"
			response = Net::HTTP.get_response(URI url)
			results << response['DATE']
			puts "  < res time #{my_index}"
		end
		pp results
		result.update  time: results.sort[1]

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