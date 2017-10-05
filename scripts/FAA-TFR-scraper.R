# Load Dependencies
## See XML package documentation https://cran.r-project.org/web/packages/XML/XML.pdf
library(XML)
library(httr)

# Set working directory
setwd("")

url <- "http://tfr.faa.gov/tfr2/list.jsp"
tables <- readHTMLTable(url)
tfrTable <- tables[[5]]

# Clean up raw table
## Keep the complement of filler and empty rows
n <- nrow(tfrTable)
tfrTable <- tfrTable[-c(1,2,3,4,n-2,n-1,n),]
## Assign first row as column names and drop that row
colnames(tfrTable) <- sapply(as.character(unlist(tfrTable[1,])), tolower)
tfrTable <- tfrTable[-c(1),]
## Drop "Zoom" column as final step to clean TFR data
tfrTable <- subset(tfrTable, select = -c(date,zoom))
## Remove "return" characters that will cause formatting issues
tfrTable$notam <- gsub("/", "_", tfrTable$notam)
tfrTable$description <- gsub("\r", " ", tfrTable$description)
tfrTable$description <- gsub("\n", " ", tfrTable$description)

tfrData <- tfrTable

# Add timestamp to record time of web scrape
timestamp <- format(Sys.time(), "%Y%m%d%H", tz="UTC")
tfrData$timestamp <- timestamp

# Now I have a list of all current FAA TFRs, basic descriptive data, and timestamp of collection
# Next steps are to loop over NOTAM ids to fetch detailed xml and add detailed TFR data
tfrNotam <- c(as.character(tfrData$notam))

xml_prefix <- "http://tfr.faa.gov/save_pages/detail_"
xml_suffix <- ".xml"

# Generate new columns in data frame
tfrData$date_issued <- NA
tfrData$date_effective <- NA
tfrData$date_expire <- NA
tfrData$code_timezone <- NA
tfrData$city <- NA
tfrData$code_type <- NA
tfrData$purpose <- NA
tfrData$notam_fulltext <- NA
tfrData$guid <- NA
tfrData$timestamp_expire <- NA
tfrData$landarea <- NA

# Loop over NOTAM ids to fetch and append detailed TFR data
i <- 1

for(notam in as.factor(tfrNotam)) {
    xmlUrl <- paste(xml_prefix, notam, xml_suffix, sep="")
    
    if(GET(xmlUrl)$status == 200) {
        notamXML <- xmlParse(xmlUrl)

        ## Global identifier
        guid <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/NotUid/codeGUID", xmlValue)

        ## Date values
        dateIssued <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/NotUid/dateIssued", xmlValue)
        dateEffective <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/dateEffective", xmlValue)
        dateExpire <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/dateExpire", xmlValue)
        codeTimeZone <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/codeTimeZone", xmlValue)

        ## Location values
        city <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/AffLocGroup/txtNameCity", xmlValue)

        ## Text description values
        codeType <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/TfrNot/codeType", xmlValue)
        purpose <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/txtDescrPurpose", xmlValue)
        notamFull <- xpathSApply(notamXML, "/XNOTAM-Update/Group/Add/Not/txtDescrUSNS", xmlValue)

        ## Append data to the relevant row
        if (length(dateIssued) > 0 ) { tfrData$date_issued[i] <- dateIssued }
        if (length(dateEffective) > 0 ) { tfrData$date_effective[i] <- dateEffective }
        if (length(dateExpire) > 0 ) { tfrData$date_expire[i] <- dateExpire }
        if (length(codeTimeZone) > 0 ) { tfrData$code_timezone[i] <- codeTimeZone }
        if (length(city) > 0 ) { tfrData$city[i] <- city }
        if (length(codeType) > 0 ) { tfrData$code_type[i] <- codeType }
        if (length(purpose) > 0) { tfrData$purpose[i] <- purpose }
        if (length(notamFull) > 0 ) { tfrData$notam_fulltext[i] <- notamFull }
        if (length(guid) > 0 ) { tfrData$guid[i] <- guid }
    }
    
    i <- i + 1 
}

# Clean data obtained from detail XML page to avoid formatting issues
tfrData$purpose <- gsub("\r", " ", tfrData$purpose)
tfrData$purpose <- gsub("\n", " ", tfrData$purpose)
tfrData$notam_fulltext <- gsub("\r", " ", tfrData$notam_fulltext)
tfrData$notam_fulltext <- gsub("\n", " ", tfrData$notam_fulltext)

# Reorder columns to be logical
tfrData <- tfrData[,c(15,1,6,16,4,12,2,11,3,17,10,7,8,9,5,13,14)]

# Pull in latest version of dataset
tfrDataMemory <- read.table("tfrData-export-memory.csv", sep=",", header=T, na.strings="")

# Loop over working data to see if any TFRs in memory have expired after most recent update
i <- 1

# Avoid error if this is first scrape with "genesis" memory csv data file
if (nrow(tfrDataMemory) >= 1) {
    for (i in seq(1, nrow(tfrDataMemory), by=1)) {
        if (is.na(tfrDataMemory$timestamp_expire[i])) {
            l_guidWorking <- length(which(tfrData$guid == tfrDataMemory$guid[i]))

            ## Write the scrape timestamp as expiration timestamp if guid is not present in working data
            if (l_guidWorking == 0) {
                tfrDataMemory$timestamp_expire[i] <- timestamp
            }
        }
        i <- i + 1
    }

    ## Write updated tfrDataMemory data frame to overwrite csv data file of TFR data in memory
    ## Note: Overwriting data in memory won't affect process of appending new TFRs below
    write.table(tfrDataMemory, file = "tfrData-export-memory.csv", append = FALSE, quote = TRUE, sep = ",", eol = "\n", na = "", dec = ".", row.names = FALSE, col.names = TRUE, qmethod = c("escape", "double"), fileEncoding = "utf8")
}

# Loop over working data and compare Globally Unique Identifiers of each TFR to those in memory
i <- 1
newTFRs <- c()

for (i in seq(1, nrow(tfrData), by=1)) {
    newGuid <- tfrData$guid[i]
    l_guidMemory <- length(which(tfrDataMemory$guid == newGuid))
    if (l_guidMemory == 0) {
        l <- length(newTFRs)
        newTFRs[l+1] <- newGuid
    }
    
    i <- i + 1
}

# newTFRs holds values of all TFRs not found in dataset stored in memory
# Generate and export subset of working data that only includes these new TFRs
tfrDataNew <- subset(tfrData, guid %in% newTFRs)
newTFRids <- subset(tfrDataNew, select=c(guid,notam))
write.table(newTFRids, file = "newTFRids-export.csv", append = FALSE, quote = TRUE, sep = ",", eol = "\n", na = "", dec = ".", row.names = FALSE, col.names = FALSE, qmethod = c("escape", "double"), fileEncoding = "utf8")

# Append new TFR data to dataset in memory
write.table(tfrDataNew, file = "tfrData-export-memory.csv", append = TRUE, quote = TRUE, sep = ",", eol = "\n", na = "", dec = ".", row.names = FALSE, col.names = FALSE, qmethod = c("escape", "double"), fileEncoding = "utf8")
