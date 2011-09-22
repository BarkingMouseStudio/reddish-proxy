process.title = 'reddish-proxy'

look = require('eyes').inspector()
log = require('logging')

argv = require('optimist')
  .usage('Usage: $0 --url [url] --key [key]')
  .demand(['url', 'key'])
  .default('url', 'redis://127.0.0.1:6379')
  .alias('url', 'u')
  .describe('url', 'A formatted redis url')
  .describe('key', 'Your reddish api key')
  .alias('key', 'k')
  .argv

url = require('url')
redis = require('redis')
_ = require('underscore')

url_parts = url.parse(argv.url)


io = require('socket.io-client')
socket = io.connect("http://dev.freeflow.io/local?key=#{argv.key}")

socket.on 'error', (err) ->
  log err

socket.on 'connect_failed', (err) ->
  log err

socket.on 'connect', -> log 'connect'
socket.on 'disconnect', -> log 'disconnect'

socket.on 'redis:message', (message) ->

redis_client = redis.createClient(url_parts.port, url_parts.hostname)
redis_monitor = redis.createClient(url_parts.port, url_parts.hostname)

if url_parts.auth
  auth_parts = url_parts.auth.split(':')
  pass = auth_parts[1]

  redis_client.auth pass, (err, reply) ->
    log err, reply

  redis_monitor.auth pass, (err, reply) ->
    log err, reply

redis_client.on 'error', (err) ->
  log err

redis_monitor.on 'error', (err) ->
  log err

redis_client.on 'ready', ->
  log 'ready'
  socket.emit 'redis:connect'

redis_client.on 'end', ->
  log 'end'
  socket.emit 'redis:end'

redis_monitor.monitor()
redis_monitor.on 'monitor', (time, args) ->
  log time, args
