# The image created with this Dockerfile starts an instance of ubuntu with the R environment installed 
# 1) In order to build an image using this docker file, run the following docker command
# $  docker build -t bde2020/pilot-sc4-rscripts:v0.1.0 .
# 2) Run a container using the command
# $ docker run --name rscripts -d bde2020/pilot-sc4-rscripts:v0.1.0

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
