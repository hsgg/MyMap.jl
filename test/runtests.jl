using MyMap
using Test
using BenchmarkTools

@testset "MyMap.jl" begin

    @testset "MeshedArrays.jl" begin
        println("MA: first index")
        totsize = (5,3)
        x = 1:5
        mx = MyMap.MeshedArray(totsize, x)
        @test length(mx) == prod(totsize)

        test_access(mx) = mx[1]

        println()
        @time test_access(mx)
        @btime $test_access($mx)
        println()
        @time test_access(mx)
        println()
        #@time test_access(mx)
        #return

        for i=1:length(mx)
            @debug i,mx[i]
            @test mx[i] == (i - 1) % 5 + 1
        end

        println("MA: second index")
        totsize = (5,3)
        x = 1:3
        mx = MyMap.MeshedArray(totsize, x')
        @test length(mx) == prod(totsize)
        for i=1:length(mx)
            @debug i,mx[i]
            @test mx[i] == (i - 1) ÷ 5 + 1
        end

        println("MA: error first index")
        totsize = (5,3)
        x = 1:3
        @test_throws Exception MyMap.MeshedArray(totsize, x)

        println("MA: error second index")
        totsize = (5,3)
        x = 1:5
        @test_throws Exception MyMap.MeshedArray(totsize, x')

        println("MA: broadcast access first index")
        totsize = (5,3)
        x = 21:25
        mx = MyMap.MeshedArray(totsize, x)
        @debug mx[3:6]
        @test mx[3:6] == [23, 24, 25, 21]

        println("MA: broadcast access second index")
        totsize = (5,3)
        x = 21:23
        mx = MyMap.MeshedArray(totsize, x')
        @debug mx[3:6]
        @test mx[3:6] == [21, 21, 21, 22]
    end


    @testset "mymap 1D" begin
        println("mymap 1D")

        function threadsloop(fn, arr)
            Treturn = Base.return_types(fn, (eltype(arr),))[1]
            out = similar(arr, Treturn)
            Threads.@threads for i=1:length(arr)
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

        test_work(arr) = test_work.(arr)

        A = 1:200
        test_work.(1:10)
        mymap(test_work, 1:10)
        threadsloop(test_work, 1:10)
        #ThreadsX.map(test_work, 1:10)
        #@time logA0 = test_work.(A)
        @time logA1 = mymap(test_work, A)
        @time logA2 = threadsloop(test_work, A)
        #@show A logA1
        @test logA1 == logA2
        #@assert logA1 == logA3
        #@assert logA2 == logA0
    end


    @testset "mymap2d" begin

        function test_work(i::Number, j::Number)
            return log(j) + log(i)
        end

        test_work(x, y) = test_work.(x, y)

        function do_2d_test(a, b)
            @show size(a),size(b)
            @time r0 = test_work.(a, b)
            @time r1 = mymap2d(test_work, a, b)
            @debug r1
            @test size(r1) == size(r0)
            @test r0 == r1
        end

        A = 1:100
        B = 11:150
        @test MyMap.calc_outsize(A, A) == (length(A),)
        @test_throws Exception MyMap.calc_outsize(A, B)
        @test_throws Exception MyMap.calc_outsize(A', B')
        @test MyMap.calc_outsize(A, B') == (length(A), length(B))
        @test MyMap.calc_outsize(A', B) == (length(B), length(A))

        do_2d_test(A, A)
        do_2d_test(A, B')
        do_2d_test(A', B)
        do_2d_test(A', A')

        println("full 2D")
        @time r0 = test_work.(A .* ones(length(A))', ones(length(A)).*A')
        @time r1 = mymap2d(test_work, A .* ones(length(A))', ones(length(A)).*A')
        @time r0 = test_work.(A .* ones(length(A))', ones(length(A)).*A')
        @time r1 = mymap2d(test_work, A .* ones(length(A))', ones(length(A)).*A')
        @test r0 == r1

        do_2d_test(A, A)
        do_2d_test(A, B')
        do_2d_test(A', B)
        do_2d_test(A', A')
    end

end
