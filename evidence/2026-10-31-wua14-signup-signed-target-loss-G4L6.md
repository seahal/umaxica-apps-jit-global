# APP signup signed target propagation probe

- HEAD: `336811e5072a93c0523e484f905082635b28f48f`.
- The worktree contained uncommitted changes, including the controller and tests.
- A temporary integration test used a session-bound, signed APP authentication path target for `/account`. The APP Email signup form action carried the token; a valid contact submission redirected to the Email OTP page without a `pt` query parameter. The probe passed (1 run, 4 assertions) and was removed afterward.
- This establishes the intermediate redirect behavior only. It does not prove loss of the eventual RP destination, validate all signed or unsigned inputs, or authorize changing the Location contract.
