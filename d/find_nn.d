/*

Copyright 2007 Aaron McBride

Findes the K (200?) Nearest Neighbors for each movie and stores them in a file along with their distance.
File size: 17770*200*(2movieId+4distance) = 20MB


Methond:
    K = 200;//for learning
    
    //preload data and features
    
    //euclidian d = sqrt(sum for all f ( (d[f][m1] - d[f][m2])^2) )
    foreach movie
        create a sum-d-squared array where each element is the sum of (the distance to each movie squared) (d self will be 0 of course)
        foreach feature
            foreach otherMovie
                d = m_v_a[f][movieIndex] - m_v_a[f][otherMovie]
                sum-d-squared[otherMovie] += d * d;
        sort sum-d-squared[otherMovie] lowest to highest
        for(i = 1; i <= K; i++)
            mnn[movieIndex][i] = toShort(sorted-sum-d-squared.key) ~ sorted-sum-d-squared.value 

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;
import std.math;
import std.c.stdlib;

float[][] f_m_a;//all of the known movie feature values indexed by f,movieIndex 

void main()
{
    d_time startTime, endTime;
    
    static int startFeature = 0;
    static int endFeature = 9;
    static float K = 200;
    
    startTime = getUTCtime();
    writefln("Start Time: ", std.date.toString(startTime));
    
    writefln("startFeature: %s", startFeature);
    writefln("endFeature: %s", endFeature);
    writefln("K: %s", K);
    
    f_m_a.length = endFeature + 1;
    
    writefln("loading feature files");
    loadFeatures(startFeature, endFeature);
    
    Stream outFile = new File("knn_" ~ std.string.toString(K), FileMode.OutNew);
    
    float d;
    for(short movieIndex = 0; movieIndex < 17770; movieIndex++)
    {
        //writefln("movieIndex: %s", movieIndex);
        //init array
        float sum_d_sq[short];//associative array from movie index to sum d squared
        for(short otherMovieIndex = 0; otherMovieIndex < 17770; otherMovieIndex++)
            sum_d_sq[otherMovieIndex] = 0.0;
        //sum the distances
        for(int f = startFeature; f <= endFeature; f++)
        {
            for(short otherMovieIndex = 0; otherMovieIndex < 17770; otherMovieIndex++)
            {
                d = f_m_a[f][movieIndex] - f_m_a[f][otherMovieIndex];
                sum_d_sq[otherMovieIndex] = d * d;
            }//for each otherMovieIndex
        }//for each f
        
        //find and sort the K nearest movies (excluding self)
        short[] nearestOtherMovies;
        nearestOtherMovies.length = 17770;
        int inCount = 0;
        for(short otherMovieIndex = 0; otherMovieIndex < 17770; otherMovieIndex++)
        {
            if(otherMovieIndex == movieIndex) continue;
            
            if(nearestOtherMovies.length == 0)
            {
                nearestOtherMovies[0] = otherMovieIndex;//usually 0
                inCount++;
            }
            else
            {
                float dist = sum_d_sq[otherMovieIndex];
                //shift the list down and insert at the correct point
                for(int i = inCount - 1; i != -1; i--)
                {
                    sum_d_sq[i+1] = sum_d_sq[i];//copy/shift
                    //if we've found a shorter distance
                    if(dist > sum_d_sq[nearestOtherMovies[i]])
                    {
                        if(i+1 < inCount)
                        {
                            nearestOtherMovies[i+1] = otherMovieIndex;
                            inCount++;
                        }
                        break;
                    }
                }
            } 
        }
        
        //TODO: write data to output file
        for(int i = 0; i < K; i++)
        {
            outFile.write(nearestOtherMovies[i]);//write near movie id
            outFile.write(cast(float)sqrt(sum_d_sq[nearestOtherMovies[i]]));//write distance
        }
        
    }//for each movieIndex
    
    outFile.flush();
    outFile.close();

    endTime = std.date.getUTCtime();
    writefln("Runtime: ", endTime - startTime);
}//end main()

void loadFeatures(int startFeature, int endFeature)
{
    Stream featureFile;
    for(int f = startFeature; f <= endFeature; f++)
    {
        featureFile = new File("features//" ~ std.string.toString(f) ~ "_m");
        f_m_a[f].length = 17770;
        for(int i = 0; i < 17770; i++)
            featureFile.read(f_m_a[f][i]);
        featureFile.close();
    } 
}

