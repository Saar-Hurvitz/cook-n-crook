## EventBus.gd
## Global signal hub so maze, chefs, and HUD communicate without tight coupling.
## Inherits from: Node (registered as an autoload singleton).
extends Node

# Signals are emitted/connect externally; suppress "never used in this class" warnings.
@warning_ignore_start("unused_signal")

## Emitted when a gatherer collects an ingredient. Team chefs listen to add UI items.
signal ingredient_collected(team: int, ingredient_id: String)

## Emitted when a gatherer steals an ingredient from the opposing gatherer.
signal ingredient_stolen(thief_team: int, victim_team: int, ingredient_id: String)

## Emitted when a chef finishes the active recipe and scores points.
signal recipe_completed(team: int, points: int, dish_name: String)

## Emitted when a new recipe is assigned after completion or at match start.
signal recipe_assigned(team: int, recipe: RecipeData)

## Emitted when a new shared dish order is generated for both chefs.
signal order_assigned(dish_id: String)

## Emitted when the player clicks a quadrant and control switches.
signal control_switched(player_slot: int)

## Emitted every second while the match timer ticks down.
signal timer_updated(seconds_remaining: float)

## Emitted once when the global timer reaches zero.
signal match_ended(winning_team: int, team_a_score: int, team_b_score: int)

## Emitted when live gameplay begins after the pre-match countdown.
signal match_started

## Emitted when gatherers collide — used for combat / steal feedback.
signal gatherer_clash(attacker_team: int, defender_team: int)

## Emitted when a gatherer throws a knife.
signal knife_thrown(team: int)

## Emitted whenever a gatherer's health changes (also on spawn / respawn).
signal gatherer_health_changed(team: int, current_health: int, max_health: int)

## Emitted once when a gatherer dies and begins its respawn lock.
signal gatherer_respawn_started(team: int)

## Emitted each second of the respawn lock with the number to display (10 → 1).
signal gatherer_respawn_tick(team: int, seconds_left: int)

## Emitted when the respawn lock ends and the gatherer can move again.
signal gatherer_respawn_finished(team: int)

## Emitted whenever a gatherer's knife ammo changes (throw, resupply, reset).
signal gatherer_knives_changed(team: int, count: int, max_knives: int)

## Emitted when a chef requests a knife be delivered to their team's gatherer.
signal knife_resupply_requested(team: int)

## Emitted whenever a gatherer's spoon ammo changes (swing, resupply, reset).
signal gatherer_spoons_changed(team: int, count: int, max_spoons: int)

## Emitted when a chef requests a spoon charge be delivered to their team's gatherer.
signal spoon_resupply_requested(team: int)

@warning_ignore_restore("unused_signal")
