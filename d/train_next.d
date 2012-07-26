/*

Copyright 2007 Aaron McBride

Trains the next feature.  


Methond:
    learnRate = 0.001;
    K = 0.02;//for learning
    
    //preload all previous features
    //create residuals arrays that predict each (movie,customer) based on old features
    //the residuals arrays (training + probe) are keyed on rowId and contain float predictions
    
    foreach epochs (max 100)
        foreach value in ratings (movieId, custId, actualRating)
            
            predictedRating = (userValue[user] * movieValue[movie]) + residuals[rowId];
            //clip to fit [1-5]//possibly with weightings (not needed?)
            
            //calc error
        	real err = learnRate * (actualRating - predictedRating);
            
            //update feature F
        	userValue[user] += err * movieValue[movie];
        	movieValue[movie] += err * userValue[user];
        	//or    	
            userValue[user] += lrate * (err * movieValue[movie] - Kl * userValue[user]);
            movieValue[movie] += lrate * (err * userValue[user] - Kl * movieValue[movie]);
            
            //calc ratings rmse as we go
            
        //use probe to calc rmse
        //show probe rmse and ratings rmse
        //if probe rmse goes up, we're probably over training
    
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
float[] custAvgRatings;
float[] residuals_t;
float[] residuals_p;


void main()
{
    d_time startTime, endTime;
    
    int nextFeatureN = 0;
    int maxFeatures = 100;
    //training config settings
    float initFVal = 0.01;
    float learnRate = 0.01; //0.005; //decay? //0.001;
    float K = 0.005; //0.1 // 0.02;
    int minEpochs = 3; // 10
    int maxEpochs = 100;
    static float minImprovement = 0.000001; //0.0003; //0.0005;      
    
    writefln("nextFeatureN: %s", nextFeatureN);
    writefln("maxFeatures: %s", maxFeatures);
    writefln("initFVal: %s", initFVal);
    writefln("learnRate: %s", learnRate);
    writefln("K: %s", K);
    writefln("minEpochs: %s", minEpochs);
    writefln("maxEpochs: %s", maxEpochs);
    writefln("minImprovement: %s", minImprovement);
    
    float prevBestProbeRmse = 5.0;
    float prevProbeRmse = 5.0;
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    writefln("loading base binary files");
    loadBaseBinaryFiles();
    
    writefln("init residuals");
    initResiduals(48, nextFeatureN);// startFeature, nextFeatureN

    /**********************************
     *    New Training Starts Here    *
     *********************************/ 
    for(int featureN = nextFeatureN; featureN <= maxFeatures; featureN++)
    {    
        writefln("Training feature: %d", featureN);    
        
        //create new feature arrays
        float[] f_m;//indexed by movieId-1
        f_m.length = 17770;
        for(i = 0; i < 17770; i++)
            f_m[i] = initFVal; //0.005;//0.5;
        
        float[] f_c;//indexed by custId2Pos[custId]
        f_c.length = 480189;
        for(i = 0; i < 480189; i++)
            f_c[i] = initFVal; //0.005;//0.0;
        
        byte actualRating;
        float predictedRating;
        float residualPrediction;
        float error;
        float errorL;
        //float residualError;
        //float update;
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
                    predictedRating = (f_c[custPos] * f_m[movieIndex]) + residuals_t[rowId];
                    
                    //experimental
                    if(abs(predictedRating - movieAvgRatings[movieIndex]) < abs(predictedRating - custAvgRatings[custPos]))//movie avg is closer
                        predictedRating = predictedRating * 0.9 + movieAvgRatings[movieIndex] * 0.1;
                    else
                        predictedRating = predictedRating * 0.9 + custAvgRatings[custPos] * 0.1;
                    
                    //clip to fit [1-5]//possibly with weightings (is this really needed?)
                    if(predictedRating < 1.0) predictedRating = 1.0;
                    else if(predictedRating > 5.0) predictedRating = 5.0;
                    
                    //calc error
                    error = actualRating - predictedRating;
                	totalSquareError += error * error;
                	
                    //update feature F
                	//userValue[user] += lrate * (err * movieValue[movie] - K * userValue[user]);
                    //movieValue[movie] += lrate * (err * userValue[user] - K * movieValue[movie]);
                    userValue = f_c[custPos];
                	f_c[custPos] += learnRate * (error * f_m[movieIndex] - K * f_c[custPos]);
                	f_m[movieIndex] += learnRate * (error * userValue - K * f_m[movieIndex]);
                }//end for each rating row in this movieId
            }//end for each movieId
            rmse = sqrt(totalSquareError / ratingCount);
            
            //use probe to calc rmse
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
                
                //experimental
                if(abs(predictedRating - movieAvgRatings[movieIndex]) < abs(predictedRating - custAvgRatings[custPos]))//movie avg is closer
                    predictedRating = predictedRating * 0.9 + movieAvgRatings[movieIndex] * 0.1;
                else
                    predictedRating = predictedRating * 0.9 + custAvgRatings[custPos] * 0.1;
                
                //clip to fit [1-5]//possibly with weightings
                if(predictedRating < 1.0) predictedRating = 1.0;
                else if(predictedRating > 5.0) predictedRating = 5.0;
                
                //calc error
                error = actualRating - predictedRating;
                totalSquareError += error * error;
                ratingCount++;
            }
            probeRmse = sqrt(totalSquareError / ratingCount);
            
            writefln("%d\t%f\t%f\t%f", epoch, rmse, probeRmse, prevProbeRmse - probeRmse);
            //if probe rmse goes up, we're probably over training
            float deltaRmse = prevProbeRmse - probeRmse;
            prevProbeRmse = probeRmse;//we want to remember this for the next epoch
            if((epoch >= minEpochs && deltaRmse <= minImprovement)/* || deltaRmse <= (minImprovement * -1)*/)
            {
                writefln("exiting due to over fitting or reached maxEpochs");
                break;
            }
            
        }//end for each epoch
        
        //if we were better off without this feature
        if(prevBestProbeRmse < probeRmse)
        {
            writefln("too many features!");
            break;
        }
        prevBestProbeRmse = probeRmse;        
        
        //save the new feature
        Stream f_cFile = new File("features\\" ~ std.string.toString(featureN) ~ "_c", FileMode.OutNew);
        for(i = 0; i < f_c.length; i++)
            f_cFile.write(f_c[i]);
        f_cFile.flush();
        f_cFile.close();
        
        Stream f_mFile = new File("features\\" ~ std.string.toString(featureN) ~ "_m", FileMode.OutNew);
        for(i = 0; i < f_m.length; i++)
            f_mFile.write(f_m[i]);
        f_mFile.flush();
        f_mFile.close(); 
        
        //add this feature to the residuals      
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
                i = rowId * 4;
                custPos = custId2Pos[(ratings[i] << 16) + (ratings[i+1] << 8) + (ratings[i+2] << 0)];
                //predict like normal
                predictedRating = (f_c[custPos] * f_m[movieIndex]) + residuals_t[rowId];
                //clip
                if(predictedRating < 1.0) predictedRating = 1.0;
                else if(predictedRating > 5.0) predictedRating = 5.0;
                //save
                residuals_t[rowId] = predictedRating;
            }
        }
    
        //calc probe residuals
        for(rowId = 0; rowId < 1408395; rowId++)
        {
            i = rowId * 6;
            movieId = (probe[i] << 8) + probe[i+1];
            movieIndex = movieId - 1;
            custPos = custId2Pos[(probe[i+2] << 16) + (probe[i+3] << 8) + (probe[i+4] << 0)];
            //predict like normal
            predictedRating = (f_c[custPos] * f_m[movieIndex]) + residuals_p[rowId];
            //clip
            if(predictedRating < 1.0) predictedRating = 1.0;
            else if(predictedRating > 5.0) predictedRating = 5.0;
            //save
            residuals_p[rowId] = predictedRating;
        }   
        
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
    custAvgRatings.length = 480189;
    Stream custAvgRatingsFile = new File("custAvgRatings");
    for(int i = 0; i < 480189; i++)
        custAvgRatingsFile.read(custAvgRatings[i]);
    custAvgRatingsFile.close();
}//loadBaseBinaryFiles()

