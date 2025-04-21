The RND() function replacement implementation creates a 32-bit random number with 2 separate xor shift functions. This implementation is experimental and does not use the RND() function parameter; means: it works as like as RND(0).

You can test it yourself with the following with the following both programs:
(1.) xorsh2x_fix.prg: This program copy's the BASIC/KERNAL ROM's into ram and patches after them the RND() function in the KERNAL ROM from $e097 to $e0d9.
(2.) xorsh2x_test.prg: This program shows the resultates of the random numbers direct on screen with "RND(0)*1000" for 1000 visable char positions on screen (40 char's/line with 25 lines = 1000).

if you are interested in the source code, simple have a look in sub folder "/src".


