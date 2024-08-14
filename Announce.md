Today I announce `MyBroadcast.jl`, a parallel threading framework. I've been
using it for about a year now, and it seems (to me, the utterly unbiased author
:)) to be simpler to use than other threading frameworks. In part, it may
simply exist because I didn't understand how to use other's code.

The key problems this package tries to address are the following:

    * Each iteration needs a buffer to perform some calculation. Once the
      calculation is done, the buffer can be reused for another iteration.
      Tasks running in parallel need their own buffer (obviously, to prevent
      race conditions). Allocating a new buffer for each iteration is too
      costly.

    * The time per iteration changes fairly smoothly as the calculation
      progresses. For example, imagine you want to initialize a matrix of size
      `n x m`, and the time per iteration is proportional to `i^2 j^2`. If,
      say, thread 1 does the iterations with small `i` and `j`, and thread 8
      gets those that are large, then thread 1 will finish long before thread
      8, and a bunch of cores will be idle while they wait for thread 8 to
      finish.

    * Stay responsive to Ctrl-C during long calculations.

This package tries to solve these problems in the following way:

    * Iterations get batched. The number of iterations per batch is determined
      dynamically, starting with one per thread, then increasing it until it
      takes ~0.5 seconds per batch.

Incidental features of my implementation are:

    * Straight-forward Julia code, no new @inventions @with #weird @syntax to
      @!allocate #buffers, etc.

    * The user is responsible for allocating buffers.
