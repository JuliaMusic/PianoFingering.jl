struct DictPolicy{P<:Union{POMDP,MDP}, T<:AbstractDict{Tuple,Float64}} <: Policy
    mdp::P
    value_dict::T
end

function action(p::DictPolicy, s)
    available_actions = actions(p.mdp,s)
    max_action = nothing
    max_action_value = 0
    for a in available_actions
        if haskey(p.value_dict,(s,a))
            action_value = p.value_dict[(s,a)]
            if action_value > max_action_value
                max_action = a
                max_action_value = action_value
            end
        else
            p.value_dict[(s,a)] = 0
        end
    end
    if max_action === nothing
        max_action = available_actions[1]
    end
    return max_action
end

function actionvalues(p::DictPolicy, s) ::Dict
    available_actions = actions(p.mdp,s)
    action_dict = Dict()
    for a in available_actions
        action_dict[a] = haskey(p.value_dict,(s,a)) ? p.value_dict[(s,a)] : 0
    end
    return action_dict
end

function Base.show(io::IO, mime::MIME"text/plain", p::DictPolicy{M}) where M <: MDP
    summary(io, p)
    println(io, ':')
    ds = get(io, :displaysize, displaysize(io))
    ioc = IOContext(io, :displaysize=>(first(ds)-1, last(ds)))
    showpolicy(io, mime, p.mdp, p)
end
