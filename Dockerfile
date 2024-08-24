# Use the official Rust image as the builder
FROM rust:latest AS builder

# Set the working directory inside the Docker container
WORKDIR /app

# Copy Cargo.toml and Cargo.lock to the working directory
COPY Cargo.toml Cargo.lock ./

# Copy the source code and other necessary files
COPY src ./src
COPY static ./static
COPY templates ./templates
COPY Rocket.toml ./Rocket.toml
COPY diesel.toml ./diesel.toml

# Build the application
RUN cargo build --release --target x86_64-unknown-linux-gnu

# Use a minimal base image for the final stage
FROM debian:latest

# Install required system packages
RUN apt-get update && \
    apt-get install -y libpq-dev

# Set the working directory in the final image
WORKDIR /app

# Create the bin directory
RUN mkdir -p /app/bin

# Copy the compiled binary from the builder stage
COPY --from=builder /app/target/x86_64-unknown-linux-gnu/release/rustyspaces /app/bin/rustyspaces

# Copy static files and other configuration files
COPY --from=builder /app/static /app/static
COPY --from=builder /app/templates /app/templates
COPY --from=builder /app/Rocket.toml /app/Rocket.toml

# Set executable permissions
RUN chmod +x /app/bin/rustyspaces

# Check directory contents for debugging
RUN ls -la /app
RUN ls -la /app/bin
RUN ls -la /app/static
RUN ls -la /app/templates

# Command to run the application
CMD ["/app/bin/rustyspaces"]
