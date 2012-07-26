/*

Removes the probe data from the ratings file and updates the movieRatingRowIds index.

Method:
    load the binary ratings, and probe files
    for each row in probe
        set the corresponding row in ratings to a rating of 0
    rewrite the ratings and movieRatingRowIds without rows with rating of 0
    save the files
*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;

ubyte[] probe;
ubyte[] movieRatingRowIds, newMovieRatingRowIds;
ubyte[] ratings, newRatings;

void main()
{
    d_time startTime, endTime, time1, time2;
    uint movieId, custId, rowId, i;
    
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    Stream probeFile, rowIdsFile, ratingsFile;
    writefln("loading binary files");
    
    probe.length = 1408395 * 6;
    probeFile = new File("probe");
    assert(probeFile.available() == probe.length, "wrong size for probe");
    probeFile.read(probe);
    probeFile.close();
    
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
    
    //mark probe data in ratings by setting rating to 0
    writefln("marking all probe data in ratings");
    time1 = getUTCtime();
    for(rowId = 0; rowId < 1408395; rowId++)
    {
        i = rowId * 6;
        //get probe movieId at i
        movieId = (probe[i] << 8) + probe[i+1];
        //get probe custId at i
        custId = (probe[i+2] << 16) + (probe[i+3] << 8) + probe[i+4];
        //set rating for (movieId, custId) to 0
        eraseRating(movieId, custId);
    }
    time2 = getUTCtime();

    //write ratings and movieRatingRowIds without probe data
    writefln("writing ratings and movieRatingRowIds index without probe data");

    //write to arrays first, then dump to files
    newMovieRatingRowIds.length = movieRatingRowIds.length;
    newRatings.length = ratings.length;
    
    //for each movie
    uint pos = 0;
    uint movieIndex, startRowId, endRowId;
    for(movieId = 1; movieId <= 17770; movieId++)
    {
        movieIndex = movieId - 1;
        startRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
        if(movieId == 17770)//end
            endRowId = (ratings.length/4);
        else
            endRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
        assert(startRowId != endRowId, "no ratings found for movieId " ~ std.string.toString(movieId));
        
        //write start pos to index file
        newMovieRatingRowIds[movieIndex*4+0] = (pos >> 24) & 0xFF;//most significant first
        newMovieRatingRowIds[movieIndex*4+1] = (pos >> 16) & 0xFF;
        newMovieRatingRowIds[movieIndex*4+2] = (pos >> 8) & 0xFF;
        newMovieRatingRowIds[movieIndex*4+3] = (pos >> 0) & 0xFF;
        
        //for each customer/rating at this movieId
        for(rowId = startRowId; rowId < endRowId; rowId++)
        {
            i = rowId*4;
            if(ratings[i+3] != 0)//if the rating is NOT 0
            {
                //write row to ratings file
                newRatings[pos*4+0] = ratings[i];//write custId (3 bytes)
                newRatings[pos*4+1] = ratings[i+1];
                newRatings[pos*4+2] = ratings[i+2];
                newRatings[pos*4+3] = ratings[i+3];//write rating (1 byte)
                pos++;
            }
        }
    }//end for each movieId
    
    //dump data to files
    ratingsFile = new File("ratings", FileMode.OutNew);
    newRatings.length = pos * 4;//shrink to fit
    assert(newRatings.length/4 == ((ratings.length/4)-(probe.length/6)), "didn't shrink ratings to the correct size");
    ratingsFile.write(newRatings);
    ratingsFile.flush();
    ratingsFile.close();
    
    rowIdsFile = new File("movieRatingRowIds", FileMode.OutNew);
    rowIdsFile.write(newMovieRatingRowIds);
    rowIdsFile.flush();
    rowIdsFile.close();

    endTime = std.date.getUTCtime();
    writefln("End Time: ", std.date.toString(endTime));
    writefln("Runtime: ", endTime - startTime);
    writefln("Wrote %d rows to ratings file", pos);
    writefln("Removed %d probe values from ratings in %d ticks.", 1408395, (time2 - time1));
}

void eraseRating(int movieId, int custId)
{
    int lowRowId, highRowId, rowId, i, cId;
    int movieIndex = movieId - 1;
    
    lowRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
    if(movieId == 17770)//end
        highRowId = (ratings.length/4);
    else
        highRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
    
    //binary search between start and end
    rowId = lowRowId + ((highRowId - lowRowId) / 2);
    i = rowId * 4;
    while(lowRowId <= highRowId)
    {
        cId = (ratings[i] << 16) + (ratings[i+1] << 8) + ratings[i+2];
        //writefln("(lowRowId, rowId, highRowId, i, cId) = (%d, %d, %d, %d, %d)", lowRowId, rowId, highRowId, i, cId);
        if(cId > custId)//p is too high
            highRowId = rowId - 1;
        else if(cId < custId)//p is too low
            lowRowId = rowId + 1;
        else//found it!
        {
            assert(ratings[i+3] != 0, "rating already zero for movieId,custId " ~ std.string.toString(movieId) ~ ", " ~ std.string.toString(custId));
            ratings[i+3] = 0;//set rating to 0
            return;
        }
        rowId = lowRowId + ((highRowId - lowRowId) / 2);//next try...
        i = rowId * 4;
    }
    assert(0, "coudn't find rating for (" ~ std.string.toString(movieId) ~ ", " ~ std.string.toString(custId) ~")");
    return 0;
}

