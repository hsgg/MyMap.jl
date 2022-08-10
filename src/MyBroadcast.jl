@doc raw"""
    MyBroadcast

This module defines the function `mybroadcast`. It behave similarly to a
threaded broadcast, except that it tries to batch iterations such that each
batch takes about 0.2 seconds to perform.

The idea is to automatically adjust the number of iterations per batch so that
overhead per iteration is low and batch size is small so that the threads keep
getting scheduled.

For example, imagine that the execution time per iteration increases. With a
static scheduler, this would mean that the first threads finish long before the
last thread. This avoids that by adjusting the number of iterations so that
each batch should take approximately 0.2 seconds.
"""
module MyBroadcast

export mybroadcast

using Base.Threads


include("MeshedArrays.jl")
using .MeshedArrays
#using LazyGrids


function calc_i_per_thread(time, i_per_thread_old; batch_avgtime=0.2, batch_maxadjust=2.0)
    adjust = batch_avgtime / time  # if we have accurate measurement of time
    adjust = min(batch_maxadjust, adjust)  # limit upward adjustment
    adjust = max(1/batch_maxadjust, adjust)  # limit downward adjustment

    if adjust < 1
        i_per_thread_new = floor(Int, adjust * i_per_thread_old)
    else
        i_per_thread_new = ceil(Int, adjust * i_per_thread_old)
    end
    i_per_thread_new = max(1, i_per_thread_new)  # must be at least 1

    return i_per_thread_new
end


function mybroadcast!(out, fn, arr)
    ntasks = length(arr)

    ifirst = 1
    i_per_thread = Atomic{Int}(1)
    last_ifirst = 0
    lk = Threads.Condition()

    num_free_threads = Atomic{Int}(Threads.nthreads())
    @assert num_free_threads[] > 0

    @sync while ifirst <= ntasks
        while num_free_threads[] < 1
            yield()
        end
        num_free_threads[] -= 1

        iset = ifirst:min(ntasks, ifirst + i_per_thread[] - 1)
        #@show ifirst,i_per_thread[]

        @spawn begin
            time = @elapsed begin
                idxs = eachindex(out, arr)[iset]
                out[idxs] .= fn(arr[idxs])
            end

            i_per_thread_new = calc_i_per_thread(time, length(iset))
            lock(lk) do
                if last_ifirst < iset[1]
                    i_per_thread[] = i_per_thread_new
                    last_ifirst = iset[1]
                end
            end
            num_free_threads[] += 1
        end

        ifirst = iset[end] + 1
        yield()  # let some threads finish so that i_per_thread[] gets updated asap
    end

    return out
end


function mybroadcast(fn, arr)
    Treturn = eltype(Base.return_types(fn, (eltype(arr),))[1])
    out = similar(arr, Treturn)
    mybroadcast!(out, fn, arr)
    return out
end


function calc_outsize(x, y)
    outsize = fill(1, max(ndims(x), ndims(y)))
    outsize[1:ndims(x)] .= size(x)
    for d=1:ndims(y)
        if outsize[d] == 1
            outsize[d] = size(y, d)
        elseif size(y, d) != 1 && outsize[d] != size(y, d)
            error("size(x) = $(size(x)) and size(y) = $(size(y)) cannot be broadcast")
        end
    end
    return (outsize...,)
end


function mybroadcast!(out, fn, x, y)
    ntasks = prod(calc_outsize(x, y))
    @assert size(out) == calc_outsize(x, y)

    ifirst = 1
    i_per_thread = Atomic{Int}(1)
    last_ifirst = 0
    lk = Threads.Condition()

    num_free_threads = Atomic{Int}(Threads.nthreads())
    @assert num_free_threads[] > 0

    all_indices = eachindex(out, x, y)

    @sync while ifirst <= ntasks
        while num_free_threads[] < 1
            # Don't spawn the next batch until a thread is free. This has
            # several implications. First, Ctrl-C actually works (seems like
            # threadid=1 is the one catching the signal, and no tasks are
            # waiting on the other threads so they actually finish instead of
            # continuing in the background). Second, printing and ProgressMeter
            # actually work. Why? Not sure. Maybe because printing uses locks
            # and yields()? Maybe tasks need to be cleaned up?
            yield()
        end
        num_free_threads[] -= 1

        ilast = min(ntasks, ifirst + i_per_thread[] - 1)
        iset = ifirst:ilast  # no need to interpolate local variables

        Threads.@spawn begin
            t0 = time_ns()

            idxs = all_indices[iset]
            xs = x[idxs]
            ys = y[idxs]
            outs = fn(xs, ys)
            out[idxs] .= outs

            time = (time_ns() - t0) / 1e9

            i_per_thread_new = calc_i_per_thread(time, length(iset))
            lock(lk) do
                if last_ifirst < iset[1]
                    i_per_thread[] = i_per_thread_new
                    last_ifirst = iset[1]
                end
            end
            num_free_threads[] += 1
        end

        ifirst = ilast + 1
        yield()  # let some threads finish so that i_per_thread[] gets updated asap
    end

    return out
end


function mybroadcast(fn, x, y)
    Treturn = eltype(Base.return_types(fn, (eltype(x), eltype(y)))[1])

    outsize = calc_outsize(x, y)
    #@show outsize, size(x), size(y)
    if size(x) != outsize
        #d = findfirst(size(x) .> 1)
        #x = LazyGrids.GridAR(outsize, x, d)
        #@show outsize d
        x = MeshedArray(outsize, x)
        #@assert x == x0
    end
    if size(y) != outsize
        #d = findfirst(size(y) .> 1)
        #y = LazyGrids.GridAR(outsize, y, d)
        #@show outsize d
        y = MeshedArray(outsize, y)
        #@assert y == y0
    end
    #@show outsize, size(x), size(y)

    out = Array{Treturn}(undef, outsize...)

    mybroadcast!(out, fn, x, y)

    return out
end


end


# vim: set sw=4 et sts=4 :
