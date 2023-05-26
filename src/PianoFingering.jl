module PianoFingering

using PyCall
using MIDI
using Base.Enums
using Base.Math
using POMDPs
using QuickPOMDPs
using POMDPTools
using Combinatorics
using DataStructures
using IterTools
using Random
using Parameters
using Base.Threads

include("const.jl")
include("pig.jl")
include("ActEpsGreedy.jl")
include("DictPolicy.jl")
include("midi_extract.jl")
include("mdp.jl")
include("q_learning.jl")
include("dyna.jl")
include("split.jl")
include("process.jl")

export fingering
export xml_to_pig

const music21 = PyNULL()

function __init__()
    copy!(music21,pyimport("music21"))
end

end