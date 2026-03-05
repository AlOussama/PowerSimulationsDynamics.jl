using PowerSimulationsDynamics, PowerSystems, PowerNetworkMatrices, PowerSystemCaseBuilder, PowerFlows, LinearAlgebra, Logging
const PSID = PowerSimulationsDynamics
const PSY = PowerSystems
const PNM = PowerNetworkMatrices

TEST_FILES_DIR = joinpath(dirname(@__DIR__), "test")
include(joinpath(TEST_FILES_DIR, "utils/get_results.jl"))
include(joinpath(TEST_FILES_DIR, "utils/data_utils.jl"))
include(joinpath(TEST_FILES_DIR, "data_tests/dynamic_test_data.jl"))
include(joinpath(TEST_FILES_DIR, "results/results_initial_conditions.jl"))
include(joinpath(TEST_FILES_DIR, "data_tests/test10.jl"))

Ybus_change = NetworkSwitch(1.0, Ybus_fault)
path = mktempdir()
sim = Simulation!(ResidualModel, threebus_sys, path, (0.0, 40.0), Ybus_change; console_level = Logging.Error)
res = get_init_values_for_comparison(sim)

println("VR_current = ", res["V_R"])
println("VR_stored  = ", test10_x0_init["V_R"])
println("VR_diff    = ", norm(res["V_R"] - test10_x0_init["V_R"]))
println("g102_curr  = ", res["generator-102-1"])
println("g102_store = ", test10_x0_init["generator-102-1"])
println("g102_diff  = ", norm(res["generator-102-1"] - test10_x0_init["generator-102-1"]))
println("g103_diff  = ", norm(res["generator-103-1"] - test10_x0_init["generator-103-1"]))
println("total_diff = ", sum(norm(get(res, k, zeros(length(v))) - v) for (k, v) in test10_x0_init))
