//Pokemon!

//defines moved to arfs_defines.dm

/mob/living/simple_mob/animal/passive/pokemon
	name = "eevee"
	icon_state = "eevee"
	icon_living = "eevee"
	icon_dead = "eevee_d"
	icon_rest = ""
	desc = "Gotta catch 'em all!"
	icon = 'content_arfs/icons/mob/mobs/pokemon.dmi'
	pixel_x = -16
	default_pixel_x = -16
	old_x = -16
	health = 100
	maxHealth = 100
	max_co2 = 10 //Lets them go outside without dying of co2
	attacktext = list("attacked") //List of verbs used when attacking something. X has attacked Y.
	has_hands = TRUE	 		//Makes gameplay more enjoyable, even if it doesn't make sense for a lot of them.
	humanoid_hands = FALSE 	//Also set this to true if they should be allowed to use guns and other humanoid-only stuff. Don't turn this on.
	response_help = "pets"
	layer = MOB_LAYER
	vore_active = TRUE
	movement_cooldown = 2
	meat_amount = 3
	makes_dirt = FALSE
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	melee_damage_lower = 3
	melee_damage_upper = 9
	universal_understand = TRUE 	//Until we can fix the inability to tell who is talking over radios and similar bugs, this will work
	var/image/heal_layer			//Used for resting and some abilities.
	var/move_cooldown_time = 100 	//Global cooldown used for some moves to avoid spam/lag.
	var/move_cooldown = FALSE
	var/list/p_types = list()
	var/list/additional_moves = list()
	var/list/p_traits = list() //List of passive traits/flags.
	var/resting_heal_max = 2
	var/on_manifest = FALSE
	var/list/active_moves = list() 	//Moves that are passive or toggles can be found here
	var/obj/item/device/communicator/simple_mob/communicator //This is created when using a pokemon teleporter or adminbuse
	var/y_offset_mult = 16 // y_offset_mult(size_mult - 1) is the amount we need to offset the mob when resizing with a size gun. Bigger icon file needs a bigger number

/mob/living/simple_mob/animal/passive/pokemon/Initialize()
	. = ..()
	verbs |= /mob/living/simple_mob/animal/passive/pokemon/proc/move_rest
	verbs |= /mob/living/proc/set_flavor_text
	verbs |= /mob/living/proc/set_ooc_notes
	heal_layer = image("icon" = 'content_arfs/icons/mob/mobs/pokemon_effects.dmi', "icon_state" = "green_sparkles")
	heal_layer.appearance_flags = RESET_COLOR
	icon_rest = "[icon_state]_rest"
	if(!tt_desc)
		tt_desc = "[capitalize(initial(icon_state))]"//icon_state will be the species if tt_desc isn't set
	voice_name = name
	init_vore()
	add_language(LANGUAGE_GALCOM)
	add_language(LANGUAGE_POKEMON)
	set_default_language(GLOB.all_languages[LANGUAGE_GALCOM])
	give_moves()//Give innate moves/verbs from the additional_moves var
	if(p_types.len)//Give type specific verbs and such
		for(var/T in p_types)
			give_moves(T)
	if(p_traits.len)
		for(var/TR in p_traits)
			give_trait(TR)

/mob/living/simple_mob/animal/passive/pokemon/Life()
	..()
	cut_overlay(heal_layer)
	rest_regeneration()//Do healing
	nutrition = 3000 //Eating is hard. Remove if there's ever an easy source of food that isn't mice
	updatehealth()//Update health overlay
	if(sleeping)
		sleeping--
		if(sleeping <= 0)
			sleeping = 0
	update_canmove()
	return TRUE

/mob/living/simple_mob/animal/passive/pokemon/death(gibbed,deathmessage="seizes up and falls limp...")
	//Clean up active moves
	if(M_GHOSTED in active_moves)
		active_moves -= M_GHOSTED
		mouse_opacity = 1
		name = real_name
		for(var/belly in vore_organs)
			var/obj/belly/B = belly
			B.escapable = initial(B.escapable)
		invisibility = initial(invisibility)
		see_invisible = initial(see_invisible)
		incorporeal_move = initial(incorporeal_move)
		density = initial(density)
		force_max_speed = initial(force_max_speed)
		update_icon()
		alpha = 0
		canmove = initial(canmove)
		alpha = initial(alpha)

	if(M_INVIS in active_moves)
		active_moves -= M_INVIS
		mouse_opacity = 1
		name = real_name
		//overlays.Cut()
		invisibility = initial(invisibility)
		see_invisible = initial(see_invisible)
		incorporeal_move = initial(incorporeal_move)
		update_icon()
		alpha = 0
		alpha = initial(alpha)
	if (M_SHOCK in active_moves)
		active_moves -= M_SHOCK
	. = ..()

