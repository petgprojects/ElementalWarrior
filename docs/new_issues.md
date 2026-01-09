# Fireball
## General
### Animations
The fireball animations don't have a clean spawn-in/spawn-out animation, they just kind of appear/disappear. Please make the animation the same as what the user sees when they do it themselves. 


## Specific
### Punch
The punch launches the fireball to the left, not in front of the hand. Please fix this.

### Cross-punch
The fireball is spawning under the left hand, not the right hand (left makes the first, right summons). Then, when the left goes to punch the summoned fireball out of the right, the fireball doesn't launch. It just explodes immediately when the left hand (fist) reaches the right (summon position). Fix both the positioning of the fireball (move to in right palm rather than under left fist), and the launch of the fireball.

### Combine
Both fireballs initially spawn under the hands, not above them. Then, when the left moves in to share it's fireball with the right hand, it's inverted - the right hand's fireball goes to the left, and it stays at the initial left spawn point. It should transfer to the right hand, and track the right hand's palm after the combination.

# Flamethrower
## General
### Flamethrower location
The flamethrower "ball" is currently inside the hand. Please move it so it's in front of the palm rather than inside it. 

## Specific
### Combine
When the combine animation is playing, the right hand jets forward, but the left jets backwards. And then, when they go to combine the flamethrowers, the combined jet is aimed backwards. Please invert the direction of the left jet and the combined jet.

# Wall
## General
### Wall spawn size
Right now, the wall spawns as a blue jet. I want it to spawn as embers only , and only animations that change the wall height should move past ember stage. 

### Wall spawn location/timing
1) The wall spawns the second the animation starts, rather than once the animation has entered the "zombie" pose. I want the wall to only spawn when the hands have properly initiated the spawn, the same way the user would. 

2) When the animation starts, there is a jet that follows the animation's hands until they enter "zombie" pose, where it remains static (as it should). The jet should not appear until the animation is in zombie pose though, and instead should have nothing.

