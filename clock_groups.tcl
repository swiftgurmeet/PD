Asynchronous Clock Groups


Asynchronous clocks and unexpandable clocks cannot be safely timed. The timing paths between them can be ignored during analysis by using the set_clock_groups command.

set_clock_groups -name async_clk0_clk1 -asynchronous -group {clk0 usrclk itfclk} \
-group {clk1 gtclkrx gtclktx}

If the name of the generated clocks cannot be predicted in advance, use get_clocks -include_generated_clocks to dynamically retrieve them. The -include_generated_clocks option is an SDC extension. The previous example can also be written as:

set_clock_groups -name async_clk0_clk1 -asynchronous \
-group [get_clocks -include_generated_clocks clk0] \
-group [get_clocks -include_generated_clocks clk1]



Exclusive Clock Groups

Some designs have several operation modes that require the use of different clocks. The selection between the clocks is usually done with a clock multiplexer.

Such clocks are called exclusive clocks. Constrain them as such by using the options of set_clock_groups:

-logically_exclusive
-physically_exclusive

Exclusive Clock Groups Example

The output of clkmux drives the design clock tree.

Both clocks share the same clock tree and cannot exist at the same time.

You must enter the following constraint to disable the analysis between the two clocks:

set_clock_groups -name exclusive_clk0_clk1 -physically_exclusive \
-group clk0 -group clk1

The following options are equivalent in the context of AMD FPGAs:

-logically_exclusive
-physically_exclusive
