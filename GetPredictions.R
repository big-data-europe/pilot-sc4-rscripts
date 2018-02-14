library(TrafficBDE) #The prediction package (https://github.com/ptzenos/TrafficBDE) 
library(lubridate) #allow usage of floor_date, ceiling_date

GetPredictions <- function(executor_number, total_executors){  
  
  df = data.frame(matrix(vector(), 0, 6, dimnames=list(c(), c("Link_id", "Direction","Exec_Timestamp","Step","Pred_Timestamp","Pred"))),stringsAsFactors=F)				
  #get traindata
  print("Getting OSM links...")
  OSM_Links <- data.table::fread("data/OSM_Main_Links.csv")
  OSM_Links <- as.data.frame(OSM_Links[,])
  print("OK. The number of links is:")
  print(nrow(OSM_Links))
  
  print("Fetching the latest complete train dataset...")
  Data<-try(as.data.frame(read.table("http://160.40.63.115:23577/fcd/traindata_complete.csv?offset=0&limit=-1", header = TRUE, sep = ";"),silent = TRUE))
  print("OK. The number of rows in this dataset was:")
  print(nrow(Data))
  
  #set next dt target
  next_dt <- as.POSIXct(Data[which.max(as.POSIXct(Data$Date)),3]) + 3600
  print("Calculating predictions for:")
  print(next_dt)
  
  #insert the same execution timestamp for all links
  exec_tstamp <- floor_date(Sys.time(),unit="15 minutes")
  
  #Produce a prediction for every link
  i <- 0;  
  
  from_number <- (((nrow(OSM_Links)/total_executors)*(executor_number - 1)) + 1)
  to_number <- (((nrow(OSM_Links)/total_executors)*(executor_number - 1)) + (nrow(OSM_Links)/total_executors))  
  print(paste("This executor will handle links from: ",from_number," to ", to_number,sep=""))
  
  for (i in from_number:to_number){ 
    print(paste("Iteration: ",i," of ",to_number,sep="" ))    
    pred <- try(kStepsForward(Data = Data, Link_id = OSM_Links[i,1], direction = OSM_Links[i,2], datetime = next_dt, predict = "Mean_speed", steps = 4),silent=TRUE)     
    if (class(pred) == "try-warning" || class(pred) == "try-error") {		
      #smth went wrong, continue
      print("Training failed")
    }
    else{
      #We got some results. Set exec_timestamp for all predictions produced in the current run
      #Comment the following line to include the actual exec_timestamp for each link in the returned dataset
      print("Training successful")
      pred[,3] = as.character(exec_tstamp)
      df <- rbind(df,pred)	 
    }	
    i <- i+1;
  }
  return(df)
}
