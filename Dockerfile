# ================================
# Build image
# ================================
FROM swift:5.2.3 as build
WORKDIR /build

RUN apt-get -q update && export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get -q install -y \
    zlib1g-dev \
    && rm -r /var/lib/apt/lists/*

# Copy required folders into container
COPY Sources Sources
COPY Tests Tests
COPY Resources Resources
COPY Package.swift Package.swift

# Compile with optimizations
RUN swift build \
    --enable-test-discovery \
    -c release \
    -Xswiftc -g

# ================================
# Run image
# ================================
FROM ubuntu:18.04
WORKDIR /SwiftTileserverCache

RUN apt-get -qq update && export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get install -y \
    libatomic1 libxml2 libz-dev libbsd0 tzdata imagemagick \
    && rm -r /var/lib/apt/lists/*

# Copy build artifacts
COPY --from=build /build/.build/release /SwiftTileserverCache
# Copy Swift runtime libraries
COPY --from=build /usr/lib/swift/ /usr/lib/swift/
# Copy Resources
COPY --from=build /build/Resources /SwiftTileserverCache/Resources


ENTRYPOINT ["./SwiftTileserverCacheApp"]
CMD ["serve", "--env", "production", "--log", "info", "--hostname", "0.0.0.0", "--port", "9000"]
