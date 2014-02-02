$stdout.sync = true
require "bundler/setup"
require "faye"
require 'redis'
require 'redis/objects'
Redis.current = Redis.new(:host => '127.0.0.1', :port => 6379)

faye_server = Faye::RackAdapter.new(:mount => '/faye', :timeout => 25, :ping => 5)

# online user
faye_server.bind(:subscribe) do |client_id, channel|
  if /\/*\/users\/*/.match(channel)
    m = /\/users\/(?<sex>\w+)\/(?<user_id>\w+)/.match(channel)
    puts "user_id #{m[:user_id]} with sex #{m[:sex].downcase} online from #{channel}"
    if m[:sex].downcase.eql?("female")
      Redis.current.sadd("online_user_ids_female", m[:user_id])
    else
      Redis.current.sadd("online_user_ids_male", m[:user_id])
    end
  end
end

#idle user
faye_server.bind(:unsubscribe) do |client_id, channel|
  if /\/*\/users\/*/.match(channel)
    m = /\/users\/(?<sex>\w+)\/(?<user_id>\w+)/.match(channel)
    puts "user_id #{m[:user_id]} offline from #{channel}"
    if m[:sex].downcase.eql?("female")
      Redis.current.srem("online_user_ids_female", m[:user_id])
    else
      Redis.current.srem("online_user_ids_male", m[:user_id])
    end
  end
end

Faye::WebSocket.load_adapter('thin')
handler = Rack::Handler.get('thin')
handler.run(faye_server, :Port => 9292)
