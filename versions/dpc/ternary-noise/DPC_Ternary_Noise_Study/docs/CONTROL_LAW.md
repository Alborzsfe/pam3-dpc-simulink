# Executable control law and assumptions

This is a new, explicitly defined ternary DPC adaptation. It is not a literal
PAM3 communication receiver, nor a claimed reproduction of a published
nine-state controller. The professor requested independent zero-state handling
and an original-controller limit; the previously supplied binary-hold adapter
did not provide that functionality.

## Source conventions

The supplied chart_29.xml selects upper legs A,B,C using binary sp,sq and
sectors 1..12. The exact four rows are transcribed in dpc3_original_table.m and
independently extracted from the actual SLX by the Python fixture generator.
Native preflight COPIES that original MATLAB Function chart as its reference.

Power measurement in the supplied system_49.xml is:

P = 1.5*(e_alpha*i_alpha + e_beta*i_beta)

Q = 1.5*(e_beta*i_alpha - e_alpha*i_beta)

The amplitude-invariant Clarke transform is used. Gate order is the actual
source mux order: [A,1-A,B,1-B,C,1-C]. Vector IDs in this package are 4A+2B+C;
they are not the V1..V6 numbering of particular DPC publications.

## Classifiers

Input errors are P_ref-P and Q_ref-Q, directly in W and var. Outer thresholds
come from the original source Relays. Let center=(on+off)/2, h=(on-off)/2,
inner=0.5*h. The classifier output is +1 above center+h, -1 below center-h;
otherwise retain +1 while error>center+inner or -1 while error<center-inner;
otherwise output zero. Initial state is zero. Large opposite-sign errors
switch immediately. No slope detector, ADC saturation, spike filter, symbol
clock or two-sample lookahead is present in the power-control path.

The proposed ternary classifier above uses its explicitly defined strict
outer comparisons. The ORIGINAL native binary Relay is a separate block:
the user's actual R2024b capture switches on at error >= +1 and off at
error <= -1, retaining its previous bit strictly inside (-1,+1). Revision 2
corrects the independent binary oracle to these inclusive comparisons and
regenerates dependent native gate/audit fixtures. Native source Relays and
the proposed ternary controller implementation are not changed by this fix.

## Physically defined new rows

The eight bridge leg vectors are enumerated. For balanced grid voltage and a
filter with L=15 mH and R=0.2 ohm, the one-step current is predicted with the
DC voltage frozen during Ts. Define complex E=e_alpha+j e_beta,
I=i_alpha+j i_beta, U=u_alpha+j u_beta, rho=exp(j*omega*Ts),
a=exp(-R*Ts/L), b=(1-a)/R (or Ts/L when R=0).

I_next = a*I + E*(rho-a)/(R+j*omega*L) - b*U

E_next = rho*E

P_next+j*Q_next = 1.5*E_next*conj(I_next)

This integrates the RL equation exactly under the stated frozen-vector,
frozen-DC, balanced sinusoidal-source assumptions. The SPS plant is nonideal;
prediction error from switch conduction, source sampling and DC variation is
not claimed absent. This model is not validated here for unbalanced/distorted
sources. Parameters are explicit rather than adapted from hidden labels.

For each of the nine state pairs (sP,sQ), indexed
row=1+3*(sP+1)+(sQ+1), the desired increment is

delta_target = [sP;sQ] .* max(abs([P_ref;Q_ref]-[P;Q]),[hP;hQ])

Thus a zero coordinate explicitly targets ZERO CHANGE of that power. No bit
hold is substituted for it. A finite set of single voltage vectors generally
cannot make both power derivatives exactly zero.

For a row containing zero, select the vector minimizing

J_hold = wP*((P_next-P-delta_target_P)/hP)^2
       + wQ*((Q_next-Q-delta_target_Q)/hQ)^2.

Numerical ties within 1e-12*max(1,J_min) choose the fewest changed upper legs,
then lowest binary vector ID. This is a tie rule, not a weighted switching-loss
objective; no loss improvement is claimed from switching frequency alone.

The four rows with no zero use the EXACT source table, with binary=(s+1)/2.
For the other five, a model-based guard compares squared normalized predicted
REFERENCE error to the vector from the source table and native Relay bits.
If the new choice has a larger one-step tracking cost, the source vector is
used. The guard decision is logged. This preserves a baseline candidate at
each zero-state step; it does NOT guarantee lower actual THD, lower ripple,
stability or globally non-worse closed-loop performance.

## Binary limit and bypass

With zero_state_enabled=false, each classifier outputs 2*b_native-1. The
original native Relays still receive exactly the original power errors and
share the controller sample time. The new table then uses only its original
four corners. The whole new actuation path must produce exactly the six gates
of the original table. Full-plant runs verify bit-exact gates and physical
signals within 1e-9 relative numerical tolerance over the configured interval.

The separate bypass mode routes the original native gate vector directly via
the selection switch. Native preflight verifies both routes on identical
inputs and verifies the normal ternary route against independent fixtures.

## Native model common changes

All modes use the same plant and logged output rates and sample the sector at
the controller period. This prevents sector transitions from producing extra
intersample control actions in the baseline. The continuous PI is retained
with fixed-step ode3; powergui and phase-C sine sampling use 1 us. Both source
sector-boundary gaps at -150 and -60 degrees are closed identically. The
measurement-only cleanup guards the original frequency monitor at t=0.
Source phase-C initial amplitude/frequency and powergui base frequency are
synchronized with the 50-Hz source settings for every mode.

## Audit vector (21 columns)

sp,sq,sector,row,vector_id,P,Q,predicted_delta_P,predicted_delta_Q,
predicted_reference_cost,original_reference_cost,guard_used,
vector IDs for rows 1..9.

The nominal CSV is only a review snapshot at 50 V phase RMS, Vdc=150 V,
P=400 W, Q=0, sector midpoints and specified requested power increments. The
runtime table depends on measured operating point, native Relay history and
previous applied legs. It is not a universal static 9-by-12 lookup table.
