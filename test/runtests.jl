using MyBroadcast
using Test
using Random
using BenchmarkTools
using Profile, FlameGraphs, ProfileView
using Polyester
using Strided

do_perf = false

@testset "MyBroadcast.jl" begin

    @testset "MeshedArrays.jl" begin
        println("MA: first index")
        totsize = (5,3)
        x = 1:5
        mx = MyBroadcast.MeshedArray(totsize, x)
        @test length(mx) == prod(totsize)

        test_access(mx2) = mx2[1]

        test_access(mx)
        @time test_access(mx)
        @btime $test_access($mx)
        @time test_access(mx)
        @time test_access(mx)
        #return

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
    end


    @testset "mybroadcast2d" begin

        function test_work(i::Number, j::Number)
            #return 1.0
            return log(j) + log(i)
        end

        function test_work(x, y)
            return test_work.(x, y)
            #@time out = Array{Float64}(undef, length(x))
            #@time for i=1:length(x)
            #    println()
            #    @time myx = x[i]
            #    @time myy = y[i]
            #    @time test_work(myx, myy)
            #    #@time out[i] = z
            #    @time out[i] = test_work(x[i], y[i])
            #end
            #return out
        end

        function do_2d_test(a, b)
            @show size(a),size(b)
            Base.GC.gc()
            @time r0 = test_work.(a, b)
            Base.GC.gc()
            @time r1 = mybroadcast2d(test_work, a, b)
            Base.GC.gc()
	    ac = collect(a)
	    bc = collect(b)
            @time r2 = @strided @. test_work(ac, bc)
            @debug r1
            @test size(r1) == size(r0)
            @test size(r2) == size(r0)
            @test r0 == r1
            @test r0 == r2
        end

        A = 1:10000
        B = 11:1500
        @test MyBroadcast.calc_outsize(A, A) == (length(A),)
        @test_throws Exception MyBroadcast.calc_outsize(A, B)
        @test_throws Exception MyBroadcast.calc_outsize(A', B')
        @test MyBroadcast.calc_outsize(A, B') == (length(A), length(B))
        @test MyBroadcast.calc_outsize(A', B) == (length(B), length(A))

        println("2d: simple test")
        do_2d_test(A, A)
        do_2d_test(A, B')
        do_2d_test(A', B)
        do_2d_test(A', A')

        println("full 2D")
        Base.GC.gc()
        @time r0 = test_work(A .* ones(length(B))', ones(length(A)).*B')
        Base.GC.gc()
        @time r0 = test_work(A .* ones(length(B))', ones(length(A)).*B')
        Base.GC.gc()
        @time r0 = test_work(A .* ones(length(B))', ones(length(A)).*B')
        Base.GC.gc()
        @time r1 = mybroadcast2d(test_work, A .* ones(length(B))', ones(length(A)).*B')
        Base.GC.gc()
        @time r1 = mybroadcast2d(test_work, A .* ones(length(B))', ones(length(A)).*B')
        Base.GC.gc()
        @time r1 = mybroadcast2d(test_work, A .* ones(length(B))', ones(length(A)).*B')
        Base.GC.gc()
        @time r2 = mybroadcast2d(test_work, A, B')
        Base.GC.gc()
        @time r2 = mybroadcast2d(test_work, A, B')
        Base.GC.gc()
        @time r2 = mybroadcast2d(test_work, A, B')
        Base.GC.gc()
        @time r3 = mybroadcast2d(test_work, A', B)
        Base.GC.gc()
        @time r3 = mybroadcast2d(test_work, A', B)
        Base.GC.gc()
        @time r3 = mybroadcast2d(test_work, A', B)
	@time Ac = collect(A)
	@time Ac = collect(A)
	@time Ac = collect(A)
	@time Bc = collect(B')
	@time Bc = collect(B')
	@time Bc = collect(B')
        Base.GC.gc()
        @time r4 = @strided @. test_work(Ac, Bc)
        Base.GC.gc()
        @time r4 = @strided @. test_work(Ac, Bc)
        Base.GC.gc()
        @time r4 = @strided @. test_work(Ac, Bc)
        @test r0 == r1
        @test r0 == r2
        @test r0 == r3'
        @test r0 == r4

        if do_perf
            println("do perf")
            Base.GC.gc()
            @profview @time r2 = mybroadcast2d(test_work, A, B')
            ProfileView.closeall()
            Base.GC.gc()
            @profview @time r2 = mybroadcast2d(test_work, A, B')
            ProfileView.closeall()
            Base.GC.gc()
            @profview @time r2 = mybroadcast2d(test_work, A, B')
        end
    end

    if do_perf
        Base.prompt("Finish? ")
    end
end
