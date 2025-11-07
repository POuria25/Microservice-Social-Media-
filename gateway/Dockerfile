FROM golang:1.24

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download && go mod tidy

COPY . .

RUN mkdir -p /app/certs
COPY certs/server.crt /app/certs/
COPY certs/server.key /app/certs/
RUN chmod 644 /app/certs/server.crt && chmod 600 /app/certs/server.key

RUN go build -o gateway
RUN go mod tidy

EXPOSE 8443


CMD ["./gateway"]