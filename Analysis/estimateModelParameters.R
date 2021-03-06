library(minpack.lm)
library(propagate)
require(MASS)


frameNames <<- c("ID", "name", "modelID", "pStart", "qStart", "mStart", "release.year", 
                 "ages", "adoptionRate", "smoothedAdoptionRate", 
                 "p", "pLwr", "pUpr", "q", "qLwr", "qUpr", 
                 "m", "mLwr", "mUpr", "qprat", "prediction", 
                 "residual", "residualAverage", "interval", "model", "upper", "lower",
                 "derv", "RMSE", "RMSEreal", "R2", "yearsToPredict", "predictedValues", 
                 "predictedLow", "predictedHigh", "pValue", "qValue")
dimensionNames <<- list(c(), frameNames)
frameDimensions <<- length(frameNames)

estimateModelParameters <- function(pData, start, end, useMovingAverage, multiplicationFactor, path) {
  
  options( warn = -1 )
  
  #extract unique values 
  unig <- unique(pData$ID)
  
  estimates <- data.frame(ID=numeric(), modelID=numeric(), pStart=numeric(), qStart=numeric(), mStart=numeric(),
                          p=numeric(), q=numeric(), m=numeric(), RMSE=numeric())
  
  
  k <- 1
  for (i in unig) {
    data <- pData[pData$ID==i,]
    print(paste("Estimating and fitting the model to ", data[1,]$name))
    
    name <- data[1,]$name
    pathElement <- paste(path, name, "/", sep="")
    dir.create(pathElement)
    pathModel <- paste(pathElement, "models/", sep="")
    dir.create(pathModel)
    #delete if there is something in the folder
    file.remove(file.path(pathModel, list.files(pathModel)))
    
    
    #take the data needed for doing the estimation
    X <- data[data$year>=start & data$year<=end,]$age
    
    
    Yper <- data[data$year >= start & data$year<=end,]$adoptionRate
    Yavg <- data[data$year >= start & data$year<=end,]$smoothedAdoptionRate
    year <- data[data$year >= start & data$year<=end,]$year
    if (useMovingAverage == TRUE) {
      Y <- Yavg
    } else {
      Y <- Yper
    }
    
    allEstimates <- estimateBassModel(X, Y, Yper, pathModel)
    
    write.table(allEstimates, file = paste(pathElement, "allEstimates.tsv", sep=""), quote=FALSE, 
                sep="\t", col.names=TRUE, row.names=FALSE)
    
    #filtering to get the best models
    allEstimates <- allEstimates[!is.na(allEstimates$p) & !is.na(allEstimates$q) & !is.na(allEstimates$m),]
    allEstimates <- allEstimates[allEstimates$p<=1,]
    
    # first check if there are any models with positive peaks 
    #allEstimates <- allEstimates[(allEstimates$m*(allEstimates$p+allEstimates$q)^2)/(4*allEstimates$q) <= multiplicationFactor,]
    
    allEstimatesZero <- allEstimates[allEstimates$p==0 | allEstimates$q==0 | allEstimates$m==0,]
    if (nrow(allEstimatesZero)>0) {
      allEstimatesZero <- allEstimatesZero[order(allEstimatesZero$RMSE),]
      allEstimatesZero <- allEstimatesZero[1,]
    }
    allEstimates <- allEstimates[!(allEstimates$p==0 | allEstimates$q==0 | allEstimates$m==0),]
    
    
    allEstimatesPositive <- allEstimates[((-1/(allEstimates$p+allEstimates$q))*log(allEstimates$p/allEstimates$q)>0 &
                                    (allEstimates$m*(allEstimates$p+allEstimates$q)^2)/(4*allEstimates$q) <= multiplicationFactor),]
    allEstimatesPositive <- allEstimatesPositive[order(allEstimatesPositive$RMSE),]
    bestEstimatesPositive <- data.frame(modelID=numeric(), pStart=numeric(), qStart=numeric(), mStart=numeric(),
                                p=numeric(), q=numeric(), m=numeric(), RMSE=numeric())
    epsilon <- 0.1
    for (cnt in 1:5) {
      tP <- allEstimatesPositive[1,]$p
      tQ <- allEstimatesPositive[1,]$q
      tM <- allEstimatesPositive[1,]$m
      
      bestEstimatesPositive <- rbind(bestEstimatesPositive, allEstimatesPositive[1,])
      allEstimatesPositive <- allEstimatesPositive[abs(allEstimatesPositive$p-tP)/tP>epsilon | 
                                                     abs(allEstimatesPositive$q-tQ)/tQ>epsilon |  
                                                      abs(allEstimatesPositive$m-tM)/tM>epsilon,]
      if (nrow(allEstimatesPositive)==0) break
    }
    allEstimatesPositive <- bestEstimatesPositive
    
    allEstimatesNegative <- allEstimates[(-1/(allEstimates$p+allEstimates$q))*log(allEstimates$p/allEstimates$q)<0,]
    allEstimatesNegative <- allEstimatesNegative[order(allEstimatesNegative$RMSE),]
    allEstimatesNegative <- allEstimatesNegative[1,]
    
    allEstimates <- rbind(allEstimatesZero, allEstimatesNegative, allEstimatesPositive)
    allEstimates <- allEstimates[order(allEstimates$RMSE),]
    
    bestEstimates <- data.frame(modelID=numeric(), pStart=numeric(), qStart=numeric(), mStart=numeric(),
                                p=numeric(), q=numeric(), m=numeric(), RMSE=numeric())
    if (nrow(allEstimates)>=5) {
      bestEstimates <- allEstimates[1:5,]
    } else {
      bestEstimates <- allEstimates
    }
        
    # more advanced way to pick good models
    # lots of the models are actually equal so we need to avoid proposing equal models
    # epsilon <- 0.1
    # for (cnt in 1:5) {
    #   tP <- allEstimates[1,]$p
    #   tQ <- allEstimates[1,]$q
    #   tM <- allEstimates[1,]$m
    #   
    #   bestEstimates <- rbind(bestEstimates, allEstimates[1,])
    #   allEstimates <- allEstimates[abs(allEstimates$p-tP)/tP>epsilon | abs(allEstimates$q-tQ)/tQ>epsilon |  
    #                                  abs(allEstimates$m-tM)/tM>epsilon,]
    #   if (nrow(allEstimates)==0) break
    # }
    
    bestEstimates <- bestEstimates[!is.na(bestEstimates$modelID),]
    write.table(bestEstimates, file = paste(pathElement, "best.tsv", sep=""), quote=FALSE, 
                sep="\t", col.names=TRUE, row.names=FALSE)
    
    bestEstimates$ID <- i
    
    k <- k + 1
    
    estimates <- rbind(estimates,bestEstimates)
    
  }
  
  options( warn = 0 )
  return (estimates)
}





