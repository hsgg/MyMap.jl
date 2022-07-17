module MeshedArrays

export MeshedArray


struct MeshedArray{T,N,Tarr,Tsz} <: AbstractArray{T,N}
    totsize::Tsz
    x::Tarr
end
MeshedArray(sz, x) = begin
    for n=1:ndims(x)
        if size(x,n) != 1
            if size(x,n) != sz[n]
                error("dimension $n in 'x' $(size(x)) must match 'sz' $sz or be 1")
            end
        end
    end
    return MeshedArray{eltype(x), length(sz), typeof(x), typeof(sz)}(sz, x)
end
Base.ndims(a::MeshedArray{T,N}) where {T, N <: Integer} = N
Base.size(a::MeshedArray) = a.totsize
Base.length(a::MeshedArray) = prod(size(a))
Base.getindex(a::MeshedArray, i::Int) = begin
    iout = 0
    szx = 1
    for n=1:ndims(a.x)
        d = ((i - 1) % size(a, n)) + 1
        i = ((i - 1) ÷ size(a, n)) + 1
        if size(a.x, n) != 1
            iout += szx * (d - 1)
        end
        szx *= size(a.x, n)
    end
    return a.x[iout+1]
end
Base.getindex(a::MeshedArray{T,N}, I::Vararg{Int,N}) where {T,N} = begin
    iout = 0
    szx = 1
    for n=1:ndims(a.x)
        @assert I[n] <= size(a, n)
        if size(a.x, n) != 1
            d = I[n]
            iout += szx * (d - 1)
        end
        szx *= size(a.x, n)
    end
    for n=ndims(a.x)+1:ndims(a)
        @assert I[n] <= size(a, n)
    end
    return a.x[iout+1]
end



end


# vim: set sw=4 et sts=4 :