/mob/living/simple_mob/animal/passive/pokemon/Topic(href, href_list)
	if(href_list["ooc_notes"])
		src.Examine_OOC()
		return 1
	return ..()

/mob/living/simple_mob/animal/passive/pokemon/examine(mob/user)
	if(alpha <= EFFECTIVE_INVIS)
		return src.loc.examine(user) // Returns messages as if they examined wherever the mob was
	var/datum/gender/T = gender_datums[get_visible_gender()]
	var/list/msg = list("<span class='info'>*---------*","This is [bicon(src)] <EM>[src.name]</EM>, a <span class ='red'>Pokemon</span></span>")
	if(flavor_text)
		msg += "[print_flavor_text()]"
	else
		msg += "[desc]" //If it's just a regular mob, print its usual description instead
	if(ooc_notes)
		msg += "<span class = 'deptradio'>OOC Notes:</span> <a href='?src=\ref[src];ooc_notes=1'>\[View\]</a>"

	if(src.getBruteLoss())
		if(src.getBruteLoss() < (maxHealth/2))
			msg += "<span class='warning'>[T.He] looks bruised.</span>"
		else
			msg += "<span class='warning'><B>[T.He] looks severely bruised and bloodied!</B></span>"
	if(src.getFireLoss())
		if(src.getFireLoss() < (maxHealth/2))
			msg += "<span class='warning'>[T.He] looks burned.</span>"
		else
			msg += "<span class='warning'><B>[T.He] looks severely burned.</B></span>"
	if(r_hand)
		msg += "[T.He] [T.is] holding [bicon(r_hand)] \a [r_hand] in [T.his] right hand."
	if(l_hand)
		msg += "[T.He] [T.is] holding [bicon(l_hand)] \a [l_hand] in [T.his] left hand."

	if(M_TF in active_moves) //Ditto transformed
		msg += "<span class='alien'><i>They don't look quite right...</i></span>"

	msg += examine_bellies()

	if(M_SHOCK in active_moves)
		msg += "<span class='warning'>[T.He] [T.is] bristling with a dangerous amount of electricity!</span>"

	msg += "<span class='deptradio'><a href='?src=\ref[src];vore_prefs=1'>\[Mechanical Vore Preferences\]</a></span>"

	if(client && ((client.inactivity / 10) / 60 > 10)) //10 Minutes
		msg += "\[Inactive for [round((client.inactivity/10)/60)] minutes\]"
	else if(disconnect_time)
		msg += "\[Disconnected/ghosted [round(((world.realtime - disconnect_time)/10)/60)] minutes ago\]"

	msg += "*---------*"

	return msg

/mob/living/simple_mob/animal/passive/pokemon/update_icon()
	. = ..()
	pixel_x = default_pixel_x 	//If they're somehow reset out of their offset, this will correct them. (grabs do this)
	pixel_y = old_y
	cut_overlay(r_hand_sprite)	//Hand sprites don't line up with the mob, just hide them
	cut_overlay(l_hand_sprite)
	//update_icon is called when you pick something up or drop it anyways, so this goes here
	if(istype(r_hand,/obj/item/weapon/card/id))
		myid = r_hand
	else if(istype(l_hand,/obj/item/weapon/card/id))
		myid = l_hand
	else
		myid = null

/mob/living/simple_mob/animal/passive/pokemon/resize(new_size, animate = TRUE, uncapped = FALSE, ignore_prefs = FALSE, aura_animation = TRUE)
	. = ..()
	//Handle pixel y offsetting large sprite mobs
	var/pixy = ((new_size - 1)*y_offset_mult)
	pixel_y = pixy
	default_pixel_y = pixy
	old_y = pixy

/mob/living/proc/set_ooc_notes()
	set name = "Set OOC Notes"
	set category = "OOC"
	set desc = "Edit your roleplaying preferences; your OOC notes."
	if(usr != src)
		to_chat(usr, "No.")
	var/msg = sanitize(input(usr,"Set your OOC notes. This should contain your roleplaying preferences.","OOC Notes",html_decode(ooc_notes)) as message|null, extra = 0)
	if(msg != null)
		ooc_notes = msg

