# multi_thread ------------------
function run_splite(notes::Vector{Notes},hand::Hand)::Vector{Fingering}
    read_range = splited_range(notes,hand)
    result_fingering = [Fingering() for _ in 1:length(notes)]
    reward = zeros(length(notes))
    @time Threads.@threads for index in eachindex(read_range)
        r = read_range[index]
        range_len = length(read_range)
        if range_len == 1
            part = whole_part
        elseif index == 1
            part = first_part
        elseif index == range_len
            part = last_part
        else
            part = middle_part
        end
        mdp = piano_mdp(notes[r],hand,part)
        exppolicy = ActEpsGreedyPolicy(mdp, 0.8)
        solver = DynaSolver(exploration_policy = exppolicy, learning_rate=0.99, n_episodes=10000, θ = 3, n_eval_traj = length(notes[r]))
        # solver = QLearningSolver(exploration_policy = exppolicy, learning_rate=0.99, n_episodes=10000, n_eval_traj = length(notes_rh[r]))
        policy = solve(solver, mdp)
        println("end: part:$(index) length:$(length(notes[r]))")
        sim = StepSimulator("s,a,r,sp")
        start_i = first(r)
        for (s,a,r,sp) in simulate(sim, mdp, policy)
            result_fingering[start_i] = a
            reward[start_i] = r
            start_i += 1
        end
    end

    for (i,f) in enumerate(result_fingering)
        println("-----------$(i):--------------------------")
        for j in f
            println("$(pitch_to_name(j.first.pitch)) : $(j.second)")
        end
        println("reward:$(reward[i])")
    end
    return result_fingering
end

function annotation(part,fgs::Vector{Fingering})
    i = 1
    last_note = music21.note.Note()
    for el in part.flat.getElementsByClass("GeneralNote")
        now_fingering = fgs[i]
        # acciaccatura, tie start
        if el.isNote && el.duration.isGrace && (!isnothing(el.tie) && el.tie.type == "start")
            el.articulations = PyVector([music21.articulations.Fingering(Int(now_fingering[Note(el.pitch.midi,0)]))])
            last_note = el
            continue
        end

        # acciaccatura, no tie
        if el.isNote && el.duration.isGrace && (isnothing(el.tie))
            grace_note = Note(el.pitch.midi,0)
            el.articulations = PyVector([music21.articulations.Fingering(Int(now_fingering[grace_note]))])
            delete!(now_fingering,grace_note) 
            last_note = el
            continue
        end

        # continue is element is not chord, note or grace_note. Skip this element
        if !(el.isNote || el.isChord) || 
            (!isnothing(el.tie) && (el.tie.type == "stop" || el.tie.type == "continue") && !last_note.duration.isGrace)
                continue
        end

        # annotation chord or note
        el.articulations = PyVector([music21.articulations.Fingering(Int(fg)) 
            for fg in fingers(now_fingering)])
        last_note = el
        i += 1
    end
end

function fingering(file_name::String)
    piano_score = music21.converter.parse("musicxml/$(file_name).musicxml")
    score_with_fingering = piano_score

    generate_MIDI(piano_score,file_name)

    notes_rh = parse_MIDI(file_name, rh)
    notes_lh = parse_MIDI(file_name, lh)

    println("right hand start:")
    rh_result = run_splite(notes_rh,rh)
    println("left hand start:")
    lh_result = run_splite(notes_lh,lh)

    lh_part = score_with_fingering.parts[0]
    rh_part = score_with_fingering.parts[1]

    annotation(lh_part,lh_result)
    annotation(rh_part,rh_result)

    score_with_fingering.write("musicxml", "output/$(file_name)_output.musicxml")
end