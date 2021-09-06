#!/usr/bin/julia

function test(λ::Real)
    if λ^5 > 2
        return 42+3
    end
end