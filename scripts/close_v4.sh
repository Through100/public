#!/bin/bash

# Load API key
source /home/karry/collective2/API_v4
strategyId="149511007"

# Function to log messages
log_message() {
    echo "$1" >> /home/karry/collective2/collective_record
}

# Define the symbol
symbol="$1"

# Step 1: Get Open Positions
positionResponse=$(curl -s -X GET "https://api4-general.collective2.com/Strategies/GetStrategyOpenPositions?StrategyIds=$strategyId" \
    -H "Authorization: Bearer $apikey" \
    -H "Accept: application/json")
echo "positionResponse: $positionResponse"
# Step 2: Extract Position Info for Given Symbol
positionInfo=$(echo "$positionResponse" | jq -r --arg symbol "$symbol" '.Results[] | select(.C2Symbol.FullSymbol == $symbol)')

if [[ -z "$positionInfo" ]]; then
    log_message "No open position found for $symbol"
    echo "No open position found for $symbol"
    exit 1
fi
echo "positionInfo: $positionInfo"
positionSize=$(echo "$positionInfo" | jq -r '.Quantity')
echo "positionSize: $positionSize"
absQuantity=$(echo "$positionSize" | awk '{print ($1 < 0) ? -$1 : $1}')
# Step 4: Determine Position Type (Long or Short)
if (( $(echo "$positionSize > 0" | bc -l) )); then
    closeSide="2"  # Sell to close if it's a long position
    log_message "$symbol is LONG with quantity $positionSize. Closing with SELL."
elif (( $(echo "$positionSize < 0" | bc -l) )); then
    closeSide="1"  # Buy to close if it's a short position
    log_message "$symbol is SHORT with quantity ${positionSize#-}. Closing with BUY."
else
    log_message "Error: Unknown position size for $symbol"
    echo "Error: Unknown position size for $symbol"
    exit 1
fi
# Step 4: Construct the JSON Payload for Closing the Position
payload=$(jq -n \
  --arg strategyId "$strategyId" \
  --arg symbol "$symbol" \
  --arg symbolType "forex" \
  --arg side "$closeSide" \
  --argjson orderQuantity "$absQuantity" \
  --arg orderType "1" \
  --arg TIF "0" \
  '{
    Order: {
      strategyId: ($strategyId | tonumber),
      orderType: $orderType,
      side: $side,
      orderQuantity: $orderQuantity,
      tif: $TIF,
      c2Symbol: {
        fullSymbol: $symbol,
        symbolType: $symbolType
      }
    }
  }')

# Step 5: Send the Close Order
response=$(curl -s -X POST "https://api4-general.collective2.com/Strategies/NewStrategyOrder" \
    -H "Authorization: Bearer $apikey" \
    -H "Content-Type: application/json" \
    -d "$payload")

# Step 6: Log the response
echo "Close Position Response: $response"
log_message "Close Position Response: $response"

