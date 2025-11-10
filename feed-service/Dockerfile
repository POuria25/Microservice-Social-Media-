FROM golang:1.23-alpine

WORKDIR /app

# Copy Go module files
COPY go.mod ./

# Download dependencies
RUN go mod download
RUN go mod tidy

# Copy source code
COPY *.go ./

# Build the feed service binary
RUN go build -o feed-service .

# Expose the service port
EXPOSE 5000

# Run the feed service
CMD ["./feed-service"]