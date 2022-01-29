# Charts for context-free parsing
module Charts

using ..Terms
using ..Rewr
using ..Equal
using ..AVMs

export Chart, Edge, AbstractSpec, EqualSpec, SpecSet, addedge, uniquefid, rewritespecs

abstract type AbstractSpec end

# An equality specification
struct EqualSpec <: AbstractSpec
    term1::Term
    term2::Term
    EqualSpec(t1::Term, t2::Term) = new(t1, t2)
    EqualSpec(path1::Vector{String}, path2::Vector{String}) = new(Term(path1...), Term(path2...))
end

# A set of specifications associated with syntax tree nodes
struct SpecSet
    specs::Vector{AbstractSpec}
end

# An edge in a chart
mutable struct Edge
    start::Int64
    last::Int64
    label::String
    fid::String
    specs::Vector{SpecSet}
    level::Int64
    used::Bool
    children::Union{Vector{Edge},Nothing}
    function Edge(start::Int64, last::Int64, label::String, fid::String, specs::Vector{SpecSet})
        new(start, last, label, fid, specs, 0, false, nothing)
    end
    function Edge(start::Int64, last::Int64, label::String, fid::String, specs::Vector{SpecSet}, level::Int64, used::Bool, children::Vector{Edge})
        new(start, last, label, fid, specs, level, used, children)
    end
end

# A chart
mutable struct Chart
    edges::Dict{Int64,Vector{Edge}}
    maxfid::Int64
    Chart() = new(Dict{Int64,Vector{Edge}}(), 0)
end

function addedge(chart::Chart, edge::Edge)
    v = get!(chart.edges, edge.start, Edge[])
    push!(v, edge)
end

# Creates a list of AVMs from the specifications associated with the chart edge.
function getavms(edge::Edge)::Vector{AVM}
    local r = AVM[]
    sizehint!(r, length(edge.specs))
    for set in edge.specs
        g = EGraph()
        for spec in set.specs
            if typeof(spec) == EqualSpec
                local c1, _ = addterm(g, spec.term1)
                local c2, _ = addterm(g, spec.term2)
                local c = Equal.merge(g, c1, c2, function(c)
                    for i in 1:(length(c.nodes)-1)
                        for j in (i+1):length(c.nodes)
                            local s1 = c.nodes[i].symbol
                            local s2 = c.nodes[j].symbol
                            if s1[1] == '@' && s2[1] == '@' && s1 != s2
                                return ConsistencyError("$s1 /= $s2")
                            end
                        end
                    end
                    nothing
                end)
                if isa(c, ConsistencyError)
                    @goto skip
                end
            end
        end
        push!(r, getavm(g, edge.fid))
    @label skip
    end
    r
end

# Returns a linearised syntax tree.
function tree(edge::Edge)::String
    local s = edge.label
    if edge.children !== nothing
        s *= "("
        local first = true
        for c in edge.children
            if first
                first = false
            else
                s *= ","
            end
            s *= tree(c)
        end
        s *= ")"
    end
    s
end

function uniquefid(chart::Chart)::String
    chart.maxfid += 1
    "f$(chart.maxfid)"
end

function rewritespecs(spec::EqualSpec, rule::RewriteRule)::EqualSpec
    EqualSpec(tryrewrite(rule, spec.term1), tryrewrite(rule, spec.term2))
end

function rewritespecs(specs::SpecSet, rule::RewriteRule)::SpecSet
    local r = AbstractSpec[]
    sizehint!(r, length(specs.specs))
    for spec in specs.specs
        push!(r, rewritespecs(spec, rule))
    end
    SpecSet(r)
end

function rewritespecs(set::Vector{SpecSet}, rule::RewriteRule)::Vector{SpecSet}
    local r = SpecSet[]
    sizehint!(r, length(set))
    for specs in set
        push!(r, rewritespecs(specs))
    end
    r
end

function Base.show(io::IO, edge::Edge)
    print(io, "-$(edge.start)- $(edge.label) -$(edge.last)- / $(edge.fid):$(tree(edge)) $(join(getavms(edge), " | "))")
end

function Base.show(io::IO, spec::EqualSpec)
    print(io, "$(spec.term1) = $(spec.term2)")
end

function Base.show(io::IO, specs::SpecSet)
    local v = String[]
    sizehint!(v, length(specs.specs))
    for spec in specs.specs
        push!(v, "$spec")
    end
    print(io, "{ $(join(v, "; ")) }")
end

function Base.show(io::IO, set::Vector{SpecSet})
    local v = String[]
    sizehint!(v, length(set))
    for specs in set
        push!(v, "$specs")
    end
    print(io, join(v, " | "))
end

function isless(edge1::Edge, edge2::Edge)::Bool
    if edge1.start < edge2.start
        return true
    end
    if edge1.start > edge2.start
        return false
    end
    if edge1.last > edge2.last
        return true
    end
    if edge1.last < edge2.last
        return false
    end
    edge1.label < edge2.label
end

function Base.show(io::IO, chart::Chart)
    local edges = Edge[]
    for (_, v) in chart.edges
        for edge in v
            if !edge.used
                push!(edges, edge)
            end
        end
    end
    sort!(edges; lt=isless)
    for edge in edges
        println(io, edge)
    end
end

end
