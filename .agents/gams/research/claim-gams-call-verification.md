# Claim verification: GAMS command-line invocation

Claim: `gams myfile` searches for the file (or myfile.gms), compiles+executes,
produces myfile.lst by default; params passed as `gams myfile key1=value1 key2=value2`.

Source (primary): https://www.gams.com/latest/docs/UG_GamsCall.html

Verbatim support:
- "The simplest way to start GAMS from a command shell is to enter the following
  command from the system prompt: `> gams myfile`"
- "GAMS will compile and execute the GAMS statements in the file `myfile`. If a
  file with this name cannot be found, GAMS will look for a file with the extended
  name `myfile.gms`. During the run GAMS will print a log to the console and create
  a listing file that is written by default to the file `myfile.lst`."
- "The syntax of the simple GAMS call is extended as follows:
  `> gams myfile key1=value1 key2=value2 ...`"

Verdict: NOT REFUTED. Fully supported, primary source, current docs.
