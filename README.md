# FAA TFR Data
The code in this project compiles a dataset of temporary flight restrictions issued by the FAA and their corresponding shapefiles.

The scripts are written to run on an AWS EC2 Linux instance, so you may need to fork in order to tweak according to your operating system or production environment. I wrote a [blog post](http://www.michaelkotro.us/posts/web-scraping-with-r-amazon-web-services-7eb5e27) outlining the process of setting up an EC2 instance with R to run these scripts.

The FAA lists its active TFRs [online](http://tfr.faa.gov/tfr2/list.jsp). Unfortunately no online repository exists for expired TFRs, stymieing analysis of temporary flight restrictions. The data on active TFRs are conveniently formatted in HTML tables, making the data conducive to using the `readHTMLTable` function provided by R's XML package.

## MIT License
You are free to copy and modify this code as you see fit to collect your own TFR data. If you find a way to improve the dataset, then please submit a pull request!

## Dependencies
* `R` ([download](https://cran.r-project.org/)),
* R's `XML` package ([R Documentation](https://cran.r-project.org/package=XML)),
* R's `RCurl` package ([R Documentation](https://cran.r-project.org/web/packages/RCurl/index.html))
* R's `httr` package ([GitHub](https://github.com/r-lib/httr)),
* `wget`(Install with [Homebrew](http://formulae.brew.sh/formula/wget) if running on Mac OS), and
* `sed`.

## Preparing the Scripts and Files to Avoid Errors
1. The shell script `shapefile-download.sh` is written specifically to run on an EC2 instance, so directory paths (i.e., `/home/ec2-user/...`) may need to be modified to match the working directory in your production environment.
2. Edit line 8 of `FAA-TFR-scrapper.R` to set the working directory to match the path to your installation of the `tfr-data` repo. Paths may need to be edited on lines 110, 131, and 156 of that file.
3. For the first collection of TFR data, you'll need to copy `tfrData-export-memory-head.csv` to a new file named `tfrData-export-memory.csv` in the working directory. Additional scrapes will append new TFRs as rows to the end of the file, so you won't want to overwrite it!

## Running the Scripts
The scripts can be run manually to compile the active list of TFRs, download their shapefiles, and append them to the records collected in your dataset thus far.

```bash
R CMD BATCH /path/to/scripts/FAA-TFR-scraper.R && /path/to/scripts/shapefile-download.sh
```

These scripts are designed to be run automatically with no need to oversee their operation. For instance, I have these scripts running on an AWS EC2 instance, with a cron task that runs every hour like so:

```bash
0 * * * * R CMD BATCH /home/ec2-user/scripts/FAA-TFR-scraper.R && /home/ec2-user/scripts/shapefile-download.sh
```

I wrote a [blog post](http://www.michaelkotro.us/posts/web-scraping-with-r-amazon-web-services-7eb5e27) outlining the process of setting up an EC2 instance to execute the web scrapes and store your data in an S3 bucket. If you do not have an AWS account currently, you can sign up and run an EC2 instance under the "free tier" for 12 months. You can collect TFR data for a year free of charge!

### Why do I need the Shell script?
The FAA posts shapefiles for most TFRs that contain valuable information about the landarea and altitudes affected that R's XML package cannot scrape.

Running the shell script after the R script will loop over the URLs where each active TFRs shapefiles are stored and download them using `wget`. The script in this repo places the shapefiles into directory `/tmp/` and then unpackage the archives in a specified directory.

## Load the Data into R
```r
tfrData <- read.table("path/to/tfrData-export-memory.csv", head=T, sep=",", na.strings = "")
```
