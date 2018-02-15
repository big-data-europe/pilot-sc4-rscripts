Pilot SC4 Forecasting
=====================
This project provides a Docker images with a R environment and R scripts that implement the prediction
algorithm (v2.0) for pilot SC4.  

## Description


## Documentation 

The structure of the input dataset should be like the following:

    Link_id: The link_id of the OSM link
    Direction: The direction of the link; (possible value is 1 or 2)
    Date: The timestamp of the information
    Min_speed: The minimum observed speed on this link/direction combo (in km/h)
    Max_speed: The maximum observed speed on this link/direction combo (in km/h)
    Mean_speed: The mean speed on this link/direction combo (in km/h)
    Stdev_speed: The standard deviation of the observed speed values for this link/direction combo (in km/h)
    Skewness_speed: Skewness of the observed speed values for this link/direction combo (in km/h)
    Kurtosis_speed: Kurtosis of the observed speed values for this link/direction combo (in km/h)
    Entries: The total gps signals that matched on this link/direction combo
    UniqueEntries: The unique taxis that matched on this link/direction combo

The R module (which is installed as a package) takes this dataset as input, it trains a model for a link/direction and produces a prediction for the requested variable (i.e. Mean_speed). 

The GetPrediction function (in the GetPredictions.R file) acts as a wrapper by calculating predictions for many links at once and for the next 4 quarters.

## Build 

    $ docker run --name forecasts -p 6311:6311 -d ptzenos/pilot-sc4-rscripts:v2.0

## Sample usage: 
To run an example, you can do the following:
```sh
R < GetPredictions.R --no-save
```
A csv file containing the output should then be created in the folder "output".

## License 
 TBD
