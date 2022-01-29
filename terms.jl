# Unary terms
module Terms

export Term, arity

# A unary term
struct Term
    head::String
    arg::Union{Nothing,Term}
    Term(head::String, arg::Term) = new(head, arg)
    function Term(head::String, tail::String...)
        new(head, length(tail) == 0 ? nothing : Term(tail[1], tail[2:end]...))
    end    
end

function arity(t::Term)::Int64
    t.arg === nothing ? 0 : 1
end

function compare(t1::Term, t2::Term)::Int8
    local l1, l2 = length(t1), length(t2)
    if l1 < l2
        return -1
    end
    if l1 > l2
        return 1
    end
    if t1.head < t2.head
        return -1
    end
    if t1.head > t2.head
        return 1
    end
    if t1.arg === nothing
        return 0
    end
    compare(t1.arg, t2.arg)
end

function Base.hash(t::Term)::UInt64
    local h = hash(t.head)
    if t.arg !== nothing
        h = xor(h * 29, hash(t.arg) * 31)
    end
    h
end

function Base.:(==)(t1::Term, t2::Term)::Bool
    compare(t1, t2) == 0
end

function Base.length(t::Term)::Int64
    if t.arg === nothing
        1
    else
        length(t.arg) + 1
    end
end

function Base.show(io::IO, t::Term)
    print(io, t.head)
    if t.arg !== nothing
        print(io, "(", t.arg, ")")
    end
end

end
