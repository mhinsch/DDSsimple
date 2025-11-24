
using SimpleDirectMediaLayer.LibSDL2

import Colors
using Colors: distinguishable_colors, RGB


include("run.jl")
include("analysis_gui.jl")

using SimpleGui

include("draw_gui.jl")

function pred(dat, reg)
	mi, ma = extrema(dat)
	[mi, ma] .* reg[1] .+ reg[2]
end


function run(model, gui, graphs1, graphs2, graphs3, logfile, max_step = 0.1)
	t = 1.0
	step = max_step
	last = 0

	pause = false
	quit = false
	one_frame = false
	fullscreen = false
    before_end = true
	while ! quit
		# don't do anything if we are in pause mode
        # switch to pause mode when t_max is reached
        if before_end && t > model.pars.t_max
            before_end = false
            pause = true
        end
		if pause && one_frame == false
			sleep(0.03)
		else
			one_frame = false
			t1 = time()
			step_until!(model, t) # run internal scheduler up to the next time step
		
			# we want the analysis to happen at every integral time step
			if (now = trunc(Int, t)) > last
				data = observe(Data, model.world, t, model.pars)
				ticker(stdout, data)
				ticker(logfile, data)
				# in case we skipped a step (shouldn't happen, but just in case...)
				for i in last:now
					set_data!(graphs1[1], [0.0, 0.0]) 
					set_data!(graphs1[2], data.distance_all, data.provision_all)
					set_data!(graphs1[3], data.distance_all, data.density_all./ccapacity(model.pars))
					set_data!(graphs1[4], pred(data.distance_all, data.cor_dist_store))
					set_data!(graphs1[5], data.distance_all, data.exchange_all)
					set_data!(graphs1[6], pred(data.distance_all, data.cor_dist_exch))
                    #=add_value!(graphs1[1], data.N.n)
					add_value!(graphs1[2], data.outside.n)
					add_value!(graphs1[3], data.donors.n)
					add_value!(graphs1[4], data.donees.n)=#

#					add_value!(graphs2[1], data.cor_cond_prov)
#					add_value!(graphs2[2], data.cor_dens_prov)
#					set_data!(graphs2[1], data.sample_relatedness, data.sample_coop_diff)
#					set_data!(graphs2[2], pred(data.sample_relatedness, data.cor_rel_coop))
					#set_data!(graphs2[1], [0.0, 0.0]) 
					#set_data!(graphs2[2], data.density_all, data.provision_all)
					#set_data!(graphs2[3], data.density_all, data.exchange_all)
					#set_data!(graphs2[4], data.density_all, data.storage_all)

					#add_value!(graphs3[1], data.coop.mean)
					#set_data!(graphs3[1], data.distance_all, data.condition_all)
					#set_data!(graphs3[2], data.distance_all, data.coop_all)

					add_value!(graphs3[1], data.meanlocrel_in.mean)
					add_value!(graphs3[2], data.maxlocrel_in.mean)
					add_value!(graphs3[3], data.meanlocrel_edge.mean)
					add_value!(graphs3[4], data.maxlocrel_edge.mean)
					add_value!(graphs3[5], data.pop_relatedness.mean)
					#=set_data!(graphs3[1], map(enumerate(data.dist.bins)) do (i,d)
						d/(2*i+4.5)
						end)=#
				end
				# remember when we did the last data output
				last = now
			end

			t += step

			# measure (real-world) time it took to simulate one step
			dt = time() - t1

			# adjust simulation step size
			if dt > 0.1
				step /= 1.1
			elseif dt < 0.03 && step < max_step # this is a simple model, so let's limit
				step *= 1.1                # max step size to about 1
			end

			#println("p_ex: $(model.n_x / (model.n_x+model.n_no_x))")
		end

		event_ref = Ref{SDL_Event}()
        while Bool(SDL_PollEvent(event_ref))
            evt = event_ref[]
            evt_ty = evt.type
			if evt_ty == SDL_QUIT
                quit = true
                break
            elseif evt_ty == SDL_KEYDOWN
                scan_code = evt.key.keysym.scancode
                if scan_code == SDL_SCANCODE_ESCAPE || scan_code == SDL_SCANCODE_Q
					quit = true
					break
                elseif scan_code == SDL_SCANCODE_P || scan_code == SDL_SCANCODE_SPACE
					pause = !pause
                    break
                elseif scan_code == SDL_SCANCODE_F 
                	if fullscreen
                		SDL_SetWindowFullscreen(gui.window, 0)
                	else
                		SDL_SetWindowFullscreen(gui.window, SDL_WINDOW_FULLSCREEN)
                	end
                	fullscreen = !fullscreen
                    break
                elseif scan_code == SDL_SCANCODE_PERIOD
                	pause = true
                	one_frame = true
                else
                    break
                end
            end
		end

		# draw gui to video memory
		draw(model, graphs1, graphs2, graphs3, gui)
		# copy to screen
		render!(gui)
	end
end


const model, logf = prepare_model(ARGS) 

# two 640x640 panels next to each other
const gui = setup_Gui("SRM", 2000, 1002, (1, 1:3), (2, 1), (2, 2), (2,3))

const rawcolors = distinguishable_colors(8, [RGB(1,1,1), RGB(0,0,0)], dropseed=true)
const colors = map(c->(Colors.red(c), Colors.green(c), Colors.blue(c)).*255, rawcolors)

const graphs1 = [
	Graph{Float64}(WHITE, ""), 
	Graph{Float64}(rgb(255, 198, 0), "dist -> prov", method=:scatter),
	Graph{Float64}(rgb(255, 0, 200), "dist -> dens", method=:scatter),
	Graph{Float64}(rgb(255, 0, 200), ""),
	Graph{Float64}(rgb(0, 240, 255), "dist -> exch", method=:scatter),
	Graph{Float64}(rgb(0, 240, 255), "")]
#=	Graph{Int}(rgb(255, 255, 0), "N"),
	Graph{Int}(red(255), "N (out)"),
	Graph{Int}(rgb(0, 240, 255), "donors"),
	Graph{Int}(WHITE, "donees")] =#
const graphs2 = [
	Graph{Float64}(rgb(colors[1]...), "", method=:scatter), 
	Graph{Float64}(rgb(colors[2]...), "rel -> coop"),
	Graph{Float64}(rgb(0, 240, 255), "dens -> exch", method=:scatter),
	Graph{Float64}(rgb(255, 0, 200), "dens -> store", method=:scatter)]

const graphs3 = [
	Graph{Float64}(rgb(colors[1]...), "mean rel in"), 
	Graph{Float64}(rgb(colors[1]...), "max rel in"), 
	Graph{Float64}(rgb(colors[2]...), "mean rel edge"), 
	Graph{Float64}(rgb(colors[2]...), "max rel edge"), 
	Graph{Float64}(rgb(colors[3]...), "pop relatedness")] 
	#Graph{Float64}(rgb(255, 0, 200), "dist->condition", method=:scatter),
	#Graph{Float64}(rgb(255, 128, 0), "dist->coop", method=:scatter)]
	#Graph{Float64}(rgb(255, 128, 0), "mean coop")]
	#Graph{Float64}(rgb(255, 128, 0), "cond - prov", method=:scatter),
	#Graph{Float64}(rgb(0, 240, 255), "cond -> exch", method=:scatter)]
#const graphs3 = [Graph{Float64}(WHITE, "density", method = :scatter)]

run(model, gui, graphs1, graphs2, graphs3, logf)


close(logf)


SDL_Quit()