/mob/living/proc/set_flavor_text()
	set name = "Set Flavortext"
	set category = "IC"
	set desc = "Edit your flavortext; a detailed description of your character."
	if(usr != src)
		to_chat(usr, "No.")
	var/msg = sanitize(input(usr,"Set your character's flavortext; a detailed description of their physical appearance.","Flavortext",html_decode(flavor_text)) as message|null, extra = 0)
	if(msg != null)
		flavor_text = msg

/mob/living/simple_mob/animal/passive/pokemon/is_incorporeal()
	if(M_GHOSTED in active_moves)
		return TRUE
	return ..()

/mob/living/simple_mob/animal/passive/pokemon/can_ztravel()
	if(M_GHOSTED in active_moves)
		return TRUE
	return ..()

//Override to stop attacking while grabbing
/mob/living/simple_mob/animal/passive/pokemon/UnarmedAttack(var/atom/A, var/proximity)
	if(is_incorporeal())
		return 0

	if(!ticker)
		to_chat(src, "You cannot attack people before the game has started.")
		return 0

	if(stat)
		return 0

	if(has_hands && istype(A,/obj) && a_intent != I_HURT)
		var/obj/O = A
		return O.attack_hand(src)

	switch(a_intent)
		if(I_HELP)
			if(isliving(A))
				custom_emote(1,"[pick(friendly)] \the [A]!")

		if(I_HURT)
			if(can_special_attack(A) && special_attack_target(A))
				return

			else if(melee_damage_upper == 0 && istype(A,/mob/living))
				custom_emote(1,"[pick(friendly)] \the [A]!")

			else
				attack_target(A)

		if(I_GRAB)
			if(has_hands)
				A.attack_hand(src)
			else
				if(isliving(A) && vore_active)//Don't attack what you're eating
					animal_nom(A)
				else
					attack_target(A)
		if(I_DISARM)
			if(has_hands)
				A.attack_hand(src)
			else
				attack_target(A)
	return 1

//Might moves this to pokemon_moves.dm
/mob/living/simple_mob/animal/passive/pokemon/proc/give_trait(var/trait)
	if(!trait)
		return FALSE
	switch(trait)
		if(P_TRAIT_RIDEABLE)
			max_buckled_mobs = 1
			can_buckle = TRUE
			buckle_movable = TRUE
			buckle_lying = FALSE
			riding_datum = new /datum/riding/pokemon(src)
			verbs |= /mob/living/proc/toggle_rider_reins //Let riders take control
			verbs |= /mob/living/simple_mob/animal/passive/pokemon/proc/riding_mount //Make people ride you
	return TRUE

/mob/living/simple_mob/animal/passive/pokemon/CtrlClickOn(var/atom/A)
	if(M_GHOSTED in active_moves)
		to_chat(src,"<span class='warning'>You need to rematerialize to do that!</span>")
		return FALSE
	else
		. = ..()

/////TEMPLATE/////
/*
/mob/living/simple_mob/animal/passive/pokemon
	name = ""
	icon_state = ""
	icon_living = ""
	icon_dead = ""
*/

/mob/living/simple_mob/animal/passive/pokemon/leg
	icon = 'content_arfs/icons/mob/mobs/legendary.dmi'
	pixel_x = -32
	default_pixel_x = -32
	old_x = -32
	health = 200
	maxHealth = 200
	meat_amount = 6
	resting_heal_max = 4

/mob/living/simple_mob/animal/passive/pokemon/leg/articuno
	name = "Articuno"
	icon_state = "articuno"
	icon_living = "articuno"
	icon_dead = "articuno_d"
	p_types = list(P_TYPE_ICE, P_TYPE_FLY)
	movement_cooldown = 1.5
	y_offset_mult = 32

/mob/living/simple_mob/animal/passive/pokemon/leg/lugia
	name = "Lugia"
	icon_state = "lugia"
	icon_living = "lugia"
	icon_dead = "lugia_d"
	p_types = list(P_TYPE_PSYCH, P_TYPE_FLY)
	movement_cooldown = 1.5
	mob_size = MOB_HUGE

/mob/living/simple_mob/animal/passive/pokemon/leg/lugia/andy
	health = 500
	maxHealth = 500
	vore_capacity = 2
	size_multiplier = 2
	default_pixel_y = 16
	pixel_y = 16
	old_y = 16

/mob/living/simple_mob/animal/passive/pokemon/leg/rayquaza
	name = "Rayquaza"
	icon_state = "rayquaza"
	icon_living = "rayquaza"
	icon_dead = "rayquaza_d"
	p_types = list(P_TYPE_FLY)
	movement_cooldown = 1.5
	mob_size = MOB_HUGE


