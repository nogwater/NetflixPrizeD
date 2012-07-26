/*

Copyright 2007 Aaron McBride

!!  Uses the "With Probe" files to train !!

Trains a series of features, only working with the last N at a time.
It acts like a sliding window of relevant features.
Hopefully it'll keep the features in use count down while eliminating some error.


Methond:

    set up training parameters
    load base binary files
    etc... see: train_next.d
    
    foreach feature f (max ???)
        calc residuals for features in window
        train the next feature:
            //see: train_next.d
        //save to feature files

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;
import std.math;
import std.c.stdlib;

ubyte[] movieRatingRowIds;
ubyte[] ratings;
//ubyte[] probe;
uint[] custId2Pos;
float[] movieAvgRatings;
//float[] custAvgRatings;
float[][] f_m_a;//all of the known movie feature values indexed by f,movieIndex 
float[][] f_c_a;//all of the known cust feature values indexed by f,custPos
float[] residuals_t;


void main()
{
    //training config settings
    static int maxFeatures = 180;
    static int windowSize = 60;
    static float initFVal = 0.005; //0.005;//0.5;
    static float learnRate = 0.005; //0.005; //decay? //0.001;
    static float K = 0.005; //0.1 // 0.02;
    static int minEpochs = 10; // 10
    static int maxEpochs = 50;
    static float minImprovement = 0.0005; //0.0003; //0.0005;    
    
    writefln("maxFeatures: %s", maxFeatures);
    writefln("windowSize: %s", windowSize);
    writefln("initFVal: %s", initFVal);
    writefln("learnRate: %s", learnRate);
    writefln("K: %s", K);
    writefln("minEpochs: %s", minEpochs);
    writefln("maxEpochs: %s", maxEpochs);
    writefln("minImprovement: %s", minImprovement);
    
    f_m_a.length = maxFeatures;
    f_c_a.length = maxFeatures;    
    residuals_t.length = 100480507;
    
    //training variables
    d_time startTime, endTime;
    float prevRmse = 5.0;
    float prevBestRmse = 5.0;
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    writefln("loading base binary files");
    loadBaseBinaryFiles();
    

    /**********************************
     *    New Training Starts Here    *
     *********************************/ 
    for(int f = 0; f < maxFeatures; f++)
    {
        calcResiduals(f, windowSize);
        
        writefln("Training feature: %d", f+1);    
        
        //create and init new feature arrays
        f_m_a[f].length = 17770;
        for(i = 0; i < 17770; i++)
            f_m_a[f][i] = initFVal;
        
        f_c_a[f].length = 480189;
        for(i = 0; i < 480189; i++)
            f_c_a[f][i] = initFVal;
        
        
        byte actualRating;
        float predictedRating;
        float residualPrediction;
        float error;
        float errorL;
        float userValue;
        float totalSquareError, rmse, probeRmse;
        uint ratingCount;
        
        for(int epoch = 0; epoch < maxEpochs; epoch++)
        {        
            totalSquareError = 0;
            ratingCount = 0;
            
            //log prediction error
            //foreach value in ratings (movieId, custId, actualRating)
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
                    i = rowId * 4;
                    ratingCount++;
                    
                    custPos = custId2Pos[(ratings[i] << 16) + (ratings[i+1] << 8) + (ratings[i+2] << 0)];
                    actualRating = ratings[i+3];
                    
                    //predict
                    predictedRating = (f_c_a[f][custPos] * f_m_a[f][movieIndex]) + residuals_t[rowId];
                    
                    //clip to fit [1-5]//possibly with weightings (is this really needed?)
                    if(predictedRating < 1.0) predictedRating = 1.0;
                    else if(predictedRating > 5.0) predictedRating = 5.0;
                    
                    //calc error
                    error = actualRating - predictedRating;
                	totalSquareError += error * error;
                	
                    //update feature
                    userValue = f_c_a[f][custPos];
                	f_c_a[f][custPos] += learnRate * (error * f_m_a[f][movieIndex] - K * f_c_a[f][custPos]);
                	f_m_a[f][movieIndex] += learnRate * (error * userValue - K * f_m_a[f][movieIndex]);
                }//end for each rating row in this movieId
            }//end for each movieId
            rmse = sqrt(totalSquareError / ratingCount);
            
            float deltaRmse = prevRmse - rmse;
            writefln("%d\t%f\t%f", epoch, rmse, deltaRmse);
            //if rmse goes up, we're probably over training
            prevRmse = rmse;//we want to remember this for the next epoch
            if(epoch >= minEpochs && deltaRmse <= minImprovement)
            {
                writefln("exiting due to over fitting or reached maxEpochs");
                break;
            }
            
        }//end for each epoch
        
        //if we were better off without this feature
        if(prevBestRmse < prevRmse)
        {
            writefln("too many features!");
            break;
        }
        prevBestRmse = prevRmse;
        
        //this feature will be added to residuals in next call to calcResiduals()
        
        //save the new feature
        Stream f_cFile = new File("features\\" ~ std.string.toString(f+1) ~ "_c", FileMode.OutNew);
        for(i = 0; i < f_c_a[f].length; i++)
            f_cFile.write(f_c_a[f][i]);
        f_cFile.flush();
        f_cFile.close();
        
        Stream f_mFile = new File("features\\" ~ std.string.toString(f+1) ~ "_m", FileMode.OutNew);
        for(i = 0; i < f_m_a[f].length; i++)
            f_mFile.write(f_m_a[f][i]);
        f_mFile.flush();
        f_mFile.close(); 
        
        endTime = std.date.getUTCtime();
        writefln("Now: ", std.date.toString(endTime));
        //writefln("Trained for %d epochs in %d ticks", epochs, time2-time1);
    }//for each featureN

