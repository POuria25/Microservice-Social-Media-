FROM golang:1.23-alpine

WORKDIR /app

# Copy Go module files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy all Go source files
COPY *.go ./

# Copy configuration file
COPY config.yaml ./

# Build the load balancer binary
RUN go build -o load-balancer

# Expose both load balancer ports
EXPOSE 9001 9002

# Run the load balancer
CMD ["./load-balancer"]
