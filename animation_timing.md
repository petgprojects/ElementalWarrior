
# Fireball
## fireball_summon_right.usdz

| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon    | 0              | 1            | 1            | Shows hand going from palm down to palm up |
| summon_active       | 1              | 3            | 2            | Shows hand with fireball in palm  |
| de_summon           | 3              | 4            | 1            | Shows hand de-summoning fireball |

## fireball_maintain_right.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon | 0 | 1 | 1 | Shows hand going from palm down to palm up |
| un_summon | 1 | 1.5 | 0.5 | Shows hand quickly going from palm up to palm down to maintain the fireball in place |
| remain_in_place | 1.5 | 2 | 0.5 | Hand stays in palm down position (fireball resting above face down hand) |
| move_hand_freely | 2 | 4 | 2 | Hand moves freely palm down, showing it can move without the fireball tracking it |
| return_to_start | 4 | 5 | 1 | Hand returns to starting position, remaining palm down - fireball still not tracking the palm |

## fireball_follow_right.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon | 0 | 1 | 1 | Shows hand going from palm down to palm up |
| move_hand | 1 | 5 | 4 | Shows fireball tracking hand |
| rotate_to_desummon | 5 | 6 | 1 |de summons fireball |
| maintain_desummon | 6 | 7 | 1 | maintains the de-summon state until next loop |

## fireball_punch_right.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon | 0 | 1 | 1 | Shows hand going from palm down to palm up |
| rotate-to-desummon | 1 | 2 | 1 | Shows hand going from palm up to palm down to keep fireball in place |
| move_back | 2 | 3 | 1 | Shows open hand (palm still down) moving back in place, fireball should persist where it was |
| curl_fist | 3 | 3.33 | 0.33 | Shows open hand curling into a fist |
| launch_punch | 3.33 | 3.66 | 0.33 | Shows curled fist launching at fireball |
| revert_to_start | 3.66 | 5 | 1.33 | Shows fist uncurling and simultaneously reverting to starting position |
| maintain_desummon | 5 | 6 | 1 | maintains the de-summon state until next loop |

## fireball_crossPunch_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon (right) | 0 | 1 | 1 | Shows right hand going from palm down to palm up |
| maintain_summon_state (right) | 1 | 3 | 2 | Shows right hand maintaining summon state (palm up, fingers extended) |
| revert_to_start (right) | 3 | 3.66 | 0.66 | Shows right hand rotating palm back down to start state |
| create_fist (left) | 0 | 1.33 | 1.33 | Shows left hand pulling back and creating fist |
| maintain_fist (left) | 1.33 | 2 | 0.66 | Shows left hand maintaining pulled back curled fist |
| launch_punch (left) | 2 | 2.33 | 0.33 | Shows left hand launching curled fist at the fireball |
| revert_to_start (left) | 2.33 | 3.66 | 1.33 | Shows left hand simultaneously uncurling fist and returning to initial state |

## fireball_combine_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon (left) | 0 | 1 | 1 | Shows left hand going from palm down to palm up |
| move_summoned_hand (left) | 1 | 1.33 | 0.33 | Shows left hand (in summon position) moving beside right hand |
| rotate_summoned_hand (left) | 1.33 | 2 | 0.66 | Shows left hand rotating pinky down into right hand to initiate combined fireball |
| revert_to_start (left) | 2 | 3.66 | 1.66 | Shows left hand simultaneously flipping palm from facing sky to facing floor, while moving back to the starting position |
| maintain_start_position (left) | 3.66 | 6 | 2.33 | Shows left hand staying in start position until next loop |
| rotate_to_summon (right) | 0 | 1 | 1 | Shows right hand going from palm down to palm up |
| maintain_summon_position (right) | 1 | 1.33 | 0.33 | Shows right hand staying in the summoning position |
| accept_combined_fireball (right) | 1.33 | 1.66 | 0.33 | Shows right hand accepting the combined fireball from left (right hand stays static here) |
| maintain_combined_fireball (right) | 1.66 | 3.66 | 2 | Shows right hand holding combined fireball (right hand stays static here) |
| move_combined_fireball (right) | 3.66 | 5.33 | 1.66 | Shows right hand moving while staying in summon position, demonstrating tracking a combined fireball with the palm |
| revert_to_start (right) | 5.33 | 6 | 0.66 | Shows right hand rotating palm down to de-summon fireball and revert to start position |

# Flamethrower:
## flamethrower_summon_right.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon | 0 | 1 | 1 | Shows hand going from palm facing floor to palm facing forward to summon flamethrower |
| move_flamethrower | 1 | 4 | 3 | Shows hand remaining in flamethrower summon position (palm facing forward), moving hand through space to demonstrate flamethrower tracking the hand |
| rotate_to_desummon | 4 | 5 | 1 | Shows hand after reverting to starting position, rotating the palm from facing out to facing down to desummon the flamethrower |

## flamethrower_combine_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| rotate_to_summon (both) | 0 | 1 | 1 | Shows both hands rotating from palm facing the floor to palm facing out to summon the flamethrower |
| move_away (both) | 1 | 2 | 1 | Shows left hand moving away from right hand and vice versa to demonstrate single hand flamethrower tracking |
| move_in (both) | 2 | 3 | 1 | Shows left hand moving in to right and vice versa to prepare to combine the fireball |
| combine (both) | 3 | 3 | 0 | At this point, the hands are synced and the flamethrowers should combine |
| move_combined (both) | 3 | 5 | 2 | Both hands move in sync in the combined flamethrower position to demonstrate combined flamethrower tracking |
| separate_hands (both) | 5 | 7 | 2 | Hands separate from combined position while moving, showing the combined flamethrower separating into two separate jets. Simultaneously, they are moving back to their starting coordinates |
| rotate_down (both) | 7 | 8 | 1 | Hands rotate from palms facing out to palms facing down, demonstrating de-summoning the flamethrowers |

