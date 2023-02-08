/*
* Important note about attack_alien : In our code, attack_ procs are received by src, not dealt by src
* For example, attack_alien defined for humans means what will happen to THEM when attacked by an alien
* In that case, the first argument is always the attacker. For attack_alien, it should always be Xenomorph sub-types
*/

//#define DEBUG_ATTACK_ALIEN

/mob/living/proc/attack_alien_grab(mob/living/carbon/xenomorph/X)
	if(X == src || anchored || buckled || X.buckled)
		return FALSE

	if(!Adjacent(X))
		return FALSE

	X.start_pulling(src)
	return TRUE

/mob/living/carbon/human/attack_alien_grab(mob/living/carbon/xenomorph/X)
	if(check_shields(COMBAT_TOUCH_ATTACK, X.xeno_caste.melee_damage, "melee"))
		return ..()
	X.visible_message(span_danger("\The [X]'s grab is blocked by [src]'s shield!"),
		span_danger("Our grab was blocked by [src]'s shield!"), null, 5)
	playsound(loc, 'sound/weapons/alien_claw_block.ogg', 25, TRUE) //Feedback
	return FALSE


/mob/living/proc/attack_alien_disarm(mob/living/carbon/xenomorph/X, dam_bonus)

	SEND_SIGNAL(src, COMSIG_LIVING_MELEE_ALIEN_DISARMED, X)
	X.do_attack_animation(src, ATTACK_EFFECT_DISARM2)
	playsound(loc, 'sound/weapons/alien_knockdown.ogg', 25, TRUE)
	X.visible_message(span_warning("\The [X] shoves [src]!"),
	span_warning("We shove [src]!"), null, 5)
	return TRUE

/mob/living/proc/can_xeno_slash(mob/living/carbon/xenomorph/X)
	if(CHECK_BITFIELD(X.xeno_caste.caste_flags, CASTE_IS_INTELLIGENT)) // intelligent ignore restrictions
		return TRUE
	else if(isnestedhost(src))
		for(var/obj/item/alien_embryo/embryo in src)
			if(!embryo.issamexenohive(X))
				continue
			to_chat(X, span_warning("We should not harm this host! It has a sister inside."))
			return FALSE
	return TRUE

/mob/living/carbon/human/can_xeno_slash(mob/living/carbon/xenomorph/X)
	. = ..()
	if(!.)
		return FALSE
	if (wear_id?.iff_signal & X.iff_signal)
		return FALSE

/mob/living/proc/get_xeno_slash_zone(mob/living/carbon/xenomorph/X, set_location = FALSE, random_location = FALSE, no_head = FALSE)
	return

/mob/living/carbon/get_xeno_slash_zone(mob/living/carbon/xenomorph/X, set_location = FALSE, random_location = FALSE, no_head = FALSE, ignore_destroyed = TRUE)
	var/datum/limb/affecting
	if(set_location)
		affecting = get_limb(set_location)
	else if(SEND_SIGNAL(X, COMSIG_XENOMORPH_ZONE_SELECT) & COMSIG_ACCURATE_ZONE)
		affecting = get_limb(X.zone_selected)
	else
		affecting = get_limb(ran_zone(X.zone_selected, 70))
	if(!affecting || (random_location && !set_location) || (ignore_destroyed && !affecting.is_usable())) //No organ or it's destroyed, just get a random one
		affecting = get_limb(ran_zone(null, 0))
	if(!affecting || (no_head && affecting == get_limb("head")) || (ignore_destroyed && !affecting.is_usable()))
		affecting = get_limb("chest")
	return affecting

