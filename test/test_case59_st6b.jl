"""
Validation PSSE/ST6B:
This case study defines a three bus system with an infinite bus, GENROU and a load.
The GENROU machine has connected an ST6B Excitation System.
The fault drop the line connecting the infinite bus and GENROU.
"""
##################################################
############### LOAD DATA ########################
##################################################

raw_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/ST6B/ThreeBusMulti.raw")
dyr_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/ST6B/ThreeBus_ST6B.dyr")
#csv_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/ST6B/results_PSSe.csv")

@testset "Test 59 ST6B ResidualModel" begin
    path = joinpath(pwd(), "test-psse-ST6B")
    !isdir(path) && mkdir(path)
    try
        # Define system
        sys = System(raw_file, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation(
            ResidualModel,
            sys, #system
            path,
            (0.0, 20.0), #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain results

        t_psid, v2_psid = get_voltage_magnitude_series(results, 102)
        _, v3_psid = get_voltage_magnitude_series(results, 103)
        _, ω_psid = get_state_series(results, ("generator-102-1", :ω))
        _, Vf = get_field_voltage_series(results, "generator-102-1")

        #=
        # Obtain PSSE results


        =#
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 59 ST6B MassMatrixModel" begin
    path = joinpath(pwd(), "test-psse-ST6B")
    !isdir(path) && mkdir(path)
    try
        # Define system
        sys = System(raw_file, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation(
            MassMatrixModel,
            sys, #system
            path,
            (0.0, 20.0), #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain results

        t_psid, v2_psid = get_voltage_magnitude_series(results, 102)
        _, v3_psid = get_voltage_magnitude_series(results, 103)
        _, ω_psid = get_state_series(results, ("generator-102-1", :ω))
        _, Vf = get_field_voltage_series(results, "generator-102-1")

        #=
        # Obtain PSSE results


        =#
    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end