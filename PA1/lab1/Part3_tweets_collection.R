

############## function dupsBetweenGroups(), the reference from website:
##############  http://www.cookbook-r.com/Manipulating_data/Comparing_data_frames/
######################################################################################

rm(list=ls())
library(twitteR)
library(ROAuth)
library(RCurl)
library(maptools)
library(maps)
library(ggmap)
library(revgeo)

require(twitteR)
require(RCurl)
require(devtools)
devtools::install_github(repo = 'rCarto/photon')

# #我的
# consumer_key <- "iFX9JC9k1fo44ezw1ye0uD1QX"
# consumer_secret <- "lmIrg9KZXLLlX06kJKMqAoeRMEGUlOA9FoZo9u9AAqSzwvpLlM"
# access_token <- "807041899194421248-RBwaxwk0KW0oYseZ5yOuEzkobPHopT4"
# access_secret <- "rE5EzjRi4XLP6O5YQsLiLBrMDq5fQY7xL5He17urXXHC4"


# 朴
consumer_key <- "pOCZAjRaHOAeoGcGCMV80yXkB"
consumer_secret <- "URWLHaNfd1TtiHbKOV4zaEXOy385Voc3J6YqqporU3QhvWIAjF"
access_token <- "2776650785-YYZNqw4AFBtPrCgViRuvbZIbSBGSr77bqfAWxvD"
access_secret <- "k5csiB8yXZ7oqX3EIMxXady7vQO7zyHuzAqcuADpQzyCg"

# #陈
# consumer_key <- "8pLJfbU53Yz7fksYe5AeBMfaE"
# consumer_secret <- "1xBDN4XO0ubKg1My2vPj8GxArk7Y3Zn9eV5IBYPGZj1QG2smpH"
# access_token <- "2776650785-sX3rkk4L7Kvhyq4eIuDTFet9rs1zaYaFyO6yeEj"
# access_secret <- "eWjT7aJcujagpKbiCUuebS0sPYsWlFghfFolYMFjpRQNq"


#-------------------some functions below:------------

##  dupsBetweenGroups reference from website
dupsBetweenGroups <- function (myData, coder) {
  # myData: the data frame
  # coder: the column which identifies the group each row belongs to
  
  # Get the data columns to use for finding matches
  # setdiff: Set Difference Of Subsets. Calculates the (nonsymmetric) set difference of subsets of a probability space.
  datadiff <- setdiff(names(myData), coder)
  # Sort by coder, then datadiff. Save order so we can undo the sorting later.
  sortorder <- do.call(order, myData)
  myData <- myData[sortorder,]
  # Find duplicates within each id group (first copy not marked)
  dupWithin <- duplicated(myData)
  # With duplicates within each group filtered out, find duplicates between groups. 
  # Need to scan up and down with duplicated() because first copy is not marked.
  dupBetween = rep(NA, nrow(myData))
  dupBetween[!dupWithin] <- duplicated(myData[!dupWithin,datadiff])
  dupBetween[!dupWithin] <- duplicated(myData[!dupWithin,datadiff], fromLast=TRUE) | dupBetween[!dupWithin]
  
  # ============= Replace NA's with previous non-NA value ==============
  # This is why we sorted earlier - it was necessary to do this part efficiently
  # Get indexes of non-NA's
  goodIdx <- !is.na(dupBetween)
  # These are the non-NA values from x only
  # Add a leading NA for later use when we index into this vector
  goodVals <- c(NA, dupBetween[goodIdx])
  # Fill the indices of the output vector with the indices pulled from
  # these offsets of goodVals. Add 1 to avoid indexing to zero.
  fillIdx <- cumsum(goodIdx)+1
  # The original vector, now with gaps filled
  dupBetween <- goodVals[fillIdx]
  # Undo the original sort
  dupBetween[sortorder] <- dupBetween
  # Return the vector of which entries are duplicated across groups
  return(dupBetween)
}

getGeoLocation<- function(long, lat){
  geo <- revgeo(longitude = long, latitude= lat, output = "frame")
  return (geo)
}




#---------------------------------step1--------------------
# create twitter connections
setup_twitter_oauth(consumer_key, consumer_secret, access_token, access_secret)

