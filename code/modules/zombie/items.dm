/obj/item/zombie_hand
	name = "zombie claw"
	desc = "A zombie's claw is its primary tool, capable of infecting \
		humans, butchering all other living things to \
		sustain the zombie, smashing open airlock doors and opening \
		child-safe caps on bottles."
	item_flags = ABSTRACT | DROPDEL
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	icon = 'icons/effects/blood.dmi'
	icon_state = "bloodhand_left"
	var/icon_left = "bloodhand_left"
	var/icon_right = "bloodhand_right"
	hitsound = 'sound/hallucinations/growl1.ogg'
	force = 21 // Just enough to break airlocks with melee attacks
	sharpness = SHARP_EDGED
	wound_bonus = -10 //this needs to be high enough to allow zombies to behead the corpses of their victims (without needing to whack at their corpse for like 2 minutes straight) so that they can eat their brains
	bare_wound_bonus = 15
	damtype = BRUTE

/obj/item/zombie_hand/Initialize()
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, HAND_REPLACEMENT_TRAIT)

/obj/item/zombie_hand/equipped(mob/user, slot)
	. = ..()
	//these are intentionally inverted
	var/i = user.get_held_index_of_item(src)
	if(!(i % 2))
		icon_state = icon_left
	else
		icon_state = icon_right

/obj/item/zombie_hand/afterattack(atom/target, mob/user, proximity_flag)
	. = ..()
	if(!proximity_flag)
		return
	else if(isliving(target))
		if(ishuman(target))
			try_to_zombie_infect(target)
		else
			check_feast(target, user)
	else if(istype(target, /obj/item/organ/brain) || istype (target, /obj/item/food/burger/brain))
		check_feast_brain(target, user)

/proc/try_to_zombie_infect(mob/living/carbon/human/target)
	CHECK_DNA_AND_SPECIES(target)

	if(NOZOMBIE in target.dna.species.species_traits)
		// cannot infect any NOZOMBIE subspecies (such as high functioning
		// zombies)
		return

	var/obj/item/organ/zombie_infection/infection
	infection = target.getorganslot(ORGAN_SLOT_ZOMBIE)
	if(!infection)
		infection = new()
		infection.Insert(target)



/obj/item/zombie_hand/suicide_act(mob/user)
	user.visible_message("<span class='suicide'>[user] is ripping [user.p_their()] brains out! It looks like [user.p_theyre()] trying to commit suicide!</span>")
	if(isliving(user))
		var/mob/living/L = user
		var/obj/item/bodypart/O = L.get_bodypart(BODY_ZONE_HEAD)
		if(O)
			O.dismember()
	return (BRUTELOSS)

/obj/item/zombie_hand/proc/check_feast(mob/living/target, mob/living/user)
	if(target.stat == DEAD)
		var/hp_gained = target.maxHealth
		target.gib()
		// zero as argument for no instant health update
		user.adjustBruteLoss(-hp_gained, 0)
		user.adjustToxLoss(-hp_gained, 0)
		user.adjustFireLoss(-hp_gained, 0)
		user.adjustCloneLoss(-hp_gained, 0)
		user.updatehealth()
		user.adjustOrganLoss(ORGAN_SLOT_BRAIN, -hp_gained) // Zom Bee gibbers "BRAAAAISNSs!1!"
		user.set_nutrition(min(user.nutrition + hp_gained, NUTRITION_LEVEL_FULL))

/obj/item/zombie_hand/proc/check_feast(mob/living/target, mob/living/user)
	qdel(target) //om nom nom
	// zero as argument for no instant health update
	user.adjustBruteLoss(-100, 0) //humans and monkeys (the two most common sources of brains) technically both have 200 health, but they're basically done for once they go into crit (and brains are more convenient to drag around than corpses), so we'll use 100 as the effective hp_gained value here
	user.adjustToxLoss(-100, 0)
	user.adjustFireLoss(-100, 0)
	user.adjustCloneLoss(-100, 0)
	user.updatehealth()
	user.adjustOrganLoss(ORGAN_SLOT_BRAIN, -100) //you are what you eat
	user.set_nutrition(min(user.nutrition + 200, NUTRITION_LEVEL_FULL)) //double the amount of nutrition that it "should" give because brains are, like, THE zombie food
