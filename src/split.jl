is_over_octave(note1::Note,note2::Note)::Bool = Int(note1.pitch)-Int(note2.pitch) >= 12

# return vector of split point,
function split_notes(notes_by_position::Vector{Notes},hand::Hand)::Vector{Int}
    len = length(notes_by_position)
    if len < 3
        error("notes too short")
    end
    
    # flip note to find lowest note when left hand
    if hand == lh
        notes_by_position = 
            map(n -> map(x -> Note(2(64.5 - x.pitch)+x.pitch,x.position), n),notes_by_position)
    end

    result = Int[1]
    max_notes = [maximum(notes) for notes in notes_by_position]
    min_notes = [minimum(notes) for notes in notes_by_position]
    for i in 2:len-1
        if length(notes_by_position[i]) > 1
            continue
        end
        # add all notes to set
        s = Set{Note}(notes_by_position[i])
        offset = 1
        at_left_bound = false
        at_right_bound = false
        is_max = true
        over_octave = false
        while length(s) < 5 
            left = i - offset
            right = i + offset
            if left >= 1 && right <= len
                union!(s, notes_by_position[left])
                union!(s, notes_by_position[right])
                if max_notes[i] < max_notes[left] || max_notes[i] < max_notes[right]
                    is_max = false
                    break
                end
                if is_over_octave(max_notes[i],min_notes[left]) || 
                    is_over_octave(max_notes[i],min_notes[right])
                    over_octave = true
                    break
                end
            else
                if left == 1
                    at_left_bound = true
                end
                if right == len
                    at_right_bound = true
                end
                break
            end
            offset += 1
        end

        if at_right_bound
            break
        end
        if at_left_bound
            continue
        end
        if !is_max
            continue
        end
        if length(s) >= 5 || over_octave
            push!(result,i)
        end            
    end
    push!(result,len)
    return result
end

function splited_range(notes_by_position::Vector{Notes},hand::Hand)::Vector{UnitRange{Int64}}
    threads_num = Threads.nthreads()
    notes_length = length(notes_by_position)
    split_length = Int(ceil(notes_length / threads_num))

    r = split_notes(notes_by_position,hand)

    println("range before splite:")
    @show r

    push!(r,notes_length)
    len_set = Set{Int}()
    
    if length(r) - 1 <= threads_num
        split_length = 5
    end

    range_vector = Vector{UnitRange{Int64}}()
    if threads_num == 1
        push!(range_vector,1:notes_length)
    else
        while true
            range_start = 1
            i = 2
            for (i,e) in enumerate(r[2:end])
                if length(range_start:e) < split_length
                    continue
                else
                    push!(range_vector,range_start:e)
                    range_start = e
                end
            end
            
            # put last element of e to range_vector
            last_range = last(range_vector)
            if last(last_range) != notes_length
                new_last_range = first(last_range) : notes_length
                range_vector[length(range_vector)] = new_last_range
            end
            
            range_len = length(range_vector)
            if range_len == threads_num || split_length in len_set || split_length <= 5
                break
            else
                empty!(range_vector)
                push!(len_set,split_length)
                range_len < threads_num ? split_length -= 1 : split_length += 1
            end
        end  
    end
    println("range after splite:")
    @show range_vector
    
    return range_vector
end