/*

Trains first feature which sets the baseline for the rest.
    All movieValues are initialised to 3.6 (global avg movie rating)
    All userValues are initilized to 1.0 (no offset)

Method:
    learnRate = 0.001;
    
    foreach epochs (max 100)
        foreach value in ratings (movieId, custId, actualRating)
            
            predictedRating = userValue[user] * movieValue[movie];
            //clip to fit [1-5]//possibly with weightings        
            
            //calc error
        	real err = learnRate * (actualRating - predictedRating);
            //update feature F
        	userValue[user] += err * userValue[movie];
        	movieValue[movie] += err * movieValue[user];
            //calc ratings rmse as we go
        //use probe to calc rmse
        //show probe rmse and ratings rmse
        //if probe rmse goes up, exit
    
    //save to feature files

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;
import std.math;

void main()
{
    d_time startTime, endTime, time1, time2;
    
    ubyte[] movieRatingRowIds;
    ubyte[] ratings;
    ubyte[] probe;
    ubyte[] custId2PosData;
    uint[] custId2Pos;
        
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    //open existing files and populate arrays with their data
    Stream rowIdsFile, ratingsFile, custId2PosFile, probeFile;
    writefln("loading binary files");
        
    movieRatingRowIds.length = 17770 * 4;
    rowIdsFile = new File("movieRatingRowIds");
    assert(rowIdsFile.available() == movieRatingRowIds.length, "wrong size for movieRatingRowIds");
    rowIdsFile.read(movieRatingRowIds);
    rowIdsFile.close();
    
    ratings.length = 99072112 * 4;
    ratingsFile = new File("ratings");
    assert(ratingsFile.available() == ratings.length, "wrong size for ratings");
    ratingsFile.read(ratings);
    ratingsFile.close();
        
    custId2PosData.length = 2649430 * 3;
    custId2PosFile = new File("custId2Pos");
    assert(custId2PosFile.available() == custId2PosData.length, "wrong size for custId2Pos");
    custId2PosFile.read(custId2PosData);
    custId2PosFile.close();
    custId2Pos.length = 2649430;
    for(int i = 0; i < 2649430; i++)
        custId2Pos[i] = (custId2PosData[i*3] << 16) + (custId2PosData[i*3+1] << 8) + (custId2PosData[i*3+2]);
    custId2PosData.length = 0;
        
    //load probe
    probe.length = 1408395 * 6;
    probeFile = new File("probe");
    assert(probeFile.available() == probe.length, "wrong size for probe");
    probeFile.read(probe);
    probeFile.close();
    
    
    //write to array first, then dump to files
    float[] f_1_m;//indexed by movieId-1
    f_1_m.length = 17770;
    for(int i = 0; i < 17770; i++) f_1_m[i] = 3.6;
    float[] f_1_c;//indexed by custId2Pos[custId]
    f_1_c.length = 480189;
    for(int i = 0; i < 480189; i++) f_1_c[i] = 1.0;
        
    writefln("start training");
    float learnRate = 0.001;
    //float Kl = 0.02;
    int epochs = 100;
    
    time1 = getUTCtime();
    byte actualRating;
    float predictedRating;
    float error;
    float[] errors;//indexed by rowId
    errors.length = 99072112;
    float errorL;
    float totalSquareError, rmse, probeRmse, prevProbeRmse;
    uint ratingCount;
    uint movieId, movieIndex, startRowId, endRowId, rowId, i, custId, custPos;
    
    prevProbeRmse = 5.0;
    for(int epoch = 0; epoch < epochs; epoch++)
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
                
                //using features 0-F predict rating
                //Baseline prediction is then: averageRating[movie] + averageOffset[user].
                //  BetterMean = (GlobalAverage*Km + sum(ObservedRatings)) / (Km + count(ObservedRatings))
                //normal prediction is:
                predictedRating = f_1_c[custPos] * f_1_m[movieIndex];
                //clip to fit [1-5]//possibly with weightings
                if(predictedRating < 0.0) predictedRating = 0.0;
                else if(predictedRating > 6.0) predictedRating = 6.0;
                
                //calc error
            	//errors[rowId] = actualRating - predictedRating;
            	error = actualRating - predictedRating;
            	
            	errorL = error * learnRate;
            	totalSquareError += error * error;
            	
                //update feature F
            	//f_1_c[custPos] += errorL * f_1_m[movieIndex];
            	//f_1_m[movieIndex] += errorL * f_1_c[custPos];
            	//or
            	//f_1_c[custPos] += learnRate * (error * f_1_m[movieIndex] - Kl * f_1_c[custPos]);
            	//f_1_m[movieIndex] += learnRate * (error * f_1_c[custPos] - Kl * f_1_m[movieIndex]);
            	//or
            	f_1_c[custPos] += learnRate * error;
            	f_1_m[movieIndex] += learnRate * error;
            }//end for each rating row in this movieId
        }//end for each movieId
        
        //use probe to calc rmse
        //show probe rmse and ratings rmse
        //writefln("totalSquareError: %f, ratingCount: %d", totalSquareError, ratingCount);
        rmse = sqrt(totalSquareError / ratingCount);
        //writefln("epoch %d rating rmse %f", epoch, rmse);
        //if probe rmse goes up, we're probably over training
        
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
            predictedRating = f_1_c[custPos] * f_1_m[movieIndex];
            //clip to fit [1-5]//possibly with weightings
            if(predictedRating < 1.0) predictedRating = 1.0;
            else if(predictedRating > 5.0) predictedRating = 5.0;
            
            //calc error
            error = actualRating - predictedRating;
            totalSquareError += error * error;
            ratingCount++;
        }
        probeRmse = sqrt(totalSquareError / ratingCount);
        //writefln("probe rating rmse %f", rmse);
        writefln("%d\t%f\t%f\t%f", epoch, rmse, probeRmse, prevProbeRmse - probeRmse);
        if(probeRmse > prevProbeRmse)
        {
            writefln("exiting due to over fitting");
            break;
        }
        prevProbeRmse = probeRmse;
        
    }//end for each epoch
    time2 = getUTCtime();
    
    
    writefln("saving feature files");
    Stream f_1_cFile = new File("features\\1_c", FileMode.OutNew);
    for(i = 0; i < f_1_c.length; i++)
        f_1_cFile.write(f_1_c[i]);
    f_1_cFile.flush();
    f_1_cFile.close();
    
    Stream f_1_mFile = new File("features\\1_m", FileMode.OutNew);
    for(i = 0; i < f_1_m.length; i++)
        f_1_mFile.write(f_1_m[i]);
    f_1_mFile.flush();
    f_1_mFile.close();
    
    
    endTime = std.date.getUTCtime();
    writefln("End Time: ", std.date.toString(endTime));
    writefln("Runtime: ", endTime - startTime);
    //writefln("Trained for %d epochs in %d ticks", epochs, time2-time1);
}//end main()
