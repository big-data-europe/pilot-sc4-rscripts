### PACKAGES ###
## Imports and load packages that might not be available by default in R ##
loadPackages <- function() {  
	# Install Packages
	if("neuralnet" %in% rownames(installed.packages()) == FALSE) {install.packages("neuralnet")}

	# Load packages
	library(neuralnet)
  
	print("Libraries loaded.")  
}

### TRAINING ###
## Temporal function to load a training dataset into an R data frame ##
loadTrainData <-function(link_id,link_direction){
	# Turn R warnings into errors
	options(warn=2)
  
	# Directories management: Trying to set working directory the directory where the script is...  
	setwd(".")
	wd<-setwd(".")
	
	print("Getting training data...")  

	# Link_id,Link_Direction,Timestamp,Avg_speed,Entries
	# oneLinkmydata<-read.table(file.path(wd, "TrainingData",paste(paste(link_id,link_direction,sep="_"), ".csv",sep="")), header= FALSE, sep = ",")
	
	# Read historical data directly from zip file (TEMPORAL SOLUTION)
	oneLinkData<-try(as.data.frame(read.csv(unz(file.path(wd, "TEMP_TrainingData",paste(paste(link_id,link_direction,sep="_"), ".zip",sep="")),paste(paste(link_id,link_direction,sep="_"), ".csv",sep="")), header= FALSE, sep = ",")),silent=FALSE)

	if (is.null(oneLinkData) || class(oneLinkData) == "try-warning" || class(oneLinkData) == "try-error") {
  
		print("Could not load training data.")  
		return (NULL)  
	}

	print("OK")  

	return(oneLinkData)
}