estimateBassModel <- function(X, Y, Yreal, path) {
  
  #Bass model estimation
  #pInterval <- c(0.01, 0.03, 0.05, 0.07, 0.1, 0.2, 0.3)
  pInterval <- seq(0.05, 1.0, 0.05)
  #qInterval <- c(0.01, 0.05, 0.1, 0.3, 0.5, 0.7, 1.0)
  qInterval <- seq(0.05, 1.0, 0.05)
  mInterval <- c(0.01, 0.1, 1, 10, 100, 1000, 10000, 30000)
  #mInterval <- seq(0,10000,100)
  
  allEstimates <- data.frame(modelID=numeric(), pStart=numeric(), qStart=numeric(), mStart=numeric(),
                             p=numeric(), q=numeric(), m=numeric(), RMSE=numeric())
  model <- NA
  k <- 1
  for (iP in pInterval) {
    for (iQ in qInterval) {
      for (iM in mInterval) {
        #cat(paste(iP,iQ,iM, "\n", sep=" "))
        allEstimates[k,"modelID"] <- k
        allEstimates[k,"pStart"] <- iP
        allEstimates[k,"qStart"] <- iQ
        allEstimates[k,"mStart"] <- iM
        
        suppressMessages(t <- try(model <- estimateBass(X,Y, iP, iQ, iM)))
        if("try-error" %in% class(t)) {
          allEstimates[k,"p"] <- NA
          allEstimates[k,"q"] <- NA
          allEstimates[k,"m"] <- NA
          allEstimates[k,"RMSE"] <- NA
        } else {
          p <- as.numeric(coef(model)["p"])
          q <- as.numeric(coef(model)["q"])
          m <- as.numeric(coef(model)["m"])
          allEstimates[k,"p"] <- p
          allEstimates[k,"q"] <- q
          allEstimates[k,"m"] <- m
          
          #          # suppressMessages(t <- try (cInt <- confint(model, level = 0.95)))
          #         #  if ("try-error" %in% class(t)) {
          #             allEstimates[k,"pLow"] <- NA
          #             allEstimates[k,"pUpr"] <- NA
          #             allEstimates[k,"qLow"] <- NA
          #             allEstimates[k,"qUpr"] <- NA
          #             allEstimates[k,"mLow"] <- NA
          #             allEstimates[k,"mUpr"] <- NA
          #         #  }else {
          # #             allEstimates[k,"pLow"] <- cInt["p",1]
          # #             allEstimates[k,"pUpr"] <- cInt["p",2]
          # #             allEstimates[k,"qLow"] <- cInt["q",1]
          # #             allEstimates[k,"qUpr"] <- cInt["q",2]
          # #             allEstimates[k,"mLow"] <- cInt["m",1]
          # #             allEstimates[k,"mUpr"] <- cInt["m",2]
          # #           }
          # WARNING These residuals will be in the end different from those calculated by 
          # when real values are used. This is because the model is estimated on moving average. 
          residual <- resid(model)
          allEstimates[k,"RMSE"] <- calculateRMSE(residual)
          #allEstimates[k,]$R2 <- calculateR2(residual, Yreal)
          saveRDS(model, paste(path,k,".rds", sep=""))
        }
        
        k <- k + 1
      }
    }
  }
  return (allEstimates)
}


