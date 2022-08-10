# MyBroadcast.jl

(This used to be called `MyMap.jl`, but as it happens, the `map` interface is
pretty useless for me, and I should really call it `MyBroadcast`. Hence, that
is what it is called.)


## TODO

- Clean up the tasks (by `fetch`ing them).

- Pass ProgressMeter into mybroadcast(): Some tasks will have extra overhead
  due to `next!()` actually updating the progress bar. We don't really want
  that in the calculation for the time of the task (unless every task ends up
  updating the bar).


## MaybeDo

- Change 2D interface so that `fn(a, b')` works. (Nah, maybe not. Very unclear
  how to decide the next batch area.)
