require 'eventmachine'

class MyServer < EM::Connection
	def receive_data(msg)
		puts "<< received: #{msg}"
		EM.stop if msg == 'q'
		send_data 'response >>'
	end
end

EM.run do
	EM.start_server '127.0.0.1', 2233, MyServer
end