///////////////////////////////
//////ALPHABETICAL PLEASE//////
///////////////////////////////

/mob/living/simple_mob/animal/passive/pokemon/absol
	name = "absol"
	icon_state = "absol"
	icon_living = "absol"
	icon_dead = "absol_d"
	p_types = list(P_TYPE_DARK)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/aggron
	name = "aggron"
	icon_state = "aggron"
	icon_living = "aggron"
	icon_dead = "aggron_d"
	p_types = list(P_TYPE_STEEL)
	movement_cooldown = 5
	mob_size = MOB_LARGE
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/alolanvulpix
	name = "alolan vulpix"
	icon_state = "alolanvulpix"
	icon_living = "alolanvulpix"
	icon_dead = "alolanvulpix_d"
	tt_desc = "Alolan Vulpix"
	p_types = list(P_TYPE_ICE)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/ampharos
	name = "ampharos"
	icon_state = "ampharos"
	icon_living = "ampharos"
	icon_dead = "ampharos_d"
	p_types = list(P_TYPE_ELEC)
	mob_size = MOB_LARGE

/mob/living/simple_mob/animal/passive/pokemon/braixen
	name = "braixen"
	icon_state = "braixen"
	icon_living = "braixen"
	icon_dead = "braixen_d"
	p_types = list(P_TYPE_FIRE)
	additional_moves = list(/mob/living/proc/hide)

/mob/living/simple_mob/animal/passive/pokemon/celebi
	name = "celebi"
	icon_state = "celebi"
	icon_living = "celebi"
	icon_dead = "celebi_d"
	p_types = list(P_TYPE_PSYCH, P_TYPE_GRASS)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/charmander
	name = "charmander"
	icon_state = "charmander"
	icon_living = "charmander"
	icon_dead = "charmander_d"
	p_types = list(P_TYPE_FIRE)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/ditto
	name = "ditto"
	icon_state = "ditto"
	icon_living = "ditto"
	icon_dead = "ditto_d"
	p_types = list(P_TYPE_NORM)
	additional_moves = list(/mob/living/proc/hide, /mob/living/simple_mob/animal/passive/pokemon/proc/move_imposter)//amogus
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/dragonair
	name = "dragonair"
	desc = "A Dragonair stores an enormous amount of energy inside its body. It is said to alter the weather around it by loosing energy from the crystals on its neck and tail."
	icon_state = "dragonair"
	icon_living = "dragonair"
	icon_dead = "dragonair_d"
	p_types = list(P_TYPE_DRAGON)
	aquatic_movement = 1
	additional_moves = list(/mob/living/simple_mob/animal/passive/pokemon/proc/move_fly,
							/mob/living/simple_mob/animal/passive/pokemon/proc/move_hover)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_LARGE

/mob/living/simple_mob/animal/passive/pokemon/dragonair/shiny
	name = "shiny dragonair"
	icon_state = "shinydragonair"
	icon_living = "shinydragonair"
	icon_dead = "shinydragonair_d"

/mob/living/simple_mob/animal/passive/pokemon/dragonite
	name = "dragonite"
	desc = "It can circle the globe in just 16 hours. It is a kindhearted Pok�mon that leads lost and foundering ships in a storm to the safety of land."
	icon_state = "dragonite"
	icon_living = "dragonite"
	icon_dead = "dragonite_d"
	p_types = list(P_TYPE_DRAGON, P_TYPE_FLY)
	aquatic_movement = 1
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_LARGE

