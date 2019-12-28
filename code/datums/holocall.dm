#define HOLOPAD_MAX_DIAL_TIME 200

#define HOLORECORD_DELAY	"delay"
#define HOLORECORD_SAY		"say"
#define HOLORECORD_SOUND	"sound"
#define HOLORECORD_LANGUAGE	"lang"
#define HOLORECORD_PRESET	"preset"
#define HOLORECORD_RENAME "rename"

#define HOLORECORD_MAX_LENGTH 200

/mob/camera/aiEye/remote/holo/setLoc()
	. = ..()
	var/obj/machinery/holopad/H = origin
	H?.move_hologram(eye_user, loc)

/obj/machinery/holopad/remove_eye_control(mob/living/user)
	if(user.client)
		user.reset_perspective(null)
	user.remote_control = null

//this datum manages it's own references

/datum/holocall
	var/mob/living/user	//the one that called
	var/obj/machinery/holopad/calling_holopad	//the one that sent the call
	var/obj/machinery/holopad/connected_holopad	//the one that answered the call (may be null)
	var/list/dialed_holopads	//all things called, will be cleared out to just connected_holopad once answered

	var/mob/camera/aiEye/remote/holo/eye	//user's eye, once connected
	var/obj/effect/overlay/holo_pad_hologram/hologram	//user's hologram, once connected
	var/datum/action/innate/end_holocall/hangup	//hangup action

	var/call_start_time
	var/head_call = FALSE //calls from a head of staff autoconnect, if the recieving pad is not secure.

//creates a holocall made by `caller` from `calling_pad` to `callees`
/datum/holocall/New(mob/living/caller, obj/machinery/holopad/calling_pad, list/callees, elevated_access = FALSE)
	call_start_time = world.time
	user = caller
	calling_pad.outgoing_call = src
	calling_holopad = calling_pad
	head_call = elevated_access
	dialed_holopads = list()

	for(var/I in callees)
		var/obj/machinery/holopad/H = I
		if(!QDELETED(H) && H.is_operational())
			dialed_holopads += H
			if(head_call)
				if(H.secure)
					calling_pad.say("Auto-connection refused, falling back to call mode.")
					H.say("Incoming call.")
				else
					H.say("Incoming connection.")
			else
				H.say("Incoming call.")
			LAZYADD(H.holo_calls, src)

	if(!dialed_holopads.len)
		calling_pad.say("Connection failure.")
		qdel(src)
		return

	testing("Holocall started")

//cleans up ALL references :)
/datum/holocall/Destroy()
	QDEL_NULL(hangup)

	if(!QDELETED(eye))
		QDEL_NULL(eye)

	if(connected_holopad && !QDELETED(hologram))
		hologram = null
		connected_holopad.clear_holo(user)

	user = null

	//Hologram survived holopad destro
	if(!QDELETED(hologram))
		hologram.HC = null
		QDEL_NULL(hologram)

	for(var/I in dialed_holopads)
		var/obj/machinery/holopad/H = I
		LAZYREMOVE(H.holo_calls, src)
	dialed_holopads.Cut()

	if(calling_holopad)
		calling_holopad.outgoing_call = null
		calling_holopad.SetLightsAndPower()
		calling_holopad = null
	if(connected_holopad)
		connected_holopad.SetLightsAndPower()
		connected_holopad = null

	testing("Holocall destroyed")

	return ..()

//Gracefully disconnects a holopad `H` from a call. Pads not in the call are ignored. Notifies participants of the disconnection
/datum/holocall/proc/Disconnect(obj/machinery/holopad/H)
	testing("Holocall disconnect")
	if(H == connected_holopad)
		var/area/A = get_area(connected_holopad)
		calling_holopad.say("[A] holopad disconnected.")
	else if(H == calling_holopad && connected_holopad)
		connected_holopad.say("[user] disconnected.")

	ConnectionFailure(H, TRUE)

