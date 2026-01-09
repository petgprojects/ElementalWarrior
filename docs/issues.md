# Individual Sections
## Fireball
1) Maintain - using fireball_follow_right.usdz, not fireball_maintain_right.usdz animation. I've cleaned and rebuilt the app several times, but it's the wrong animation still.
2) Punch - looks good, but punch doesn't actually launch the fireball. Include a fireball animation in the punch.
3) Cross-punch - fireball is summoning over left hand, it should summon over right hand. Left hand is punching, not summoning. As well, please include the "launch" animation after the punch happens.
4) Combine - It starts with both hands summoning a fireball (one in each hand). The right hand fireball is tracking properly, but the left one is spawning below the hand, not above. As well, when the combine happens, the fireball teleports under the left hand, not the right hand. The right hand is the one that should recieve it. When the animation is in it's final act of the right hand moving to show tracking of the combined fireball, the fireball does move in sync with the right hand, but it is below the left hand, not above the right hand. Finally, the new fireball is not a "combined" fireball, it is simply a single regular fireball. Make it a combined fireball, and make sure to show the "combining" animation.

## Flamethrower
1) Summon - The flamethrower jet is coming out of the left hand side of the hand, not the palm. Fix the direction of this please.
2) Combine - same issue as summon: jets come out of the left side, not the front of the palm. As well, there is no "combine" animation - make sure to include a proper animation for the combination.

## Wall
### Common issues
1) The fire wall just kind of appears below the hands. Make it appear in front. The hands move forwards and up to summon, so maybe set the wall to be below the hands in their summon state (after they've moved up and forwards)
2) The fire wall is perpindicular to the hands - make it parallel to the hands, the same way it is when the user actually summons it
3) The fire wall spawns as red flames. Make it spawn as blue, the same as how the user would see it. Right now, the "confirm" animation turns the flames blue from red, when it should be vice versa
4) The wall initially spawns quite high, while when the user does it, it would naturally spawn as just a line of embers. Keep it spawning as a line of embers, and raise/lower it according to the animation.
5) The wall initally spawns quite narrow - incrase the initial width by double. 


# General bugs

## Loading Screen
On first load of an animation, it takes quite a while before the animation actually loads. Loading a new tutorial while one is already open is quite fast though. 
On that first load, please show a little loading screen or something indicating to the user that something is in fact happening.

## Navigating the animation
I want the user to be able to scale/move the animation by pinching and dragging the animation itself, not just the bar at the bottom of the window. There must be a way to do this, so please figure it out.

## UI
Right now, the right hand side of the "tutorials" window is nearly empty. The left side is made up of the list of tutorials, and the right just has "Play"/"Stop", and the text preview of what's happening. Make this a little cleaner and remove some of the empty space.