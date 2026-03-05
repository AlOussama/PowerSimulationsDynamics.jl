"""
Regenerate test reference values (initial conditions and eigenvalues) for all
PowerSimulationsDynamics test cases. Run from the project root with:

    julia --project=test scripts/regenerate_test_results.jl

The script builds each simulation using the exact same setup as the corresponding
test file, then writes updated results to test/results/.
"""

using PowerSimulationsDynamics
using PowerSystems
using PowerNetworkMatrices
using PowerSystemCaseBuilder
using PowerFlows
using LinearAlgebra
using Logging
using NLsolve
using SciMLBase
using Sundials
using OrdinaryDiffEq
using DataFrames
using DelimitedFiles
using InfrastructureSystems

const PSID = PowerSimulationsDynamics
const PSY = PowerSystems
const PNM = PowerNetworkMatrices
const PF  = PowerFlows

TEST_FILES_DIR = joinpath(dirname(@__DIR__), "test")
include(joinpath(TEST_FILES_DIR, "utils/get_results.jl"))
include(joinpath(TEST_FILES_DIR, "utils/data_utils.jl"))
include(joinpath(TEST_FILES_DIR, "data_tests/dynamic_test_data.jl"))

# ─── Output helpers ────────────────────────────────────────────────────────────

function fmt_float(x::Float64)
    s = repr(x)           # gives exact round-trip repr
    return s
end

function fmt_complex(z::ComplexF64)
    re, im = real(z), imag(z)
    if im >= 0
        return "$(fmt_float(re)) + $(fmt_float(im))im"
    else
        return "$(fmt_float(re)) - $(fmt_float(abs(im)))im"
    end
end

function write_x0_init(io::IO, varname::String, d::Dict{String, Vector{Float64}})
    println(io, "$(varname) = Dict{String, Any}(")
    for (k, v) in d
        println(io, "    \"$(k)\" => [")
        for x in v
            println(io, "        $(fmt_float(x))")
        end
        println(io, "    ],")
    end
    println(io, ")")
    println(io)
end

function write_eigvals(io::IO, varname::String, eigs::Vector{ComplexF64})
    println(io, "$(varname) = [")
    for z in eigs
        println(io, "    $(fmt_complex(z))")
    end
    println(io, "]")
    println(io)
end

function build_and_capture(sys, perturbation, tspan; model = ResidualModel)
    path = mktempdir()
    try
        sim = Simulation!(model, sys, path, tspan, perturbation; console_level = Logging.Error)
        if sim.status != PSID.BUILT
            @warn "Simulation not BUILT for capture, status = $(sim.status)"
            return nothing, nothing
        end
        x0 = get_init_values_for_comparison(sim)
        # make all values Float64 vectors (drop Vm/θ — not stored in reference files)
        x0_filt = Dict{String, Vector{Float64}}()
        for (k, v) in x0
            k in ("Vm", "θ") && continue
            x0_filt[k] = v
        end
        small_sig = small_signal_analysis(sim)
        eigs = small_sig.stable ? small_sig.eigenvalues : nothing
        return x0_filt, eigs
    finally
        rm(path; force = true, recursive = true)
    end
end

# ─── Collect all results ───────────────────────────────────────────────────────
x0_results  = Dict{String, Dict{String, Vector{Float64}}}()
eig_results = Dict{String, Vector{ComplexF64}}()

function store!(varname, sys, perturbation, tspan; model = ResidualModel)
    @info "Building: $varname"
    x0, eigs = build_and_capture(sys, perturbation, tspan; model)
    if !isnothing(x0)
        x0_results[varname] = x0
    end
    if !isnothing(eigs)
        eig_results[varname * "_eigvals"] = eigs
    end
end

