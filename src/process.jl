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
            result_fingering[start_i] = copy(a)
            reward[start_i] = r
            start_i += 1
        end
    end

    # for (i,f) in enumerate(result_fingering)
    #     println("-----------$(i):--------------------------")
    #     for j in f
    #         println("$(pitch_to_name(j.first.pitch)) : $(j.second)")
    #     end
    #     println("reward:$(reward[i])")
    # end
    
    return result_fingering
end

function annotation(part,fgs::Vector{Fingering})
    el_dict = SortedDict()
    # try to pick up all the sounding note and chord
    for el in part.flat.notes
        if el.isChord
            # skip chord symbol
            py_hasattr = pybuiltin("hasattr")
            if py_hasattr(el,"figure")
                continue
            end

            # add this chord?
            sounding_chord = false
            for n in el.notes
                has_tie = !isnothing(n.tie)
                # chord has sounding note(no tie), or has start tie. So it's sounding chord
                if !has_tie || (has_tie && n.tie.type == "start")
                    sounding_chord = true
                    break
                end
            end
            if !sounding_chord
                continue
            end
        end
        
        if el.isNote  
            if !isnothing(el.tie) && (!(el.tie.type == "start") || isnothing(el.tie))
                continue
            end
        end

        offset = el.offset
        if haskey(el_dict,offset)
            push!(el_dict[offset],el)
        else
            el_dict[offset] = PyVector([el])
        end
    end
    
    if length(el_dict) != length(fgs)
        error("number of fingering and note not equal.")
    end

    #start annotation
    for (els_pair,fin) in zip(el_dict,fgs)
        for el in els_pair.second
            if el.isNote
                el.articulations = PyVector([music21.articulations.Fingering(Int(fin[Note(el.pitch.midi,0)]))]) 
            end
            if el.isChord
                el.articulations = PyVector([music21.articulations.Fingering(
                    Int(fin[Note(n.pitch.midi,0)])) for n in el.notes])
            end
        end
    end
end

function xml_to_pig(file_name::String)
    file, extension = split(file_name,".")
    file_name = String(file)
    extension = String(extension)
    notes_rh,notes_lh,piano_score = musicxml_loader(file_name)
    println("right hand start:")
    rh_result = run_splite(notes_rh,rh)
    println("left hand start:")
    lh_result = run_splite(notes_lh,lh)
    xml_result_to_pig(file_name, rh_result, lh_result)
end

function fingering(file_name::String)
    file, extension = split(file_name,".")
    file_name = String(file)
    extension = String(extension)

    notes_rh,notes_lh = Notes[],Notes[]
    piano_score = nothing
    if extension == "musicxml"
        notes_rh,notes_lh,piano_score = musicxml_loader(file_name)
    elseif extension == "txt"
        notes_rh,notes_lh = pig_loader(file_name)
    end

    println("right hand start:")
    rh_result = run_splite(notes_rh,rh)
    println("left hand start:")
    lh_result = run_splite(notes_lh,lh)
    
    if extension == "musicxml"
        # score_with_fingering = music21.converter.parse("musicxml/$(file_name).musicxml")
        rh_part = piano_score.parts[1]
        annotation(rh_part,rh_result)
        lh_part = piano_score.parts[0]
        annotation(lh_part,lh_result)
        piano_score.write("musicxml", "output/$(file_name)_output.musicxml")
    elseif extension == "txt"
        pig_write(file_name,rh_result,lh_result)
    end
end