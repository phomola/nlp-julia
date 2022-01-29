# Term rewriting
module Rewr

using ..Terms

export RewriteRule, rewrite, tryrewrite

# A rewrite rule
struct RewriteRule
    lhs::Term
    rhs::Term
end

# Rewriting a term, returns nothing if impossible
function rewrite(rule::RewriteRule, t::Term)::Union{Nothing,Term}
    if rule.lhs == t
        return rule.rhs
    end
    if t.arg !== nothing
        local arg = rewrite(rule, t.arg)
        if arg !== nothing
            return Term(t.head, arg)
        end
    end
    nothing
end

# Rewriting a term, returns the input if impossible
function tryrewrite(rule::RewriteRule, t::Term)::Term
    if rule.lhs == t
        return rule.rhs
    end
    if t.arg !== nothing
        local arg = tryrewrite(rule, t.arg)
        return Term(t.head, arg)
    end
    t
end

end