//Forcefully disconnects a holopad `H` from a call. Pads not in the call are ignored.
/datum/holocall/proc/ConnectionFailure(obj/machinery/holopad/H, graceful = FALSE)
	testing("Holocall connection failure: graceful [graceful]")
	if(H == connected_holopad || H == calling_holopad)
		if(!graceful && H != calling_holopad)
			calling_holopad.say("Connection failure.")
		qdel(src)
		return

	LAZYREMOVE(H.holo_calls, src)
	dialed_holopads -= H
	if(!dialed_holopads.len)
		if(graceful)
			calling_holopad.say("Call rejected.")
		testing("No recipients, terminating")
		qdel(src)

//Answers a call made to a holopad `H` which cannot be the calling holopad. Pads not in the call are ignored
/datum/holocall/proc/Answer(obj/machinery/holopad/H)
	testing("Holocall answer")
	if(H == calling_holopad)
		CRASH("How cute, a holopad tried to answer itself.")

	if(!(H in dialed_holopads))
		return

	if(connected_holopad)
		CRASH("Multi-connection holocall")

	for(var/I in dialed_holopads)
		if(I == H)
			continue
		Disconnect(I)

	for(var/I in H.holo_calls)
		var/datum/holocall/HC = I
		if(HC != src)
			HC.Disconnect(H)

	connected_holopad = H

	if(!Check())
		return

	hologram = H.activate_holo(user)
	hologram.HC = src

	//eyeobj code is horrid, this is the best copypasta I could make
	eye = new
	eye.origin = H
	eye.eye_initialized = TRUE
	eye.eye_user = user
	eye.name = "Camera Eye ([user.name])"
	user.remote_control = eye
	user.reset_perspective(eye)
	eye.setLoc(H.loc)

	hangup = new(eye, src)
	hangup.Grant(user)
	playsound(H, 'sound/machines/ping.ogg', 100)
	H.say("Connection established.")

//Checks the validity of a holocall and qdels itself if it's not. Returns TRUE if valid, FALSE otherwise
/datum/holocall/proc/Check()
	for(var/I in dialed_holopads)
		var/obj/machinery/holopad/H = I
		if(!H.is_operational())
			ConnectionFailure(H)

	if(QDELETED(src))
		return FALSE

	. = !QDELETED(user) && !user.incapacitated() && !QDELETED(calling_holopad) && calling_holopad.is_operational() && user.loc == calling_holopad.loc

	if(.)
		if(!connected_holopad)
			. = world.time < (call_start_time + HOLOPAD_MAX_DIAL_TIME)
			if(!.)
				calling_holopad.say("No answer received.")
				calling_holopad.temp = ""

	if(!.)
		testing("Holocall Check fail")
		qdel(src)

/datum/action/innate/end_holocall
	name = "End Holocall"
	icon_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "camera_off"
	var/datum/holocall/hcall

/datum/action/innate/end_holocall/New(Target, datum/holocall/HC)
	..()
	hcall = HC

/datum/action/innate/end_holocall/Activate()
	hcall.Disconnect(hcall.calling_holopad)


//RECORDS
/datum/holorecord
	var/caller_name = "Unknown" //Caller name
	var/image/caller_image
	var/list/entries = list()
	var/language = /datum/language/common //Initial language, can be changed by HOLORECORD_LANGUAGE entries

/datum/holorecord/proc/set_caller_image(mob/user)
	var/olddir = user.dir
	user.setDir(SOUTH)
	caller_image = image(user)
	user.setDir(olddir)

/obj/item/disk/holodisk
	name = "holorecord disk"
	desc = "Stores recorder holocalls."
	icon_state = "holodisk"
	obj_flags = UNIQUE_RENAME
	custom_materials = list(/datum/material/iron = 100, /datum/material/glass = 100)
	var/datum/holorecord/record
	//Preset variables
	var/preset_image_type
	var/preset_record_text

