Pilot SC4 R Scripts
===================
This project provides a Docker images with a R environment and R scripts that implement the prediction
algorithm for pilot SC4.  

## Description
A framework for traffic prediction based on historical data has been defined. The implementation is conducted on a link (aka road) level. The historical data is properly transformed and cleaned for the back propagating Neural Network algorithm to be applied for the model estimation based on the last 3 time steps (quarters). The historical data is first normalized based on the min-max normalization.

Based on the normalized data and using the neuralnet package in R, the training of the model is performed by taking into account the average speed and the number of entries observed in the 3 previous steps:

```sh
NNOut <- try(neuralnet(avgSpeed_Current + entries_Current ~ avgSpeed_45 + avgSpeed_30 + avgSpeed_15 + entries_45 + entries_30 + entries_15, trainset, hidden=c(2,1),lifesign = "minimal", linear.output = TRUE, threshold=0.01, stepmax = 1000000), silent=FALSE)
```

The hidden layers have been chosen based on iterative examination of various combinations. The most promising combination of hidden layers and number of neurons has been identified to be 2 layers, one with 6 neurons and the other with 3 neurons. Unfortunately, there are times when the training of the model cannot be completed by applying these parameter values. In that case, we need to lower the numbers of neurons (down to 1) and try again. Currently we define 2 layers, the first with 2 neurons and the other with 1. The script is applied for data from only one link and for a specific period of time. The output is the Neural Network definition, that can be applied in new data of the same format.

##Documentation 

Overall the script contains the following functions:

- **loadPackages()**: This function loads all the required R packages.

- **prepareTrainAndTestData(link_id,link_direction,trainData)**: This function should be used in order to prepare the train and test dataset for a link. It should return a properly transformed dataset to be passed into the trainModel and testModel functions in case all went good, or NULL (or throw an exception) in case of an error. It expects the link's historical data to be passed as an R data frame input argument. After a successful run, the function creates the following 2 files in the subdirectory called "models" under the script's current directory:
 - maxs_link_id_link_direction.rds and mins_link_id_link_direction.rds: Those files contain serialized normalization data (min-max) that will be used in the training process.
 
 The above 2 files need to exist in the script's folder structure for the rest functions to be able to successfully load and deserialize the model and produce the predictions.

- **trainModel(link_id, link_direction, preparedTrainAndTestData)**: This function should be used in order to create, train and save the model. It should return 1 in case all went good or 0 (or throw an exception) in case of error. The required “preparedTrainAndTestData” input data frame is the output of the prepareTrainAndTestData function (see above). Note that we need to create a separate model for every link of interest in the network (there exists a one-to-one relationship between links and models). This function has to be called every time we need to create or (re)train a link's model. The function uses the first 4/5 of the preparedTrainAndTestData entries for the training process. After a successful run, the function creates the following file in the subdirectory called "models" under the script's current directory:
 - NNOut_link_id_link_direction.rds: Contains a serialized representation of the trained model.
 
 The above file needs to exist in the script's folder structure for the rest functions to be able to successfully load and deserialize the model and produce the predictions.
 
- **testModel(link_id,link_direction,preparedTrainAndTestData)**: This function is being used in order to test the model. The required “preparedTrainAndTestData” input data frame is the output of the prepareTrainAndTestData function (see above). It uses the last 1/5 of the preparedTrainAndTestData entries for the testing process. It returns a list with 3 items: a) A data frame containing the predicted as well as the real values, b) mse for speed predictions and c) mse for entries predictions.

- **getPredictionFromModel(link_id,link_direction,rtData)**: This function uses the saved model to produce predictions of the average speed value and the number of entries on the link for the next quarter. It returns the predicted speed and entries values for the requested link or throws an exception in case of error. 

 As already noted, this function expects the 3 files (NNOut_link_id_link_direction.rds, maxs_link_id_link_direction.rds and mins_link_id_link_direction.rds) to exist in the "models" subdirectory under the script's working directory. In addition, it requires the link's latest average speed and entries data (for the last 3 quarters) to be passed as an R data frame input argument. For the time being, the feed's URL (it’s a private url, to gain access please ask) is the following:

 http://160.40.63.115:23577/fcd/speed_hourly.csv?offset=0&limit=-1 
 
 In case you don’t have access to the feed’s URL, you can use the sample file in the test folder for demonstration purposes.


##Requirements 
After cloning the project create a folder "models" before running the script.

##Build 

##Install and Run 

##Usage 
Load required R packages:
```sh
loadPackages()
```
Load train and test data for link 200512125, direction 1:
```sh
trainTestData <- loadTrainData(200512125,1)
```
Prepare train-test data for link 200512125, direction 1 and save min-max:
```sh
preparedTrainTestData <- prepareTrainAndTestData(200512125,1,trainTestData)
```
Train the model:
```sh
trainModel(200512125,1,preparedTrainTestData)
```
Test the model (optional):
```sh
testResults = testModel(200512125,1,preparedTrainTestData)
```
Print calculated vs real values (speeds and entries) comparison [1] and the mean square error (mse) for speeds [2] and entries [3] predictions:
```sh
testResults[1]
testResults[2] 
testResults[3] 
```
Load real time speeds and etries data for the last 3 quarters:
```sh
rtData <- loadRTData()
```
OR load static testing data for the last 3 quarters (for demonstrating purposes only in case access to the url is restricted):
```sh
rtData <- loadRTDataFromFile()
```
Get predictions from model
```sh
getPredictionFromModel(200512125,1,rtData)
```

##License 
 
