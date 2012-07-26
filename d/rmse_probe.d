/*

Copyright 2007 Aaron McBride

Calculates a RMSE of a given set of features against the probe set.


Methond:

    set up test parameters
    load base binary files
    
    foreach probe row
        make prediction
        calculate error
    
    report rmse

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;
import std.math;

ubyte[] probe;
uint[] custId2Pos;
float[] movieAvgRatings;
float[] custAvgRatings;
float[][] f_m_a;//all of the known movie feature values indexed by f,movieIndex 
float[][] f_c_a;//all of the known cust feature values indexed by f,custPos
float[] residuals_t;
float[] residuals_p;


void main()
{
    d_time startTime, endTime;
    
    int startFeature = 48;
    int endFeature = 150;
    
    f_m_a.length = endFeature+1;
    f_c_a.length = endFeature+1;
    
    writefln("startFeature: %s", startFeature);
    writefln("endFeature: %s", endFeature);
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    writefln("loading base binary files");
    loadBaseBinaryFiles();
    
    writefln("loading feature files");
    loadFeatures(startFeature, endFeature);  
    
    writefln("calculating probe rmse");
    
    uint rowId, i, movieId, movieIndex, custPos, actualRating;    
    float predictedRating, error, rmse;
    float totalSquareError = 0;
    float ratingCount = 0;
    static float mixRatio = 0.91;//ratio of prediction to nearest avg
    float lAvg;
    float hAvg;
    int lCount = 0;
    int mCount = 0;
    int hCount = 0;
    //for each probe row
    for(rowId = 0; rowId < 1408395; rowId++)
    {
        //read row
        i = rowId * 6;
        movieId = (probe[i] << 8) + probe[i+1];
        movieIndex = movieId - 1;
        custPos = custId2Pos[(probe[i+2] << 16) + (probe[i+3] << 8) + (probe[i+4] << 0)];
        actualRating = probe[i+5];
        
        //start prediction with the movie avg rating
        predictedRating = movieAvgRatings[movieIndex];// 3.6;
        for(int f = startFeature; f <= endFeature; f++)
        {
            predictedRating += (f_c_a[f][custPos] * f_m_a[f][movieIndex]);
            //clip
            if(predictedRating < 1.0) predictedRating = 1.0;
            else if(predictedRating > 5.0) predictedRating = 5.0;
            
        }
        
        predictedRating = (predictedRating * mixRatio) + ((movieAvgRatings[movieIndex] + custAvgRatings[custPos]) / 2.0) * (1-mixRatio);
    
        //if(movieAvgRatings[movieIndex] > custAvgRatings[custPos])
        //{
        //    lAvg = custAvgRatings[custPos];
        //    hAvg = movieAvgRatings[movieIndex];
        //}
        //else
        //{
        //    lAvg = movieAvgRatings[movieIndex];
        //    hAvg = custAvgRatings[custPos];
        //}
    
        
    
        //benefit of the doubt rating: 1.03756
        //if(hAvg < predictedRating)
        //    predictedRating = predictedRating;
        //else
        //    predictedRating = hAvg;    
    
        //anti-benefit of the doubt rating: 0.93071
        //if(hAvg < predictedRating)
        //    predictedRating = hAvg;   
        //else
        //    predictedRating = predictedRating;
        
        //if(predictedRating < lAvg)//prediction is low
            //predictedRating = predictedRating * mixRatio + lAvg * (1 - mixRatio); //lCount++;
        //    predictedRating = predictedRating;
        //else if(predictedRating < hAvg)//prediction is between low and high
            //predictedRating = predictedRating * mixRatio + lAvg * ((1-mixRatio)/2) + hAvg * ((1-mixRatio)/2);
        //    predictedRating = predictedRating;
            //predictedRating = (predictedRating + lAvg + hAvg) / 3.0; //mCount++;
        //else//prediction is high
        //    predictedRating = predictedRating * mixRatio + hAvg * (1 - mixRatio); //lCount++;
            //predictedRating = predictedRating; // hCount++;
        
    
        //if(abs(movieAvgRatings[movieIndex] - predictedRating) < abs(custAvgRatings[custPos] - predictedRating))
        //    predictedRating = predictedRating * mixRatio + movieAvgRatings[movieIndex] * (1 - mixRatio);//movie avg closer
        //else
        //    predictedRating = predictedRating * mixRatio + custAvgRatings[custPos] * (1 - mixRatio);//cust avg closer
    
        //predict based on closest avg
        //if(abs(movieAvgRatings[movieIndex] - actualRating) < abs(custAvgRatings[custPos] - actualRating))
        //    predictedRating = movieAvgRatings[movieIndex];//movie avg closer
        //else
        //    predictedRating = custAvgRatings[custPos];//cust avg closer
    
        error = actualRating - predictedRating;
        totalSquareError += error * error;
        ratingCount++;
    }

    rmse = sqrt(totalSquareError / ratingCount);
    
    //writefln("lCount: %s  mCount: %s  hCount: %s", lCount, mCount, hCount); //1408395   
    writefln("Probe RMSE: %s", rmse);
        
    endTime = std.date.getUTCtime();
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
        
    //load probe
    probe.length = 1408395 * 6;
    Stream probeFile = new File("probe");
    assert(probeFile.available() == probe.length, "wrong size for probe");
    probeFile.read(probe);
    probeFile.close();
    
    //load movieAvgRatings
    movieAvgRatings.length = 17770;
    Stream movieAvgRatingsFile = new File("movieAvgRatings");
    for(int i = 0; i < 17770; i++)
        movieAvgRatingsFile.read(movieAvgRatings[i]);
    movieAvgRatingsFile.close();
    
    //load custAvgRatings
    custAvgRatings.length = 480189;
    Stream custAvgRatingsFile = new File("custAvgRatings");
    for(int i = 0; i < 480189; i++)
        custAvgRatingsFile.read(custAvgRatings[i]);
    custAvgRatingsFile.close();
    
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
