#!/usr/bin/env julia


module MyMap

using Base.Threads

function mymap!(out, fn, arr)
    nconcurrent_tasks = Threads.nthreads()
    ntasks = length(arr)
    @show ntasks nconcurrent_tasks

    @sync for i=1:ntasks
        @spawn out[i] = fn(arr[i])
    end

    return out
end


function mymap(fn, arr)
    Treturn = Base.return_types(fn, (eltype(arr),))[1]
    @show Treturn
    out = similar(arr, Treturn)
    mymap!(out, fn, arr)
    return out
end


function main()
    A = 1:100000
    @time logA = mymap(log, A)
    @time logA = mymap(log, A)
    @time logA = mymap(log, A)
    #@show A logA
    @assert logA == log.(A)
end


end

MyMap.main()


# vim: set sw=4 et sts=4 :
