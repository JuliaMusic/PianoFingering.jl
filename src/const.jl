import MIDI.Note
const Notes = MIDI.Notes{MIDI.Note}
MIDI.Notes{MIDI.Note}(v::Vector{MIDI.Note}) = MIDI.Notes(v)

@enum Hand lh=-1 rh=1
@enum Finger f1=1 f2=2 f3=3 f4=4 f5=5
@enum Direct up=1 down=-1 level=0
@enum FingeringType nature cross move
@enum Part first_part last_part middle_part whole_part

const Pitch = UInt8
const NoteFingerPair = Pair{Note, Finger}
const Fingering = SortedDict{Note, Finger}
struct FingeringState
    index::Int
    fingering::Fingering
end

# single finger strength sorted by finger number
const single_finger_strength = [2, 4, 5, 3, 1]

# make Notes sort by pitch.
Base.isless(n1::Note,n2::Note) = n1.pitch < n2.pitch
Base.isequal(n1::Note,n2::Note) = Base.isequal(n1.pitch, n2.pitch)
Base.hash(n::Note,h::UInt) = Base.hash(n.pitch)

# FingeringState as key
Base.:(==)(a::FingeringState,b::FingeringState)= a.index == b.index && a.fingering == b.fingering 
Base.isequal(a::FingeringState,b::FingeringState) = Base.isequal(a.index,b.index) && Base.isequal(a.fingering,b.fingering)
Base.hash(a::FingeringState,h::UInt)= Base.hash(a.index,Base.hash(a.fingering))

# pretty print NoteFingerPair
function Base.show(io::IO, nfp::NoteFingerPair)
    nn = rpad(pitch_to_name(nfp.first.pitch), 3)
    print(io,"Pair: $(nn) => $(nfp.second)")
end
function Base.show(io::IO, fingering::Fingering)
    print(io,"$Fingering  ")
    for nfp in fingering
        nn = rpad(pitch_to_name(nfp.first.pitch), 3)
        print(io,"$(nn) => $(nfp.second) ")
    end
end

# midi note number of white keys
white_keys = [21, 23, 24, 26, 28, 29, 31, 33, 35, 36, 38, 40, 41, 43, 45, 47, 48, 50, 52, 53, 55, 57, 59, 60, 62, 
    64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84, 86, 88, 89, 91, 93, 95, 96, 98, 100, 101, 103, 105, 107, 108]
# midi note number of black keys
black_keys = [22, 25, 27, 30, 32, 34, 37, 39, 42, 44, 46, 49, 51, 54, 56, 58, 61, 63, 66, 68, 70, 73,75, 78, 80, 
    82, 85, 87, 90, 92, 94, 97, 99, 102, 104, 106]

# index 1: vector of fingers of N fingering combinations
# index 2: vector of fingerings combinations
# index 3: vector of fingering fingers 
all_rh_fingerings = [collect(combinations(instances(Finger),i)) for i=1:5 ]
all_lh_fingerings = [broadcast(reverse,f) for f in all_rh_fingerings] 

# max fingerings distance between 2 fingers, value -1 means this fingering is physical impossibal
max_finger_distance = [
    -1 4 5 6 7;
    3 -1 3 4 6;
    2 -1 -1 3 4;
    1.5 -1 -1 -1 3;
    -1 -1 -1 -1 -1;
]

# initialize notes from Fingering
Notes(f::Fingering) = Notes(Note[keys(f)...])

# initialize fingers from Fingering
fingers(f::Fingering)::Vector{Finger} = [values(f)...]

# get keyboards position of notes
relative_position(n::Note) = n.pitch in white_keys ? 
    findfirst(isequal(n.pitch), white_keys) : findfirst(isequal(n.pitch+1), white_keys)-0.5

# calculate distance between two different keys over piano keyboards
key_distance(start_note::Note, end_note::Note) = abs(relative_position(end_note) - relative_position(start_note))

# get note position relative to A0
note_position(note::Note) = key_distance(Note("A0"),note)+1

# get all fingering by hand
all_fingering_by_hand(hand::Hand) = hand == rh ? all_rh_fingerings : all_lh_fingerings

# get natural hand position, finger distance between two finger
nature_distance(finger1::Finger,finger2::Finger) = abs(Int(finger1)-Int(finger2))

# white key range between highest and lowest note of chord
function chord_range(notes::Notes) #key_distance(first(notes),last(notes))+1
    _, index_max = findmax(n -> n.pitch, notes)
    max_pitch_note = notes[index_max]
    _, index_min = findmin(n -> n.pitch, notes)
    min_pitch_note = notes[index_min]
    return key_distance(max_pitch_note,min_pitch_note)+1
end
chord_range(fingering::Fingering) = chord_range(Notes(fingering))
# fingering transition range
function chord_range(f1::Fingering,f2::Fingering)
    v = Vector{Note}()
    append!(v,Notes(f1),Notes(f2))
    sort!(v)
    return chord_range(Notes(v))
end 

