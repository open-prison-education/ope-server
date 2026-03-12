#!/bin/bash

# Copy the bundled approved_websites page if no index.html exists yet
if [ ! -f /usr/share/nginx/html/index.html ]; then
   cp /defaults/index.html /usr/share/nginx/html/index.html
fi

/bin/bash -c "exec nginx -g 'daemon off;'"
