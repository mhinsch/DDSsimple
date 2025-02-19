using MiniEvents

include("util.jl")
include("stupider.jl")
include("main_util.jl")


function run(model, logfile, step = 1.0)
	t = 1.0
	last = 0

	quit = false
	while t < model.pars.t_max

		step_until!(model, t) # run internal scheduler up to the next time step
		
		# we want the analysis to happen at every integral time step
		if (now = trunc(Int, t)) >= last
			# in case we skipped a step (shouldn't happen, but just in case...)
			for i in last:now
				# print all stats to file
				#print_stats(logfile, model)
				# this is suboptimal, as all these are calculated in print_stats as well
				# solution forthcoming
			end
			# remember when we did the last data output
			last = now
		end

		t += step

		println(t, " ", model.N)
	end
end


function prepare_outfiles(fname)
	logfile = open(fname, "w")
	#print_header(logfile, Data)
	logfile
end

const allpars, args = load_parameters(ARGS, Pars) #=, cmdl = ( 
    ["--log-freq"],
    Dict(:help => "set time steps between log calls", :default => 23*60, :arg_type => Int),
    ["--output", "-o"],
    Dict(:help => "set data output file name", :default => "data.tsv", :arg_type => String)))
    =#
    
const p = allpars[1]

Random.seed!(p.seed)


## setup

const model = setup(p)

const logf = prepare_outfiles("log_file.txt")

## run

run(model, logf)


## cleanup

close(logf)

