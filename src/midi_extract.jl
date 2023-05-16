function remove_chord_symbol(piano_score)
    for p in piano_score.parts
        p.atSoundingPitch = false
        for m in p.getElementsByClass("Measure")
            m.removeByClass("ChordSymbol")
        end
    end
end

function generate_MIDI(piano_score,file_name)
    remove_chord_symbol(piano_score)

    piano_lh,piano_rh = nothing,nothing

    if length(piano_score.parts) < 1
        error("score is empty")
    elseif length(piano_score.parts) > 1
        piano_lh = piano_score.parts[0]
        piano_rh = piano_score.parts[1]
    else
        piano_rh = piano_score.parts[0]
    end

    if piano_lh ≠ nothing
        piano_lh.write("midi", "midi/$(file_name)_lh.mid")
    end
    if piano_rh ≠ nothing
        piano_rh.write("midi", "midi/$(file_name)_rh.mid")
    end
end

function midi_loader(file_name::String, hand::Hand)::Vector{Notes}
    # get right hand notes 
    midi = load("midi/$(file_name)_$(hand).mid")
    piano_track = midi.tracks[2]

    notes = getnotes(piano_track)
    notes_by_position = Notes[]
    temp_notes = Notes(Note[])
    temp_set = Set{UInt8}()
    temp_position = notes[1].position

    for n in notes
        if temp_position < n.position
            push!(notes_by_position, copy(temp_notes))
            empty!(temp_notes)
            empty!(temp_set)
            temp_position = n.position
        end

        if !(n.pitch in temp_set)
            push!(temp_notes, n)
            push!(temp_set, n.pitch)
        end
    end
    push!(notes_by_position, temp_notes)

    # c=1
    # for i in notes_by_position
    #     for n in i
    #         @show n
    #     end
    #     println("at $(c)---------")
    #     c+=1
    # end
    
    return notes_by_position
end

function musicxml_loader(file_name::String)
    piano_score = music21.converter.parse("musicxml/$(file_name).musicxml")
    generate_MIDI(piano_score,file_name)
    return midi_loader(file_name, rh),midi_loader(file_name, lh),piano_score
end