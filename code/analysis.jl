using PyPlot
using Logging

include("psmsdst.jl")
greedygen = include("solvers/softgreedy.jl")

function analyze()
    problemname = "PSMSDSTdata/PSMSDST6.txt"

    problem = parsepsmsdst(problemname)

    hardnesses = 5:0.25/2.0:8
    costs = Vector()

    for hardness in hardnesses
        solver,name = greedygen(attempts=0,hardness=hardness)

        solution = solver(problem)

        starttimes, finishtimes, cost = evaluatesolution(problem,solution)

        @info "Looking for best hardness" hardness cost

        push!(costs,cost)
    end

    plt.plot(hardnesses,costs)
    plt.show()
end

if abspath(PROGRAM_FILE) == @__FILE__
    analyze()
end