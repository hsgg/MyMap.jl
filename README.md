# MyBroadcast.jl

(This used to be called `MyMap.jl`, but as it happens, the `map` interface is
pretty useless for me, and I should really call it `MyBroadcast`. Hence, that
is what it is called. Then again, maybe this is more like a `map`, and I just
clumsily add an interface to make it more like broadcast? Hm...🤔)


## Introduction

This module defines the function `mybroadcast()`. It behaves similarly to a
threaded broadcast, except that it tries to batch iterations such that each
batch takes about 0.2 seconds to perform.

It tries to solve problems related to the following:

1. Each iteration systematically takes a different amount of time.

2. Each iteration needs a buffer allocated. However, that buffer might be
   reused in another iteration.

3. Remain responsive, e.g., Ctrl-C should interrupt a long calculation.

4. Give readable error messages.

The idea is to automatically adjust the number of iterations per batch so that
overhead per iteration is low and batch size is small so that the threads keep
getting scheduled.

For example, imagine that you iterate over `i=1:1000_000` and the execution
time per iteration increases with `i`. With a scheduler that divides the tasks
up into batches of equal numbers of iterations, this would mean that the first
threads finish long before the last thread. MyBroadcast avoids that by
adjusting the number of iterations so that each batch should take approximately
0.5 seconds.

Furthermore, the batching of iterations is advantageous if a buffer needs to be
used for each iteration, and this buffer can be reused for the next iteration,
as long as they don't run at the same time. Allocating a separate buffer for
each iteration would add a lot of overhead, so that traditional `map()` can
take longer than the serial implementation. Batching avoids that pitfall.

Why 0.5 seconds? Because we are humans, and 0.5 seconds makes it close enough
to instantaneous. Maybe it should be 0.2 seconds. Maybe it is 0.2 seconds. How
should I know? I switched so many times, I forgot. Maybe the overhead should be
measured and folded into the equation. Yes, maybe.

An essential part of debugging are error messages. If a thread encounters an
exception, it catches that and signals all other threads. The main thread
prints the exception. This makes reading the error messages quite bearable.


## Usage

This is how you would create an N x M matrix:
```julia
using MyBroadcast

N = 1000
M = 2000

matrix = mybroadcast(1:N, (1:M)') do nn,mm
    batchsize = length(nn)
    out = Array{Float64}(undef, batchsize)

    for i = 1:length(nn)
        n = nn[i]
	m = mm[i]
	out[i] = n + m  # super fancy math
    end

    return out
end

matrix[4,5] == 4 + 5  # Whoa!
```

By default the number of threads is `Threads.nthreads()`. I mean, that's the
number of threads there are, why not use them? If you still want to use a
different number of threads, you can pass the `num_threads` keyword argument.


## Anticipated FAQ

1. Why didn't you use... instead?
Probably because I didn't understand how to use it properly. That is, in a way
that it wouldn'd be slower than the serial implementation.

2. Why implement MeshedArrays when there is LazyGrids?
Because I didn't know LazyGrids existed when I wrote MeshedArrays... and then
it turned out MeshedArrays is faster.


## Unanticipated FAQ

None!


## Todo

- Pass ProgressMeter into mybroadcast(): Some tasks will have extra overhead
  due to `next!()` actually updating the progress bar. We don't really want
  that in the calculation for the time of the task (unless every task ends up
  updating the bar).


## MaybeDo

- Change 2D interface so that `fn(a, b')` works. (Nah, maybe not. Very unclear
  how to decide the next batch area.)
