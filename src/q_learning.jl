import POMDPs: Solver, solve, Policy
"""
    QLearningSolver
Vanilla Q learning implementation for tabular MDPs
Parameters:
- `exploration_policy::ExplorationPolicy`:
    Exploration policy to select the actions
- `n_episodes::Int64`:
    Number of episodes to train the Q table
    default: `100`
- `max_episode_length::Int64`:
    Maximum number of steps before the episode is ended
    default: `100`
- `learning_rate::Float64`
    Learning rate
    defaul: `0.001`
- `eval_every::Int64`:
    Frequency at which to evaluate the trained policy
    default: `10`
- `n_eval_traj::Int64`:
    Number of episodes to evaluate the policy
- `rng::AbstractRNG` random number generator
- `verbose::Bool`:
    print information during training
    default: `true`
"""

@with_kw mutable struct QLearningSolver{E<:ExplorationPolicy} <: Solver
   n_episodes::Int64 = 100
   max_episode_length::Int64 = 100
   learning_rate::Float64 = 0.001
   exploration_policy::E
   Q_vals::Union{Nothing, Dict{Tuple,Float64}} = nothing
   #Q_vals::Union{Nothing, Matrix{Float64}} = nothing
   eval_every::Int64 = 30
   n_eval_traj::Int64 = 20
   rng::AbstractRNG = Random.GLOBAL_RNG
   verbose::Bool = true
end

function solve(solver::QLearningSolver, mdp::MDP)
    rng = solver.rng
    if solver.Q_vals === nothing
        Q = Dict{Tuple,Float64}()
        #Q = zeros(length(states(mdp)), length(actions(mdp)))
    else
        Q = solver.Q_vals
    end
    exploration_policy = solver.exploration_policy
    sim = RolloutSimulator(rng=rng, max_steps=solver.max_episode_length)

    on_policy = DictPolicy(mdp, Q)
    k = 0
    old_avg = 0
    for i = 1:solver.n_episodes
        s = rand(rng, initialstate(mdp))
        t = 0
        while !isterminal(mdp, s) && t < solver.max_episode_length
            a = action(exploration_policy, on_policy, k, s)
            k += 1
            sp, r = @gen(:sp, :r)(mdp, s, a, rng)
            
            action_dict = actionvalues(on_policy,sp)
            action_dict_values = collect(values(action_dict))
            max_sp_prediction = isempty(action_dict_values) ? 0 : maximum(action_dict_values)

            current_s_prediction = 0 
            haskey(Q,(s,a)) ? (current_s_prediction = Q[(s,a)]) : (Q[(s,a)] = 0)
            
            Q[(s,a)] += solver.learning_rate * (r + discount(mdp) * max_sp_prediction - current_s_prediction)
            s = sp
            t += 1
        end
        if i % solver.eval_every == 0
            r_tot = 0.0
            for traj in 1:solver.n_eval_traj
                r_tot += simulate(sim, mdp, on_policy, rand(rng, initialstate(mdp)))
            end

            new_avg = r_tot/solver.n_eval_traj
            solver.verbose ? println("On Iteration $i, Returns: $(new_avg)") : nothing
            round(old_avg,digits = 1) == round(new_avg,digits = 1) ? break : old_avg = new_avg
        end
    end
    return on_policy
end

# POMDPLinter.@POMDP_require solve(solver::QLearningSolver, problem::Union{MDP,POMDP}) begin
#     P = typeof(problem)
#     S = statetype(P)
#     A = actiontype(P)
#     @req initialstate(::P, ::AbstractRNG)
#     @req gen(::DDNOut{(:sp, :r)}, ::P, ::S, ::A, ::AbstractRNG)
#     @req stateindex(::P, ::S)
#     @req states(::P)
#     ss = states(problem)
#     @req length(::typeof(ss))
#     @req actions(::P)
#     as = actions(problem)
#     @req length(::typeof(as))
#     @req actionindex(::P, ::A)
#     @req discount(::P)
# end