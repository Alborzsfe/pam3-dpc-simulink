# DPC / PAM3 identical-input comparison

Read `README_FA.md` for the complete Persian guide. In MATLAB R2024b, extract the full project, set its root as Current Folder, load your original `Ts` and `e` parameters if available, and execute `START_DPC_COMPARISON`.

The script records errors and native dp/dq decisions from an instrumented copy of the supplied converter, then compares a sampled binary relay, a new control-oriented ternary adapter, and the existing full PAM3 decoder after static ADC calibration. It preserves the original converter gate path. Simscape Electrical Specialized Power Systems is needed to execute the supplied power model. The replay model uses MATLAB and Simulink only.

`START_SYNTHETIC_DEMO` runs a separately labelled educational example. `validate_dpc_simulink` executes replay tests against saved independent Python fixtures. Python is optional for fixture regeneration; it is not needed by the MATLAB workflow.

Saved local example results are actual GNU Octave executions of the MATLAB numerical core, with Python-rendered plots. No converter or new replay Simulink execution is claimed for this delivery. The previous standalone PAM3 model was separately reported by the user to pass in MATLAB R2024b, with 60 channel captures and 6975 symbols; that does not validate this new converter application.

See `docs/EXPERIMENT_DESIGN.md` for what this experiment can and cannot establish. `validation/DELIVERY_STATUS.json` records checks and execution boundaries.
