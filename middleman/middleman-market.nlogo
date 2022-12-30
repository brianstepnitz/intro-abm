__includes [
  "middleman-common.nls"
]

extensions [
  nw
]

globals [
  hide-empty-orders? ; Hide orders that didn't make trades.

  filled-buy-prices ; List of all buy prices from filled orders.
  filled-sell-prices ; List of all sell prices from filled orders.
]

;;;;;;;;;;;;;;;;;;;;
;; Setup procedures.
;;;;;;;;;;;;;;;;;;;;

;; Make the labelers for the orders.
to position-my-order-labeler [ the-color ]
  let mid-x (mean [xcor] of both-ends)
  let mid-y (mean [ycor] of both-ends)

  let order-heading link-heading
  let orthogonal-heading ifelse-value (order-heading >= 0 and order-heading <= 180) [order-heading - 90] [order-heading + 90]

  let the-labeler nobody
  ask patch mid-x mid-y [
    sprout-agent-labelers 1 [
      set size 0
      set label-color the-color
      setxy mid-x mid-y
      set heading orthogonal-heading
      forward 0.5

      ;; If we want to draw on the right side
      if ((order-heading > 90 and order-heading <= 180) or (order-heading > 270 and order-heading < 360)) [
        set heading 90
        forward 5
      ]

      set the-labeler self
    ]
  ]

  set my-labeler the-labeler
end

;; Setup
to setup-market
  setup

  set hide-empty-orders? false

  set filled-buy-prices []
  set filled-sell-prices []

  (ifelse
    network-definition = "Diamond" [
      make-network-layered 1 2 1 1
    ]

    network-definition = "Five Traders" [
      make-network-layered 1 5 1 1
    ]

    network-definition = "Two Layers of Three Traders" [
      make-network-layered 1 3 2 1
    ]

    network-definition = "Three Trader Chain" [
      make-network-layered 1 1 3 1
    ]

    network-definition = "One Trader" [
      make-network-layered 1 1 1 1
    ]

    network-definition = "2P 2Lx3T 2C" [
      make-network-layered 2 3 2 2
    ]

    network-definition = "(load from file)" [
      let filename user-file
      if (filename != false) [
        nw:load-graphml filename
      ]
    ]
  )

  toggle-strategy-labels ; Turn off strategy labels.

  ask purchase-orders [
    position-my-order-labeler magenta
  ]
  ask sale-orders [
    position-my-order-labeler pink
  ]

  set-world-mode "READY" white
  reset-ticks
end

;;;;;;;;;;;;;;;;;;;;;
;; Draw order labels.
;;;;;;;;;;;;;;;;;;;;;

;; Reports if the given order is inactive.
to-report is-order-inactive? [ the-order ]
  (ifelse
    is-purchase-order? the-order [
      report (world-mode = "INCOME PHASE" or world-mode = "SELL PHASE")
    ]

    is-sale-order? the-order [
      report (world-mode = "PRODUCTION PHASE" or world-mode = "BUY PHASE")
    ]
  )
end

;; Update this order's label.
to update-this-order-label
  ask my-labeler [
    set label order-label-string
  ]

  ifelse
  (hide-empty-orders? and items-traded = 0) or
  is-order-inactive? self
  [
    hide-link
    ask my-labeler [ hide-turtle ] ; In this case, always hide labeler.
  ] [
    show-link
    ask my-labeler [ show-turtle ]
  ]
end

;; Update all order labels.
to update-all-order-labels
  ask purchase-orders [
    update-this-order-label
  ]

  ask sale-orders [
    update-this-order-label
  ]
end

;; Toggle whether orders are visible outside their active phase.
to toggle-empty-orders
  set hide-empty-orders? not hide-empty-orders?
  update-all-order-labels
end

;;;;;;;;;;;;;;;;;
;; Run the model.
;;;;;;;;;;;;;;;;;

;; Producers produce items.
to do-production-phase
  ask producers [
    set stock (stock + runresult production-function-string)
    update-this-agent-labels
  ]
end

