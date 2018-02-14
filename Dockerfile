# The image created with this Dockerfile starts an instance of ubuntu with the R environment, 
# Rserve and the R scripts that implement the traffic forecasting algorithm.
# 1) In order to build an image using this docker file, run the following docker command
# $  docker build -t bde2020/pilot-sc4-rscripts:v0.1.0 .
# 2) Run a container using the command
# $ docker run --name forecasts -p 6311:6311 -d bde2020/pilot-sc4-rscripts:v0.1.0

# Pull base image
FROM ubuntu
MAINTAINER Luigi Selmi <luigiselmi@gmail.com>

# Install vi for editing
RUN apt-get update && \
    apt-get install -y vim


# Install R
RUN apt-get update \
    && apt-get install -y r-base r-base-dev \
    && apt-get install -y libpq-dev libssl-dev

# Copy the R scripts for the prediction algorithm 
ADD NNLink.R .

# Add Rserve for the communication Java - R
ADD start_rserve.sh .
ADD Rserve.conf .
ADD rserve/ rserve/
# Install the Rserve package for R
RUN ["R", "CMD", "INSTALL", "rserve/Rserve_1.8-5.tar.gz"]
#RUN Rscript -e "install.packages('Rserve')"
# Start Rserve
CMD ["sh","start_rserve.sh"]
