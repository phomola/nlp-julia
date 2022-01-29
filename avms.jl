# Attribute-value matrices (feature structures)
module AVMs

export AVM, setfeature

# An AVM is just a heterogenous dictionary
mutable struct AVM
    features::Dict{String,Any}
    AVM() = new(Dict{String,Any}())
end

function setfeature(avm::AVM, path::Vector{String}, value::Any)
    if length(path) == 1
        avm.features[path[1]] = value
    else
        local avm2 = get!(avm.features, path[1], AVM())
        setfeature(avm2, path[2:end], value)
    end
end

function Base.show(io::IO, avm::AVM)
    local pairs = String[]
    sizehint!(pairs, length(avm.features))
    for (attr, value) in avm.features
        push!(pairs, "$attr=$value")
    end
    print(io, "[$(join(pairs, ", "))]")
end

end
