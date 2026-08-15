* TEST-09 mutant for LINT-07. A Solve asserting solveStat only.
* Linted only, never executed.
Variable obj, x;
Equation e; e.. obj =e= sqr(x - 3);
Model M / e /;
Solve M using nlp minimizing obj;
abort$(M.solveStat <> %solveStat.normalCompletion%) "solveStat only", M.solveStat;
