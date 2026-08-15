* TEST-09 mutant for LINT-06. A Solve asserting modelStat only -- exactly the
* shape both payoff units carried before GATE-03. The trailing M.solveStat in
* the DISPLAY list is the point: it proves LINT-06's partner is not satisfied
* by a display argument, only by the symbol inside the abort$() condition.
* Linted only, never executed.
Variable obj, x;
Equation e; e.. obj =e= sqr(x - 3);
Model M / e /;
Solve M using nlp minimizing obj;
abort$(M.modelStat <> %modelStat.optimal%) "modelStat only", M.modelStat, M.solveStat;
