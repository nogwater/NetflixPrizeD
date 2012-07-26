/*

Copyright 2007 Aaron McBride

Makes predictions for the qualifying.txt data.


Methond:

    load base binary files (custId2Pos, movie avg for baseline)
    load feature files
    
    read qualifying.txt
    open predictions.txt for writing
    for each line
        if it ends in a colon
            set movieId
            write line to predictions.txt
        else
            split at first comma to get custId
            make a prediction for (movieId, custId)
            write prediction line to predictions.txt

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;
//import std.math;
//import std.c.stdlib;

uint[] custId2Pos;
float[] movieAvgRatings;
float[][] f_m_a;//all of the known movie feature values indexed by f,movieIndex 
float[][] f_c_a;//all of the known cust feature values indexed by f,custPos

void main()
{
    static int startFeature = 48;
    static int endFeature = 99;
    
    writefln("startFeature: %s", startFeature);
    writefln("endFeature: %s", endFeature);
    
    f_m_a.length = endFeature+1;
    f_c_a.length = endFeature+1;
    
    d_time startTime, endTime, time1, time2;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    writefln("loading base binary files");
    loadBaseBinaryFiles();
    
    writefln("loading feature files");
    loadFeatures(startFeature, endFeature);    

    //open qualifying.txt and read it into a big string
    writefln("loading qualifying.txt");
    char[] fileContents;    
    Stream qualifyingFile = new File("..\\download\\qualifying.txt");
    fileContents = qualifyingFile.readString(qualifyingFile.available());
    qualifyingFile.close();
    
    Stream predictionsFile = new File("predictions.txt", FileMode.OutNew);
    writefln("making predictions");
    time1 = getUTCtime();
    uint movieId, movieIndex, custId, custPos, commaPos;
    float prediction;
    int predictionCount = 0;
    foreach(char[] line; fileContents.splitlines())
    {
        if(line[line.length-1] == ':')
        {
            movieId = atoi(line[0..line.length-1]);
            movieIndex = movieId - 1;
            predictionsFile.writeLine(line);
        }
        else
        {
            commaPos = find(line, ',');
            custId = atoi(line[0..commaPos]);
            custPos = custId2Pos[custId];
            //make a prediction!
            //baseline
            prediction = movieAvgRatings[movieIndex];
            for(int f = startFeature; f <= endFeature; f++)
            {
                prediction += (f_c_a[f][custPos] * f_m_a[f][movieIndex]);
                //clip as we go
                if(prediction < 1.0) prediction = 1.0;
                else if(prediction > 5.0) prediction = 5.0;
            }
            predictionsFile.writeLine(std.string.toString(prediction));
            predictionCount++;
        }
    }//end for each line in qualifying.txt    
    
    predictionsFile.flush();
    predictionsFile.close();
    time2 = getUTCtime();

    endTime = std.date.getUTCtime();
    writefln("Made %d predictions in %d ticks", predictionCount, time2-time1);
    writefln("Runtime: ", endTime - startTime);
}//end main()

void loadBaseBinaryFiles()
{        
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
    
    //load movieAvgRatings
    movieAvgRatings.length = 17770;
    Stream movieAvgRatingsFile = new File("movieAvgRatings");
    for(int i = 0; i < 17770; i++)
        movieAvgRatingsFile.read(movieAvgRatings[i]);
    movieAvgRatingsFile.close();
}//loadBaseBinaryFiles()

void loadFeatures(int startFeature, int endFeature)
{
    Stream featureFile;
    for(int f = startFeature; f <= endFeature; f++)
    {
        writefln("loading feature %d", f);
        featureFile = new File("features//" ~ std.string.toString(f) ~ "_c");
        f_c_a[f].length = 480189;
        for(int i = 0; i < 480189; i++)
            featureFile.read(f_c_a[f][i]);
        featureFile.close();
        
        featureFile = new File("features//" ~ std.string.toString(f) ~ "_m");
        f_m_a[f].length = 17770;
        for(int i = 0; i < 17770; i++)
            featureFile.read(f_m_a[f][i]);
        featureFile.close();
    } 
}