# ------------------------------step2--------------------
# search tweets
# 1) directly using following keywords to search: sick, influenza, flu, ill, H1N1, pneumonia....runny nose,  sore throat,
#     dry cough,vomiting, stuffy nose, headache, fever，tonsillitis，vaccine
# 2) try using following words, make sure the correct meaning related to flu:
#     dose, nasal passages, bronchi, respiratory inflammation, tuberculosis(TB)

  cur_tweets <- searchTwitter("vaccine", n=5000)
  # convert twitteR lists to data frame
  cur_tweetsDF <- twListToDF(cur_tweets)
  # store no location
  noLocation <- cur_tweetsDF[(is.na(cur_tweetsDF$longitude) | is.na(cur_tweetsDF$latitude)),]
  # store the tweets Data frame has location
  cur_tweetsDF <- cur_tweetsDF[!(is.na(cur_tweetsDF$longitude) & is.na(cur_tweetsDF$latitude)),]
  
  for(row in 1:nrow(noLocation)){
    usr_id <- noLocation[row, "id"]
    usr_screenName <- noLocation[row, "screenName"]
    usrs <- lookupUsers(c(usr_id, usr_screenName))
    temp <- twListToDF(usrs)
    loc_str <- temp$location
    geo <- geocode(location = loc_str)
    long <- geo$lon
    lat <- geo$lat
    noLocation[row, "longitude"] <- long
    noLocation[row, "latitude"] <- lat
  }
  cur_tweetsDF <- rbind(cur_tweetsDF, noLocation)
  cur_tweetsDF <- cur_tweetsDF[!(is.na(cur_tweetsDF$longitude) & is.na(cur_tweetsDF$latitude)),]
  

  if(nrow(cur_tweetsDF) > 0){
   # store the tweets has text, location, and id
    cur_tweetsDF <- cur_tweetsDF[c("id","longitude", "latitude", "text")]
    colnames(cur_tweetsDF)[2] <- "long"
    colnames(cur_tweetsDF)[3] <- "lat"
    cur_tweetsDF$coder <-"B"
    cur_tweetsDF <-unique(cur_tweetsDF)
  }


#------------step3: find if there is duplicates value with previous data we searched----------------------

# read previous tweets data frame csv file
pre_tweetsDF <- read.csv("InputData/tweetsDF.csv", header=T, stringsAsFactors=FALSE, fileEncoding="latin1",sep=",")
# pre_tweetsDF <- read.csv("InputData/tweetsDF.csv", header=T, sep=",")
pre_tweetsDF <- pre_tweetsDF[c("id","long", "lat", "text")]
pre_tweetsDF$coder <- "A"
# create a tempDF to store row combine two data frame
tempDF <-  rbind(pre_tweetsDF, cur_tweetsDF)
tempDF <- tempDF[, c("coder", "id", "long", "lat", "text")]
# Find the rows which have duplicates in a different group.
dupRows <- dupsBetweenGroups(tempDF, "coder")
# Print it alongside the data frame
tempDF <- cbind(tempDF, dup=dupRows)
# split two data frame, in ordering to find if there is duplicated in cur_tweetsDF
pre_tweetsDF <- subset(tempDF, coder=="A", select=-c(coder, dup))
cur_tweetsDF <- subset(tempDF, coder=="B", select = -coder)
# remove the row when dup== true, the row exists in pre_tweetsDF as well
cur_tweetsDF <- subset(cur_tweetsDF, dup=="FALSE")
cur_tweetsDF <- cur_tweetsDF[, c("id", "long", "lat", "text")]

#-----------step4: search the cur_tweetsDF geolocation inside the USA-----
cur_tweetsDF$long <- as.numeric(as.character(cur_tweetsDF$long))
cur_tweetsDF$lat <- as.numeric(as.character(cur_tweetsDF$lat))
cur_tweetsDF <- subset(cur_tweetsDF,cur_tweetsDF$long > (-180) & cur_tweetsDF$long < 0 & cur_tweetsDF$lat > 0 & cur_tweetsDF$lat < 180)
debug1 <- cur_tweetsDF
# cur_tweetsDF <- debug1
if(nrow(cur_tweetsDF) != 0){
  # cur_tweetsDF$long <- as.character(cur_tweetsDF$long)
  # cur_tweetsDF$lat <- as.character(cur_tweetsDF$lat)
  geo1 <- getGeoLocation(cur_tweetsDF[1, "long"], cur_tweetsDF[1,"lat"])
  
  if(nrow(cur_tweetsDF) > 1){
    for (row in 2:nrow(cur_tweetsDF)) {
      geon <- getGeoLocation(cur_tweetsDF[row, "long"], cur_tweetsDF[row, "lat"])
      geo1 <- rbind(geo1, geon)
    }
  }
  geo1 <- geo1[, c("state", "country")]
  colnames(geo1)[1] <- "states"
  cur_tweetsDF <- cur_tweetsDF[c("id","long", "lat", "text")]
  cur_tweetsDF <-cbind(cur_tweetsDF,geo1)
  
}
cur_tweetsDF <- subset(cur_tweetsDF, cur_tweetsDF$country == "United States of America")

#-----------------------step5-1: add cur_tweetsDF to tweetsDF.csv files-------
temp1 <- cur_tweetsDF[, c("id", "long", "lat", "text")]
# combine two csv files
final1DF <- rbind(temp1, pre_tweetsDF)
# remove the data if they are all the same
dropX <-"X"
final1DF <-final1DF[ , !(names(final1DF) %in% dropX)]
write.csv(final1DF, file = "InputData/tweetsDF.csv")

#-----------------------step5-2: add cur_tweetsDF to updatedTweets.csv files-------
temp2 <- cur_tweetsDF[,c("id", "long", "lat", "states")]
pre_tweetsDF <- read.csv("InputData/updatedTweets.csv", header=T, sep=",")
dropX <-"X"
pre_tweetsDF <-pre_tweetsDF[ , !(names(pre_tweetsDF) %in% dropX)]
final2DF <- rbind(temp2, pre_tweetsDF)
write.csv(final2DF, file = "InputData/updatedTweets.csv")
