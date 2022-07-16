#!/usr/bin/env julia


module MyMap

using Base.Threads


function calc_i_per_thread(time, i_per_thread_old; batch_avgtime=0.1, batch_maxadjust=2.0)
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


function mymap!(out, fn, arr)
    ntasks = length(arr)

    ifirst = 1
    i_per_thread = Atomic{Int}(1)
    last_ifirst = Atomic{Int}(0)  # doesn't need to be atomic
    lk = Threads.Condition()

    @sync while ifirst <= ntasks
        iset = ifirst:min(ntasks, ifirst + i_per_thread[] - 1)
        idxs = eachindex(arr)[iset]
        #@show ifirst,i_per_thread[]

        @spawn begin
            time = @elapsed out[idxs] .= fn(arr[idxs])

            i_per_thread_new = calc_i_per_thread(time, length(iset))
            lock(lk) do
                if last_ifirst[] < iset[1]
                    i_per_thread[] = i_per_thread_new
                    last_ifirst[] = iset[1]
                end
            end
        end

        ifirst = iset[end] + 1
    end

    return out
end


function mymap(fn, arr)
    Treturn = Base.return_types(fn, (eltype(arr),))[1]
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


function test_work(i::Number)
    #return i + 1.1
    s = 0.0
    for j=1:i^2
        s += log(j*float(i))
    end
    return s
end

function test_work(arr)
    return test_work.(arr)
end


function main()
    A = 1:1000
    test_work.(1:100)
    mymap(test_work, 1:100)
    threadsloop(test_work, 1:100)
    #ThreadsX.map(test_work, 1:100)
    #@time logA0 = test_work.(A)
    @time logA1 = mymap(test_work, A)
    @time logA2 = threadsloop(test_work, A)
    #@show A logA1
    @assert logA1 == logA2
    #@assert logA1 == logA3
    #@assert logA2 == logA0
end


end

MyMap.main()


# vim: set sw=4 et sts=4 :
