/*

Generates a file containing customer avg ratings.
Structured as a list of D floats indexed by custPos (see map_customers.d)

Method:
    load the binary ratings, movieRatingRowIds, and custId2Pos files
    for each movieId
        for each rating row for movieId
            get cust
            get rating
            add rating to cust total
            inc cust count
    for each cust
        saves as a float
Prints:
Global Rating Avg: 3.6033
Global Avg Cust Avg Rating: 3.67445

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;

//input data
ubyte[] movieRatingRowIds;
ubyte[] ratings;
uint[] custId2Pos;

void main()
{
    d_time startTime, endTime;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    writefln("loading binary files");
        
    //load movieRatingRowIds
    movieRatingRowIds.length = 17770 * 4;
    Stream rowIdsFile = new File("movieRatingRowIds");
    assert(rowIdsFile.available() == movieRatingRowIds.length, "wrong size for movieRatingRowIds");
    rowIdsFile.read(movieRatingRowIds);
    rowIdsFile.close();
    
    //load ratings
    ratings.length = 99072112 * 4;
    Stream ratingsFile = new File("ratings");
    assert(ratingsFile.available() == ratings.length, "wrong size for ratings");
    ratingsFile.read(ratings);
    ratingsFile.close();
        
    //load custId2Pos
    ubyte[] custId2PosData;
    custId2PosData.length = 2649430 * 3;
    Stream custId2PosFile = new File("custId2Pos");
    assert(custId2PosFile.available() == custId2PosData.length, "wrong size for custId2Pos");
    custId2PosFile.read(custId2PosData);
    custId2PosFile.close();
    custId2Pos.length = 2649430;
    for(int i = 0; i < 2649430; i++)
        custId2Pos[i] = (custId2PosData[i*3] << 16) + (custId2PosData[i*3+1] << 8) + (custId2PosData[i*3+2]);
    custId2PosData.length = 0;
    
    //write to array first, then dump to files
    
    writefln("computing averages");    

    //working knowledge
    uint[] custPosRatingTotal;
    custPosRatingTotal.length = 480189;
    for(int i = 0; i < 480189; i++)
        custPosRatingTotal[i] = 0;
    uint[] custPosRatingCount;
    custPosRatingCount.length = 480189;
    for(int i = 0; i < 480189; i++)
        custPosRatingCount[i] = 0;
    uint globalRatingTotal = 0;
    uint globalRatingCount = 0;
    float globalAvgTotal = 0;
    uint custCount = 0;
    
    //for each movie,cust
    uint movieId, movieIndex, startRowId, endRowId, rowId;
    byte rating;
    
    for(movieId = 1; movieId <= 17770; movieId++)
    {
        movieIndex = movieId - 1;
        startRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
        if(movieId == 17770)//end
            endRowId = (ratings.length/4);
        else
            endRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
        
        //for each customer/rating at this movieId
        for(rowId = startRowId; rowId < endRowId; rowId++)
        {
            //get data for this row
            int i = rowId * 4;
            
            uint custPos = custId2Pos[(ratings[i] << 16) + (ratings[i+1] << 8) + (ratings[i+2] << 0)];
            rating = ratings[i+3];
            
            custPosRatingTotal[custPos] += rating;
            custPosRatingCount[custPos] += 1;
            
            globalRatingTotal += rating;
            globalRatingCount += 1;
            
        }
    }//end for each movieId
    
    //process each customer
    float avg;
    Stream custAvgRatings = new File("custAvgRatings", FileMode.OutNew);
    for(int custPos = 0; custPos < 480189; custPos++)
    {
        avg = cast(double)custPosRatingTotal[custPos] / cast(double)custPosRatingCount[custPos];
        //writefln("%s\t%s\t%s\t%s", custPos, custPosRatingTotal[custPos], cast(double)custPosRatingCount[custPos], avg);
        assert(avg >= 1.0, "avg too low for custPos: " ~ std.string.toString(custPos));
        assert(avg <= 5.0, "avg too high for custPos: " ~ std.string.toString(custPos));
        custAvgRatings.write(avg);
        
        globalAvgTotal += avg;
        custCount += 1;
    }
    custAvgRatings.flush();
    custAvgRatings.close();
        
    writefln("Global Rating Avg: %s", cast(double)globalRatingTotal / cast(double)globalRatingCount);
    writefln("Global Avg Cust Avg Rating: %s", globalAvgTotal / custCount);
    
    assert(custCount == 480189, "wrong number of customers counted: " ~ std.string.toString(custCount));

    endTime = std.date.getUTCtime();
    writefln("End Time: ", std.date.toString(endTime));
    writefln("Runtime: ", endTime - startTime);
}
