/*

Prints the movie titles sorted by feature value.

*/

import std.stdio;
import std.string;
import std.stream;
import std.file;

void main()
{
    char[] movieTitles[];
    movieTitles.length = 17771;
    char[] lines;
    char[] title;
    int cPos1, cPos2;
    int i;
        
    //load the movie titles
    Stream file = new File("..\\download\\movie_titles.txt");
    lines = file.readString(file.available());
    i = 1;
    foreach(char[] line; lines.splitlines())
    {
        cPos1 = find(line, ',');
        cPos2 = find(line[cPos1+1..$], ',') + cPos1 + 1;
        title = line[cPos2+1..$];
        //writefln("%s", title);
        movieTitles[i] = title;
        i++;
    }
    file.close();
    
    for(int f = 1; f <= 10; f++)
    {
        int valueMovies[float];
        float value1;
        //load the feature data
        file = new File("features\\" ~ toString(f) ~ "_m");
        i = 1;
        while(!file.eof())
        {
            file.read(value1);
            valueMovies[value1] = i++;       
        }
        file.close();
        
        //get a sorted list of feature values
        float[] sortedValues = valueMovies.keys.dup.sort.reverse;
        
        //write title file
        file = new File("feature_titles\\" ~ toString(f) ~ ".txt", FileMode.OutNew);
        foreach(float value2; sortedValues)
        {
            int movieId = valueMovies[value2];
            //writefln("%s", movieTitles[movieId]);
            file.writeLine(movieTitles[movieId]);
        }
    }
    
}//end main()