# check if two finger in keyboard are too narrow
# too narrow, return true, else, return false
narrow_finger_check(p1::NoteFingerPair,p2::NoteFingerPair)::Bool = 
    ceil(key_distance(p1.first,p2.first)) < abs(Int(p1.second) - Int(p2.second))

# hand move distance between two fingering
function hand_move_distance(hand::Hand,f1::Fingering,f2::Fingering) 
    hand_position_s(nfp::Pair{Note,Finger}) = note_position(nfp.first) + Int(hand)*(3 - Int(nfp.second))
    hand_position(fingering::Fingering) = (hand_position_s(first(fingering)) + hand_position_s(last(fingering))) / 2
    return abs(hand_position(f1)-hand_position(f2))
end
# get hand position
# function hand_position(hand::Hand,fingering::Fingering)
    
#     return 
# end

# check if next notes is same as current fingering
# if same, return true, else, false 
function is_same_notes(f::Fingering,n::Notes)::Bool
    sort!(n.notes, by = x -> x.pitch )
    return [keys(f)...] == n.notes
end

function build_fingering(hand::Hand,notes::Notes,fingers::Vector{Finger})::Fingering
    if !allunique(notes)
        error("dumplicate notes")
    end
    if !allunique(fingers)
        error("dumplicate fingers")
    end

    notes_num = length(notes)
    fingers_num = length(fingers)

    if notes_num == fingers_num
        sort!(notes.notes, by = x -> x.pitch )
        hand == rh ? sort!(fingers) : sort!(fingers, rev = true)
        return Fingering(notes.=>fingers)
    else
        error("notes number and finger are not equal")
    end 
end

# assignment initial fingering for notes
function assign_fingering(hand::Hand,notes::Notes)::Vector{Fingering}
    # number of notes
    notes_num = length(notes)
    if notes_num > 5 || notes_num == 0
        error("wrong notes number: $(notes_num)")
    end

    sort!(notes.notes, by = x -> x.pitch )
    # result fingering
    return_fingering::Vector{Fingering} = Fingering[]
    all_fingerings = all_fingering_by_hand(hand)
    
    if notes_num == 1
        return [build_fingering(hand,notes,f) for f in all_fingerings[1]]
    else
        for fingering in all_fingerings[notes_num]
            physical_possible = true
            for (finger_pair,note_pair) in zip(collect(combinations(fingering,2)),collect(combinations(notes,2)))
                key_dis = key_distance(note_pair[1],note_pair[2])
                f1_index = Int(finger_pair[1])
                f2_index = Int(finger_pair[2])
                (fi,fo) = hand == rh ? (f1_index,f2_index) : (f2_index,f1_index)
                if key_dis > max_finger_distance[fi,fo]
                    physical_possible = false
                        break
                end
            end
            if physical_possible
                finger_check = true
                for i in 1:notes_num-1
                    if narrow_finger_check(notes[i]=>fingering[i],notes[i+1]=>fingering[i+1])
                        finger_check = false
                        break
                    end
                end
                if finger_check
                    push!(return_fingering,build_fingering(hand,notes,fingering))
                end
            end
        end
    end
    return return_fingering
end

# check if 1 note to 1 note fingering with hand movement
# hand need move to press next key, return fasle
# hand don't need move to press next key, return true
function is_1to1_no_move(hand::Hand, start_fingering::Fingering,next_note::Note)::Bool
    if length(start_fingering) ≠ 1
        error("Wrong fingering number, fingering must have only 1 note")
    end

    fingering = first(start_fingering)
    start_note = fingering.first
    start_finger = fingering.second
    start_note_position = relative_position(start_note)
    next_note_position = relative_position(next_note)
    inner_distance = 0
    outer_distance = 0

    if start_finger == f1
        inner_distance = max_finger_distance[2,1]
        outer_distance = max_finger_distance[1,5]
    elseif start_finger == f5
        inner_distance = max_finger_distance[1,5]
        outer_distance = 0
    else
        inner_distance = max_finger_distance[1,Int(start_finger)]
        outer_distance = max_finger_distance[Int(start_finger),5]
    end

    (left_distance, right_distance) = hand == rh ? (inner_distance, outer_distance) : (outer_distance, inner_distance)
    left_bound = start_note_position - left_distance
    right_bound = start_note_position + right_distance

    return next_note_position >= left_bound && next_note_position <= right_bound
end

# get stretch between two fingers
function stretch_rate(hand::Hand,nfp1::NoteFingerPair,nfp2::NoteFingerPair)
    if (nfp1.first > nfp2.first && hand == rh) || (nfp1.first < nfp2.first && hand == lh)
        nfp1,nfp2 = nfp2,nfp1
    end

    note1 = nfp1.first
    note2 = nfp2.first
    finger1 = nfp1.second
    finger2 = nfp2.second
    
    nature_dis = nature_distance(finger1, finger2)
    finger_dis = key_distance(note1, note2)
    max_dis = max_finger_distance[Int(finger1),Int(finger2)]

    stratch_rate = finger_dis > nature_dis ? 
        (finger_dis - nature_dis) / (max_dis - nature_dis) : (nature_dis - finger_dis) / nature_dis

    return round(stratch_rate; digits=2)
