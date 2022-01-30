# nlp-julia
NLP library for Julia

At the moment there is a parser for unification grammars.
A **chart parser** for context-free grammars is combined with equational constraints
resolved using **e-graphs**, a data structure used in automated theorem proving.

The output of the parser can be converted into logical forms (in first-order logic)
that can be interpreted using Prolog (as in IBM Watson) or, for example, abductive reasoning.

See also [this unification parser written in Rust](https://github.com/phomola/ug-rs).