calculateBestModelValues <- function(marketShare, bestModels, path) {
  
  modelEstimates <- data.frame(matrix(vector(),0,frameDimensions, 
                                      dimnames = dimensionNames))
  
  modelEsPerElement <- data.frame(matrix(vector(),0,frameDimensions, 
                                         dimnames = dimensionNames))
  
  pickFrame <- data.frame(ID=character(), name=character(), modelID=character(), qualityFit=character())
  
  
  uniq <- unique(marketShare$ID)
  
  for (i in uniq) {
    data <- marketShare[marketShare$ID==i,]
    name <- data[1,][["name"]]
    pickFrame <- rbind(pickFrame, data.frame(ID=i, name=name, modelID=NA, qualityFit=NA))
    pathElement <- paste(path, name, "/", sep="")
    pathElModels <- paste(pathElement, "models/", sep="")
    models <- bestModels[bestModels$ID==i,]
    modelEsPerElement <- modelEsPerElement[0,]
    for (j in models$modelID) {
      mFile <- paste(getwd(),"/",pathElModels, j, ".rds", sep="")
      print(mFile)
      model <- readRDS(mFile)
      pStart <- models[models$modelID==j,]$pStart
      qStart <- models[models$modelID==j,]$qStart
      mStart <- models[models$modelID==j,]$mStart
      print (paste("hello", pStart, qStart, mStart))
      estimates <- calculateModelValues(data, model, j, pStart, qStart, mStart)
      modelEsPerElement <- rbind(modelEsPerElement, estimates)
    }
    saveRDS(modelEsPerElement, file=paste(pathElement, "estimates.rds", sep=""))
    
    modelEstimates <- rbind(modelEstimates, modelEsPerElement)
  }
  
  write.table(pickFrame, file = paste(path, "selectedModels.tsv", sep=""), quote=FALSE, 
              sep="\t", col.names=TRUE, row.names=FALSE)
  
  return (modelEstimates)
  
} 