## Function to prepare training and testing datasets ##
prepareTrainAndTestData <- function(link_id,link_direction,trainData) {

	# Turn R warnings into errors
	options(warn=2)
  
	# The value to return: 0 means no model created, 1 means model created and saved
	success <- 0
  
	# Directories management: Trying to set working directory the directory where the script is...  
	setwd(".")
	wd<-setwd(".")

	#print(is.data.frame(trainData))

	#Do not even attempt to train the model with less than 10k entries
	if (nrow(trainData) < 10000)
	{
	  print("Too small dataset. Cannot continue.")
	  return (NULL)
	}

	print("Preparing data...")  

	names(trainData)<- try(c("LinkID","Direction","Timestamp","Avg_Speed","Entries"),silent=TRUE)

	trainData$date <- as.POSIXlt(strptime(trainData$Timestamp, "%Y-%m-%d %H:%M:%S"))
	trainData$Timestamp<-NULL
	names(trainData)<- try(c("LinkID","Direction","Avg_Speed","Entries", "date"),silent=TRUE)

	################################## Data PREPARATION ###############################################	
	# 1. The notion is that we prepare first format appropriately the data. This includes:
	#     a) formating the given data in quarters (this requires attention in the number of entries recorded given the irregular calls to the database)
	#     b) making regular quarters 
	#     c) prepare for merging
	#     d) find start and end of examined period
	#     e) prepare the dataset that includes the regular timeseries for all the period and starting fromt the 00.00 time of the first day examined
	#     f) merge the data and have a nice timeseries object
	# 2. We fill missing values taking into account that if there is no entry for a 15 minutes interval, it is either free flow or there is a problem. 
	#     For the time being we assume the average of all the speed values. The entries are set to 0

	# make quarters in the linkdate 
	trainData$Quarter<-format(strptime("1970-01-01", "%Y-%m-%d") + round(as.numeric(trainData$date)/900)*900,"%Y-%m-%d %H:%M")
	trainData$Quarter<-as.POSIXlt(trainData$Quarter)
	# make date character for merge
	trainData$charDate<-as.character(trainData$Quarter)

	# REGULAR TIMESERIES DATES

	# find start and end date for the creation of regular timeseries
	rangeOfDates<-range(trainData$Quarter,na.rm=TRUE)
	startDate<-format(as.POSIXlt(rangeOfDates[1]), "%Y-%m-%d")
	endDate<-format(as.POSIXlt(rangeOfDates[2]), "%Y-%m-%d")

	mySeq<-data.frame(seq(from = as.POSIXlt(startDate), to = as.POSIXlt(endDate), by = "15 mins"))
	names(mySeq)<-"Quarter"
	mySeq$Quarter<-as.POSIXlt(mySeq$Quarter)
	mySeq$charDate<-as.character(mySeq$Quarter)

	# merge the data
	forTS <- merge(mySeq,trainData,all.x= TRUE, by='charDate')
	forTS$Quarter.x<-NULL
	forTS$date<-NULL
	forTS$Quarter.y<-NULL
	forTS$charDate<-as.POSIXlt(forTS$charDate)

	# we need to prepare the data 
	forTS$LinkID<-trainData$LinkID[1]
	#set speed as the average of histrocial speeds if no data found 
	forTS$Avg_Speed[is.na(forTS$Avg_Speed)]<-as.integer(mean(trainData$Avg_Speed))
	forTS$Entries[is.na(forTS$Entries)]<-0

	NewDesign<-data.frame(rep(0,nrow(forTS)-3))
	names(NewDesign)<-c("avgSpeed_45")
	NewDesign$avgSpeed_30<-0
	NewDesign$avgSpeed_15<-0
	NewDesign$avgSpeed_Current<-0

	NewDesign$entries_45<-0
	NewDesign$entries_30<-0
	NewDesign$entries_15<-0
	NewDesign$entries_Current<-0
	i<-4
	k<-1
	for(i in 4:nrow(forTS)){
	  NewDesign$avgSpeed_45[k]        <-forTS$Avg_Speed[i-3]
	  NewDesign$avgSpeed_30[k]        <-forTS$Avg_Speed[i-2]
	  NewDesign$avgSpeed_15[k]        <-forTS$Avg_Speed[i-1]
	  NewDesign$avgSpeed_Current[k]   <-forTS$Avg_Speed[i]
	  
	  NewDesign$entries_45[k]        <-forTS$Entries[i-3]
	  NewDesign$entries_30[k]        <-forTS$Entries[i-2]
	  NewDesign$entries_15[k]        <-forTS$Entries[i-1]
	  NewDesign$entries_Current[k]   <-forTS$Entries[i]
	  k<-k+1
	}

	print("OK")  

	# The new design is the actual table format we can use for the implementation of the algorithm
	print("Normalizing data...")  

	# we select a train set (4/5 of the initial dataset)
	trnumrows <- (nrow(NewDesign) * 4)/5

	small4TS <- NewDesign[1:trnumrows, ] 

	# We need to normalize values
	# Given a subset of data, we NORMALIZE THE DATA IN ORDER TO APPLY THE NN
	maxs <- apply(small4TS, 2, max) 
	mins <- apply(small4TS, 2, min)

	# now the new variable is named scaled
	scaled <- as.data.frame(scale(small4TS, center = mins, scale = maxs - mins))

	print("OK")  

	print("Saving min-max...")  
	
	# Throws error if cannot save min-max
	savmaxs <- try(saveRDS(maxs,file.path(wd, "models",paste("maxs",paste(paste(link_id,link_direction,sep="_"), ".rds",sep=""),sep="_"))), silent=FALSE)
	savmins <- try(saveRDS(mins,file.path(wd, "models",paste("mins",paste(paste(link_id,link_direction,sep="_"), ".rds",sep=""),sep="_"))), silent=FALSE)
	
	if (class(savmaxs) == "try-warning" || class(savmaxs) == "try-error" ||
	    class(savmins) == "try-warning" || class(savmins) == "try-error") {
	  
	  print("Could not save min-max.")  
	}
	
	else{
	  print("OK")  
	}
	
	TrainAndTestData.list <- list(small4TS, scaled)
	
	return(TrainAndTestData.list)
}

