

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
    B = 11:1500  # with another 0, GC goes crazy

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
    println("mybroadcast 2d transpose:")
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

