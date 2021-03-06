mime <- function(x) {
  values <- strsplit(x, split=";")
  c <- sapply(values, "[", 1) 
  return (c)
}

property <- function(x, prop) {
  if (prop=="mime" | prop=="Mime") {
    return (mime(x))
  } 
  values <- strsplit(x, split="; ")
  c <- unlist(sapply(values, extractProperty, prop))
  return (c)
}

extractProperty <- function(x, property) {
  x  <- unlist(x)
  c <- unlist(strsplit(x[grep(property, x, fixed=TRUE)], split="="))[2]
  c[grep("\"*\"",c)] <- substring(c[grep("\"*\"",c)], 2, nchar(c[grep("\"*\"",c)])-1)
  c[is.null(c)] <- NA
  return (c)
}

loadDataFromFile <- function(x, names) {
  txt <- readLines(x)
  splitTxt <- strsplit(txt, split="\t")
  processed <- lapply(splitTxt, processLine)
  data <- matrix(unlist(processed), nrow=length(processed), byrow=TRUE)
  colnames(data) <- names
  #colnames(data) <- c("server", "tika", "droid", "year", "amount")
  data <- as.data.frame(data, stringAsFactors=FALSE)
  data$server <- as.character(data$server)
  data$tika <- as.character(data$tika)
  data$droid <- as.character(data$droid)
  data$year <- as.integer(as.character(data$year))
  data$amount <- as.integer(as.character(data$amount))
  return(data)
}

processLine <- function(x) {
  out <- character(5)
  out[1] <- x[1]
  out[2] <- x[2]
  out[3] <- x[3]
  out[4] <- x[4]
  out[5] <- x[5]
  out
}

mySum <- function(x,y) {
  return (sum(y[x]))
}

estimateS <- function(p,q,m,num) {
  c <- c(1:num) 
  sum <- 0
  for (i in 1:num) {
    if (i==1) {
      c[i] <- p*m
      sum <- c[i]
    } else {
      c[i] <- p*m +(q-p)*sum-(q/m)*sum*sum
      sum <- sum + c[i]
    } 
  }
  return (c)
}

unifyValues <- function(el, groupProps) {
  bo <- el
  if (!is.na(el) & el!=" "){
#     if (bo=="image/x-ms-bmp") {
#       print(bo)
#       print(groupProps)
#     }
    tmp <- unlist(lapply(groupProps, function(x) el %in% unlist(x)))
    poz <- min(which(tmp==TRUE))
    if (is.finite(poz)) {
      tmpList <- unlist(groupProps[poz])
      bo <- tmpList[1]
    } 
  }
  return (bo)
}

recordConflicts <-function(data, properties, x) {
  for (prop in properties) {
    tempData <- data
    tempNames <- grep(prop, names(tempData))
    tempData <- tempData[, c(tempNames, grep("amount", names(tempData)))]
    if (x==1 | x==2) {
      tempData <- tempData[apply(tempData[,names(tempData)!="amount"], 1 , function(x) length(unique(x))!=1),]
    } else if (x==3 | x==4) {
        tempData <- tempData[is.na(tempData[[prop]]) | is.null(tempData[[prop]]),]
        tempData <- tempData[,!(names(tempData)==prop)]
        tempNames <- tempNames[!(tempNames %in% which(names(data)==prop))]
    }
    if (nrow(tempData)>0) {
      tempData$amount <- as.numeric(tempData$amount)
      tempData <- tempData[!is.na(tempData$amount),]
      tempData[is.na(tempData)] <- "NA"
      tempData <- aggregate(as.formula(paste("amount~", paste(names(data)[tempNames], collapse="+"), sep="")), 
                            FUN=sum, data=tempData, na.rm=TRUE, na.action=NULL)
      tempData <- tempData[order(tempData$amount, na.last = TRUE, decreasing=TRUE),]
    }
    pathTemp <- paste(path, "/statistics",sep="")
    dir.create(pathTemp)
    write.table(tempData, file=paste(pathTemp, "/conflictstats", prop, x, ".tsv", sep=""), 
              quote=FALSE, sep="\t", col.names=TRUE, row.names=FALSE)
  }
}

countConflicts <- function(data, properties, x) {
  numTotal <- sum(data$amount)
  tempData <- data
  for (prop in properties) {
    tempNames <- grep(prop, names(tempData))
    if (x==1) {
      tempData <- tempData[apply(tempData[,tempNames], 1 , function(x) length(unique(x))==1),]
    } else if (x==2) {
      tempData <- tempData[!is.na(tempData[[prop]]) & !is.null(tempData[[prop]]),]
    }
  }
  nCon <- numTotal - sum(tempData$amount)
  return (nCon)
}




