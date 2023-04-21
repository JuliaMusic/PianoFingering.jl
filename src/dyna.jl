import POMDPs: Solver, solve, Policy

@with_kw mutable struct DynaSolver{E<:ExplorationPolicy} <: Solver
   n_episodes::Int64 = 100
   max_episode_length::Int64 = 100
   learning_rate::Float64 = 0.001
   θ::Float64 = 1.0
   exploration_policy::E
   Q_vals::Union{Nothing, Dict{Tuple,Float64}} = nothing
   model_vals::Union{Nothing, Dict{Tuple,Tuple}} = nothing
   eval_every::Int64 = 150
   n_eval_traj::Int64 = 20
   rng::AbstractRNG = Random.GLOBAL_RNG
   verbose::Bool = true
end

function solve(solver::DynaSolver, mdp::MDP)
    rng = solver.rng
    pqueue = PriorityQueue{Tuple,Float64}(Base.Order.Reverse)
    # key is "state", value is "vector of s-a pair" which predicted to key state
    predict = Dict()
    if solver.Q_vals === nothing
        Q = Dict{Tuple,Float64}()
        model = Dict{Tuple,Tuple}()
    else
        Q = solver.Q_vals
        model = solver.model_vals
    end
    exploration_policy = solver.exploration_policy
    sim = RolloutSimulator(rng=rng, max_steps=solver.max_episode_length)

    on_policy = DictPolicy(mdp, Q)
    k = 0
    ini_state = []
    last_reward = 0 # no use, why?
    old_avg = 0
    for i = 1:solver.n_episodes
        s = rand(rng, initialstate(mdp))
        if !(s in ini_state)
            push!(ini_state,s)
        end
        t = 0
        while !isterminal(mdp, s) && t < solver.max_episode_length
            a = action(exploration_policy, on_policy, k, s)
            k += 1
            sp, r = @gen(:sp, :r)(mdp, s, a, rng)

            #update predict
            if !haskey(predict,sp)
                predict[sp] = [(s,a)]
            else
                pre_sa_vector = predict[sp]
                if !((s,a) in pre_sa_vector)
                    push!(predict[sp],(s,a))
                end
            end

            # model learning
            model[(s,a)] = (sp,r)
            
            # all available action and reward at SP
            action_dict = actionvalues(on_policy,sp)
            action_dict_values = collect(values(action_dict))
            # max_a(S',a)
            max_sp_prediction = isempty(action_dict_values) ? 0 : maximum(action_dict_values)

            current_s_prediction = 0 
            haskey(Q,(s,a)) ? (current_s_prediction = Q[(s,a)]) : (Q[(s,a)] = 0)
            
            # TD-ERROR
            td_error = r + discount(mdp) * max_sp_prediction - current_s_prediction
            # prioritize calculates
            prioritize = abs(td_error)
            
            # if prioritize > solver.θ
                # enqueue
            pqueue[(s,a)] = prioritize
            # end
            # pqueue not empty
            while !isempty(pqueue)
                # dequeue state action pair
                (temp_s,temp_a) = dequeue!(pqueue) 
                # get next state and reward from model
                (temp_sp,temp_r) = model[(temp_s,temp_a)]
                
                temp_action_value = actionvalues(on_policy,temp_sp)
                temp_action_dict_values = collect(values(temp_action_value))
                temp_max_sp_prediction = isempty(temp_action_dict_values) ? 0 : maximum(temp_action_dict_values)
                
                # update Q value
                Q[(temp_s,temp_a)] += solver.learning_rate * (temp_r + discount(mdp) * temp_max_sp_prediction - Q[(temp_s,temp_a)])

                if !(temp_s in ini_state)
                    for sa_tuple in predict[temp_s]
                        (_,r_pre) = model[sa_tuple]
                        temp_max_s_prediction = maximum(collect(values(actionvalues(on_policy,temp_s))))
                        pre_td_error = r_pre + discount(mdp) * temp_max_s_prediction - Q[sa_tuple]
                        pre_prioritize = abs(pre_td_error)
                        if pre_prioritize > solver.θ
                            pqueue[sa_tuple] = pre_prioritize
                        end
                    end
                end
            end
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

# POMDPLinter.@POMDP_require solve(solver::DynaSolver, problem::Union{MDP,POMDP}) begin
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
