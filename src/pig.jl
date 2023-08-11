using MIDI

mutable struct PigNote
    note_id::Int
    onset_time::Float64
    offset_time::Float64
    spelled_pitch::String
    onset_velocity::Int
    offset_velocity::Int
    channel::Int
    finger_number::Int
end

# load pig dataset without fingering
# return tuple(rh_notes,lh_notes)
function pig_loader(file_path::String)::Tuple{Vector{Notes},Vector{Notes}}
    rh_pig_notes,lh_pig_notes = parse_pig(file_path)
    return (pig_to_notes_by_time(rh_pig_notes),pig_to_notes_by_time(lh_pig_notes))
end 

# read pig file and return left hand / right hand PigNote
function parse_pig(file_path::String)::Tuple{Vector{PigNote},Vector{PigNote}}
    rh_pig_notes = PigNote[]
    lh_pig_notes = PigNote[]
    for pn in pig_to_pignotes(file_path)
        pn.finger_number > 0 ? push!(rh_pig_notes,pn) : push!(lh_pig_notes,pn)
    end
    return rh_pig_notes,lh_pig_notes
end

# read pig file and convert to Vector of PigNote
function pig_to_pignotes(file_path::String)::Vector{PigNote}
    all_notes = PigNote[]
    open(file_path) do file
        for ln in eachline(file)
            if startswith(ln,"//") || length(ln) == 0
                continue
            end

            note_id, onset_time, offset_time, spelled_pitch, onset_velocity, 
                offset_velocity, channel, finger_number = split(ln,"\t")

            dash = findfirst("_",finger_number)
            if !isnothing(dash)
                finger_number = SubString(finger_number,1,first(dash)-1)
            end

            pn = PigNote(
                parse(Int,note_id),
                parse(Float64,onset_time),
                parse(Float64,offset_time),
                spelled_pitch,
                parse(Int,onset_velocity),
                parse(Int,offset_velocity),
                parse(Int,channel),
                parse(Int,finger_number))
            push!(all_notes,pn)
        end
    end
    return all_notes
end

# Vector{PigNote} to Vector{Notes}, n in Vector{Notes}
function pigs_sort_by_time(pig_notes::Vector{PigNote})::Vector{Vector{PigNote}}
    fn = pig_notes[1]
    
    pigs_by_time = Vector{Vector{PigNote}}()
    temp_time = fn.onset_time
    temp_vec = PigNote[]

    for n in pig_notes
        # 30ms onset_time between two notes, read as chord
        if abs(n.onset_time - temp_time) > 0.03
            push!(pigs_by_time,copy(temp_vec))
            empty!(temp_vec)
        end
        push!(temp_vec,n)
        temp_time = n.onset_time
    end

    push!(pigs_by_time,copy(temp_vec))

    for n in pigs_by_time
        f = n[1].onset_time
        n = map(x->x.onset_time = f, n)
    end
    
    # now all pig_notes save in pigs_by_time
    # convert it to Vector{Notes}
    return pigs_by_time
end

function pig_to_fingering_by_time(pig_notes::Vector{PigNote})::Vector{Fingering}
    fn = first(pig_notes)
    # suppose first note is a sixteenth note
    sixteenth_time = fn.offset_time - fn.onset_time
    duration16th = pig_notes[2].onset_time - pig_notes[1].onset_time

    map(pigs_sort_by_time(pig_notes)) do pns
        position = round(Int,256 * pns[1].onset_time / sixteenth_time)
        fgn = Fingering()
        for pn in pns
            nt = Note(
                name_to_pitch(pn.spelled_pitch), 
                pn.onset_velocity, 
                position, 
                round(Int,256 * duration16th / sixteenth_time), 
                pn.channel)
            fg = Finger(abs(pn.finger_number))
            push!(fgn,nt=>fg)
        end
        fgn
    end
end

function pig_to_notes_by_time(pig_notes::Vector{PigNote})
    fn = first(pig_notes)
    # suppose first note is a sixteenth note
    sixteenth_time = fn.offset_time - fn.onset_time
    duration16th = pig_notes[2].onset_time - pig_notes[1].onset_time
    
    map(pigs_sort_by_time(pig_notes)) do pns
        position = round(Int,256 * pns[1].onset_time / sixteenth_time)
        notes_vec = map(pns) do pn
            Note(
                name_to_pitch(pn.spelled_pitch), 
                pn.onset_velocity, 
                position, 
                round(Int,256 * duration16th / sixteenth_time), 
                pn.channel)
        end
        Notes(notes_vec)
    end
