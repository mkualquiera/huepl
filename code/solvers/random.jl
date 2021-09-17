
include("../psmsdst.jl")

"""
    solvegreedy(problem)

Solves the given PSMSDST problem using a purely random approach. While jobs
are available to be programmed, it programs any available job on any machine.

Solutions are generated and compared to the best solution that has been found
so far. If no improvement is made to the solution after a number of 
``attempts``, the solver stops and the best solution found is returned.
"""
function solverandom(problem::PSMSDSTProblem,attempts::Int)::Vector{Vector{Int}}

    machines = 1:problem.nummachines
    
    bestsolution = nothing
    bestcost = typemax(Int64)
    
    # Number of solutions without improvement
    noimprovement = 0 

    # Keep trying solutions until the number of attempts is exceeded
    while noimprovement < attempts
        # Create resulting vector for the solution
        solution = [ Vector{Int}() for machineid in machines ] 

        # Create a set for the jobs that have not been programmed yet
        availablejobs = Set{Int}(1:problem.numjobs)

        # Program jobs until a complete solution is reached
        while !isempty(availablejobs)

            # Get a random job and machine
            job = rand(availablejobs)
            machine = rand(machines)

            push!(solution[machine],job)
            delete!(availablejobs,job)
        end

        _, _, cost, _ = evaluatesolution(problem,solution)
        noimprovement += 1

        if cost < bestcost
            bestcost = cost
            bestsolution = solution
            noimprovement = 0 
        end
    end

    return bestsolution
end

# 
#     getsolver()
# 
# Returns a pair containing the name of the solver, and a pre-parameterized 
# function that only takes the problem as argument. 
# 
# Internally it also solves a small problem using the solver, ensuring that
# the code for the solver is compiled ahead of time and there is no reduced
# performance during evaluation.
# 
# # Examples
# ```julia-repl
# julia> include("solvers/solver.jl")(param1=42.0,param2=64.0)
# "Solver param1=42 param2=64"=>#1 (generic function with 1 method)
# ```

function getsolver(;attempts=20::Int)::Pair{String,Function}
    solver = problem -> solverandom(problem,attempts)

    presolve(solver)

    return "Random n=$attempts"=>solver
end