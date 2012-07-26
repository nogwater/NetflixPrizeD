/*

Generates a file containing movie avg ratings.
//Structured like an array of 2 byte numbers.
//    Rating averages can be stored in two bytes as: (rating-1)*16383
//        ratings in [1 to 5] only
//        ie 1 = 0, 1.5 = 8191, 2 = 16383, 5 = 65532
//        to convert back: (stored/16383)+1
//        the granularity is: 0.00006103888
Structured as a list of D floats.

Method:
    load the binary ratings, and movieRatingRowIds files
    for each movieId
        for each rating row for movieId
            get rating
            add rating to total
        //save as two bytes in movieAvgRatings ((ratingTotal / count) - 1 * 16383)
        saves as a float
Prints:
Global Rating Avg: 3.604290
Global Avg Movie Avg Rating: 3.228137
(slightly different from python)

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;

ubyte[] movieRatingRowIds;
ubyte[] ratings;
//ubyte[] movieAvgRatings;

void main()
{
    d_time startTime, endTime, time1, time2;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    Stream probeFile, rowIdsFile, ratingsFile;
    writefln("loading binary files");
        
    movieRatingRowIds.length = 17770 * 4;
    rowIdsFile = new File("movieRatingRowIdsWP");
    assert(rowIdsFile.available() == movieRatingRowIds.length, "wrong size for movieRatingRowIds");
    rowIdsFile.read(movieRatingRowIds);
    rowIdsFile.close();
    
    ratings.length = 100480507 * 4;
    ratingsFile = new File("ratingsWP");
    assert(ratingsFile.available() == ratings.length, "wrong size for ratings");
    ratingsFile.read(ratings);
    ratingsFile.close();    
    
    //write to array first, then dump to files
    //movieAvgRatings.length = 17770 * 2;
    
    writefln("computing averages");
    time1 = getUTCtime();
    double globalRatingTotal = 0;
    double globalAvgTotal = 0;
    uint movieCount = 0;
    uint rowCount = 0;
    //for each movie
    uint movieId, movieIndex, startRowId, endRowId, rowId;
    float avg; 
    double ratingTotal, ratingCount;
    uint codedAvg;
    
    
    rowIdsFile = new File("movieAvgRatingsWP", FileMode.OutNew);
    
    for(movieId = 1; movieId <= 17770; movieId++)
    {
        movieCount++;
        movieIndex = movieId - 1;
        startRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
        if(movieId == 17770)//end
            endRowId = (ratings.length/4);
        else
            endRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
        
        ratingTotal = 0;
        ratingCount = endRowId - startRowId;
        
        //for each customer/rating at this movieId
        for(rowId = startRowId; rowId < endRowId; rowId++)
        {
            ratingTotal += ratings[rowId*4+3];//add this rating
            rowCount++;
        }

        avg = (ratingTotal / ratingCount);
        assert(avg >= 1.0, "avg ratting too low for movie " ~ std.string.toString(movieId) ~ " in rows " ~ std.string.toString(startRowId) ~ " to " ~ std.string.toString(endRowId));
        assert(avg <= 5.0, "avg ratting too high for movie " ~ std.string.toString(movieId) ~ " in rows " ~ std.string.toString(startRowId) ~ " to " ~ std.string.toString(endRowId));
        globalRatingTotal += ratingTotal;
        globalAvgTotal += avg;
        
        
        //codedAvg = cast(uint)(avg - 1 * 16383);
        //write to data array
        //movieAvgRatings[movieIndex*2+0] = (codedAvg >> 8) & 0xFF;//most significant first
        //movieAvgRatings[movieIndex*2+1] = (codedAvg >> 0) & 0xFF;
        
        rowIdsFile.write(avg);
    }//end for each movieId
    time2 = getUTCtime();
    
    rowIdsFile.flush();
    rowIdsFile.close();
    
    //dump data to file    
    //rowIdsFile = new File("movieAvgRatings", FileMode.OutNew);
    //rowIdsFile.write(movieAvgRatings);
    //rowIdsFile.flush();
    //rowIdsFile.close();
    
    writefln("Global Rating Avg: %f", globalRatingTotal / rowCount);
    writefln("Global Avg Movie Avg Rating: %f", globalAvgTotal / movieCount);

    endTime = std.date.getUTCtime();
    writefln("End Time: ", std.date.toString(endTime));
    writefln("Runtime: ", endTime - startTime);
    writefln("Computed avges for %d movies using %d ratings in %d ticks", movieCount, rowCount, time2-time1);
}
