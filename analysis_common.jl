using MiniObserve
using Statistics
using StatsBase
using LinearRegression

# mean and variance
const MVA = MeanVarAcc{Float64}
# maximum, minimum
const MMA = MaxMinAcc{Float64}


function local_relatedness(person, radius, world)
    r = 0.0
    m = 0.0
    n = 0

    for p in iter_circle(world.pop_cache, person.pos, radius)
        if p == person
            continue
        end
        rel = relatedness(person, p)
        m = max(m, rel)
        r += rel
        n += 1
    end

    (n>0 ? r/n : 0.0), m
end


