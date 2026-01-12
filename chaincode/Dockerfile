# Build stage: Compile the Go binary
FROM golang:1.23-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /app

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o chaincode ./cmd/

# Final stage: Create a minimal image
FROM alpine:latest

# Install CA certificates for secure communication
RUN apk add --no-cache ca-certificates

# Set working directory
WORKDIR /app

# Copy the binary from the builder stage
COPY --from=builder /app/chaincode .
# Copy .env file (optional, will be overridden by environment variables in docker-compose)
COPY --from=builder /app/.env .

# External ports
EXPOSE 9999

# Run the binary
CMD ["./chaincode"]
