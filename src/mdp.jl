function piano_mdp(notes::Vector{Notes}, hand::Hand,part::Part)
    State = FingeringState
    Action = Fingering
    function R(s::FingeringState, a=missing)
        sp = State(s.index+1,a,Notes())
        fingering_s = s.fingering
        fingering_sp = sp.fingering
        num_s = length(fingering_s)
        num_sp = length(fingering_sp)
        notes_sp = Notes(fingering_sp)
        notes_s = Notes(fingering_s)

        notes_s_duration = num_s ≠ 0 ? Int(first(notes_s).duration) : 0

        finger_reward = mapreduce(x->single_finger_strength[Int(x)],+,fingers(fingering_sp))
        reward = 0
        # initial fingering reward
        # 1 note, 50 reward; more than 1 note, reward by stretch rate
        if s.index == 0 || notes_s_duration >= 2048
            reward = num_sp == 1 ? 50 : 50(1-all_stretch_rate(hand,fingering_sp))
        # pre fingering is same as next fingering
        elseif fingering_s == fingering_sp
            reward = 50
        # 1 note to 1 note
        elseif num_s == 1 && num_sp == 1
            if fingering_sp in get_1to1_fingering(hand,fingering_s,first(notes_sp))
                nfp_s = first(fingering_s)
                nfp_sp = first(fingering_sp)
                if is_1to1_cross(hand,nfp_s,nfp_sp)             
                    reward = 20+2.5(4-cross_distance(nfp_s,nfp_sp))
                else    
                    sr = stretch_rate(hand,nfp_s,nfp_sp)
                    if sr == 0 || (ceil(key_distance(nfp_s.first,nfp_sp.first)) == 1 && abs(Int(nfp_s.second)-Int(nfp_sp.second))==1)
                        return 50
                    elseif sr > 0
                        sr = abs(sr)
                        reward = 40 + 10(1-sr^2)
                    end
                end
            else
                reward = 20-hand_move_distance(hand,fingering_s,fingering_sp)/2
            end
        
        else
            range_s = chord_range(fingering_s)
            range_sp = chord_range(fingering_sp)
            rev_num = note_finger_reverse_order_num(hand,fingering_s,fingering_sp)
            (same_finger_num, same_note_num) = (0,0)
            if rev_num == 0
                same_finger_num = same_finger_but_different_note_num(fingering_s,fingering_sp)
                same_note_num = same_note_but_different_finger_num(fingering_s,fingering_sp)
            end
            discount = 1
            if !(range_s >= 6 && range_sp >= 6)
                    discount = 1 - (same_finger_num + same_note_num + rev_num) / (num_s + num_sp)
            end

            # 1 to n, n to n 
            if num_sp > 1
                move_dis = hand_move_distance(hand,fingering_s,fingering_sp)
                str_rate = all_stretch_rate(hand,fingering_sp)
                if range_s >= 6 && range_sp >= 6
                    reward = 49(1-str_rate)+1
                elseif move_dis > 5
                    # when move > 5, consider stratch rate more than move distance
                    reward = (20(1-str_rate)+(45-move_dis)/4.5) * discount
                else
                    # when move <= 5, consider stratch rate and move
                    reward = (25(6(1-str_rate^2.2)+ 4(5-move_dis))/13) * discount
                end    
            # n to 1
            else
                move_dis = hand_move_distance(hand,fingering_s,fingering_sp)
                cr = chord_range(fingering_s,fingering_sp)
                if cr >=7
                    discount = 1
                end
                reward = (50-1.2move_dis) * discount
                if move_dis >= 20
                    finger_reward *= 500
                end
            end
        end
        return reward + 0.01finger_reward
    end

    function A(s::FingeringState)
        if s.index < length(notes)
            notes_sp = notes[s.index+1]
            fingering_s = s.fingering
            num_s = length(fingering_s)
            num_sp = length(notes_sp)

            notes_s = Notes(fingering_s)

            notes_s_duration = num_s ≠ 0 ? Int(first(notes_s).duration) : 0
            # at first notes
            if s.index == 0
                # first part, or whole part,
                if part == first_part || part == whole_part || notes_s_duration >= 2048
                    return assign_fingering(hand, notes[s.index+1])
                else
                    return [build_fingering(hand,notes[s.index+1],[f5])]
                end
            # at last notes
            elseif s.index == length(notes)-1 && (part == first_part || part == middle_part)
                return [build_fingering(hand,notes[s.index+1],[f5])]
            elseif num_s == 1 && num_sp == 1
                a = get_1to1_fingering(hand,s.fingering,first(notes_sp))
                if length(a) != 0
                    return a
                else
                    return assign_fingering(hand, notes[s.index+1])
                end
            else
                return assign_fingering(hand, notes[s.index+1])
            end
        else
            return []
        end
    end

    return QuickMDP(
        transition = function (s, a)
            next_index = s.index+1
            next_notes =  length(notes) == next_index ? Notes() : notes[next_index+1]
            return Deterministic(State(next_index,a,next_notes))
        end,
        statetype = FingeringState,
        actiontype = Fingering,
        actions = A,
        reward = R,
        initialstate = Deterministic(State(0,Fingering(),notes[1])),
        isterminal = s -> s.index == length(notes)
    )
end


