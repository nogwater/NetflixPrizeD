/*

    Calculates the RMSE for the given feature(s).

Method:
    load data files: probe, features
    
    count = 0;
    totalSquareError = 0;
    foreach probe value (movieId, custId, actualRating)
        //make a prediction for (movieId, custId)
        for each feature
            predictedRating = userValue[user] * movieValue[movie];
        //avg the features together
        //clip anything outside of 1-5
        
        //calc error
        error = predictedRating - actualRating;
        errorSquared = error * error;
        totalSquareError += errorSquared;
        count++;
    msq = totalSquareError / count;
    rmse = sqrt(msq);
    //print rmse
*/