/mob/living/simple_mob/animal/passive/pokemon/dratini
	name = "dratini"
	desc = "A Dratini continually molts and sloughs off its old skin. It does so because the life energy within its body steadily builds to reach uncontrollable levels."
	icon_state = "dratini"
	icon_living = "dratini"
	icon_dead = "dratini_d"
	movement_cooldown = 3
	aquatic_movement = 1
	p_types = list(P_TYPE_DRAGON)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/eevee
	name = "eevee"
	desc = "Eevee has an unstable genetic makeup that suddenly mutates due to its environment. Radiation from various stones causes this Pok�mon to evolve."
	icon_state = "eevee"
	icon_living = "eevee"
	icon_dead = "eevee_d"
	p_types = list(P_TYPE_NORM)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/espeon
	name = "espeon"
	desc = "Espeon is extremely loyal to any trainer it considers to be worthy. It is said to have developed precognitive powers to protect its trainer from harm."
	icon_state = "espeon"
	icon_living = "espeon"
	icon_dead = "espeon_d"
	p_types = list(P_TYPE_PSYCH)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/fennekin
	name = "fennekin"
	icon_state = "fennekin"
	icon_living = "fennekin"
	icon_dead = "fennekin_d"
	p_types = list(P_TYPE_FIRE)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/flaaffy
	name = "flaaffy"
	icon_state = "flaaffy"
	icon_living = "flaaffy"
	icon_dead = "flaaffy_d"
	p_types = list(P_TYPE_ELEC)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/flareon
	name = "flareon"
	desc = "Flareon's fluffy fur releases heat into the air so that its body does not get excessively hot. Its body temperature can rise to a maximum of 1,650 degrees F."
	icon_state = "flareon"
	icon_living = "flareon"
	icon_dead = "flareon_d"
	p_types = list(P_TYPE_FIRE)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/flygon
	name = "flygon"
	desc = "The flapping of its wings sounds something like singing. Those lured by the sound are enveloped in a sandstorm, becoming Flygon's prey."
	icon_state = "flygon"
	icon_living = "flygon"
	icon_dead = "flygon_d"
	p_types = list(P_TYPE_GROUND, P_TYPE_DRAGON)
	additional_moves = list(/mob/living/simple_mob/animal/passive/pokemon/proc/move_fly,
							/mob/living/simple_mob/animal/passive/pokemon/proc/move_hover)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_LARGE

/mob/living/simple_mob/animal/passive/pokemon/furret
	name = "furret"
	icon_state = "furret"
	icon_living = "furret"
	icon_dead = "furret_d"
	p_types = list(P_TYPE_NORM)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/gallade
	name = "gallade"
	icon_state = "gallade"
	icon_living = "gallade"
	icon_dead = "gallade_d"
	p_types = list(P_TYPE_PSYCH, P_TYPE_FIGHT)
	additional_moves = list(/mob/living/proc/hide)

/mob/living/simple_mob/animal/passive/pokemon/gardevoir
	name = "gardevoir"
	icon_state = "gardevoir"
	icon_living = "gardevoir"
	icon_dead = "gardevoir_d"
	p_types = list(P_TYPE_PSYCH, P_TYPE_FAIRY)
	additional_moves = list(/mob/living/proc/hide)

/mob/living/simple_mob/animal/passive/pokemon/gastly
	name = "gastly"
	desc = "Almost invisible, this gaseous Pok�mon cloaks the target and puts it to sleep without notice."
	icon_state = "gastly"
	icon_living = "gastly"
	icon_dead = "gastly_d"
	p_types = list(P_TYPE_GHOST, P_TYPE_POISON)
	additional_moves = list(/mob/living/proc/hide)

/mob/living/simple_mob/animal/passive/pokemon/gengar
	name = "gengar"
	desc = "It hides in shadows. It is said that if Gengar is hiding, it cools the area by nearly 10 degrees F."
	icon_state = "gengar"
	icon_living = "gengar"
	icon_dead = "gengar_d"
	p_types = list(P_TYPE_GHOST, P_TYPE_POISON)
	additional_moves = list(/mob/living/proc/hide)


/mob/living/simple_mob/animal/passive/pokemon/glaceon
	name = "glaceon"
	desc = "By controlling its body heat, it can freeze the atmosphere around it to make a diamond-dust flurry."
	icon_state = "glaceon"
	icon_living = "glaceon"
	icon_dead = "glaceon_d"
	p_types = list(P_TYPE_ICE)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/haunter
	name = "haunter"
	desc = "If you get the feeling of being watched in darkness when nobody is around, Haunter may be there."
	icon_state = "haunter"
	icon_living = "haunter"
	icon_dead = "haunter_d"
	p_types = list(P_TYPE_GHOST, P_TYPE_POISON)
	additional_moves = list(/mob/living/proc/hide)

/mob/living/simple_mob/animal/passive/pokemon/jirachi
	name = "jirachi"
	desc = "Generations have believed that any wish written on a note on its head will come true when it awakens."
	icon_state = "jirachi"
	icon_living = "jirachi"
	icon_dead = "jirachi_d"
	p_types = list(P_TYPE_STEEL, P_TYPE_PSYCH)
	additional_moves = list(/mob/living/simple_mob/animal/passive/pokemon/proc/move_fly,
							/mob/living/simple_mob/animal/passive/pokemon/proc/move_hover)

