"""
Test for PSS model : STAB1 available in PSS/e
This case study defines a two bus system with an infinite bus in 2,
and a GENSAL in bus 1.
The GENSAL machine has the SEXS and the STAB1 models
The small disturbance is a change of Vref in SEXS
The system is small-signal stable thanks to the PSS
"""
##################################################
############### LOAD DATA ########################
##################################################

raw_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/STAB1/OMIB_SSS.raw")
dyr_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/STAB1/OMIB_SSS.dyr")

sys = System(raw_file, dyr_file)
for l in get_components(PSY.StandardLoad, sys)
    transform_load_to_constant_impedance(l)
end

##################################################
############### SOLVE PROBLEM ####################
##################################################


@testset "Test 41 STAB1 ResidualModel" begin
    path = joinpath(pwd(), "test-psse-stab1")
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem

        gen = first(get_components(Generator, sys))
        dynamic_injector = get_dynamic_injector(gen)

        for g in get_components(Generator, sys)
            #Find the generator at bus 1
            if get_number(get_bus(g)) == 1
                gen = g
                dynamic_injector = get_dynamic_injector(g)
            end
        end

        perturbation = ControlReferenceChange(1.0, dynamic_injector, :V_ref, 1.0472)

        sim = Simulation(
            ResidualModel,
            sys,
            path,
            (0.0, 20.0), #time span
            perturbation,
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain results

        t_psid, v1_psid = get_voltage_magnitude_series(results, 1)
        _, ω_psid = get_state_series(results, ("generator-1-1", :ω))

        # Obtain PSSE results


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 41 STAB1 MassMatrixModel" begin
    path = joinpath(pwd(), "test-psse-stab1")
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem

        gen = first(get_components(Generator, sys))
        dynamic_injector = get_dynamic_injector(gen)

        for g in get_components(Generator, sys)
            #Find the generator at bus 1
            if get_number(get_bus(g)) == 1
                gen = g
                dynamic_injector = get_dynamic_injector(g)
            end
        end

        perturbation = ControlReferenceChange(1.0, dynamic_injector, :V_ref, 1.0472)

        sim = Simulation(
            MassMatrixModel,
            sys,
            path,
            (0.0, 20.0), #time span
            perturbation,
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain results

        t_psid, v1_psid = get_voltage_magnitude_series(results, 1)
        _, ω_psid = get_state_series(results, ("generator-1-1", :ω))

        # Obtain PSSE results


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end