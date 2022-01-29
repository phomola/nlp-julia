# Context-free grammar parsing
# The time complexity of the algorithm is O(n^3) (in the length of the input).
module Grammars

using ..Charts
using ..Rewr
using ..Terms

export Grammar, Rule, addrule, parse

# A symbol with specifications on the right-hand side of a context-free rule
struct RuleSlot
    symbol::String
    skippable::Bool
    repeatable::Bool
    specs::Vector{SpecSet}
end

# A context-free rule
struct Rule
    lhs::String
    rhs::Vector{RuleSlot}
    function Rule(lhs::String, _rhs::Vector{String}, allspecs::Vector{Vector{SpecSet}})
        local rhs = RuleSlot[]
        sizehint!(rhs, length(_rhs))
        for i in 1:length(_rhs)
            local s = _rhs[i]
            local specs = allspecs[i]
            local last = s[end]
            if last == '*'
                push!(rhs, RuleSlot(s[1:end-1], true, true, specs))
            elseif last == '+'
                push!(rhs, RuleSlot(s[1:end-1], false, true, specs))
            elseif last == '?'
                push!(rhs, RuleSlot(s[1:end-1], true, false, specs))
            else
                push!(rhs, RuleSlot(s, false, false, specs))
            end
        end
        new(lhs, rhs)
    end
end

# A context-free grammar
mutable struct Grammar
    rules::Vector{Rule}
    Grammar() = new(Rule[])
end

function addrule(grammar::Grammar, rule::Rule)
    push!(grammar.rules, rule)
end

function match(cb::Function, chart::Chart, rule::Vector{RuleSlot}, level::Int64, start::Int64, pos::Int64, path::Vector{Tuple{Edge,Int64}}, canskip::Bool)
    if pos > length(rule)
        local valid = false
        for (edge, _) in path
            if edge.level == level
                valid = true
                break
            end
        end
        if valid
            cb(path)
        end
    else
        local slot = rule[pos]
        if canskip && slot.skippable
            match(cb, chart, rule, level, start, pos + 1, path, true)    
        end
        for edge in get(chart.edges, start, Edge[])
            if edge.label == slot.symbol
                if slot.repeatable
                    push!(path, (edge, pos))
                    match(cb, chart, rule, level, edge.last, pos, path, false)
                    pop!(path)
                end
                push!(path, (edge, pos))
                match(cb, chart, rule, level, edge.last, pos + 1, path, true)
                pop!(path)
            end
        end
    end
end

function match(cb::Function, chart::Chart, rule::Rule, level::Int64)
    for (start, _) in chart.edges
        match(cb, chart, rule.rhs, level, start, 1, Tuple{Edge,Int64}[], true)
    end
end

# Iteratively applies the grammar's rules to the chart until no new edges can be added.
# This function represents a fixed point.
function Base.parse(grammar::Grammar, chart::Chart, level::Int64=0)
    local newedges = Edge[]
    for rule in grammar.rules
        match(chart, rule, level) do path
            local children = Edge[]
            local newspecs = [SpecSet([])]
            local fid = uniquefid(chart)
            local upvarrewr = RewriteRule(Term("*"), Term(fid))
            for (edge, index) in path
                local downvarrewr = RewriteRule(Term("."), Term(edge.fid))
                push!(children, edge)
                edge.used = true
                local extspecs = SpecSet[]
                sizehint!(extspecs, length(newspecs))
                for set1 in newspecs
                    for set2 in edge.specs
                        for set3 in rule.rhs[index].specs
                            local specs = AbstractSpec[]
                            sizehint!(specs, length(set1.specs) + length(set2.specs) + length(set3.specs))
                            for spec in set1.specs
                                push!(specs, spec)
                            end
                            for spec in set2.specs
                                push!(specs, spec)
                            end
                            for spec in set3.specs
                                spec = rewritespecs(spec, upvarrewr)
                                spec = rewritespecs(spec, downvarrewr)
                                push!(specs, spec)
                            end
                            push!(extspecs, SpecSet(specs))
                        end
                    end
                end
                newspecs = extspecs
            end
            local newedge = Edge(children[1].start, children[end].last, rule.lhs, fid, newspecs, level + 1, false, children)
            push!(newedges, newedge)
        end
    end
    if !isempty(newedges)
        for edge in newedges
            addedge(chart, edge)
        end
        parse(grammar, chart, level + 1)
    end
end

function Base.show(io::IO, slot::RuleSlot)
    print(io, slot.symbol)
    if slot.skippable
        if slot.repeatable
            print(io, "*")
        else
            print(io, "?")
        end
    elseif slot.repeatable
        print(io, "+")
    end
end

function Base.show(io::IO, rule::Rule)
    print(io, "$(rule.lhs) ->")
    for s in rule.rhs
        print(io, " $s")
    end
end

function Base.show(io::IO, grammar::Grammar)
    for rule in grammar.rules
        println(io, rule)
    end
end

end
