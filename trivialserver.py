#!/usr/bin/env python3

"""

  Trivial http server in python, only for testing, not deployment.
  serves current working directory on PORT

"""

import http.server
import socketserver
import sys

PORT = 8001

if len(sys.argv) > 1:
   PORT=int(sys.argv[1])

Handler = http.server.SimpleHTTPRequestHandler

httpd = socketserver.TCPServer(("", PORT), Handler)

print("serving at port", PORT)
httpd.serve_forever()
