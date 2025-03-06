
using MiniEvents

include("util.jl")
include("processes.jl")
include("main_util.jl")
include("analysis.jl")


function run_model(model, logfile, step = 1.0)
	t = 1.0

	while t < model.pars.t_max
		step_until!(model, t) # run internal scheduler up to the next time step
	    data = observe(Data, model.world, t, model.pars)
		ticker(stdout, data)
		
		t += step
	end
end


function prepare_outfiles(fname)
	logfile = open(fname, "w")
	#print_header(logfile, Data)
	logfile
end


function prepare_model(args, outf_name = "log_file.txt", override=nothing)
	allpars, args = load_parameters(args, Pars; override)      
	p = allpars[1]

	Random.seed!(p.seed)

	model = setup(p)

	logf = prepare_outfiles("log_file.txt")

	model, logf
end

