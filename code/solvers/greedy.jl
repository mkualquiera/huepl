
include("../psmsdst.jl")


"""
    solvegreedy(problem)

Solves the given PSMSDST problem using a greedy heuristic: for every pair (j,m)
of available jobs and machines, the pair that produces the lowest increment 
in the objective function is programmed, until a complete solution is reached.
"""
function solvegreedy(problem::PSMSDSTProblem)::Vector{Vector{Int}}

    machines = 1:problem.nummachines
    
    # Create resulting vector for the solution
    solution = [ Vector{Int}() for machineid in machines ] 

    # Create a set for the jobs that have not been programmed yet
    availablejobs = Set{Int}(1:problem.numjobs)

    # Create a vector for the finish times of each machine
    machinefinishtimes = [ 0 for machineid in machines ]

    # Variable that holds the current objective function
    currentmaxfinishtime = maximum(machinefinishtimes)

    # Matrix that contains how the machine finish time would increase when
    # a job is programmed on it.
    delays = [ problem.durations[job] for job in 1:problem.numjobs, 
                machine in machines ]

    # Matrix that indicates if programming a job on a machine would invalidate
    # the pre-calculated delay.
    createsdelayupdate = [ true for job in 1:problem.numjobs, 
        machine in machines ]

    # The id of the machine that will be updated because the cached delays
    # where invalidated.
    updatedelays = 0

    # Program jobs until a complete solution is reached
    while !isempty(availablejobs)

        # Cartesian product, (j,m) pairs of jobs and machines.
        options = Iterators.product(availablejobs,machines)

        if updatedelays > 0
            # The delays of a machine need to be recalculated.
            machine = updatedelays
            for job in availablejobs

                # The initial delay is just the duration of the job
                delay = problem.durations[job]

                if length(solution[machine]) > 0
                    lastjob = solution[machine][end]
                    lastfamily = problem.families[lastjob]
                    thisfamily = problem.families[job]

                    # If the family of the next job is different to the
                    # family of this job, this means that all the delays are
                    # invalidated because the setup times will change. 
                    createsdelayupdate[job,machine] = thisfamily != lastfamily

                    # Add the setup time to the delay
                    delay += problem.setuptimes[lastfamily,thisfamily]
                end

                delays[job,machine] = delay
            end    
        end

        # Look for the best option
        bestoption = nothing
        bestcost = typemax(Int64)

        for (job,machine) in options
            # Finish time of the machine if the job was programmed on it.
            virtualmachinefinish = (machinefinishtimes[machine]
                +delays[job,machine])
            
            # Objective function if the job was programmed on it.
            cost = max(currentmaxfinishtime,virtualmachinefinish)

            if cost < bestcost
                bestoption = (job,machine,virtualmachinefinish,
                    createsdelayupdate[job,machine])
                bestcost = cost
            end
        end

        job,machine,finishtime,createsupdate = bestoption

        # If the job creates an update in the delays, they have to be 
        # re-calculated in the next iteration.
        if createsupdate
            updatedelays = machine
        else
            updatedelays = 0 
        end

        machinefinishtimes[machine] = finishtime

        currentmaxfinishtime = maximum(machinefinishtimes)
        push!(solution[machine],job)
        delete!(availablejobs,job)
    end

    return solution
end

#
#    getsolver()
#
#Returns a pair containing the name of the solver, and a pre-parameterized 
#function that only takes the problem as argument. 
#
#Internally it also solves a small problem using the solver, ensuring that
#the code for the solver is compiled ahead of time and there is no reduced
#performance during evaluation.
#
## Examples
#```julia-repl
#julia> include("solvers/solver.jl")(param1=42.0,param2=64.0)
#"Solver param1=42 param2=64"=>#1 (generic function with 1 method)
#```

function getsolver()::Pair{String,Function}
    solver = problem -> solvegreedy(problem)

    presolve(solver)

    return "Greedy"=>solver
end