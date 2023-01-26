

@testset "mybroadcast 1D" begin
    println("mybroadcast 1D")

    function threadsloop(fn, arr)
        Treturn = Base.return_types(fn, (eltype(arr),))[1]
        out = similar(arr, Treturn)
        Threads.@threads for i=1:length(arr)
            out[i] = fn(arr[i])
        end
        return out
    end

    function polyesterloop(fn, arr)
        Treturn = Base.return_types(fn, (eltype(arr),))[1]
        out = similar(arr, Treturn)
        @batch minbatch=50 for i=1:length(arr)
            out[i] = fn(arr[i])
        end
        return out
    end

    function stridedloop(fn, arr)
        Treturn = Base.return_types(fn, (eltype(arr),))[1]
        out = similar(arr, Treturn)
        arrc = collect(arr)
        @strided @. out = fn(arrc)
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

    test_work(arr) = test_work.(arr)

    A = 1:200
    test_work.(1:10)
    mybroadcast(test_work, 1:10)
    threadsloop(test_work, 1:10)
    polyesterloop(test_work, 1:10)
    stridedloop(test_work, 1:10)
    #ThreadsX.broadcast(test_work, 1:10)
    #@time logA0 = test_work.(A)
    println("1D: mybroadcast:")
    @time logA1 = mybroadcast(test_work, A)
    @time logA1 = mybroadcast(test_work, A)
    @time logA1 = mybroadcast(test_work, A)
    println("1D: @threads:")
    @time logA2 = threadsloop(test_work, A)
    @time logA2 = threadsloop(test_work, A)
    @time logA2 = threadsloop(test_work, A)
    println("1D: @batch (Polyester):")
    @time logA3 = polyesterloop(test_work, A)
    @time logA3 = polyesterloop(test_work, A)
    @time logA3 = polyesterloop(test_work, A)
    println("1D: @strided:")
    @time logA4 = stridedloop(test_work, A)
    @time logA4 = stridedloop(test_work, A)
    @time logA4 = stridedloop(test_work, A)
    #@show A logA1
    @test logA1 == logA2
    @test logA1 == logA3
    @test logA1 == logA4
    #@assert logA1 == logA3
    #@assert logA2 == logA0


    A = 1:1500
    prog = Progress(length(A), 0.2, "Test $A: ")
    @time mybroadcast(A) do arr
        out = test_work.(arr)
        next!(prog, step=length(arr), showvalues=[(:batchsize, length(arr))])
        return out
    end
end

