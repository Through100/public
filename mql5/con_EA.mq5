#property copyright "KAI YI LIM"
#property description "EA designed for Forex trading, 15 minutes Period, focused on minimizing drawdown while maximizing profits."
#property version "1.0"

//Class
#include <Trade\Trade.mqh> // Include CTrade class

// Declare the CTrade object
CTrade trade;
CTrade ExtTrade;
//datetime end_date = D'2024.12.12'; // Set your end date here

int    ExtHandleEMA50 = 0;
int    ExtHandleEMA10 = 0;
int    ExtHandleEMA7 = 0;
//Declare Input Parameters
input group "Take Profit & Stop Loss (Percentage)"
input double global_profit_loss = 3; //Global TP & SL (Override four variables below, 0 = Disabled)
input double global_Stop_Loss_division = 1;  //Division
//input double Loss = 1.5;
input double custom_TakeProfitPercentLong = 0;   // Custom TP for Long (If Set, Set "Global TP & SL" value as 0 ) 
input double custom_StopLossPercentLong = 0; // Custom SL for Long (If Set, Set "Global TP & SL" value as 0 ) 
input double custom_TakeProfitPercentShort = 0;   // Custom TP for Short (If Set, Set "Global TP & SL" value as 0 ) 
input double custom_StopLossPercentShort = 0; // Custom SL for Short (If Set, Set "Global TP & SL" value as 0 ) 
//---

// Profit Limit Percentage Custom Long
static double ProfitPercentLong = custom_TakeProfitPercentLong;   
static double StopLossPercentLong = custom_StopLossPercentLong; // Stop Loss Percentage Custom Long
static double ProfitPercentShort = custom_TakeProfitPercentShort;   // Profit Limit Percentage Custom Short
static double StopLossPercentShort = custom_StopLossPercentShort; //

input group "Order Size in Percentage (Include Leverage)"
input double OrderPercentage = 80;     //Order Size (Max: 99%)

input group "Sharp"
input int BarBackCheckShort = 5; //BarBackCheckShort [4-10]
input int BarBackCheckLong = 8;  //BarBackCheckLong [4-10]
input int BarBackCheckVolatile = 3; //Bars range consider for Volatile and Exotic [4-10] 

input bool sharp_enabled = true;
input double VolatilityThreshold = 0.03;  // VolatilityThreshold [0.1 - 0.5] 
input double ConfidentThreshold = 0.03;  //ConfidentThreshold [0.1 - 0.8]
double SurgePercentage = VolatilityThreshold;
double SharpSurgePercentage = ConfidentThreshold;
double SinkPercentage = VolatilityThreshold;
double SharpDropPercentage = ConfidentThreshold;
input double Aggresive_level = 0.02;  //Aggresive level [0.1 - 0.8 "Higher mean less aggresive"]
input group "Support Resistance"
input int leftBars = 24; //Support and Resistance (LeftBar) [1-50]
input int rightBars = 13; //Support and Resistance (RightBar) [1-50]

input group "Prop Firm (Concurent Risk Consider)"
input bool Concurent_Risk_Capital = false;
input float Consistant_risk_capital = 5000;
input group "Prop Firm (Limit Profit)"
input bool LimitProfit = true;
input float profitLimitValue = 1000;
input group "Limit Opened Position)"
input int ConcurrentPositionAllowed = 3;
input group "Close on Pivot"
input bool CloseOnPivot = false;
input int CAP_Range = 4;
input group "Close Low Volatile"
input bool CloseLowVolatile = false;
input int CLV_Range = 5;
input float CLV_Percentage = 0.02;
input group "ADR"
input bool ADR_Enabled = false;
input int     adrLength = 12;                  // ADR Length
input double   smaThreshold = 0.017941;          // Threshold for SMA difference
static double smaDiff = 0;
int maHighHandle, maLowHandle;
input group "MA"
input bool MA_Enabled = true;
input int maPeriod20 = 20;
input int maPeriod50 = 28;
input int maPeriod80 = 80;
double ma20[2], ma50[2], ma80[1];
int ma20Handle, ma50Handle, ma80Handle;
input group "Offset_between_first_second_bar"
input bool Offset_Enabled = false;
input double offset = 0.01;
input group "Smart_stop_loss"
input bool smart_stop_loss_Enabled = true;
input int PivotLeft = 10;
input int PivotRight = 10;

double ema50hl2, ema10hl2, ema7hl2;
int period50 = 50;
int period10 = 10;
int period7 = 7;
double HL2;
static bool within_and_near_to_support = false;
static bool within_and_near_to_resist = false;
static bool on_top_of_support = false;
static bool far_below_resistance = false;
static bool double_on_top_of_support = false;
static bool double_far_below_resistance = false;

// Global Variables
double lastPivotHigh = EMPTY_VALUE;
double lastPivotLow  = EMPTY_VALUE;
static bool sharp_surge = NULL;
static bool sharp_sink = NULL;
static bool sharp_surge_prev1 = NULL;
static bool sharp_sink_prev1 = NULL;
static bool sharp_surge_prev2 = NULL;
static bool sharp_sink_prev2 = NULL;

static bool brought_long = false;
static bool brought_short = false;
static bool canclose = false;
static double brought_price = 0;
static double profit_price = 0;
static double stoplost_price = 0;
static double tp_level = 0;  // To store TP level globally
static double sl_level = 0;  // To store SL level globally
static bool sharp_surge_array_1;
static bool sharp_surge_array_2;
static bool sharp_surge_array_3;
static bool sharp_sink_array_1;
static bool sharp_sink_array_2;
static bool sharp_sink_array_3;
static double top = 0.0;  // Resistance level (Pivot High)
static double bot = 0.0;  // Support level (Pivot Low)
static int FirstBar = -1;
static double consistant_sl_level = 0;
static bool sharprise = false;
static bool sharpsink = false;
static bool sharp_ignore = false;
static bool offset_ignore = false;
static bool ssl_ignore = false;
static double existing_top = 0;
static double existing_low = 0;
#define MA_MAGIC 1234501

//+------------------------------------------------------------------+
//| Function to get HL2 value                                         |
//+------------------------------------------------------------------+
double GetHL2(int i)
{
    HL2 = (iHigh(Symbol(), PERIOD_CURRENT, i + 1) + iLow(Symbol(), PERIOD_CURRENT, i + 1)) / 2.0;
    return HL2;
}

void ResetPivots()
{
   lastPivotHigh = EMPTY_VALUE;
   lastPivotLow  = EMPTY_VALUE;
}

bool Close_After_Sharp()
{
   if(!CloseOnPivot) return(false);

   // 1) Long side: look for “new” pivothigh that beats the last
   if(brought_long)
   {
      double ph = MyPivotHigh(CAP_Range,1);
      if(ph != EMPTY_VALUE)
      {
         // first pivot OR higher than before?
         if(lastPivotHigh != EMPTY_VALUE && ph > lastPivotHigh)
         {
            CloseOpenPositions();//Close Profit
         }
         if(lastPivotHigh == EMPTY_VALUE || ph > lastPivotHigh)
         {
            lastPivotHigh = ph;            
         }
      }
   }

   // 2) Short side: look for “new” pivotlow that beats the last
   if(brought_short)
   {
      double pl = MyPivotLow(CAP_Range,1);
      if(pl != EMPTY_VALUE)
      {
         if(lastPivotLow != EMPTY_VALUE && pl < lastPivotLow)
         {
            CloseOpenPositions();//Close Profit
         }
         if(lastPivotLow == EMPTY_VALUE || pl < lastPivotLow)
         {
            lastPivotLow = pl;
            // … your code to act on the new pivot low, e.g.:
            //   PrintFormat("New pivot low: %.5f", pl);
            //   ExecuteSharpExitOnLow();
         }
      }
   }

   return(false);
}