/mob/living/proc/attack_alien_harm(mob/living/carbon/xenomorph/X, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)

	if(!can_xeno_slash(X))
		return FALSE

	var/damage = X.xeno_caste.melee_damage * X.xeno_melee_damage_modifier
	if(!damage)
		return FALSE

	var/datum/limb/affecting = get_xeno_slash_zone(X, set_location, random_location, no_head)
	var/armor_block = 0

	var/list/damage_mod = list()
	var/list/armor_mod = list()

	var/signal_return = SEND_SIGNAL(X, COMSIG_XENOMORPH_ATTACK_LIVING, src, damage, damage_mod, armor_mod)

	// if we don't get any non-stacking bonuses dont apply dam_bonus
	if(!(signal_return & COMSIG_XENOMORPH_BONUS_APPLIED))
		damage_mod += dam_bonus

	if(!(signal_return & COMPONENT_BYPASS_ARMOR))
		armor_block = get_soft_armor("melee", affecting)

	for(var/i in damage_mod)
		damage += i

	for(var/i in armor_mod)
		armor_block *= i

	if(!(signal_return & COMPONENT_BYPASS_SHIELDS))
		damage = check_shields(COMBAT_MELEE_ATTACK, damage, "melee")

	if(!damage)
		X.visible_message(span_danger("\The [X]'s slash is blocked by [src]'s shield!"),
			span_danger("Our slash is blocked by [src]'s shield!"), null, COMBAT_MESSAGE_RANGE)
		return FALSE

	var/attack_sound = "alien_claw_flesh"
	var/attack_message1 = span_danger("\The [X] slashes [src]!")
	var/attack_message2 = span_danger("We slash [src]!")
	var/log = "slashed"

	//Somehow we will deal no damage on this attack
	if(!damage)
		playsound(X.loc, 'sound/weapons/alien_claw_swipe.ogg', 25, 1)
		X.do_attack_animation(src)
		X.visible_message(span_danger("\The [X] lunges at [src]!"), \
		span_danger("We lunge at [src]!"), null, 5)
		return FALSE

	X.do_attack_animation(src, ATTACK_EFFECT_REDSLASH)

	//The normal attack proceeds
	playsound(loc, attack_sound, 25, 1)
	X.visible_message("[attack_message1]", \
	"[attack_message2]")

	if(status_flags & XENO_HOST && stat != DEAD)
		log_combat(X, src, log, addition = "while they were infected")
	else //Normal xenomorph friendship with benefits
		log_combat(X, src, log)

	apply_damage(damage, BRUTE, affecting, armor_block, TRUE, TRUE, updating_health = TRUE) //This should slicey dicey

	return TRUE

/mob/living/silicon/attack_alien_disarm(mob/living/carbon/xenomorph/X, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)

	if(stat == DEAD) //A bit of visual flavor for attacking Cyborgs. Sparks!
		return FALSE
	. = ..()
	if(!.)
		return
	var/datum/effect_system/spark_spread/spark_system
	spark_system = new /datum/effect_system/spark_spread()
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)
	spark_system.start(src)
	playsound(loc, "alien_claw_metal", 25, TRUE)

/mob/living/silicon/attack_alien_harm(mob/living/carbon/xenomorph/X, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)

	if(stat == DEAD) //A bit of visual flavor for attacking Cyborgs. Sparks!
		return FALSE
	. = ..()
	if(!.)
		return
	var/datum/effect_system/spark_spread/spark_system
	spark_system = new /datum/effect_system/spark_spread()
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)
	spark_system.start(src)
	playsound(loc, "alien_claw_metal", 25, TRUE)


/mob/living/carbon/xenomorph/attack_alien_harm(mob/living/carbon/xenomorph/X, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)
	if(issamexenohive(X))
		X.visible_message(span_warning("\The [X] nibbles [src]."),
		span_warning("We nibble [src]."), null, 5)
		return FALSE
	return ..()


/mob/living/carbon/human/attack_alien_harm(mob/living/carbon/xenomorph/X, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)

	if(stat == DEAD)
		if(istype(wear_ear, /obj/item/radio/headset/mainship))
			var/obj/item/radio/headset/mainship/cam_headset = wear_ear
			if(cam_headset.camera.status)
				cam_headset.camera.toggle_cam(null, FALSE)
				playsound(loc, "alien_claw_metal", 25, 1)
				X.do_attack_animation(src, ATTACK_EFFECT_CLAW)
				to_chat(X, span_warning("We disable the creatures hivemind sight apparatus."))
				return FALSE

		if(length(static_light_sources) || length(hybrid_light_sources) || length(affected_movable_lights))
			playsound(loc, "alien_claw_metal", 25, 1)
			X.do_attack_animation(src, ATTACK_EFFECT_CLAW)
			disable_lights(sparks = TRUE)
			to_chat(X, span_warning("We disable whatever annoying lights the dead creature possesses."))
		else
			to_chat(X, span_warning("[src] is dead, why would we want to touch it?"))
		return FALSE

	SEND_SIGNAL(X, COMSIG_XENOMORPH_ATTACK_HUMAN, src)

	. = ..()
	if(!.)
		return FALSE

//Every other type of nonhuman mob //MARKER OVERRIDE
/mob/living/attack_alien(mob/living/carbon/xenomorph/X, damage_amount = X.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)
	if(X.status_flags & INCORPOREAL)
		return FALSE

	if (X.fortify)
		return FALSE

	switch(X.a_intent)
		if(INTENT_HELP)
			if(on_fire)
				X.visible_message(span_danger("[X] stares at [src]."), span_notice("We stare at the roasting [src], toasty."), null, 5)
				return FALSE
			X.visible_message(span_notice("\The [X] caresses [src] with its scythe-like arm."), \
			span_notice("We caress [src] with our scythe-like arm."), null, 5)
			return FALSE

		if(INTENT_GRAB)
			return attack_alien_grab(X)

		if(INTENT_HARM, INTENT_DISARM)
			return attack_alien_harm(X)
	return FALSE

