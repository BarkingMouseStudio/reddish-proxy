process.title = 'reddish-proxy'

optimist = require('optimist')
redis = require('redis')
url = require('url')

net = require 'net'

argv = optimist
  .usage("Usage: #{process.title} --url [url] --key [key]")
  .demand(['url', 'key'])
  .default('url', 'redis://127.0.0.1:6379')
  .alias('url', 'u')
  .describe('url', 'A formatted redis url')
  .describe('key', 'Your Reddish api key')
  .alias('key', 'k')
  .argv

key = argv.key

unless /^[a-f0-9]{40}$/i.test(key)
  console.error 'Invalid API key', key
  return

{ port: redis_port, hostname: redis_hostname } = url.parse(argv.url)
reddish_port = 8000
reddish_hostname = if process.env.NODE_ENV is 'production' then 'reddish.freeflow.io' else 'dev.freeflow.io'
handshaken = false

console.log "Proxying #{redis_hostname}:#{redis_port} to #{reddish_hostname}:#{reddish_port}..."

console.log 'Redis client connecting...', redis_port, redis_hostname
redis_client = net.createConnection(redis_port, redis_hostname)

console.log 'Reddish client connecting...', reddish_port, reddish_hostname
reddish_client = net.createConnection(reddish_port, reddish_hostname)

redis_client.on 'connect', ->
  console.log "Redis client connected to #{redis_hostname}:#{redis_port}"

redis_client.on 'data', (data) -> reddish_client.write(data) if handshaken

redis_client.on 'close', (err) ->
  console.error 'Redis client closed', err if err
  console.error 'Closing Reddish client'
  reddish_client.end()

reddish_client.on 'connect', ->
  console.log "Handshaking with #{reddish_hostname}:#{reddish_port}...", key
  reddish_client.write(data = JSON.stringify(key: key))

reddish_client.on 'data', (data) ->
  unless handshaken
    try
      json = JSON.parse(data.toString())

      if err = json?.error
        console.error 'Handshake failed:', err
        return

      console.log 'Handshake succeeded'
      handshaken = true
    catch err then console.error 'Handshake failed:', err
    return

  redis_client.write(data)

reddish_client.on 'close', (err) ->
  console.error 'Reddish client closed', err if err
  console.error 'Closing Redis client'
  redis_client.end()
