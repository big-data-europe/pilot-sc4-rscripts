# The image created with this Dockerfile starts an instance of ubuntu with the R environment, 
# Rserve and the R scripts that implement the traffic forecasting algorithm.
# 1) In order to build an image using this docker file, run the following docker command
# $  docker build -t ptzenos/pilot-sc4-rscripts:v2.0 .
# 2) Run a container using the command
# $ docker run --name forecasts -p 6311:6311 -d ptzenos/pilot-sc4-rscripts:v2.0

# Pull base image
FROM ubuntu
LABEL authors="Luigi Selmi <luigiselmi@gmail.com>,Panagiotis Tzenos <ptzenos@gmail.com>"

# Install vi for editing
RUN apt-get update && \
    apt-get install -y vim

# Install R
RUN apt-get update \
    && apt-get install -y r-base r-base-dev \
    && apt-get install -y libpq-dev libssl-dev \
    && apt-get install -y libcurl4-openssl-dev

# Copy the R scripts for the prediction algorithm 
# ADD R/ R/ 
ADD GetPredictions.R .

# Copy a a script to test the algorithm
# ADD test_forecast.R .

# Create the folder for the models
# RUN mkdir models

# Create the folder for the output files
RUN mkdir output

# Add Rserve for the communication Java - R
ADD start_rserve.sh .
ADD Rserve.conf .
ADD rserve/ rserve/

# Add data
ADD data/ data/

# Add devtools 
ADD devtools/ devtools/

# Add TrafficBDE
ADD trafficbde/ trafficbde/

# Add build_package_dependencies
ADD build_package_dependencies/ build_package_dependencies/

# Install devtools package and dependencies
RUN ["R","CMD","INSTALL","devtools/jsonlite_1.5.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/digest_0.6.15.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/git2r_0.21.0.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/withr_2.1.1.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/whisker_0.3-2.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/memoise_1.1.0.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/rstudioapi_0.7.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/mime_0.5.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/curl_3.1.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/openssl_1.0.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/R6_2.2.2.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/httr_1.3.1.tar.gz"]
RUN ["R","CMD","INSTALL","devtools/devtools_1.13.4.tar.gz"]


# Install build dependencies
RUN ["R","CMD","INSTALL","build_package_dependencies/stringi_1.1.6.tar.gz"]
RUN ["R","CMD","INSTALL","build_package_dependencies/magrittr_1.5.tar.gz"]
RUN ["R","CMD","INSTALL","build_package_dependencies/stringr_1.2.0.tar.gz"]
RUN ["R","CMD","INSTALL","build_package_dependencies/evaluate_0.10.1.tar.gz"]
RUN ["R","CMD","INSTALL","build_package_dependencies/highr_0.6.tar.gz"]
RUN ["R","CMD","INSTALL","build_package_dependencies/markdown_0.8.tar.gz"]
RUN ["R","CMD","INSTALL","build_package_dependencies/yaml_2.1.16.tar.gz"]
RUN ["R","CMD","INSTALL","build_package_dependencies/knitr_1.19.tar.gz"]


# Install trafficbde package and dependencies
RUN ["R","CMD","INSTALL","trafficbde/gtable_0.2.0.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/Rcpp_0.12.15.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/plyr_1.8.4.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/reshape2_1.4.3.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/RColorBrewer_1.1-2.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/dichromat_2.0-0.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/colorspace_1.3-2.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/munsell_0.4.3.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/labeling_0.3.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/viridisLite_0.3.0.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/scales_0.5.0.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/assertthat_0.2.0.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/crayon_1.3.4.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/cli_1.0.0.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/utf8_1.1.3.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/rlang_0.1.6.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/pillar_1.1.0.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/tibble_1.4.2.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/lazyeval_0.2.1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/ggplot2_2.2.1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/iterators_1.0.9.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/foreach_1.4.4.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/ModelMetrics_1.1.0.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/bindr_0.1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/plogr_0.1-1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/bindrcpp_0.2.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/glue_1.2.0.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/pkgconfig_2.0.1.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/BH_1.66.0-1.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/dplyr_0.7.4.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/purrr_0.2.4.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/tidyselect_0.2.3.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/tidyr_0.8.0.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/mnormt_1.5-5.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/psych_1.7.8.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/broom_0.4.3.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/numDeriv_2016.8-1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/SQUAREM_2017.10-1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/lava_1.6.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/prodlim_1.6.1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/ipred_0.9-6.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/kernlab_0.9-25.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/CVST_0.2-1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/DRR_0.0.3.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/dimRed_0.1.0.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/lubridate_1.7.2.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/timeDate_3042.101.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/DEoptimR_1.0-8.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/robustbase_0.92-8.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/sfsmisc_1.1-1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/ddalpha_1.3.1.1.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/gower_0.1.2.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/RcppRoll_0.2.2.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/recipes_0.1.2.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/caret_6.0-78.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/data.table_1.10.4-3.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/bitops_1.0-6.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/RCurl_1.95-4.10.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/hms_0.4.1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/readr_1.1.1.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/reshape_0.8.7.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/zoo_1.8-1.tar.gz"]
RUN ["R","CMD","INSTALL","trafficbde/neuralnet_1.33.tar.gz "]
RUN ["R","CMD","INSTALL","trafficbde/TrafficBDE_0.0.0.9000.tar.gz "]

# Install the Rserve package for R
RUN ["R", "CMD", "INSTALL", "rserve/Rserve_1.8-5.tar.gz"]
#RUN Rscript -e "install.packages('Rserve')"

# Start Rserve
CMD ["sh","start_rserve.sh"]