bool Close_Low_Volatile()
{
   // Ensure the CloseLowVolatile option is enabled
   if (CloseLowVolatile)
   {
      bool is_CLV = false;
      // Validate that CLV_Range is valid
      if (CLV_Range < 2)
         return false; // Invalid range, return false by default

      // Initialize variables
      int low_volatile_count = 0; // Count of bars with low volatility
      double reference_price = GetHL2(CLV_Range); // Reference price for comparison

      // Loop through each bar in the range
      for (int i = CLV_Range - 1; i >= 1; i--)
      {
         // Get the price of the current bar
         double current_price = GetHL2(i);

         // Calculate the absolute percentage difference
         double percentage_difference = fabs((current_price - reference_price) / reference_price) * 100;

         // Check if the percentage difference is below the threshold
         if (percentage_difference < CLV_Percentage)
         {
            low_volatile_count++; // Increment low-volatility bar count


         }
         else
         {
            // If any bar exceeds the threshold, exit early (optimization)
            break;
         }
      }
                 // If all bars in the range are low volatile, return true early
     if (low_volatile_count >= CLV_Range/2)
     {
               //return true;
     is_CLV = true;
     }
     if (is_CLV == true && brought_long && brought_price < GetHL2(1) )
     {
         return true;
     }
     
     if (is_CLV == true && brought_short && brought_price > GetHL2(1) )
     {
         return true;
     }     
     
      // If we finish the loop and not all bars are low volatile, return false
      return false;
   }

   return false; // Default return if CloseLowVolatile is disabled
}


void CheckSharpConditions()
{
    long i = 0; // Get the last index (most recent bar) // 1 is best

    // Calculate hl2 dynamically using GetHL2 function
    double hl2_value = GetHL2(0); 
 

    
    // Sharp Surge Condition
    double surgePercent = (iHigh(Symbol(), PERIOD_CURRENT, i + 1) - iLow(Symbol(), PERIOD_CURRENT, BarBackCheckShort + 1)) / iLow(Symbol(), PERIOD_CURRENT, BarBackCheckShort + 1) * 100;
    double sharpSurgePercent = (iHigh(Symbol(), PERIOD_CURRENT, i + 1) - iLow(Symbol(), PERIOD_CURRENT, BarBackCheckVolatile + 1)) / iLow(Symbol(), PERIOD_CURRENT, BarBackCheckVolatile + 1) * 100;
    
    //Print("iLow: ", DoubleToString(iLow(Symbol(), PERIOD_CURRENT, i)));
    //Print("iHigh: ", DoubleToString(iHigh(Symbol(), PERIOD_CURRENT, i)));
    //Print("iHigh_5: ", DoubleToString(iHigh(Symbol(), PERIOD_CURRENT, BarBackCheckShort)));
    //Print("surgePercent: ", DoubleToString(surgePercent));
    //Print("sharpSurgePercent: ", DoubleToString(sharpSurgePercent));
    if (surgePercent > SurgePercentage &&
        sharpSurgePercent > SharpSurgePercentage &&
        !sharp_surge_array_1 && !sharp_surge_array_2 && !sharp_surge_array_3 && // Check last 3 bars
        hl2_value > ema10hl2 && hl2_value > ema7hl2 &&
        (hl2_value - ema50hl2) / ema50hl2 * 100 > Aggresive_level)
    {
        sharp_surge = true;
        sharp_sink = false; // Reset sharp sink if a surge occurs
    }
    else 
    {
        sharp_surge = false;
    }

    // Sharp Sink Condition
    double sinkPercent = (iLow(Symbol(), PERIOD_CURRENT, i + 1) - iHigh(Symbol(), PERIOD_CURRENT, BarBackCheckLong + 1)) / iHigh(Symbol(), PERIOD_CURRENT, BarBackCheckLong + 1) * 100;
    double sharpSinkPercent = (iLow(Symbol(), PERIOD_CURRENT, i + 1) - iHigh(Symbol(), PERIOD_CURRENT, BarBackCheckVolatile + 1)) / iHigh(Symbol(), PERIOD_CURRENT, BarBackCheckVolatile + 1) * 100;

    if (sinkPercent < -SinkPercentage &&
        sharpSinkPercent < -SharpDropPercentage &&
        !sharp_sink_array_1 && !sharp_sink_array_2 && !sharp_sink_array_3 && // Check last 3 bars
        hl2_value < ema10hl2 && hl2_value < ema7hl2 &&
        (ema50hl2 - hl2_value) / hl2_value * 100 > Aggresive_level)
    {
        sharp_sink = true;
        sharp_surge = false; // Reset sharp surge if a sink occurs
    }
    else 
    {
        sharp_sink = false;
    }

    
    // Output hl2 for debugging
    //Print("hl2_value = ", hl2_value);
    //Print(" Debug: HL2 EMA 50 = ", hl2_ema50, ", HL2 EMA 10 = ", hl2_ema10, ", HL2 EMA 7 = ", hl2_ema7);
    // Update sharp surge/sink history arrays
    
}

void UpdateSharpHistory()
{
    // Shift the previous two values back
    sharp_surge_array_3 = sharp_surge_array_2;
    sharp_surge_array_2 = sharp_surge_array_1;
    sharp_surge_array_1 = sharp_surge;


    sharp_sink_array_3 = sharp_sink_array_2;
    sharp_sink_array_2 = sharp_sink_array_1;
    sharp_sink_array_1 = sharp_sink;
}


int lastBarChecked = -1;  // To store the index of the last processed bar


double MyPivotHigh(int _leftBars, int _rightBars) {
    int _pivotRange = _leftBars + _rightBars;

    // Ensure we have enough bars to calculate the pivot
    if (_leftBars <= 0 || _rightBars <= 0 || Bars(_Symbol, PERIOD_CURRENT) < (_pivotRange + 1)) {
        Print("Error: Insufficient bars to calculate MyPivotHigh.");
        return EMPTY_VALUE;
    }

    double _arrayOfSeriesValues[];
    ArrayResize(_arrayOfSeriesValues, _pivotRange + 1);

    // Copy high values over the required range
    int copied = CopyHigh(_Symbol, PERIOD_CURRENT, 0, _pivotRange + 1, _arrayOfSeriesValues);
    if (copied <= 0) {
        Print("Error: CopyHigh failed in MyPivotHigh.");
        return EMPTY_VALUE;
    }

    // Possible pivot high at the _rightBars index
    double _possiblePivotHigh = _arrayOfSeriesValues[_rightBars];

    // Find maximum value in the array
    double max_value = _arrayOfSeriesValues[0];
    int max_index = 0;
    for (int i = 0; i <= _pivotRange; i++) {
        if (_arrayOfSeriesValues[i] > max_value) {
            max_value = _arrayOfSeriesValues[i];
            max_index = i;
        }
    }

    // Calculate the offset of the pivot point from the right side
    int _pivotHighRightBars = _pivotRange - max_index;
    if (_pivotHighRightBars == _rightBars) {
        return _possiblePivotHigh;
    } else {
       // Print("No valid pivot high found for this range in MyPivotHigh.");
        return EMPTY_VALUE;
    }
}

