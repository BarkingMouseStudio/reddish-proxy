Reddish Proxy
=============

Simple proxy to expose a local redis instance to the [reddish](https://reddi.sh) service.


Installation
------------

`sudo npm install -g reddish-proxy`


Steps to connect
----------------

* First, create a new connection on reddish (but its name should *not* start with the `redis://` protocol, otherwise reddish will think its a public connection)

* Then just copy the connection key and pass it to `reddish-proxy`

        Usage: reddish-proxy --url [url] --key [key]

        Options:
          --url, -u  A formatted redis url        [required]  [default: "redis://127.0.0.1:6379"]
          --key, -k  Your Reddish connection key  [required]

        Missing required arguments: key
