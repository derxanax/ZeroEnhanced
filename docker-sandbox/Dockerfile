# Use Ubuntu 24.04 as a base
FROM ubuntu:24.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install sudo and other common tools that root might need
RUN apt-get update && apt-get install -y sudo curl wget git nano

# Set the working directory
WORKDIR /workspace

# By default, the user is root. No need to specify anything else.
CMD ["/bin/bash"] 