/mob/living/attack_larva(mob/living/carbon/xenomorph/larva/M)
	M.visible_message(span_danger("[M] nudges its head against [src]."), \
	span_danger("We nudge our head against [src]."), null, 5)

/// UV_SHITCODE_VARIANT ///

/mob/living/proc/attack_uv_grab(mob/living/carbon/xenomorph/zuv/Z)
	if(Z == src || anchored || buckled || Z.buckled)
		return FALSE

	if(!Adjacent(Z))
		return FALSE

	Z.start_pulling(src)
	return TRUE

/mob/living/carbon/human/attack_uv_grab(mob/living/carbon/xenomorph/zuv/Z)
	if(check_shields(COMBAT_TOUCH_ATTACK, Z.xeno_caste.melee_damage, "melee"))
		return ..()
	Z.visible_message(span_danger("\The [Z]'s grab is blocked by [src]'s shield!"),
		span_danger("Our grab was blocked by [src]'s shield!"), null, 5)
	playsound(loc, 'sound/weapons/alien_claw_block.ogg', 25, TRUE) //Feedback
	return FALSE


/mob/living/proc/attack_uv_disarm(mob/living/carbon/xenomorph/zuv/Z, dam_bonus)

	SEND_SIGNAL(src, COMSIG_LIVING_MELEE_ALIEN_DISARMED, Z)
	Z.do_attack_animation(src, ATTACK_EFFECT_DISARM2)
	playsound(loc, 'sound/weapons/alien_knockdown.ogg', 25, TRUE)
	Z.visible_message(span_warning("\The [Z] shoves [src]!"),
	span_warning("We shove [src]!"), null, 5)
	return TRUE

/mob/living/proc/can_uv_slash(mob/living/carbon/xenomorph/zuv/Z)
	if(CHECK_BITFIELD(Z.xeno_caste.caste_flags, CASTE_IS_INTELLIGENT)) // intelligent ignore restrictions
		return TRUE
	else if(isnestedhost(src))
		for(var/obj/item/alien_embryo/embryo in src)
			if(!embryo.issamexenohive(Z))
				continue
			to_chat(Z, span_warning("We should not harm this host! It has a sister inside."))
			return FALSE
	return TRUE

/mob/living/carbon/human/can_uv_slash(mob/living/carbon/xenomorph/zuv/Z)
	. = ..()
	if(!.)
		return FALSE
	if (wear_id?.iff_signal & Z.iff_signal)
		return FALSE

/mob/living/proc/get_uv_slash_zone(mob/living/carbon/xenomorph/zuv/Z, set_location = FALSE, random_location = FALSE, no_head = FALSE)
	return

/mob/living/carbon/get_uv_slash_zone(mob/living/carbon/xenomorph/zuv/Z, set_location = FALSE, random_location = FALSE, no_head = FALSE, ignore_destroyed = TRUE)
	var/datum/limb/affecting
	if(set_location)
		affecting = get_limb(set_location)
	else if(SEND_SIGNAL(Z, COMSIG_XENOMORPH_ZONE_SELECT) & COMSIG_ACCURATE_ZONE)
		affecting = get_limb(Z.zone_selected)
	else
		affecting = get_limb(ran_zone(Z.zone_selected, 70))
	if(!affecting || (random_location && !set_location) || (ignore_destroyed && !affecting.is_usable())) //No organ or it's destroyed, just get a random one
		affecting = get_limb(ran_zone(null, 0))
	if(!affecting || (no_head && affecting == get_limb("head")) || (ignore_destroyed && !affecting.is_usable()))
		affecting = get_limb("chest")
	return affecting

