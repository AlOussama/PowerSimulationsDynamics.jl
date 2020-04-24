function mdl_filter_ode!(
    device_states,
    output_ode,
    current_r,
    current_i,
    sys_Sbase,
    f0,
    ω_sys,
    device::PSY.DynamicInverter{C, O, IC, DC, P, PSY.LCLFilter},
) where {
    C <: PSY.Converter,
    O <: PSY.OuterControl,
    IC <: PSY.InnerControl,
    DC <: PSY.DCSource,
    P <: PSY.FrequencyEstimator,
}

    #Obtain external states inputs for component
    #TODO: If converter has dynamics, need to reference states:
    #external_ix = device.input_port_mapping[device.converter]
    #Vd_cnv = device_states[external_ix[1]]
    #Vq_cnv = device_states[external_ix[2]]
    external_ix = get_input_port_ix(device, PSY.LCLFilter)
    δ = device_states[external_ix[1]]

    #Obtain inner variables for component
    V_tR = get_inner_vars(device)[VR_inv_var]
    V_tI = get_inner_vars(device)[VI_inv_var]
    Vd_cnv = get_inner_vars(device)[Vd_cnv_var]
    Vq_cnv = get_inner_vars(device)[Vq_cnv_var]

    #Get parameters
    filter = PSY.get_filter(device)
    ωb = 2 * pi * f0
    lf = PSY.get_lf(filter)
    rf = PSY.get_rf(filter)
    cf = PSY.get_cf(filter)
    lg = PSY.get_lg(filter)
    rg = PSY.get_rg(filter)
    MVABase = PSY.get_inverter_Sbase(device)

    #RI to dq transformation
    V_ri_cnv = dq_ri(δ + pi / 2) * [Vd_cnv; Vq_cnv]
    V_g = sqrt(V_tR^2 + V_tI^2)

    #Obtain indices for component w/r to device
    local_ix = get_local_state_ix(device, PSY.LCLFilter)

    #Define internal states for filter
    internal_states = @view device_states[local_ix]
    Ir_cnv = internal_states[1]
    Ii_cnv = internal_states[2]
    Vr_filter = internal_states[3]
    Vi_filter = internal_states[4]
    Ir_filter = internal_states[5]
    Ii_filter = internal_states[6]

    #Inputs (control signals) - N/A

    #Compute 6 states ODEs (D'Arco EPSR122 Model)
    #Inverter Output Inductor (internal state)
    #𝜕id_c/𝜕t
    output_ode[local_ix[1]] = (
        ωb / lf * V_ri_cnv[1] - ωb / lf * Vr_filter - ωb * rf / lf * Ir_cnv +
        ωb * ω_sys * Ii_cnv
    )
    #𝜕iq_c/𝜕t
    output_ode[local_ix[2]] = (
        ωb / lf * V_ri_cnv[2] - ωb / lf * Vi_filter - ωb * rf / lf * Ii_cnv -
        ωb * ω_sys * Ir_cnv
    )
    #LCL Capacitor (internal state)
    #𝜕vd_o/𝜕t
    output_ode[local_ix[3]] =
        (ωb / cf * Ir_cnv - ωb / cf * Ir_filter + ωb * ω_sys * Vi_filter)
    #𝜕vq_o/𝜕t
    output_ode[local_ix[4]] =
        (ωb / cf * Ii_cnv - ωb / cf * Ii_filter - ωb * ω_sys * Vr_filter)
    #Grid Inductance (internal state)
    #𝜕id_o/𝜕t
    output_ode[local_ix[5]] = (
        ωb / lg * Vr_filter - ωb / lg * V_tR - ωb * rg / lg * Ir_filter +
        ωb * ω_sys * Ii_filter
    )
    #𝜕iq_o/𝜕t (Multiply Vq by -1 to lag instead of lead)
    output_ode[local_ix[6]] = (
        ωb / lg * Vi_filter + ωb / lg * V_tI - ωb * rg / lg * Ii_filter -
        ωb * ω_sys * Ir_filter
    )

    #Update inner_vars
    get_inner_vars(device)[Vd_filter_var] = Vr_filter
    get_inner_vars(device)[Vq_filter_var] = Vi_filter
    #TODO: If PLL models at PCC, need to update inner vars:
    #get_inner_vars(device)[Vd_filter_var] = V_dq[q::dq_ref]
    #get_inner_vars(device)[Vq_filter_var] = V_dq[q::dq_ref]

    #Compute current from the inverter to the grid
    I_RI = (MVABase / sys_Sbase) * [Ir_filter; Ii_filter]
    #Update current
    current_r[1] += I_RI[1]
    current_i[1] += I_RI[2]
end
