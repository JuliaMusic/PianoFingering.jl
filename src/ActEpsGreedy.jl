import POMDPs: action, value, solve, updater
struct ActEpsGreedyPolicy{T<:Function, R<:AbstractRNG, M<:Union{MDP,POMDP}} <: ExplorationPolicy
    eps::T
    rng::R
    m::M
end
function ActEpsGreedyPolicy(problem::Union{MDP,POMDP}, eps::Function; 
                         rng::AbstractRNG=Random.GLOBAL_RNG)
    return ActEpsGreedyPolicy(eps, rng, problem)
end
function ActEpsGreedyPolicy(problem::Union{MDP,POMDP}, eps::Real; 
                         rng::AbstractRNG=Random.GLOBAL_RNG)
    return ActEpsGreedyPolicy(x->eps, rng, problem)
end
function POMDPs.action(p::ActEpsGreedyPolicy, on_policy::Policy, k, s)
    if rand(p.rng) < p.eps(k)
        return rand(p.rng, actions(p.m,s))
    else 
        return action(on_policy, s)
    end
end