calculateModelValues <- function(marketShare, model, modelID, pStart, qStart, mStart, calculationType ="confidence", predictionYears = NA, isCV=FALSE) {
  
  if (length(unique(marketShare$ID))>1) {
    
    message("Expecting only one market element!")
    return (NA)
    
  } else {
    intervalType <- calculationType
    modelEstimates <- data.frame(matrix(vector(),0,frameDimensions, 
                                        dimnames = dimensionNames))
    
    modelEstimates[1,][["ID"]] <- marketShare[1,]$ID
    modelEstimates[1,][["name"]] <- marketShare[1,]$name
    modelEstimates[1,][["release.year"]] <- marketShare[1,]$release.year
    modelEstimates[1,][["modelID"]] <- modelID
    modelEstimates[1,"pStart"] <- pStart[1]
    modelEstimates[1,"qStart"] <- qStart[1]
    modelEstimates[1,"mStart"] <- mStart[1]
    #print (pStart)
    #print (paste("hello here", modelEStimates[1,][["pStart"]], modelEStimates[1,][["qStart"]], modelEStimates[1,][["mStart"]]))
    
    X <- marketShare$age
    
    Yper  <- marketShare$adoptionRate
    Yreal <- Yper
    Yavg  <- marketShare$smoothedAdoptionRate
    releaseYear  <- marketShare$release.year
    
    modelEstimates[1,][["ages"]] <- list(X)
    modelEstimates[1,][["adoptionRate"]] <- list(Yper)
    modelEstimates[1,][["smoothedAdoptionRate"]] <- list(Yavg)
    
    if (isCV==FALSE) {
      f <- data.frame(x=seq(0,30, len=100))
      t <- try(temp <- predictNLS(model, newdata=f, interval=intervalType, alpha=0.05))
      if("try-error" %in% class(t)) {
        print("error in predictNLS 1")
        modelEstimates[1,][["p"]] <- NA
        modelEstimates[1,][["pLwr"]] <- NA
        modelEstimates[1,][["pUpr"]] <- NA
        modelEstimates[1,][["q"]] <- NA
        modelEstimates[1,][["qLwr"]] <- NA
        modelEstimates[1,][["qUpr"]] <- NA
        modelEstimates[1,][["m"]] <- NA
        modelEstimates[1,][["mLwr"]] <- NA
        modelEstimates[1,][["mUpr"]] <- NA
        modelEstimates[1,][["qprat"]] <-NA
        modelEstimates[1,][["prediction"]] <- NA
        modelEstimates[1,][["residual"]] <- NA
        modelEstimates[1,][["residualAverage"]] <- NA
        modelEstimates[1,][["interval"]] <- NA
        modelEstimates[1,][["model"]] <- NA
        modelEstimates[1,][["upper"]] <- NA
        modelEstimates[1,][["lower"]] <- NA
        modelEstimates[1,][["derv"]] <- NA
        modelEstimates[1,][["RMSE"]] <- NA
        modelEstimates[1,][["MSEreal"]] <- NA
        modelEstimates[1,][["R2"]] <- NA
        modelEstimates[1,][["pValue"]] <- NA
        modelEstimates[1,][["qValue"]] <- NA
      } else {
        r <- data.frame(x=X)
        t <- try(tempRes <- predictNLS(model, newdata=r, interval=intervalType, alpha=0.05))
        if("try-error" %in% class(t)) {
          print("error in predictNLS 2")
        } 
        
        
        #calculate residuals 
        residual <- Yreal - tempRes$summary[,1] 
        residualAverage <- Yavg - tempRes$summary[,1]
        
        #calculate confidence intervals for estimated parameters 
        # t <- try (cInt <- confint(model, level = 0.95))
        t <- try (cInt <- calculateConfidence(model, level = 0.95))
        if ("try-error" %in% class(t)) {
          print("error in calculating confidence intervals")
          pL <- NA
          pU <- NA
          qL <- NA
          qU <- NA
          mL <- NA
          mU <- NA
        }else {
          pL <- cInt["p",1]
          pU <- cInt["p",2]
          qL <- cInt["q",1]
          qU <- cInt["q",2]
          mL <- cInt["m",1]
          mU <- cInt["m",2]
          
        }
        modelEstimates[1,][["p"]] <- coef(model)["p"]
        p <- as.numeric(modelEstimates[1,][["p"]])
        modelEstimates[1,][["pLwr"]] <- pL
        modelEstimates[1,][["pUpr"]] <- pU
        modelEstimates[1,][["q"]] <- coef(model)["q"]
        q <- as.numeric(modelEstimates[1,][["q"]])
        modelEstimates[1,][["qLwr"]] <- qL
        modelEstimates[1,][["qUpr"]] <- qU
        modelEstimates[1,][["m"]] <- coef(model)["m"]
        m <- as.numeric(modelEstimates[1,][["m"]])
        modelEstimates[1,][["mLwr"]] <- mL
        modelEstimates[1,][["mUpr"]] <- mU
        modelEstimates[1,][["qprat"]] <-as.numeric(q/p)
        modelEstimates[1,][["prediction"]] <- list(tempRes$summary[,1])
        modelEstimates[1,][["residual"]] <- list(residual)
        modelEstimates[1,][["residualAverage"]] <- list(residualAverage)
        modelEstimates[1,][["interval"]] <- list(f$x)
        modelEstimates[1,][["model"]] <- list(temp$summary[,1])
        modelEstimates[1,][["lower"]] <- list(temp$summary[,5])
        modelEstimates[1,][["upper"]] <- list(temp$summary[,6])
        f$derv <- ((m/p)*(p+q)^3*exp(-(p+q)*f$x)*((q/p)*exp(-(p+q)*f$x)-1))/(((q/p)*exp(-(p+q)*f$x)+1)^3)
        modelEstimates[1,][["derv"]] <- list(f$derv)
        modelEstimates[1,][["RMSE"]] <- calculateRMSE(resid(model))
        modelEstimates[1,][["RMSEreal"]] <- calculateRMSE(residual)
        modelEstimates[1,][["R2"]] <- calculateR2(residual, Yreal)
        
        f$pValue <- p*m*(1-(1-exp(-(p+q)*f$x))/((q/p)*exp(-(p+q)*f$x)+1))
        f$qValue <- temp$summary[,1] - f$pValue
        modelEstimates[1,][["pValue"]] <- list(f$pValue)
        modelEstimates[1,][["qValue"]] <- list(f$qValue)
      }
      
    }
    
    if (calculationType=="prediction") {
      
      predictionAge <- predictionYears - as.numeric(releaseYear[1])
      r <- data.frame(x=predictionAge)
      t <- try(tempPred <- predictNLS(model, newdata=r, interval=intervalType, alpha=0.05))
      if("try-error" %in% class(t)) {
        print("error in predictNLS 3")
      } else {
        modelEstimates[1,][["yearsToPredict"]] <- list(predictionYears)
        modelEstimates[1,][["predictedValues"]] <- list(tempPred$summary[,1])
        modelEstimates[1,][["predictedLow"]] <- list(tempPred$summary[,5])
        modelEstimates[1,][["predictedHigh"]] <- list(tempPred$summary[,6])
      }
    } else {
      modelEstimates[1,][["yearsToPredict"]] <- NA
      modelEstimates[1,][["predictedValues"]] <- NA
      modelEstimates[1,][["predictedLow"]] <- NA
      modelEstimates[1,][["predictedHigh"]] <- NA
    }
    
    
    
  }
  
  return (modelEstimates)
  
}