/obj/item/disk/holodisk/Initialize(mapload)
	. = ..()
	if(preset_record_text)
		build_record()

/obj/item/disk/holodisk/Destroy()
	QDEL_NULL(record)
	return ..()

/obj/item/disk/holodisk/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/disk/holodisk))
		var/obj/item/disk/holodisk/holodiskOriginal = W
		if (holodiskOriginal.record)
			if (!record)
				record = new
			record.caller_name = holodiskOriginal.record.caller_name
			record.caller_image = holodiskOriginal.record.caller_image
			record.entries = holodiskOriginal.record.entries.Copy()
			record.language = holodiskOriginal.record.language
			to_chat(user, "<span class='notice'>You copy the record from [holodiskOriginal] to [src] by connecting the ports!</span>")
			name = holodiskOriginal.name
		else
			to_chat(user, "<span class='warning'>[holodiskOriginal] has no record on it!</span>")
	..()

/obj/item/disk/holodisk/proc/build_record()
	record = new
	var/list/lines = splittext(preset_record_text,"\n")
	for(var/line in lines)
		var/prepared_line = trim(line)
		if(!length(prepared_line))
			continue
		var/splitpoint = findtext(prepared_line," ")
		if(!splitpoint)
			continue
		var/command = copytext(prepared_line,1,splitpoint)
		var/value = copytext(prepared_line,splitpoint+1)
		switch(command)
			if("DELAY")
				var/delay_value = text2num(value)
				if(!delay_value)
					continue
				record.entries += list(list(HOLORECORD_DELAY,delay_value))
			if("NAME")
				if(!record.caller_name)
					record.caller_name = value
				else
					record.entries += list(list(HOLORECORD_RENAME,value))
			if("SAY")
				record.entries += list(list(HOLORECORD_SAY,value))
			if("SOUND")
				record.entries += list(list(HOLORECORD_SOUND,value))
			if("LANGUAGE")
				var/lang_type = text2path(value)
				if(ispath(lang_type,/datum/language))
					record.entries += list(list(HOLORECORD_LANGUAGE,lang_type))
			if("PRESET")
				var/preset_type = text2path(value)
				if(ispath(preset_type,/datum/preset_holoimage))
					record.entries += list(list(HOLORECORD_PRESET,preset_type))
	if(!preset_image_type)
		record.caller_image = image('icons/mob/animal.dmi',"old")
	else
		var/datum/preset_holoimage/H = new preset_image_type
		record.caller_image = H.build_image()

//These build caller image from outfit and some additional data, for use by mappers for ruin holorecords
/datum/preset_holoimage
	var/nonhuman_mobtype //Fill this if you just want something nonhuman
	var/outfit_type
	var/species_type = /datum/species/human

/datum/preset_holoimage/proc/build_image()
	if(nonhuman_mobtype)
		var/mob/living/L = nonhuman_mobtype
		. = image(initial(L.icon),initial(L.icon_state))
	else
		var/mob/living/carbon/human/dummy/mannequin = generate_or_wait_for_human_dummy("HOLODISK_PRESET")
		if(species_type)
			mannequin.set_species(species_type)
		if(outfit_type)
			mannequin.equipOutfit(outfit_type,TRUE)
		mannequin.setDir(SOUTH)
		COMPILE_OVERLAYS(mannequin)
		. = image(mannequin)
		unset_busy_human_dummy("HOLODISK_PRESET")

