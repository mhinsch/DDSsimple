
"Model parameters"
@kwdef mutable struct Pars
	"world size x"
	sz_x :: Float64 = 1000.0
	"world size y"
	sz_y :: Float64 = 1000.0
	"initial pop size"
	n_ini :: Int = 200
	"y location of initial pop"
	ini_y :: Float64 = 100.0
	"x location of initial pop"
	ini_x :: Float64 = 100.0
    ini_coop :: Vector{Float64} = [0.0, 1.0]

	"max range of spatial effects (in multiple of sd)"
	effect_radius :: Float64 = 3.0
    
	"reproduction rate"
	r_repr :: Float64 = 0.1
	"natural ibackground mortality"
	r_death :: Float64 = 1.0/60.0
	"mortality under starvation"
	r_starve :: Float64 = 1.0
	"movement rate"
	r_move :: Float64 = 0.01
	"exchange rate"
	r_exch :: Float64 = 1.0
	
	"effect of provisioning on reproduction (0-1)"
	eff_prov_repr :: Float64 = 1.0
	"nonlinear effects of provision on reproduction (1=neutral)"
	shape_prov_repr :: Float64 = 1.0
	"effect of provisioning on death (0-1)"
	eff_prov_death :: Float64 = 0.0
	"nonlinear effects of provision on death (1=neutral)"
	shape_prov_death :: Float64 = 1.0
	
	"carrying capacity"
	capacity :: Float64 = 5.0
	"sd of influence of density"
	spread_density :: Float64 = 5.0

	"whether agents are stopped at the edge or disappear"
	open_edge :: Bool = true
	"distribution of step size: 1 - Uniform, 2 - Normal, 3 - Levy"
	move_mode :: Int = 3
	"mean step size"
	mu_mig :: Float64 = 0.0
	"sd of stepsize"
	theta_mig :: Float64 = 0.5
	"density dependence of move rate"
	dd_move :: Float64 = 0.0
	"offset of move rate for dd move"
	dd_r_move_0 :: Float64 = 0.5

	"exchange rate model: 1 - provision, 2 - local condition"
	exchange_mode :: Int = 1
	"sd of exchange distance"
	spread_exchange :: Float64 = 10
	"proportion of resources that get exchanged"
	prop_exchange :: Float64 = 0.5
	"efficiency of exchange"
	eff_exchange :: Float64 = 0.9
	"rate at which resources get reset to default"
	r_reset_prov :: Float64 = 1.0
	"whether to cap donations at amount needed"
	cap_donations :: Bool = false

	"'mutation' rate"
	r_mut :: Float64 = 0.05
	d_mut :: Float64 = 0.05
	
	"rate of appearance of weather effects"
	r_weather :: Float64 = 20
	"rate of disappearance of weather effects"
	r_weather_end :: Float64 = 0.3

	"sd of effect of weather"
	spread_weather :: Float64 = 10.0
	"min and max value of weather influence on capacity"
	wth_range :: Vector{Float64} = [-1.0, 0.0]

	"random seed"
	seed :: Int = 41
	"simulation time"
	t_max :: Float64 = 1000.0
end
