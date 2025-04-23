#!/bin/bash

# Load API key
source /home/karry/collective2/API_v4
strategyId="149511007"

# Function to log messages
log_message() {
    echo "$1" >> /home/karry/collective2/collective_record
}

# Define the symbol and quantity
symbol="$1"
quantity=5

# Construct the JSON payload
payload=$(jq -n \
  --arg strategyId "$strategyId" \
  --arg symbol "$symbol" \
  --arg symbolType "forex" \
  --arg side "1" \
  --argjson orderQuantity "$quantity" \
  --arg orderType "1" \
  --arg TIF "0" \
  --argjson stopLoss null \
  --argjson limit null \
  '{
    Order: {
      strategyId: ($strategyId | tonumber),
      orderType: $orderType,
      side: $side,
      orderQuantity: $orderQuantity,
      limit: $limit,
      tif: $TIF,
      stopLoss: $stopLoss,
      c2Symbol: {
        fullSymbol: $symbol,
        symbolType: $symbolType
      }
    }
  }')

response=$(curl -s -X POST "https://api4-general.collective2.com/Strategies/NewStrategyOrder" \
    -H "Authorization: Bearer $apikey" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>&1)
echo $response
echo "CURL Response: $response" >> /home/karry/collective2/collective_record

# Log the response
log_message "Order Response: $response"

