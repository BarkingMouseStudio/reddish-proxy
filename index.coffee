process.title = 'reddish-proxy'

url = require 'url'
net = require 'net'
redis = require 'redis'
optimist = require 'optimist'
tls = require 'tls'

options = optimist
  .usage("Usage: #{process.title} --local [local] --remote [remote] --key [key] -p1 [port] -p2 [port]")
  .demand(['local', 'remote', 'key'])
  .default('local', 'redis://127.0.0.1:6379')
  .default('remote', 'redis://127.0.0.1:6379')
  .default('remote_port', 8000)
  .default('remote_monitor_port', 8001)
  .default('secure', false)
  .default('verbose', false)
  .boolean('secure')
  .boolean('verbose')
  .describe('help', 'Print this help text.')
  .describe('key', 'Your Reddish connection key from your reddish instance.')
  .describe('local', 'The redis:// url to your local redis server.')
  .describe('remote', 'The url to your remote reddish instance socket.')
  .describe('remote_port', 'The standard port to your remote reddish instance socket.')
  .describe('remote_monitor_port', 'The monitor port to your remote reddish instance socket.')
  .describe('secure', 'Should TLS/SSL be used (your reddish server will need to be configured with certs).')
  .describe('verbose', 'Turn on extra logging.')
  .alias('local', 'l')
  .alias('remote', 'r')
  .alias('remote_port', 'p1')
  .alias('remote_monitor_port', 'p2')
  .alias('key', 'k')
  .alias('secure', 's')
  .alias('verbose', 'v')
  .argv

{ key, local, remote, verbose, secure } = options


# cli colors

R = "\x1b[31m"
G = "\x1b[32m"
Y = "\x1b[33m"
X = "\x1b[39m"


# validate the connection key

key_regex = /^[a-f0-9]{40}$/i

unless key_regex.test(key)
  console.error "#{R}ERROR#{X}", 'Invalid connection key', key
  return


# deconstruct `redis://` url

{ protocol, port: local_port, hostname: local_hostname } = url.parse(local)


# validate the connection key

local_protocol_regex = /^redis/i

unless local_protocol_regex.test(protocol)
  console.error "#{R}ERROR#{X}", 'Invalid redis protocol', protocol
  return

options.local_hostname = local_hostname
options.local_port = local_port


# deconstruct Reddish connection details

{ hostname: remote_hostname } = url.parse(remote)

options.remote_hostname = remote_hostname


class Connection
  @verbose: verbose
  @secure: secure

  handshaken: false
  connected: false

  handleLocalConnect: =>
    console.log "Local redis client connected", "#{@local_hostname}:#{@local_port}" if Connection.verbose

  handleLocalData: (data) =>
    @remote_endpoint.write(data) if @remote_endpoint and @handshaken

  handleLocalClose: (err) =>
    console.error "#{R}ERROR#{X}", 'Local client closed', "#{@local_hostname}:#{@local_port}"
    if @connected
      console.error "#{R}ERROR#{X}", 'Reconnecting Local client', "#{@local_hostname}:#{@local_port}"
      @local_client.connect(@local_port, @local_hostname) 

  handleLocalError: (err) =>
    console.error "#{R}ERROR#{X}", 'Local client error', err.message if err

  initializeLocalConnection: (options) ->
    console.log 'Local redis client connecting...', "#{@local_hostname}:#{@local_port}" if Connection.verbose

    @local_client = net.createConnection(@local_port, @local_hostname)
    @local_client.setTimeout(0)
    @local_client.setNoDelay()
    @local_client.setKeepAlive(true)

    @local_client.on 'connect', @handleLocalConnect
    @local_client.on 'data', @handleLocalData
    @local_client.on 'close', @handleLocalClose
    @local_client.on 'error', @handleLocalError

  handleRemoteConnect: =>
    @connected = true

    unless @handshaken
      console.log "Handshaking with endpoint at #{@remote_hostname}:#{@remote_port}..." if Connection.verbose
      @remote_endpoint.write(data = JSON.stringify(key: @key))

  handleRemoteHandshake: (data) =>
    try
      json = JSON.parse(data.toString())

      if err = json?.error
        console.error "#{R}ERROR#{X}", 'Endpoint handshake failed:', err
        return

      console.log "#{G}SUCCESS#{X}", "Proxying redis client at #{@local_hostname}:#{@local_port} to reddish endpoint at #{@remote_hostname}:#{@remote_port}..."
      @handshaken = true
    catch err
      console.error "#{R}ERROR#{X}", 'Endpoint handshake failed:', err

  handleRemoteData: (data) =>
    unless @handshaken
      return @handleRemoteHandshake(data)

    @local_client.write(data)

  handleRemoteClose: (err) =>
    @connected = false
    console.error "#{R}ERROR#{X}", 'Remote endpoint closed, closing Local client', (err.message if err)
    @local_client.end()

  handleRemoteError: (err) =>
    console.error "#{R}ERROR#{X}", 'Remote endpoint error', (err.message if err)

  initializeRemoteConnection: ->
    console.log 'Remote endpoint connecting...', "#{@remote_hostname}:#{@remote_port}" if Connection.verbose

    if Connection.secure
      @remote_endpoint = tls.connect @remote_port, @remote_hostname, @handleRemoteConnect
    else
      @remote_endpoint = net.connect @remote_port, @remote_hostname, @handleRemoteConnect
      @remote_endpoint.setKeepAlive(true)

    @remote_endpoint.setTimeout(0)
    @remote_endpoint.setNoDelay()

    @remote_endpoint.on 'data', @handleRemoteData
    @remote_endpoint.on 'close', @handleRemoteClose
    @remote_endpoint.on 'error', @handleRemoteError

  constructor: (@remote_port, options) ->
    { @local_hostname, @local_port, @remote_hostname, @key } = options

    @initializeLocalConnection()
    @initializeRemoteConnection()

remote_connection = new Connection(options.remote_port, options)
remote_monitor_connection = new Connection(options.remote_monitor_port, options)