endTime = std.date.getUTCtime();
writefln("Runtime: ", endTime - startTime);
}//end main()

void loadBaseBinaryFiles()
{
    //load movieRatingRowIds
    movieRatingRowIds.length = 17770 * 4;
    Stream rowIdsFile = new File("movieRatingRowIdsWP");
    assert(rowIdsFile.available() == movieRatingRowIds.length, "wrong size for movieRatingRowIds");
    rowIdsFile.read(movieRatingRowIds);
    rowIdsFile.close();
    
    //load ratings
    ratings.length = 100480507 * 4;
    Stream ratingsFile = new File("ratingsWP");
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
    
    //load movieAvgRatings
    movieAvgRatings.length = 17770;
    Stream movieAvgRatingsFile = new File("movieAvgRatingsWP");
    for(int i = 0; i < 17770; i++)
        movieAvgRatingsFile.read(movieAvgRatings[i]);
    movieAvgRatingsFile.close();
    
}//loadBaseBinaryFiles()


void calcResiduals(int f, int windowSize)
{
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
    
    int firstF = f - windowSize - 1;
    if(firstF < 0) firstF = 0;
    writefln("calc residuals for f [%d - %d]", firstF+1, f);
        
    //Baseline for training set
    float movieBaseline;
    for(movieId = 1; movieId <= 17770; movieId++)
    {
        movieIndex = movieId - 1;
        startRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
        if(movieId == 17770)//end
            endRowId = (ratings.length/4);
        else
            endRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
        
        movieBaseline = movieAvgRatings[movieIndex];// 3.6;
                
        //for each customer/rating at this movieId
        for(rowId = startRowId; rowId < endRowId; rowId++)
        {
            i = rowId * 4;
            residuals_t[rowId] = movieBaseline;// 3.6
        }
    }//end for all ratings
    
    //add past features that are within the window to residuals
    
    float predictedRating;
    for(int pastF = firstF; pastF < f; pastF++)
    {
        //add to training residuals
        for(movieId = 1; movieId <= 17770; movieId++)
        {
            movieIndex = movieId - 1;
            startRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
            if(movieId == 17770)//end
                endRowId = (ratings.length/4);
            else
                endRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
            
            movieBaseline = movieAvgRatings[movieIndex];// 3.6;
                    
            //for each customer/rating at this movieId
            for(rowId = startRowId; rowId < endRowId; rowId++)
            {
                i = rowId * 4;
                custPos = custId2Pos[(ratings[i] << 16) + (ratings[i+1] << 8) + (ratings[i+2] << 0)];
                //predict like normal
                predictedRating = (f_c_a[pastF][custPos] * f_m_a[pastF][movieIndex]) + residuals_t[rowId];
                //clip
                if(predictedRating < 1.0) predictedRating = 1.0;
                else if(predictedRating > 5.0) predictedRating = 5.0;
                //save
                residuals_t[rowId] = predictedRating;
            }
        }
    }//end for each past feature
    
}//calcResiduals
