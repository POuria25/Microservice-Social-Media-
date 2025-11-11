FROM golang:1.23-alpine

WORKDIR /app

# Copy Go module files
COPY go.mod  go.sum ./

# Download dependencies
RUN go mod download


# Copy source code
COPY . .

# Build the feed service binary
RUN go build -o feed-service .

# Expose the service port
EXPOSE 5000

# Run the feed service
CMD ["./feed-service"]