// Function to calculate custom pivot low in MQL5
double MyPivotLow(int _leftBars, int _rightBars) {
    int _pivotRange = _leftBars + _rightBars;

    // Ensure we have enough bars to calculate the pivot
    if (_leftBars <= 0 || _rightBars <= 0 || Bars(_Symbol, PERIOD_CURRENT) < (_pivotRange + 1)) {
        Print("Error: Insufficient bars to calculate MyPivotLow.");
        return EMPTY_VALUE;
    }

    double _arrayOfSeriesValues[];
    ArrayResize(_arrayOfSeriesValues, _pivotRange + 1);

    // Copy low values over the required range
    int copied = CopyLow(_Symbol, PERIOD_CURRENT, 0, _pivotRange + 1, _arrayOfSeriesValues);
    if (copied <= 0) {
        Print("Error: CopyLow failed in MyPivotLow.");
        return EMPTY_VALUE;
    }

    // Possible pivot low at the _rightBars index
    double _possiblePivotLow = _arrayOfSeriesValues[_rightBars];

    // Find minimum value in the array
    double min_value = _arrayOfSeriesValues[0];
    int min_index = 0;
    for (int i = 0; i <= _pivotRange; i++) {
        if (_arrayOfSeriesValues[i] < min_value) {
            min_value = _arrayOfSeriesValues[i];
            min_index = i;
        }
    }

    // Calculate the offset of the pivot point from the right side
    int _pivotLowRightBars = _pivotRange - min_index;
    if (_pivotLowRightBars == _rightBars) {
        return _possiblePivotLow;
    } else {
        //Print("No valid pivot low found for this range in MyPivotLow.");
        return EMPTY_VALUE;
    }
}
//Support and resistance based on Pivothigh/low
void CheckSupportResistanceConditions()
{
    double hl2_value = GetHL2(1); 
         
    if (top - hl2_value < hl2_value - bot && top - hl2_value > 0)
    {
        within_and_near_to_support = true;
        within_and_near_to_resist = false;
        on_top_of_support = false;
        far_below_resistance = false;
        double_on_top_of_support = false;
        double_far_below_resistance = false;
    }
    if (top - hl2_value < hl2_value - bot && top - hl2_value < 0)
    {
        within_and_near_to_support = false;
        within_and_near_to_resist = false;
        on_top_of_support = true;
        far_below_resistance = false;
        double_on_top_of_support = false;
        double_far_below_resistance = false;
    }
    if (top - hl2_value > hl2_value - bot && hl2_value - bot > 0)
    {
        within_and_near_to_resist = true;
        within_and_near_to_support = false;
        on_top_of_support = false;
        far_below_resistance = false;
        double_on_top_of_support = false;
        double_far_below_resistance = false;
    }
    if (top - hl2_value > hl2_value - bot && hl2_value - bot < 0)
    {
        within_and_near_to_resist = false;
        within_and_near_to_support = false;
        on_top_of_support = false;
        far_below_resistance = true;
        double_on_top_of_support = false;
        double_far_below_resistance = false;
    }
    if (top - hl2_value < hl2_value - bot && ((top - bot) * 2 + bot) - hl2_value < 0)
    {
        within_and_near_to_support = false;
        within_and_near_to_resist = false;
        on_top_of_support = false;
        far_below_resistance = false;
        double_on_top_of_support = true;
        double_far_below_resistance = false;
    }
    if (top - hl2_value > hl2_value - bot && hl2_value - (bot - (top - bot) * 2) < 0)
    {
        within_and_near_to_resist = false;
        within_and_near_to_support = false;
        on_top_of_support = false;
        far_below_resistance = false;
        double_on_top_of_support = false;
        double_far_below_resistance = true;
    }
}

void LogAccountState() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);       // Fetch account assets
    double liabilities = AccountInfoDouble(ACCOUNT_LIABILITIES); // Fetch account liabilities
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);       // Fetch account equity
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);       // Fetch account margin
    double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN); // Fetch account free margin
    double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
    // Print formatted log message
    PrintFormat("Account state: Balance: %.2f, Liabilities: %.2f, Equity %.2f, Margin: %.2f, Free Margin: %.2f, Margin Level: %.2f%%",
                balance, liabilities, equity, margin, freeMargin, marginLevel);
}

//Buy//sell/Close
double CalculateLotSize(double price)
{
    // Get the account balance (use free margin to consider what's actually available for trading)
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double accountLeverage = AccountInfoInteger(ACCOUNT_LEVERAGE); // Get the leverage of the account
    double OrderPercentage1 = OrderPercentage / 100.0; // Convert trade percentage to a fraction

    // Calculate the effective funds to be used for trading based on the trade percentage and leverage
    double fundsToTrade = accountBalance * OrderPercentage1;

    // Get contract size for the symbol
    double contractSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);
    double pointSize = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    // Get calculation mode for the symbol
    int calcMode = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_CALC_MODE);
    double multiplier = 1.0;
    double normalizedPrice = price;

    while (normalizedPrice >= 10.0)  // Keep dividing until price is a single-digit value
    {
        normalizedPrice /= 10.0;
        multiplier /= 10.0;
    }
    // Debugging Statements for the Initial Data
    /*Print("DEBUG - Symbol: ", Symbol(), 
          ", Calculation Mode: ", calcMode, 
          ", Account Balance: ", accountBalance, 
          ", Leverage: ", accountLeverage, 
          ", Funds to Trade (with leverage): ", fundsToTrade, 
          ", Contract Size: ", contractSize, 
          ", Price: ", price);
    Print("pointSize: ", pointSize);*/
    // If contract size is not available, handle it as an error
    if (contractSize <= 0)
    {
        Print("Error: Unable to retrieve contract size for symbol ", Symbol());
        return 0.0; // Handle the error appropriately
    }

    // Calculate the lot size based on the calculation mode
    double lotSize = 0.0;

    if (calcMode == 0) // Forex symbols
    {
        // Forex pairs: calculate lot size based on funds available and contract size directly
        lotSize = fundsToTrade / (price * multiplier * contractSize );
        
        // 300000/100,000 * 10.54, 369.89  * 0.00001, 0.001

        //369.89  * 10
        //10.54 * 10,000
        //1.37 * 100,000

        // Debugging Statement for Forex Lot Calculation
        //Print("DEBUG - Forex Calculation with Leverage: Lot Size Calculated as: ", lotSize);
    }
    else if (calcMode == 4) // Spot Trading (e.g., XAUUSD)
    {
        // Commodities/Spot Trading: Calculate lot size based on both contract size and price
        lotSize = fundsToTrade / (price * contractSize);

        // Debugging Statement for Spot Trading Lot Calculation
        //Print("DEBUG - Spot Trading Calculation with Leverage: Lot Size Calculated as: ", lotSize);
    }
    else
    {
        // For other symbol types (e.g., stocks), calculate in a simplified way
        lotSize = fundsToTrade / price / accountLeverage; // Assuming 1 unit contract size for simplicity

        // Debugging Statement for Fallback Calculation
        //Print("DEBUG - Fallback Calculation with Leverage: Lot Size Calculated as: ", lotSize);
    }

    // Minimum and maximum lot sizes for the symbol
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    // Debugging Statements for Lot Constraints
    //Print("DEBUG - Min Lot: ", minLot, ", Max Lot: ", maxLot, ", Lot Step: ", lotStep);

    // Ensure the lot size is within the allowable range and adjusted to the proper step
    if (lotSize < minLot)
    {
        //Print("DEBUG - Adjusting Lot Size to Min Lot: ", minLot);
        lotSize = minLot;
    }
    else if (lotSize > maxLot)
    {
        //Print("DEBUG - Adjusting Lot Size to Max Lot: ", maxLot);
        lotSize = maxLot;
    }
    else
    {
        // Normalize lot size to the nearest valid step
        lotSize = NormalizeDouble(floor(lotSize / lotStep) * lotStep, 3);
        lotSize = NormalizeDouble(lotSize, 2);
        //Print("DEBUG - Normalized Lot Size to Nearest Step: ",lotSize);
    }

    return lotSize;
}


enum PriceType {
    ASK = 0,
    BID = 1,
    LOW = 2,
    HIGH = 3,
    CLOSE = 4,
    HL = 5,
    // Add more options if needed
};