;; Go through a buy phase.
to do-buy-phase

  ;; Traders set a buy price.
  ask traders [
    ask my-in-sale-orders [
      update-this-order-label
    ]

    set buy-price runresult buy-strategy-string

    ask my-in-purchase-orders [
      set price 0
      set items-traded 0
    ]
  ]

  ;; Go from highest price to lowest.
  ;; (Producers want to maximize how much they can get per item)
  foreach (sort-by [ [trader1 trader2] -> [buy-price] of trader1 > [buy-price] of trader2] traders) [ the-trader ->
    ask the-trader [
      while [ money >= buy-price and any? (my-in-purchase-orders with [[stock] of end1 > 0]) ] [
        ask one-of (my-in-purchase-orders with [[stock] of end1 > 0]) [
          ask end1 [ set stock (stock - 1) ]
          ask end2 [ set money (money - buy-price) ]

          ;; Populate the purchase-order.
          set items-traded (items-traded + 1)
        ] ; end ask purchase-order
      ] ; end while
    ] ; end ask trader
  ] ; next trader

  ;; Clear the purchase orders.
  ask purchase-orders [
    set price [buy-price] of end2

    if (items-traded > 0) [ set filled-buy-prices (lput price filled-buy-prices) ]

    ask end1 [
      set money (money + [items-traded] of myself * [price] of myself)
      update-this-agent-labels
    ]
    ask end2 [
      set stock (stock + [items-traded] of myself)
      update-this-agent-labels
    ]

    update-this-order-label
  ]
end

;; Consumers earn an income.
to do-income-phase
  ask consumers [
    set money (money + runresult income-function-string)
    update-this-agent-labels
  ]
end

;; Go through a sell phase.
to do-sell-phase

  ;; Traders choose a sell price.
  ask traders [
    ask my-in-purchase-orders [
      update-this-order-label
    ]

    set sell-price runresult sell-strategy-string

    ask my-in-sale-orders [
      set price 0
      set items-traded 0
    ]
  ]

  ;; Go from lowest to highest.
  ;; (Consumers want to minimize how much they pay per item.)
  foreach (sort-on [sell-price] traders) [ the-trader ->
    ask the-trader [
      while [ stock > 0 and any? (my-in-sale-orders with [[money] of end1 > [sell-price] of end2]) ] [
        ask one-of (my-in-sale-orders with [[money] of end1 >= [sell-price] of end2]) [
          ask end1 [ set money (money - [sell-price] of the-trader) ]
          ask end2 [ set stock (stock - 1) ]

          set items-traded (items-traded + 1)
        ] ; end ask sale-order
      ] ; end while
    ] ; end ask trader
  ]; next trader

  ;; Clear the sale orders.
  ask sale-orders [
    set price [sell-price] of end2

    if (items-traded > 0) [ set filled-sell-prices (lput price filled-sell-prices) ]

    ask end1 [
      set stock (stock + [items-traded] of myself)
      update-this-agent-labels
    ]
    ask end2 [
      set money (money + [items-traded] of myself * [price] of myself)
      update-this-agent-labels
    ]

    update-this-order-label
  ]
end

;; Run the model.
to go

  ;; Step through the phases one at a time.
  (ifelse

    (world-mode = "READY" or world-mode = "SELL PHASE") [
      set-world-mode "PRODUCTION PHASE" green
      do-production-phase
    ]

    (world-mode = "PRODUCTION PHASE") [
      set-world-mode "BUY PHASE" violet
      do-buy-phase
    ]

    (world-mode = "BUY PHASE") [
      set-world-mode "INCOME PHASE" red
      do-income-phase
    ]

    (world-mode = "INCOME PHASE") [
      set-world-mode "SELL PHASE" orange
      do-sell-phase

      ;; Only advance tick after sell phase is done.
      tick
    ]
  )
end
@#$#@#$#@
GRAPHICS-WINDOW
216
10
653
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

CHOOSER
6
11
215
56
network-definition
network-definition
"One Trader" "Three Trader Chain" "Diamond" "Five Traders" "Two Layers of Three Traders" "2P 2Lx3T 2C" "(load from file)"
4

