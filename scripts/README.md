# Scripts Overview
The two scripts are designed to be run sequentially, so you can run them in order through the command line like so

```bash
R CMD BATCH /path/to/scripts/FAA-TFR-scraper.R && /path/to/scripts/shapefile-download.sh
```

Or as a cron task like so

```bash
0 * * * * R CMD BATCH /home/ec2-user/scripts/FAA-TFR-scraper.R && /home/ec2-user/scripts/shapefile-download.sh
```

## The R Script
The R script takes in both the existing dataset in memory and the "fresh" webscrape data and outputs a list of new TFRs and a new copy of the "memory" dataset. It also accesses each active TFR's XML page in order to fetch more detailed data than the [FAA's TFR homepage](http://tfr.faa.gov/tfr2/list.jsp) provides.

## The Shell Script
The Shell script takes in the list of new TFRs output by the R script in order to download and unpack the shapefiles the FAA posts online. In the event that the FAA has not posted shapefiles for a TFR, that TFR's identifier string and NOTAM string will be output to the `newTFRids-archive.csv` file, along with an entry in each row that is a timestamp of when the TFR was added to the archive.

If a TFR in the archived list has shapefiles posted at a later time, the script will unpack the zip archive just as it would for any other TFR.

If after a week of scrapes, an archived TFR has not had shapefiles uploaded, the script will strip it from the list of archived TFRs. (I assume by that point the FAA will not be posting shapefiles at all.)

**Note:** The shell script is written to be run on an EC2 instance, so modifications to directory paths will be necessary for other environments.