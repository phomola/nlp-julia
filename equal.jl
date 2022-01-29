# E-graphs for unary terms
module Equal

using ..Terms
using ..AVMs

export EGraph, ConsistencyError, addterm, getclass, merge, getavm

abstract type AbstractEClass end

mutable struct ENode{C<:AbstractEClass}
    symbol::String
    arg::Union{C,Nothing}
    class::Union{C,Nothing}
end

mutable struct EClass <: AbstractEClass
    nodes::Vector{ENode{EClass}}
    parents::Vector{ENode{EClass}}
end

mutable struct EGraph
    classes::Vector{EClass}
    EGraph() = new(EClass[])
end

function fillavm(g::EGraph, c::EClass, attrs::Vector{String}, avm::AVM)
    for n in c.parents
        local attr = n.symbol
        for n2 in n.class.nodes
            if n2.arg === nothing
                if n2.symbol[1] == '@'
                    setfeature(avm, vcat(attrs, [attr]), n2.symbol[2:end])
                else
                    setfeature(avm, vcat(attrs, [attr]), getavm(g, n2.symbol))
                end
                @goto skip
            end
        end
        fillavm(g, n.class, vcat(attrs, [attr]), avm)
    @label skip
    end
end

# Builds an AVM for the given identifier from the terms in the e-graph.
function getavm(g::EGraph, id::String)::AVM
    local c = getclass(g, Term(id))
    @assert(typeof(c) == EClass) # the term must exist in the e-graph
    local avm = AVM()
    fillavm(g, c, String[], avm)
    avm
end

function Base.hash(n::ENode{EClass})::UInt64
    local h = hash(n.symbol)
    if n.arg !== nothing
        h = xor(h * 29, hash(n.arg) * 31)
    end
    h
end

function Base.:(==)(n1::ENode{EClass}, n2::ENode{EClass})::Bool
    n1.symbol == n2.symbol && n1.arg === n2.arg
end

function copy(g::EGraph)::EGraph
    EGraph(copy(g.classes))
end

function getclass(g::EGraph, t::Term)::Union{EClass,Nothing}
    for c in g.classes
        if hasterm(c, t)
            return c
        end
    end
    nothing
end

function hasterm(c::EClass, t::Term)::Bool
    for n in c.nodes
        if n.symbol == t.head
            if n.arg !== nothing && t.arg !== nothing
                if hasterm(n.arg, t.arg)
                    return true
                end
            elseif n.arg !== nothing || t.arg !== nothing
                error("bad term arity ($t vs $n)")
            else
                return true
            end
        end
    end
    false
end

function allterms(n::ENode{C})::Vector{Term} where C
    local r = Term[]
    if n.arg === nothing
        push!(r, Term(n.symbol))
    else
        for t in allterms(n.arg)
            push!(r, Term(n.symbol, t))
        end
    end
    r
end

function allterms(c::EClass)::Vector{Term}
    local r = Term[]
    for n in c.nodes
        append!(r, allterms(n))
    end
    r
end

function Base.show(io::IO, n::ENode{EClass})
    local terms = allterms(n)
    print(io, join(map(t -> string(t), terms), " "))
end

function Base.show(io::IO, c::EClass)
    local terms = allterms(c)
    print(io, "#$(length(c.nodes)) #$(length(c.parents)) ", join(map(t -> string(t), terms), " "))
end

function Base.show(io::IO, g::EGraph)
    println(io, "E-graph")
    for c in g.classes
        println(io, " ", c)
    end
end

# Adds a term to the e-graph.
function addterm(g::EGraph, t::Term)::Tuple{EClass,Bool}
    local class = getclass(g, t)
    if class !== nothing
        return class, false
    end
    local argclass = nothing
    if t.arg !== nothing
        argclass, _ = addterm(g, t.arg)
    end
    local n = ENode{EClass}(t.head, argclass, nothing)
    if argclass !== nothing
        push!(argclass.parents, n)
    end
    local c = EClass(ENode{EClass}[n], ENode{EClass}[])
    n.class = c
    push!(g.classes, c)
    return (c, true)
end

# An error indicating that a set of terms isn't consistent.
struct ConsistencyError
    message::String
end

# Merges two e-classes.
function merge(g::EGraph, c1::EClass, c2::EClass, checker::Union{Function,Nothing})::Union{EClass,ConsistencyError}
    if c1 === c2
        c1
    end
    local i = findfirst(isequal(c1), g.classes)
    local j = findfirst(isequal(c2), g.classes)
    local nodes = Set{ENode{EClass}}()
    local parents = Set{ENode{EClass}}()
    newclass = EClass(Vector{ENode{EClass}}[], Vector{ENode{EClass}}[])
    for n in c1.nodes
        n.class = newclass
        push!(nodes, n)
    end
    for n in c2.nodes
        n.class = newclass
        push!(nodes, n)
    end
    newclass.nodes = tovector(nodes)
    for n in c1.parents
        @assert(n.arg === c1)
        n.arg = newclass
        push!(parents, n)
    end
    for n in c2.parents
        @assert(n.arg == c2)
        n.arg = newclass
        push!(parents, n)
    end
    newclass.parents = tovector(parents)
    local tobemerged = Set{Tuple{ENode{EClass},ENode{EClass}}}()
    for n1 in c1.parents
        for n2 in c2.parents
            if n1.symbol == n2.symbol
                push!(tobemerged, (n1, n2))
            end
        end
    end
    g.classes[i] = newclass
    deleteat!(g.classes, j)
    for (n1, n2) in tobemerged
        @assert(n1.arg === n2.arg)
        local c1, c2 = n1.class, n2.class
        local r = merge(g, c1, c2, checker)
        if !isa(r, EClass)
            return r
        end
    end
    if checker !== nothing
        local r = checker(newclass)
        if r !== nothing
            return r
        end
    end
    newclass
end

function tovector(s::Set{T})::Vector{T} where T
    local a = T[]
    for el in s
        push!(a, el)
    end
    a
end

end
