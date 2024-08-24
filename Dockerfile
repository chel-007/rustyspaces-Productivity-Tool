FROM rust:latest AS builder

WORKDIR /app

# Copy Cargo.toml and Cargo.lock
COPY Cargo.toml Cargo.lock ./

# Fetch dependencies
RUN cargo fetch

# Copy source code and static files
COPY src ./src
COPY static ./static  # Ensure the static directory is copied

# Build the application
RUN cargo build --release --target x86_64-unknown-linux-gnu

FROM debian:latest

RUN apt-get update && \
    apt-get install -y libpq-dev

WORKDIR /app/bin

COPY --from=builder /app/target/x86_64-unknown-linux-gnu/release/rustyspaces .
COPY --from=builder /app/static ./static  # Ensure static files are copied

RUN chmod +x rustyspaces

CMD ["./rustyspaces"]
