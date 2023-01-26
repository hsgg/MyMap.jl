
@testset "ProgressMeter output" begin


    A = 1:100
    B = 11:1500

    p = Progress(length(A) * length(B), 0, "testing: ")
    @show length(A) * length(B)

    @time mybroadcast(A, B') do ii,jj
        out = Array{Float64}(undef, length(ii))

        buffer = Array{Float64}(undef, 100)
        for idx=1:length(ii)
            i = ii[idx]
            j = jj[idx]
            for m=1:length(buffer)
                for n=1:(i*j)
                    buffer[m] = i * j / (m * n)
                end
            end
            out[idx] = sum(buffer)
            #next!(p)
        end

        next!(p, step=length(ii), showvalues=[(:batchsize, length(ii))])
        return out
    end

end
