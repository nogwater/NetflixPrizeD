/*

Creates a movieRatingRowIds file (length: 17770 * 4  size: 69KB):
    the format is like an array of 4 byte ints
    which contain the rowIds in the ratings file for the movie.
    Look at movieRatingRowIds[movieId-1 * 4] for 4 bytes indicating rowId.

note: to find counts, just use (row[movieId+1] - row[movieId])
    
Creates a ratings file (length: 100480507 * (3+1)  size: 383MB)
    the format is as a list of rows
    each row is a custId (3 bytes) and a rating (1 byte)
    there are 100480507 (one for each ranking) ordered by (movieId, custId).
    To find a rating for (movieId, custId),
        startPos = movieRatingRowIds[movieId-1*4]
        endPos = startPos + movieRatingCounts[movieId-1*2]
    binary search for custId between startPos and endPos.
    
note: multi-byte numbers are stored as big-endian

Method:
    maintain a global counter for rowId
    for each file in training_set
        write to movieRatingRowIds, the current rowId
        count number of ratings as you go
        build an associative array from custId to rating
        order the custIds
        write to ratings file, the rows as (custId, rating)
        write to movieRatingCounts, the ratings count for this movie
*/

import std.stdio;
import std.string;
import std.file;
import std.stream;
import std.date;
import std.mmfile;

void main()
{
    d_time startTime, endTime;
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    char[] trainingSetPath = r"C:\NetflixPrize2\download\training_set\";
    //char[] trainingSetPath = r"C:\NetflixPrize2\download\training_set_t\";
    char[] filename = trainingSetPath ~ "mv_0000000.txt";
    
    int rowId = 0;
    
    char[] lines;
    int custId;
    byte rating;
    int[] custIds;
    int ratingsRead = 0;
    
    int cPos1, cPos2;//comma positions in the line    
    
    writefln("making mm files");
    //create mm files
    MmFile mmMovieRatingRowIds = new MmFile("movieRatingRowIdsWP", MmFile.Mode.ReadWriteNew, 17770 * 4, null, 0);
    MmFile mmRatings = new MmFile("ratingsWP", MmFile.Mode.ReadWriteNew, 100480507 * 4, null, 0);
    
    writefln("reading files...");
    //read through each movie file
    for(int movieId = 1; movieId <= 17770; movieId++)
    {
        //writef("starting %d ", movieId);
        //set insert the movieId in the file path, and open file
        filename[44..49] = zfill(std.string.toString(movieId), 5);//real
        //filename[46..51] = zfill(std.string.toString(movieId), 5);
        Stream file = new File(filename);
        file.readLine();//skip first line
        
        //write to movieRatingRowIds, the current rowId
        //writefln("writing to rowIds for movieId %d: %d %d %d %d", movieId, ((rowId>>24) & 0xFF), ((rowId>>16) & 0xFF), ((rowId>>8) & 0xFF), ((rowId>>0) & 0xFF));
        mmMovieRatingRowIds[(movieId-1)*4+0] = ((rowId>>24) & 0xFF);//most significant first
        mmMovieRatingRowIds[(movieId-1)*4+1] = ((rowId>>16) & 0xFF);
        mmMovieRatingRowIds[(movieId-1)*4+2] = ((rowId>>8) & 0xFF);
        mmMovieRatingRowIds[(movieId-1)*4+3] = ((rowId>>0) & 0xFF);
        
        //read the entire file, then chop it up
        //ratingsCount = 0;
        byte[int] ratingsByCustId;
        lines = file.readString(file.available());
        foreach(char[] line; lines.splitlines())
        {
            cPos1 = find(line, ',');
            cPos2 = rfind(line, ',');
            //read custId
            custId = atoi(line[0..cPos1]);
            //read rating
            rating = atoi(line[cPos1+1..cPos2]);
            //writefln("read rating (%d,%d)", custId, rating); 
            //store rating by custId
            ratingsByCustId[custId] = rating;
            //ratingsCount++;
            ratingsRead++;
        }//end foreach line in file
        file.close();
        //get the custIds (keys of ratingsByCustId) and sort them
        custIds = ratingsByCustId.keys.dup.sort;
        //ratingsCount should equal ratingsByCustId.keys.length
        
        //write to ratings file, the rows as (custId, rating)
        foreach(int id; custIds)
        {
            //writefln("writing to ratings for custId %d: %d %d %d %d", id, ((id>>16) & 0xFF), ((id>>8) & 0xFF), ((id>>0) & 0xFF), ratingsByCustId[id]);
            mmRatings[(rowId)*4+0] = ((id>>16) & 0xFF);//write the custId
            mmRatings[(rowId)*4+1] = ((id>>8) & 0xFF);
            mmRatings[(rowId)*4+2] = ((id>>0) & 0xFF);
            mmRatings[(rowId)*4+3] = ratingsByCustId[id];//write the rating
            rowId++;
        }

        //writefln("processed movieId (%d) with %d ratings", movieId, ratingsCount);
	}//for each movieId
	writefln();

    endTime = std.date.getUTCtime();
    writefln("End Time: ", std.date.toString(endTime));
    writefln("Runtime: ", endTime - startTime);
    writefln("Read %d ratings.", ratingsRead);
}
