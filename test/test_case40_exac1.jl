"""
Test for AVR model : EXAC1 available in PSS/e
This case study defines a four bus system with an infinite bus in 1,
a GENSAL in bus 2 and a constant impedance load in bus 3
The GENSAL machine has the EXAC1 and a HYGOV.
The disturbance is the outage of one line between buses 1 and 4
"""
##################################################
############### LOAD DATA ########################
##################################################

raw_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/EXAC1/TVC_System_32.raw")
dyr_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/EXAC1/TVC_System.dyr")

sys = System(raw_file, dyr_file)
for l in get_components(PSY.StandardLoad, sys)
    transform_load_to_constant_impedance(l)
end

##################################################
############### SOLVE PROBLEM ####################
##################################################


@testset "Test 40 EXAC1 ResidualModel" begin
    path = joinpath(pwd(), "test-psse-exac1")
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem
        sim = Simulation(
            ResidualModel,
            sys, #system
            path,
            (0.0, 20.0), #time span
            BranchTrip(1.0, Line, "BUS1-BUS4-i_1"), #Type of Fault
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain results

        t_psid, v2_psid = get_voltage_magnitude_series(results, 2)
        _, v3_psid = get_voltage_magnitude_series(results, 3)
        _, ω_psid = get_state_series(results, ("generator-2-1", :ω))

        # Obtain PSSE results


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 40 EXAC1 MassMatrixModel" begin
    path = joinpath(pwd(), "test-psse-exac1")
    !isdir(path) && mkdir(path)
    try
        # Define Simulation Problem
        sim = Simulation(
            MassMatrixModel,
            sys, #system
            path,
            (0.0, 20.0), #time span
            BranchTrip(1.0, Line, "BUS1-BUS4-i_1"), #Type of Fault
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain results

        t_psid, v2_psid = get_voltage_magnitude_series(results, 2)
        _, v3_psid = get_voltage_magnitude_series(results, 3)
        _, ω_psid = get_state_series(results, ("generator-2-1", :ω))

        # Obtain PSSE results


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end