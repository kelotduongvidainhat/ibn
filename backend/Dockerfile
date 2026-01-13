# Build stage
FROM golang:alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev

# Copy go mod and sum files
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . .

# Build the application
RUN go build -o backend_server main.go

# Final stage
FROM alpine:3.18

WORKDIR /app

# Install runtime dependencies
# bash is needed for the scripts
# docker-cli is needed for the backend to run the superadmin toolkit
RUN apk add --no-cache bash docker-cli

# Copy the binary from the builder stage
COPY --from=builder /app/backend_server .

# The backend expects the .env file in the same directory, 
# but we will provide most of them via docker-compose environment section.
# We'll copy it just in case.
COPY .env .

EXPOSE 8080

CMD ["./backend_server"]
