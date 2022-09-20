# MyBroadcast.jl

(This used to be called `MyMap.jl`, but as it happens, the `map` interface is
pretty useless for me, and I should really call it `MyBroadcast`. Hence, that
is what it is called. Then again, maybe this is more like a `map`, and I just
clumsily add an interface to make it more like broadcast?)


## Introduction

This module defines the function `mybroadcast`. It behaves similarly to a
threaded broadcast, except that it tries to batch iterations such that each
batch takes about 0.2 seconds to perform.

The idea is to automatically adjust the number of iterations per batch so that
overhead per iteration is low and batch size is small so that the threads keep
getting scheduled.

For example, imagine that you iterate over `i=1:1_000_000` and the execution
time per iteration increases with `i`. With a static scheduler that divides the
tasks up into batches of equal numbers of iterations, this would mean that the
first threads finish long before the last thread. This avoids that by adjusting
the number of iterations so that each batch should take approximately 0.5
seconds.

Why 0.5 seconds? Because we are humans, and 0.5 seconds makes it close enough
to instantaneous. Maybe it should 0.2 seconds. Maybe the overhead should be
measured and folded into the equation. Maybe.

Furthermore, the batching of iterations is advantageous if a buffer needs to be
used for each iteration, and this buffer can be reused for the next iteration,
as long as they don't run at the same time. Allocating a separate buffer for
each iteration would add a lot of overhead, so that traditional `map()` can
take longer than the serial implementation. Batching avoids that pitfall.

An essential part of debugging are error messages. If a thread encounters an
exception, it catches that and passes it on to the main thread. The main thread
then signals all the other threads to stop, and then prints the exception. This
makes reading the error messages fairly nice.


## TODO

- Pass ProgressMeter into mybroadcast(): Some tasks will have extra overhead
  due to `next!()` actually updating the progress bar. We don't really want
  that in the calculation for the time of the task (unless every task ends up
  updating the bar).


## MaybeDo

- Change 2D interface so that `fn(a, b')` works. (Nah, maybe not. Very unclear
  how to decide the next batch area.)
