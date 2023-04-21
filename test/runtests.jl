using Test
using PyCall, MIDI, Base.Enums, POMDPs, QuickPOMDPs, POMDPTools, Combinatorics, DataStructures, IterTools

include("../src/const.jl")
include("../src/midi_extract.jl")
include("../src/mdp.jl")
@test Notes("C4 C5").notes == Notes("C4 C5").notes

@test relative_position(Note("C#1")) == 3.5
@test relative_position(Note("C1")) == 3

@test key_distance(Note("C#1"), Note("C1")) == 0.5
@test !isequal(Note("C#1"), Note("C#2"))
@test isequal(Note("C#1"), Note("C#1"))

@test all_stretch_rate(rh,Fingering(Note("D5")=>f1,Note("A5")=>f2,Note("D6")=>f5)) > all_stretch_rate(rh,Fingering(Note("D5")=>f1,Note("A5")=>f3,Note("D6")=>f5))


@test all_stretch_rate(rh,Fingering(Note("A5")=>f1,Note("D6")=>f2,Note("A6")=>f5)) < all_stretch_rate(rh,Fingering(Note("A5")=>f1,Note("D6")=>f3,Note("A6")=>f5))
# Fingering equal
@test Fingering(Note("C4")=>f1,Note("D4")=>f2) == Fingering(Note("D4")=>f2,Note("C4")=>f1)
@test Fingering(Note("C4")=>f1,Note("D4")=>f2) ≠ Fingering(Note("C5")=>f1)
@test isequal(Fingering(Note("C4")=>f1, Note("D4")=>f2),Fingering(Note("C4")=>f1, Note("D4")=>f2))
@test isequal(Fingering(Note("C4")=>f1, Note("D4")=>f2),Fingering(Note("D4")=>f2, Note("C4")=>f1))
@test !isequal(Fingering(Note("C4")=>f1, Note("D4")=>f2),Fingering(Note("D4")=>f2, Note("C4")=>f4))

# FingeringState equal
fs1 = FingeringState(1,Fingering(Note("C4")=>f1,Note("D4")=>f2))
fs2 = FingeringState(1,Fingering(Note("C4")=>f1,Note("D4")=>f2))
fs3 = FingeringState(4,Fingering(Note("C4")=>f1,Note("D4")=>f2))
fs4 = FingeringState(1,Fingering(Note("C4")=>f1,Note("E4")=>f2))
@test fs1 == fs2
@test fs1 ≠ fs3
@test fs1 ≠ fs4
@test isequal(fs1,fs2)
@test !isequal(fs1,fs3)
@test !isequal(fs1,fs4)

@test (fs1,Fingering(Note("C4")=>f1,Note("D4")=>f2)) == (fs1,Fingering(Note("C4")=>f1,Note("D4")=>f2))
dictN = Dict((fs1,Fingering(Note("C4")=>f1,Note("D4")=>f2))=>3)
@test dictN[(FingeringState(1,Fingering(Note("C4")=>f1,Note("D4")=>f2)),Fingering(Note("C4")=>f1,Note("D4")=>f2))] == 3


#getNotePosition
@test note_position(Note("A0")) == 1
@test note_position(Note("C4")) == 24


# relative_position
@test relative_position(Note("A0")) == 1

# is_1to1_no_move
@test is_1to1_no_move(rh, Fingering(Note("C4")=>f1), Note("D4"))
@test is_1to1_no_move(rh, Fingering(Note("C4")=>f1), Note("C4"))
@test is_1to1_no_move(rh, Fingering(Note("C4")=>f1), Note("C5"))
@test is_1to1_no_move(rh, Fingering(Note("C4")=>f1), Note("G3"))
@test !is_1to1_no_move(rh, Fingering(Note("C4")=>f1), Note("E3"))
@test !is_1to1_no_move(rh, Fingering(Note("C4")=>f1), Note("D5"))
@test is_1to1_no_move(lh, Fingering(Note("C4")=>f1),Note("C3"))
@test is_1to1_no_move(lh, Fingering(Note("C4")=>f1),Note("F4"))
@test !is_1to1_no_move(lh, Fingering(Note("C4")=>f1), Note("B2"))
@test !is_1to1_no_move(lh, Fingering(Note("C4")=>f1), Note("G4"))
@test is_1to1_no_move(lh, Fingering(Note("C4")=>f3),Note("F4"))
@test !is_1to1_no_move(lh, Fingering(Note("C4")=>f3),Note("B4"))
@test !is_1to1_no_move(lh, Fingering(Note("C4")=>f3),Note("D3"))

