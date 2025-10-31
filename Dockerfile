FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Set Ghidra version
ENV GHIDRA_VERSION=11.2.1
ENV GHIDRA_DATE=20241105
ENV GHIDRA_INSTALL_DIR=/opt/ghidra
ENV INSTALL_MODE=docker

# Install base dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    gcc \
    make \
    openjdk-21-jdk \
    python3 \
    python3-pip \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create workspace
WORKDIR /workspace

# Copy NeoGhidra source
COPY . /workspace/neoghidra

# Set environment variable for install script
ENV NEOGHIDRA_SRC=/workspace/neoghidra

# Run installation script
RUN chmod +x /workspace/neoghidra/standalone/scripts/install.sh && \
    /workspace/neoghidra/standalone/scripts/install.sh

# Create a user for running (optional, can run as root in container)
RUN useradd -m -s /bin/bash ghidra && \
    mkdir -p /home/ghidra/.config && \
    cp -r /root/.config/nvim /home/ghidra/.config/ && \
    cp -r /root/.local /home/ghidra/ && \
    chown -R ghidra:ghidra /home/ghidra

# Set up working directory for binaries
WORKDIR /binaries

# Default to ghidra user
USER ghidra
ENV HOME=/home/ghidra
ENV GHIDRA_INSTALL_DIR=/opt/ghidra

# Entry point
ENTRYPOINT ["/usr/local/bin/neoghidra"]
CMD []
