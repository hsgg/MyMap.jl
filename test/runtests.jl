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
    include("meshedarrays.jl")
    include("calc_outsize.jl")
    include("mybroadcast_1d.jl")
    include("mybroadcast_2d.jl")
    include("thread_distribution.jl")
    #include("progressmeter.jl")  # can only be tested with a human

    if do_perf
        Base.prompt("Finish? ")
    end
end