/mob/living/simple_mob/animal/passive/pokemon/jolteon
	name = "jolteon"
	desc = "Its cells generate weak power that is amplified by its fur's static electricity to drop thunderbolts. The bristling fur is made of electrically charged needles."
	icon_state = "jolteon"
	icon_living = "jolteon"
	icon_dead = "jolteon_d"
	p_types = list(P_TYPE_ELEC)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/attack_hand(mob/user as mob)
	if(LAZYLEN(buckled_mobs)) //Handle unbuckling riding mobs
		if(user in buckled_mobs)
			riding_datum.force_dismount(user)
		if(user == src)
			for(var/rider in buckled_mobs)
				riding_datum.force_dismount(rider)
	else
		. = ..()
	//Shock them after they attack or whatever, so they actually affect the pkmn in question
	if(!stat && (M_SHOCK in active_moves))
		electrocute_mob(user, get_area(src), src, 1)

/mob/living/simple_mob/animal/passive/pokemon/attackby(obj/item/weapon/W, mob/user, params)
	if(M_SHOCK in active_moves)
		electrocute_mob(user, get_area(src), src, W.siemens_coefficient)
		if(!stat && istype(W, /obj/item/weapon/cell))
			var/obj/item/weapon/cell/C = W
			if(move_cooldown)
				to_chat(user,"<span class='red'>\the [src.name] is recharging!</span>")
				return
			if(C.charge == C.maxcharge)
				to_chat(user,"<span class='red'>[C] is already fully charged!</span>")
				return
			electrocute_mob(user, get_area(src), src, W.siemens_coefficient)
			to_chat(user,"<span class='green'>You charge [C] using [src].</span>")
			var/chargetogive = rand(50,250)
			C.give(chargetogive)
			C.update_icon()
			move_cooldown = TRUE
			spawn(move_cooldown_time)
				move_cooldown = FALSE
			return
	..()

/mob/living/simple_mob/animal/passive/pokemon/jolteon/bud
	name = "Bud"
	active_moves = list(M_SHOCK) //Shocks you by default

/mob/living/simple_mob/animal/passive/pokemon/kirlia
	name = "kirlia"
	icon_state = "kirlia"
	icon_living = "kirlia"
	icon_dead = "kirlia_d"
	p_types = list(P_TYPE_PSYCH, P_TYPE_FAIRY)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/larvitar
	name = "larvitar"
	desc = "It is born deep underground. It can't emerge until it has entirely consumed the soil around it."
	icon = 'content_arfs/icons/mob/mobs/pokemon.dmi'
	icon_state = "larvitar"
	icon_living = "larvitar"
	icon_dead = "larvitar_d"
	p_types = list(P_TYPE_ROCK, P_TYPE_GROUND)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/leafeon
	name = "leafeon"
	icon_state = "leafeon"
	icon_living = "leafeon"
	icon_dead = "leafeon_d"
	p_types = list(P_TYPE_GRASS)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/linoone
	name = "linoone"
	icon_state = "linoone"
	icon_living = "linoone"
	icon_dead = "linoone_d"
	p_types = list(P_TYPE_NORM)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/growlithe
	name = "growlithe"
	icon_state = "growlithe"
	icon_living = "growlithe"
	icon_dead = "growlithe_d"
	p_types = list(P_TYPE_FIRE)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/mareep
	name = "mareep"
	icon_state = "mareep"
	icon_living = "mareep"
	icon_dead = "mareep_d"
	p_types = list(P_TYPE_ELEC)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/mightyena
	name = "mightyena"
	icon_state = "mightyena"
	icon_living = "mightyena"
	icon_dead = "mightyena"
	p_types = list(P_TYPE_DARK)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/miltank
	name = "miltank"
	icon_state = "miltank"
	icon_living = "miltank"
	icon_dead = "miltank_d"
	p_types = list(P_TYPE_NORM)
	var/datum/reagents/udder = null
	movement_cooldown = 3

/mob/living/simple_mob/animal/passive/pokemon/miltank/Initialize()
	udder = new(50)
	udder.my_atom = src
	..()

/mob/living/simple_mob/animal/passive/pokemon/miltank/Life()
	. = ..()
	if(stat == CONSCIOUS)
		if(udder && prob(5))
			udder.add_reagent("milk", rand(5, 10))

