# Use a base image with Rust pre-installed
FROM rust:latest AS builder

# Set the working directory
WORKDIR /app

# Copy the Cargo files and source code
COPY Cargo.toml Cargo.lock ./
COPY src ./src

# Build the application
RUN cargo build --release --target x86_64-unknown-linux-gnu

# Use a minimal base image to run the application
FROM debian:latest

# Install required libraries
RUN apt-get update && \
    apt-get install -y libpq-dev

# Set the working directory
WORKDIR /app/bin

# Copy the built binary from the builder stage
COPY --from=builder /app/target/x86_64-unknown-linux-gnu/release/rustyspaces .

# Make the binary executable
RUN chmod +x rustyspaces

# Set the command to run the binary
CMD ["./rustyspaces"]
