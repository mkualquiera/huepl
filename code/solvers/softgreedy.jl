include("../psmsdst.jl")

"""
    softmax(input[,hard=1.0])

Compresses a k-dimensional vector of values from an arbitrary range into the 
[0.0,1.0] range such that they sum 1. Numerically higher values in the input 
will result in numerically higher values in the output.

The output can be interpreted as the probability that a given value in the
input is the maximum element, given incomplete or partial information. 

The hardness parameter determines how biased the probability distribution will
be towards selecting the true maximum. As hardness tends to infinity, the 
distribution converges to the maximum, and as hardness tends to zero, the 
distribution converges to a uniform distribution over the input.
"""
function softmax(input::Vector{Float64};hard=1.0::Float64)::Vector{Float64}
    exponentials = exp.(input .* hard)
    denominator = sum(exponentials)
    return exponentials ./ denominator
end


"""
    softmin(input[,hard=1.0])

Compresses a k-dimensional vector of values from an arbitrary range into the 
[0.0,1.0] range such that they sum 1. Numerically lower values in the input 
will result in numerically higher values in the output.

The output can be interpreted as the probability that a given value in the
input is the minimum element, given incomplete or partial information. 

The hardness parameter determines how biased the probability distribution will
be towards selecting the true minimum. As hardness tends to infinity, the 
distribution converges to the minimum, and as hardness tends to zero, the 
distribution converges to a uniform distribution over the input.
"""
softmin(input::Vector{Float64};hard=1::Float64)::Vector{Float64} = 
    softmax(-input,hard=hard)

"""
    solvegreedy(problem)

Solves the given PSMSDST problem using a "soft greedy" heuristic: for every 
pair (j,m) of available jobs and machines, the objective function of 
programming that job on that machine is computed. Then, the softmin function
is applied to these values, and a pair is sampled using this distribution,
and it is programmed. 
This continues until a feasible solution is found. 

Solutions are generated and compared to the best solution that has been found
so far. If no improvement is made to the solution after a number of 
``attempts``, the solver stops and the best solution found is returned.
"""
function solvesoftgreedy(problem::PSMSDSTProblem,
    hard::Float64,attempts::Int64)::Vector{Vector{Int}}

    machines = 1:problem.nummachines

    bestsolution = nothing
    bestcost = typemax(Int64)

    # Number of solutions without improvement
    improvementdelay = 0

    # Keep trying solutions until the number of attempts is exceeded
    while improvementdelay < attempts
    
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

        # Matrix that indicates if programming a job on a machine would 
        # invalidate the pre-calculated delay.
        createsdelayupdate = [ true for job in 1:problem.numjobs, 
            machine in machines ]

        # The id of the machine that will be updated because the cached delays
        # where invalidated.
        updatedelays = 0

        # Program jobs until a complete solution is reached
        while !isempty(availablejobs)  

            # Cartesian product, (j,m) pairs of jobs and machines.
            options = (Iterators.product(availablejobs,machines) 
                |> collect |> vec)

            # The delays of a machine need to be recalculated.
            if updatedelays > 0
                machine = updatedelays
                for job in availablejobs
                    delay = problem.durations[job]

                    if length(solution[machine]) > 0
                        lastjob = solution[machine][end]
                        lastfamily = problem.families[lastjob]
                        thisfamily = problem.families[job]
                        # If the family of the next job is different to the
                        # family of this job, this means that all the delays are
                        # invalidated because the setup times will change. 
                        createsdelayupdate[job,machine] = 
                            (thisfamily != lastfamily)
                        
                        # Add the setup time to the delay
                        delay += problem.setuptimes[lastfamily,thisfamily]
                    end

                    delays[job,machine] = delay
                end    
            end

            # Compute costs vector

            costs = zeros(length(options))
            finishtimes = zeros(length(options))

            for (i,(job,machine)) in enumerate(options)
                finishtimes[i] = (machinefinishtimes[machine]
                    +delays[job,machine])
                
                costs[i] = max(currentmaxfinishtime,finishtimes[i])                 
            end

            # Normalize costs relative to the minimum one, to avoid numerical
            # unstability
            normcosts = costs .- minimum(costs)

            # Compute probability distribution using softmin function
            distribution = softmin(normcosts,hard=hard)

            # Sample from the probability distribution
            optionindex = findfirst(cumsum(distribution) .> rand())

            job,machine = options[optionindex]

            finishtime = finishtimes[optionindex]

            createsupdate = createsdelayupdate[job,machine]

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

        improvementdelay += 1

        cost = maximum(machinefinishtimes)

        if cost < bestcost
            bestcost = cost
            bestsolution = solution
            improvementdelay = 0
        end
    end

    return bestsolution
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
function getsolver(;hardness=1.0::Float64,
        attempts=20::Int64)::Pair{String,Function}
    solver = problem -> solvesoftgreedy(problem,hardness,attempts)

    presolve(solver)

    return "Softgreedy n=$attempts 𝍍=$hardness"=>solver
end