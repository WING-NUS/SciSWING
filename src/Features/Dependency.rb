#/usr/bin/ruby
# encoding: UTF-8

### 20/05/2014 - Ankur

# This script takes as input a json which should ideally be the output of the
# module Ranker.rb. It searches for the top sentences, and then for each of
# these sentences, it creates the dependency parse and attaches it to the same
# json as output.
# To create the dependency parse, first the UNIX socket server, located in
# $project_dir/lib/Stanford-Parser/ParseServer.java, is cranked up and it
# starts listening on the same host on port 5000. Then its a matter of passing
# the sentences to it on the same port.

require 'socket'
require 'daemons'
require 'json'

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
    `java -classpath "#{classpath}" #{parser} >#{serverlog}`
  end

  # Wait for a sec while the socket is properly initialized.
  # Ankur: On my dev machine (P4 2.6 GHz, 2 cores, 512 K cache), it took around
  # 3 seconds to get the server to start up gracefully before shoving data into
  # it.
  sleep 3

  # Everything from this point on should be included within this begin..rescue
  # block so that if something happens, the socket is closed and the daemon is
  # stopped lest it is orphaned and runs amuck.
  begin

    # Initiate communication with the parse-server
    client_socket = hand_shake

    ARGF.each do |l_JSN|

      $g_JSON = JSON.parse l_JSN
      $g_JSON["corpus"].each do |l_Article|
        l_Article["top_sentences"].each do |rank, sent_data|
          client_socket.puts(sent_data["sentence"])
          dep_parse = JSON.parse client_socket.recv(4096)
          l_Article["top_sentences"][rank] = { :id => sent_data["id"],
                                               :sentence => sent_data["sentence"],
                                               :dep_parse => dep_parse["parse"] }
        end
      end
      puts JSON.generate $g_JSON

    end

    client_socket.puts "q\n"
    client_socket.close
  rescue
    raise
  ensure
    # Stopping parse-server
    server_job.stop
  end
  # This is redundant
  server_job.stop
end
