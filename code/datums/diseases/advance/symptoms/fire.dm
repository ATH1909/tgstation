/*
//////////////////////////////////////

Alkali perspiration

	Hidden.
	Lowers resistance.
	Decreases stage speed.
	Decreases transmittablity.
	Fatal Level.

Bonus
	Ignites infected mob.
	Explodes mob on contact with water.

//////////////////////////////////////
*/

/datum/symptom/alkali

	name = "Alkali perspiration"
	desc = "The virus attaches to sudoriparous glands, synthesizing a chemical that bursts into flames when reacting with water, leading to self-immolation."
	stealth = 2
	resistance = -2
	stage_speed = -2
	transmittable = -2
	level = 7
	severity = 6
	base_message_chance = 100
	symptom_delay_min = 30
	symptom_delay_max = 90
	var/direct_damage = FALSE
	var/explosion_power = 1
	threshold_desc = "<b>Resistance 9:</b> Doubles the intensity of the immolation effect, but reduces the frequency of all of this symptom's effects.<br>\
					  <b>Stage Speed 8:</b> Increases explosion radius and explosion damage to the host when the host is wet.<br>\
					  <b>Transmission 8:</b> The virus deals direct damage to the host when it ignites them. The damage dealt is based on how flammable the host is."

/datum/symptom/alkali/Start(datum/disease/advance/A)
	if(!..())
		return
	if(A.properties["resistance"] >= 9) //intense but sporadic effect
		power = 2
		symptom_delay_min = 50
		symptom_delay_max = 140
	if(A.properties["stage_rate"] >= 8) //serious boom when wet
		explosion_power = 2
	if(A.properties["transmittable"] >= 8) //does direct burn damage as well, so that people who are wearing atmos hardsuits and such aren't safe
		direct_damage = TRUE

/datum/symptom/alkali/Activate(datum/disease/advance/A)
	if(!..())
		return
	var/mob/living/M = A.affected_mob
	switch(A.stage)
		if(3)
			if(prob(base_message_chance))
				to_chat(M, "<span class='warning'>[pick("Your veins boil.", "You feel hot.", "You smell meat cooking.")]</span>")
		if(4)
			if(M.fire_stacks < 0)
				M.visible_message("<span class='warning'>[M]'s sweat sizzles and pops on contact with water!</span>")
				explosion(get_turf(M),-1,(-1 + explosion_power),(2 * explosion_power))
			Alkali_fire_stage_4(M, A)
			M.IgniteMob()
			to_chat(M, "<span class='userdanger'>Your sweat bursts into flames!</span>")
			M.emote("scream")
		if(5)
			if(M.fire_stacks < 0)
				M.visible_message("<span class='warning'>[M]'s sweat sizzles and pops on contact with water!</span>")
				explosion(get_turf(M),-1,(-1 + explosion_power),(2 * explosion_power))
			Alkali_fire_stage_5(M, A)
			M.IgniteMob()
			to_chat(M, "<span class='userdanger'>Your skin erupts into an inferno!</span>")
			M.emote("scream")

/datum/symptom/alkali/proc/Alkali_fire_stage_4(mob/living/M, datum/disease/advance/A)
	var/get_stacks = 6 * power
	M.adjust_fire_stacks(get_stacks)
	if(direct_damage)
		M.take_overall_damage(burn = get_stacks, required_status = BODYPART_ORGANIC)
	return 1

/datum/symptom/alkali/proc/Alkali_fire_stage_5(mob/living/M, datum/disease/advance/A)
	var/get_stacks = 8 * power
	M.adjust_fire_stacks(get_stacks)
	if(direct_damage)
		M.take_overall_damage(burn = get_stacks, required_status = BODYPART_ORGANIC)
	return 1
