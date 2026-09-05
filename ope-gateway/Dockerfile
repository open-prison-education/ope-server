FROM jwilder/nginx-proxy:alpine

LABEL description="Web Gateway for Open Prison Education"

RUN apk add nano openssl logrotate


COPY docker-entrypoint.sh /app/
COPY init_certs.sh /app/
COPY openssl.cnf.tmpl /app/
COPY nginx.tmpl /app/
COPY uploads.conf /app/
COPY gateway.conf /app/
COPY nginx.conf /app/nginx.conf
COPY proxy.conf /app/
COPY index.html /app/
COPY 502.html /app/
COPY logrotate-nginx /etc/logrotate.d/nginx

WORKDIR /app/

RUN chmod +x /app/*.sh


ENV DOCKER_HOST unix:///var/run/docker.sock

VOLUME ["/etc/nginx/certs", "/var/run", "/etc/nginx/vhost.d", "/usr/share/nginx/html", "/etc/nginx/dhparam", "/etc/nginx/conf.d" ]

EXPOSE 80 443

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["forego", "start", "-r"]