/mob/living/simple_mob/animal/passive/pokemon/miltank/attackby(var/obj/item/O as obj, var/mob/user as mob)
	var/obj/item/weapon/reagent_containers/glass/G = O
	if(stat == CONSCIOUS && istype(G) && G.is_open_container())
		user.visible_message("<span class='notice'>[user] milks [src] using \the [O].</span>")
		var/transfered = udder.trans_id_to(G, "milk", rand(5,10))
		if(G.reagents.total_volume >= G.volume)
			user << "<font color='red'> The udder is dry. Wait a bit longer... </font>"
		if(!transfered)
			user << "<font color='red'> The udder is dry. Wait a bit longer... </font>"
		..()

/mob/living/simple_mob/animal/passive/pokemon/poochyena
	name = "poochyena"
	icon_state = "poochyena"
	icon_living = "poochyena"
	icon_dead = "poochyena_d"
	p_types = list(P_TYPE_DARK)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/sylveon
	name = "sylveon"
	desc = "Sylveon, the Intertwining Pok�mon. Sylveon affectionately wraps its ribbon-like feelers around its Trainer's arm as they walk together."
	icon_state = "sylveon"
	icon_living = "sylveon"
	icon_dead = "sylveon_d"
	response_help  = "pets"
	response_harm   = "hits"
	p_types = list(P_TYPE_FAIRY)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/umbreon
	name = "umbreon"
	icon_state = "umbreon"
	icon_dead = "umbreon_d"
	icon_living = "umbreon"
	p_types = list(P_TYPE_DARK)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/vulpix
	name = "vulpix"
	icon_state = "vulpix"
	icon_living = "vulpix"
	icon_dead = "vulpix_d"
	p_types = list(P_TYPE_FIRE)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/tentacruel
	name = "tentacruel"
	icon_state = "tentacruel"
	icon_living = "tentacruel"
	icon_dead = "tentacruel_d"
	movement_cooldown = 3
	p_types = list(P_TYPE_WATER)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/thievul
	name = "thievul"
	icon_state = "thievul"
	icon_living = "thievul"
	icon_dead = "thievul_d"
	p_types = list(P_TYPE_DARK)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/ninetales
	name = "ninetales"
	icon_state = "ninetales"
	icon_living = "ninetales"
	icon_dead = "ninetales_d"
	p_types = list(P_TYPE_FIRE)
	additional_moves = list(/mob/living/simple_mob/animal/passive/pokemon/proc/move_telepathy)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/ponyta
	name = "ponyta"
	icon_state = "ponyta"
	icon_living = "ponyta"
	icon_dead = "ponyta_d"
	p_types = list(P_TYPE_FIRE)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_SMALL
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/zubat
	name = "zubat"
	icon_state = "zubat"
	icon_living = "zubat"
	icon_dead = "zubat_d"
	desc = "Even though it has no eyes, it can sense obstacles using ultrasonic waves it emits from its mouth."
	p_types = list(P_TYPE_FLY, P_TYPE_POISON)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/tangela
	name = "tangela"
	icon_state = "tangela"
	icon_living = "tangela"
	icon_dead = "tangela_d"
	p_types = list(P_TYPE_GRASS, P_TYPE_POISON)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/pinsir
	name = "pinsir"
	icon_state = "pinsir"
	icon_living = "pinsir"
	icon_dead = "pinsir_d"
	p_types = list(P_TYPE_BUG)

/mob/living/simple_mob/animal/passive/pokemon/omanyte
	name = "omanyte"
	icon_state = "omanyte"
	icon_living = "omanyte"
	icon_dead = "omanyte_d"
	movement_cooldown = 3
	p_types = list(P_TYPE_ROCK, P_TYPE_WATER)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/magmar
	name = "magmar"
	icon_state = "magmar"
	icon_living = "magmar"
	icon_dead = "magmar_d"
	movement_cooldown = 3
	p_types = list(P_TYPE_FIRE)

/mob/living/simple_mob/animal/passive/pokemon/magicarp
	name = "magicarp"
	icon_state = "magicarp"
	icon_living = "magicarp"
	icon_dead = "magicarp_d"
	movement_cooldown = 5
	p_types = list(P_TYPE_WATER)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/lapras
	name = "lapras"
	icon_state = "lapras"
	icon_living = "lapras"
	icon_dead = "lapras_d"
	movement_cooldown = 3
	p_types = list(P_TYPE_WATER)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/kabuto
	name = "kabuto"
	icon_state = "Kabuto"
	icon_living = "Kabuto"
	icon_dead = "Kabuto_d"
	p_types = list(P_TYPE_ROCK, P_TYPE_WATER)
	additional_moves = list(/mob/living/proc/hide)

