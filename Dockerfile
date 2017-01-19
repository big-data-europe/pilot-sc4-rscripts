# Pull base image
#FROM ubuntu:15.04
FROM ubuntu
MAINTAINER Luigi Selmi <luigiselmi@gmail.com>

# Install vi for editing
RUN apt-get update && \
    apt-get install -y vim


# Install R
RUN apt-get update \
    && apt-get install -y r-base r-base-dev \
    && apt-get install -y libpq-dev

# Copy the R scripts for the map matching 
ADD NNLink.R .