/obj/item/disk/holodisk/example
	preset_image_type = /datum/preset_holoimage/clown
	preset_record_text = {"
	NAME Clown
	DELAY 10
	SAY Why did the chaplain cross the maint ?
	DELAY 20
	SAY He wanted to get to the other side!
	SOUND clownstep
	DELAY 30
	LANGUAGE /datum/language/narsie
	SAY Helped him get there!
	DELAY 10
	SAY ALSO IM SECRETLY A GORILLA
	DELAY 10
	PRESET /datum/preset_holoimage/gorilla
	NAME Gorilla
	LANGUAGE /datum/language/common
	SAY OOGA
	DELAY 20"}

/datum/preset_holoimage/engineer
	outfit_type = /datum/outfit/job/engineer

/datum/preset_holoimage/engineer/rig
	outfit_type = /datum/outfit/job/engineer/gloved/rig

/datum/preset_holoimage/engineer/ce
	outfit_type = /datum/outfit/job/ce

/datum/preset_holoimage/engineer/ce/rig
	outfit_type = /datum/outfit/job/engineer/gloved/rig

/datum/preset_holoimage/engineer/atmos
	outfit_type = /datum/outfit/job/atmos

/datum/preset_holoimage/engineer/atmos/rig
	outfit_type = /datum/outfit/job/engineer/gloved/rig

/datum/preset_holoimage/researcher
	outfit_type = /datum/outfit/job/scientist

/datum/preset_holoimage/captain
	outfit_type = /datum/outfit/job/captain

/datum/preset_holoimage/nanotrasenprivatesecurity
	outfit_type = /datum/outfit/nanotrasensoldiercorpse2

/datum/preset_holoimage/gorilla
	nonhuman_mobtype = /mob/living/simple_animal/hostile/gorilla

/datum/preset_holoimage/corgi
	nonhuman_mobtype = /mob/living/simple_animal/pet/dog/corgi

/datum/preset_holoimage/clown
	outfit_type = /datum/outfit/job/clown

/obj/item/disk/holodisk/donutstation/whiteship
	name = "Blackbox Print-out #DS024"
	desc = "A holodisk containing the last viable recording of DS024's blackbox."
	preset_image_type = /datum/preset_holoimage/engineer/ce
	preset_record_text = {"
	NAME Geysr Shorthalt
	SAY Engine renovations complete and the ships been loaded. We all ready?
	DELAY 25
	PRESET /datum/preset_holoimage/engineer
	NAME Jacob Ullman
	SAY Lets blow this popsicle stand of a station.
	DELAY 20
	PRESET /datum/preset_holoimage/engineer/atmos
	NAME Lindsey Cuffler
	SAY Uh, sir? Shouldn't we call for a secondary shuttle? The bluespace drive on this thing made an awfully weird noise when we jumped here..
	DELAY 30
	PRESET /datum/preset_holoimage/engineer/ce
	NAME Geysr Shorthalt
	SAY Pah! Ship techie at the dock said to give it a good few kicks if it started acting up, let me just..
	DELAY 25
	SOUND punch
	SOUND sparks
	DELAY 10
	SOUND punch
	SOUND sparks
	DELAY 10
	SOUND punch
	SOUND sparks
	SOUND warpspeed
	DELAY 15
	PRESET /datum/preset_holoimage/engineer/atmos
	NAME Lindsey Cuffler
	SAY Uhh.. is it supposed to be doing that??
	DELAY 15
	PRESET /datum/preset_holoimage/engineer/ce
	NAME Geysr Shorthalt
	SAY See? Working as intended. Now, are we all ready?
	DELAY 10
	PRESET /datum/preset_holoimage/engineer
	NAME Jacob Ullman
	SAY Is it supposed to be glowing like that?
	DELAY 20
	SOUND explosion

	"}

/datum/outfit/bee_terrorist/hooded
	name = "Bee Costume"
	head = /obj/item/clothing/head/hooded/bee_hood

/datum/outfit/bee_terrorist/hooded/sweater
	r_hand = /obj/item/clothing/suit/hooded/bee_costume

/datum/outfit/fancysuit
	name = "Fancy Suit"
	uniform = /obj/item/clothing/under/suit/black
	shoes = /obj/item/clothing/shoes/sneakers/black
	ears = /obj/item/radio/headset
	gloves = /obj/item/clothing/gloves/color/white

/datum/preset_holoimage/beecostume
	outfit_type = /datum/outfit/bee_terrorist/hooded

/datum/preset_holoimage/beecostume/moth
	species_type = /datum/species/moth

/datum/preset_holoimage/beecostume/moth/sweater
	outfit_type = /datum/outfit/bee_terrorist/hooded/sweater

/datum/preset_holoimage/beecostume/lizard
	species_type = /datum/species/lizard

/datum/preset_holoimage/beecostume/vampire
	species_type = /datum/species/vampire

/datum/preset_holoimage/suit
	outfit_type = /datum/outfit/fancysuit

/obj/item/disk/holodisk/ATHATH
	name="The Tape"
	desc="Play me!"
	preset_image_type=/datum/preset_holoimage/suit
	preset_record_text={"
	NAME Bob Bobson
	SAY Greetings from the Phantom Zone, everyone!
	DELAY 30
	SAY I'm Research Director Bob Bobson, not to be confused with Captain Bob Bobson or Head of Personnel Bob Bobson.
	DELAY 50
	SAY Unfortunately, the other Bobs couldn't be here with me today, but I have a feeling that things would just get very confusing with them around.
	DELAY 50
	SAY So, how's the Winter Ball going?
	DELAY 80
	SAY Yeah, I thought so.
	DELAY 20
	SAY I was looking forward to attending this Winter Ball and performing in this talent show in person, but, ah, the gods kind of banished me from existence for a month.
	DELAY 50
	SAY So... yeah.
	DELAY 20
	SAY Fortunately, I'm still able to co- er, modify the fabric of reality from in here, which is why you have this disk- it's my submission for this talent show!
	DELAY 50
	SAY More specifically, it's a reading of the first 3 minutes of the Bee Movie script... after I ran it through Space Google Translate 10 times!
	DELAY 50
	SAY This was originally gonna be a solo act, but since a bunch of my friends got banished to the Phantom Zone along with me, I've incorporated them into this too.
	DELAY 50
	SAY By the way, we're fine with whatever heckling you audience members want to do; it's not like we can hear you and have our feelings hurt mid-performance or anything.
	DELAY 50
	SAY And with that introduction over, the rest of the ATHATH group and I present to you: The First 3 Minutes of the Bee Movie, Space Google Translate Edition!
	DELAY 30
	NAME Bob Bobson (as Narrator)
	DELAY 30
	SAY In accordance with all recognized laws
	DELAY 20
	SAY aviation
	DELAY 20
	SAY There's no way
	DELAY 10
	SAY I have to be able to fly.
	DELAY 20
	SAY Your wings are too small
	DELAY 15
	SAY Some grease from the floor.
	DELAY 20
	SAY Of course, the bee is still flying.
	DELAY 20
	SAY because bees don't care
	DELAY 15
	SAY What people think is impossible.
	DELAY 20
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	DELAY 10
	SAY Gold, black, yellow, black
	DELAY 15
	SAY Gold, black, yellow, black
	DELAY 15
	PRESET /datum/preset_holoimage/beecostume/moth/sweater
	DELAY 10
	SAY Oh black and gold!
	DELAY 10
	SAY Shake gently.
	DELAY 15
	NAME Llabeht Stih (as Janet Benson)
	PRESET /datum/preset_holoimage/beecostume
	SAY Berries! Breakfast is ready!
	DELAY 15
	NAME DIO (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/vampire
	SAY The world!
	SOUND 'sound/magic/timeparadox2.ogg'
	DELAY 30
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Wait a moment.
	DELAY 15
	SAY Hello
	DELAY 10
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY Barry?
	DELAY 10
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Adam?
	DELAY 10
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY What do you think will happen?
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY I can't choose you.
	DELAY 10
	SOUND 'sound/weapons/gun/revolver/dry_fire.ogg'
	DELAY 20
	SOUND 'sound/machines/blender.ogg'
	DELAY 40
	SOUND 'sound/machines/microwave/microwave-end.ogg'
	DELAY 10
	SAY Are you OK.
	DELAY 15
	NAME Llabeht Stih (as Janet Benson)
	PRESET /datum/preset_holoimage/beecostume
	SAY Use the stairs. Your father
	DELAY 15
	SAY He paid them a lot of money.
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY I'm sorry, I'm happy.
	DELAY 15
	NAME Uzuzap I (as Martin Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY This is a graduate.
	DELAY 15
	SAY We are so proud of you, my son.
	DELAY 15
	SAY Perfect protocol, all b.
	DELAY 15
	NAME Llabeht Stih (as Janet Benson)
	PRESET /datum/preset_holoimage/beecostume
	SAY Very proud
	DELAY 10
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Mine! I have something to do here.
	DELAY 15
	NAME Uzuzap I (as Martin Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY You jumped on the wick
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY I! You have a choice!
	DELAY 15
	NAME Uzuzap I (as Martin Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Hello! Let it be around 118,000.
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Yes!
	DELAY 15
	NAME Llabeht Stih (as Janet Benson)
	PRESET /datum/preset_holoimage/beecostume
	SAY Barry, I told you
	DELAY 10
	SAY Stop flying home!
	DELAY 30
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SOUND 'sound/vehicles/carrev.ogg'
	DELAY 20
	SOUND 'sound/vehicles/clowncar_load1.ogg'
	DELAY 20
	SAY Hi Adam.
	DELAY 10
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY Hi Barry.
	DELAY 10
	SAY Fossil fusion?
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY a little. A special day, gradually.
	DELAY 20
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY I never thought of doing it.
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY The third year
	DELAY 10
	SAY Greenhouse three days.
	DELAY 15
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY I am uncomfortable.
	DELAY 20
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Three days at university. I'm glad I got it
	DELAY 15
	SAY Once wrapped in a basket.
	DELAY 15
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY You came back different.
	DELAY 20
	NAME Elmagio Tonama (as Artie)
	PRESET /datum/preset_holoimage/beecostume
	SAY Hi Barry.
	DELAY 10
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Artie ban, mustache grow? Looks good
	DELAY 20
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY Did you hear Frankie?
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Yes, yes
	DELAY 10
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY Are you going to a funeral?
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY No, I won't go.
	DELAY 10
	SAY Everybody knows
	DELAY 10
	SAY Bite a man, die.
	DELAY 10
	SAY Don't miss the squirrel.
	DELAY 10
	SAY What a Girl
	DELAY 10
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY I think so
	DELAY 20
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY I just left
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY I just left
	DELAY 20
	SAY I like this addition
	DELAY 15
	SAY Play in the park today.
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY That's why we don't want a vacation.
	DELAY 20
	SOUND 'sound/vehicles/clowncar_ram1.ogg'
	DELAY 30
	SAY Strong guy ...
	DELAY 10
	SAY in circumstances
	DELAY 15
	SAY Well, Adam, today we are men.
	DELAY 15
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY We are!
	DELAY 15
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY bees.
	DELAY 15
	NAME Hits-The-Ball (as Adam Flayman)
	PRESET /datum/preset_holoimage/beecostume/lizard
	SAY Amen!
	DELAY 10
	NAME Jack Jackson (as Barry B. Benson)
	PRESET /datum/preset_holoimage/beecostume/moth
	SAY Alleluia!
	DELAY 40
	NAME Bob Bobson
	PRESET /datum/preset_holoimage/suit
	SAY And... Scene!
	DELAY 20
	SAY My thanks go to all of you for letting us perform here for you today, and have a fantastic Winter Ball!
	DELAY 40
	SAY ... Hold on, the off button for this thing is somewhere...
	DELAY 30
	SAY Aha! Found i-
	DELAY 10
	"}