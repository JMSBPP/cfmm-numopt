$include primitives.gms

Scalar eta_x_y "Current elasticity between asset and cash";
eta_x_y = precision;

Set eta_x_yDomain / etaAboveZero, etaBelowOne /;

Parameter eta_x_yVal(eta_x_yDomain);

eta_x_yVal("etaAboveZero") = precision;
eta_x_yVal("etaBelowOne")  = unity - precision;


Set inventory / assetX, cashY /;
Set inventoryDomain / invPos /;

Parameter
    inventoryLo(inventory, inventoryDomain)
    inventoryUp(inventory, inventoryDomain);

inventoryLo(inventory,"invPos") = unity;
inventoryUp(inventory,"invPos") = uintMax;


Set poolLiquidity / liquidityL /;
Set poolLiquidityDomain / liqPos /;

Parameter
    poolLiquidityLo(poolLiquidity, poolLiquidityDomain)
    poolLiquidityUp(poolLiquidity, poolLiquidityDomain);

poolLiquidityLo(poolLiquidity,"liqPos") = unity;
poolLiquidityUp(poolLiquidity,"liqPos") = uintMax;


Positive Variable
    inv(inventory)
    poolL(poolLiquidity);

inv.lo(inventory) = inventoryLo(inventory,"invPos");
inv.up(inventory) = inventoryUp(inventory,"invPos");

poolL.lo(poolLiquidity) = poolLiquidityLo(poolLiquidity,"liqPos");
poolL.up(poolLiquidity) = poolLiquidityUp(poolLiquidity,"liqPos");


Equation poolLiquidityCone;

poolLiquidityCone..
    poolL("liquidityL") =e=
        inv("assetX") ** (eta_x_y / unity)
      * inv("cashY") ** (1 - eta_x_y / unity);



