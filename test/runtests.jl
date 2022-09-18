using MyBroadcast
using Test
using Random
using BenchmarkTools
using Profile, FlameGraphs, ProfileView
using Polyester
using ThreadsX
using Strided
using LazyGrids
using ProgressMeter

do_perf = false

@testset "MyBroadcast.jl" begin

    @testset "MeshedArrays.jl" begin
        println("MA: first index")
        totsize = (5,3)
        x = 1:5
        mx = MyBroadcast.MeshedArray(totsize, x)
        @test length(mx) == prod(totsize)

        lx = LazyGrids.GridOT(Int, totsize, 1)
        @show mx lx
        @test mx == lx
        @test mx[1:end] == lx[1:end]

        test_access(mx2) = mx2[1]

        test_access(mx)
        @time test_access(mx)
        @btime $test_access($mx)
        @time test_access(mx)
        @time test_access(mx)

        for i=1:length(mx)
            @debug i,mx[i]
            @test mx[i] == (i - 1) % 5 + 1
        end

        println("MA: second index")
        totsize = (5,3)
        x = 1:3
        mx = MyBroadcast.MeshedArray(totsize, x')
        @test length(mx) == prod(totsize)
        for i=1:length(mx)
            @debug i,mx[i]
            @test mx[i] == (i - 1) ÷ 5 + 1
        end
        lx = LazyGrids.GridOT(Int, totsize, 2)
        @show mx lx
        @test mx == lx
        @test mx[1:end] == lx[1:end]

        println("MA: error first index")
        totsize = (5,3)
        x = 1:3
        @test_throws Exception MyBroadcast.MeshedArray(totsize, x)

        println("MA: error second index")
        totsize = (5,3)
        x = 1:5
        @test_throws Exception MyBroadcast.MeshedArray(totsize, x')

        println("MA: broadcast access first index")
        totsize = (5,3)
        x = 21:25
        mx = MyBroadcast.MeshedArray(totsize, x)
        @debug mx[3:6]
        @test mx[3:6] == [23, 24, 25, 21]

        println("MA: broadcast access second index")
        totsize = (5,3)
        x = 21:23
        mx = MyBroadcast.MeshedArray(totsize, x')
        @debug mx[3:6]
        @test mx[3:6] == [21, 21, 21, 22]

        if do_perf
            println("MA: broadcast access performance")
            y = 1:10100
            #totsize = (length(y), 10000)
            totsize = (10000, length(y))
            my = MyBroadcast.MeshedArray(totsize, y')
            #my = rand(1:10100, totsize...)
            dotest() = begin
                Random.seed!(1234567890)
                Base.GC.gc()
                @time for i=1:10
                    a,b = rand(1:length(my), 2)
                    idxs = a:b
                    my[idxs]
                end
            end
            dotest()
            dotest()
            dotest()
            @profview dotest()
            ProfileView.closeall()
            @profview dotest()
            ProfileView.closeall()
            @profview dotest()
        end
    end


    @testset "calc_outsize()" begin
        A = 1:10000
        B = 11:1500

        @test MyBroadcast.calc_outsize(A) == (length(A),)

        @test MyBroadcast.calc_outsize(A, A) == (length(A),)
        @test_throws Exception MyBroadcast.calc_outsize(A, B)
        @test_throws Exception MyBroadcast.calc_outsize(A', B')
        @test MyBroadcast.calc_outsize(A, B') == (length(A), length(B))
        @test MyBroadcast.calc_outsize(A', B) == (length(B), length(A))
        @test MyBroadcast.calc_outsize(A', A') == (1, length(A))

        @test MyBroadcast.calc_outsize(A, A, A) == (length(A),)
        @test MyBroadcast.calc_outsize(A, A, B') == (length(A), length(B))
        @test MyBroadcast.calc_outsize(A, B', A) == (length(A), length(B))
        @test MyBroadcast.calc_outsize(B', A, A) == (length(A), length(B))
        @test MyBroadcast.calc_outsize(B', B', B') == (1, length(B))
    end


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


    @testset "mybroadcast 2D" begin

        function test_work!(i::Number, j::Number, buffer)
            #len = length(buffer)
            #@. buffer = (1:len) * i / j
            #return sum(buffer)

            buffer .= 1.0
            return buffer[5]

            #for m=1:length(buffer)
            #    for n=1:(i*j)
            #        buffer[m] = i * j / (m * n)
            #    end
            #end
            #return buffer[1]
        end

        function test_work(i::Number, j::Number)
            buffer = Array{Float64}(undef, 100)  # an allocation every iteration
            return test_work!(i, j, buffer)
        end

        function test_work(x, y)
            buffer = Array{Float64}(undef, 100)  # allocation is done only once per batch
            return test_work!.(x, y, Ref(buffer))
        end

        function do_2d_test(a, b)
            @show size(a),size(b)
            Base.GC.gc()
            @time r0 = test_work!.(a, b, Ref(fill(0.0,100)))
            Base.GC.gc()
            @time r1 = mybroadcast(test_work, a, b)
            Base.GC.gc()
            @debug r1
            @test size(r1) == size(r0)
            @test r0 == r1
        end

        println()
        println("2d: small test")
        a = 1:5
        b = 1:3
        do_2d_test(a, a)
        do_2d_test(a, b')
        do_2d_test(a', b)
        do_2d_test(a', a')

        A = 1:10000
        B = 11:15000

        Af = A .* ones(length(B))'
        Bf = ones(length(A)) .* B'

        outsize = MyBroadcast.calc_outsize(A, B')
        Am = MyBroadcast.MeshedArray(outsize, A)
        Bm = MyBroadcast.MeshedArray(outsize, B')

        println()
        println("2d: simple test")
        do_2d_test(A, A)
        do_2d_test(A, B')
        do_2d_test(A', B)
        do_2d_test(A', A')

        println()
        println("full 2D")
        println("Single threaded broadcast:")
        Base.GC.gc()
        @time r0 = test_work!.(Af, Bf, Ref(fill(0.0,100)))
        Base.GC.gc()
        @time r0 = test_work!.(Af, Bf, Ref(fill(0.0,100)))
        Base.GC.gc()
        @time r0 = test_work!.(Af, Bf, Ref(fill(0.0,100)))

        println()
        println("Single threaded broadcast with MeshedArrays:")
        Base.GC.gc()
        @time r0 = test_work!.(Am, Bm, Ref(fill(0.0,100)))
        Base.GC.gc()
        @time r0 = test_work!.(Am, Bm, Ref(fill(0.0,100)))
        Base.GC.gc()
        @time r0 = test_work!.(Am, Bm, Ref(fill(0.0,100)))

        println()
        println("mybroadcast 2d full index arrays:")
        Base.GC.gc()
        @time r1 = mybroadcast(test_work, Af, Bf)
        Base.GC.gc()
        @time r1 = mybroadcast(test_work, Af, Bf)
        Base.GC.gc()
        @time r1 = mybroadcast(test_work, Af, Bf)

        println()
        println("mybroadcast 2D:")
        Base.GC.gc()
        @time r2 = mybroadcast(test_work, A, B')
        Base.GC.gc()
        @time r2 = mybroadcast(test_work, A, B')
        Base.GC.gc()
        @time r2 = mybroadcast(test_work, A, B')

        println()
        println("mybroadcast 2d inverse:")
        Base.GC.gc()
        @time r3 = mybroadcast(test_work, A', B)
        Base.GC.gc()
        @time r3 = mybroadcast(test_work, A', B)
        Base.GC.gc()
        @time r3 = mybroadcast(test_work, A', B)

        println()
        println("mybroadcast 2d with LazyGrids:")
        Al, Bl = ndgrid(A, B)
        Base.GC.gc()
        @time r4 = mybroadcast(test_work, Al, Bl)
        Base.GC.gc()
        @time r4 = mybroadcast(test_work, Al, Bl)
        Base.GC.gc()
        @time r4 = mybroadcast(test_work, Al, Bl)

        println()
        println("strided with full arrays:")
        Ac = collect(A)
        Bc = collect(B')
        Base.GC.gc()
        @time r5 = @strided test_work.(Ac, Bc)
        Base.GC.gc()
        @time r5 = @strided test_work.(Ac, Bc)
        Base.GC.gc()
        @time r5 = @strided test_work.(Ac, Bc)
        println()

        println("MeshedArrays with ThreadsX map:")
        outsize = MyBroadcast.calc_outsize(A, B')
        Am = MyBroadcast.MeshedArray(outsize, A)
        Bm = MyBroadcast.MeshedArray(outsize, B')
        Base.GC.gc()
        @time r6 = ThreadsX.map(test_work, Am, Bm)
        Base.GC.gc()
        @time r6 = ThreadsX.map(test_work, Am, Bm)
        Base.GC.gc()
        @time r6 = ThreadsX.map(test_work, Am, Bm)
        println()

        println("LazyGrids with ThreadsX map:")
        ALG, BLG = ndgrid(A, B)  # LazyGrids
        Base.GC.gc()
        @time r7 = ThreadsX.map(test_work, ALG, BLG)
        Base.GC.gc()
        @time r7 = ThreadsX.map(test_work, ALG, BLG)
        Base.GC.gc()
        @time r7 = ThreadsX.map(test_work, ALG, BLG)

        println()
        # strided?
        @test r0 ≈ r1  rtol=eps(1.0)
        @test r0 ≈ r2  rtol=eps(1.0)
        @test r0 ≈ r3'  rtol=eps(1.0)
        @test r0 ≈ r4  rtol=eps(1.0)
        @test r0 ≈ r5  rtol=eps(1.0)
        @test r0 ≈ r6  rtol=eps(1.0)
        @test r0 ≈ r7  rtol=eps(1.0)

        if do_perf
            println("do perf")
            Base.GC.gc()
            @time @profview r2 = mybroadcast(test_work, A, B')
            ProfileView.closeall()
            Base.GC.gc()
            @time @profview r2 = mybroadcast(test_work, A, B')
            ProfileView.closeall()
            Base.GC.gc()
            @time @profview r2 = mybroadcast(test_work, A, B')
        end
    end


    @testset "Thread distribution" begin

        function test_work!(i::Number, j::Number, buffer)
            for m=1:length(buffer)
                for n=1:(i*j)
                    buffer[m] = i * j / (m * n)
                end
            end
            return sum(buffer)
        end

        function test_work(i::Number, j::Number)
            buffer = Array{Float64}(undef, 100)  # an allocation every iteration
            return test_work!(i, j, buffer)
        end

        function test_work(x, y)
            buffer = Array{Float64}(undef, 100)  # allocation is done only once per batch
            return test_work!.(x, y, Ref(buffer))
        end

        num_batches = fill(0, Threads.nthreads())
        num_tasks_per_batch = fill(0.0, Threads.nthreads())

        A = 1:100
        B = 11:1500

        mybroadcast(A, B') do ii, jj
            tid = Threads.threadid()
            num_batches[tid] += 1
            num_tasks_per_batch[tid] += length(ii)
            test_work(ii, jj)
        end
        num_tasks_per_batch ./= num_batches
        num_tasks_per_batch = round.(num_tasks_per_batch, digits=1)
        @show num_batches
        @show num_tasks_per_batch
        @show sum(num_batches)
        println()
    end


    if do_perf
        Base.prompt("Finish? ")
    end
end
