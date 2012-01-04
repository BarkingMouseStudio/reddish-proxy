# set the process title for `ps`

process.title = 'reddish-proxy'


# import modules

url = require 'url'
net = require 'net'
tls = require 'tls'
redis = require 'redis'
optimist = require 'optimist'


# setup command line arguments

argv = optimist
  .usage("Usage: #{process.title} --url [url] --key [key]")
  .demand(['url', 'key'])
  .default('url', 'redis://127.0.0.1:6379')
  .alias('url', 'u')
  .describe('url', 'A formatted redis url')
  .describe('key', 'Your Reddish connection key')
  .alias('key', 'k')
  .argv


# deconstruct args

{ key, url: arg_url } = argv


# connection key validation regex

key_regex = /^[a-f0-9]{40}$/i


# valid the connection key

unless key_regex.test(key)
  console.error 'ERROR: Invalid connection key', key
  return


# deconstruct `redis://` url

{ port: redis_port, hostname: redis_hostname } = url.parse(arg_url)


# setup Reddish connection details

reddish_port = 8000
reddish_monitor_port = 8001
reddish_hostname = 'reddi.sh'


# setup handshaken and connected state

handshaken = monitor_handshaken = false
connected = monitor_connected = false


# initialize Redis connection

console.log 'Redis client connecting...', redis_port, redis_hostname
redis_client = net.createConnection(redis_port, redis_hostname)
redis_client.setTimeout(0)
redis_client.setNoDelay()
redis_client.setKeepAlive(true)

console.log 'Redis monitor client connecting...', redis_port, redis_hostname
redis_monitor_client = net.createConnection(redis_port, redis_hostname)
redis_monitor_client.setTimeout(0)
redis_monitor_client.setNoDelay()
redis_monitor_client.setKeepAlive(true)


# initialize Reddish connection

console.log 'Reddish endpoint connecting...', reddish_port, reddish_hostname
reddish_endpoint = tls.connect reddish_port, reddish_hostname, ->
  connected = true

  unless handshaken
    console.log "Handshaking with endpoint at #{reddish_hostname}:#{reddish_port}..."
    reddish_endpoint.write(data = JSON.stringify(key: key))

reddish_endpoint.setTimeout(0)
reddish_endpoint.setNoDelay()
# reddish_endpoint.setKeepAlive(true)

console.log 'Reddish monitor endpoint connecting...', reddish_monitor_port, reddish_hostname
reddish_monitor_endpoint = tls.connect reddish_monitor_port, reddish_hostname, ->
  monitor_connected = true

  unless monitor_handshaken
    console.log "Handshaking with monitor endpoint at #{reddish_hostname}:#{reddish_monitor_port}..."
    reddish_monitor_endpoint.write(data = JSON.stringify(key: key))
reddish_monitor_endpoint.setTimeout(0)
reddish_monitor_endpoint.setNoDelay()
# reddish_monitor_endpoint.setKeepAlive(true)


# handle Redis connect event

redis_client.on 'connect', ->
  console.log "Redis client connected to #{redis_hostname}:#{redis_port}"

redis_monitor_client.on 'connect', ->
  console.log "Redis monitor client connected to #{redis_hostname}:#{redis_port}"


# handle Redis data event

redis_client.on 'data', (data) ->
  reddish_endpoint.write(data) if handshaken

redis_monitor_client.on 'data', (data) ->
  reddish_monitor_endpoint.write(data) if monitor_handshaken


# handle Redis close event

redis_client.on 'close', (err) ->
  console.error 'ERROR: Redis client closed'
  if connected
    console.error 'ERROR: Reconnecting Redis client'
    redis_client.connect(redis_port, redis_hostname) 

redis_monitor_client.on 'close', (err) ->
  console.error 'ERROR: Redis monitor client closed'
  if monitor_connected
    console.error 'ERROR: Reconnecting monitor Redis client'
    redis_client.connect(redis_port, redis_hostname) 


# handle Redis error event

redis_client.on 'error', (err) ->
  console.error 'ERROR: Redis client error', err.message if err

redis_monitor_client.on 'error', (err) ->
  console.error 'ERROR: Redis monitor client error', err.message if err


# handle Reddish data event

reddish_endpoint.on 'data', (data) ->
  unless handshaken
    try
      json = JSON.parse(data.toString())

      if err = json?.error
        console.error 'ERROR: Endpoint handshake failed:', err
        return

      console.log 'Endpoint handshake succeeded'
      console.log "SUCCESS: Proxying redis client at #{redis_hostname}:#{redis_port} to reddish endpoint at #{reddish_hostname}:#{reddish_monitor_port}..."
      handshaken = true
    catch err then console.error 'ERROR: Endpoint handshake failed:', err
    return

  redis_client.write(data)

reddish_monitor_endpoint.on 'data', (data) ->
  unless monitor_handshaken
    try
      json = JSON.parse(data.toString())

      if err = json?.error
        console.error 'ERROR: Monitor endpoint handshake failed:', err
        return

      console.log 'Monitor endpoint handshake succeeded'
      console.log "SUCCESS: Proxying redis monitor client at #{redis_hostname}:#{redis_port} to reddish monitor endpoint at #{reddish_hostname}:#{reddish_monitor_port}..."
      monitor_handshaken = true
    catch err then console.error 'ERROR: Monitor endpoint handshake failed:', err
    return

  redis_monitor_client.write(data)


# handle Reddish close event

reddish_endpoint.on 'close', (err) ->
  connected = false
  console.error 'ERROR: Reddish endpoint closed: closing Redis client'
  redis_client.end()

reddish_monitor_endpoint.on 'close', (err) ->
  monitor_connected = false
  console.error 'ERROR: Reddish monitor endpoint closed: closing Redis monitor client'
  redis_monitor_client.end()


# handle Reddish error event

reddish_endpoint.on 'error', (err) ->
  console.error 'ERROR: Reddish endpoint error', err.message if err

reddish_monitor_endpoint.on 'error', (err) ->
  console.error 'ERROR: Reddish monitor endpoint error', err.message if err
