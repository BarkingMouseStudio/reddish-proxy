Reddish Proxy
=============

Simple proxy to expose a local redis instance to a remote reddish server.

`npm install -g reddish-proxy`


Usage
-----

* Create a new connection on reddish (with a name *not* starting with the `redis://` protocol, otherwise reddish will think its a public connection).

* Then just copy the connection key and pass it to `reddish-proxy`.

    Usage: reddish-proxy --local [local] --remote [remote] --key [key] -p1 [port] -p2 [port]

    Options:
      --help                       Print this help text.                                                              
      --key, -k                    Your Reddish connection key from your reddish instance.                              [required]
      --local, -l                  The redis:// url to your local redis server.                                         [required]  [default: "redis://127.0.0.1:6379"]
      --remote, -r                 The url to your remote reddish instance socket.                                      [required]  [default: "https://reddi.sh"]
      --remote_port, --p1          The standard port to your remote reddish instance socket.                            [default: 8000]
      --remote_monitor_port, --p2  The monitor port to your remote reddish instance socket.                             [default: 8001]
      --secure, -s                 Should TLS/SSL be used (your reddish server will need to be configured with certs).  [boolean]  [default: false]
      --verbose, -v                Turn on extra logging.                                                               [boolean]  [default: false]
