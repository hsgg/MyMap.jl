@doc raw"""
    MyBroadcast

This module defines the function `mybroadcast`. It behave similarly to a
threaded broadcast, except that it tries to batch iterations such that
the overhead resulting from parallelization is small, while also attempting to
fully utilise all threads.

In particular, the goal is to achieve this when the cost of each iteration
varies, or when a buffer is needed for each iteration. The case where the
buffer gets allocated for each iteration must be avoided, as that would stress
the garbage collector to much. Therefore, iterations are batched together.

For example, imagine that the execution time per iteration increases. With a
static scheduler, this would mean that the first threads finish long before the
last thread. `mybroadcast` avoids that by adjusting the number of iterations
per batch so that the overhead is approximately 10%.

Furthermore, `mybroadcast` while attempt to limit the size of each batch so
that the execution time is ~0.5 seconds. That keeps it reacting to inputs (like
Ctrl-C) and wastes at most ~0.5 seconds idle time for one thread at the end.

So why batch iterations? Imagine you need to allocate a buffer for each
iteration, and this buffer can be shared for sequentially run iterations.
Allocating a separate buffer would add a lot of overhead, so that traditional
`map()` can take longer than the serial implementation. Batching avoids that
pitfall.
"""
module MyBroadcast

export mybroadcast

using Base.Threads


include("MeshedArrays.jl")
using .MeshedArrays


function calc_i_per_thread(computetime, totaltime, i_per_thread_old; batch_maxtime=1.0, batch_maxadjust=2.0, overhead_target_fraction=0.1)

    overhead = 1 - computetime / totaltime

    adjust = overhead / overhead_target_fraction
    adjust = min(adjust, batch_maxtime / totaltime)  # limit batch time
    adjust = min(adjust, batch_maxadjust)  # limit upward adjustment
    adjust = max(adjust, 1/batch_maxadjust)  # limit downward adjustment

    if adjust < 1
        i_per_thread_new = floor(Int, adjust * i_per_thread_old)
    else
        i_per_thread_new = ceil(Int, adjust * i_per_thread_old)
    end

    return max(1, i_per_thread_new)  # must be at least 1
end


function calc_outsize(x...)
    outsize = fill(1, maximum(ndims.(x)))
    outsize[1:ndims(x[1])] .= size(x[1])
    for i=2:length(x)
        for d=1:ndims(x[i])
            if outsize[d] == 1
                outsize[d] = size(x[i], d)
            elseif size(x[i], d) != 1 && outsize[d] != size(x[i], d)
                error("cannot find common broadcast dimensions size.(x) = $(size.(x))")
            end
        end
    end
    return (outsize...,)
end


function get_new_batch!(nextifirstchannel, ntasks, batchsize)
    ifirst = take!(nextifirstchannel)
    ilast = min(ntasks, ifirst + batchsize - 1)
    put!(nextifirstchannel, ilast + 1)
    iset = ifirst:ilast
    return iset
end


function mybroadcast!(out, fn, x...)
    ntasks = prod(calc_outsize(x...))
    @assert size(out) == calc_outsize(x...)

    num_threads = Threads.nthreads()

    errorchannel = Channel{Any}(num_threads)

    nextifirstchannel = Channel{Int}(1)  # this channel is used to synchronize all the threads
    put!(nextifirstchannel, 1)

    all_indices = eachindex(out, x...)

    # worker threads process the data
    @threads for _ in 1:num_threads
        mytime_a = time_ns()
        try
            batchsize = 1

            iset = get_new_batch!(nextifirstchannel, ntasks, batchsize)

            while length(iset) > 0

                idxs = all_indices[iset]

                xs = (x[i][idxs] for i=1:length(x))

                computetime = @elapsed outs = fn(xs...)

                out[idxs] .= outs

                mytime_b = time_ns()
                mytottime = (mytime_b - mytime_a) ./ 1e9
                mytime_a = mytime_b

                batchsize = calc_i_per_thread(computetime, mytottime, length(iset))

                iset = get_new_batch!(nextifirstchannel, ntasks, batchsize)
            end
        catch e
            if e isa InvalidStateException
                @info "Exiting thread $(Threads.threadid()) due to closed channel"
            else
                # we caused the exception
                close(nextifirstchannel)  # notify other threads
                bt = catch_backtrace()
                @warn "Exception in thread $(Threads.threadid()):\n  $e"
                put!(errorchannel, (Threads.threadid(), e, bt))
            end
        end
    end


    num_failed_tasks = 0
    while isready(errorchannel)
        num_failed_tasks += 1
        tid, e, stack = take!(errorchannel)
        println(stdout)
        @error "Exception in thread $tid of $num_threads:\n  $e"
        showerror(stdout, e, stack)
        println(stdout)
    end
    if num_failed_tasks > 0
        println(stdout)
        @error "Exceptions in threads" num_failed_tasks num_threads
        error("Exceptions in threads")
    end

    return out
end


function mybroadcast(fn, x...)
    Treturn = eltype(Base.return_types(fn, (eltype.(x)...,))[1])

    outsize = calc_outsize(x...)
    #@show outsize, size.(x)
    xs = [y for y in x]
    for i=1:length(xs)
        if size(xs[i]) != outsize
            xs[i] = MeshedArray(outsize, xs[i])
        end
    end
    #@show outsize, size.(xs)

    out = Array{Treturn}(undef, outsize...)

    mybroadcast!(out, fn, xs...)

    return out
end


end


# vim: set sw=4 et sts=4 :
