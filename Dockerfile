FROM swift:5.1
MAINTAINER 0815flo
LABEL Description="Docker image for running Swift Tileserver Cache."

RUN apt-get update && apt-get install -y sudo openssl libssl-dev libcurl4-openssl-dev

RUN apt-get -y update && apt-get install -y imagemagick && cp /usr/bin/convert /usr/local/bin

# Expose default port
EXPOSE 9000

RUN mkdir /SwiftTileserverCache
WORKDIR /SwiftTileserverCache

ADD Sources /SwiftTileserverCache/Sources
ADD Tests /SwiftTileserverCache/Tests
ADD Package.swift /SwiftTileserverCache
RUN cd /SwiftTileserverCache && swift build -c release
RUN cp .build/release/SwiftTileserverCacheApp .

CMD ["./SwiftTileserverCacheApp"]