double GetPrice(int ptype) {
    PriceType priceTypeEnum = (PriceType)ptype; // Convert integer to enum
    switch (priceTypeEnum) {
        case ASK: return SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        case BID: return SymbolInfoDouble(Symbol(), SYMBOL_BID);
        case LOW: return iLow(Symbol(), PERIOD_CURRENT, 1);
        case HIGH: return iHigh(Symbol(), PERIOD_CURRENT, 1);
        case CLOSE: return iClose(Symbol(), PERIOD_CURRENT, 1);
        case HL: return (iHigh(Symbol(), PERIOD_CURRENT, 1) + iLow(Symbol(), PERIOD_CURRENT, 1)) / 2;
        default: return 0.0;
    }
}

bool CheckMoneyForTrade(string symb,double lots,ENUM_ORDER_TYPE type)
  {
//--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
//--- values of the required and free margin
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   //--- call of the checking function
   if(!OrderCalcMargin(type,symb,lots,price,margin))
     {
      //--- something went wrong, report and return false
      Print("Error in ",__FUNCTION__," code=",GetLastError());
      return(false);
     }
   //--- if there are insufficient funds to perform the operation
   if(margin>free_margin)
     {
      //--- report the error and return false
      Print("Not enough money for ",EnumToString(type)," ",lots," ",symb," Error code=",GetLastError());
      return(false);
     }
//--- checking successful
   return(true);
  }

// Function to execute Sell using CTrade class
void ExecuteSell()
{

    int totalPositions = PositionsTotal();
    if (totalPositions >= ConcurrentPositionAllowed)
    {
        Print("Maximum concurrent positions reached. Sell order not executed.");
        return;
    }
    
    //int i = initial7; //better be 0 
    double bid = GetPrice(1);
    double bid2 = GetPrice(3);
    //double bid = iHigh(Symbol(), PERIOD_CURRENT, 0);
    //double bid = iClose(Symbol(), PERIOD_CURRENT, 1);
    //double bid = GetHL2(0);
    // Calculate the lot size
    double lotSize = CalculateLotSize(bid);

    // Calculate Stop-Loss and Take-Profit prices
    double sl = bid2 + (StopLossPercentShort / 100 * bid2);
    double tp = bid2 - (ProfitPercentShort / 100 * bid2);

    // Retrieve the minimum stop level from the broker
    double stopLevelPoints = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);

    // Ensure SL and TP respect the broker's stop level
    if ((sl - bid) < stopLevelPoints)
        sl = bid + stopLevelPoints;
    if ((bid - tp) < stopLevelPoints)
        tp = bid - stopLevelPoints;

    // Normalize SL and TP to 5 decimal places
    sl = NormalizeDouble(sl, 5);
    tp = NormalizeDouble(tp, 5);
    Print("Entering Short Position...");
    Print("StopLoss: ", sl, " TakeProfit: ", tp, " Instrument Stop Level Points: ", stopLevelPoints);
    tp_level = tp;
    sl_level = sl;
    
   //Function to include consistant risk
    double riskCapital = Consistant_risk_capital; // Total risk capital

    if(Concurent_Risk_Capital)
    {
 
      UpdateStopLossWithDividedRisk(Consistant_risk_capital);
      consistant_sl_level = GetStopLossPriceForNewTrade(bid, lotSize, Consistant_risk_capital, totalPositions , false);
      consistant_sl_level = NormalizeDouble(consistant_sl_level, 5);
    }     
    else
    {
         consistant_sl_level = sl_level;
    }        
    
    // Place a Sell order using the CTrade class
    //if (!trade.Sell(lotSize, NULL, bid, sl, tp))
    if (!trade.Sell(lotSize, Symbol(), bid, consistant_sl_level))
    {
        Print("Sell order failed: ", GetLastError());
    }
    else
    {
        brought_price = bid;
        //Print("Sell order executed successfully.");
    }
    LogAccountState();
}


// Function to execute Buy using CTrade class
void ExecuteBuy()
{

    int totalPositions = PositionsTotal();
    if (totalPositions >= ConcurrentPositionAllowed)
    {
        Print("Maximum concurrent positions reached. Buy order not executed.");
        return;
    }
    double ask = GetPrice(0);
    double ask2 = GetPrice(2);
    //double ask = iLow(Symbol(), PERIOD_CURRENT, 1);
    //double ask = iClose(Symbol(), PERIOD_CURRENT, 1);
    //double ask = GetHL2(0);
    // Calculate the lot size
    double lotSize = CalculateLotSize(ask);

    // Calculate Stop-Loss and Take-Profit prices
    double sl = ask2 - (StopLossPercentLong / 100 * ask2);
    double tp = ask2 + (ProfitPercentLong / 100 * ask2);

    // Retrieve the minimum stop level from the broker
    double stopLevelPoints = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(Symbol(), SYMBOL_POINT);

    // Ensure SL and TP respect the broker's stop level
    if ((ask - sl) < stopLevelPoints)
        sl = ask - stopLevelPoints;
    if ((tp - ask) < stopLevelPoints)
        tp = ask + stopLevelPoints;

    // Normalize SL and TP to 5 decimal places
    sl = NormalizeDouble(sl, 5);
    tp = NormalizeDouble(tp, 5);
    Print("Entering Long Position...");
    Print("StopLoss: ", sl, " TakeProfit: ", tp, " Instrument Stop Level Points: ", stopLevelPoints);
    tp_level = tp;
    sl_level = sl;
    
    double riskCapital = Consistant_risk_capital; // Total risk capital Default 5000

    if(Concurent_Risk_Capital)
      {
         UpdateStopLossWithDividedRisk(Consistant_risk_capital);
         consistant_sl_level = GetStopLossPriceForNewTrade(ask, lotSize, Consistant_risk_capital, totalPositions , true);
         consistant_sl_level = NormalizeDouble(consistant_sl_level, 5);
  
      }
    else
      {
         consistant_sl_level = sl_level;
      }    
            
    // Place a Buy order using the CTrade class
    //if (!trade.Buy(lotSize, NULL, ask, sl, tp))
    if (!trade.Buy(lotSize, Symbol(), ask, consistant_sl_level))
    {
        Print("Buy order failed: ", GetLastError());
    }
    else
    {
        brought_price = ask;
        //Print("Buy order executed successfully.");
    }
    LogAccountState();
}

