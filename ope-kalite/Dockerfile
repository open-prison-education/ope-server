FROM python:2.7-alpine3.6

# ope-kalite - KALite - Khan Academy offline image
# Build with docker build -t ope-kalite .

#INSTRUCTIONS
# Build the kalite container and run it with the docker-compose command
# View the kalite website and create your admin user.
# Download all videos

# To copy to offline server use the setup tool

LABEL description="KALite Image for Open Prison Education"
LABEL version="0.1"

RUN apk add --update --no-cache \
	bash wget  unzip \
	&& pip install --upgrade pip \
	&& pip install --upgrade setuptools ka-lite-static \
	#&& wget -O en.zip 
#http://pantry.learningequality.org/downloads/ka-lite/0.17/content/contentpacks/en.zip \
#	&& upzip en.zip \
	&& apk del --purge unzip wget \
	&& rm -rf /var/cache/apk/* \
	&& echo 'done'

LABEL rebuild=2
COPY start.sh /start.sh
RUN chmod +x /start.sh

VOLUME ["/root/.kalite"]
EXPOSE 8008
ENV USER=ka-lite
#ENTRYPOINT exec bash
#ENTRYPOINT exec kalite start --foreground
ENTRYPOINT /start.sh