void initResiduals(int startFeature, int nextFeatureN)
{
    //loads residuals based on features from 1 to (nextFeature-1)
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
        
    //the residuals arrays (training + probe) are keyed on rowId and contain float predictions
    residuals_t.length = 99072112;
    for(i = 0; i < 99072112; i++)
        residuals_t[i] = 0;

    residuals_p.length = 1408395;
    for(i = 0; i < 1408395; i++)
        residuals_p[i] = 0;
        
    //preload residual with baseline movie avgs
    //baseline for training set
    float movieBaseline;
    for(movieId = 1; movieId <= 17770; movieId++)
    {
        movieIndex = movieId - 1;
        startRowId = (movieRatingRowIds[movieIndex*4] << 24) + (movieRatingRowIds[movieIndex*4+1] << 16) + (movieRatingRowIds[movieIndex*4+2] << 8) + movieRatingRowIds[movieIndex*4+3];
        if(movieId == 17770)//end
            endRowId = (ratings.length/4);
        else
            endRowId = (movieRatingRowIds[movieId*4] << 24) + (movieRatingRowIds[movieId*4+1] << 16) + (movieRatingRowIds[movieId*4+2] << 8) + movieRatingRowIds[movieId*4+3];
        
        //movieRatingCount = (endRowId-startRowId);
        //[GlobalAverage*K + sum(ObservedRatings)] / [K + count(ObservedRatings)]
        //movieBaseline = ((90 + (movieAvgRatings[movieIndex]*movieRatingCount)) / (25 + movieRatingCount));
        movieBaseline = movieAvgRatings[movieIndex];// 3.6;
                
        //for each customer/rating at this movieId
        for(rowId = startRowId; rowId < endRowId; rowId++)
        {
            i = rowId * 4;
            custPos = custId2Pos[(ratings[i] << 16) + (ratings[i+1] << 8) + (ratings[i+2] << 0)];
            residuals_t[rowId] = movieBaseline;// 3.6
            //residuals_t[rowId] = (movieBaseline + custAvgRatings[custPos]) / 2.0;
        }
    }//end for all ratings
    
    //baseline for probe
    for(rowId = 0; rowId < 1408395; rowId++)
    {
        i = rowId * 6;
        movieId = (probe[i] << 8) + probe[i+1];
        movieIndex = movieId - 1;
        custPos = custId2Pos[(probe[i+2] << 16) + (probe[i+3] << 8) + (probe[i+4] << 0)];
        residuals_p[rowId] = movieAvgRatings[movieIndex];// 3.6;
        //residuals_p[rowId] = (movieAvgRatings[movieIndex] + custAvgRatings[custPos]) / 2.0;
    }
    
    float predictedRating;
    //load more residuals from feature files
    for(int f = startFeature; f < nextFeatureN; f++)
    {
        float[] f_m;//indexed by movieId-1
        f_m.length = 17770;
        float[] f_c;//indexed by custId2Pos[custId]
        f_c.length = 480189;
        
        //load old feature files
        Stream f_mFile = new File("features\\" ~ std.string.toString(f) ~ "_m");
        for(i = 0; i < 17770; i++)
            f_mFile.read(f_m[i]);
        f_mFile.close();
        
        Stream f_cFile = new File("features\\" ~ std.string.toString(f) ~ "_c");
        for(i = 0; i < 480189; i++)
            f_cFile.read(f_c[i]);
        f_cFile.close();
        
        //calc training residuals        
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
                i = rowId * 4;
                custPos = custId2Pos[(ratings[i] << 16) + (ratings[i+1] << 8) + (ratings[i+2] << 0)];
                
                //predict like normal
                predictedRating = (f_c[custPos] * f_m[movieIndex]) + residuals_t[rowId];
                //clip
                if(predictedRating < 1.0) predictedRating = 1.0;
                else if(predictedRating > 5.0) predictedRating = 5.0;
                //save
                residuals_t[rowId] = predictedRating;
            }
        }
    
        //calc probe residuals
        for(rowId = 0; rowId < 1408395; rowId++)
        {
            i = rowId * 6;
            movieId = (probe[i] << 8) + probe[i+1];
            movieIndex = movieId - 1;
            custPos = custId2Pos[(probe[i+2] << 16) + (probe[i+3] << 8) + (probe[i+4] << 0)];
            
            //predict like normal
            predictedRating = (f_c[custPos] * f_m[movieIndex]) + residuals_p[rowId];
            //clip
            if(predictedRating < 1.0) predictedRating = 1.0;
            else if(predictedRating > 5.0) predictedRating = 5.0;
            //save
            residuals_p[rowId] = predictedRating;
        }        
    }//end for each old residual file
    
}//initResiduals
