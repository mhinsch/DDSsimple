
using SimpleDirectMediaLayer.LibSDL2

include("run.jl")

using SimpleGui

include("draw_gui.jl")



function run(model, gui, graphs1, graphs2, graphs3, logfile, max_step = 0.1)
	t = 1.0
	step = max_step
	last = 0

	pause = false
	quit = false
	while ! quit
		# don't do anything if we are in pause mode
		if pause
			sleep(0.03)
		else
			t1 = time()
			step_until!(model, t) # run internal scheduler up to the next time step
		
			# we want the analysis to happen at every integral time step
			if (now = trunc(Int, t)) >= last
				data = observe(Data, model.world, t, model.pars)
				# in case we skipped a step (shouldn't happen, but just in case...)
				for i in last:now
					# print all stats to file
					#print_stats(logfile, model)
					# this is suboptimal, as all these are calculated in print_stats as well
					# solution forthcoming
					add_value!(graphs1[1], data.N.n)
					add_value!(graphs1[2], data.outside.n)
					add_value!(graphs1[3], data.donors.n)
					add_value!(graphs1[4], data.donees.n)

					add_value!(graphs2[2], data.cor_cond_prov)
					add_value!(graphs2[3], data.cor_dens_prov)
					add_value!(graphs2[4], 0.0)

					set_data!(graphs3[1], map(enumerate(data.dist.bins)) do (i,d)
						d/(2*i+4.5)
						end)
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

			ticker(stdout, data)
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
const graphs1 = [Graph{Int}(green(255)), Graph{Int}(red(255)), Graph{Int}(blue(255)), Graph{Int}(WHITE)] 
const graphs2 = [Graph{Float64}(green(255)), Graph{Float64}(red(255)), Graph{Float64}(blue(255)), Graph{Float64}(WHITE)] 
const graphs3 = [Graph{Float64}(WHITE)]

run(model, gui, graphs1, graphs2, graphs3, logf)


close(logf)


SDL_Quit()