/mob/living/proc/attack_uv_harm(mob/living/carbon/xenomorph/zuv/Z, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)

	if(!can_uv_slash(Z))
		return FALSE

	var/damage = Z.xeno_caste.melee_damage * Z.xeno_melee_damage_modifier
	if(!damage)
		return FALSE

	var/datum/limb/affecting = get_uv_slash_zone(Z, set_location, random_location, no_head)
	var/armor_block = 0

	var/list/damage_mod = list()
	var/list/armor_mod = list()

	var/signal_return = SEND_SIGNAL(Z, COMSIG_XENOMORPH_ATTACK_LIVING, src, damage, damage_mod, armor_mod)

	// if we don't get any non-stacking bonuses dont apply dam_bonus
	if(!(signal_return & COMSIG_XENOMORPH_BONUS_APPLIED))
		damage_mod += dam_bonus

	if(!(signal_return & COMPONENT_BYPASS_ARMOR))
		armor_block = get_soft_armor("melee", affecting)

	for(var/i in damage_mod)
		damage += i

	for(var/i in armor_mod)
		armor_block *= i

	if(!(signal_return & COMPONENT_BYPASS_SHIELDS))
		damage = check_shields(COMBAT_MELEE_ATTACK, damage, "melee")

	if(!damage)
		Z.visible_message(span_danger("\The [Z]'s momentum is blocked by [src]'s shield!"),
			span_danger("Our momentum is blocked by [src]'s shield!"), null, COMBAT_MESSAGE_RANGE)
		return FALSE

	var/attack_sound = "punch"
	var/attack_message1 = span_danger("\The [Z] runs into [src]!")
	var/attack_message2 = span_danger("We smash into [src]!")
	var/log = "slashed"

	//Somehow we will deal no damage on this attack
	if(!damage)
		playsound(Z.loc, 'sound/weapons/punchmiss.ogg', 25, 1)
		Z.do_attack_animation(src)
		Z.visible_message(span_danger("\The [Z] lunges at [src]!"), \
		span_danger("We lunge at [src]!"), null, 5)
		return FALSE

	Z.do_attack_animation(src, ATTACK_EFFECT_SMASH)

	//The normal attack proceeds
	playsound(loc, attack_sound, 25, 1)
	Z.visible_message("[attack_message1]", \
	"[attack_message2]")

	if(status_flags & XENO_HOST && stat != DEAD)
		log_combat(Z, src, log, addition = "while they were infected")
	else //Normal xenomorph friendship with benefits
		log_combat(Z, src, log)

	apply_damage(damage, BRUTE, affecting, armor_block, TRUE, TRUE, updating_health = TRUE) //This should slicey dicey

	return TRUE

/mob/living/silicon/attack_uv_harm(mob/living/carbon/xenomorph/zuv/Z, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)

	if(stat == DEAD) //A bit of visual flavor for attacking Cyborgs. Sparks!
		return FALSE
	. = ..()
	if(!.)
		return
	var/datum/effect_system/spark_spread/spark_system
	spark_system = new /datum/effect_system/spark_spread()
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)
	spark_system.start(src)
	playsound(loc, "alien_claw_metal", 25, TRUE)


/mob/living/carbon/xenomorph/attack_uv_harm(mob/living/carbon/xenomorph/zuv/Z, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)
	if(issamexenohive(Z))
		Z.visible_message(span_warning("\The [Z] nibbles [src]."),
		span_warning("We nibble [src]."), null, 5)
		return FALSE
	return ..()


/mob/living/carbon/human/attack_uv_harm(mob/living/carbon/xenomorph/zuv/Z, dam_bonus, set_location = FALSE, random_location = FALSE, no_head = FALSE, no_crit = FALSE, force_intent = null)

	if(stat == DEAD)
		if(istype(wear_ear, /obj/item/radio/headset/mainship))
			var/obj/item/radio/headset/mainship/cam_headset = wear_ear
			if(cam_headset.camera.status)
				cam_headset.camera.toggle_cam(null, FALSE)
				playsound(loc, "punch", 25, 1)
				Z.do_attack_animation(src, ATTACK_EFFECT_SMASH)
				to_chat(Z, span_warning("We disable the creatures hivemind sight apparatus."))
				return FALSE

		if(length(static_light_sources) || length(hybrid_light_sources) || length(affected_movable_lights))
			playsound(loc, "punch", 25, 1)
			Z.do_attack_animation(src, ATTACK_EFFECT_SMASH)
			disable_lights(sparks = TRUE)
			to_chat(Z, span_warning("We disable whatever annoying lights the dead creature possesses."))
		else
			to_chat(Z, span_warning("[src] is dead, why would we want to touch it?"))
		return FALSE

	SEND_SIGNAL(Z, COMSIG_XENOMORPH_ATTACK_HUMAN, src)

	. = ..()
	if(!.)
		return FALSE

/mob/living/attack_uv(mob/living/carbon/xenomorph/zuv/Z, damage_amount = Z.xeno_caste.melee_damage, damage_type = BRUTE, damage_flag = "", effects = TRUE, armor_penetration = 0, isrightclick = FALSE)
	if(Z.status_flags & INCORPOREAL)
		return FALSE

	if (Z.fortify)
		return FALSE

	switch(Z.a_intent)
		if(INTENT_HELP)
			if(on_fire)
				Z.visible_message(span_danger("[Z] stares at [src]."), span_notice("We stare at the roasting [src], toasty."), null, 5)
				return FALSE
			Z.visible_message(span_notice("\The [Z] nudges [src]."), \
			span_notice("We nudge [src]."), null, 5)
			return FALSE

		if(INTENT_GRAB)
			return attack_uv_grab(Z)

		if(INTENT_HARM, INTENT_DISARM)
			return attack_uv_harm(Z)
	return FALSE
