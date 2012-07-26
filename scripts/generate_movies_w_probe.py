"""
Generates the movie index and data files (with probe data).
The index file is of the form:
    movieId(2), rowId(4),ratingCount(3),avgRating(2)
The data file is of the form:
    custId(3), rating(1)
Required Files:
    download\training_set\mv_00?????.txt
Sample Source Data:
    1:
    1488844,3,2005-09-06
    822109,5,2005-05-13
Method:
    create for writing binary:
        data\m_idx_wp
        data\m_dat_wp
    set rowId = 0
    foreach file in download\training_set\
        open the file
        read the first line
        store the number before the colon as movieId
        set ratingTotal = 0
        set ratingCount = 0
        foreach additional line
            split into custId,rating
            ratingTotal += rating
            ratingCount++
            write to m_dat_wp: custId,rating
        compute avg
        convert avg into short (2 bytes) by (avg-1)*16384 
        write to m_idx_wp: id(2),rowId(4),count(3),avg(2)
        rowId += count
    close files
    print summary (movie count, global rating count, global avg, run time)
"""

import os
import struct #http://docs.python.org/lib/module-struct.html
import time   #http://docs.python.org/lib/module-time.html


idxFileName = "data\\m_idx_wp"
datFileName = "data\\m_dat_wp"
sourcePath = "download\\training_set\\"
#sourcePath = "download\\training_set_tiny\\"

startTime = time.time()

idxFile = open(idxFileName, "wb")
datFile = open(datFileName, "wb")

rowId = 0
globalRatingCount = 0
globalRatingTotal = 0
globalRatingAvgTotal = 0
globalMovieCount = 0

for i in range(17770):
    movieId = i + 1
    mFile = open(os.path.join(sourcePath,'mv_' + str(movieId).rjust(7, '0') + '.txt'), "r")
    mFile.readline()#skip the first line
    ratingTotal = 0
    ratingCount = 0
    #print movieId
    for line in mFile:
        [custId, rating, date] = line.split(',', 3)
        #print custId, rating
        custId = int(custId)
        rating = int(rating)
        ratingTotal += rating
        ratingCount += 1
        #write to m_dat_wp: custId(3),rating(1)
        datFile.write(struct.pack('B', (custId >> 16) & 255))
        datFile.write(struct.pack('B', (custId >> 8) & 255))
        datFile.write(struct.pack('B', (custId >> 0) & 255))
        datFile.write(struct.pack('B', rating))
    mFile.close()
    #end for each data line in movie file
    #print movieId, ratingTotal, ratingCount, (ratingTotal/float(ratingCount))
    #convert avg into short (2 bytes) by (avg-1)*16384
    avg = ratingTotal / float(ratingCount)
    sAvg = int(round((avg - 1) * 16383))
    #write to m_idx_wp: rowId(4),count(3),sAvg(2)
    #idxFile.write(struct.pack('H', int(movieId)))
    idxFile.write(struct.pack('I', rowId))
    idxFile.write(struct.pack('B', (ratingCount >> 16) & 255))
    idxFile.write(struct.pack('B', (ratingCount >> 8) & 255))
    idxFile.write(struct.pack('B', (ratingCount >> 0) & 255))
    idxFile.write(struct.pack('H', sAvg))
    #print "movieId:", movieId, "count:", ratingCount, "avg:", avg
    rowId += ratingCount
    globalRatingCount += ratingCount
    globalRatingTotal += ratingTotal
    globalRatingAvgTotal += avg
    globalMovieCount += 1
#end for each file in sourchPath

idxFile.flush()
idxFile.close()
datFile.flush()
datFile.close()

globalAvgRating = globalRatingTotal / float(globalRatingCount)
globalMovieAvgRating = globalRatingAvgTotal / float(globalMovieCount)
endTime = time.time()
runTime = endTime - startTime
print "globalMovieCount:", globalMovieCount
print "globalRatingCount:", globalRatingCount
print "globalAvgRating:", globalAvgRating 
print "globalMovieAvgRating:", globalMovieAvgRating 
print "runTime(sec):", runTime
