/*

Creates a probeSet file (length: 1408395 * (2+3+1)  size: 8MB):
    the format is as a list of rows
    each row is movieId(2bytes) + custId(3bytes) + rating(1byte)
    there are 1408395 rows (one for each probe "question").
    note: this could be made smaller by storing movieIds in an index
        like in the ratings file, but it's unnecessary.
    
note: multi-byte numbers are stored as big-endian

Method:
    load the binary ratings, and movieRatingRowIds files
    for each line in C:\NetflixPrize2\download\probe.txt
        if line ends with ':', set movieId
        else
            set custId
            search for rating of (movieId, custId)
            write row (movieId,CustId,rating) to probeSet file
            
    runtime reading from mm files: about 40 min 
    runtime reading bin files into memory: about 6 min
    runtime writing bin file from array: about 6 min
    runtime with a binary search for rating: about 1.25 min
*/

import std.stdio;
import std.string;
import std.file;
import std.stream;
import std.date;

ubyte[] ratings;
ubyte[] movieRatingRowIds;

void main()
{
    d_time startTime, endTime, time1, time2;
    startTime = getUTCtime();
    Stream probeInputSet, rowIdsFile, ratingsFile, probeFile;
    
    writefln("Start Time: ", std.date.toString(startTime));
    
    char[] probeSetFilePath = r"C:\NetflixPrize2\download\probe.txt";
    //char[] probeSetFilePath = r"C:\NetflixPrize2\download\probe_tiny.txt";
    //char[] probeSetFilePath = r"C:\NetflixPrize2\download\probe_t.txt";
    
    int pos = 0;
    int probeCount = 0;
    
    char[] fileContents;
    int movieId;
    int custId;
    byte rating;    
    
    //create array to store binary probe data
    ubyte[] probeData;
    probeData.length = 1408395 * 6;
    
    //open existing files and populate arrays with their data
    writefln("loading binary files");
    movieRatingRowIds.length = 17770 * 4;
    rowIdsFile = new File("movieRatingRowIds");
    assert(rowIdsFile.available() == movieRatingRowIds.length, "wrong size for movieRatingRowIds");
    rowIdsFile.read(movieRatingRowIds);
    rowIdsFile.close();
    
    ratings.length = 100480507 * 4;
    ratingsFile = new File("ratings");
    assert(ratingsFile.available() == ratings.length, "wrong size for ratings");
    ratingsFile.read(ratings);
    ratingsFile.close();
    
    writefln("reading probe.txt ...");    
    probeInputSet = new File(probeSetFilePath);
    //read the entire file, then chop it up
    fileContents = probeInputSet.readString(probeInputSet.available());
    probeInputSet.close();
    
    writefln("finding all ratings for probe data");
    time1 = getUTCtime();
    foreach(char[] line; fileContents.splitlines())
    {
        //what does atoi return if it fails?
        if(line[line.length-1] == ':')
        {
            movieId = atoi(line[0..line.length-1]);
        }
        else
        {
            custId = atoi(line);
            rating = getRating(movieId, custId);
            //writefln("(%d,%d,%d)", movieId, custId, rating);
            //write row to probe data
            probeData[pos++] = ((movieId>>8) & 0xFF);//write the movieId
            probeData[pos++] = ((movieId>>0) & 0xFF);            
            probeData[pos++] = ((custId>>16) & 0xFF);//write the custId
            probeData[pos++] = ((custId>>8) & 0xFF);
            probeData[pos++] = ((custId>>0) & 0xFF);
            probeData[pos++] = rating;//write the rating
            probeCount++;
        }
    }
    time2 = getUTCtime();

    //write probe data to file
    writefln("saving probe data to file");
    probeFile = new File("probe", FileMode.OutNew);
    probeFile.flush();
    uint bytesWritten = probeFile.write(probeData);
    probeFile.close();
    assert(bytesWritten == probeData.length, "couldn't write all of the probe data");

    endTime = std.date.getUTCtime();
    writefln("End Time: ", std.date.toString(endTime));
    writefln("Runtime: ", endTime - startTime);
    writefln("Read %d probe values in %d ticks.", probeCount, (time2 - time1));
}

byte getRating(int movieId, int custId)
{
    int lowRowId, highRowId, rowId, cId;
    int movieIndex = movieId - 1;    
    lowRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
    if(movieId == 17770)//end
        highRowId = (ratings.length/4);
    else
        highRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
    //lowRowId = getRowId(movieId);
    //highRowId = getRowId(movieId+1);
    
    //binary search between start and end
    rowId = lowRowId + ((highRowId - lowRowId) / 2);
    while(lowRowId <= highRowId)
    {
        cId = (ratings[rowId*4] << 16) + (ratings[rowId*4+1] << 8) + ratings[rowId*4+2];
        if(cId > custId)//p is too high
            highRowId = rowId - 1;
        else if(cId < custId)//p is too low
            lowRowId = rowId + 1;
        else//found it!
            return ratings[rowId*4+3];//return the rating
        rowId = lowRowId + ((highRowId - lowRowId) / 2);//next try...
    }
    assert(0, "coudn't find rating for (" ~ std.string.toString(movieId) ~ ", " ~ std.string.toString(custId) ~")");
    return 0;
}

