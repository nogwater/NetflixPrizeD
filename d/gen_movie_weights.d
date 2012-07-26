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
//float[] f_m;//current movie feature being learned
//float[] f_c;//current cust feature being learned
float[] residuals_t;
float[] residuals_p;
float[] weights;


void main()
{
    //training config settings    
    static int startFeature = 0;//48;
    static int endFeature = 14;//150;
    static float learnRate = 0.0001; //0.005; //decay? //0.001;
    static float K = 0.02; //0.1 // 0.02;
    static int maxEpochs = 100;
    static float minImprovement = 0.000001; //0.0003; //0.0005;    
    
    writefln("startFeature: %s", startFeature);
    writefln("endFeature: %s", endFeature);
    writefln("learnRate: %s", learnRate);
    writefln("K: %s", K);
    writefln("maxEpochs: %s", maxEpochs);
    writefln("minImprovement: %s", minImprovement);
    
    //f_m_a.length = maxFeatures;
    //f_c_a.length = maxFeatures;
    //f_m.length = 17770;
    //f_c.length = 480189;
    residuals_t.length = 99072112;
    residuals_p.length = 1408395;
    
    //training variables
    d_time startTime, endTime;
    float prevProbeRmse = 5.0;
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    writefln("loading base binary files");
    loadBaseBinaryFiles();
    initResiduals(startFeature, endFeature);
    
    weights.length = 17770;
    for(i = 0; i < 17770; i++)
        weights[i] = 0.0;//init with full weight to prediction
        
    byte actualRating;
    float predictedRating, weightedRating, w;
    float residualPrediction;
    float error;
    float errorL;
    float userValue;
    float totalSquareError, rmse, probeRmse;
    uint ratingCount;
    
    //for each epoch
    for(int epoch = 1; epoch <= maxEpochs; epoch++)
    {        
        totalSquareError = 0;
        ratingCount = 0;
        
        //make predictions and calc error
        //foreach value in ratings (movieId, custId, actualRating)
        for(movieId = 1; movieId <= 17770; movieId++)
        {
            float totalW = 0;
            float ratingsForThisMovie = 0;
            
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
                predictedRating = residuals_t[rowId];
                
                //clip to fit [1-5]//possibly with weightings (is this really needed?)
                if(predictedRating < 1.0) predictedRating = 1.0;
                else if(predictedRating > 5.0) predictedRating = 5.0;
                
                //weight with avg
                weightedRating = (movieAvgRatings[movieIndex] * weights[movieIndex]) + (predictedRating * (1.0 - weights[movieIndex]));
                //clip
                if(weightedRating < 1.0) weightedRating = 1.0;
                else if(weightedRating > 5.0) weightedRating = 5.0;
                
                //calc error
                error = actualRating - weightedRating;
            	totalSquareError += error * error;
            	
                if(movieAvgRatings[movieIndex] - predictedRating != 0.0)
            	{
                	//update weight
                	//correct weight = (actualRating - predictedRating) / (movieAvgRatings[movieIndex] - predictedRating)
                	w = (actualRating - predictedRating) / (movieAvgRatings[movieIndex] - predictedRating);
                    totalW += w;
                	//move weights[movieIndex] towards w
                    //weights[movieIndex] += learnRate * (w - weights[movieIndex]);// - (K * weights[movieIndex]);
                }               
            	
            }//end for each rating row in this movieId
            
            if(endRowId - startRowId != 0)
                weights[movieIndex] = (totalW / (endRowId - startRowId)) * 0.01;//avg w
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
            predictedRating = residuals_p[rowId];
            
            //clip to fit [1-5]//possibly with weightings
            if(predictedRating < 1.0) predictedRating = 1.0;
            else if(predictedRating > 5.0) predictedRating = 5.0;
            
            //weight with avg
            weightedRating = (movieAvgRatings[movieIndex] * weights[movieIndex]) + (predictedRating * (1-weights[movieIndex]));
            //clip
            if(weightedRating < 1.0) weightedRating = 1.0;
            else if(weightedRating > 5.0) weightedRating = 5.0;
            
            //calc error
            error = actualRating - weightedRating;
            totalSquareError += error * error;
            ratingCount++;
        }
        probeRmse = sqrt(totalSquareError / ratingCount);
        
        float deltaRmse = prevProbeRmse - probeRmse;
        writefln("%d\t%f\t%f\t%f", epoch, rmse, probeRmse, deltaRmse);
        //if probe rmse goes up, we're probably over training
        prevProbeRmse = probeRmse;//we want to remember this for the next epoch
        if(deltaRmse <= minImprovement)
        {
            writefln("exiting due to over fitting");
            //break;
        }
        
    }//end for each epoch
    
    //TODO: save weights

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


void initResiduals(int startFeature, int endFeature)
{
    //f = next feature to be learned
    //window size is the maximum number of features to work with at a time
    
    uint movieId, movieIndex, startRowId, endRowId, movieRatingCount, rowId, i, custId, custPos;
    writefln("calc residuals for f [%d - %d]", startFeature, endFeature);

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
    for(int f = startFeature; f <= endFeature; f++)
    {
        writefln("loading feature %d", f);
        //load feature loadF from file loadF
        featureFile = new File("features//" ~ std.string.toString(f) ~ "_c");
        f_c_load.length = 480189;
        for(i = 0; i < 480189; i++)
            featureFile.read(f_c_load[i]);
        featureFile.close();
        
        featureFile = new File("features//" ~ std.string.toString(f) ~ "_m");
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
