# Use Ubuntu 24.04 as a base
FROM ubuntu:24.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install sudo and other common tools
RUN apt-get update && apt-get install -y sudo curl wget git nano

# Create a non-root user 'zet' with a home directory
# We will dynamically pass the UID and GID during the build process
ARG USER_ID
ARG GROUP_ID

RUN groupadd --gid $GROUP_ID zet || groupadd zet
RUN useradd --uid $USER_ID --gid $GROUP_ID -m -s /bin/bash zet

# Add the 'zet' user to the sudo group and allow passwordless sudo
RUN usermod -aG sudo zet
RUN echo 'zet ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set the working directory
WORKDIR /workspace

# Switch to the 'zet' user
USER zet 