BUTTON
64
61
128
94
Setup
setup-market
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
19
99
96
132
Go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
100
99
163
132
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
8
149
109
182
Toggle Titles
toggle-titles
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
8
185
173
218
Toggle Inventory Labels
toggle-inventory-labels
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
8
221
166
254
Toggle Strategy Labels
toggle-strategy-labels
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
8
257
156
290
Toggle Empty Orders
toggle-empty-orders
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
180
506
696
656
Average Prices
tick
Price
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Buy price" 1.0 0 -8630108 true "" "plot ifelse-value any? purchase-orders with [items-traded > 0] [mean [price] of purchase-orders with [items-traded > 0]] [0]"
"Sell price" 1.0 0 -955883 true "" "plot ifelse-value any? sale-orders with [items-traded > 0] [mean [price] of sale-orders with [items-traded > 0]] [0]"

MONITOR
9
457
106
502
Mean Buy Price
mean filled-buy-prices
2
1
11

MONITOR
64
406
154
451
Max Buy Price
max filled-buy-prices
2
1
11

MONITOR
64
508
170
553
Median Buy Price
median filled-buy-prices
2
1
11

MONITOR
63
559
172
604
Modes Buy Prices
modes filled-buy-prices
2
1
11

MONITOR
63
609
149
654
Min Buy Price
min filled-buy-prices
2
1
11

MONITOR
704
406
792
451
Max Sell Price
max filled-sell-prices
2
1
11

MONITOR
652
455
747
500
Mean Sell Price
mean filled-sell-prices
2
1
11

MONITOR
704
507
808
552
Median Sell Price
median filled-sell-prices
2
1
11

MONITOR
705
556
811
601
Modes Sell Prices
modes filled-sell-prices
2
1
11

MONITOR
705
606
788
651
Min Sell Price
min filled-sell-prices
2
1
11

MONITOR
112
457
220
502
StdDev Buy Price
standard-deviation filled-buy-prices
2
1
11

MONITOR
751
455
856
500
StdDev Sell Price
standard-deviation filled-sell-prices
2
1
11

@#$#@#$#@
# Middleman Market

## WHAT IS IT?

This model shows a simplified supply chain network from producers to consumers and through a series of traders that act as middlemen in the market.

## HOW IT WORKS

### Agents

The model consists of three principal types of agents: **Producers** (green), **Traders** (yellow), and **Consumers** (red).

  * All Agents have a _stock_ indicating the number of items it currently holds, and an amount of _money_ that it currently has. Together these make up the agent's _inventory_.
  * Each Producer has a _production function_ that defines how many items it produces each tick.
  * Each Trader has a _buy strategy_ that defines the price at which it is willing to buy during the Buy Phase of the current tick.
  * Each Trader has a _sell strategy_ that defines the price at which it is willing to sell during Sell Phase of the current tick.
  * Each Consumer has an _income function_ that defines how much money it earns each tick.

> In the networks included with the model, the agents have the following defaults:
>   * All Producers produce a fixed amount of 10 items per tick.
>   * All Consumers earn a fixed amount of $100 per tick.
>   * All Traders start with a stock of 10 items and $100 in money. Producers and Consumers start with nothing.
>
> For a buy strategy, Traders start with a buy price of $1 in the first tick. In subsequent ticks, if the Trader did not make any buys in the previous round, it increases its buy price by $1 up to a maximum equal to its current amount of money. Otherwise it decreases its buy price by $1 down to a minimum of $1.
>
> Their sell strategy is similar: They start at $1. Then if they made any sales in the previous round, they increase their sell price by $1, with no maximum. Otherwise they lower their sell price by $1 down to a minimum of $1.
>
> See **Extending the Model** below for ways to change these.

### Environment

Agents exist in a supply chain consisting of a network of links represented by **Purchase Orders** (violet) and **Sale Orders** (orange).

  * Traders may have Purchase Order links with Producers or other Traders. During the Buy Phase, they may only buy items from agents with which they have a Purchase Order link.
  * Traders may have Sale Order links with Consumers or other Traders. During the Sell phase, they may only sell items to agents with which they have a Sale Order link.
  * Each Order stores the number of _items traded_ and at what _price_ they were traded between the connected agents during the current tick.

### Actions

In every tick, the simulation goes through the following phases:

#### Production Phase

All Producers produce items according to their _production function_.

#### Buy Phase

All Traders set their buy price according to their _buy strategy_.

We assume sellers want to maximize the price for which they can sell their items. Thus, going in order from the Trader with the highest buy price to the lowest (with ties broken arbitrarily), each Trader does the following:

