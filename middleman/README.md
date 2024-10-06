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

