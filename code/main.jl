#!/usr/bin/julia

using Logging

function test()
    a = 3
    @info "test1" a
    
    @error "test2" a
    
    @warn "test3" a
    
    @debug "test4" a
    
    mat = [ 1 2 3 4 5 6 7 ; 7 6 5 4 3 2 1 ; 2 3 4 5 6 7 8 ; 1 2 3 4 5 6 7 ]
    display(mat)
    println()

    for i in 1:10
        println([ "test" for j in 1:i ]...)
        sleep(0.2)
    end
    killme()
end

test()