# Primary technical references

- Supplied source: `source_model/DPC_POWER_RAHMAN_original.slx`; original model retained unchanged.
- Patent digital core: US11405248B2, reconstructed in the earlier PAM3 project. This package reuses that core; the binary-hold interface is a new converter-control adaptation.
- MathWorks: Relay sample-time programmatic parameter: https://www.mathworks.com/help/simulink/slref/relay.html
- MathWorks: Stateflow.EMChart Script property: https://www.mathworks.com/help/stateflow/api/stateflow.emchart.html
- MathWorks: harmonic RMS THD definition: https://www.mathworks.com/help/simscape-electrical/ref/totalharmonicdistortion.html
- MathWorks: classic powergui FFT Analysis (R2024b installed documentation, Specialized Power Systems). Select a structure-with-time signal and match THD maximum frequency, not just plotted range.
- MATLAB `thd` returns dBc in its usual form. This package explicitly computes percent from coherent Fourier harmonic RMS amplitudes, avoiding unit ambiguity: https://www.mathworks.com/help/signal/ref/thd.html

These references support APIs and metric definitions; they do not validate the proposed controller's closed-loop performance.
