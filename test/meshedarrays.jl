
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

