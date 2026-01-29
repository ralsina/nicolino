# Dockerfile for Pocketbase CMS pre-configured for Nicolino
# Build: docker build -f pocketbase/docker/pocketbase.Dockerfile -t nicolino-pocketbase .
# Run: docker run -p 8090:8090 -v $(pwd)/pb_data:/pb/pb_data nicolino-pocketbase

FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    unzip \
    ca-certificates

# Create a non-root user with fixed UID/GID that matches host
RUN addgroup -g 1000 pocketbase && \
    adduser -D -u 1000 -G pocketbase pocketbase

# Download and unzip PocketBase
ARG PB_VERSION=0.23.5
ADD https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip /tmp/pb.zip
RUN unzip /tmp/pb.zip -d /pb/

# Copy Nicolino-specific migrations
COPY pocketbase/migrations /pb/pb_migrations

# Set ownership
RUN chown -R pocketbase:pocketbase /pb

# Switch to non-root user
USER pocketbase
WORKDIR /pb

# Expose the default Pocketbase port
EXPOSE 8090

# Start PocketBase
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090"]
