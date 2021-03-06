# ================================
# Build image
# ================================
FROM swift:5.2 as build
WORKDIR /build

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
FROM swift:5.2
WORKDIR /SwiftTileserverCache

# Install imagemagick
RUN apt-get -y update && apt-get install -y imagemagick

# Copy build artifacts
COPY --from=build /build/.build/release /SwiftTileserverCache
# Copy Resources
COPY --from=build /build/Resources /SwiftTileserverCache/Resources

ENTRYPOINT ["./SwiftTileserverCacheApp"]
CMD ["serve", "--env", "production", "--log", "info", "--hostname", "0.0.0.0", "--port", "9000"]
