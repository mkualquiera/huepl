struct PSMSDSTProblem 
    numjobs::Integer
    nummachines::Integer
    numfamilies::Integer
    durations::Vector{Integer}
    families::Vector{Integer}
    setuptimes::Matrix{Integer}
    lowerbound::Integer
end

"""
    parsepsmsdst(path)

Parse a PSMSDST problem from a text file into a PSMSDSTProblem struct. 

Will error if the file does not exists or if the job indices are presented
in an unexpected format. 

# Examples
```julia-repl
julia> parsepsmsdst("PSMSDSTdata/PSMSDST1.txt")
PSMSDSTProblem(20, 2, 3, Integer[18, 7, 12, 11, 7, 18, 19, 19, ...
```
"""
function parsepsmsdst(path::String)::PSMSDSTProblem

    # Read the raw file as text
    text = open(path,"r") do f 
        read(f,String)
    end

    # Split each line
    lines = split(text,r"\n|\r\n")

    # Remove empty lines
    lines = filter(x->x!="",lines)

    # Split each line on a whitespace separator
    segmented = map(line->split(strip(line),r"(\s+)"),lines) 

    # Convert to numbers
    numerical = map(line->map(segment->parse(Int,segment),line),segmented)

    # Extract data from the first line
    numjobs, nummachines, numfamilies = numerical[1]

    # Extract the data for each job
    jobsinfo = vcat(transpose.(numerical[2:1+numjobs])...)

    if jobsinfo[:,1] != collect(1:numjobs)
        error("Job indices have an unexpected format")
    end

    durations = jobsinfo[:,2]
    families = jobsinfo[:,3]

    # Extract the setup times
    setuptimes = vcat(transpose.(numerical[end-numfamilies+1:end])...)

    inevitablesetups = 0 
    if numfamilies > nummachines
        inevitablesetups = numfamilies - nummachines
    end
    lowestsetup = typemax(Int64)
    for i in 1:numfamilies
        for j in 1:numfamilies
            if i != j 
                if setuptimes[i,j] < lowestsetup
                    lowestsetup = setuptimes[i,j]
                end
            end
        end
    end

    lowerbound = round(Int64,(sum(durations)/nummachines) 
        + inevitablesetups*lowestsetup)

    # Construct the result
    PSMSDSTProblem(
        numjobs,
        nummachines,
        numfamilies,
        durations,
        families,
        setuptimes,
        lowerbound
    )
end

"""
    isfeasible(problem,solution)

Determine if a given solution is feasible for the PSMSDST problem.

The i-th elementh of the solution vector corresponds to the list of jobs 
(in order) that are to be processed by machine i

Returns a tuple where the first element determines if the solution is feasible
and, when not feasible, the second element contains the reason.

# Examples
```julia-repl
julia> testproblem = PSMSDSTProblem(5,3,2,[6,9,4,2,7],[2,1,2,2,1,2],[0 4; 3 0])
PSMSDSTProblem(5, 3, 2, Integer[6, 9, 4, 2, 7], Integer[2, 1, 2, 2, 1, 2]...
julia> testsolution = Array{Int}.([[2,5],[3,4,1]])
2-element Vector{Vector{Int64}}:...
julia> feasible = isfeasible(testproblem, testsolution)
(false,"The problem has 3 machine but the solution only lists 2 machines")
```
"""
function isfeasible(problem::PSMSDSTProblem,solution::Vector{Vector{Int}}
    )::Tuple{Bool,Union{Nothing,String}}

    # Verify solution length
    if length(solution) != problem.nummachines
        return false, "The problem has $(problem.nummachines) machines but" *
        " the solution only lists $(length(solution)) machines"
    end
    
    # Create sets for counting
    programmedjobs = Set{Int}()
    availablejobs = Set{Int}(1:problem.numjobs)

    for machine in solution
        for job in machine
            if job in programmedjobs
                return false, "Job $job is programmed twice."
            end
            if !(job in availablejobs) 
                return false, "Job $job is not listed in the problem."
            end
            push!(programmedjobs,job)
            delete!(availablejobs,job)
        end
    end

    # Determine if there are jobs that were not programmed
    if !isempty(availablejobs)
        return false, "jobs $availablejobs were not programmed."
    end

    # Looks like it is feasible!
    return true, nothing
end

"""
    evaluatesolution(problem,solution[,verifyfeasibility=true])

Go throught a proposed solution and calculate the start time of each job,
the finish time of each machine, and the finish time of the last job.

If ``verifyfeasibility`` is set to true, this function will also verify
that the solution is feasible and error if it isn't.

# Examples
```julia-repl
julia> starttimes, finishtimes, lastfinish = evaluatesolution(problem,solution)
Vector{Vector{Int64}}, Vector{Int64}, Int64...
```
"""
function evaluatesolution(problem::PSMSDSTProblem,solution::Vector{Vector{Int}}
    ;verifyfeasibility::Bool=false)::Tuple{Vector{Vector{Int}},Vector{Int},Int,Float64}

    # Verify feasibility when asked
    if verifyfeasibility
        feasible, reason = isfeasible(problem,solution)
        if not feasible
            error(reason)
        end
    end

    # Initialize start times and finish times to 0
    starttimes = [ [ 0 for (_,_) in enumerate(jobs) ] 
                        for (_,jobs) in enumerate(solution) ]

    finishtimes = [ 0 for (_,_) in enumerate(solution) ]

    # Compute metrics for each machine
    for (machineid,jobs) in enumerate(solution)
        currtime = 0 
        for (scheduledorder,jobid) in enumerate(jobs)
            starttime = currtime
            if scheduledorder != 1
                # Find the setup time considering the previous processed job
                thisfamily = problem.families[jobid]
                prevfamily = problem.families[jobs[scheduledorder-1]]
                setuptime = problem.setuptimes[prevfamily,thisfamily]
                starttime += setuptime
            end
            starttimes[machineid][scheduledorder] = starttime
            finishtime = starttime + problem.durations[jobid]

            # Increment the current time
            currtime = finishtime
        end

        # The finish time is the last current time
        finishtimes[machineid] = currtime
    end

    # The maximum job finish time is the maximum finish time over all machines.
    maxtime = maximum(finishtimes)

    relative = ((maxtime - problem.lowerbound) / problem.lowerbound)*100

    return starttimes, finishtimes, maxtime, relative
end

"""
    presolve(solver)

Solves a small problem using the provided solver. This ensures that the solver
function is pre-compiled and no performance is lost during evaluation.

Note that this method is not perfect, as Julia will only compile the code that
is reached by solving this problem, and not necessarily the entire thing.
"""
function presolve(solver::Function)
    testproblem = PSMSDSTProblem(5,3,2,[6,9,4,2,7],[1,2,2,1,2],[0 4; 3 0],100)
    solver(testproblem)
    return
end

function __test()
    parsed = parsepsmsdst("PSMSDSTdata/PSMSDST1.txt")
    @info "Parse result" parsed

    testproblem = PSMSDSTProblem(5,3,2,[6,9,4,2,7],[1,2,2,1,2],[0 4; 3 0],100)
    @info "Test problem" testproblem

    testsolution = Array{Int}.([[2,5],[3,1,4],[]])
    feasible = isfeasible(testproblem, testsolution)
    @info "Test solution" testsolution feasible

    starttimes, finishtimes, loss = evaluatesolution(testproblem,testsolution)
    @info "Evaluation" starttimes finishtimes loss
end

if abspath(PROGRAM_FILE) == @__FILE__
    using Logging
    __test()
end