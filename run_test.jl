include("run.jl")

using Jeeps

function run_once(logfname, ovr)

    const model, logf = prepare_model(ARGS, logfname, ovr) 
    run_model(model, logf)
    close(logf)

end

const ps = ParamSpace(
    defaults = [
        :ini_coop => (1.0, 1.0),
        :move_mode => 2,
        :r_mut => 0.0],

    :r_exch => [0.0, 1.0],

    (:r_move, :theta_mig) => [
        (0.01, 20.0),
        (0.1, 2.0),
        (1.0, 0.2)],

    (:eff_prov_repr, :eff_prov_death) => [
        (1.0, 0.0),
        (0.5, 0.5),
        (0.0, 1.0) ],

    (:spread_weather, :rad_weather) => [
        (5.0, 15.0),
        (10.0, 30.0),
        (20.0, 60.0) ],

    :r_weather => [10, 20, 40],
    
    :r_weather_end => [0.1, 0.3, 0.9],

    :seed => 1:10
    )
    
    