# Wall:
## wall_summon_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| hands_extend | 0 | 1 | 1 | Both hands extend from (hands open, fingertips facing down) moving both up and forward, while rotating into (palms facing down, fingertips facing forward), demonstrating summoning a wall of fire |
| hands_stay | 1 | 2.66 | 1.66 | Both hands remain in the summoning position (palms facing down, fingers extended) |
| return_to_start | 2.66 | 4 | 1.33 | Both hands simultaneously rotate fingertips such that they're facing down and palm is facing backwards, and move back to the starting position |

## wall_width_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| hands_extend | 0 | 1 | 1 | Both hands extend from (hands open, fingertips facing down) moving both up and forward, while rotating into (palms facing down, fingertips facing forward), demonstrating summoning a wall of fire |
| hands_separate | 1 | 3 | 2 | Both hands remain in summon position, separating from eachother demonstrating increasing the width of the wall |
| hands_combine | 3 | 5 | 2 | Both hands remain in summon position, moving closer together, demonstrating decreasing the width of the wall |
| revert_to_start | 5 | 6 | 1 | Both hands simultaneously rotate such that palms are facing backwards and fingertips facing down, and move to starting position |
| remain_in_start_position | 6 | 7 | 1 | Both hands remain in the starting position, waiting for the next loop |

## wall_height_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| hands_extend | 0 | 1 | 1 | Both hands extend from (hands open, fingertips facing down) moving both up and forward, while rotating into (palms facing down, fingertips facing forward), demonstrating summoning a wall of fire |
| summon_remains | 1 | 2 | 1 | Both hands remain in summon position (palms facing floor, fingertips extended), not moving |
| increase_height | 2 | 3 | 1 | Both hands move up while staying in the summon position simultaneously, to increase the height of the wall |
| decrease_height | 3 | 4 | 1 | Both hands move down while staying in the summon position simultaneously, to decrease the height of the wall |
| revert_to_start | 4 | 5 | 1 | Both hands simultaneously rotate such that palms are facing backwards and fingertips facing down, and move to starting position |

## wall_location_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| hands_extend | 0 | 1 | 1 | Both hands extend from (hands open, fingertips facing down) moving both up and forward, while rotating into (palms facing down, fingertips facing forward), demonstrating summoning a wall of fire |
| summon_remains | 1 | 2 | 1 | Both hands remain in summon position (palms facing floor, fingertips extended), not moving |
| move_right | 2 | 3 | 1 | Both hands remain in summon position while moving right to move the wall to the right |
| move_back | 3 | 4 | 1 | Both hands remain in the summon position while moving back to move the wall backwards |
| move_left_and_forward | 4 | 5 | 1 | Both hands remain in the summon position while moving left and forwards to move the wall left and forwards |
| revert_to_start | 5 | 6 | 1 | Both hands simultaneously rotate such that palms are facing backwards and fingertips facing down, and move to starting position |
| remain_in_start_position | 6 | 7 | 1 | Both hands remain in the starting position, waiting for the next loop |

## wall_rotation_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| hands_extend | 0 | 1 | 1 | Both hands extend from (hands open, fingertips facing down) moving both up and forward, while rotating into (palms facing down, fingertips facing forward), demonstrating summoning a wall of fire |
| summon_remains | 1 | 2 | 1 | Both hands remain in summon position (palms facing floor, fingertips extended), not moving |
| rotate_counterclockwise | 2 | 3 | 1 | Right hand moves forwards, while left simultaneously moves backwards to rotate the wall counterclockwise |
| rotate_clockwise | 3 | 4 | 1 | Right hand moves backwards, while left simultaneously moves forwards, to rotate the wall clockwise |
| reset_rotation | 4 | 5 | 1 | Right hand moves slightly forwards while left moves slightly backwards to reset the wall's rotation to it's original state |
| revert_to_start | 5 | 6 | 1 | Both hands simultaneously rotate such that palms are facing backwards and fingertips facing down, and move to starting position |

## wall_confirm_both.usdz
| Animation Name      | Start Time (s) | End Time (s) | Duration (s) | Notes                |
|---------------------|----------------|--------------|--------------|----------------------|
| hands_extend | 0 | 0.33 | 0.33 | Both hands extend from (hands open, fingertips facing down) moving both up and forward, while rotating into (palms facing down, fingertips facing forward), demonstrating summoning a wall of fire |
| summon_remains | 0.33 | 1 | 0.66 | Both hands remain in summon position (palms facing floor, fingertips extended), not moving |
| increase_height | 1 | 2 | 1 | Both hands move up while staying in the summon position simultaneously, to increase the height of the wall |
| height_remains | 2 | 3 | 1 | Both hands remain in summon position (palms facing floor, fingertips extended), at the new height |
| fist_clench | 3 | 3.16 | 0.16 | Both hands clench into fists |
| fist_unclench | 3.16 | 3.33 | 0.16 | Both fists unclench into open hands (palms down, fingers open, facing out), finalizing the confirmation process of the wall. It should now fade from blue to red fire |
| summon_remains | 3.33 | 3.66 | 0.33 | Both hands remain in summon position (palms facing floor, fingertips extended), not moving |
| revert_to_start | 3.66 | 5 | 1.33 | Both hands simultaneously rotate such that palms are facing backwards and fingertips facing down, and move to starting position |
| remain_in_start_position | 5 | 7 | 2 | Both hands remain in the starting position, waiting for the next loop |
