STUDENTNAME = "JuanPabloOssaZapata"

using Logging
using XLSX
using Profile

include("psmsdst.jl")

@info "Compiling solvers..."

solvers = Dict(
    # Does not use any parameters
    include("solvers/random.jl")(attempts=10000),

    # Does not use any parameters
    include("solvers/greedy.jl")(),

    # -- PARAMETERS --
    # attempts: The number of solution attempts with no improvement until the 
    # method stops. In other words, if the method is unable to get a better
    # solution in this many attempts, it will stop.
    # hardness: Determines how biased the method will be towards greedyness.
    # Mathematically, the hardness parameter controls the β parameter of a 
    # softmax function.
    include("solvers/softgreedy.jl")(attempts=40,hardness=5.5)
)

function main()    

    allproblems = loadproblems()

    for (solvername,solver) in solvers

        shortname = split(solvername,r"\s")[1]

        filename = "PSMSDST_$(STUDENTNAME)_$(shortname).xlsx"

        XLSX.openxlsx(filename,mode="w") do xf

            newfile = true

            for (problemname, problem) in allproblems

                sheetname = "$problemname"

                if newfile
                    newfile = false
                    sheet = xf[1]
                    XLSX.rename!(sheet,sheetname)
                else
                    sheet = XLSX.addsheet!(xf,sheetname)
                end

                @info "Solving problem" solvername problemname
                
                tstart = time()

                solution = solver(problem)
                
                tend = time()

                elapsed = tend - tstart

                feasible, reason = isfeasible(problem,solution)

                if !feasible 
                    @error "SOLUTION PROVIDED BY SOLVER IS NOT FEASIBLE" #= 
                    =# solvername problemname reason
                end

                starttimes, finishtimes, cost, relative = 
                    evaluatesolution(problem,solution)

                optimal = problem.lowerbound == cost

                @info "Problem solved" solvername problemname elapsed #=
                =# feasible cost problem.lowerbound relative optimal

                if optimal
                    @warn "OPTIMAL SOLUTION FOUND!"
                end

                for (machineid,jobs) in enumerate(solution)
                    # First cell is the number of jobs
                    sheet[machineid,1] = length(jobs)
                    # Next cells are the job ids
                    for (index,job) in enumerate(jobs)
                        sheet[machineid,index+1] = job
                    end
                    # Next cells are the job start times
                    for (index,job) in enumerate(jobs)
                        sheet[machineid,index+1+length(jobs)] = job
                    end
                    # Final cell is the finish time
                    sheet[machineid,2+2*length(jobs)] = finishtimes[machineid]
                end
                # First cell of last row is the total cost
                sheet[length(solution)+1,1] = cost
            end
        end
    end
end

function loadproblems()::Vector{Tuple{String,PSMSDSTProblem}}
    result = Vector{Tuple{String,PSMSDSTProblem}}()
    @info "Loading problems..."
    for (root,_,files) in walkdir("PSMSDSTdata/")
        for file in files
            push!(result,(file,parsepsmsdst(joinpath(root,file))))
        end
    end

    reg = r"PSMSDST(\d+).txt"

    sort!(result,by=x->parse(Int64,match(reg,x[1])[1]))

    @info "Problems loaded"
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