/mob/living/simple_mob/animal/passive/pokemon/aerodactyl
	name = "aerodactyl"
	icon_state = "Aerodactyl"
	icon_living = "Aerodactyl"
	icon_dead = "Aerodactyl_d"
	p_types = list(P_TYPE_ROCK, P_TYPE_FLY)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/lickitung
	name = "lickitung"
	icon_state = "lickitung"
	icon_living = "lickitung"
	icon_dead = "lickitung_d"
	p_types = list(P_TYPE_NORM)

/mob/living/simple_mob/animal/passive/pokemon/cubone
	name = "cubone"
	icon_state = "cubone"
	icon_living = "cubone"
	icon_dead = "cubone_d"
	p_types = list(P_TYPE_GROUND)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/mew
	name = "mew"
	icon_state = "mew"
	icon_living = "mew"
	icon_dead = "mew_d"
	p_types = list(P_TYPE_PSYCH)
	additional_moves = list(/mob/living/simple_mob/animal/passive/pokemon/proc/move_fly,
							/mob/living/simple_mob/animal/passive/pokemon/proc/move_hover,
							/mob/living/simple_mob/animal/passive/pokemon/proc/move_imposter,
							/mob/living/simple_mob/animal/passive/pokemon/proc/move_invisibility)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/mewtwo
	name = "mewtwo"
	icon_state = "mewtwo"
	icon_living = "mewtwo"
	icon_dead = "mewtwo_d"
	p_types = list(P_TYPE_PSYCH)
	additional_moves = list(/mob/living/simple_mob/animal/passive/pokemon/proc/move_fly,
							/mob/living/simple_mob/animal/passive/pokemon/proc/move_hover)

/mob/living/simple_mob/animal/passive/pokemon/purrloin
	name = "purrloin"
	icon_state = "purrloin"
	icon_living = "purrloin"
	icon_dead = "purrloin_d"
	p_types = list(P_TYPE_DARK)
	additional_moves = list(/mob/living/proc/hide)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/ralts
	name = "ralts"
	icon_state = "ralts"
	icon_living = "ralts"
	icon_dead = "ralts_d"
	p_types = list(P_TYPE_PSYCH, P_TYPE_FAIRY)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/snorlax
	name = "snorlax"
	icon_state = "snorlax"
	icon_living = "snorlax"
	icon_dead = "snorlax_d"
	p_types = list(P_TYPE_NORM)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/vaporeon
	name = "vaporeon"
	icon_state = "vaporeon"
	icon_living = "vaporeon"
	icon_dead = "vaporeon_d"
	p_types = list(P_TYPE_WATER)
	p_traits = list(P_TRAIT_RIDEABLE)

/mob/living/simple_mob/animal/passive/pokemon/zigzagoon
	name = "zigzagoon"
	icon_state = "zigzagoon"
	icon_living = "zigzagoon"
	icon_dead = "zigzagoon_d"
	p_types = list(P_TYPE_NORM)
	additional_moves = list(/mob/living/proc/hide)
	p_traits = list(P_TRAIT_RIDEABLE)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/zoroark
	name = "zoroark"
	icon_state = "zoroark"
	icon_living = "zoroark"
	icon_dead = "zoroark_d"
	p_types = list(P_TYPE_DARK)
	additional_moves = list(/mob/living/proc/hide, /mob/living/simple_mob/animal/passive/pokemon/proc/move_imposter)

/mob/living/simple_mob/animal/passive/pokemon/zorua
	name = "zorua"
	icon_state = "zorua"
	icon_living = "zorua"
	icon_dead = "zorua_d"
	p_types = list(P_TYPE_DARK)
	additional_moves = list(/mob/living/proc/hide, /mob/living/simple_mob/animal/passive/pokemon/proc/move_imposter)
	mob_size = MOB_SMALL

/mob/living/simple_mob/animal/passive/pokemon/zorua_hisuian
	name = "hisuian zorua"
	icon_state = "zorua_hisuian"
	icon_living = "zorua_hisuian"
	icon_dead = "zorua_hisuian_d"
	tt_desc = "hisuian zorua"
	p_types = list(P_TYPE_NORM, P_TYPE_GHOST)
	additional_moves = list(/mob/living/proc/hide, /mob/living/simple_mob/animal/passive/pokemon/proc/move_imposter)
	mob_size = MOB_SMALL

///////////////////////
//ALPHABETICAL PLEASE//
///////////////////////
