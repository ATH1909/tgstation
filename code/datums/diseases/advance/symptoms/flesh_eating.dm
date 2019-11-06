/*
//////////////////////////////////////

Autophagocytosis (AKA Programmed mass cell death)

	Very noticable.
	Lowers resistance.
	Fast stage speed.
	Decreases transmittablity.
	Fatal Level.

Bonus
	Deals brute damage over time.

//////////////////////////////////////
*/

/datum/symptom/flesh_death

	name = "Autophagocytosis Necrosis"
	desc = "The virus rapidly consumes infected cells, leading to heavy and widespread damage."
	stealth = -2
	resistance = -2
	stage_speed = 1
	transmittable = -2
	level = 7
	severity = 6
	base_message_chance = 50
	symptom_delay_min = 3
	symptom_delay_max = 6
	var/limbloss = FALSE
	threshold_desc = "<b>Stage Speed 7:</b> The virus can rot off the connection between a host's limb and their body, causing the limb to be severed.<br>\
					  <b>Stealth 5:</b> The symptom remains hidden until active."

/datum/symptom/flesh_death/Start(datum/disease/advance/A)
	if(!..())
		return
	if(A.properties["stealth"] >= 5)
		suppress_warning = TRUE
	if(A.properties["stage_rate"] >= 7) //has a chance per tick to rot off one of the host's limbs
		limbloss = TRUE

/datum/symptom/flesh_death/Activate(datum/disease/advance/A)
	if(!..())
		return
	var/mob/living/M = A.affected_mob
	switch(A.stage)
		if(2,3)
			if(prob(base_message_chance) && !suppress_warning)
				to_chat(M, "<span class='warning'>[pick("You feel your body break apart.", "Your skin rubs off like dust.")]</span>")
		if(4,5)
			if(prob(base_message_chance / 2)) //reduce spam
				to_chat(M, "<span class='userdanger'>[pick("You feel your muscles weakening.", "Some of your skin detaches itself.", "You feel sandy.")]</span>")
			Flesh_death(M, A)

/datum/symptom/flesh_death/proc/Flesh_death(mob/living/M, datum/disease/advance/A)
	var/get_damage = rand(6,10)
	M.take_overall_damage(brute = get_damage, required_status = BODYPART_ORGANIC)
	if((A.stage >= 5) && limbloss && iscarbon(M) && prob(10)) //should average out to about once every 90 seconds
		var/mob/living/carbon/C = M
		var/selected_part = pick(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG) //yes, sometimes this will try to pick a limb that's already gone and do nothing; this is intentional
		var/obj/item/bodypart/bp = C.get_bodypart(selected_part)
		if(bp && bp.status == BODYPART_ORGANIC)
			C.emote("scream")
			bp.receive_damage(200, 0, 0)
			bp.drop_limb()
			to_chat(C, "<span class='warning'>One of your limbs suddenly rots off!</span>")