end

pignote_to_string_without_fingering(pn::PigNote)::String = 
    "$(pn.note_id)\t$(pn.onset_time)\t$(pn.offset_time)\t$(pn.spelled_pitch)\t$(pn.onset_velocity)\t$(pn.offset_velocity)\t$(pn.channel)\t"

function pig_write(file_name::String,rh_fingerings::Vector{Fingering},lh_fingerings::Vector{Fingering})
    open("output/$(file_name)_output.txt","w") do file
        write(file,"//Version:\n")
        pns = pig_to_pignotes("pig/$(file_name).txt")
        rh_pointer = 1
        lh_pointer = 1

        str_vec = map(pns) do pn
            pig_str = pignote_to_string_without_fingering(pn)
            fin_str = ""
            key_note = Note(name_to_pitch(pn.spelled_pitch),0)
            if pn.finger_number > 0
                while true
                    rh_fingering = rh_fingerings[rh_pointer]
                    if haskey(rh_fingering,key_note)
                        fin_str = string(Int(rh_fingering[key_note]))
                        delete!(rh_fingering,key_note)
                        if isempty(rh_fingering)
                            rh_pointer += 1
                        end
                        break
                    else
                        rh_pointer+=1
                    end
                end
            else
                while true
                    lh_fingering = lh_fingerings[lh_pointer]
                    if haskey(lh_fingering,key_note)
                        fin_str = "-$(Int(lh_fingering[key_note]))"
                        delete!(lh_fingering,key_note)
                        if isempty(lh_fingering)
                            lh_pointer += 1
                        end
                        break
                    else
                        lh_pointer+=1
                    end
                end
            end
            pig_str*fin_str
        end

        for s in str_vec
            write(file,"$(s)\n")
        end
    end
end

# NoteFingerPair to pig line string with fingering, but no pig note id at string start
function nfp_to_string(nfp::NoteFingerPair,hand::Hand)::String
    note = nfp.first
    finger = nfp.second
    channel = hand == rh ? 0 : 1
    # time count by ms
    onset_time = midi_ms_per_tick * Int(note.position) / 1000
    offset_time = midi_ms_per_tick * (note.position + note.duration*0.98) / 1000
    return "$(onset_time)\t$(offset_time)\t$(pitch_to_name(note.pitch))\t$(note.velocity)\t0\t$(channel)\t$(Int(hand)*Int(finger))"
end    

function xml_result_to_pig(file_name::String,rh_fingerings::Vector{Fingering},lh_fingerings::Vector{Fingering})
    open("output/$(file_name)_output.txt","w") do file
        write(file,"//Version:\n")
        # latest pos
        pos = 0
        count = 0
        str_vec = String[]
        rh_pointer = 1
        lh_pointer = 1
        rh_now_fingering = rh_fingerings[rh_pointer]
        lh_now_fingering = lh_fingerings[lh_pointer]
        rh_pos = first(rh_now_fingering).first.position
        lh_pos = first(lh_now_fingering).first.position
        length_rh = length(rh_fingerings)
        length_lh = length(lh_fingerings)
        
        while !(rh_pointer == length_rh && lh_pointer == length_lh)
            if rh_pos <= lh_pos
                for nfp in rh_now_fingering
                    push!(str_vec,"$(count)\t$(nfp_to_string(nfp,rh))")
                    count += 1
                end
                if rh_pointer < length_rh
                    rh_pointer += 1
                    rh_now_fingering = rh_fingerings[rh_pointer]
                    rh_pos = first(rh_now_fingering).first.position
                end
            else
                for nfp in lh_now_fingering
                    push!(str_vec,"$(count)\t$(nfp_to_string(nfp,lh))")
                    count += 1
                end
                if lh_pointer < length_lh
                    lh_pointer += 1
                    lh_now_fingering = lh_fingerings[lh_pointer]
                    lh_pos = first(lh_now_fingering).first.position
                end
            end
        end
        for s in str_vec
            write(file,"$(s)\n")
        end
    end
end