/*

Copyright 2007 Aaron McBride

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
ubyte[] probe;
uint[] custId2Pos;
float[] movieAvgRatings;
//float[] custAvgRatings;
//float[][] f_m_a;//all of the known movie feature values indexed by f,movieIndex 
//float[][] f_c_a;//all of the known cust feature values indexed by f,custPos
float[] f_m;//current movie feature being learned
float[] f_c;//current cust feature being learned
float[] residuals_t;
float[] residuals_p;


void main()
{
    //training config settings
    static int startFeature = 151;
    static int maxFeatures = 100;
    int windowSize = 32;//initially 2, grow from there
    static maxWindowSize = 100;
    static windowSizeInc = 1;
    static float initFVal = 0.01; //0.005;//0.5;
    static float learnRate = 0.01; //0.005; //decay? //0.001;
    static float K = 0.005; //0.1 // 0.02;
    static int minEpochs = 3; // 10
    static int maxEpochs = 100;
    static float minImprovement = 0.000001; //0.0003; //0.0005;    
    
    writefln("startFeature: %s", startFeature);
    writefln("maxFeatures: %s", maxFeatures);
    writefln("windowSize: %s", windowSize);
    writefln("maxWindowSize: %s", maxWindowSize);
    writefln("windowSizeInc: %s", windowSizeInc);
    writefln("initFVal: %s", initFVal);
    writefln("learnRate: %s", learnRate);
    writefln("K: %s", K);
    writefln("minEpochs: %s", minEpochs);
    writefln("maxEpochs: %s", maxEpochs);
    writefln("minImprovement: %s", minImprovement);
    
    //f_m_a.length = maxFeatures;
    //f_c_a.length = maxFeatures;
    f_m.length = 17770;
    f_c.length = 480189;
    residuals_t.length = 99072112;
    residuals_p.length = 1408395;
    
    //training variables
    d_time startTime, endTime;
    float prevBestProbeRmse = 5.0;
    float prevProbeRmse = 5.0;
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    writefln("loading base binary files");
    loadBaseBinaryFiles();
    

    /**********************************
     *    New Training Starts Here    *
     *********************************/ 
    for(int f = startFeature; f < maxFeatures; f++)
    {
        loadResiduals(f, windowSize);
        
        writefln("Training feature: %d", f);    
        
        //create and init new feature arrays
        f_m.length = 17770;
        for(i = 0; i < 17770; i++)
            f_m[i] = initFVal;
        
        f_c.length = 480189;
        for(i = 0; i < 480189; i++)
            f_c[i] = initFVal;
        
        
        byte actualRating;
        float predictedRating;
        float residualPrediction;
        float error;
        float errorL;
        float userValue;
        float totalSquareError, rmse, probeRmse;
        uint ratingCount;
        
        //for each epoch
        for(int epoch = 0; epoch < maxEpochs; epoch++)
        {        
            totalSquareError = 0;
            ratingCount = 0;
            
            //make predictions and calc error
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
                    predictedRating = (f_c[custPos] * f_m[movieIndex]) + residuals_t[rowId];
                    
                    //clip to fit [1-5]//possibly with weightings (is this really needed?)
                    if(predictedRating < 1.0) predictedRating = 1.0;
                    else if(predictedRating > 5.0) predictedRating = 5.0;
                    
                    //calc error
                    error = actualRating - predictedRating;
                	totalSquareError += error * error;
                	
                    //update feature
                    userValue = f_c[custPos];
                	f_c[custPos] += learnRate * (error * f_m[movieIndex] - K * f_c[custPos]);
                	f_m[movieIndex] += learnRate * (error * userValue - K * f_m[movieIndex]);
                }//end for each rating row in this movieId
            }//end for each movieId
            rmse = sqrt(totalSquareError / ratingCount);
            
            //make probe predictions and calc error
            //writefln("checking rmse for probe");
            totalSquareError = 0;
            ratingCount = 0;
            for(rowId = 0; rowId < 1408395; rowId++)
            {
                i = rowId * 6;
                movieId = (probe[i] << 8) + probe[i+1];
                movieIndex = movieId - 1;
                custPos = custId2Pos[(probe[i+2] << 16) + (probe[i+3] << 8) + (probe[i+4] << 0)];
                actualRating = probe[i+5];
                                
                //make a prediction for this probe row
                predictedRating = (f_c[custPos] * f_m[movieIndex]) + residuals_p[rowId];
                
                //clip to fit [1-5]//possibly with weightings
                if(predictedRating < 1.0) predictedRating = 1.0;
                else if(predictedRating > 5.0) predictedRating = 5.0;
                
                //calc error
                error = actualRating - predictedRating;
                totalSquareError += error * error;
                ratingCount++;
            }
            probeRmse = sqrt(totalSquareError / ratingCount);
            
            float deltaRmse = prevProbeRmse - probeRmse;
            writefln("%d\t%f\t%f\t%f", epoch, rmse, probeRmse, deltaRmse);
            //if probe rmse goes up, we're probably over training
            prevProbeRmse = probeRmse;//we want to remember this for the next epoch
            if(epoch >= minEpochs && deltaRmse <= minImprovement)
            {
                writefln("exiting due to over fitting or reached maxEpochs");
                break;
            }
            
        }//end for each epoch
        
        //if we better stop at this feature
        if(prevBestProbeRmse < probeRmse + 0.00001)
        {
            if(windowSize < maxWindowSize)
            {
                windowSize += windowSizeInc;
                writefln("window size grown to: %s", windowSize);
            }
            else
            {
                writefln("too many features!");
                break;
            }
        }
        prevBestProbeRmse = probeRmse;
        
        //this feature will be added to residuals in next call to calcResiduals()
        
        //save the new feature
        Stream f_cFile = new File("features\\" ~ std.string.toString(f) ~ "_c", FileMode.OutNew);
        for(i = 0; i < f_c.length; i++)
            f_cFile.write(f_c[i]);
        f_cFile.flush();
        f_cFile.close();
        
        Stream f_mFile = new File("features\\" ~ std.string.toString(f) ~ "_m", FileMode.OutNew);
        for(i = 0; i < f_m.length; i++)
            f_mFile.write(f_m[i]);
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
    //custAvgRatings.length = 480189;
    //Stream custAvgRatingsFile = new File("custAvgRatings");
    //for(int i = 0; i < 480189; i++)
    //    custAvgRatingsFile.read(custAvgRatings[i]);
    //custAvgRatingsFile.close();
}//loadBaseBinaryFiles()


