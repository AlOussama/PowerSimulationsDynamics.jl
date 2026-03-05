"""
Validation PSSE/TGOV1:
This case study defines a three bus system with an infinite bus, GENROU+AC1A+GAST and a load.
The fault drop the line connecting the infinite bus and GENROU
"""

##################################################
############### SOLVE PROBLEM ####################
##################################################

raw_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/GAST/ThreeBusMulti.raw")
dyr_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/GAST/ThreeBus_GAST.dyr")

@testset "Test 21 GAST ResidualModel" begin
    path = mktempdir()
    try
        sys = System(raw_file, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation!(
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

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
        t = series[1]
        δ = series[2]

        # TODO: Test mechanical torque in PSSE
        series2 = get_mechanical_torque_series(results, "generator-102-1")

        # Obtain PSSE results

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 21 GAST MassMatrixModel" begin
    path = (joinpath(pwd(), "test-psse-gast"))
    !isdir(path) && mkdir(path)
    try
        sys = System(raw_file, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation!(
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

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
        t = series[1]
        δ = series[2]

        # TODO: Test mechanical torque in PSSE
        _, τm = get_mechanical_torque_series(results, "generator-102-1")
        _, Ir = get_source_real_current_series(results, "generator-101-1")
        _, Ii = get_source_imaginary_current_series(results, "generator-101-1")

        # Obtain PSSE results

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end