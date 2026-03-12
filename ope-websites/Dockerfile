FROM nginx

LABEL description="Approved Websites page - Image for Open Prison Education"
LABEL version="0.1"

LABEL build=1
COPY start.sh /start.sh
COPY index.html /defaults/index.html
RUN chmod +x /start.sh

VOLUME ["/usr/share/nginx/html"]
EXPOSE 80

ENTRYPOINT ["/start.sh"]
