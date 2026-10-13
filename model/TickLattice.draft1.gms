$if set INCLUDE_TICK_LATTICE $exit
$setGlobal INCLUDE_TICK_LATTICE 1


* REQUIREMENTS
*  Bound these values by the spacing and the max and low bounds
* We need to create a set on which the spacing is some tickSpacing and is bounded


* For simplicity start with a fixed finite size set of ticks , spaced by a given tick spacing
* This is the case of ticks which start at the value of a tick spacing and then moves to 2 times that tick spacing, and then 3 times that tick spacing

$onText
* TODO: This needs to be extended adaptively,
--> the documentation progress is https://gams.com/54/docs/UG_SetDefinition.html
$offText
Set Ticks /200, 400, 600/;





