//+------------------------------------------------------------------+
//|                                             Risk Consistency.mq5 |
//|                                          Copyright 2024, Karry's |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Karry's"
#property link      "https://www.mql5.com"
#property version   "1.00"

input float Risk_Amount_Total = 1000;
input int MaxPositionsOpen = 3;
input bool Consider_for_next_order = false;



//
Idea, allow other EA open a position, but will adjust the risk immediately and close the latest opedn position., allow user to choose to close the most loss positions or latest position.


//
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+



void UpdateStopLossWithDividedRisk(double totalStopLossAmount)
{
    int totalPositions = PositionsTotal(); // Get total positions
    if (totalPositions <= 0)
    {
        //Print("No positions found to adjust consistent stop loss.");
        return;
    }

    // Divide the total stop loss amount equally among all positions
    double individualStopLossAmount = totalStopLossAmount / (totalPositions + 1);

    Print("Dividing total stop loss of ", totalStopLossAmount, " USD among ", totalPositions, 
          " positions. Each position gets ", individualStopLossAmount, " USD stop loss limit.");

    for (int i = 0; i < totalPositions; i++)
    {
        ulong positionTicket = PositionGetTicket(i);
        if (PositionSelectByTicket(positionTicket))
        {
            // Get position details
            string symbol        = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double volume        = PositionGetDouble(POSITION_VOLUME);
            double entryPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL     = PositionGetDouble(POSITION_SL);

            // Retrieve contract size
            double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            if (contractSize <= 0 || volume <= 0)
            {
                Print("Invalid contract size or volume for ", symbol);
                continue;
            }

            // Calculate stop loss adjustment based on individual USD risk
            double riskPerUnit = individualStopLossAmount / (volume * contractSize);
            double newStopLoss = 0.0;

            if (type == POSITION_TYPE_BUY) // Long Position
            {
                newStopLoss = entryPrice - riskPerUnit;
            }
            else if (type == POSITION_TYPE_SELL) // Short Position
            {
                newStopLoss = entryPrice + riskPerUnit;
            }
            else
            {
                Print("Unsupported position type for ticket: ", positionTicket);
                continue;
            }

            // Normalize stop loss to symbol's digits
            newStopLoss = NormalizeDouble(newStopLoss, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

            // Check if stop loss needs updating
            if (currentSL != newStopLoss)
            {
                if (PositionModify(positionTicket, newStopLoss))
                {
                    Print("Stop Loss updated for ", symbol, " Position Ticket: ", positionTicket, " to ", newStopLoss);
                }
                else
                {
                    Print("Failed to update Stop Loss for ", symbol, " Position Ticket: ", positionTicket, " Error: ", GetLastError());
                }
            }
            else
            {
                Print("Stop Loss unchanged for ", symbol, " Position Ticket: ", positionTicket);
            }
        }
    }
}

// Function to modify stop loss for a position
bool PositionModify(ulong positionTicket, double stopLoss)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);

    request.action   = TRADE_ACTION_SLTP;  // Modify SL/TP
    request.position = positionTicket;
    request.sl       = stopLoss;
    request.tp       = PositionGetDouble(POSITION_TP);  // Keep the TP unchanged

    if (!OrderSend(request, result))
    {
        Print("OrderSend failed. Error: ", GetLastError());
        return false;
    }
    return true;
}


double CalculateStopLossForNewOrder(double totalRiskCapital)
{
    double allocatedRisk = 0.0;
    int totalPositions = PositionsTotal();

    // Loop through existing positions to calculate allocated risk
    for (int i = 0; i < totalPositions; i++)
    {
        ulong positionTicket = PositionGetTicket(i);
        if (PositionSelectByTicket(positionTicket))
        {
            string symbol        = PositionGetString(POSITION_SYMBOL);
            double volume        = PositionGetDouble(POSITION_VOLUME);
            double entryPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
            double slPrice       = PositionGetDouble(POSITION_SL);

            // Skip positions without a stop loss
            if (slPrice == 0.0)
                continue;

            double contractSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double priceDifference = MathAbs(entryPrice - slPrice);

            // Calculate the risk allocated to this position in USD
            double positionRisk = volume * contractSize * priceDifference;
            allocatedRisk += positionRisk;
        }
    }

    // Calculate remaining risk capital
    double remainingRisk = totalRiskCapital - allocatedRisk;
    if (remainingRisk <= 0)
    {
        Print("No remaining risk capital available.");
        return 0.0; // No risk available
    }

    return remainingRisk;
}
