# Netflix Prize Attempt in D

This D code was my attempt at the Netflix Prize.  At it's best, it achieved a RMSE of 0.9158 which is better than Netflix's Cinematch RMSE of 0.9514.

I haven't looked at this project in over five years (since 2007), so I don't remember how it works or what files do what.  I'm going to try to clean it up some.  I'm renaming files that didn't have an extention to the .map extention and not committing any data files (they're not really mine) so that they can be easily filtered by .gitignore.  Because of the missing data files, and possible changes in D, I don't think this code will be very useful as-is.  I may consider creating fake data file to play with.

## Credit:
I have to give credit to Simon Funk for explaining how to use SVD to make useful ratings estimates.  I used his notes and code extensively in my code.  http://sifter.org/~simon/journal/20061211.html

## Additional Links:
* http://www.netflixprize.com/
* http://dlang.org/
* http://www.apejet.org/aaron/blog/2007/03/12/netflix-prize-update-2/
* http://www.apejet.org/aaron/blog/2007/03/13/netflix-prize-sample-features/