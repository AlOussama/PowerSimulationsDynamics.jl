"""
Validation PSSE/ZIP:
This case study defines a three bus system with an infinite bus, GENROU and a load.
The fault drop the line connecting the infinite bus and GENROU.
"""

##################################################
############### SOLVE PROBLEM ####################
##################################################

names = ["ConstantPower", "ConstantCurrent"]
load_models = ["ConstantPower", "ConstantCurrent"]
raw_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/LOAD/ThreeBusMulti.raw")
dyr_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/LOAD/ThreeBus_GENROU.dyr")

initial_conditions = test33_zipload_x0_init

tspan = (0.0, 20.0)

function test_zipload_implicit(load_model)
    path = (joinpath(pwd(), "test-psse-zipload"))
    !isdir(path) && mkdir(path)
    try
        sys = System(raw_file, dyr_file)
        if load_model == "ConstantPower"
            for l in get_components(PSY.StandardLoad, sys)
                transform_load_to_constant_power(l)
            end
        else
            for l in get_components(PSY.StandardLoad, sys)
                transform_load_to_constant_current(l)
            end
        end

        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            sys,
            path,
            tspan,
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); abstol = 1e-9, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for voltages
        series = get_voltage_magnitude_series(results, 102)
        t_psid = series[1]
        v2_psid = series[2]
        _, v3_psid = get_voltage_magnitude_series(results, 103)


        #TODO: Test for LoadPower
        p = get_activepower_series(results, "load1031")

    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

function test_zipload_mass_matrix(load_model)
    path = (joinpath(pwd(), "test-psse-zipload"))
    !isdir(path) && mkdir(path)
    try
        sys = System(raw_file, dyr_file)
        if load_model == "ConstantPower"
            for l in get_components(PSY.StandardLoad, sys)
                transform_load_to_constant_power(l)
            end
        else
            for l in get_components(PSY.StandardLoad, sys)
                transform_load_to_constant_current(l)
            end
        end

        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            sys,
            path,
            tspan,
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); abstol = 1e-9, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for voltages
        series = get_voltage_magnitude_series(results, 102)
        t_psid = series[1]
        v2_psid = series[2]
        _, v3_psid = get_voltage_magnitude_series(results, 103)


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 33 ZIPLoad ResidualModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            load_model = load_models[ix]
            test_zipload_implicit(load_model)
        end
    end
end

@testset "Test 33 ZIPLoad ResidualModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            load_model = load_models[ix]
            test_zipload_mass_matrix(load_model)
        end
    end
end