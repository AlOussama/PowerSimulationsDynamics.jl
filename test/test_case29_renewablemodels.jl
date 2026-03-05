"""
Case 29:
This case study a three bus system with 1 Generic Renewable Model (REPCA, REECB, REGCA) and an infinite source.
The fault drop the connection between buses 1 and 3, eliminating the direct connection between the load at bus 1
and the generator located in bus 3. The infinite generator is located at bus 2.
"""

##################################################
############### LOAD DATA ########################
##################################################

include(joinpath(TEST_FILES_DIR, "data_tests/test29.jl"))

##################################################
############### SOLVE PROBLEM ####################
##################################################

names = ["RENA: No Flags", "RENA: Freq Flag"]
F_flags = [0, 1]




# time span
tspan = (0.0, 5.0);

function test_renA_implicit(F_Flag)
    path = (joinpath(pwd(), "test-psse-renA"))
    !isdir(path) && mkdir(path)
    try
        sys = System(threebus_file_dir)
        add_source_to_ref(sys)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        for g in get_components(Generator, sys)
            case_gen = inv_generic_renewable(g, F_Flag)
            add_component!(sys, case_gen, g)
        end

        Ybus_change = BranchTrip(1.0, Line, "BUS 1-BUS 3-i_1")

        sim = Simulation(ResidualModel, sys, path, tspan, Ybus_change)


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(
            sim,
            IDA();
            dtmax = 0.005,
            saveat = 0.005,
            abstol = 1e-9,
            reltol = 1e-9,
        ) == PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for generator
        t, voltage = get_voltage_magnitude_series(results, 103)
        _, power = get_activepower_series(results, "generator-103-1")
        _, rpower = get_reactivepower_series(results, "generator-103-1")


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

function test_renA_mass_matrix(F_Flag)
    path = (joinpath(pwd(), "test-psse-renA"))
    !isdir(path) && mkdir(path)
    try
        sys = System(threebus_file_dir)
        add_source_to_ref(sys)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        for g in get_components(Generator, sys)
            case_gen = inv_generic_renewable(g, F_Flag)
            add_component!(sys, case_gen, g)
        end

        Ybus_change = BranchTrip(1.0, Line, "BUS 1-BUS 3-i_1")

        sim = Simulation(MassMatrixModel, sys, path, tspan, Ybus_change)


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(
            sim,
            Rodas4();
            dtmax = 0.005,
            saveat = 0.005,
            abstol = 1e-6,
            reltol = 1e-6,
        ) == PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for generator
        t, voltage = get_voltage_magnitude_series(results, 103)
        _, power = get_activepower_series(results, "generator-103-1")
        _, rpower = get_reactivepower_series(results, "generator-103-1")


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 29 RENA ResidualModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            #dyr_file = dyr_files[ix]
            F_flag = F_flags[ix]
            test_renA_implicit(F_flag)
        end
    end
end

@testset "Test 29 RENA MassMatrixModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            #dyr_file = dyr_files[ix]
            F_flag = F_flags[ix]
            test_renA_mass_matrix(F_flag)
        end
    end
end

"""
Case 29: Test with dyr files
This case study a three bus system with 1 Generic Renewable Model (REPCA, REECB, REGCA) and an infinite source.
The fault drop the connection between buses 1 and 3, eliminating the direct connection between the load at bus 1
and the generator located in bus 3. The infinite generator is located at bus 2.
"""

raw_file_dir = joinpath(TEST_FILES_DIR, "benchmarks/psse/RENA/ThreeBusRenewable.raw")

names_dyr = [
    "RENA: No F_Flag, Ref_Flag = 1, V_Flag = 1, Q_Flag = 0",
    "RENA: No F_Flag, Ref_Flag = 1, V_Flag = 0, Q_Flag = 0",
    "RENA: No F_Flag, Ref_Flag = 1, V_Flag = 1, Q_Flag = 1",
]


dyr_files = [
    joinpath(
        TEST_FILES_DIR,
        "benchmarks/psse/RENA/ThreeBus_REN_A_NOFREQFLAG_with_REF_FLAG.dyr",
    ),
    joinpath(
        TEST_FILES_DIR,
        "benchmarks/psse/RENA/ThreeBus_REN_A_NOFREQFLAG_with_REF_FLAG_no_V_FLAG.dyr",
    ),
    joinpath(
        TEST_FILES_DIR,
        "benchmarks/psse/RENA/ThreeBus_REN_A_NOFREQFLAG_with_REF_FLAG_Q_FLAG.dyr",
    ),
]



tspans = [(0.0, 10.0), (0.0, 10.0), (0.0, 20.0)]

function test_renA_implicit_dyr(dyr_file, tspan)
    path = (joinpath(pwd(), "test-psse-renA_dyr"))
    !isdir(path) && mkdir(path)
    try
        sys = System(raw_file_dir, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            sys, #system
            path,
            tspan, #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 3-i_1"), #Type of Fault
        ) #Type of Fault


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for generator
        t, voltage = get_voltage_magnitude_series(results, 103)
        _, angl = get_voltage_angle_series(results, 103)
        _, angl_ref = get_voltage_angle_series(results, 102)

        # Obtain data from PSS/E


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

function test_renA_massmatrix_dyr(dyr_file, tspan)
    path = (joinpath(pwd(), "test-psse-renA_dyr"))
    !isdir(path) && mkdir(path)
    try
        sys = System(raw_file_dir, dyr_file)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end

        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            sys, #system
            path,
            tspan, #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 3-i_1"), #Type of Fault
        ) #Type of Fault


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for generator
        t, voltage = get_voltage_magnitude_series(results, 103)
        _, angl = get_voltage_angle_series(results, 103)
        _, angl_ref = get_voltage_angle_series(results, 102)

        # Obtain data from PSS/E


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 29 RENA ResidualModel with dyr" begin
    for (ix, name) in enumerate(names_dyr)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            tspan = tspans[ix]
            test_renA_implicit_dyr(dyr_file, tspan)
        end
    end
end

@testset "Test 29 RENA MassMatrixModel with dyr" begin
    for (ix, name) in enumerate(names_dyr)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            tspan = tspans[ix]
            test_renA_massmatrix_dyr(dyr_file, tspan)
        end
    end
end