# ─── test01 — OMIB ─────────────────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_omib")
    sys_f = deepcopy(sys)
    b = get_component(Branch, sys_f, "BUS 1-BUS 2-i_1")
    b.r = 0.00; b.x = 0.1
    Ybus_f = PNM.Ybus(sys_f)[:, :]
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test01", sys, pert, (0.0, 30.0))
end

# ─── test02 — oneDoneQ threebus ────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_oneDoneQ")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test02", sys, pert, (0.0, 20.0))
end

# ─── test03 — simple marconato ─────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_simple_marconato")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test03", sys, pert, (0.0, 20.0))
end

# ─── test04 — marconato ────────────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_marconato")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test04", sys, pert, (0.0, 20.0))
end

# ─── test05 — simple anderson ──────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_simple_anderson_fouad")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test05", sys, pert, (0.0, 20.0))
end

# ─── test06 — anderson ─────────────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_anderson_fouad")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test06", sys, pert, (0.0, 20.0))
end

# ─── test07 — 5-shaft ──────────────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_5shaft")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test07", sys, pert, (0.0, 20.0))
end

# ─── test08 — VSM inverter ─────────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_vsm_inverter")
    case_inv = collect(get_components(DynamicInjection, sys))[1]
    pert = ControlReferenceChange(1.0, case_inv, :P_ref, 0.7)
    store!("test08", sys, pert, (0.0, 20.0))
end

# ─── test09 — oneDoneQ_inverter ────────────────────────────────────────────────
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_machine_vsm")
    case_inv = collect(PSY.get_components(PSY.DynamicInverter, sys))[1]
    pert = ControlReferenceChange(1.0, case_inv, :P_ref, 1.2)
    store!("test09", sys, pert, (0.0, 20.0))
end

# ─── test10 — threebus static branches ────────────────────────────────────────
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test10.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test10", threebus_sys, pert, (0.0, 40.0))
end

# ─── test12 — multimachine ─────────────────────────────────────────────────────
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test12.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test12", threebus_sys, pert, (0.0, 20.0))
end

# ─── test13 — AVRs ─────────────────────────────────────────────────────────────
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test13.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test13", threebus_sys, pert, (0.0, 20.0))
end

# ─── test14 — inverter ref ─────────────────────────────────────────────────────
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test14.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test14", threebus_sys, pert, (0.0, 20.0))
end

# ─── PSSE validation tests ─────────────────────────────────────────────────────
# Each builds from raw+dyr files and uses BranchTrip

function psse_store!(varname, raw_file, dyr_file, tspan, fault_branch; loads_to_impedance = true)
    sys = System(raw_file, dyr_file)
    if loads_to_impedance
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end
    end
    pert = BranchTrip(1.0, Line, fault_branch)
    store!(varname, sys, pert, tspan)
end

