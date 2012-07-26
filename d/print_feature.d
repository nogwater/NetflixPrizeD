/*

Prints a feature file to standard output.

*/

import std.stdio;
import std.string;
import std.date;
import std.stream;
import std.file;
import std.math;

void main()
{
    float f;
    Stream file = new File("features\\1_m");
    while(!file.eof())
    {
        file.read(f);
        writefln(f);
        
    }
    file.close();
}//end main()