makePredictions <- function(marketShare, modelEstimates, chosen, years, path, pathMarket) {
  
  
  pathPrediction <- paste(path,"/prediction/",sep="")  
  dir.create(pathPrediction)
  file.remove(file.path(pathPrediction, list.files(pathPrediction)))
  
  allEstimates <- data.frame(matrix(vector(),0,frameDimensions, 
                                    dimnames = dimensionNames))
  
  for (i in chosen$ID) {
    data <- marketShare[marketShare$ID==i,]
    name <- data[1,][["name"]]
    print(paste("Predicting for " , name))
    pathModel <- paste(pathMarket, name, "/models/", chosen[chosen$ID==i,]$modelID, ".rds", sep="")
    model <- readRDS(pathModel)
    estimates <- calculateModelValues(data, model, chosen[chosen$ID==i,]$modelID, modelEstimates[modelEstimates$ID==i,]$pStart, 
                                      modelEstimates[modelEstimates$ID==i,]$qStart, modelEstimates[modelEstimates$ID==i,]$mStart,
                                      "prediction", years)
    predictionYears <- unlist(estimates[1,][["yearsToPredict"]])
    predicted <- unlist(estimates[1,][["predictedValues"]])
    predictedLow <- unlist(estimates[1,][["predictedLow"]])
    prediectedHigh <- unlist(estimates[1,][["predictedHigh"]])
    
    dataPred <- data.frame(ID=i, name=name, year=predictionYears, 
                           prediction.value=predicted, prediction.low=predictedLow, prediction.high=prediectedHigh)
    
    data <- data[data$year %in% years,]
    dataPred <- merge(x=data, y=dataPred, by=c("ID", "name", "year"), all.y = TRUE)
    dataPred <- dataPred[, names(dataPred) %in% c("ID", "name", "year", "adoptionRate", 
                                                  "prediction.value", "prediction.low", "prediction.high")]
    names(dataPred)[names(dataPred)=="adoptionRate"] <- "actual.value"
    write.table(dataPred, file = paste(pathPrediction, name, "-predictions.tsv", sep=""), quote=FALSE, 
                sep="\t", col.names=TRUE, row.names=FALSE)
    
    
    allEstimates <- rbind(allEstimates, estimates)
    
  }
  return (allEstimates)
  
}



