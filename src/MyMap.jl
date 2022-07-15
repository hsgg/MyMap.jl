#!/usr/bin/env julia


module MyMap

using Base.Threads


function calc_i_per_thread(time, i_per_thread_old; batch_avgtime=1.0, batch_maxadjust=100.0)
    adjust = batch_avgtime / time  # if we have accurate measurement of time
    adjust = min(batch_maxadjust, adjust)  # limit upward adjustment
    adjust = max(1/batch_maxadjust, adjust)  # limit downward adjustment

    i_per_thread_new = floor(Int, adjust * i_per_thread_old)
    i_per_thread_new = max(1, i_per_thread_new)  # must be at least 1

    return i_per_thread_new
end


function mymap!(out, fn, arr; batch_avgtime=1.0, batch_maxadjust=10.0)
    nconcurrent_tasks = Threads.nthreads()
    ntasks = length(arr)
    #@show ntasks nconcurrent_tasks

    ifirst = 1
    i_per_thread = Atomic{Int}(1)

    @sync while ifirst <= ntasks
        iset = ifirst:min(ntasks, ifirst + i_per_thread[] - 1)
        #@show ifirst,i_per_thread_now

        @spawn begin
            time = @elapsed for i in iset
                out[i] = fn(arr[i])
            end

            i_per_thread[] = calc_i_per_thread(time[], length(iset); batch_avgtime, batch_maxadjust)
        end

        ifirst = iset[end] + 1
    end

    return out
end


function mymap(fn, arr)
    Treturn = Base.return_types(fn, (eltype(arr),))[1]
    #@show Treturn
    out = similar(arr, Treturn)
    mymap!(out, fn, arr)
    return out
end


function threadsloop(fn, arr)
    Treturn = Base.return_types(fn, (eltype(arr),))[1]
    out = similar(arr, Treturn)
    @threads for i=1:length(arr)
        out[i] = fn(arr[i])
    end
    return out
end


function test_work(i)
    s = 0.0
    for j=1:i
        s += log(j*i)
    end
    return s
end


function main()
    A = 1:10000
    logA0 = test_work.(1:100)
    #@time logA0 = test_work.(A)
    logA1 = mymap(test_work, 1:100)
    @time logA1 = mymap(test_work, A)
    logA2 = threadsloop(test_work, 1:100)
    @time logA2 = threadsloop(test_work, A)
    #@show A logA1
    @assert logA1 == logA2
    #@assert logA2 == logA0
end


end

MyMap.main()


# vim: set sw=4 et sts=4 :