## Function to create, train and save a model for a link ##
trainModel <- function(link_id,link_direction, preparedTrainAndTestData){
  
  # Turn R warnings into errors
  options(warn=2)
  
  # The value to return: 0 means no model created, 1 means model created and saved
  success <- 0
  
  # Directories management: Trying to set working directory the directory where the script is...  
  setwd(".")
  wd<-setwd(".")
  
  small4TS <- preparedTrainAndTestData[[1]]
  scaled <- preparedTrainAndTestData[[2]]
  
  # we select a train set (4/5 of the initial dataset)
  trnumrows <- (nrow(scaled) * 4)/5
  
  trainset <- scaled[1:trnumrows, ] 
  
  print("Training model...")  
  
  # This is the NN estimation given the variables we want
  # Throws error if algorithm did not converge
  NNOut <- try(neuralnet(avgSpeed_Current + entries_Current ~ avgSpeed_45 + avgSpeed_30 +
                           avgSpeed_15 + entries_45 + entries_30 + 
                           entries_15, trainset, hidden=c(2,1),lifesign = "minimal", 
                         linear.output = TRUE, threshold=0.01, stepmax = 1000000), silent=FALSE)
  
  if (is.null(NNOut) || class(NNOut) == "try-warning" || class(NNOut) == "try-error") {
    print("Could not train model.")  
  }
  else
  {
    
    print("OK")  
    
    print("Saving model...")  
    
    # Throws error if cannot save model
    savNNOut <- try(saveRDS(NNOut,file.path(wd, "models",paste("NNOut",paste(paste(link_id,link_direction,sep="_"), ".rds",sep=""),sep="_"))), silent=FALSE)
    
    if (class(savNNOut) == "try-warning" || class(savNNOut) == "try-error") {
      
      print("Could not save model.")  
    }
    
    else{
      print("OK")  
      
      success <- 1  
    }
  }
  
  return (success)
}

## Function to test a model for a link ##
testModel <- function(link_id,link_direction, preparedTrainAndTestData){
  
  # Turn R warnings into errors
  options(warn=2)
  
  # Directories management: Trying to set working directory the directory where the script is...  
  setwd(".")
  wd<-setwd(".")
  
  small4TS <- preparedTrainAndTestData[[1]]
  scaled <- preparedTrainAndTestData[[2]]
  
  # Load model for current link
  print("Loading model and min-max...")  
  
  NNOut <- try(readRDS(file.path(wd, "models",paste("NNOut",paste(paste(paste(link_id,link_direction,sep="_"), ".rds",sep="")),sep="_"))),silent = FALSE)
  maxs <- try(readRDS(file.path(wd, "models",paste("maxs",paste(paste(paste(link_id,link_direction,sep="_"), ".rds",sep="")),sep="_"))),silent = FALSE)
  mins <- try(readRDS(file.path(wd, "models",paste("mins",paste(paste(paste(link_id,link_direction,sep="_"), ".rds",sep="")),sep="_"))),silent = FALSE)
  
  if (is.null(NNOut) || class(NNOut) == "try-warning" || class(NNOut) == "try-error" || 
      is.null(maxs) || class(maxs) == "try-warning" || class(maxs) == "try-error" ||
      is.null(mins) || class(mins) == "try-warning" || class(mins) == "try-error") {
    
    print("Could not load model and/or min-max.")  
    return (NULL)
  }
  
  
  ############################### Testing the model ###############################
  
  # we select a test set (the other 1/5 of the initial dataset)
  testset <- scaled[((nrow(scaled) * 4)/5):nrow(scaled), ]
  
  testSe<-testset[ , c("avgSpeed_45" , "avgSpeed_30" ,"avgSpeed_15" , "entries_45" , "entries_30","entries_15")]
  
  NNOut.results <- compute(NNOut, testSe)
  
  speeds_testresults_scaled <- data.frame(actual = testset$avgSpeed_Current, prediction = NNOut.results$net.result[,1])
  speeds_pr.nn <- NNOut.results$net.result[,1]*(max(small4TS$avgSpeed_Current)-min(small4TS$avgSpeed_Current))+min(small4TS$avgSpeed_Current)
  speeds_test.r <- (testset$avgSpeed_Current)*(max(small4TS$avgSpeed_Current)-min(small4TS$avgSpeed_Current))+min(small4TS$avgSpeed_Current)
  speeds_testresults<-data.frame(round(speeds_pr.nn))
  speeds_testresults$Real<-speeds_test.r
  speeds_MSE.nn <- sum((speeds_test.r - speeds_pr.nn)^2)/nrow(testset)
  
  entries_testresults_scaled <- data.frame(actual = testset$entries_Current, prediction = NNOut.results$net.result[,2])
  entries_pr.nn <- NNOut.results$net.result[,2]*(max(small4TS$entries_Current)-min(small4TS$entries_Current))+min(small4TS$entries_Current)
  entries_test.r <- (testset$entries_Current)*(max(small4TS$entries_Current)-min(small4TS$entries_Current))+min(small4TS$entries_Current)
  entries_testresults<-data.frame(round(entries_pr.nn))
  entries_testresults$Real<-entries_test.r
  entries_MSE.nn <- sum((entries_test.r - entries_pr.nn)^2)/nrow(testset)
  
  output<-list(data.frame(speeds_testresults,entries_testresults), speeds_MSE.nn,entries_MSE.nn)
  
  return(output)
  
  ############################### Testing the model ###############################
  
}