crossValidate <- function(marketShare, modelEstimates, path, experimentName) {
  
  pathCrossValidation <- paste(path,"cross-validation/",sep="")  
  dir.create(pathCrossValidation)
  dfAllModelsInBounds <- data.frame(age=0:40) 
  for (id in unique(modelEstimates$ID)) {
    name <- modelEstimates[modelEstimates$ID==id,]$name
    print(paste("Validating ", name))
    modelID <- modelEstimates[modelEstimates$ID==id,]$modelID
    crossValidationResults <- data.frame(pStart=as.numeric(), qStart=as.numeric(), mStart=as.numeric(), p=as.numeric(),
                                         q=as.numeric(),m=as.numeric(), age=as.numeric(), real.value=as.numeric(), 
                                         predicted.value=as.numeric(), lower=as.numeric(), upper=as.numeric(), 
                                         inBounds=as.numeric())
    data <- marketShare[marketShare$ID==id,]
    if (nrow(data)<4) next
    k <- 1
    for (ag in data$age) {
      year <- data[data$age == ag,]$year 
      X <- data[data$age != ag,]$age
      Y <- data[data$age != ag,]$smoothedAdoptionRate
      Xl <- data[data$age == ag,]$age
      Yl <- data[data$age == ag,]$smoothedAdoptionRate
      pStart <- modelEstimates[modelEstimates$ID == id, ]$pStart
      qStart <- modelEstimates[modelEstimates$ID == id, ]$qStart
      mStart <- modelEstimates[modelEstimates$ID == id, ]$mStart
      realValue <- Yl[1]
      crossValidationResults[k, "pStart"] <- pStart
      crossValidationResults[k, "qStart"] <- qStart
      crossValidationResults[k, "mStart"] <- mStart
      crossValidationResults[k, "age"] <- ag
      crossValidationResults[k, "real.value"] <- realValue
      print(paste("Cross validation for age ",ag))
      suppressMessages(t <- try(model <- estimateBass(X,Y, pStart, qStart, mStart)))
      if("try-error" %in% class(t)) {
        crossValidationResults[k, "predicted.value"] <- NA
        crossValidationResults[k, "lower"] <- NA
        crossValidationResults[k, "upper"] <- NA
        crossValidationResults[k, "inBounds"] <- FALSE
      } else {
        estimates <- calculateModelValues(data, model, modelEstimates[modelEstimates$ID == id, ]$modelID, pStart, 
                                          qStart, mStart,"prediction", c(year), isCV=TRUE)
        predictedValue <- unlist(estimates[1,"predictedValues"])[1]
        low <- unlist(estimates[1,"predictedLow"])[1]
        high <- unlist(estimates[1,"predictedHigh"])[1]
        crossValidationResults[k, "p"] <- coef(model)["p"]
        crossValidationResults[k, "q"] <- coef(model)["q"]
        crossValidationResults[k, "m"] <- coef(model)["m"]
        #print(paste(crossValidationResults[k, "p"],crossValidationResults[k, "q"],crossValidationResults[k, "m"]))
        crossValidationResults[k, "predicted.value"] <- predictedValue
        crossValidationResults[k, "lower"] <- low
        crossValidationResults[k, "upper"] <- high
        if (is.nan(low) | is.nan(high)) {
          crossValidationResults[k, "inBounds"] <- FALSE
        } else {
          if (realValue > low & realValue < high) {
          #if (abs(predictedValue - realValue)/realValue <=0.2){
            crossValidationResults[k, "inBounds"] <- TRUE
          } else {
            crossValidationResults[k, "inBounds"] <- FALSE
          }
        }
      }
      k <- k + 1
      
    }
    pathCVFile <- paste(pathCrossValidation, name, ".tsv", sep="")
    write.table(crossValidationResults, file =pathCVFile, quote=FALSE, 
                sep="\t", col.names=TRUE, row.names=FALSE )
    crossValidationResults <- crossValidationResults[,names(crossValidationResults) %in% c("age", "inBounds")]
    colnames(crossValidationResults) <- c("age", name)
    dfAllModelsInBounds <- merge(x=dfAllModelsInBounds, y=crossValidationResults, all=TRUE)
  }
  pathAll <- paste(pathCrossValidation, experimentName, "-joinedResults.tsv", sep="")
  write.table(dfAllModelsInBounds, file =pathAll, quote=FALSE, 
              sep="\t", col.names=TRUE, row.names=FALSE )
  
}



