# Example of parsing a simple phrase

include("terms.jl")
include("rewr.jl")
include("avms.jl")
include("equal.jl")
include("chart.jl")
include("grammar.jl")

using .Terms
using .Rewr
using .Charts
using .Grammars

# creating the chart

chart = Chart()
specset1 = SpecSet([EqualSpec(["det", "*"], ["@1"])])
fid = uniquefid(chart)
specset1 = rewritespecs(specset1, RewriteRule(Term("*"), Term(fid)))
specset2 = SpecSet([EqualSpec(["det", "*"], ["@0"])])
specset2 = rewritespecs(specset2, RewriteRule(Term("*"), Term(fid)))
addedge(chart, Edge(1, 2, "Det", fid, [specset1, specset2]))
specset = SpecSet([EqualSpec(["func", "lex", "*"], ["@mad"]), EqualSpec(["index", "lex", "*"], ["@2"])])
fid = uniquefid(chart)
specset = rewritespecs(specset, RewriteRule(Term("*"), Term(fid)))
addedge(chart, Edge(2, 3, "A", fid, [specset]))
specset = SpecSet([EqualSpec(["func", "lex", "*"], ["@dog"]), EqualSpec(["index", "lex", "*"], ["@3"])])
fid = uniquefid(chart)
specset = rewritespecs(specset, RewriteRule(Term("*"), Term(fid)))
addedge(chart, Edge(3, 4, "N", fid, [specset]))
println(chart)

# creating the grammar

grammar = Grammar()
addrule(grammar, Rule("S", ["NP"], [[SpecSet([EqualSpec(["*"], ["."])])]]))
addrule(grammar, Rule("NP", ["Det?", "A*", "N"], [
    [SpecSet([EqualSpec(["*"], ["."])])],
    [SpecSet([EqualSpec(["adj", "*"], ["."])])],
    [SpecSet([EqualSpec(["*"], ["."])])],
]))
println(grammar)

# parsing and printing the result

parse(grammar, chart)
println(chart)