end

# get average of all finger stretch rate
function all_stretch_rate(hand::Hand,fingering::Fingering)
    s = subsets([fingering...],2)
    return round(mapreduce(x->stretch_rate(hand,x[1],x[2])^1.5,+,s) / length(s), digits=2)
end

# Get all available fingering, and hand stretch, no movement
# one to one, consider crossing finger
function get_1to1_fingering(hand::Hand, start_fingering::Fingering,next_note::Note)::Vector{Fingering}
    nfp = first(start_fingering)
    start_note = nfp.first
    start_finger = nfp.second
    distance = key_distance(start_note,next_note)
    direct = level
    if next_note > start_note
        direct = up
    elseif next_note < start_note
        direct = down
    end

    r = Fingering[]

    if direct == level
        push!(r, Fingering(next_note=>start_finger))
        return r
    end
        # calculate all available fingering, no crossing
    if (direct == up && hand == rh) || (direct == down && hand == lh)
        for i in 2:5 
            if (distance <= max_finger_distance[Int(start_finger),i]) && ((start_finger != f1 && 
                    !narrow_finger_check(start_note=>start_finger,next_note=>Finger(i))) || start_finger == f1)
                    # prevent narrow finger
                    push!(r,Fingering(next_note=>Finger(i)))
            end
        end
    elseif ((direct == up && hand == lh) || (direct == down && hand == rh)) && start_finger != f1
        for i in 1:5
            if (distance <= max_finger_distance[i,Int(start_finger)]) && 
                ((i != 1 && !narrow_finger_check(start_note=>start_finger,next_note=>Finger(i))) || i == 1)
                    push!(r,Fingering(next_note=>Finger(i)))
            end
        end
    end
    # calculate all available crossing fingering
    if (start_finger == f2 || start_finger == f3 || start_finger == f4) && #start finger is f2,f3 or f4
        ((direct == up && hand == rh) || (direct == down && hand == lh)) && # left hand go down, right hand go up
            !(start_note.pitch in white_keys && next_note.pitch in black_keys) && # start note is white, end note can't be black when crossing
                distance <= max_finger_distance[Int(start_finger),1] # note distance is large than max
                    push!(r,Fingering(next_note=>f1))
    elseif start_finger == f1 && ((direct == up && hand == lh) || (direct == down && hand == rh))
        for i in 2:4
            if distance <= max_finger_distance[i,1]
                push!(r,Fingering(next_note=>Finger(i)))
            end
        end
    end
    return r
end

# check if it's cross fingering
function is_1to1_cross(hand::Hand,start_nfp::NoteFingerPair,end_nfp::NoteFingerPair)
    start_note = start_nfp.first
    start_finger = start_nfp.second
    end_note = end_nfp.first
    end_finger = end_nfp.second
    direct = end_note > start_note ? up : down
    return ((start_finger == f2 || start_finger == f3 || start_finger == f4) && end_finger == f1 && 
        ((direct == up && hand == rh) || (direct == down && hand == lh))) || 
            (start_finger == f1 && ((direct == up && hand == lh) || (direct == down && hand == rh)))
end

# get f1 or f2,f3,f4, move distance when cross finger.
function cross_distance(start_nfp::NoteFingerPair,end_nfp::NoteFingerPair)
    dis = key_distance(start_nfp.first,end_nfp.first)
    finger_start = start_nfp.second
    finger_end = end_nfp.second
    return finger_start == f1 ? dis + Int(finger_end) - 1 : dis + Int(finger_start) - 1
end

# the number of same finger but different note in fingering transition
function same_finger_but_different_note_num(pre_fingering::Fingering,next_fingering::Fingering)
    same_fingers = intersect(fingers(pre_fingering),fingers(next_fingering))
    num = 0
    if length(same_fingers) ≠ 0
        for sf ∈ same_fingers
            if findfirst(isequal(sf),pre_fingering).pitch ≠ 
                findfirst(isequal(sf),next_fingering).pitch
                    num += 1
            end
        end
    end
    return num
end

# the number of same note but different finger in fingering transition
function same_note_but_different_finger_num(pre_fingering::Fingering,next_fingering::Fingering)
    num = 0
    for (k,v) ∈ pre_fingering
        if haskey(next_fingering,k) && next_fingering[k] ≠ v
            num += 1
        end
    end
    return num
end

# reverse order number in fingering transition
# for example: fingering transition ,right hand "C4-f1,E4-f3" -> "F4-f2,A4-f4"
# E4-f3,F4-f2 is a reverse order, this function find number of reverse order
function note_finger_reverse_order_num(hand::Hand,pre_fingering::Fingering,next_fingering::Fingering)
    merge_fingering = Vector{NoteFingerPair}()
    append!(merge_fingering,pre_fingering,next_fingering)
    pitch_ordered = merge_fingering[sortperm(merge_fingering)]
    num = 0
    for (p1,p2) ∈ partition(pitch_ordered,2,1)
        if (hand == rh && p1.second > p2.second) || (hand == lh && p2.second > p1.second)
            num += 1
        end
    end
    return num
end