### PREDICTION ###
## Temporal function to get the speed data for the last 3 quarters from the http api ##
loadRTData <- function(){
	# Turn R warnings into errors
	options(warn=2)

	# Get a subset of data (could be done through Kafka)
	# Read data for last 3 quarters
	print("Getting data for the last 3 quarters...")  
	
  #this url is only accessible by verified clients
	rtData<-try(as.data.frame(read.table("http://160.40.63.115:23577/fcd/speed_hourly.csv?offset=0&limit=-1", header = TRUE, sep = ";"),silent = TRUE))

	if (is.null(rtData) || class(rtData) == "try-warning" || class(rtData) == "try-error") {
		print("Could not get data for the past 3 quarters. Cannot continue.")  
		return (NULL)
	} 
	
	colnames(rtData) <- c("link_id","link_name","link_direction","link_free_flow_speed","avgSpeed_45" , "entries_45" ,
                  "avgSpeed_30", "entries_30", "avgSpeed_15", 
                  "entries_15")


	print("OK")  

	return (rtData)
}

## Temporal function to get the speed data for the last 3 quarters from a file (for demostration purposes) ##
loadRTDataFromFile <- function(){
  # Turn R warnings into errors
  options(warn=2)
  
  # Get a subset of data (could be done through Kafka)
  # Read data for last 3 quarters
  print("Getting data for the last 3 quarters...")  
  
  rtData<-try(as.data.frame(read.table("TEMP_RTData/speed_hourly_sample.csv", header = TRUE, sep = ";"),silent = TRUE))
  
  if (is.null(rtData) || class(rtData) == "try-warning" || class(rtData) == "try-error") {
    print("Could not get data for the past 3 quarters. Cannot continue.")  
    return (NULL)
  } 
  
  colnames(rtData) <- c("link_id","link_name","link_direction","link_free_flow_speed","avgSpeed_45" , "entries_45" ,
                        "avgSpeed_30", "entries_30", "avgSpeed_15", 
                        "entries_15")
  
  print("OK")  
  
  return (rtData)
}

