

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