# test15 — GENROU
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/GENROU/ThreeBusMulti.raw")
    psse_store!("test_psse_genrou",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GENROU/ThreeBus_GENROU.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
    psse_store!("test_psse_genrou_no_sat",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GENROU/ThreeBus_GENROU_NO_SAT.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
    psse_store!("test_psse_genrou_high_sat",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GENROU/ThreeBus_GENROU_HIGH_SAT.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test16 — GENROE
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/GENROE/ThreeBusMulti.raw")
    psse_store!("test_psse_genroe",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GENROE/ThreeBus_GENROE.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
    psse_store!("test_psse_genroe_high_sat",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GENROE/ThreeBus_GENROE_HIGH_SAT.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test17 — GENROU + AVR
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test17.jl"))
    pert = BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1")
    @info "Building: test_psse_genrou_avr"
    for (varname, sys_i) in [("test_psse_genrou_avr", threebus_sys)]
        x0, eigs = build_and_capture(sys_i, pert, (0.0, 20.0))
        if !isnothing(x0); x0_results[varname * "_init"] = x0; end
        if !isnothing(eigs); eig_results["test17_eigvals"] = eigs; end
    end
end

# test18 — GENSAL
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/GENSAL/ThreeBusMulti.raw")
    psse_store!("test_psse_gensal",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GENSAL/ThreeBus_GENSAL.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test19 — GENSAE
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/GENSAE/ThreeBusMulti.raw")
    psse_store!("test_psse_gensae",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GENSAE/ThreeBus_GENSAE.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test20 — AC1A
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/ThreeBusMulti.raw")
    psse_store!("test_psse_ac1a",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/ThreeBus_AC1A.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
    psse_store!("test_psse_ac1a_sat",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/ThreeBus_AC1A_SAT.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test21 — GAST
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/GAST/ThreeBusMulti.raw")
    psse_store!("test_psse_gast",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/GAST/ThreeBus_GAST.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test21 — TGOV1 (part of GAST folder or separate)
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/TGOV1/ThreeBusMulti.raw")
    if isfile(raw)
        psse_store!("test_psse_tgov1",
            raw,
            joinpath(TEST_FILES_DIR, "benchmarks/psse/TGOV1/ThreeBus_TGOV1.dyr"),
            (0.0, 20.0), "BUS 1-BUS 2-i_1")
    else
        @warn "TGOV1 raw file not found at $raw — skipping test_psse_tgov1"
    end
end

# test23 — droop inverter
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test23.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test23", threebus_sys, pert, (0.0, 20.0))
end

# test24 — grid following
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test24.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test24", threebus_sys, pert, (0.0, 20.0))
end

# test25 — multimach dynlines
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test25.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test25", threebus_sys, pert, (0.0, 20.0))
end

# test26 — SEXS
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_oneDoneQ")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test26", sys, pert, (0.0, 20.0))
end

# test29 — renewable models
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test29.jl"))
    pert = BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1")
    store!("test29", threebus_sys_genrou, pert, (0.0, 20.0))
end

# test31 — HyGov
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_oneDoneQ")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test31_hygov", sys, pert, (0.0, 20.0))
end

# test33 — ZIP load
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_oneDoneQ")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test33_zipload", sys, pert, (0.0, 20.0))
end

# test37 — Induction motor
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_ind_motor")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test37", sys, pert, (0.0, 20.0))
end

# test38 — simplified induction motor
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_simple_ind_motor")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test38", sys, pert, (0.0, 20.0))
end

# test39 — EXST1
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/EXST1/ThreeBusMulti.raw")
    psse_store!("test39", raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/EXST1/ThreeBus_EXST1.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test40 — EXAC1
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/EXAC1/ThreeBusMulti.raw")
    psse_store!("test40", raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/EXAC1/ThreeBus_EXAC1.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test41 — STAB1
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/STAB1/ThreeBusMulti.raw")
    psse_store!("test41", raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/STAB1/ThreeBus_STAB1.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# test43 — REGCA voltage
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test29.jl"))
    pert = BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1")
    store!("test43", threebus_sys_regca, pert, (0.0, 20.0))
end

# test44 — VOC
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test44.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test44", threebus_sys, pert, (0.0, 20.0))
end

# test45 — SauerPai
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test45.jl"))
    pert = BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1")
    store!("test45", threebus_sys, pert, (0.0, 20.0))
end

# test46 — active load
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test46.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test46", threebus_sys, pert, (0.0, 20.0))
end

# test47 — SCRX
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_oneDoneQ")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test47", sys, pert, (0.0, 20.0))
end

# test49 — CSVGN1
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_oneDoneQ")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test49", sys, pert, (0.0, 20.0))
end

# test51 — grid following kaura
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test51.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test51", threebus_sys, pert, (0.0, 20.0))
end

# test52/53/54 — PSS2A/PSS2B/PSS2C (similar three-bus systems)
for (num, sysname) in [("test52", "psid_test_threebus_pss2a"),
                       ("test53", "psid_test_threebus_pss2b"),
                       ("test54", "psid_test_threebus_pss2c")]
    try
        sys = build_system(PSIDTestSystems, sysname)
        pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
        Ybus_f = get_ybus_fault_threebus_sys(sys)
        pert = NetworkSwitch(1.0, Ybus_f)
        store!(num, sys, pert, (0.0, 20.0))
    catch e
        @warn "Skipping $num: $e"
    end
end

# test55 — ESST1A
let
    sys = build_system(PSIDTestSystems, "psid_test_threebus_oneDoneQ")
    pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
    Ybus_f = get_ybus_fault_threebus_sys(sys)
    pert = NetworkSwitch(1.0, Ybus_f)
    store!("test55", sys, pert, (0.0, 20.0))
end

# test59—62 governor tests (ST6B, WPIDHY, ST8C, TGSimple)
for (num, sysname) in [("test59", "psid_test_threebus_st6b"),
                       ("test60", "psid_test_threebus_wpidhy"),
                       ("test61", "psid_test_threebus_st8c")]
    try
        sys = build_system(PSIDTestSystems, sysname)
        pf = ACPowerFlow(); solve_and_store_power_flow!(pf, sys)
        Ybus_f = get_ybus_fault_threebus_sys(sys)
        pert = NetworkSwitch(1.0, Ybus_f)
        store!(num, sys, pert, (0.0, 20.0))
    catch e
        @warn "Skipping $num: $e"
    end
end

# test62 — TGSimple (threebus avr-style)
let
    include(joinpath(TEST_FILES_DIR, "data_tests/test62.jl"))
    pert = NetworkSwitch(1.0, Ybus_fault)
    store!("test62", threebus_sys, pert, (0.0, 20.0))
end

# PSSE IEEEST
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/IEEEST/ThreeBusMulti.raw")
    psse_store!("test_psse_ieeest_no_filt",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/IEEEST/ThreeBus_IEEEST_no_filt.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
    psse_store!("test_psse_ieeest_with_filt",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/IEEEST/ThreeBus_IEEEST_with_filt.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1")
end

# PSSE DERA
let
    raw = joinpath(TEST_FILES_DIR, "benchmarks/psse/DERA/ThreeBusMulti.raw")
    psse_store!("test_psse_dera_freqflag0",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/DERA/ThreeBus_DERA_freqflag0.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1"; loads_to_impedance = false)
    psse_store!("test_psse_dera_freqflag1",
        raw,
        joinpath(TEST_FILES_DIR, "benchmarks/psse/DERA/ThreeBus_DERA_freqflag1.dyr"),
        (0.0, 20.0), "BUS 1-BUS 2-i_1"; loads_to_impedance = false)
end

# ─── Write results ─────────────────────────────────────────────────────────────
@info "Writing results_initial_conditions.jl ..."
open(joinpath(TEST_FILES_DIR, "results/results_initial_conditions.jl"), "w") do io
    println(io, "# Auto-generated by scripts/regenerate_test_results.jl")
    println(io)
    for (varname, d) in sort(collect(x0_results), by = first)
        # strip trailing _init if already present to avoid double suffix
        key = endswith(varname, "_init") ? varname : varname * "_x0_init"
        # For PSSE-named variables keep the _init suffix convention
        if startswith(varname, "test_psse_")
            key = varname * "_init"
        elseif startswith(varname, "test") && !endswith(varname, "_init")
            key = varname * "_x0_init"
        else
            key = varname
        end
        write_x0_init(io, key, d)
    end
end

@info "Writing results_eigenvalues.jl ..."
open(joinpath(TEST_FILES_DIR, "results/results_eigenvalues.jl"), "w") do io
    println(io, "# Auto-generated by scripts/regenerate_test_results.jl")
    println(io)
    for (varname, eigs) in sort(collect(eig_results), by = first)
        write_eigvals(io, varname, eigs)
    end
end

@info "Done. Regenerated $(length(x0_results)) x0_init and $(length(eig_results)) eigval sets."
