# pull request testing
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
loadTrainData <-function(link_id,link_direction)
{
	# Turn R warnings into errors
	options(warn=2)
  
	# Directories management: Trying to set working directory the directory where the script is...  
	setwd(".")
	wd<-setwd(".")
  
	print("Getting training data...")  

	# Link_id,Link_Direction,Timestamp,Avg_speed,Entries
	# oneLinkmydata<-read.table(file.path(wd, "TrainingData",paste(paste(link_id,link_direction,sep="_"), ".csv",sep="")), header= FALSE, sep = ",")
	# Read historical data directly from zip file (TEMPORAL SOLUTION)
	
	oneLinkData<-try(as.data.frame(read.csv(unz(file.path(wd, "test",paste(paste(link_id,link_direction,sep="_"), ".zip",sep="")),paste(paste(link_id,link_direction,sep="_"), ".csv",sep="")), header= FALSE, sep = ",")),silent=TRUE)

	if (is.null(oneLinkData) || class(oneLinkData) == "try-warning" || class(oneLinkData) == "try-error") {
  
		print("Could not load training data.")  
		return (NULL)  
	}

	print("OK")  

	return(oneLinkData)
}

## Function to create, train and save a model for a link ##
prepareAndTrainModel <- function(link_id,link_direction,trainData) {

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
	  return(success)
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

	# set number of entries for training 
	# currently all entries are used for training
	trnumrows <- nrow(NewDesign)

	small4TS <- NewDesign[1:trnumrows, ] #20000

	# We need to normalize values
	# Given a subset of data, we NORMALIZE THE DATA IN ORDER TO APPLY THE NN
	maxs <- apply(small4TS, 2, max) 
	mins <- apply(small4TS, 2, min)

	# now the new variable is named scaled
	scaled <- as.data.frame(scale(small4TS, center = mins, scale = maxs - mins))

	print("OK")  

	# we select a train set. This might not be required
	trainset <- scaled[1:trnumrows, ] #18000

	print("Training model...")  

	# This is the NN estimation given the variables we want
	# Throws error if algorithm did not converge
	NNOut <- try(neuralnet(avgSpeed_Current ~ avgSpeed_45 + avgSpeed_30 +
						   avgSpeed_15 + entries_45 + entries_30 + 
						   entries_15, trainset, hidden=c(1,1),lifesign = "minimal", 
						   linear.output = TRUE), silent=FALSE)

	if (is.null(NNOut) || class(NNOut) == "try-warning" || class(NNOut) == "try-error") {
	  print("Could not train model.")  
	}
	else
	{
	  
	  print("OK")  
	  
	  print("Saving model...")  
	  
	  # Throws error if cannot save model
	  savNNOut <- try(saveRDS(NNOut,file.path(wd, "models",paste("NNOut",paste(paste(link_id,link_direction,sep="_"), ".rds",sep=""),sep="_"))), silent=FALSE)
	  savmaxs <- try(saveRDS(maxs,file.path(wd, "models",paste("maxs",paste(paste(link_id,link_direction,sep="_"), ".rds",sep=""),sep="_"))), silent=FALSE)
	  savmins <- try(saveRDS(mins,file.path(wd, "models",paste("mins",paste(paste(link_id,link_direction,sep="_"), ".rds",sep=""),sep="_"))), silent=FALSE)

	  if (class(savNNOut) == "try-warning" || class(savNNOut) == "try-error" || 
		  class(savmaxs) == "try-warning" || class(savmaxs) == "try-error" ||
		  class(savmins) == "try-warning" || class(savmins) == "try-error") {
		
		print("Could not save model.")  
	  }
	  
	  else{
		print("OK")  
		
		success <- 1  
	  }
	}

	return(success)

	############################### Testing the model ###############################

	#testset <- scaled[18000:20000, ]

	#testSe<-testset[ , c("avgSpeed_45" , "avgSpeed_30" ,"avgSpeed_15" , "entries_45" , "entries_30","entries_15")]

	#NNOut.results <- compute(NNOut, testSe)

	#testresults_scaled <- data.frame(actual = testset$avgSpeed_Current, prediction = NNOut.results$net.result)

	#pr.nn <- NNOut.results$net.result*(max(small4TS$avgSpeed_Current)-min(small4TS$avgSpeed_Current))+min(small4TS$avgSpeed_Current)
	#test.r <- (testset$avgSpeed_Current)*(max(small4TS$avgSpeed_Current)-min(small4TS$avgSpeed_Current))+min(small4TS$avgSpeed_Current)

	#testresults<-data.frame(pr.nn)
	#testresults$Real<-test.r

	#MSE.nn <- sum((test.r - pr.nn)^2)/nrow(testset)

	#output<-list(testresults,testresults_scaled,MSE.nn)

	#return(output)

	############################### Testing model ###############################
}

### PREDICTION ###
## Temporal function to get the speed data for the last 3 quarters ##
loadRTData <- function()
{
	# Turn R warnings into errors
	options(warn=2)

	# Get a subset of data (could be done through Kafka)
	# Read data for last 3 quarters
	print("Getting data for the last 3 quarters...")  

	rtData<-try(as.data.frame(read.table("http://160.40.63.115:23577/fcd/speed_hourly.csv?offset=0&limit=-1", header = TRUE, sep = ";"),silent = TRUE))

	if (is.null(rtData) || class(rtData) == "try-warning" || class(rtData) == "try-error") {
		print("Could not get data for the past 3 quarters. Cannot continue.")  
		return (NULL)
	} 
	
	colnames(rtData) <- c("link_id","link_name","link_direction","link_free_flow_speed","avgSpeed_45" , "avgSpeed_30" ,
								 "avgSpeed_15" , "entries_45" , "entries_30",
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
	next_prediction<- as.matrix(rtData[rtData$link_id== link_id & rtData$link_direction==link_direction,c("avgSpeed_45","avgSpeed_30","avgSpeed_15","entries_45","entries_30","entries_15")],nrow=1,ncol=6)

	colnames(next_prediction) <- c("avgSpeed_45" , "avgSpeed_30" ,
								 "avgSpeed_15" , "entries_45" , "entries_30",
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

	result <- NNOut.results$net.result*(maxs[4]-mins[4])+mins[4]

	print(paste("Scaling prediction and returning the result (",result,") before exiting"))  

	# Getting data that make sense (apply de-normalization)
	return(as.integer(result))
}

#loadPackages()
#trainData <- loadTrainData(200512125,1)
#prepareAndTrainModel(200512125,1,trainData)
#rtData <- loadRTData()
#getPredictionFromModel(200512125,1,rtData)