# nature_distance
@test nature_distance(f1,f2) == 1
@test nature_distance(f1,f3) == 2
@test nature_distance(f1,f5) == 4
@test nature_distance(f2,f5) == 3
@test nature_distance(f4,f2) == 2

# hand_move_distance
@test hand_move_distance(rh, Fingering(Note("C4")=>f1,Note("G4")=>f4), Fingering(Note("C4")=>f1,Note("G4")=>f5)) == 0.5

@test chord_range(Notes(Fingering(Note("D4")=>f2,Note("G4")=>f5))) == 4
@test chord_range(Notes(Fingering(Note("D4")=>f2,Note("G4")=>f5,Note("E4")=>f3))) == 4

@test same_finger_but_different_note_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("E4")=>f2)) == 1
@test same_finger_but_different_note_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("E4")=>f1)) == 0
@test same_finger_but_different_note_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("D4")=>f2,Note("G4")=>f5)) == 0
@test same_finger_but_different_note_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("G4")=>f5)) == 0
@test same_finger_but_different_note_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("E4")=>f2,Note("F4")=>f5)) == 2
@test same_finger_but_different_note_num(Fingering(Note("D4")=>f1,Note("G4")=>f2),Fingering(Note("D4")=>f1)) == 0

@test same_note_but_different_finger_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("G4")=>f4)) == 1
@test same_note_but_different_finger_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("A4")=>f4)) == 0
@test same_note_but_different_finger_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("D4")=>f2,Note("G4")=>f5)) == 0
@test same_note_but_different_finger_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("D4")=>f2)) == 0
@test same_note_but_different_finger_num(Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("D4")=>f1,Note("G4")=>f3)) == 2
@test same_note_but_different_finger_num(Fingering(Note("D4")=>f1,Note("G4")=>f2),Fingering(Note("D4")=>f1)) == 0

@test note_finger_reverse_order_num(rh,Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("G4")=>f4,Note("E4")=>f1)) == 1
@test note_finger_reverse_order_num(rh,Fingering(Note("D4")=>f2,Note("G4")=>f5),Fingering(Note("A4")=>f4,Note("E4")=>f1)) == 2
@test note_finger_reverse_order_num(rh,Fingering(Note("D4")=>f1,Note("G4")=>f2),Fingering(Note("D4")=>f1)) == 0

# is_same_notes
@test is_same_notes(Fingering(Note("C4")=>f1,Note("G4")=>f5),Notes("C4 G4"))
@test !is_same_notes(Fingering(Note("C4")=>f1,Note("G4")=>f5),Notes("C4 D4"))
@test is_same_notes(Fingering(Note("C4")=>f1),Notes("C4"))

# narrow_finger_check
@test narrow_finger_check(Note("C4")=>f2,Note("D4")=>f4)
@test narrow_finger_check(Note("E4")=>f5,Note("C4")=>f1)

# is_1to1_cross
@test is_1to1_cross(rh,Note("C4")=>f1,Note("B3")=>f2)
@test is_1to1_cross(rh,Note("C4")=>f2,Note("D4")=>f1)
@test !is_1to1_cross(rh,Note("C4")=>f1,Note("D4")=>f2)
@test is_1to1_cross(lh,Note("C4")=>f2,Note("B3")=>f1)
@test is_1to1_cross(lh,Note("C4")=>f1,Note("D4")=>f2)
@test is_1to1_cross(rh,Note("A5")=>f1,Note("G5")=>f2)

# cross_distance
@test cross_distance(Note("C4")=>f2,Note("D4")=>f1) == 2.0
@test cross_distance(Note("C4")=>f3,Note("E4")=>f1) == 4.0