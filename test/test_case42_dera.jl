"""
Case 42:
This case study a three bus system with one AggregateDistributedGenerationA model, one load, and one infinite source.
The fault drops the line connecting the infinite bus and AggregateDistributedGenerationA.

"""
##################################################
############### LOAD DATA ########################
##################################################

raw_file = joinpath(TEST_FILES_DIR, "benchmarks/psse/DERA/ThreeBusMulti.raw")

##################################################
############### SOLVE PROBLEM ####################
##################################################

names = ["DERA: FreqFlag=0", "DERA: FreqFlag=1"]

#TODO - include set of dyr values once parser includes DERA.
FreqFlag_values = [0, 1]

tspan = (0.0, 4.0)

function test_dera_residual(freqflag_value)
    path = (joinpath(pwd(), "test-psse-dera"))
    !isdir(path) && mkdir(path)
    try
        threebus_sys = System(raw_file; runchecks = false)
        for g in get_components(ThermalStandard, threebus_sys)
            g.bus.bustype == ACBusTypes.REF && remove_component!(threebus_sys, g)
        end
        add_source_to_ref(threebus_sys)
        for g in get_components(ThermalStandard, threebus_sys)
            case_dera = dera(g, freqflag_value)
            add_component!(threebus_sys, case_dera, g)
        end
        for l in get_components(PSY.StandardLoad, threebus_sys)
            transform_load_to_constant_impedance(l)
        end

        sim = Simulation(
            ResidualModel,
            threebus_sys,
            path,
            tspan,
            BranchTrip(2.0, Line, "BUS 1-BUS 2-i_1"),
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, IDA(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        t_psid = get_voltage_angle_series(results, 102)[1]
        θ_psid = get_voltage_angle_series(results, 102)[2]
        V_psid = get_voltage_magnitude_series(results, 102)[2]
        power = get_activepower_series(results, "generator-102-1")


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

function test_dera_massmatrix(freqflag_value)
    path = (joinpath(pwd(), "test-psse-dera"))
    !isdir(path) && mkdir(path)
    try
        threebus_sys = System(raw_file; runchecks = false)
        for g in get_components(ThermalStandard, threebus_sys)
            g.bus.bustype == ACBusTypes.REF && remove_component!(threebus_sys, g)
        end
        add_source_to_ref(threebus_sys)
        for g in get_components(ThermalStandard, threebus_sys)
            case_dera = dera(g, freqflag_value)
            add_component!(threebus_sys, case_dera, g)
        end
        for l in get_components(PSY.StandardLoad, threebus_sys)
            transform_load_to_constant_impedance(l)
        end

        sim = Simulation(
            MassMatrixModel,
            threebus_sys,
            path,
            tspan,
            BranchTrip(2.0, Line, "BUS 1-BUS 2-i_1"),
        )


        # Obtain small signal results for initial conditions
        small_sig = small_signal_analysis(sim)
        @test small_sig.stable


        # Solve problem
        @test execute!(sim, Rodas4(); dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        t_psid = get_voltage_angle_series(results, 102)[1]
        θ_psid = get_voltage_angle_series(results, 102)[2]
        V_psid = get_voltage_magnitude_series(results, 102)[2]
        power = get_activepower_series(results, "generator-102-1")


    finally
        @info("removing test files")
        rm(path; force = true, recursive = true)
    end
end

@testset "Test 42 DERA ResidualModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            freqflag_value = FreqFlag_values[ix]
            test_dera_residual(freqflag_value)
        end
    end
end

@testset "Test 42 DERA MassMatrixModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            freqflag_value = FreqFlag_values[ix]
            test_dera_massmatrix(freqflag_value)
        end
    end
end