estimateBass <- function(X,Y, sP, sQ, sM) {
  f <- data.frame(x=X, y=Y)
  #fit <- nls(y ~ m*((p+q)^2/p)*((exp(-(p+q)*x))/(1+(q/p)*exp(-(p+q)*x))^2), data=f, algorithm="port", start=list(p=sP,q=sQ,m=sM), lower = c(0,0,0)) 
  fit <- nlsLM(y ~ m*((p+q)^2/p)*((exp(-(p+q)*x))/(1+(q/p)*exp(-(p+q)*x))^2), data=f, start=list(p=sP,q=sQ,m=sM),
               control = list(maxiter=1000), lower = c(0.0,0.0,0.0)) 
  return (fit)
}

calculateRMSE <- function(resid) {
  rmse <- sqrt(sum(resid^2) / length(resid))
  return (rmse)
}

calculateR2 <- function(resid, Y) {
  RSS <- sum(resid^2)
  m <- mean(Y)
  TSS <- sum((Y - m)^2)
  r2 <- 1 - RSS/TSS
  return (r2)
}


calculateConfidence <- function(model, level=0.95) {
  
  a <- (1 - level)/2
  a <- c(a, 1-a)
  df <- df.residual(model)
  t <- qt(a,df)
  params <- coef(model)
  serr <- sqrt(diag(vcov(model)))
  inter <- array(NA, dim = c(length(names(params)), 2L),
                 dimnames = list(names(params), 
                                 paste(format(100 * a, trim = TRUE, scientific = FALSE, digits = 3),"%")))
  inter[] <- params + serr %o% t
  return (inter)
  
  
}
