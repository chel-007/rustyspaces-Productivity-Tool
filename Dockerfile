# Use the official Rust image as the builder
FROM rust:latest AS builder

# Set the working directory inside the Docker container
WORKDIR /app

# Copy Cargo.toml and Cargo.lock to the working directory
COPY Cargo.toml Cargo.lock ./

# Fetch dependencies
RUN cargo fetch

# Copy the source code and other necessary files
COPY src ./src
COPY static ./static
COPY rocket.toml ./rocket.toml
COPY diesel.toml ./diesel.toml

# Build the application
RUN cargo build --release --target x86_64-unknown-linux-gnu

# Use a minimal base image for the final stage
FROM debian:latest

# Install required system packages
RUN apt-get update && \
    apt-get install -y libpq-dev

# Set the working directory in the final image
WORKDIR /app/bin

# Copy the compiled binary from the builder stage
COPY --from=builder /app/target/x86_64-unknown-linux-gnu/release/rustyspaces .

# Copy static files if needed
COPY --from=builder /app/static ./static

# Set executable permissions
RUN chmod +x rustyspaces

# Command to run the application
CMD ["./rustyspaces"]
