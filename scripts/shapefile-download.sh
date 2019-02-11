#!/bin/bash
runtime=$(date +%s)

while IFS="," read guid notam
do
    temp_guid="${guid%\"}"
    temp_notam="${notam%\"}"
    temp_guid="${temp_guid#\"}"
    temp_notam="${temp_notam#\"}"
    wget https://tfr.faa.gov/save_pages/$temp_notam.shp.zip -P /tmp/
    
    if [ -f "/tmp/$temp_notam.shp.zip" ]; then
        unzip /tmp/$temp_notam.shp.zip -d /home/ec2-user/shapefiles/$temp_guid
    else
        # write guid, notam pair to `archive` csv file for later scrapes
        paste -d, <(echo "$guid") <(echo "$notam") <(echo $runtime) >> /home/ec2-user/newTFRids-archive.csv
    fi
done < newTFRids-export.csv

# loop over archive file if present to check if shapefile archive has been posted
if [ -f "/home/ec2-user/newTFRids-archive.csv" ]; then
    while IFS="," read guid notam timestamp
    do
        temp_guid="${guid%\"}"
        temp_notam="${notam%\"}"
        temp_guid="${temp_guid#\"}"
        temp_notam="${temp_notam#\"}"
        temp_date="${timestamp%\"}"
        temp_date="${temp_date#\"}"
        wget https://tfr.faa.gov/save_pages/$temp_notam.shp.zip -P /tmp/
    
        if [ -f "/tmp/$temp_notam.shp.zip" ]; then
            unzip /tmp/$temp_notam.shp.zip -d /home/ec2-user/shapefiles/$temp_guid
            sed -i "/$temp_guid/d" newTFRids-archive.csv
        else
            # check timestamp to see if TFR should be removed from archive to avoid downloading shapefiles of a future TFR that shares NOTAM identifier
            timestamp_d=$(date -d @$timestamp)
            expire_stamp_d=$(date --date="$timestamp_d +7 days")
            expire_stamp_s=$(date --date="$expire_stamp_d" +%s)
            
            # remove record from archived TFRs if no shapefile has been found within a week
            if [ $runtime -ge $expire_stamp_s ]; then
                sed -i "/$temp_guid/d" newTFRids-archive.csv
            fi
        fi
    done < newTFRids-archive.csv
fi
