#/usr/bin/ruby
# encoding: UTF-8

### 20/05/2014 - Ankur

require 'socket'
require 'daemons'

$project_dir = "/home/ankur/devbench/scientific/SciSWING"

def hand_shake
  client_socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM
  client_socket.connect Socket.pack_sockaddr_in(5000, "localhost")
  line = client_socket.gets
  if line.strip == "Connection established"
    client_socket.puts "Load Parser"
    line2 = client_socket.gets
    if line2.strip == "Parser Loaded...Ready to accept sentences..."
      return client_socket
    else
      puts "Something wrong while loading parser"
      puts "#{line2}"
      client_socket.puts "q\n"
      client_socket.close
    end
  else
    puts "Something wrong during initial handshake"
    puts "#{line1}"
    client_socket.puts "q\n"
    client_socket.close
  end
end

if __FILE__ == $0 then
  # Start the server as a background process
  parserdir = "#{$project_dir}/lib/Stanford-Parser"
  serverlog = "#{parserdir}/ParseServer1.log"
  classpath = "#{parserdir}:#{parserdir}/*"
  parser = "ParseServer"
  #server_job = Daemons.call do
  server_job = fork do
    `java -classpath "#{classpath}" #{parser} >#{serverlog}`
  end
  Process.detach(server_job)

  begin
    client_socket = hand_shake
    ['Samantha killed the dog in the park.',
    'Gabriele has a thick Italian accent.',
    'Where will we go for dinner?'].each do |sent|
      client_socket.puts(sent)
      puts client_socket.recv(4096)
    end
    client_socket.puts "q\n"
    client_socket.close
  rescue
    raise
  ensure
    #server_job.stop
  end

  #server_job.stop
end