## Function to get next quarter's speed prediction for a link ##
getPredictionFromModel <- function(link_id,link_direction, rtData) {
  
	# Turn R warnings into errors
	options(warn=2)
  
	# Directories management: Trying to set working directory the directory where the script is...
	setwd(".")
	wd<-setwd(".")
  
	#print(is.data.frame(rtData))
	next_prediction<- as.matrix(rtData[rtData$link_id== link_id & rtData$link_direction==link_direction,c("avgSpeed_45","entries_45","avgSpeed_30","entries_30","avgSpeed_15","entries_15")],nrow=1,ncol=6)

	
	colnames(next_prediction) <- c("avgSpeed_45" , "entries_45" ,
	                               "avgSpeed_30" , "entries_30" , "avgSpeed_15",
	                               "entries_15")

	print("Latest data: ")
	print(next_prediction)

	if (nrow(next_prediction)!=1){
		print("No data for the last 3 quarters. Cannot continue.")  
		return (NULL)
	}


	# Load model for current link
	print("Loading model...")  

	NNOut <- try(readRDS(file.path(wd, "models",paste("NNOut",paste(paste(paste(link_id,link_direction,sep="_"), ".rds",sep="")),sep="_"))),silent = TRUE)
	maxs <- try(readRDS(file.path(wd, "models",paste("maxs",paste(paste(paste(link_id,link_direction,sep="_"), ".rds",sep="")),sep="_"))),silent = TRUE)
	mins <- try(readRDS(file.path(wd, "models",paste("mins",paste(paste(paste(link_id,link_direction,sep="_"), ".rds",sep="")),sep="_"))),silent = TRUE)

	if (is.null(NNOut) || class(NNOut) == "try-warning" || class(NNOut) == "try-error" || 
	  is.null(maxs) || class(maxs) == "try-warning" || class(maxs) == "try-error" ||
	  is.null(mins) || class(mins) == "try-warning" || class(mins) == "try-error") {

		print("Could not load model.")  
		return (NULL)
	}

	print("OK")

	# NORMALIZE THE DATA IN ORDER TO APPLY THE NN (also removing the "current" columns)

	print("Normalizing data for the past 3 quarters...")  

	maxs_no_current <- maxs[c(1,2,3,5,6,7)]
	mins_no_current <- mins[c(1,2,3,5,6,7)]

	# now the new variable is named scaled_current_prediction
	scaled_next_prediction <- as.data.frame(scale(next_prediction, center = mins_no_current, scale = maxs_no_current - mins_no_current))

	print("OK")

	print("Using model to create prediction...")  

	NNOut.results <- try(compute(NNOut, scaled_next_prediction))

	if (is.null(NNOut) || class(NNOut) == "try-warning" || class(NNOut) == "try-error") {
		print("Could not create prediction.")  
		return (NULL)
	}

	result_scaled <- data.frame(prediction = NNOut.results$net.result)

	print("OK")
  
	result <- c(1:2)
	result[1] <- NNOut.results$net.result[1]*(maxs[4]-mins[4])+mins[4] #speed
	result[2] <- NNOut.results$net.result[2]*(maxs[8]-mins[8])+mins[8] #entries

	print(paste("Scaling prediction and returning the results (Estimated speed",round(result)[1],", estimated entries", round(result)[2],") before exiting"))  

	# Getting data that make sense (apply de-normalization)
	return(round(result)) 
}

# #load packages
# loadPackages()
# #load train-test data
# trainTestData <- loadTrainData(200512125,1)
# #prepare train-test data and save min-max
# preparedTrainTestData <- prepareTrainAndTestData(200512125,1,trainTestData)
# #train model
# trainModel(200512125,1,preparedTrainTestData)
# #test model
# testResults = testModel(200512125,1,preparedTrainTestData)
# testResults[1] #compare calculated vs real values (speeds and entries)
# testResults[2] #mse (speeds)
# testResults[3] #mse (entries)
# #load rt data
# rtData <- loadRTData()
# #get prediction from model
# getPredictionFromModel(200512125,1,rtData)
