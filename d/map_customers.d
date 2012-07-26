/*
Creates two mem map files for users:
    custId2Pos (length: 2,649,430 * 3  size: 7.6MB)
    - look at custId2Pos[id * 3] for 3 bytes indicating pos
    custPos2Id (length: 480,189 * 3  size: 1.4MB)
    - look at custPos2Id[pos * 3] for 3 bytes indicating id
    
    first create a temp array keyed by userId with value of true if the user exists
    then loop through the array to get the position of each userId and store the data in the files
*/

import std.stdio;
import std.string;
import std.file;
import std.stream;
import std.date;
import std.mmfile;

void main()
{
    const int ROW_SIZE = 3;
    d_time startTime, midTime, endTime;
    char[] trainingSetPath = r"C:\NetflixPrize2\download\training_set\";
    //char[] trainingSetPath = r"C:\NetflixPrize2\download\training_set_fake\";
    
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    bool[] custIds;//the big array
    custIds.length = 2649430;    
    
    char[] filename = trainingSetPath ~ "mv_0000000.txt";
    //char[] line;
    char[] lines;
    int custId;
    int ratingsRead = 0;
    
    //read through the entire training set and place a true at each custId2Pos[id] for exists
    for(int movieId = 1; movieId <= 17770; movieId++)
    {
        //set insert the movieId in the file path
        filename[44..49] = zfill(std.string.toString(movieId), 5);
        
        //writefln("loading ", filename);
        Stream file = new File(filename);
        file.readLine();//skip first line
        
        //fastset so far!
        //read the entire file, then chop it up
        lines = file.readString(file.available());
        foreach(char[] line; lines.splitlines())
        {
            custId = atoi(line[0..find(line, ',')]);
            custIds[custId] = true;
            ratingsRead++;
        }        
        
        //a bit faster
        //using the foreach/delegate method:
        //foreach(char[] line; file) {
        //    custId = atoi(line[0..find(line, ',')]);
        //    custIds[custId] = true;
        //    ratingsRead++;
        //}
        
        //slowish
        //reading one line at a time:
        //while(!file.eof) {
        //    line = file.readLine();
        //    custId = atoi(line[0..find(line, ',')]);
        //    custIds[custId] = true;
        //    ratingsRead++;
        //}
        file.close();
	}//for each movieId

    midTime = getUTCtime();
    writefln("Mid Time: ", std.date.toString(midTime));

    //scan through custIds converting existing ids to positions
    
    //create mm files
    MmFile mmCustId2Pos = new MmFile("custId2Pos", MmFile.Mode.ReadWriteNew, 2649430 * ROW_SIZE, null, 0);
    MmFile mmCustPos2Id = new MmFile("custPos2Id", MmFile.Mode.ReadWriteNew, 480189 * ROW_SIZE, null, 0);
    int pos = 0;
    for(int id = 0; id < custIds.length; id++)
    {
        if(custIds[id])
        {
            //writefln("mapping %d->%d", pos, id);
            //write id at pos
            mmCustPos2Id[pos*ROW_SIZE+0] = cast(ubyte)((id>>16) & 0xFF);//most significant first
            mmCustPos2Id[pos*ROW_SIZE+1] = cast(ubyte)((id>>8) & 0xFF);
            mmCustPos2Id[pos*ROW_SIZE+2] = cast(ubyte)((id>>0) & 0xFF);
            //write pos at id
            mmCustId2Pos[id*ROW_SIZE+0] = cast(ubyte)((pos>>16) & 0xFF);//most significant first
            mmCustId2Pos[id*ROW_SIZE+1] = cast(ubyte)((pos>>8) & 0xFF);
            mmCustId2Pos[id*ROW_SIZE+2] = cast(ubyte)((pos>>0) & 0xFF);
            pos++;
        }
    }    
    
    endTime = std.date.getUTCtime();
    writefln("End Time: ", std.date.toString(endTime));
    writefln("Runtime: ", endTime - startTime);
    writefln("Read %d ratings.", ratingsRead);
}
