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
        #@show ifirst,i_per_thread[]

        @spawn begin
            time = @elapsed begin
                idxs = eachindex(out, arr)[iset]
                out[idxs] .= fn(arr[idxs])
            end

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


struct MeshedArray{T,N,Tarr,Tsz} <: AbstractArray{T,N}
    totsize::Tsz
    x::Tarr
end
MeshedArray(sz, x) = begin
    for n=1:ndims(x)
        if size(x,n) != 1
            if size(x,n) != sz[n]
                error("dimension $n in 'x' $(size(x)) must match 'sz' $sz or be 1")
            end
        end
    end
    return MeshedArray{eltype(x), length(sz), typeof(x), typeof(sz)}(sz, x)
end
Base.ndims(a::MeshedArray{T,N}) where {T, N <: Integer} = N
Base.size(a::MeshedArray) = a.totsize
Base.length(a::MeshedArray) = prod(size(a))
Base.getindex(a::MeshedArray, i::Int) = begin
    iout = 0
    szx = 1
    for n=1:ndims(a.x)
        d = ((i - 1) % size(a, n)) + 1
        i = ((i - 1) ÷ size(a, n)) + 1
        if size(a.x, n) != 1
            iout += szx * (d - 1)
        end
        szx *= size(a.x, n)
    end
    return a.x[iout+1]
end
Base.getindex(a::MeshedArray{T,N}, I::Vararg{Int,N}) where {T,N} = begin
    iout = 0
    szx = 1
    for n=1:ndims(a.x)
        @assert I[n] <= size(a, n)
        if size(a.x, n) != 1
            d = I[n]
            iout += szx * (d - 1)
        end
        szx *= size(a.x, n)
    end
    for n=ndims(a.x)+1:ndims(a)
        @assert I[n] <= size(a, n)
    end
    return a.x[iout+1]
end

function test_meshedarray()
    println("first index")
    totsize = (5,3)
    x = 1:5
    mx = MeshedArray(totsize, x)
    @assert length(mx) == prod(totsize)
    for i=1:length(mx)
        @show i,mx[i]
        @assert mx[i] == (i - 1) % 5 + 1
    end

    println("second index")
    totsize = (5,3)
    x = 1:3
    mx = MeshedArray(totsize, x')
    @assert length(mx) == prod(totsize)
    for i=1:length(mx)
        @show i,mx[i]
        @assert mx[i] == (i - 1) ÷ 5 + 1
    end

    #println("error first index")
    #totsize = (5,3)
    #x = 1:3
    #mx = MeshedArray(totsize, x)

    #println("error second index")
    #totsize = (5,3)
    #x = 1:5
    #mx = MeshedArray(totsize, x')

    println("broadcast access first index")
    totsize = (5,3)
    x = 21:25
    mx = MeshedArray(totsize, x)
    @show mx[3:6]
    @assert mx[3:6] == [23, 24, 25, 21]

    println("broadcast access second index")
    totsize = (5,3)
    x = 21:23
    mx = MeshedArray(totsize, x')
    @show mx[3:6]
    @assert mx[3:6] == [21, 21, 21, 22]
end


function mymap2d!(out, fn, x, y)
    ntasks = prod(calc_outsize(x, y))
    @assert size(out) == calc_outsize(x, y)

    ifirst = 1
    i_per_thread = Atomic{Int}(1)
    last_ifirst = Atomic{Int}(0)  # doesn't need to be atomic
    lk = Threads.Condition()

    @sync while ifirst <= ntasks
        iset = ifirst:min(ntasks, ifirst + i_per_thread[] - 1)
        #@show ifirst,i_per_thread[]

        @spawn begin
            time = @elapsed begin
                idxs = eachindex(out, x, y)[iset]
                out[idxs] .= fn(x[idxs], y[idxs])
            end

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


function mymap2d(fn, x, y)
    Treturn = Base.return_types(fn, (eltype(x), eltype(y)))[1]
    outsize = calc_outsize(x, y)
    @show outsize
    out = Array{Treturn}(undef, outsize...)
    mymap2d!(out, fn, x, y)
    return out
end


############### test 2d

function test_work(i::Number, j::Number)
    return log(j) + log(i)
end

function test_work(x, y)
    return test_work.(x, y)
end


function main2d()
    A = 1:10
    B = 11:15
    @assert calc_outsize(A, A) == (10,)
    #@assert calc_outsize(A, B) == (10,)  # should throw error
    @assert calc_outsize(A, B') == (10, 5)
    @assert calc_outsize(A', B) == (5, 10)

    r0 = test_work.(A, A)
    r1 = mymap2d(test_work, A, A)
    @show r0
    @assert r0 == r1

    r0 = test_work.(A .* ones(10)', ones(10).*A')
    r1 = mymap2d(test_work, A .* ones(10)', ones(10).*A')
    @show r0
    @assert r0 == r1

    r0 = test_work.(A, A')
    r1 = mymap2d(test_work, A, A')
    @show r0
    @assert r0 == r1
end



############### test 1d

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

#MyMap.main()
#MyMap.main2d()
MyMap.test_meshedarray()


# vim: set sw=4 et sts=4 :