void loadResiduals(int f, int windowSize)
{
    //f = next feature to be learned
    //window size is the maximum number of features to work with at a time
    
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
    
    int firstF = f - (windowSize - 1);
    int lastF = f - 1;
    if(firstF < 0) firstF = 0;
    writefln("calc residuals for f [%d - %d]", firstF, lastF);

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
    
    //Baseline for probe
    for(rowId = 0; rowId < 1408395; rowId++)
    {
        i = rowId * 6;
        movieId = (probe[i] << 8) + probe[i+1];
        movieIndex = movieId - 1;
        residuals_p[rowId] = movieAvgRatings[movieIndex];// 3.6;
    }

    //add past features that are within the window to residuals
    
    float predictedRating;
    Stream featureFile;
    float[] f_c_load;
    float[] f_m_load;
    for(int loadF = firstF; loadF <= lastF; loadF++)
    {
        //load feature loadF from file loadF
        featureFile = new File("features//" ~ std.string.toString(loadF) ~ "_c");
        f_c_load.length = 480189;
        for(i = 0; i < 480189; i++)
            featureFile.read(f_c_load[i]);
        featureFile.close();
        
        featureFile = new File("features//" ~ std.string.toString(loadF) ~ "_m");
        f_m_load.length = 17770;
        for(i = 0; i < 17770; i++)
            featureFile.read(f_m_load[i]);
        featureFile.close();
        
        //add to training residuals
        for(movieId = 1; movieId <= 17770; movieId++)
        {
            movieIndex = movieId - 1;
            startRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
            if(movieId == 17770)//end
                endRowId = (ratings.length/4);
            else
                endRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
            
            //movieBaseline = movieAvgRatings[movieIndex];// 3.6;
                    
            //for each customer/rating at this movieId
            for(rowId = startRowId; rowId < endRowId; rowId++)
            {
                i = rowId * 4;
                custPos = custId2Pos[(ratings[i] << 16) + (ratings[i+1] << 8) + (ratings[i+2] << 0)];
                //predict like normal
                predictedRating = (f_c_load[custPos] * f_m_load[movieIndex]) + residuals_t[rowId];
                //clip
                if(predictedRating < 1.0) predictedRating = 1.0;
                else if(predictedRating > 5.0) predictedRating = 5.0;
                //save
                residuals_t[rowId] = predictedRating;
            }
        }
        
        //add to probe residuals
        for(rowId = 0; rowId < 1408395; rowId++)
        {
            i = rowId * 6;
            movieId = (probe[i] << 8) + probe[i+1];
            movieIndex = movieId - 1;
            custPos = custId2Pos[(probe[i+2] << 16) + (probe[i+3] << 8) + (probe[i+4] << 0)];
            //predict like normal
            predictedRating = (f_c_load[custPos] * f_m_load[movieIndex]) + residuals_p[rowId];
            //clip
            if(predictedRating < 1.0) predictedRating = 1.0;
            else if(predictedRating > 5.0) predictedRating = 5.0;
            //save
            residuals_p[rowId] = predictedRating;
        }
    }//end for each past feature
    
}//calcResiduals
