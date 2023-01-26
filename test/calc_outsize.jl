

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

