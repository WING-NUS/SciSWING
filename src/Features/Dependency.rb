#/usr/bin/ruby
# encoding: UTF-8

### 20/05/2014 - Ankur

#TODO Description of what this script does.

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
  serverlog = "#{parserdir}/Server.log"
  classpath = "#{parserdir}:#{parserdir}/*"
  parser = "ParseServer"
  server_job = Daemons.call do
  #server_job = fork do
    `java -classpath "#{classpath}" #{parser} >#{serverlog}`
  end
  #Process.detach(server_job)

  # Wait for a sec while the socket is properly initialized.
  # Ankur: On my dev machine (P4 2.6 GHz, 2 cores, 512 K cache), it took around
  # 3 seconds to get the server to start up gracefully before shoving data into
  # it.
  sleep 3

  # Everything from this point on should be included within this begin..rescue
  # block so that if something happens, the socket is closed and the daemon is
  # stopped lest it is orphaned and runs amuck.
  begin
    #client_socket = hand_shake
    #['Samantha killed the dog in the park.',
    #'Gabriele has a thick Italian accent.',
    #'Where will we go for dinner?'].each do |sent|
    #  client_socket.puts(sent)
    #  puts client_socket.recv(4096)
    #end

    client_socket = hand_shake

    ARGF.each do |l_JSN|

      $g_JSON = JSON.parse l_JSN
      $g_JSON["corpus"].each do |l_Article|
        l_Article["top_sentences"].each do |rank, sentence|
          client_socket.puts(sentence)
          dep_parse = JSON.parse client_socket.recv(4096)
          puts JSON.pretty_generate dep_parse

    client_socket.puts "q\n"
    client_socket.close
  rescue
    raise
  ensure
    puts "Stopping Parser Server"
    server_job.stop
  end

  server_job.stop
end
