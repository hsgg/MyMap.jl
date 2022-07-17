using MyMap
using Test

@testset "MyMap.jl" begin

    @testset "MeshedArrays.jl" begin
        println("MA: first index")
        totsize = (5,3)
        x = 1:5
        mx = MyMap.MeshedArray(totsize, x)
        @test length(mx) == prod(totsize)
        for i=1:length(mx)
            @show i,mx[i]
            @test mx[i] == (i - 1) % 5 + 1
        end

        println("MA: second index")
        totsize = (5,3)
        x = 1:3
        mx = MyMap.MeshedArray(totsize, x')
        @test length(mx) == prod(totsize)
        for i=1:length(mx)
            @show i,mx[i]
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
        @show mx[3:6]
        @test mx[3:6] == [23, 24, 25, 21]

        println("MA: broadcast access second index")
        totsize = (5,3)
        x = 21:23
        mx = MyMap.MeshedArray(totsize, x')
        @show mx[3:6]
        @test mx[3:6] == [21, 21, 21, 22]
    end

end
