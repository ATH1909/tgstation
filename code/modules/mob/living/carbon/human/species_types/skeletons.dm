/datum/species/skeleton
	// 2spooky
	name = "Spooky Scary Skeleton"
	id = "skeleton"
	say_mod = "rattles"
	sexes = 0
	meat = /obj/item/reagent_containers/food/snacks/meat/slab/human/mutant/skeleton
	species_traits = list(NOBLOOD)
	inherent_traits = list(TRAIT_NOMETABOLISM,TRAIT_TOXIMMUNE,TRAIT_RESISTHEAT,TRAIT_NOBREATH,TRAIT_RESISTCOLD,TRAIT_RESISTHIGHPRESSURE,TRAIT_RESISTLOWPRESSURE,TRAIT_RADIMMUNE,\
	TRAIT_PIERCEIMMUNE,TRAIT_NOHUNGER,TRAIT_EASYDISMEMBER,TRAIT_LIMBATTACHMENT,TRAIT_FAKEDEATH)
	inherent_biotypes = MOB_UNDEAD|MOB_HUMANOID
	mutanttongue = /obj/item/organ/tongue/bone
	damage_overlay_type = ""//let's not show bloody wounds or burns over bones.
	disliked_food = NONE
	liked_food = GROSS | MEAT | RAW
	//They can technically be in an ERT
	changesource_flags = MIRROR_BADMIN | WABBAJACK | ERT_SPAWN

/datum/species/skeleton/check_roundstart_eligible()
	if(SSevents.holidays && SSevents.holidays[HALLOWEEN])
		return TRUE
	return ..()

//Can still metabolize milk through meme magic
/datum/species/skeleton/handle_chemicals(datum/reagent/chem, mob/living/carbon/human/H)
	. = ..()
	if(chem.type == /datum/reagent/consumable/milk)
		if(chem.volume >= 6)
			H.reagents.remove_reagent(chem.type, chem.volume - 5)
			to_chat(H, "<span class='warning'>The excess milk is dripping off your bones!</span>")
		H.heal_bodypart_damage(1,1, 0)
		H.reagents.remove_reagent(chem.type, chem.metabolization_rate)
		return TRUE
	if(chem.type == /datum/reagent/toxin/bonehurtingjuice)
		H.adjustStaminaLoss(7.5, 0)
		H.adjustBruteLoss(0.5, 0)
		if(prob(20))
			switch(rand(1, 3))
				if(1)
					var/list/possible_says = list("oof.", "ouch!", "my bones.", "oof ouch.", "oof ouch my bones.")
					H.say(pick(possible_says), forced = /datum/reagent/toxin/bonehurtingjuice)
				if(2)
					var/list/possible_mes = list("oofs softly.", "looks like their bones hurt.", "grimaces, as though their bones hurt.")
					H.say("*custom " + pick(possible_mes), forced = /datum/reagent/toxin/bonehurtingjuice)
				if(3)
					to_chat(H, "<span class='warning'>Your bones hurt!</span>")
		if(chem.overdosed)
			if(prob(4) && iscarbon(H)) //big oof
				var/selected_part
				switch(rand(1, 4)) //God help you if the same limb gets picked twice quickly.
					if(1)
						selected_part = BODY_ZONE_L_ARM
					if(2)
						selected_part = BODY_ZONE_R_ARM
					if(3)
						selected_part = BODY_ZONE_L_LEG
					if(4)
						selected_part = BODY_ZONE_R_LEG
				var/obj/item/bodypart/bp = H.get_bodypart(selected_part) //We're so sorry skeletons, you're so misunderstood
				if(bp)
					playsound(H, get_sfx("desceration"), 50, TRUE, -1) //You just want to socialize
					H.visible_message("<span class='warning'>[H] rattles loudly and flails around!!</span>", "<span class='danger'>Your bones hurt so much that your missing muscles spasm!!</span>")
					H.say("OOF!!", forced=/datum/reagent/toxin/bonehurtingjuice)
					bp.receive_damage(200, 0, 0) //But I don't think we should
				else
					to_chat(H, "<span class='warning'>Your missing arm aches from wherever you left it.</span>")
					H.emote("sigh")
		H.reagents.remove_reagent(chem.type, chem.metabolization_rate)
		return TRUE
