Reddish Proxy
=============

Simple proxy to expose a local redis instance to the [reddi.sh](https://reddi.sh) service.

We're still actively developing this proxy and the reddish service so please update often.

We'll announce changes on our Twitter account [@reddishapp](https://twitter.com/reddishapp).


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