void ExitOrderbyTPSL() //Exit order that on ever tick
{

    //int i = initial8;  //better be 0 
    // Check if TP or SL hit for long
    bool trade_executed = false;
    // Retrieve current ask and bid prices
    double ask = GetPrice(0);
    double bid = GetPrice(1);

    // Static variables to store the lowest ask, highest bid, TP, and SL levels
    static double lowest_ask = ask;
    static double highest_bid = bid;

    static double sl_level_long = ask;  // Initial SL for long position
    static double sl_level_short = bid; // Initial SL for short position

    // Normalize initial SL levels
    sl_level_long = NormalizeDouble(sl_level_long, 5);
    sl_level_short = NormalizeDouble(sl_level_short, 5);

    // Update for long position
   /* if (brought_long) 
    {
        // Track and update the lowest ask to adjust the take profit level
        if (ask < lowest_ask) 
        {
            lowest_ask = ask;
            //ProfitPercentLong = ProfitPercentLong - (5/100 * ProfitPercentLong);
            tp_level = lowest_ask + (ProfitPercentLong / 100 * lowest_ask);
            tp_level = NormalizeDouble(tp_level, 5);
            lowest_ask = NormalizeDouble(lowest_ask, 5);
            //trade_executed = true;
           // Print("Long Position - Price opened at: ", PositionGetDouble(POSITION_PRICE_OPEN), ", Lowest ask: ", DoubleToString(lowest_ask, 5), ", New TP: ", DoubleToString(tp_level, 5));
        }

        // Track and update the highest ask to adjust the stop loss level upward

    }

    // Update for short position
    if (brought_short) 
    {
        // Track and update the highest bid to adjust the take profit level
        if (bid > highest_bid) 
        {
            highest_bid = bid;
            //ProfitPercentShort = ProfitPercentShort + (5/100 * ProfitPercentShort);
            tp_level = highest_bid - (ProfitPercentShort / 100 * highest_bid);
            tp_level = NormalizeDouble(tp_level, 5);
            highest_bid = NormalizeDouble(highest_bid, 5);
            //trade_executed = true;
            //Print("Short Position - Price opened at: ", PositionGetDouble(POSITION_PRICE_OPEN), ", Highest bid: ", DoubleToString(highest_bid, 5), ", New TP: ", DoubleToString(tp_level, 5));
        }

    }

    if (brought_long && !brought_short && (bid >= tp_level) && !trade_executed)
    {
        Print("Closing Long position as TP hit");
        CloseOpenPositions();  // Close the long position
        lowest_ask = ask;
        highest_bid = bid;
        sl_level_long = ask;
        sl_level_short = bid;
        sl_level = 0;
        brought_long = false;
        trade_executed = true;
        //canclose = true;

    }
    
    if (brought_long && !brought_short && (bid <= sl_level) && !trade_executed)
    {
        Print("Closing Long position as SL hit");
        CloseOpenPositions();  // Close the long position
        lowest_ask = ask;
        highest_bid = bid;
        sl_level_long = ask;
        sl_level_short = bid;
        sl_level = 0;
        //canclose = true;
        brought_long = false;
        trade_executed = true;
    }

    if (!brought_long && brought_short && (ask <= tp_level ) && !trade_executed)
    {
        Print("Closing Short position as TP hit", ask," <ask tp_level> ", tp_level);
        CloseOpenPositions();  // Close the short position
        lowest_ask = ask;
        highest_bid = bid;
        sl_level_long = ask;
        sl_level_short = bid;
        sl_level = 0;
        //canclose = true;
        brought_short = false;
        trade_executed = true;        
    }
    
    if (!brought_long && brought_short && (ask >= sl_level ) && !trade_executed)
    {
        Print("Closing Short position as SL hit");
        CloseOpenPositions();  // Close the short position
        lowest_ask = ask;
        highest_bid = bid;
        sl_level_long = ask;
        sl_level_short = bid;
        sl_level = 0;
        //canclose = true;
        brought_short = false;   
        trade_executed = true;             

    }    */
    if  (!PositionSelect(Symbol())&& !trade_executed) {
        //Print("There are open positions.");
        tp_level = 0;
        sl_level = 0;
        lowest_ask = ask;
        highest_bid = bid;
        sl_level_long = ask;
        sl_level_short = bid;    
        brought_short = false;
        brought_long = false;
    }  
    // Reset flags after positions close
    /*if (!brought_long && !PositionSelect(Symbol()))
    {
        brought_long = false;
        tp_level = 0;
        sl_level = 0;
        trade_executed = false;
    }
    if (!brought_short && !PositionSelect(Symbol()))
    {
        brought_short = false;
        tp_level = 0;
        sl_level = 0;
        trade_executed = false;
    }
    */
    if (trade_executed == true)
    {
      Print("-----------------------------------------------------------------------------------");
    }
}    


void CloseOpenPositions()
{

    // Check if there is an open position for the current symbol
    if (PositionSelect(Symbol()))
    {
        // Retrieve position details
        double positionLots = PositionGetDouble(POSITION_VOLUME);
        ulong positionTicket = PositionGetInteger(POSITION_TICKET);
        double positionPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        long positionType = PositionGetInteger(POSITION_TYPE);  // POSITION_TYPE_BUY or POSITION_TYPE_SELL
        
        // Print position information for debugging
        Print("Open Position Found: Ticket ", positionTicket, 
              ", Type: ", positionType == POSITION_TYPE_BUY ? "Buy" : "Sell", 
              ", Lots: ", positionLots, 
              ", Open Price: ", positionPrice);
        Print("Closing Existing Position ... ");    
        // Try to close the position
        if (trade.PositionClose(Symbol()))  // Using the global 'trade' object
        {
            Print("Existing Position closed successfully: Ticket ", positionTicket);
            brought_price = 0;
            UpdateStopLossWithDividedRisk_Closing(Consistant_risk_capital);
            LogAccountState();
        }
        else
        {
            Print("Failed to close position: Ticket ", positionTicket, " Error: ", GetLastError());
            LogAccountState();
        }
    }
    else
    {
        //Print("No open positions found for symbol: ", Symbol());
    }
    
}


//Execute order
void Execute_order()
{
    bool trade_executed = false;
    double lot_size = CalculateLotSize(GetPrice(0));
    bool canTrade = CheckMoneyForTrade(_Symbol, lot_size, ORDER_TYPE_BUY);
    
    if  (!canTrade && !trade_executed )
    {    trade_executed = true;
    }
       
    // Example Buy condition: if sharp sink and within support/resistance range
    if  (!brought_long && ( sharp_sink && double_on_top_of_support  ) && !trade_executed && (smaDiff > smaThreshold  || smaDiff < -smaThreshold  || smaDiff == 0) && ( ma20[0] == 0 || ((ma20[0] - ma50[0]) > (ma20[1] - ma50[1]) && ma20[0] > ma80[0])) && (iClose(Symbol(), PERIOD_CURRENT, 2) > iOpen(Symbol(), PERIOD_CURRENT, 2) && iClose(Symbol(), PERIOD_CURRENT, 1) > iOpen(Symbol(), PERIOD_CURRENT, 1)) && (  (( iOpen(Symbol(), PERIOD_CURRENT, 1) - iOpen(Symbol(), PERIOD_CURRENT, 2) ) < offset)  || offset_ignore == true  ))
    {
        Print("Enter Long");
        CloseOpenPositions();
        ExecuteBuy(); // Execute Buy order
        brought_long = true;
        //sharp_surge = false;
        //sharp_sink = false;
        trade_executed = true;
        ResetPivots();
    }
    if  (!PositionSelect(Symbol())&& !trade_executed) {
        //Print("There are open positions.");
        brought_long = false;
        brought_short = false;
        sharp_sink = false;
        
        tp_level = 0;
        sl_level = 0;
    }  

    // Example Sell condition: if sharp surge and within support/resistance range
    if  (!brought_short && ( sharp_surge && double_far_below_resistance  ) && !trade_executed && (smaDiff > smaThreshold  || smaDiff < -smaThreshold  || smaDiff == 0 ) && ( ma20[0] == 0 || ((ma20[0] - ma50[0]) < (ma20[1] - ma50[1]) && ma20[0] < ma80[0])) && (iClose(Symbol(), PERIOD_CURRENT, 2) < iOpen(Symbol(), PERIOD_CURRENT, 2) && iClose(Symbol(), PERIOD_CURRENT, 1) < iOpen(Symbol(), PERIOD_CURRENT, 1)) && (  (( iOpen(Symbol(), PERIOD_CURRENT, 1) - iOpen(Symbol(), PERIOD_CURRENT, 2) ) > -offset)  || offset_ignore == true  ))
    {
        Print("Enter Short");
        CloseOpenPositions();
        ExecuteSell(); // Execute Sell order
        brought_short = true;
        //sharp_sink = false;
        //sharp_surge = false;
        trade_executed = true;
        ResetPivots();
    }


    // Handle reversals

    //---
    
    if ((sharp_surge && sharp_surge_array_1 && sharp_surge_array_2) && brought_long && !trade_executed)
    {
        Print("Closing long position due to reversal detected");
        CloseOpenPositions();
        brought_long = false;
        brought_short = false;
        trade_executed = true;
        sharp_surge = false;
        trade_executed = true;
        
    }

    if ((sharp_sink && sharp_sink_array_1 && sharp_sink_array_2) && brought_short && !trade_executed)
    {
        Print("Closing short position due to reversal detected");
        CloseOpenPositions();
        brought_long = false;
        brought_short = false;
        trade_executed = true;
        sharp_sink = false;
    }
    

    
    if (Close_After_Sharp() && !trade_executed )
    {
        Print("Closing after sharp");
        CloseOpenPositions();
        brought_long = false;
        brought_short = false;
        trade_executed = true;
        sharp_sink = false;
        sharp_surge = false;
    }
    
    if ((brought_long || brought_short) && Close_Low_Volatile() && !trade_executed )
    {
        Print("Closing low volatile");
        CloseOpenPositions();
        brought_long = false;
        brought_short = false;
        trade_executed = true;
        sharp_sink = false;
        sharp_surge = false;
    }    



    if (trade_executed == true)
    {
    Print("-----------------------------------------------------------------------------------");
    }
    // Reset flags after positions close
    /*if (!PositionSelect(Symbol()))
    {
        brought_long = false;
        brought_short = false;
        tp_level = 0;
        sl_level = 0;
        trade_executed = false;
    }*/
    
}