While the Trader has enough money, it randomly selects an agent it's able to buy from, and orders one item from that agent. It then repeats this process as long as it can.

Then the simulation moves on to the Trader with the next highest buy price.

> The money and the item in that order are "locked" and cannot be used for the rest of this Buy Phase.

Once all orders have been placed, the market clears.

#### Income Phase

All Consumers earn money according to their _income function_.

#### Sell Phase

All Traders set their sell price according to their _sell strategy_.

Now we assume that buyers want to minimize the price for which they buy their items. So going in order from the Trader with the lowest sell price to the highest (with ties broken arbitrarily), each Trader now does the following:

While the Trader has stock, it randomly selects an agent it's able to sell to, and orders the sale of one item to that agent. It then repeats this process as long as it can.

Then the simulation moves on to the Trader with the next lowest sell price.

> Like with the orders in the Buy Phase, the money and the item in that sale order are then "locked" and cannot be used for the rest of this Sell Phase.

Once all sale orders have been placed, the market clears.

The tick then ends and the phases repeat from the beginning.

## HOW TO USE IT

### Inputs

The entire input of the model is contained within the _network definition_ chosen for the simulation run:

  * **One Trader**: A simple supply chain consisting of a single Producer, single Consumer, and a single middleman Trader between them.
  * **Three Trader Chain**: Three Traders connected in series between a Producer and Consumer.
  * **Diamond**: Two Traders each connected to a single Producer and single Consumer.
  * **Five Traders**: Five Traders each connected to a single Producer and single Consumer.
  * **Two Layers of Three Traders**: A single Producer connected to three Traders, a single Consumer connected to three different Traders, and then the first set of Traders each connected to each of the second set of Traders.
  * **2P 2Lx3T 2C**: Two layers of three Traders as in the previous definition, but with two Producers and two Consumers.
  * **(load from file)**: Networks saved in a custom GraphML format may be loaded into and run by this Middleman Market model.

> These GraphML files were hand-created networks that were then saved using the `nw:save-graphml` procedure of the NetLogo `nw` extension.

> The GraphML format may be self evident enough to play around with yourself if you so desire.

> Due to limitations in how this assignment can be submitted for the _Introduction to Agent-Based Modeling_ Summer 2022 course, any GraphML files included with this submission will have a ".graphml.txt" extension.

The network definition completely describe each agent's inventory, strategies, and the network topology for the simulation.

### Setup

Once a network definition has been chosen, press the **Setup** button to load the chosen network definition into the model.

### Go

Each press of the **Go once** button progresses the simulation to the next phase, from _Production Phase_ → _Buy Phase_ → _Income Phase_ → _Sell Phase_ and back again.

The **Go** button goes through those phases continuously, until unpressed.

### Toggle Buttons

These buttons control how the network is displayed in the world view. The model implements them as buttons and not switches so that they have an immediate impact on the view even when the simulation is not running.

  * **Toggle Titles** toggles whether or not the Phase Title is displayed on the world view.
  * **Toggle Inventory Labels** toggles whether or not each agent's inventory is displayed on the world view.
  * **Toggle Strategy Labels** toggles whether or not each agent's strategies (_production function_ for Producers, _income function_ for Consumers, and "_buy strategy_ / _sell strategy_" for Traders) are displayed on the world view.
  * **Toggle Empty Orders** toggles whether or not only orders that had any items traded are displayed on the world view. Displaying empty orders allows you to see what buy price / sell price a Trader is choosing even when it is not succeeding in making any purchases or sales.

## THINGS TO NOTICE

By default, there is very little randomness in the running of the simulation. There is only a little in how the simulation arbitrarily breaks ties in buy price or sell price. Still, this is enough to make most simulation runs at least a little bit different from one another.

### Outputs

