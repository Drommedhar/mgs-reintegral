#ifndef MGS_INPUT_MOVIE_H
#define MGS_INPUT_MOVIE_H

/* A nonzero diagnostic tail repeats the final packet after E and always fails completion. */
int MgsInputMovieConfigure(const char *record, const char *replay, const char *identity,
                          unsigned diagnostic_tail_frames);
/* Returns 0 on failure, 1 while running, and 2 at a verified replay end. */
int MgsInputMovieVSync(void);
unsigned MgsInputMovieSamples(void);
int MgsInputMovieClose(void);
int MgsInputMovieReplaying(void);
int MgsInputMovieSupportsRumble(int port);

#endif
