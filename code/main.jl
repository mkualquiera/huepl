#!/usr/bin/julia

using Logging

function test()
    a = 3
    @info "ha" a
    
    @error "ono" a
    
    @warn "uwu" a
    
    @debug "deb" a

    for i in 1:10
        println([ "honk" for j in 1:i ]...)
        sleep(0.2)
    end
    killme()
end

test()