#### World

  * **Title** The current phase may be displayed at the top and bottom of the world view. Toggleable via button.
  * **Inventory** Each agent's stock and money amounts update as they make trades and may be displayed beneath the agent. Toggleable via button.
  * **Orders**
    * During the Buy Phase, all Sale Order links are hidden so that only information about purchases can be seen. Similarly, during the Sell Phase, all Purchase Order links are hidden.
    * Each order's _money traded_ and _items traded_ amounts update each tick and are displayed near an order when shown. NetLogo does not provide easy ways to prevent the overlap of these labels so this information may get a little crowded in the view.
    * Whether or not to display empty orders (orders that didn't make any trades this round) is toggleable via button. Turning them off may reduce some of the clutter and highlight which agents are participating in the market. However, you won't be able to see those agents' buy or sell price from this tick directly in the world view.
  * **Strategies** Each agent's strategies (_production function_, _income function_, or "_buy strategy / sell strategy_") may be displayed above the agent. Toggleable via button.

#### Plot

The plot shows the average Buy Price and average Sell Price of ALL non-empty orders at each tick. Watch as the prices fluctuate or stabalize, depending on the topology of the network.

#### Monitors

The monitors beside the plot show the indicated statistic for all non-empty orders throughout the history of the simulation.

## THINGS TO TRY

The networks in the _network definition_ chooser approximately go in order of increasing competition. How do the different topologies affect the prices?

Try running the simulation a few times with the included "fan-network.graphml" network definition. Most of the time, one of the Traders is able to out-compete two of the others so that those two are effectively unable to participate in the market. Watch the plot of the prices to see what happens each time one of the Traders is knocked out.

## EXTENDING THE MODEL

Different agent strategies would certainly produce profoundly different behaviors in the simulation. An earlier implementation of this model experimented with that some more, but in the interest of simplicity this was dropped from the current implementation. However, some of the infrastructure for experimenting with this still exists in the code.

In particular, agent strategies (_production function_ for Producers, _income function_ for Consumers, and _buy strategy / sell strategy_ for Traders) are all stored as Strings representing reporters to be run from an agent context using the NetLogo `runresult` keyword.

When choosing one of the predefined network definitions (not from a file), the model uses a `default-`_X_ variable to set the strategy of each corresponding agent. One of the first changes could be changing one of these variables. For example:

```
set default-income-function "random 100"
```

to have Consumers earn a random amount of money each tick from $0 to $99.

More advanced reporters that take up more than one line could be defined in the code and then set in one of those variables. For example:

```
;; Cycles through a list.
to-report cycle-thru [ a-list ]
  report item (ticks mod length a-list) a-list
end

;; then,

set default-production-function "cycle-thru [10 1 9 2 8 3 7 4 6 5]"

```
To have producers cycle through a list to determine how much it produces at each tick.

Even more advanced extensions may include having different Traders have different buy or sell strategies from other Traders, maybe to see which strategies perform better over others. There are many possible directions to go!

## NETLOGO FEATURES

The NetLogo `nw` extension was used to save and load supply chain network definitions to and from GraphML files.

To allow for the possibility of the model user to easily use their own agent strategies, agents store their _production function_, _income function_, _buy strategy_, or _sell strategy_ as Strings that are compiled and run with `runresult`. This also allowed the strategy to be displayable as a label on the world view.

Allowing multiple labels per agent, and trying to control how labels were displayed on links, led to using invisible turtles `tie`'d to agents to display those labels. Inspiration was taken from the "Label Position Example" in the Code Examples section of the NetLogo Model Library.

The "Toggle _X_" buttons might more intutively be switches. However, in order to have them take effect as soon as they were switched, the model needed to implement them as buttons.

## RELATED MODELS

Some inspiration was taken from the [Beer Distribution Game](https://en.wikipedia.org/w/index.php?title=Beer_distribution_game&oldid=1057752108) and its variant described by [Nair and Vidal](https://jmvidal.cse.sc.edu/netlogomas/beernet/index.html) (with a download of a NetLogo implementation included at that link).

## CREDITS AND REFERENCES

The idea of Middleman, especially the rules splitting up into a separate Buy Phase and Sell Phase, largely came from "Games with Pencil and Paper" (1993) by Eric Solomon.

Other references:

John D. Sterman, (1989) Modeling Managerial Behavior: Misperceptions of Feedback in a Dynamic Decision Making Experiment. Management Science 35(3):321-339.
Anand Nair and José M. Vidal. Supply Network Topology and Robustness against Disruptions: An investigation using Multi-agent Model. International Journal of Production Research, 49(5):1391--1404, 2011.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
