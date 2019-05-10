# telnet 127.0.0.1 2233
require 'socket'

server = TCPServer.open '127.0.0.1', 2233
loop do
	Thread.new(((server.accept))) do |client|
		while !(msg = (((client.recv 500))) ).empty?
			puts "<< received: #{msg}"
			exit if msg == 'q'
			client.print 'response >>'
		end
	end
end