void UpdateStopLossWithDividedRisk(double totalStopLossAmount)
{
    int totalPositions = PositionsTotal(); // Get total positions
    if (totalPositions <= 0)
    {
        Print("No positions found to adjust consistent stop loss.");
        return;
    }

    // Divide the total stop loss amount equally among all positions (including the new one)
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

            // Retrieve contract size (e.g., 100,000 for Forex)
            double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            if (contractSize <= 0 || volume <= 0)
            {
                Print("Invalid contract size or volume for ", symbol);
                continue;
            }

            // Calculate units at risk based on individual stop-loss amount and entry price
            double riskUnits = individualStopLossAmount / entryPrice;

            // Calculate current position units
            double positionUnits = volume * contractSize;

            // Adjust units for stop loss
            double stopLossUnits;
            if (type == POSITION_TYPE_BUY) // Long Position
            {
                stopLossUnits = positionUnits - riskUnits;
            }
            else if (type == POSITION_TYPE_SELL) // Short Position
            {
                stopLossUnits = positionUnits + riskUnits;
            }
            else
            {
                Print("Unsupported position type for ticket: ", positionTicket);
                continue;
            }

            // Calculate new stop-loss price based on adjusted units
            double newStopLoss;
            if (type == POSITION_TYPE_BUY) // Long Position
            {
                newStopLoss = stopLossUnits / contractSize * entryPrice / volume;
            }
            else if (type == POSITION_TYPE_SELL) // Short Position
            {
                newStopLoss = stopLossUnits / contractSize * entryPrice / volume;
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


void UpdateStopLossWithDividedRisk_Closing(double totalStopLossAmount)
{
    int totalPositions = PositionsTotal(); // Get total positions
    if (totalPositions <= 0)
    {
        Print("No positions found to adjust consistent stop loss.");
        return;
    }

    // Divide the total stop loss amount equally among all positions (exclude the new one)
    double individualStopLossAmount = totalStopLossAmount / (totalPositions);

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

            // Retrieve contract size (e.g., 100,000 for Forex)
            double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            if (contractSize <= 0 || volume <= 0)
            {
                Print("Invalid contract size or volume for ", symbol);
                continue;
            }

            // Calculate units at risk based on individual stop-loss amount and entry price
            double riskUnits = individualStopLossAmount / entryPrice;

            // Calculate current position units
            double positionUnits = volume * contractSize;

            // Adjust units for stop loss
            double stopLossUnits;
            if (type == POSITION_TYPE_BUY) // Long Position
            {
                stopLossUnits = positionUnits - riskUnits;
            }
            else if (type == POSITION_TYPE_SELL) // Short Position
            {
                stopLossUnits = positionUnits + riskUnits;
            }
            else
            {
                Print("Unsupported position type for ticket: ", positionTicket);
                continue;
            }

            // Calculate new stop-loss price based on adjusted units
            double newStopLoss;
            if (type == POSITION_TYPE_BUY) // Long Position
            {
                newStopLoss = stopLossUnits / contractSize * entryPrice / volume;
            }
            else if (type == POSITION_TYPE_SELL) // Short Position
            {
                newStopLoss = stopLossUnits / contractSize * entryPrice / volume;
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

double GetStopLossPriceForNewTrade(double entryPrice, double volume, double totalRisk, int totalExistingPositions, bool isBuy)
{
    double contractSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_CONTRACT_SIZE);

    if (contractSize <= 0 || volume <= 0 || totalRisk <= 0 || totalExistingPositions < 0)
    {
        Print("Invalid input parameters for stop loss calculation.");
        return 0.0;
    }

    // Divide total risk across all positions (existing + new one)
    double individualStopLossAmount = totalRisk / (totalExistingPositions + 1);

    // Calculate risk in units based on the new trade's volume and entry price
    double riskUnits = individualStopLossAmount / entryPrice;

    // Determine the adjusted stop loss price based on the position type (buy/sell)
    double newStopLossPrice;
    if (isBuy)
    {
        // For Buy, SL is below the entry price
        double positionUnits = volume * contractSize;
        double stopLossUnits = positionUnits - riskUnits;

        // Adjust SL price based on risk and contract size
        newStopLossPrice = stopLossUnits / (contractSize * volume) * entryPrice;
    }
    else
    {
        // For Sell, SL is above the entry price
        double positionUnits = volume * contractSize;
        double stopLossUnits = positionUnits + riskUnits;

        // Adjust SL price based on risk and contract size
        newStopLossPrice = stopLossUnits / (contractSize * volume) * entryPrice;
    }

    // Normalize the stop loss to the symbol's digits
    return NormalizeDouble(newStopLossPrice, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}



void LimitProfitPerPosition(double profitLimit)
{
    int totalPositions = PositionsTotal();
    if (totalPositions <= 0)
    {
        //Print("No positions to monitor.");
        return;
    }

    for (int i = totalPositions - 1; i >= 0; i--) // Loop from the last to handle index shifting during closures
    {
        ulong positionTicket = PositionGetTicket(i);
        if (PositionSelectByTicket(positionTicket))
        {
            // Retrieve position details
            string symbol        = PositionGetString(POSITION_SYMBOL);
            double currentProfit  = PositionGetDouble(POSITION_PROFIT);
            double volume         = PositionGetDouble(POSITION_VOLUME);

            // Check if the profit meets or exceeds the limit
            if (currentProfit >= profitLimit)
            {
                Print("Closing position for ", symbol, " with profit: ", currentProfit);

                 if (trade.PositionClose(symbol))  // Using the global 'trade' object
                 {
                     Print("Position closed successfully by profitLimit: Ticket ", positionTicket);
                 }
                 else
                 {
                     Print("Failed to close position: Ticket ", positionTicket, " Error: ", GetLastError());
                 }
            }
        }
    }
}

void PrintPositionValue()
{
   int totalPositions = PositionsTotal();  // Get the total number of open positions

   // Loop through all positions
   for(int i = 0; i < totalPositions; i++)
   {
      string symbol = PositionGetSymbol(i);  // Get the symbol of the position
      if(PositionSelect(symbol))  // Select the position by symbol
      {
         double volume = PositionGetDouble(POSITION_VOLUME);  // Volume in lots
         double price = PositionGetDouble(POSITION_PRICE_OPEN);  // Open price in quote currency
         double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);  // Contract size

         // Calculate the position value in the quote currency
         double positionValue = volume * contractSize * price;  // Initial value in quote currency

         // Account currency
         string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);  // E.g., USD
         string quoteCurrency = StringSubstr(symbol, 3, 3);  // Quote currency (e.g., USD in USDSEK)

         // If the quote currency is different from the account currency, convert
         if(accountCurrency != quoteCurrency)
         {
            string conversionSymbol = quoteCurrency + accountCurrency;  // Conversion pair (e.g., SEKUSD)
            double conversionRate = 1.0;

            if(SymbolSelect(conversionSymbol, true))
            {
               conversionRate = SymbolInfoDouble(conversionSymbol, SYMBOL_BID);  // Conversion rate
            }
            else
            {
               // Handle reverse pair (e.g., USDSEK)
               string reverseConversionSymbol = accountCurrency + quoteCurrency;
               if(SymbolSelect(reverseConversionSymbol, true))
               {
                  double reverseRate = SymbolInfoDouble(reverseConversionSymbol, SYMBOL_BID);
                  if(reverseRate > 0.0)
                     conversionRate = 1.0 / reverseRate;
                  else
                  {
                     Print("Error: Unable to find conversion pair for ", quoteCurrency, " to ", accountCurrency);
                     continue;
                  }
               }
               else
               {
                  Print("Error: Unable to find conversion pair for ", quoteCurrency, " to ", accountCurrency);
                  continue;
               }
            }

            // Convert the position value to the account currency
            positionValue *= conversionRate;
         }

         // Print the position value in the account currency
         Print("Symbol: ", symbol, 
               " | Volume: ", volume, 
               " | Open Price: ", price, 
               " | Value in ", accountCurrency, ": ", positionValue);
      }
      else
      {
         Print("Error: Unable to select position for symbol: ", symbol);
      }
   }
}


void calculateADR() {
   // Calculate SMA of High and Low

   double smaHigh[1];
   double smaLow[1];

   ArraySetAsSeries(smaHigh, true);
   ArraySetAsSeries(smaLow, true);
   
   if (CopyBuffer(maHighHandle, 0, 0, 1, smaHigh) < 0 ||
       CopyBuffer(maLowHandle, 0, 0, 1, smaLow) < 0)
     {
      Print("Error copying MA buffer: ", GetLastError());
      return;
     }
   if (ADR_Enabled == true)
   {
      smaDiff = smaHigh[0] - smaLow[0];
   }
   else
   {
      smaDiff = 0;
   }   
}


void ma()
{

   if (MA_Enabled == true)
   {
      ArraySetAsSeries(ma20, true);
      ArraySetAsSeries(ma50, true);
      ArraySetAsSeries(ma80, true);
      
      if (
          CopyBuffer(ma20Handle, 0, 0, 2, ma20) != 2 ||
          CopyBuffer(ma50Handle, 0, 0, 2, ma50) != 2 ||
          CopyBuffer(ma80Handle, 0, 0, 1, ma80) != 1
      )
      {
         Print("Failed to get MA buffer(s): ", GetLastError());
         return;
      }
   }
   else 
   {
      ma20[0] = 0;
      ma50[0] = 0;
      ma80[0] = 0;
   }
}


void sharp_check()
{
   if (sharp_enabled == false)
   {
     sharp_ignore = true; 
   }
   else
   {
      sharp_ignore = false;
   }
}

void OffsetCheck()
{
if (Offset_Enabled == false)
   {
      offset_ignore = true; 
   }
   else
   {
      offset_ignore = false;
   }
}

void SSL_Check()
{
if (smart_stop_loss_Enabled == true)
   {
       static double existing_top = 0.0;
       static double existing_bot = 0.0;
       double new_top = MyPivotHigh(PivotLeft, PivotRight);
       double new_bot = MyPivotLow(PivotLeft, PivotRight); 

       //Compare if there are new pivot high and new pivot low occur after first long position entry.
       if (brought_long && existing_top > 0 && existing_top != new_top && existing_bot != new_bot)
       {
         sl_level = MyPivotLow(PivotLeft, PivotRight);
         sl_level = NormalizeDouble(sl_level, 5);
         existing_top = new_top;
         existing_bot = new_bot;
       }
       
       
       //Ensure this is new long position entry, assigned current pivot to existing top, bot variable.
       if (brought_long && existing_top == 0)  
       {
         existing_top = new_top;
         existing_bot = new_bot;
       }
       
       //Compare if there are new pivot high and new pivot low occur after first short  position entry.
       if (brought_short && existing_bot > 0 && existing_top != new_top && existing_bot != new_bot)
       {
         sl_level = MyPivotHigh(PivotLeft, PivotRight);
         sl_level = NormalizeDouble(sl_level, 5);
         existing_top = new_top;
         existing_bot = new_bot;
       }
       
       
       //Ensure this is new short position entry, assigned current pivot to existing top, bot variable.
       if (brought_short && existing_bot == 0)  
       {
         existing_top = new_top;
         existing_bot = new_bot;
       }
       
       //Reset variables
       if (!brought_long && !brought_short)
       {
          existing_top = 0.0;
          existing_bot = 0.0;
       }  
   }
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int EMA50Handler;   // Handle for the EMA indicator
int EMA10Handler;   // Handle for the EMA indicator
int EMA7Handler;   // Handle for the EMA indicator
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    if(global_profit_loss > 0 && global_Stop_Loss_division > 0)
    {
     ProfitPercentLong = global_profit_loss;
     StopLossPercentLong = global_profit_loss/global_Stop_Loss_division;
     ProfitPercentShort = global_profit_loss;
     StopLossPercentShort = global_profit_loss/global_Stop_Loss_division;
    }
    if(global_profit_loss > 0 && global_Stop_Loss_division < 0 )
    {
     ProfitPercentLong = global_profit_loss;
     StopLossPercentLong = global_profit_loss*-global_Stop_Loss_division;
     ProfitPercentShort = global_profit_loss;
     StopLossPercentShort = global_profit_loss*-global_Stop_Loss_division;    
    }
    /*if (TimeCurrent() > end_date) {
        Print("The EA has reached its expiration date and will no longer trade.");
        return(INIT_FAILED); // Stop the EA from initializing if past the date
    }*/

//---  ExtTrade.SetExpertMagicNumber(MA_MAGIC);
 EMA50Handler = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_MEDIAN);
 EMA10Handler = iMA(_Symbol, _Period, 10, 0, MODE_EMA, PRICE_MEDIAN);
 EMA7Handler = iMA(_Symbol, _Period, 7, 0, MODE_EMA, PRICE_MEDIAN);
    // Check if the handle was created successfully
    if (EMA50Handler == INVALID_HANDLE) {
        Print("Error creating EMA indicator handle.");
        return INIT_FAILED;
    }
   //--- Check if we have enough bars to calculate EMA (at least 10 bars for period 10)
   if (Bars(_Symbol, _Period) < 50)
   {
      Print("Not enough bars to initialize EMA");
      return(INIT_FAILED);
   }

//ma

   ma20Handle = iMA(_Symbol, _Period, maPeriod20, 0, MODE_SMA, PRICE_HIGH);
   ma50Handle = iMA(_Symbol, _Period, maPeriod50, 0, MODE_SMA, PRICE_HIGH);
   ma80Handle = iMA(_Symbol, _Period, maPeriod80, 0, MODE_SMA, PRICE_HIGH);

   if (ma20Handle == INVALID_HANDLE || ma50Handle == INVALID_HANDLE || ma80Handle == INVALID_HANDLE)
   {
     Print("Failed to create one or more MA handles");
     return(INIT_FAILED);
   }


   // Create handles for moving averages
   maHighHandle = iMA(_Symbol, _Period, adrLength, 0, MODE_SMA, PRICE_MEDIAN);
   maLowHandle  = iMA(_Symbol, _Period, adrLength, 0, MODE_SMA, PRICE_MEDIAN);

   if (maHighHandle == INVALID_HANDLE || maLowHandle == INVALID_HANDLE)
     {
      Print("Failed to create MA handles");
      return(INIT_FAILED);
     }


   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
 {
    /*if (TimeCurrent() > end_date) {
        Print("The EA's trial period has ended on 10-Dec-2024. Please proceed to purchase this EA to continue trading.");
        return; // Stop trading operations
    }*/
  if (LimitProfit)
  { 
   LimitProfitPerPosition(profitLimitValue);
   

  } 

  static int lastBar = -1;
  ExitOrderbyTPSL();

  int currentBar = iBars(Symbol(), PERIOD_CURRENT);  //Likely starting at 24714
  
  if (FirstBar == -1)
  {
      FirstBar = iBars(Symbol(), PERIOD_CURRENT);
  }
  
  if (currentBar != lastBar && currentBar != -1)
  {
     // Update the last processed bar to the current one
     lastBar = currentBar;
     OnNewBar();
  }
}
//+------------------------------------------------------------------+
//| NewBarEvent function                                              |
//+------------------------------------------------------------------+
void OnNewBar()
{

    //ExecuteBuy();
    UpdateSharpHistory();
    double EMA50Value[];  // Array to store the EMA values
    double EMA10Value[];    
    double EMA7Value[];
    if (CopyBuffer(EMA50Handler, 0, 0, 1, EMA50Value) > 0) {
        //Print("Current EMA50: ", EMA50Value[0]);
    } else {
        Print("Error retrieving EMA value.");
    }
    if (CopyBuffer(EMA10Handler, 0, 0, 1, EMA10Value) > 0) {
        //Print("Current EMA10: ", EMA10Value[0]);
    } else {
        //Print("Error retrieving EMA value.");
    }
    if (CopyBuffer(EMA7Handler, 0, 0, 1, EMA7Value) > 0) {
        //Print("Current EMA7: ", EMA7Value[0]);
    } else {
        Print("Error retrieving EMA value.");
    }        


   ema50hl2 = EMA50Value[0];
   ema10hl2 = EMA10Value[0];
   ema7hl2 = EMA7Value[0];

   double new_top = MyPivotHigh(leftBars, rightBars);
   double new_bot = MyPivotLow(leftBars, rightBars);

    if (new_top < 99999 ) {
        top = new_top;
        //Print("Calculated pivot high (top): ", top);
    }
    if (new_bot < 99999) {
         bot = new_bot;
        //Print("Calculated pivot low (bot): ", bot);
    }
    
   CheckSharpConditions();

   CheckSupportResistanceConditions();

   calculateADR();
   ma();
   sharp_check();
   OffsetCheck();
   SSL_Check();
   
   Execute_order();

   // Output the updated pivot high and low values
   //Print("Current Top (Pivot High): ", top);
   //Print("Current Bot (Pivot Low): ", bot);

   //Debug Print
   static bool prev_brought_long = brought_long;
   static bool prev_brought_short = brought_short;
   static double prev_tp_level = tp_level;
   static double prev_sl_level = sl_level;
   static bool prev_sharp_surge = sharp_surge;
   static bool prev_sharp_sink = sharp_sink;
   static bool prev_sharp_surge_array_1 = sharp_surge_array_1;
   static bool prev_sharp_sink_array_1 = sharp_sink_array_1;
   static bool prev_sharp_surge_array_2 = sharp_surge_array_2;
   static bool prev_sharp_sink_array_2 = sharp_sink_array_2;
   static bool prev_sharp_surge_array_3 = sharp_surge_array_3;
   static bool prev_sharp_sink_array_3 = sharp_sink_array_3;
   static bool prev_within_and_near_to_support = within_and_near_to_support;
   static bool prev_within_and_near_to_resist = within_and_near_to_resist;
   static bool prev_on_top_of_support = on_top_of_support;
   static bool prev_far_below_resistance = far_below_resistance;
   static bool prev_double_on_top_of_support = double_on_top_of_support;
   static bool prev_double_far_below_resistance = double_far_below_resistance;
   static double prev_top = top;
   static double prev_bot = bot;
   static double prev_hl2_now = GetHL2(0);
 
   /*
   // Print only if the state has changed
   if (brought_long != prev_brought_long) {
       Print("brought_long = ", brought_long);
       prev_brought_long = brought_long;
   }
   if (brought_short != prev_brought_short) {
       Print("brought_short = ", brought_short);
       prev_brought_short = brought_short;
   }
   
   if (tp_level != prev_tp_level) {
       Print("tp_level = ", tp_level);
       prev_tp_level = tp_level;
   }
   if (sl_level != prev_sl_level) {
       Print("sl_level = ", sl_level);
       prev_sl_level = sl_level;
   }

   if (sharp_surge != prev_sharp_surge) {
       Print("sharp_surge = ", sharp_surge);
       prev_sharp_surge = sharp_surge;
   }
   if (sharp_sink != prev_sharp_sink) {
       Print("sharp_sink = ", sharp_sink);
       prev_sharp_sink = sharp_sink;
   }
   if (sharp_sink_array_1 != prev_sharp_sink_array_1) {
       Print("sharp_sink_array_1 = ", sharp_sink_array_1);
       prev_sharp_sink_array_1 = sharp_sink_array_1;
   }
   if (sharp_sink_array_2 != prev_sharp_sink_array_2) {
       Print("sharp_sink_array_2 = ", sharp_sink_array_2);
       prev_sharp_sink_array_2 = sharp_sink_array_2;
   }
   if (sharp_surge_array_1 != prev_sharp_surge_array_1) {
       Print("sharp_surge_array_1 = ", sharp_surge_array_1);
       prev_sharp_surge_array_1 = sharp_surge_array_1;
   }
   if (sharp_surge_array_2 != prev_sharp_surge_array_2) {
       Print("sharp_surge_array_2 = ", sharp_surge_array_2);
       prev_sharp_surge_array_2 = sharp_surge_array_2;
   }

   if (within_and_near_to_support != prev_within_and_near_to_support) {
       Print("within_and_near_to_support = ", within_and_near_to_support);
       prev_within_and_near_to_support = within_and_near_to_support;
   }
   if (within_and_near_to_resist != prev_within_and_near_to_resist) {
       Print("within_and_near_to_resist = ", within_and_near_to_resist);
       prev_within_and_near_to_resist = within_and_near_to_resist;
   }
   if (on_top_of_support != prev_on_top_of_support) {
       Print("on_top_of_support = ", on_top_of_support);
       prev_on_top_of_support = on_top_of_support;
   }
   if (far_below_resistance != prev_far_below_resistance) {
       Print("far_below_resistance = ", far_below_resistance);
       prev_far_below_resistance = far_below_resistance;
   }
   if (double_on_top_of_support != prev_double_on_top_of_support) {
       Print("double_on_top_of_support = ", double_on_top_of_support);
       prev_double_on_top_of_support = double_on_top_of_support;
   }
   if (double_far_below_resistance != prev_double_far_below_resistance) {
       Print("double_far_below_resistance = ", double_far_below_resistance);
      prev_double_far_below_resistance = double_far_below_resistance;

   }
   if (top != prev_top) {
       Print("top = ", top);
       prev_top = top;
   }
   if (bot != prev_bot) {
       Print("bot = ", bot);
       prev_bot = bot;
   }
*/
//   if (GetHL2(0) != prev_hl2_now) {
//       Print("hl2_now = ", GetHL2(0));
//       prev_hl2_now = GetHL2(0);
//   }

}
//+------------------------------------------------------------------+

